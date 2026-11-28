import { randomUUID } from 'node:crypto';

import bcrypt from 'bcryptjs';
import { Router } from 'express';
import jwt from 'jsonwebtoken';
import { z } from 'zod';
import { resolveUserPermissions } from '../users/staff-positions.js';

const PASSWORD_HASH_ROUNDS = 12;
const JWT_EXPIRES_IN_SECONDS = 60 * 60;
const JWT_AUDIENCE = 'meta-gym-clients';
const JWT_ISSUER = 'meta-gym-api';
const DUMMY_PASSWORD_HASH =
  '$2b$12$erQ1llirs4rV5UXCV2v70ecMyqHgZALJjeHT09iKkOArmNexxGYVO';

const registrationSchema = z.strictObject({
  email: z.string().trim().toLowerCase().email('Email không hợp lệ'),
  fullName: z
    .string()
    .trim()
    .min(2, 'Họ tên phải có ít nhất 2 ký tự')
    .max(120, 'Họ tên không được vượt quá 120 ký tự'),
  password: z
    .string()
    .min(8, 'Mật khẩu phải có ít nhất 8 ký tự')
    .refine(
      (password) => Buffer.byteLength(password, 'utf8') <= 72,
      'Mật khẩu không được vượt quá 72 byte',
    )
    .regex(/[a-z]/, 'Mật khẩu phải có chữ thường')
    .regex(/[A-Z]/, 'Mật khẩu phải có chữ hoa')
    .regex(/[0-9]/, 'Mật khẩu phải có chữ số'),
});

const sessionSchema = z.strictObject({
  email: z.string().trim().toLowerCase().email('Email không hợp lệ'),
  password: z
    .string()
    .min(1, 'Mật khẩu không được để trống')
    .refine(
      (password) => Buffer.byteLength(password, 'utf8') <= 72,
      'Mật khẩu không được vượt quá 72 byte',
    ),
});

function getValidationDetails(error) {
  const fields = {};

  for (const issue of error.issues) {
    if (issue.code === 'unrecognized_keys') {
      for (const key of issue.keys) {
        fields[key] = [...(fields[key] ?? []), 'Trường này không được phép'];
      }
      continue;
    }

    const field = issue.path[0];
    if (typeof field === 'string') {
      fields[field] = [...(fields[field] ?? []), issue.message];
    }
  }

  return { fields };
}

function sendInternalServerError(response) {
  return response.status(500).json({
    error: {
      code: 'INTERNAL_SERVER_ERROR',
      details: {},
      message: 'Đã xảy ra lỗi, vui lòng thử lại sau',
    },
  });
}

function sendTooManyRequests(response) {
  return response.status(429).json({
    error: {
      code: 'TOO_MANY_REQUESTS',
      details: {},
      message: 'Quá nhiều lần đăng nhập thất bại, vui lòng thử lại sau',
    },
  });
}

