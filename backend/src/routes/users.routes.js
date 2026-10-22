import bcrypt from 'bcryptjs';
import { Router } from 'express';
import jwt from 'jsonwebtoken';
import { z } from 'zod';

const audience = 'meta-gym-clients';
const issuer = 'meta-gym-api';
const passwordSchema = z.string().min(8).refine(
  (value) => Buffer.byteLength(value, 'utf8') <= 72 &&
    /[a-z]/.test(value) && /[A-Z]/.test(value) && /[0-9]/.test(value),
  'Mật khẩu phải dài 8–72 byte và có chữ hoa, chữ thường, chữ số',
);
const commonSchema = {
  fullName: z.string().trim().min(2).max(120).optional(),
  phone: z.string().trim().max(20).nullable().optional(),
};
const memberSchema = z.strictObject({
  ...commonSchema,
  dateOfBirth: z.iso.date().nullable().optional(),
  gender: z.enum(['MALE', 'FEMALE', 'OTHER', 'PREFER_NOT_TO_SAY']).nullable().optional(),
  heightCm: z.number().positive().max(300).nullable().optional(),
  fitnessGoal: z.string().nullable().optional(),
  experienceLevel: z.enum(['BEGINNER', 'INTERMEDIATE', 'ADVANCED']).nullable().optional(),
  activityLevel: z.enum(['LOW', 'MODERATE', 'HIGH']).nullable().optional(),
  healthNotes: z.string().nullable().optional(),
  injuryNotes: z.string().nullable().optional(),
  dietaryPreferences: z.string().nullable().optional(),
});
const coachSchema = z.strictObject({
  ...commonSchema,
  biography: z.string().nullable().optional(),
  specialties: z.array(z.string().trim().min(1)).max(20).optional(),
  qualifications: z.string().nullable().optional(),
  experienceYears: z.number().int().min(0).max(32767).optional(),
  availabilityNote: z.string().nullable().optional(),
});
const adminSchema = z.strictObject(commonSchema);
const changePasswordSchema = z.strictObject({
  currentPassword: z.string().min(1),
  newPassword: passwordSchema,
});
const profileColumns = {
  MEMBER: {
    dateOfBirth: 'date_of_birth', gender: 'gender', heightCm: 'height_cm',
    fitnessGoal: 'fitness_goal', experienceLevel: 'experience_level',
    activityLevel: 'activity_level', healthNotes: 'health_notes',
    injuryNotes: 'injury_notes', dietaryPreferences: 'dietary_preferences',
  },
  COACH: {
    biography: 'biography', specialties: 'specialties',
    qualifications: 'qualifications', experienceYears: 'experience_years',
    availabilityNote: 'availability_note',
  },
};

function error(response, status, code, message, details = {}) {
  return response.status(status).json({ error: { code, details, message } });
}

function validationError(response, issue) {
  const fields = {};
  for (const item of issue.issues) {
    if (item.code === 'unrecognized_keys') {
      for (const key of item.keys) fields[key] = ['Trường này không được phép'];
    } else if (typeof item.path[0] === 'string') {
      const key = item.path[0];
      (fields[key] ??= []).push(item.message);
    }
  }
  return error(response, 422, 'VALIDATION_ERROR', 'Dữ liệu không hợp lệ', { fields });
}

function toPublicUser(row) {
  const result = {
    id: row.id, email: row.email, fullName: row.full_name,
    phone: row.phone, role: row.role, status: row.status,
  };
  if (row.role === 'MEMBER' || row.role === 'COACH') {
    result.profile = {};
    for (const [key, column] of Object.entries(profileColumns[row.role])) {
      result.profile[key] = row[column] ?? null;
    }
  }
  return result;
}

async function loadUser(database, id) {
  const result = await database.query(
    `SELECT u.id, u.email::text, u.full_name, u.phone, u.role, u.status,
            u.session_version, m.date_of_birth::text, m.gender, m.height_cm::float8,
            m.fitness_goal, m.experience_level, m.activity_level,
            m.health_notes, m.injury_notes, m.dietary_preferences,
            c.biography, c.specialties, c.qualifications,
            c.experience_years, c.availability_note
     FROM users u
     LEFT JOIN member_profiles m ON m.user_id = u.id AND u.role = 'MEMBER'
     LEFT JOIN coach_profiles c ON c.user_id = u.id AND u.role = 'COACH'
     WHERE u.id = $1`,
    [id],
  );
  return result.rows[0];
}

