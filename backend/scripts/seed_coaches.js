import dotenv from 'dotenv';
dotenv.config();
import crypto from 'crypto';
import { createDatabasePool } from '../src/config/database.js';

const pool = createDatabasePool();

const coachesData = [
  {
    id: '10000000-0000-4000-8000-000000000011',
    fullName: 'Nguyễn Hùng (Alex Nguyễn)',
    email: 'alex.hung@metagym.vn',
    phone: '0901234001',
    specialties: ['Tăng cơ Hypertrophy', 'Sức mạnh Powerlifting', 'Tăng cân'],
    biography: 'Huấn luyện viên thể hình chuyên sâu về phát triển khối lượng cơ bắp và kỹ thuật nâng tạ chuẩn thi đấu.',
    qualifications: 'CSCS · NASM Certified Personal Trainer · Cựu VĐV Thể hình Quốc gia',
    experienceYears: 6,
    availabilityNote: 'Thứ 2 – Thứ 7 · 07:00 – 19:30',
    memberLimit: 8,
  },
  {
    id: '10000000-0000-4000-8000-000000000012',
    fullName: 'Lê Minh Trang (Chloe Lê)',
    email: 'chloe.trang@metagym.vn',
    phone: '0901234002',
    specialties: ['Giảm mỡ Siết cơ', 'Pilates & Mobility', 'Dinh dưỡng giảm cân'],
    biography: 'Chuyên gia điều chỉnh vóc dáng thon gọn, săn chắc cơ bụng và cải thiện độ linh hoạt khớp xương cho người làm việc văn phòng.',
    qualifications: 'ACE Certified Fitness Coach · Precision Nutrition Level 1',
    experienceYears: 5,
    availabilityNote: 'Thứ 2 – Thứ 7 · 06:30 – 18:30',
    memberLimit: 8,
  },
  {
    id: '10000000-0000-4000-8000-000000000013',
    fullName: 'Trần Quốc Bảo (Kevin Trần)',
    email: 'kevin.bao@metagym.vn',
    phone: '0901234003',
    specialties: ['Thể lực & Cardio HIIT', 'Phục hồi sau chấn thương', 'Calisthenics'],
    biography: 'Huấn luyện viên sức bền và tim mạch, chuyên tối ưu hóa hiệu suất thể thao và phục hồi chức năng sau chấn thương vận động.',
    qualifications: 'ISSA Certified Fitness Trainer · Chuyên viên Phục hồi Vận động',
    experienceYears: 7,
    availabilityNote: 'Thứ 2 – Thứ 7 · 08:00 – 20:00',
    memberLimit: 8,
  },
  {
    id: '10000000-0000-4000-8000-000000000014',
    fullName: 'Hoàng Thảo My (Mia Hoàng)',
    email: 'mia.my@metagym.vn',
    phone: '0901234004',
    specialties: ['Tăng cơ giảm mỡ (Body Recomp)', 'Yoga Flow & Giãn cơ', 'Sức khỏe tim mạch'],
    biography: 'Phương pháp tập luyện kết hợp giữa chuyển động dẻo dai và kháng lực hiện đại giúp cơ thể thon gọn, tràn đầy năng lượng.',
    qualifications: 'NASM-CPT · Yoga Alliance RYT-200 · Certified Functional Strength Coach',
    experienceYears: 4,
    availabilityNote: 'Thứ 2 – Thứ 7 · 07:00 – 18:00',
    memberLimit: 8,
  },
];

// Slots: 4 slots per day (08:00, 09:30, 14:00, 15:30) across 6 workdays (1 to 6)
const slotMinutes = [
  { start: 480, end: 570 },
  { start: 570, end: 660 },
  { start: 840, end: 930 },
  { start: 930, end: 1020 },
];
const weekdays = [1, 2, 3, 4, 5, 6];

const passwordHash = '$2b$10$k1wuaEmLZAAyTHg9zMCTkObae8fxOWFp7EufnxRS/NG8DBe9u8iXi';

async function seed() {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    for (const coach of coachesData) {
      console.log(`Seeding coach: ${coach.fullName} (${coach.email})...`);

      // 1. Insert or update users table
      await client.query(`
        INSERT INTO users (id, email, password_hash, role, full_name, phone, status, session_version)
        VALUES ($1, $2, $3, 'COACH', $4, $5, 'ACTIVE', 1)
        ON CONFLICT (id) DO UPDATE SET
          email = EXCLUDED.email,
          full_name = EXCLUDED.full_name,
          phone = EXCLUDED.phone,
          status = 'ACTIVE',
          updated_at = statement_timestamp()
      `, [coach.id, coach.email, passwordHash, coach.fullName, coach.phone]);

      // 2. Insert or update coach_profiles table
      await client.query(`
        INSERT INTO coach_profiles (user_id, biography, specialties, qualifications, experience_years, availability_note, member_limit)
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        ON CONFLICT (user_id) DO UPDATE SET
          biography = EXCLUDED.biography,
          specialties = EXCLUDED.specialties,
          qualifications = EXCLUDED.qualifications,
          experience_years = EXCLUDED.experience_years,
          availability_note = EXCLUDED.availability_note,
          member_limit = EXCLUDED.member_limit,
          updated_at = statement_timestamp()
      `, [
        coach.id,
        coach.biography,
        coach.specialties,
        coach.qualifications,
        coach.experienceYears,
        coach.availabilityNote,
        coach.memberLimit,
      ]);

      // 3. Delete existing weekly slots for this coach and recreate 24 slots (6 days x 4 slots)
      await client.query('DELETE FROM coach_weekly_slots WHERE coach_id = $1', [coach.id]);

      for (const weekday of weekdays) {
        for (const slot of slotMinutes) {
          const slotId = crypto.randomUUID();
          await client.query(`
            INSERT INTO coach_weekly_slots (id, coach_id, weekday, start_minute)
            VALUES ($1, $2, $3, $4)
          `, [slotId, coach.id, weekday, slot.start]);
        }
      }
    }

    await client.query('COMMIT');
    console.log('Successfully seeded 4 coaches with complete profiles and weekly slots!');
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Seed error:', err);
    throw err;
  } finally {
    client.release();
    await pool.end();
  }
}

seed();
