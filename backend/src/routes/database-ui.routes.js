import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import express from 'express';
import jwt from 'jsonwebtoken';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const COOKIE_NAME = 'mg_db_ui_token';
const TOKEN_SCOPE = 'database-ui';

function quoteIdent(identifier) {
  return `"${String(identifier).replace(/"/g, '""')}"`;
}

function timingSafeTextEqual(left, right) {
  const leftHash = crypto.createHash('sha256').update(String(left ?? ''), 'utf8').digest();
  const rightHash = crypto.createHash('sha256').update(String(right ?? ''), 'utf8').digest();
  return crypto.timingSafeEqual(leftHash, rightHash);
}

function parseCookies(cookieHeader) {
  const cookies = {};
  if (!cookieHeader || typeof cookieHeader !== 'string') {
    return cookies;
  }
  for (const part of cookieHeader.split(';')) {
    const idx = part.indexOf('=');
    if (idx === -1) continue;
    const key = part.slice(0, idx).trim();
    const val = part.slice(idx + 1).trim();
    if (key) {
      try {
        cookies[key] = decodeURIComponent(val);
      } catch {
        cookies[key] = val;
      }
    }
  }
  return cookies;
}

function extractToken(request) {
  const authHeader = request.headers.authorization;
  if (typeof authHeader === 'string' && authHeader.startsWith('Bearer ')) {
    const token = authHeader.slice(7).trim();
    if (token) return token;
  }
  const cookies = parseCookies(request.headers.cookie);
  return cookies[COOKIE_NAME] || null;
}

function loadUiHtml() {
  const htmlPath = path.resolve(__dirname, 'database-ui.html');
  return fs.readFileSync(htmlPath, 'utf8');
}

async function listPublicTables(database) {
  const result = await database.query(
    `SELECT
       t.table_name AS name,
       COALESCE(s.n_live_tup, 0)::bigint AS row_estimate
     FROM information_schema.tables t
     LEFT JOIN pg_stat_user_tables s
       ON s.schemaname = t.table_schema AND s.relname = t.table_name
     WHERE t.table_schema = 'public'
       AND t.table_type = 'BASE TABLE'
     ORDER BY t.table_name ASC`,
  );

  return result.rows.map((row) => ({
    name: row.name,
    rowEstimate: Number(row.row_estimate ?? 0),
  }));
}

