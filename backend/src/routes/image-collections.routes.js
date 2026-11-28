import { randomUUID } from 'node:crypto';

import { Router } from 'express';
import { z } from 'zod';

import {
  createApiLogMiddleware,
  createImageServerAuth,
  requireScope,
} from '../middleware/image-server-auth.js';
import { fail, ok, zodValidationError } from '../services/image-server-helpers.js';
import { slugify } from '../services/image-validation.js';

const uuid = z.uuid();

const folderCreateSchema = z.strictObject({
  name: z.string().trim().min(1).max(150),
  parentId: uuid.nullable().optional(),
});

const folderPatchSchema = z.strictObject({
  name: z.string().trim().min(1).max(150).optional(),
  parentId: uuid.nullable().optional(),
});

const albumCreateSchema = z.strictObject({
  title: z.string().trim().min(1).max(180),
  description: z.string().trim().max(2000).nullable().optional(),
  visibility: z.enum(['public', 'private']).default('private'),
  coverImageId: uuid.nullable().optional(),
});

const albumPatchSchema = z.strictObject({
  title: z.string().trim().min(1).max(180).optional(),
  description: z.string().trim().max(2000).nullable().optional(),
  visibility: z.enum(['public', 'private']).optional(),
  coverImageId: uuid.nullable().optional(),
});

const albumImagesSchema = z.strictObject({
  imageIds: z.array(uuid).min(1).max(100),
});

