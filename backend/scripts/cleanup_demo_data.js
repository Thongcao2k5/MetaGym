import dotenv from 'dotenv';
dotenv.config();

import { createDatabasePool } from '../src/config/database.js';

const pool = createDatabasePool();

async function cleanup() {
  console.log('--- BẮT ĐẦU DỌN DẸP TOÀN BỘ DỮ LIỆU MẪU (CLEANUP DEMO DATA) ---');

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Xóa theo thứ tự ràng buộc khóa ngoại
    console.log('1. Đặt lại con trỏ đọc tin nhắn (Read Cursor)...');
    await client.query(`
      UPDATE conversation_participants 
      SET last_read_message_id = NULL 
      WHERE last_read_message_id::text LIKE '90000000-0000-4000-8000-%';
    `);

    console.log('2. Xóa Messages mẫu...');
    await client.query(`DELETE FROM messages WHERE id::text LIKE '90000000-0000-4000-8000-%'`);

    console.log('2. Xóa Thực đơn mẫu trong Giáo trình (Training Plan Meals)...');
    await client.query(`DELETE FROM training_plan_day_meals WHERE id::text LIKE '90000000-0000-4000-8000-%'`);

    console.log('3. Xóa Bài tập mẫu trong Giáo trình (Training Plan Exercises)...');
    await client.query(`DELETE FROM training_plan_exercises WHERE id::text LIKE '90000000-0000-4000-8000-%'`);

    console.log('4. Xóa Ngày tập mẫu trong Giáo trình (Training Plan Days)...');
    await client.query(`DELETE FROM training_plan_days WHERE id::text LIKE '90000000-0000-4000-8000-%'`);

    console.log('5. Xóa Giáo trình mẫu (Training Plans)...');
    await client.query(`DELETE FROM training_plans WHERE id::text LIKE '90000000-0000-4000-8000-%'`);

    console.log('6. Xóa Nhật ký tập luyện mẫu (Member Journal Entries)...');
    await client.query(`DELETE FROM member_journal_entries WHERE id::text LIKE '90000000-0000-4000-8000-%'`);

    console.log('7. Xóa Đo đạc chỉ số cơ thể mẫu (Body Measurements)...');
    await client.query(`DELETE FROM body_measurements WHERE id::text LIKE '90000000-0000-4000-8000-%'`);

    console.log('8. Xóa Lịch sử check-in gym mẫu (Gym Visits)...');
    await client.query(`DELETE FROM gym_visits WHERE id::text LIKE '90000000-0000-4000-8000-%'`);

    console.log('9. Xóa Bài tập thư viện mẫu (Exercises)...');
    await client.query(`DELETE FROM exercises WHERE id::text LIKE '90000000-0000-4000-8000-%'`);

    console.log('10. Xóa Thiết bị mẫu (Equipment)...');
    await client.query(`DELETE FROM equipment WHERE id::text LIKE '90000000-0000-4000-8000-%'`);

    console.log('11. Xóa Gói tập gym mẫu (Membership Plans)...');
    await client.query(`DELETE FROM membership_plans WHERE id::text LIKE '90000000-0000-4000-8000-%'`);

    await client.query('COMMIT');
    console.log('✨ ĐÃ DỌN DẸP SẠCH SẼ TOÀN BỘ DỮ LIỆU MẪU! KHÔNG CÒN BẤT KỲ DẤU VẾT NÀO.');
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('❌ Lỗi khi dọn dẹp dữ liệu mẫu:', error);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

cleanup();