async function getTableMetadata(database, tableName) {
  const tableCheck = await database.query(
    `SELECT table_name
     FROM information_schema.tables
     WHERE table_schema = 'public'
       AND table_type = 'BASE TABLE'
       AND table_name = $1`,
    [tableName],
  );

  if (tableCheck.rows.length === 0) {
    return null;
  }

  const [columnsRes, pkRes, fkRes, enumsRes] = await Promise.all([
    database.query(
      `SELECT
         column_name,
         data_type,
         udt_name,
         is_nullable,
         column_default,
         character_maximum_length,
         is_identity,
         ordinal_position
       FROM information_schema.columns
       WHERE table_schema = 'public' AND table_name = $1
       ORDER BY ordinal_position ASC`,
      [tableName],
    ),
    database.query(
      `SELECT kcu.column_name
       FROM information_schema.table_constraints tc
       JOIN information_schema.key_column_usage kcu
         ON tc.constraint_name = kcu.constraint_name
        AND tc.table_schema = kcu.table_schema
       WHERE tc.table_schema = 'public'
         AND tc.table_name = $1
         AND tc.constraint_type = 'PRIMARY KEY'
       ORDER BY kcu.ordinal_position ASC`,
      [tableName],
    ),
    database.query(
      `SELECT
         kcu.column_name,
         ccu.table_name AS foreign_table,
         ccu.column_name AS foreign_column
       FROM information_schema.table_constraints tc
       JOIN information_schema.key_column_usage kcu
         ON tc.constraint_name = kcu.constraint_name
        AND tc.table_schema = kcu.table_schema
       JOIN information_schema.constraint_column_usage ccu
         ON ccu.constraint_name = tc.constraint_name
        AND ccu.table_schema = tc.table_schema
       WHERE tc.table_schema = 'public'
         AND tc.table_name = $1
         AND tc.constraint_type = 'FOREIGN KEY'`,
      [tableName],
    ),
    database.query(
      `SELECT t.typname AS enum_name, e.enumlabel AS enum_value
       FROM pg_type t
       JOIN pg_enum e ON t.oid = e.enumtypid
       JOIN pg_namespace n ON n.oid = t.typnamespace
       WHERE n.nspname = 'public'
       ORDER BY t.typname ASC, e.enumsortorder ASC`,
    ),
  ]);

  const primaryKeys = pkRes.rows.map((row) => row.column_name);
  const fkMap = new Map();
  for (const fk of fkRes.rows) {
    fkMap.set(fk.column_name, {
      table: fk.foreign_table,
      column: fk.foreign_column,
    });
  }

  const enums = {};
  for (const row of enumsRes.rows) {
    if (!enums[row.enum_name]) enums[row.enum_name] = [];
    enums[row.enum_name].push(row.enum_value);
  }

  const columns = columnsRes.rows.map((col) => ({
    name: col.column_name,
    dataType: col.data_type,
    udtName: col.udt_name,
    nullable: col.is_nullable === 'YES',
    defaultValue: col.column_default,
    maxLength: col.character_maximum_length,
    isIdentity: col.is_identity === 'YES',
    isPrimaryKey: primaryKeys.includes(col.column_name),
    foreignKey: fkMap.get(col.column_name) ?? null,
    enumValues: col.data_type === 'USER-DEFINED' ? (enums[col.udt_name] ?? null) : null,
  }));

  return {
    table: tableName,
    columns,
    primaryKeys,
    columnMap: new Map(columns.map((c) => [c.name, c])),
  };
}

function coerceColumnValue(column, rawValue) {
  if (rawValue === null || rawValue === undefined) {
    return null;
  }

  const dt = column.dataType;
  if (dt === 'json' || dt === 'jsonb') {
    if (typeof rawValue === 'string') {
      const trimmed = rawValue.trim();
      if (trimmed === '') return null;
      JSON.parse(trimmed);
      return trimmed;
    }
    return JSON.stringify(rawValue);
  }

  if (dt === 'boolean') {
    if (typeof rawValue === 'boolean') return rawValue;
    if (rawValue === 'true' || rawValue === '1') return true;
    if (rawValue === 'false' || rawValue === '0') return false;
  }

  return rawValue;
}

function sendDatabaseError(response, error) {
  const status = error?.code && typeof error.code === 'string' && error.code.startsWith('2') ? 400 : 500;
  return response.status(status).json({
    error: {
      code: error?.code || 'DATABASE_ERROR',
      message: error?.message || 'Thao tác cơ sở dữ liệu thất bại',
      detail: error?.detail || null,
    },
  });
}