const tagCreateSchema = z.strictObject({
  name: z.string().trim().min(1).max(80),
  color: z.string().trim().regex(/^#[0-9a-fA-F]{3,8}$/).optional(),
});

function buildFolderTree(rows) {
  const byId = new Map();
  const roots = [];
  for (const row of rows) {
    byId.set(row.id, {
      id: row.id,
      ownerId: row.owner_id,
      parentId: row.parent_id ?? null,
      name: row.name,
      slug: row.slug,
      imageCount: Number(row.image_count ?? 0),
      createdAt: row.created_at,
      children: [],
    });
  }
  for (const node of byId.values()) {
    if (node.parentId && byId.has(node.parentId)) {
      byId.get(node.parentId).children.push(node);
    } else {
      roots.push(node);
    }
  }
  return roots;
}

export function createImageCollectionsRouter({ database, jwtSecret }) {
  const router = Router();
  const authenticate = createImageServerAuth({ database, jwtSecret });
  const apiLogger = createApiLogMiddleware({ database });

  router.use(['/folders', '/albums', '/tags'], apiLogger, authenticate);

  // ---------------- FOLDERS ----------------
  router.get('/folders', requireScope('folders:read'), async (request, response) => {
    try {
      const isAdmin = request.authUser.role === 'ADMIN';
      const values = isAdmin ? [] : [request.authUser.id];
      const ownerWhere = isAdmin ? '' : 'AND f.owner_id = $1';
      const res = await database.query(
        `SELECT f.*,
                (SELECT COUNT(*)::int FROM images i WHERE i.folder_id = f.id AND i.deleted_at IS NULL) AS image_count
         FROM folders f
         WHERE f.deleted_at IS NULL ${ownerWhere}
         ORDER BY lower(f.name) ASC`,
        values,
      );
      const items = res.rows.map((r) => ({
        id: r.id,
        ownerId: r.owner_id,
        parentId: r.parent_id ?? null,
        name: r.name,
        slug: r.slug,
        imageCount: Number(r.image_count ?? 0),
        createdAt: r.created_at,
        updatedAt: r.updated_at,
      }));
      return ok(response, { items, tree: buildFolderTree(res.rows) });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể tải danh sách thư mục.');
    }
  });

  router.post('/folders', requireScope('folders:write'), async (request, response) => {
    const parsed = folderCreateSchema.safeParse(request.body);
    if (!parsed.success) return zodValidationError(response, parsed.error);
    const { name, parentId = null } = parsed.data;
    try {
      if (parentId) {
        const parentRes = await database.query(
          'SELECT id, owner_id FROM folders WHERE id = $1 AND deleted_at IS NULL',
          [parentId],
        );
        if (!parentRes.rows.length) {
          return fail(response, 404, 'NOT_FOUND', 'Thư mục cha không tồn tại.');
        }
      }
      const inserted = await database.query(
        `INSERT INTO folders (id, owner_id, parent_id, name, slug)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING *`,
        [randomUUID(), request.authUser.id, parentId, name, slugify(name, 'folder')],
      );
      const row = inserted.rows[0];
      return ok(response, {
        id: row.id,
        ownerId: row.owner_id,
        parentId: row.parent_id,
        name: row.name,
        slug: row.slug,
        imageCount: 0,
        createdAt: row.created_at,
      }, { status: 201 });
    } catch (err) {
      if (err.code === '23505') {
        return fail(response, 409, 'DUPLICATE_FOLDER', 'Tên thư mục đã tồn tại ở cấp này.');
      }
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể tạo thư mục.');
    }
  });

  router.patch('/folders/:id', requireScope('folders:write'), async (request, response) => {
    const { id } = request.params;
    if (!uuid.safeParse(id).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã thư mục không hợp lệ.');
    const parsed = folderPatchSchema.safeParse(request.body);
    if (!parsed.success) return zodValidationError(response, parsed.error);

    try {
      const existing = await database.query('SELECT * FROM folders WHERE id = $1 AND deleted_at IS NULL', [id]);
      const folder = existing.rows[0];
      if (!folder || (request.authUser.role !== 'ADMIN' && folder.owner_id !== request.authUser.id)) {
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy thư mục.');
      }
      if (parsed.data.parentId === id) {
        return fail(response, 422, 'VALIDATION_ERROR', 'Thư mục không thể làm thư mục cha của chính nó.');
      }

      const updates = [];
      const values = [];
      if (parsed.data.name !== undefined) {
        values.push(parsed.data.name);
        updates.push(`name = $${values.length}`);
        values.push(slugify(parsed.data.name, 'folder'));
        updates.push(`slug = $${values.length}`);
      }
      if (parsed.data.parentId !== undefined) {
        values.push(parsed.data.parentId);
        updates.push(`parent_id = $${values.length}`);
      }
      if (!updates.length) return ok(response, folder);

      values.push(id);
      const upd = await database.query(
        `UPDATE folders SET ${updates.join(', ')}, updated_at = now() WHERE id = $${values.length} RETURNING *`,
        values,
      );
      return ok(response, upd.rows[0]);
    } catch (err) {
      if (err.code === '23505') {
        return fail(response, 409, 'DUPLICATE_FOLDER', 'Tên thư mục bị trùng ở cấp đích.');
      }
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể cập nhật thư mục.');
    }
  });

  router.delete('/folders/:id', requireScope('folders:write'), async (request, response) => {
    const { id } = request.params;
    if (!uuid.safeParse(id).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã thư mục không hợp lệ.');
    try {
      const existing = await database.query('SELECT * FROM folders WHERE id = $1 AND deleted_at IS NULL', [id]);
      const folder = existing.rows[0];
      if (!folder || (request.authUser.role !== 'ADMIN' && folder.owner_id !== request.authUser.id)) {
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy thư mục.');
      }
      await database.query('UPDATE images SET folder_id = NULL WHERE folder_id = $1', [id]);
      await database.query('UPDATE folders SET deleted_at = now(), updated_at = now() WHERE id = $1', [id]);
      return ok(response, { id, deleted: true });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể xóa thư mục.');
    }
  });

  // ---------------- ALBUMS ----------------
  router.get('/albums', requireScope('albums:read'), async (request, response) => {
    try {
      const isAdmin = request.authUser.role === 'ADMIN';
      const values = isAdmin ? [] : [request.authUser.id];
      const ownerWhere = isAdmin ? '' : 'AND a.owner_id = $1';
      const res = await database.query(
        `SELECT a.*, u.full_name AS owner_name,
                (SELECT COUNT(*)::int FROM album_images ai JOIN images i ON i.id = ai.image_id WHERE ai.album_id = a.id AND i.deleted_at IS NULL) AS image_count
         FROM albums a
         LEFT JOIN users u ON u.id = a.owner_id
         WHERE a.deleted_at IS NULL ${ownerWhere}
         ORDER BY a.created_at DESC`,
        values,
      );
      return ok(response, res.rows.map((a) => ({
        id: a.id,
        ownerId: a.owner_id,
        ownerName: a.owner_name ?? null,
        title: a.title,
        description: a.description ?? '',
        coverImageId: a.cover_image_id ?? null,
        coverThumbnailUrl: a.cover_image_id ? `/api/v1/images/${a.cover_image_id}/thumbnail` : null,
        visibility: a.visibility,
        shareSlug: a.share_slug ?? null,
        imageCount: Number(a.image_count ?? 0),
        createdAt: a.created_at,
        updatedAt: a.updated_at,
      })));
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể tải danh sách album.');
    }
  });

  router.post('/albums', requireScope('albums:write'), async (request, response) => {
    const parsed = albumCreateSchema.safeParse(request.body);
    if (!parsed.success) return zodValidationError(response, parsed.error);
    const { title, description = null, visibility, coverImageId = null } = parsed.data;
    try {
      const id = randomUUID();
      const shareSlug = `${slugify(title, 'album')}-${id.slice(0, 6)}`;
      const res = await database.query(
        `INSERT INTO albums (id, owner_id, title, description, cover_image_id, visibility, share_slug)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         RETURNING *`,
        [id, request.authUser.id, title, description, coverImageId, visibility, shareSlug],
      );
      const a = res.rows[0];
      return ok(response, {
        id: a.id,
        ownerId: a.owner_id,
        title: a.title,
        description: a.description ?? '',
        coverImageId: a.cover_image_id,
        coverThumbnailUrl: a.cover_image_id ? `/api/v1/images/${a.cover_image_id}/thumbnail` : null,
        visibility: a.visibility,
        shareSlug: a.share_slug,
        imageCount: 0,
        createdAt: a.created_at,
      }, { status: 201 });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể tạo album.');
    }
  });

  router.get('/albums/:id', requireScope('albums:read'), async (request, response) => {
    const { id } = request.params;
    if (!uuid.safeParse(id).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã album không hợp lệ.');
    try {
      const res = await database.query('SELECT * FROM albums WHERE id = $1 AND deleted_at IS NULL', [id]);
      const album = res.rows[0];
      if (!album || (request.authUser.role !== 'ADMIN' && album.owner_id !== request.authUser.id)) {
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy album.');
      }
      const imagesRes = await database.query(
        `SELECT i.id, i.filename, i.mime_type, i.extension, i.size_bytes, i.width, i.height, i.visibility, ai.sort_order
         FROM album_images ai
         JOIN images i ON i.id = ai.image_id
         WHERE ai.album_id = $1 AND i.deleted_at IS NULL
         ORDER BY ai.sort_order ASC, ai.added_at DESC`,
        [id],
      );
      return ok(response, {
        id: album.id,
        ownerId: album.owner_id,
        title: album.title,
        description: album.description ?? '',
        coverImageId: album.cover_image_id,
        coverThumbnailUrl: album.cover_image_id ? `/api/v1/images/${album.cover_image_id}/thumbnail` : null,
        visibility: album.visibility,
        shareSlug: album.share_slug,
        createdAt: album.created_at,
        images: imagesRes.rows.map((img) => ({
          id: img.id,
          filename: img.filename,
          mimeType: img.mime_type,
          extension: img.extension,
          sizeBytes: Number(img.size_bytes ?? 0),
          width: img.width,
          height: img.height,
          visibility: img.visibility,
          originalUrl: `/api/v1/images/${img.id}/file`,
          thumbnailUrl: `/api/v1/images/${img.id}/thumbnail`,
        })),
      });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể tải chi tiết album.');
    }
  });

  router.patch('/albums/:id', requireScope('albums:write'), async (request, response) => {
    const { id } = request.params;
    if (!uuid.safeParse(id).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã album không hợp lệ.');
    const parsed = albumPatchSchema.safeParse(request.body);
    if (!parsed.success) return zodValidationError(response, parsed.error);
    try {
      const existing = await database.query('SELECT * FROM albums WHERE id = $1 AND deleted_at IS NULL', [id]);
      const album = existing.rows[0];
      if (!album || (request.authUser.role !== 'ADMIN' && album.owner_id !== request.authUser.id)) {
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy album.');
      }
      const updates = [];
      const values = [];
      for (const [key, col] of [
        ['title', 'title'],
        ['description', 'description'],
        ['visibility', 'visibility'],
        ['coverImageId', 'cover_image_id'],
      ]) {
        if (parsed.data[key] !== undefined) {
          values.push(parsed.data[key]);
          updates.push(`${col} = $${values.length}`);
        }
      }
      if (!updates.length) return ok(response, album);
      values.push(id);
      const upd = await database.query(
        `UPDATE albums SET ${updates.join(', ')}, updated_at = now() WHERE id = $${values.length} RETURNING *`,
        values,
      );
      return ok(response, upd.rows[0]);
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể cập nhật album.');
    }
  });

  router.delete('/albums/:id', requireScope('albums:write'), async (request, response) => {
    const { id } = request.params;
    if (!uuid.safeParse(id).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã album không hợp lệ.');
    try {
      const existing = await database.query('SELECT * FROM albums WHERE id = $1 AND deleted_at IS NULL', [id]);
      const album = existing.rows[0];
      if (!album || (request.authUser.role !== 'ADMIN' && album.owner_id !== request.authUser.id)) {
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy album.');
      }
      await database.query('UPDATE albums SET deleted_at = now(), updated_at = now() WHERE id = $1', [id]);
      return ok(response, { id, deleted: true });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể xóa album.');
    }
  });

  router.post('/albums/:id/images', requireScope('albums:write'), async (request, response) => {
    const { id } = request.params;
    if (!uuid.safeParse(id).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã album không hợp lệ.');
    const parsed = albumImagesSchema.safeParse(request.body);
    if (!parsed.success) return zodValidationError(response, parsed.error);
    try {
      const existing = await database.query('SELECT * FROM albums WHERE id = $1 AND deleted_at IS NULL', [id]);
      const album = existing.rows[0];
      if (!album || (request.authUser.role !== 'ADMIN' && album.owner_id !== request.authUser.id)) {
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy album.');
      }
      for (const imageId of parsed.data.imageIds) {
        await database.query(
          'INSERT INTO album_images (album_id, image_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
          [id, imageId],
        );
      }
      if (!album.cover_image_id && parsed.data.imageIds[0]) {
        await database.query(
          'UPDATE albums SET cover_image_id = $1, updated_at = now() WHERE id = $2 AND cover_image_id IS NULL',
          [parsed.data.imageIds[0], id],
        );
      }
      return ok(response, { albumId: id, addedCount: parsed.data.imageIds.length });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể thêm ảnh vào album.');
    }
  });

  router.delete('/albums/:id/images', requireScope('albums:write'), async (request, response) => {
    const { id } = request.params;
    if (!uuid.safeParse(id).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã album không hợp lệ.');
    const parsed = albumImagesSchema.safeParse(request.body);
    if (!parsed.success) return zodValidationError(response, parsed.error);
    try {
      const existing = await database.query('SELECT * FROM albums WHERE id = $1 AND deleted_at IS NULL', [id]);
      const album = existing.rows[0];
      if (!album || (request.authUser.role !== 'ADMIN' && album.owner_id !== request.authUser.id)) {
        return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy album.');
      }
      await database.query(
        'DELETE FROM album_images WHERE album_id = $1 AND image_id = ANY($2::uuid[])',
        [id, parsed.data.imageIds],
      );
      return ok(response, { albumId: id, removedCount: parsed.data.imageIds.length });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể gỡ ảnh khỏi album.');
    }
  });

  // ---------------- TAGS ----------------
  router.get('/tags', requireScope('images:read'), async (_request, response) => {
    try {
      const res = await database.query(
        `SELECT t.*,
                (SELECT COUNT(*)::int FROM image_tags it JOIN images i ON i.id = it.image_id WHERE it.tag_id = t.id AND i.deleted_at IS NULL) AS image_count
         FROM tags t
         ORDER BY lower(t.name) ASC`,
      );
      return ok(response, res.rows.map((t) => ({
        id: t.id,
        name: t.name,
        slug: t.slug,
        color: t.color ?? '#FF5E36',
        imageCount: Number(t.image_count ?? 0),
        createdAt: t.created_at,
      })));
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể tải danh sách tag.');
    }
  });

  router.post('/tags', requireScope('images:write'), async (request, response) => {
    const parsed = tagCreateSchema.safeParse(request.body);
    if (!parsed.success) return zodValidationError(response, parsed.error);
    const { name, color = '#FF5E36' } = parsed.data;
    const slug = slugify(name, 'tag');
    try {
      const res = await database.query(
        `INSERT INTO tags (id, name, slug, color)
         VALUES ($1, $2, $3, $4)
         RETURNING *`,
        [randomUUID(), name, slug, color],
      );
      return ok(response, { ...res.rows[0], imageCount: 0 }, { status: 201 });
    } catch (err) {
      if (err.code === '23505') {
        return fail(response, 409, 'DUPLICATE_TAG', 'Tag đã tồn tại.');
      }
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể tạo tag.');
    }
  });

  router.delete('/tags/:id', requireScope('images:delete'), async (request, response) => {
    const { id } = request.params;
    if (!uuid.safeParse(id).success) return fail(response, 422, 'VALIDATION_ERROR', 'Mã tag không hợp lệ.');
    try {
      const res = await database.query('DELETE FROM tags WHERE id = $1 RETURNING id', [id]);
      if (!res.rows.length) return fail(response, 404, 'NOT_FOUND', 'Không tìm thấy tag.');
      return ok(response, { id, deleted: true });
    } catch {
      return fail(response, 500, 'INTERNAL_SERVER_ERROR', 'Không thể xóa tag.');
    }
  });

  return router;
}
