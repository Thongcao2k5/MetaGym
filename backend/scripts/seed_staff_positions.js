import { randomUUID } from 'node:crypto';
import bcrypt from 'bcryptjs';

import { createDatabasePool } from '../src/config/database.js';

const STAFF_SEEDS = [
  {
    email: 'manager@metagym.vn',
    fullName: 'Trần Minh Quân',
    phone: '0903112233',
    positionCode: 'MANAGER',
    roleCode: 'manager',
    department: 'Điều hành phòng tập',
    shiftNote: 'Ca hành chính & điều phối trưởng ca',
  },
  {
    email: 'letan@metagym.vn',
    fullName: 'Nguyễn Thảo Vy',
    phone: '0904223344',
    positionCode: 'RECEPTIONIST',
    roleCode: 'receptionist',
    department: 'Quầy lễ tân & Thu ngân',
    shiftNote: 'Ca sáng 06:00 – 14:00 (Thu ngân & QR Check-in)',
  },
  {
    email: 'kythuat@metagym.vn',
    fullName: 'Lê Hoàng Khang',
    phone: '0905334455',
    positionCode: 'TECHNICIAN',
    roleCode: 'technician',
    department: 'Kỹ thuật thiết bị & Nội dung',
    shiftNote: 'Kiểm tra máy tập, bài tập & cập nhật hình ảnh WebP',
  },
];

async function run() {
  const database = createDatabasePool();
  const passwordHash = await bcrypt.hash('MetaGym123!', 12);
  try {
    let created = 0;
    for (const item of STAFF_SEEDS) {
      const existing = await database.query(`SELECT id FROM users WHERE email = $1 LIMIT 1`, [item.email]);
      if (existing.rows.length > 0) {
        const userId = existing.rows[0].id;
        await database.query(
          `INSERT INTO staff_profiles (user_id, position_code, department, shift_note)
           VALUES ($1, $2, $3, $4)
           ON CONFLICT (user_id) DO UPDATE
             SET position_code = EXCLUDED.position_code,
                 department = EXCLUDED.department,
                 shift_note = EXCLUDED.shift_note`,
          [userId, item.positionCode, item.department, item.shiftNote],
        );
        continue;
      }

      const roleRes = await database.query(`SELECT id FROM roles WHERE code = $1 LIMIT 1`, [item.roleCode]);
      const roleId = roleRes.rows[0]?.id ?? null;
      const userId = randomUUID();

      await database.query(
        `INSERT INTO users (id, email, password_hash, role, full_name, phone, role_id, status)
         VALUES ($1, $2, $3, 'STAFF', $4, $5, $6, 'ACTIVE')`,
        [userId, item.email, passwordHash, item.fullName, item.phone, roleId],
      );
      await database.query(
        `INSERT INTO staff_profiles (user_id, position_code, department, shift_note)
         VALUES ($1, $2, $3, $4)`,
        [userId, item.positionCode, item.department, item.shiftNote],
      );
      created += 1;
    }
    console.log(JSON.stringify({ ok: true, seededStaffAccounts: created, totalTemplates: STAFF_SEEDS.length }));
  } finally {
    await database.end();
  }
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