export function createAuthRouter({ database, jwtSecret, loginRateLimiter }) {
  const authRouter = Router();

  authRouter.post('/registrations', async (request, response) => {
    const validation = registrationSchema.safeParse(request.body);

    if (!validation.success) {
      return response.status(422).json({
        error: {
          code: 'VALIDATION_ERROR',
          details: getValidationDetails(validation.error),
          message: 'Dữ liệu đăng ký không hợp lệ',
        },
      });
    }

    const { email, fullName, password } = validation.data;

    try {
      const passwordHash = await bcrypt.hash(password, PASSWORD_HASH_ROUNDS);
      const result = await database.query(
        `WITH inserted_user AS (
          INSERT INTO users (id, email, password_hash, role, full_name)
          VALUES ($1, $2, $3, 'MEMBER', $4)
          RETURNING id, email, full_name, role, status, created_at
        ), inserted_profile AS (
          INSERT INTO member_profiles (user_id)
          SELECT id FROM inserted_user
        )
        SELECT id, email::text, full_name, role, status, created_at
        FROM inserted_user`,
        [randomUUID(), email, passwordHash, fullName],
      );
      const user = result.rows[0];

      return response.status(201).json({
        data: {
          createdAt: user.created_at,
          email: user.email,
          fullName: user.full_name,
          id: user.id,
          role: user.role,
          status: user.status,
        },
      });
    } catch (error) {
      if (error.code === '23505' && error.constraint === 'users_email_key') {
        return response.status(409).json({
          error: {
            code: 'EMAIL_ALREADY_EXISTS',
            details: {},
            message: 'Email đã được sử dụng',
          },
        });
      }

      return sendInternalServerError(response);
    }
  });

  authRouter.post('/sessions', async (request, response) => {
    const validation = sessionSchema.safeParse(request.body);

    if (!validation.success) {
      return response.status(422).json({
        error: {
          code: 'VALIDATION_ERROR',
          details: getValidationDetails(validation.error),
          message: 'Dữ liệu đăng nhập không hợp lệ',
        },
      });
    }

    const { email, password } = validation.data;
    const rateLimitContext = {
      email,
      ip: request.ip ?? request.socket.remoteAddress ?? 'unknown',
    };

    try {
      return await loginRateLimiter.run(rateLimitContext, async (limit) => {
        if (limit.blocked) {
          return sendTooManyRequests(response);
        }

        const sessionDatabase = limit.database ?? database;
        const result = await sessionDatabase.query(
        `SELECT id, email::text, password_hash, role, full_name, phone, status,
                avatar_media_id, session_version
         FROM users
         WHERE email = $1
         LIMIT 1`,
        [email],
      );
        const user = result.rows[0];
        const passwordMatches = await bcrypt.compare(
          password,
          user?.password_hash ?? DUMMY_PASSWORD_HASH,
        );

        if (!user || !passwordMatches) {
          if (await limit.registerFailure()) {
            return sendTooManyRequests(response);
          }

          return response.status(401).json({
          error: {
            code: 'INVALID_CREDENTIALS',
            details: {},
            message: 'Email hoặc mật khẩu không đúng',
          },
        });
        }

        if (user.status !== 'ACTIVE') {
          return response.status(403).json({
          error: {
            code: 'ACCOUNT_DISABLED',
            details: {},
            message: 'Tài khoản đã bị khóa',
          },
        });
        }

        const updateResult = await sessionDatabase.query(
        `UPDATE users
         SET last_login_at = now()
         WHERE id = $1 AND status = 'ACTIVE' AND session_version = $2
         RETURNING id`,
        [user.id, user.session_version],
      );

        if (updateResult.rows.length === 0) {
          return response.status(403).json({
          error: {
            code: 'ACCOUNT_DISABLED',
            details: {},
            message: 'Tài khoản không còn khả dụng',
          },
        });
        }

        await limit.resetAccount();

        const accessToken = jwt.sign(
        {
          role: user.role,
          sessionVersion: user.session_version,
        },
        jwtSecret,
        {
          algorithm: 'HS256',
          audience: JWT_AUDIENCE,
          expiresIn: JWT_EXPIRES_IN_SECONDS,
          issuer: JWT_ISSUER,
          subject: user.id,
        },
      );

        let staffExtra = null;
        if (user.role === 'STAFF') {
          const spRes = await sessionDatabase.query(
            `SELECT sp.position_code, sp.department, sp.shift_note, r.permissions AS role_permissions
             FROM staff_profiles sp
             LEFT JOIN users u ON u.id = sp.user_id
             LEFT JOIN roles r ON r.id = u.role_id
             WHERE sp.user_id = $1`,
            [user.id],
          ).catch(() => ({ rows: [] }));
          const sp = spRes.rows[0];
          staffExtra = {
            staffPosition: sp?.position_code || 'RECEPTIONIST',
            permissions: resolveUserPermissions({ role: 'STAFF', ...sp }),
            ...(sp?.department ? { department: sp.department } : {}),
            ...(sp?.shift_note ? { shiftNote: sp.shift_note } : {}),
          };
        }

        return response.status(200).json({
        data: {
          accessToken,
          expiresIn: JWT_EXPIRES_IN_SECONDS,
          tokenType: 'Bearer',
          user: {
            email: user.email,
            fullName: user.full_name,
            id: user.id,
            role: user.role,
            status: user.status,
            ...(user.phone ? { phone: user.phone } : {}),
            ...(user.avatar_media_id ? { avatarUrl: `/api/v1/users/${user.id}/avatar` } : {}),
            ...(staffExtra || {}),
          },
        },
        });
      });
    } catch {
      return sendInternalServerError(response);
    }
  });

  return authRouter;
}