export function createDatabaseUiRouter({
  database,
  jwtSecret,
  username = process.env.DB_UI_USERNAME || 'admin',
  password = process.env.DB_UI_PASSWORD || 'admin',
}) {
  const router = express.Router();
  const uiHtml = loadUiHtml();

  router.use((_request, response, next) => {
    response.removeHeader('Content-Security-Policy');
    next();
  });

  function requireAuth(request, response, next) {
    const token = extractToken(request);
    if (!token) {
      return response.status(401).json({
        error: {
          code: 'UNAUTHORIZED',
          message: 'Vui lòng đăng nhập để sử dụng Database UI',
        },
      });
    }

    try {
      const payload = jwt.verify(token, jwtSecret);
      if (payload?.scope !== TOKEN_SCOPE) {
        return response.status(401).json({
          error: {
            code: 'INVALID_TOKEN',
            message: 'Phiên đăng nhập không hợp lệ',
          },
        });
      }
      request.dbUiUser = payload.username;
      return next();
    } catch {
      return response.status(401).json({
        error: {
          code: 'INVALID_TOKEN',
          message: 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại',
        },
      });
    }
  }

  router.get('/', (_request, response) => {
    response.type('html').send(uiHtml);
  });

  router.post('/api/login', (request, response) => {
    const inputUsername = request.body?.username;
    const inputPassword = request.body?.password;

    if (
      typeof inputUsername !== 'string' ||
      typeof inputPassword !== 'string' ||
      !timingSafeTextEqual(inputUsername, username) ||
      !timingSafeTextEqual(inputPassword, password)
    ) {
      return response.status(401).json({
        error: {
          code: 'INVALID_CREDENTIALS',
          message: 'Sai tài khoản hoặc mật khẩu',
        },
      });
    }

    const token = jwt.sign(
      { scope: TOKEN_SCOPE, username },
      jwtSecret,
      { expiresIn: '12h' },
    );

    response.setHeader(
      'Set-Cookie',
      `${COOKIE_NAME}=${encodeURIComponent(token)}; HttpOnly; SameSite=Lax; Path=/database; Max-Age=43200`,
    );

    return response.status(200).json({
      data: {
        token,
        username,
      },
    });
  });

  router.post('/api/logout', (_request, response) => {
    response.setHeader(
      'Set-Cookie',
      `${COOKIE_NAME}=; HttpOnly; SameSite=Lax; Path=/database; Max-Age=0`,
    );
    return response.status(200).json({ data: { loggedOut: true } });
  });

  router.get('/api/me', requireAuth, (request, response) => {
    return response.status(200).json({
      data: {
        username: request.dbUiUser,
      },
    });
  });

  router.get('/api/tables', requireAuth, async (_request, response) => {
    try {
      const tables = await listPublicTables(database);
      return response.status(200).json({ data: { tables } });
    } catch (error) {
      return sendDatabaseError(response, error);
    }
  });

  router.get('/api/tables/:table/schema', requireAuth, async (request, response) => {
    try {
      const meta = await getTableMetadata(database, request.params.table);
      if (!meta) {
        return response.status(404).json({
          error: { code: 'TABLE_NOT_FOUND', message: 'Không tìm thấy bảng dữ liệu' },
        });
      }
      return response.status(200).json({
        data: {
          table: meta.table,
          columns: meta.columns,
          primaryKeys: meta.primaryKeys,
        },
      });
    } catch (error) {
      return sendDatabaseError(response, error);
    }
  });

  router.get('/api/tables/:table/rows', requireAuth, async (request, response) => {
    try {
      const meta = await getTableMetadata(database, request.params.table);
      if (!meta) {
        return response.status(404).json({
          error: { code: 'TABLE_NOT_FOUND', message: 'Không tìm thấy bảng dữ liệu' },
        });
      }

      const page = Math.max(1, Number.parseInt(String(request.query.page ?? '1'), 10) || 1);
      const pageSize = Math.min(
        100,
        Math.max(1, Number.parseInt(String(request.query.pageSize ?? '25'), 10) || 25),
      );
      const search = typeof request.query.search === 'string' ? request.query.search.trim() : '';
      const requestedSortBy = typeof request.query.sortBy === 'string' ? request.query.sortBy : '';
      const sortDir = String(request.query.sortDir ?? 'asc').toLowerCase() === 'desc' ? 'DESC' : 'ASC';

      const sortColumn = meta.columnMap.has(requestedSortBy)
        ? requestedSortBy
        : (meta.primaryKeys[0] ?? meta.columns[0]?.name ?? null);

      const tableIdent = `"public".${quoteIdent(meta.table)}`;
      const params = [];
      let whereSql = '';

      if (search && meta.columns.length > 0) {
        params.push(`%${search}%`);
        const clauses = meta.columns.map(
          (col) => `CAST(${quoteIdent(col.name)} AS TEXT) ILIKE $1`,
        );
        whereSql = `WHERE ${clauses.join(' OR ')}`;
      }

      const countRes = await database.query(
        `SELECT COUNT(*)::bigint AS total FROM ${tableIdent} ${whereSql}`,
        params,
      );
      const total = Number(countRes.rows[0]?.total ?? 0);

      const orderSql = sortColumn ? `ORDER BY ${quoteIdent(sortColumn)} ${sortDir}` : '';
      const offset = (page - 1) * pageSize;
      const limitParamIndex = params.length + 1;
      const offsetParamIndex = params.length + 2;

      const rowsRes = await database.query(
        `SELECT * FROM ${tableIdent} ${whereSql} ${orderSql} LIMIT $${limitParamIndex} OFFSET $${offsetParamIndex}`,
        [...params, pageSize, offset],
      );

      return response.status(200).json({
        data: {
          table: meta.table,
          columns: meta.columns,
          primaryKeys: meta.primaryKeys,
          rows: rowsRes.rows,
          pagination: {
            page,
            pageSize,
            total,
            totalPages: Math.max(1, Math.ceil(total / pageSize)),
          },
        },
      });
    } catch (error) {
      return sendDatabaseError(response, error);
    }
  });

  router.post('/api/tables/:table/rows', requireAuth, async (request, response) => {
    try {
      const meta = await getTableMetadata(database, request.params.table);
      if (!meta) {
        return response.status(404).json({
          error: { code: 'TABLE_NOT_FOUND', message: 'Không tìm thấy bảng dữ liệu' },
        });
      }

      const values = request.body?.values;
      if (!values || typeof values !== 'object' || Array.isArray(values)) {
        return response.status(400).json({
          error: { code: 'INVALID_BODY', message: 'Thiếu object values để thêm bản ghi' },
        });
      }

      const entries = Object.entries(values);
      const colIdents = [];
      const placeholders = [];
      const params = [];

      for (const [colName, rawVal] of entries) {
        const col = meta.columnMap.get(colName);
        if (!col) {
          return response.status(400).json({
            error: { code: 'INVALID_COLUMN', message: `Cột không tồn tại: ${colName}` },
          });
        }
        let coerced;
        try {
          coerced = coerceColumnValue(col, rawVal);
        } catch {
          return response.status(400).json({
            error: { code: 'INVALID_VALUE', message: `Giá trị JSON không hợp lệ ở cột ${colName}` },
          });
        }
        colIdents.push(quoteIdent(col.name));
        params.push(coerced);
        placeholders.push(`$${params.length}`);
      }

      const tableIdent = `"public".${quoteIdent(meta.table)}`;
      const sql = colIdents.length > 0
        ? `INSERT INTO ${tableIdent} (${colIdents.join(', ')}) VALUES (${placeholders.join(', ')}) RETURNING *`
        : `INSERT INTO ${tableIdent} DEFAULT VALUES RETURNING *`;

      const result = await database.query(sql, params);
      return response.status(201).json({
        data: { row: result.rows[0] ?? null },
      });
    } catch (error) {
      return sendDatabaseError(response, error);
    }
  });

  router.patch('/api/tables/:table/rows', requireAuth, async (request, response) => {
    try {
      const meta = await getTableMetadata(database, request.params.table);
      if (!meta) {
        return response.status(404).json({
          error: { code: 'TABLE_NOT_FOUND', message: 'Không tìm thấy bảng dữ liệu' },
        });
      }

      if (meta.primaryKeys.length === 0) {
        return response.status(400).json({
          error: { code: 'NO_PRIMARY_KEY', message: 'Bảng không có khóa chính nên không hỗ trợ sửa dòng' },
        });
      }

      const primaryKey = request.body?.primaryKey;
      const values = request.body?.values;

      if (!primaryKey || typeof primaryKey !== 'object' || Array.isArray(primaryKey)) {
        return response.status(400).json({
          error: { code: 'INVALID_PRIMARY_KEY', message: 'Thiếu thông tin khóa chính (primaryKey)' },
        });
      }
      if (!values || typeof values !== 'object' || Array.isArray(values)) {
        return response.status(400).json({
          error: { code: 'INVALID_BODY', message: 'Thiếu dữ liệu cập nhật (values)' },
        });
      }

      const setClauses = [];
      const params = [];

      for (const [colName, rawVal] of Object.entries(values)) {
        const col = meta.columnMap.get(colName);
        if (!col) {
          return response.status(400).json({
            error: { code: 'INVALID_COLUMN', message: `Cột không tồn tại: ${colName}` },
          });
        }
        let coerced;
        try {
          coerced = coerceColumnValue(col, rawVal);
        } catch {
          return response.status(400).json({
            error: { code: 'INVALID_VALUE', message: `Giá trị JSON không hợp lệ ở cột ${colName}` },
          });
        }
        params.push(coerced);
        setClauses.push(`${quoteIdent(col.name)} = $${params.length}`);
      }

      if (setClauses.length === 0) {
        return response.status(400).json({
          error: { code: 'EMPTY_UPDATE', message: 'Không có trường nào để cập nhật' },
        });
      }

      const whereClauses = [];
      for (const pkCol of meta.primaryKeys) {
        if (!(pkCol in primaryKey) || primaryKey[pkCol] === undefined || primaryKey[pkCol] === null) {
          return response.status(400).json({
            error: { code: 'MISSING_PRIMARY_KEY', message: `Thiếu giá trị khóa chính: ${pkCol}` },
          });
        }
        params.push(primaryKey[pkCol]);
        whereClauses.push(`${quoteIdent(pkCol)} = $${params.length}`);
      }

      const tableIdent = `"public".${quoteIdent(meta.table)}`;
      const result = await database.query(
        `UPDATE ${tableIdent} SET ${setClauses.join(', ')} WHERE ${whereClauses.join(' AND ')} RETURNING *`,
        params,
      );

      if (result.rows.length === 0) {
        return response.status(404).json({
          error: { code: 'ROW_NOT_FOUND', message: 'Không tìm thấy dòng dữ liệu cần sửa' },
        });
      }

      return response.status(200).json({
        data: { row: result.rows[0] },
      });
    } catch (error) {
      return sendDatabaseError(response, error);
    }
  });

  router.delete('/api/tables/:table/rows', requireAuth, async (request, response) => {
    try {
      const meta = await getTableMetadata(database, request.params.table);
      if (!meta) {
        return response.status(404).json({
          error: { code: 'TABLE_NOT_FOUND', message: 'Không tìm thấy bảng dữ liệu' },
        });
      }

      if (meta.primaryKeys.length === 0) {
        return response.status(400).json({
          error: { code: 'NO_PRIMARY_KEY', message: 'Bảng không có khóa chính nên không hỗ trợ xóa dòng' },
        });
      }

      const primaryKey = request.body?.primaryKey;
      if (!primaryKey || typeof primaryKey !== 'object' || Array.isArray(primaryKey)) {
        return response.status(400).json({
          error: { code: 'INVALID_PRIMARY_KEY', message: 'Thiếu thông tin khóa chính (primaryKey)' },
        });
      }

      const whereClauses = [];
      const params = [];
      for (const pkCol of meta.primaryKeys) {
        if (!(pkCol in primaryKey) || primaryKey[pkCol] === undefined || primaryKey[pkCol] === null) {
          return response.status(400).json({
            error: { code: 'MISSING_PRIMARY_KEY', message: `Thiếu giá trị khóa chính: ${pkCol}` },
          });
        }
        params.push(primaryKey[pkCol]);
        whereClauses.push(`${quoteIdent(pkCol)} = $${params.length}`);
      }

      const tableIdent = `"public".${quoteIdent(meta.table)}`;
      const result = await database.query(
        `DELETE FROM ${tableIdent} WHERE ${whereClauses.join(' AND ')} RETURNING *`,
        params,
      );

      if (result.rows.length === 0) {
        return response.status(404).json({
          error: { code: 'ROW_NOT_FOUND', message: 'Không tìm thấy dòng dữ liệu cần xóa' },
        });
      }

      return response.status(200).json({
        data: { deleted: result.rows[0] },
      });
    } catch (error) {
      return sendDatabaseError(response, error);
    }
  });

  return router;
}