export function createAuthentication({ database, jwtSecret }) {
  return async (request, response, next) => {
    const header = request.get('authorization');
    if (!header || !/^Bearer \S+$/.test(header)) {
      return error(response, 401, 'UNAUTHORIZED', 'Cần đăng nhập');
    }
    let claims;
    try {
      claims = jwt.verify(header.slice(7), jwtSecret, {
        algorithms: ['HS256'], audience, issuer,
      });
    } catch {
      return error(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập không hợp lệ');
    }
    if (typeof claims !== 'object' || !z.uuid().safeParse(claims.sub).success ||
        !['MEMBER', 'COACH', 'ADMIN'].includes(claims.role) ||
        !Number.isSafeInteger(claims.sessionVersion) || claims.sessionVersion < 0) {
      return error(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập không hợp lệ');
    }
    try {
      const user = await loadUser(database, claims.sub);
      if (!user || user.status !== 'ACTIVE' || user.role !== claims.role ||
          user.session_version !== claims.sessionVersion) {
        return error(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }
      request.authUser = user;
      next();
    } catch {
      return error(response, 500, 'INTERNAL_SERVER_ERROR', 'Đã xảy ra lỗi, vui lòng thử lại sau');
    }
  };
}

export function createUsersRouter({ database, jwtSecret }) {
  const router = Router();
  router.use(createAuthentication({ database, jwtSecret }));

  router.get('/me', (request, response) => response.json({ data: toPublicUser(request.authUser) }));

  router.patch('/me', async (request, response) => {
    const role = request.authUser.role;
    const schema = role === 'MEMBER' ? memberSchema : role === 'COACH' ? coachSchema : adminSchema;
    const parsed = schema.safeParse(request.body);
    if (!parsed.success) return validationError(response, parsed.error);
    const fields = parsed.data;
    if (Object.keys(fields).length === 0) {
      return error(response, 422, 'VALIDATION_ERROR', 'Cần ít nhất một trường để cập nhật');
    }
    const client = await database.connect().catch(() => null);
    if (!client) return error(response, 500, 'INTERNAL_SERVER_ERROR', 'Đã xảy ra lỗi, vui lòng thử lại sau');
    try {
      await client.query('BEGIN');
      const current = await client.query(
        `SELECT role FROM users WHERE id = $1 AND status = 'ACTIVE'
         AND session_version = $2 FOR UPDATE`,
        [request.authUser.id, request.authUser.session_version],
      );
      if (current.rows.length === 0 || current.rows[0].role !== role) {
        await client.query('ROLLBACK');
        return error(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }
      const userFields = Object.entries({ fullName: 'full_name', phone: 'phone' })
        .filter(([key]) => key in fields);
      if (userFields.length) {
        await client.query(
          `UPDATE users SET ${userFields.map(([, column], index) => `${column} = $${index + 1}`).join(', ')} WHERE id = $${userFields.length + 1}`,
          [...userFields.map(([key]) => fields[key]), request.authUser.id],
        );
      }
      const table = role === 'MEMBER' ? 'member_profiles' : 'coach_profiles';
      const profileFields = Object.entries(profileColumns[role] ?? {})
        .filter(([key]) => key in fields);
      if (profileFields.length) {
        const updated = await client.query(
          `UPDATE ${table} SET ${profileFields.map(([, column], index) => `${column} = $${index + 1}`).join(', ')} WHERE user_id = $${profileFields.length + 1} RETURNING user_id`,
          [...profileFields.map(([key]) => fields[key]), request.authUser.id],
        );
        if (updated.rows.length !== 1) throw new Error('Profile missing');
      }
      const user = await loadUser(client, request.authUser.id);
      await client.query('COMMIT');
      return response.json({ data: toPublicUser(user) });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return error(response, 500, 'INTERNAL_SERVER_ERROR', 'Đã xảy ra lỗi, vui lòng thử lại sau');
    } finally {
      client.release();
    }
  });

  router.patch('/me/password', async (request, response) => {
    const parsed = changePasswordSchema.safeParse(request.body);
    if (!parsed.success) return validationError(response, parsed.error);
    const client = await database.connect().catch(() => null);
    if (!client) return error(response, 500, 'INTERNAL_SERVER_ERROR', 'Đã xảy ra lỗi, vui lòng thử lại sau');
    try {
      await client.query('BEGIN');
      const current = await client.query(
        `SELECT password_hash FROM users WHERE id = $1 AND status = 'ACTIVE'
         AND session_version = $2 FOR UPDATE`,
        [request.authUser.id, request.authUser.session_version],
      );
      if (current.rows.length === 0) {
        await client.query('ROLLBACK');
        return error(response, 401, 'UNAUTHORIZED', 'Phiên đăng nhập đã hết hiệu lực');
      }
      if (!await bcrypt.compare(parsed.data.currentPassword, current.rows[0].password_hash)) {
        await client.query('ROLLBACK');
        return error(response, 401, 'INVALID_CREDENTIALS', 'Mật khẩu hiện tại không đúng');
      }
      const hash = await bcrypt.hash(parsed.data.newPassword, 12);
      await client.query(
        'UPDATE users SET password_hash = $1, session_version = session_version + 1 WHERE id = $2',
        [hash, request.authUser.id],
      );
      await client.query('COMMIT');
      return response.json({ data: { changed: true } });
    } catch {
      await client.query('ROLLBACK').catch(() => {});
      return error(response, 500, 'INTERNAL_SERVER_ERROR', 'Đã xảy ra lỗi, vui lòng thử lại sau');
    } finally {
      client.release();
    }
  });

  return router;
}
