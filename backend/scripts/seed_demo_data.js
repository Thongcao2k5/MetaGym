import dotenv from 'dotenv';
dotenv.config();

import { createDatabasePool } from '../src/config/database.js';

const pool = createDatabasePool();

const MEMBER_ID = '10000000-0000-4000-8000-000000000003'; // Member Demo (m@m.com)
const COACH_MIA_ID = '10000000-0000-4000-8000-000000000014'; // Hoàng Thảo My
const ADMIN_ID = '00000000-0000-4000-8000-000000000001';
const RELATIONSHIP_ID = '9e1e22d3-75a4-478b-a2d3-d0c2cb824adc'; // Member <-> Coach Mia

async function seed() {
  console.log('--- ĐANG KHỞI TẠO DỮ LIỆU MẪU (DEMO SEED) CHO BÁO CÁO ---');

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // 1. Thêm gói hội viên phong phú (Membership Plans)
    console.log('1. Khởi tạo Gói tập Gym...');
    await client.query(`
      INSERT INTO membership_plans (id, name, description, price, duration_days, status, created_by)
      VALUES 
        ('90000000-0000-4000-8000-000000000031', 'Gói 3 Tháng Pro - Thể Lực & Siết Cơ', '[DEMO_DATA] Bao gồm toàn bộ khu vực tạ, cardio và xông hơi thảo dược. Tiết kiệm 15%.', 1350000, 90, 'ACTIVE', $1),
        ('90000000-0000-4000-8000-000000000032', 'Gói 1 Năm VIP Diamond', '[DEMO_DATA] Đặc quyền tập luyện 365 ngày toàn hệ thống, tặng 2 buổi huấn luyện cùng PT và tủ đồ riêng.', 4800000, 365, 'ACTIVE', $1)
      ON CONFLICT (id) DO UPDATE SET 
        name = EXCLUDED.name,
        description = EXCLUDED.description,
        price = EXCLUDED.price,
        duration_days = EXCLUDED.duration_days,
        status = EXCLUDED.status;
    `, [ADMIN_ID]);

    // 2. Thêm Thiết bị phòng gym (Equipment)
    console.log('2. Khởi tạo Thiết bị phòng gym...');
    await client.query(`
      INSERT INTO equipment (id, name, category, target_muscles, description, usage_steps, safety_notes, status, created_by)
      VALUES
        ('90000000-0000-4000-8000-000000000011', 'Ghế đẩy ngực Bench Press', 'Tạ tự do & Kháng lực', ARRAY['Ngực', 'Tay sau', 'Vai trước'], '[DEMO_DATA] Ghế đẩy ngực phẳng tiêu chuẩn Olympic.', '["Nằm ngửa lưng chạm ghế", "Hai chân chạm sàn vững vàng", "Nắm thanh đòn rộng hơn vai", "Hạ tạ có kiểm soát chạm ngực dưới", "Đẩy tạ dứt khoát lên"]'::jsonb, 'Luôn có người hỗ trợ (spotter) hoặc dùng chốt an toàn khi tập mức tạ nặng.', 'ACTIVE', $1),
        ('90000000-0000-4000-8000-000000000012', 'Khung gánh tạ Squat Rack', 'Tạ tự do', ARRAY['Đùi trước', 'Mông', 'Đùi sau', 'Lưng dưới'], '[DEMO_DATA] Khung tập gánh tạ đa năng tích hợp thanh bảo hộ an toàn.', '["Chỉnh thanh đỡ ngang ngực", "Đặt đòn lên cầu vai", "Gồng chặt cơ bụng và hạ hông", "Đạp sàn đứng thẳng dậy"]'::jsonb, 'Không khóa khớp gối ở đỉnh động tác.', 'ACTIVE', $1),
        ('90000000-0000-4000-8000-000000000013', 'Máy kéo xô Lat Pulldown', 'Máy khối', ARRAY['Lưng xô', 'Tay trước', 'Lưng giữa'], '[DEMO_DATA] Máy kéo xô cáp chuyên dụng phát triển độ rộng của lưng.', '["Chỉnh đệm đùi vừa vặn", "Hai tay nắm rộng thanh kéo", "Ưỡn ngực kéo thanh đòn xuống xương đòn", "Nhả tạ từ từ có kiểm soát"]'::jsonb, 'Không dùng đà đu người ra sau quá nhiều.', 'ACTIVE', $1),
        ('90000000-0000-4000-8000-000000000014', 'Dàn tạ đơn Dumbbells cao cấp', 'Tạ tự do', ARRAY['Toàn thân'], '[DEMO_DATA] Bộ tạ đơn cao su từ 2.5kg đến 40kg phục vụ tập các nhóm cơ.', '["Chọn mức tạ phù hợp", "Khởi động kỹ cổ tay", "Tập trung vào cảm nhận cơ bắp"]'::jsonb, 'Đặt tạ nhẹ nhàng lên giá sau khi tập xong.', 'ACTIVE', $1)
      ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        category = EXCLUDED.category,
        target_muscles = EXCLUDED.target_muscles,
        description = EXCLUDED.description,
        usage_steps = EXCLUDED.usage_steps,
        safety_notes = EXCLUDED.safety_notes;
    `, [ADMIN_ID]);

    // 3. Thêm Thư viện bài tập (Exercises)
    console.log('3. Khởi tạo Thư viện bài tập...');
    await client.query(`
      INSERT INTO exercises (id, equipment_id, name, description, target_muscles, instructions, safety_notes, difficulty, status, created_by)
      VALUES
        ('90000000-0000-4000-8000-000000000021', '90000000-0000-4000-8000-000000000011', 'Barbell Bench Press', '[DEMO_DATA] Bài tập nền tảng xây dựng cơ ngực vạm vỡ và sức mạnh thân trên.', ARRAY['Ngực', 'Tay sau'], 'Nằm ngửa, siết bả vai, hít sâu khi hạ tạ và thở mạnh khi đẩy lên.', 'Cổ tay thẳng, không uốn cong gập cổ tay.', 'INTERMEDIATE', 'ACTIVE', $1),
        ('90000000-0000-4000-8000-000000000022', '90000000-0000-4000-8000-000000000014', 'Incline Dumbbell Press', '[DEMO_DATA] Đẩy tạ đơn ghế dốc 30-45 độ phát triển cơ ngực trên săn chắc.', ARRAY['Ngực trên', 'Vai trước'], 'Ghế nghiêng 30 độ, nâng tạ lên vuông góc sàn, ép chặt cơ ngực ở đỉnh.', 'Không va chạm tạ vào nhau tạo tiếng ồn lớn.', 'INTERMEDIATE', 'ACTIVE', $1),
        ('90000000-0000-4000-8000-000000000023', '90000000-0000-4000-8000-000000000012', 'Barbell Back Squat', '[DEMO_DATA] Vua của các bài tập chân đùi, kích thích phát triển toàn diện thân dưới.', ARRAY['Đùi trước', 'Mông', 'Lưng dưới'], 'Chân rộng bằng vai, mũi chân mở nhẹ, gồng core và ngồi xổm xuống tới khi đùi song song sàn.', 'Lưng luôn giữ thẳng tự nhiên, không cong lưng.', 'ADVANCED', 'ACTIVE', $1),
        ('90000000-0000-4000-8000-000000000024', '90000000-0000-4000-8000-000000000013', 'Lat Pulldown Kéo Xô Mặt Trước', '[DEMO_DATA] Bài tập tạo hình lưng chữ V (V-taper) sắc nét.', ARRAY['Lưng xô', 'Tay trước'], 'Kéo thanh đòn về phía ức ngực, ép chặt 2 xương bả vai.', 'Giữ thân người cố định, không đung đưa lưng.', 'BEGINNER', 'ACTIVE', $1),
        ('90000000-0000-4000-8000-000000000025', '90000000-0000-4000-8000-000000000014', 'Dumbbell Bicep Curl', '[DEMO_DATA] Cuốn tạ đơn từng tay cô lập cơ bắp tay trước.', ARRAY['Tay trước'], 'Đứng thẳng, cùi chỏ khép sát thân mình, cuốn tạ lên đồng thời xoay nhẹ cổ tay hướng ra ngoài.', 'Không nhấc cùi chỏ ra phía trước khi cuốn tạ.', 'BEGINNER', 'ACTIVE', $1),
        ('90000000-0000-4000-8000-000000000026', NULL, 'Plank Siết Cơ Bụng & Core', '[DEMO_DATA] Giữ thăng bằng tĩnh tăng sức mạnh cơ trọng tâm và ổn định cột sống.', ARRAY['Cơ bụng', 'Cơ core', 'Lưng dưới'], 'Chống cẳng tay xuống thảm, cơ thể tạo thành một đường thẳng từ đầu đến gót chân, siết chặt bụng và mông.', 'Không võng lưng hoặc nhô mông quá cao.', 'BEGINNER', 'ACTIVE', $1)
      ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        description = EXCLUDED.description,
        target_muscles = EXCLUDED.target_muscles,
        instructions = EXCLUDED.instructions,
        safety_notes = EXCLUDED.safety_notes,
        difficulty = EXCLUDED.difficulty;
    `, [ADMIN_ID]);

    // 4. Lịch sử điểm danh đến phòng gym (Gym Visits)
    console.log('4. Khởi tạo Lịch sử check-in gym (Gym Visits)...');
    await client.query(`
      INSERT INTO gym_visits (id, member_id, visit_day, checked_in_at, gym_name, gym_address)
      VALUES
        ('90000000-0000-4000-8000-000000000041', $1, (CURRENT_DATE - INTERVAL '1 day')::date, (CURRENT_DATE - INTERVAL '1 day' + TIME '18:30:00')::timestamptz, 'Meta Gym Flagship Center', '123 Nguyễn Thị Minh Khai, Phường Bến Thành, Quận 1, TP.HCM'),
        ('90000000-0000-4000-8000-000000000042', $1, (CURRENT_DATE - INTERVAL '3 day')::date, (CURRENT_DATE - INTERVAL '3 day' + TIME '18:15:00')::timestamptz, 'Meta Gym Flagship Center', '123 Nguyễn Thị Minh Khai, Phường Bến Thành, Quận 1, TP.HCM'),
        ('90000000-0000-4000-8000-000000000043', $1, (CURRENT_DATE - INTERVAL '5 day')::date, (CURRENT_DATE - INTERVAL '5 day' + TIME '07:10:00')::timestamptz, 'Meta Gym Flagship Center', '123 Nguyễn Thị Minh Khai, Phường Bến Thành, Quận 1, TP.HCM'),
        ('90000000-0000-4000-8000-000000000044', $1, (CURRENT_DATE - INTERVAL '7 day')::date, (CURRENT_DATE - INTERVAL '7 day' + TIME '19:00:00')::timestamptz, 'Meta Gym Flagship Center', '123 Nguyễn Thị Minh Khai, Phường Bến Thành, Quận 1, TP.HCM'),
        ('90000000-0000-4000-8000-000000000045', $1, (CURRENT_DATE - INTERVAL '10 day')::date, (CURRENT_DATE - INTERVAL '10 day' + TIME '18:45:00')::timestamptz, 'Meta Gym Flagship Center', '123 Nguyễn Thị Minh Khai, Phường Bến Thành, Quận 1, TP.HCM')
      ON CONFLICT (id) DO NOTHING;
    `, [MEMBER_ID]);

    // 5. Nhật ký & Chỉ số cơ thể (Body Measurements & Journal)
    console.log('5. Khởi tạo Chỉ số cơ thể & Nhật ký tập luyện...');
    await client.query(`
      INSERT INTO body_measurements (id, member_id, measured_at, weight_kg, body_fat_percent, chest_cm, waist_cm, hips_cm, arm_cm, thigh_cm, notes)
      VALUES
        ('90000000-0000-4000-8000-000000000051', $1, (CURRENT_DATE - INTERVAL '14 day')::timestamptz, 73.8, 19.2, 96.0, 82.5, 95.0, 32.5, 56.0, '[DEMO_DATA] Đo đạc định kỳ đầu tháng với Coach.'),
        ('90000000-0000-4000-8000-000000000052', $1, (CURRENT_DATE - INTERVAL '7 day')::timestamptz, 72.9, 18.3, 97.0, 80.5, 94.5, 33.0, 56.0, '[DEMO_DATA] Vòng eo giảm tốt sau tuần ăn thâm hụt calo.'),
        ('90000000-0000-4000-8000-000000000053', $1, CURRENT_TIMESTAMP, 72.1, 17.5, 98.0, 78.5, 94.0, 33.8, 56.5, '[DEMO_DATA] Cơ bắp ngực và bắp tay nét hơn rõ rệt.')
      ON CONFLICT (id) DO UPDATE SET
        weight_kg = EXCLUDED.weight_kg,
        body_fat_percent = EXCLUDED.body_fat_percent,
        chest_cm = EXCLUDED.chest_cm,
        waist_cm = EXCLUDED.waist_cm,
        hips_cm = EXCLUDED.hips_cm,
        arm_cm = EXCLUDED.arm_cm,
        thigh_cm = EXCLUDED.thigh_cm,
        notes = EXCLUDED.notes;
    `, [MEMBER_ID]);

    await client.query(`
      INSERT INTO member_journal_entries (id, member_id, journal_date, notes, chest_cm, waist_cm, hips_cm, achievements)
      VALUES
        ('90000000-0000-4000-8000-000000000061', $1, (CURRENT_DATE - INTERVAL '3 day')::date, '[DEMO_DATA] Buổi tập ngực và tay sau hoàn thành xuất sắc! Đẩy tạ Bench Press lên mức 70kg x 8 reps.', 97.5, 79.5, 94.0, '["PR Bench Press 70kg", "Năng lượng tập luyện cao"]'::jsonb),
        ('90000000-0000-4000-8000-000000000062', $1, (CURRENT_DATE - INTERVAL '1 day')::date, '[DEMO_DATA] Buổi tập Chân & Bụng với Coach. Squat 80kg hoàn thành trọn vẹn 4 hiệp không bị mỏi lưng dưới.', 98.0, 78.5, 94.0, '["Squat 80kg x 4 sets", "Coach feedback: Form chuẩn"]'::jsonb)
      ON CONFLICT (id) DO UPDATE SET
        notes = EXCLUDED.notes,
        chest_cm = EXCLUDED.chest_cm,
        waist_cm = EXCLUDED.waist_cm,
        achievements = EXCLUDED.achievements;
    `, [MEMBER_ID]);

    // 6. Giáo trình đào tạo của Coach (Training Plan, Days, Exercises, Meals)
    console.log('6. Khởi tạo Giáo trình của Coach (Curriculum)...');
    await client.query(`
      INSERT INTO training_plans (id, relationship_id, member_id, coach_id, title, goal, start_date, end_date, version, status, published_at)
      VALUES (
        '90000000-0000-4000-8000-000000000071',
        $1, $2, $3,
        'Lộ Trình Tăng Cơ Nạc & Siết Cơ 8 Tuần',
        'Tăng 2kg cơ bắp nạc, giảm 3% mỡ cơ thể, xây dựng form chuẩn các động tác compound và cải thiện sức bền thể lực toàn diện.',
        CURRENT_DATE, (CURRENT_DATE + INTERVAL '60 days')::date,
        1, 'ACTIVE', CURRENT_TIMESTAMP
      )
      ON CONFLICT (id) DO UPDATE SET
        title = EXCLUDED.title,
        goal = EXCLUDED.goal,
        status = EXCLUDED.status,
        published_at = EXCLUDED.published_at;
    `, [RELATIONSHIP_ID, MEMBER_ID, COACH_MIA_ID]);

    // Plan Days
    await client.query(`
      INSERT INTO training_plan_days (id, plan_id, day_number, title, notes, scheduled_date)
      VALUES
        ('90000000-0000-4000-8000-000000000072', '90000000-0000-4000-8000-000000000071', 1, 'Thứ Hai: Ngực & Tay Sau (Chest & Triceps)', 'Tập trung phát lực từ cơ ngực và giữ cùi chỏ kiểm soát.', CURRENT_DATE),
        ('90000000-0000-4000-8000-000000000073', '90000000-0000-4000-8000-000000000071', 2, 'Thứ Tư: Lưng Xô & Tay Trước (Back & Biceps)', 'Ưỡn ngực kéo vai về sau, gồng chặt xô trong 1 giây ở cuối động tác.', (CURRENT_DATE + INTERVAL '2 days')::date),
        ('90000000-0000-4000-8000-000000000074', '90000000-0000-4000-8000-000000000071', 3, 'Thứ Sáu: Chân Đùi & Cơ Bụng (Legs & Core)', 'Khởi động kỹ khớp gối và hông trước khi vào bài tập chính.', (CURRENT_DATE + INTERVAL '4 days')::date)
      ON CONFLICT (id) DO UPDATE SET
        title = EXCLUDED.title,
        notes = EXCLUDED.notes,
        scheduled_date = EXCLUDED.scheduled_date;
    `);

    // Plan Exercises
    await client.query(`
      INSERT INTO training_plan_exercises (id, plan_day_id, exercise_id, exercise_name_snapshot, instructions_snapshot, safety_notes_snapshot, display_order, sets, reps, duration_seconds, rest_seconds, weight_guidance, notes)
      VALUES
        ('90000000-0000-4000-8000-000000000081', '90000000-0000-4000-8000-000000000072', '90000000-0000-4000-8000-000000000021', 'Barbell Bench Press', 'Hạ tạ chậm 2-3s chạm ngực dưới, đẩy lên dứt khoát', 'Khóa cổ tay chắc chắn', 1, 4, '8-10', NULL, 90, '60kg - 70kg', 'Khởi động 2 set nhẹ trước'),
        ('90000000-0000-4000-8000-000000000082', '90000000-0000-4000-8000-000000000072', '90000000-0000-4000-8000-000000000022', 'Incline Dumbbell Press', 'Ghế dốc 30 độ, siết căng ngực trên', 'Kiểm soát đường đi của tạ', 2, 4, '10-12', NULL, 60, '20kg/tay', 'Hít sâu khi hạ tạ'),
        ('90000000-0000-4000-8000-000000000083', '90000000-0000-4000-8000-000000000073', '90000000-0000-4000-8000-000000000024', 'Lat Pulldown Kéo Xô Mặt Trước', 'Kéo tạ xuống ngang xương ức', 'Không dùng đà đu người', 1, 4, '10-12', NULL, 60, '45kg - 55kg', 'Giữ 1 giây siết cơ xô'),
        ('90000000-0000-4000-8000-000000000084', '90000000-0000-4000-8000-000000000073', '90000000-0000-4000-8000-000000000025', 'Dumbbell Bicep Curl', 'Cuốn tạ cô lập bắp tay trước', 'Khép sát cùi chỏ vào thân', 2, 3, '12 reps', NULL, 45, '12kg/tay', 'Tập chậm từng tay'),
        ('90000000-0000-4000-8000-000000000085', '90000000-0000-4000-8000-000000000074', '90000000-0000-4000-8000-000000000023', 'Barbell Back Squat', 'Ngồi xổm đùi song song mặt sàn', 'Lưng thẳng, mắt nhìn về phía trước', 1, 4, '8 reps', NULL, 120, '70kg - 85kg', 'Thắt đai bảo hộ lưng'),
        ('90000000-0000-4000-8000-000000000086', '90000000-0000-4000-8000-000000000074', '90000000-0000-4000-8000-000000000026', 'Plank Siết Cơ Bụng & Core', 'Thân người thẳng tắp, gồng core', 'Không võng lưng', 2, 3, '3 hiệp', 60, 45, 'Trọng lượng cơ thể', 'Thở đều nhịp nhàng')
      ON CONFLICT (id) DO UPDATE SET
        sets = EXCLUDED.sets,
        reps = EXCLUDED.reps,
        weight_guidance = EXCLUDED.weight_guidance,
        notes = EXCLUDED.notes;
    `);

    // Plan Meals
    await client.query(`
      INSERT INTO training_plan_day_meals (id, plan_day_id, display_order, meal_type, scheduled_time, title, notes)
      VALUES
        ('90000000-0000-4000-8000-000000000091', '90000000-0000-4000-8000-000000000072', 1, 'BREAKFAST', '07:30:00', 'Bữa sáng năng lượng cao', 'Yến mạch 60g, chuối tiêu, 3 lòng trắng trứng + 1 lòng đỏ trần nước sôi.'),
        ('90000000-0000-4000-8000-000000000092', '90000000-0000-4000-8000-000000000072', 2, 'LUNCH', '12:00:00', 'Bữa trưa giàu đạm nạc', '200g ức gà áp chảo sốt tiêu đen, cơm gạo lứt 150g, bông cải xanh luộc.'),
        ('90000000-0000-4000-8000-000000000093', '90000000-0000-4000-8000-000000000072', 3, 'SNACK', '16:30:00', 'Pre-workout snack', '1 muỗng Whey Isolate pha 250ml nước mát + 1 quả táo xanh.'),
        ('90000000-0000-4000-8000-000000000094', '90000000-0000-4000-8000-000000000072', 4, 'DINNER', '19:45:00', 'Bữa tối phục hồi cơ bắp', '180g cá hồi phi lê áp chảo, salad rau củ dầu ô liu, 1 củ khoai lang vàng.')
      ON CONFLICT (id) DO UPDATE SET
        meal_type = EXCLUDED.meal_type,
        title = EXCLUDED.title,
        notes = EXCLUDED.notes;
    `);

    // 7. Lịch sử tin nhắn thực tế giữa Hội viên và Coach (Messages)
    console.log('7. Khởi tạo Tin nhắn trao đổi với Huấn luyện viên...');
    const convId = '3c799954-da82-47b6-981f-645e128acae9'; // Conversation Member <-> Coach Mia
    await client.query(`
      INSERT INTO messages (id, conversation_id, sender_id, client_message_id, message_type, content, sent_at)
      VALUES
        ('90000000-0000-4000-8000-000000000101', $1, $3, '90000000-0000-4000-8000-000000000101', 'TEXT', 'Chào bạn! Mình là Coach Mia Hoàng. Rất vui được đồng hành cùng bạn trong hành trình tập luyện tại Meta Gym!', CURRENT_TIMESTAMP - INTERVAL '2 days' + INTERVAL '30 minutes'),
        ('90000000-0000-4000-8000-000000000102', $1, $2, '90000000-0000-4000-8000-000000000102', 'TEXT', 'Dạ em chào Coach! Mục tiêu của em là giảm mỡ bụng và tăng cơ nạc trong 2 tháng tới ạ.', CURRENT_TIMESTAMP - INTERVAL '2 days' + INTERVAL '35 minutes'),
        ('90000000-0000-4000-8000-000000000103', $1, $3, '90000000-0000-4000-8000-000000000103', 'TEXT', 'Mục tiêu rất rõ ràng! Mình đã lên sẵn Giáo trình 8 tuần kèm thực đơn dinh dưỡng chi tiết trong mục Tập Luyện của bạn rồi nhé.', CURRENT_TIMESTAMP - INTERVAL '1 day' + INTERVAL '2 hours'),
        ('90000000-0000-4000-8000-000000000104', $1, $2, '90000000-0000-4000-8000-000000000104', 'TEXT', 'Dạ em vừa mở app xem rồi ạ, giáo trình rất chi tiết từng bài và mức tạ. Lịch hẹn tuần này của em thế nào coach nhỉ?', CURRENT_TIMESTAMP - INTERVAL '1 day' + INTERVAL '2 hours 10 minutes'),
        ('90000000-0000-4000-8000-000000000105', $1, $3, '90000000-0000-4000-8000-000000000105', 'TEXT', 'Buổi đầu tiên chúng ta sẽ test thể lực và form Bench Press vào 18:00 chiều nay nhé. Nhớ uống đủ nước và khởi động nhẹ trước 10 phút!', CURRENT_TIMESTAMP - INTERVAL '3 hours'),
        ('90000000-0000-4000-8000-000000000106', $1, $2, '90000000-0000-4000-8000-000000000106', 'TEXT', 'Vâng em cảm ơn Coach, hẹn gặp Coach lúc 18:00 tại tầng 2 ạ! 💪', CURRENT_TIMESTAMP - INTERVAL '2 hours 45 minutes')
      ON CONFLICT (id) DO UPDATE SET
        content = EXCLUDED.content,
        sent_at = EXCLUDED.sent_at;
    `, [convId, MEMBER_ID, COACH_MIA_ID]);

    await client.query(`
      UPDATE conversations SET last_message_at = CURRENT_TIMESTAMP - INTERVAL '2 hours 45 minutes' WHERE id = $1;
    `, [convId]);

    // 8. Loyalty & Meta Points (Demo Member: Nguyễn Minh Quân - Vàng)
    console.log('8. Khởi tạo Loyalty & Meta Points (1.240 điểm khả dụng / 2.150 điểm xét hạng)...');
    await client.query(`
      INSERT INTO loyalty_accounts (member_id, available_points, tier_points)
      VALUES ($1, 1240, 2150)
      ON CONFLICT (member_id) DO UPDATE SET
        available_points = EXCLUDED.available_points,
        tier_points = EXCLUDED.tier_points;
    `, [MEMBER_ID]);

    await client.query(`
      INSERT INTO loyalty_redemptions (
        id, member_id, reward_id, reward_code_snapshot, category_snapshot,
        title_snapshot, points_spent, discount_amount_snapshot, voucher_code,
        requires_staff_confirm, condition_text, status, idempotency_key,
        redeemed_at, expires_at, used_at
      )
      VALUES
        (
          '90000000-0000-4000-8000-000000000201', $1,
          'a0000000-0000-4000-8000-000000000002', 'rw-inbody', 'SERVICE',
          'Một lần đo InBody', 400, 0, 'MG-DEMO-INBODY1', true,
          'Cần nhân viên lễ tân hoặc Huấn luyện viên xác nhận khi sử dụng tại câu lạc bộ.',
          'UNUSED', 'seed-demo-redemption-1',
          CURRENT_TIMESTAMP - INTERVAL '8 days', CURRENT_TIMESTAMP + INTERVAL '22 days', NULL
        ),
        (
          '90000000-0000-4000-8000-000000000202', $1,
          'a0000000-0000-4000-8000-000000000001', 'rw-voucher-100', 'VOUCHER',
          'Voucher giảm 100.000đ', 300, 100000, 'MG-DEMO-VOUCHER1', false,
          'Dùng mã này khi gia hạn gói tập phòng gym hoặc xác nhận tại quầy.',
          'USED', 'seed-demo-redemption-2',
          CURRENT_TIMESTAMP - INTERVAL '54 days', CURRENT_TIMESTAMP - INTERVAL '24 days',
          CURRENT_TIMESTAMP - INTERVAL '40 days'
        ),
        (
          '90000000-0000-4000-8000-000000000203', $1,
          'a0000000-0000-4000-8000-000000000003', 'rw-pt-trial', 'SERVICE',
          'Một buổi PT trải nghiệm', 900, 0, 'MG-DEMO-PTTRIAL', true,
          'Cần nhân viên/HLV xác nhận khi còn hiệu lực. Đã quá hạn sử dụng.',
          'EXPIRED', 'seed-demo-redemption-3',
          CURRENT_TIMESTAMP - INTERVAL '110 days', CURRENT_TIMESTAMP - INTERVAL '80 days', NULL
        )
      ON CONFLICT (id) DO NOTHING;
    `, [MEMBER_ID]);

    await client.query(`
      INSERT INTO loyalty_point_transactions (
        id, member_id, tx_type, points_delta, tier_points_delta,
        title, detail, reference_type, reference_id, status_label, created_at
      )
      VALUES
        (
          '90000000-0000-4000-8000-000000000301', $1, 'EARN', 1500, 1500,
          'Cộng điểm khi đăng ký gói Nâng cao kỳ trước',
          'Đăng ký gói tập · Ghi nhận điểm tích lũy xét hạng',
          'SEED', '90000000-0000-4000-8000-000000000301', 'Thành công',
          CURRENT_TIMESTAMP - INTERVAL '160 days'
        ),
        (
          '90000000-0000-4000-8000-000000000302', $1, 'EARN', 650, 650,
          'Cộng điểm khi gia hạn gói tập',
          'Gia hạn Gói Tiêu chuẩn 6 tháng · Cộng vào khả dụng & xét hạng',
          'SEED', '90000000-0000-4000-8000-000000000302', 'Thành công',
          CURRENT_TIMESTAMP - INTERVAL '72 days'
        ),
        (
          '90000000-0000-4000-8000-000000000303', $1, 'ADJUST', 190, 0,
          'Hoàn điểm điều chỉnh giao dịch quầy',
          'Điều chỉnh hoàn điểm khả dụng từ yêu cầu đổi dịch vụ trước đó',
          'SEED', '90000000-0000-4000-8000-000000000303', 'Đã hoàn điểm',
          CURRENT_TIMESTAMP - INTERVAL '35 days'
        ),
        (
          '90000000-0000-4000-8000-000000000304', $1, 'SPEND', -400, 0,
          'Trừ điểm đổi ưu đãi: Một lần đo InBody',
          'Chỉ trừ Điểm khả dụng · Giữ nguyên Điểm xét hạng',
          'REWARD_REDEMPTION', '90000000-0000-4000-8000-000000000201', 'Đã đổi ưu đãi',
          CURRENT_TIMESTAMP - INTERVAL '8 days'
        )
      ON CONFLICT (id) DO NOTHING;
    `, [MEMBER_ID]);

    await client.query('COMMIT');
    console.log('✅ KHỞI TẠO DỮ LIỆU MẪU THÀNH CÔNG RỰC RỠ!');
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('❌ Lỗi khi khởi tạo dữ liệu mẫu:', error);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

seed();
