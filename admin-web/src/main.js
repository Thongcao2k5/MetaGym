import 'bootstrap/dist/css/bootstrap.min.css';
import 'bootstrap/dist/js/bootstrap.bundle.min.js';
import Chart from 'chart.js/auto';
import QRCode from 'qrcode';
import './style.css';

const root = document.querySelector('#app');
const base = (import.meta.env.VITE_API_BASE_URL || '/api/v1').replace(/\/$/, '');
let token = sessionStorage.getItem('metagym_admin_token');
let user;
let chart;
const esc = (value) => String(value ?? '').replace(/[&<>"']/g,
  (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char]);
const currency = (value) => `${new Intl.NumberFormat('vi-VN').format(Number(value ?? 0))} ₫`;

async function api(path, method = 'GET', body, key) {
  const response = await fetch(`${base}${path}`, { method,
    headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(body === undefined ? {} : { 'Content-Type': 'application/json' }),
      ...(key ? { 'Idempotency-Key': key } : {}) },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    if (response.status === 401 && token) signOut();
    throw new Error(payload.error?.message || `HTTP ${response.status}`);
  }
  return payload;
}

function signOut() {
  token = null; user = null;
  sessionStorage.removeItem('metagym_admin_token');
  location.hash = '/admin/login';
}

function notice(text, kind = 'success') {
  const box = document.querySelector('#notice');
  if (box) box.innerHTML = `<div class="alert alert-${kind}" role="alert">${esc(text)}</div>`;
}

function layout(section, content) {
  const links = [ ['dashboard', 'Tổng quan'], ['members', 'Member'],
    ['coaches', 'Coach'], ['plans', 'Gói tập'], ['coach-packages', 'Gói Coach'], ['payments', 'Thanh toán'],
    ['relationships', 'Quan hệ'], ['terminations', 'Yêu cầu kết thúc'],
    ['gym', 'Phòng gym'], ['equipment', 'Thiết bị'], ['nutrition-foods', 'Thực phẩm'], ['profile', 'Hồ sơ'] ];
  root.innerHTML = `<div class="admin-shell"><aside class="admin-sidebar bg-dark text-white p-3">
    <a class="brand text-white text-decoration-none" href="#/admin/dashboard">META GYM <span>ADMIN</span></a>
    <nav class="nav flex-column mt-4" aria-label="Quản trị">${links.map(([id, label]) =>
      `<a class="nav-link ${section === id ? 'active' : ''}" href="#/admin/${id}">${label}</a>`).join('')}</nav>
    <button class="btn btn-outline-light btn-sm mt-4" id="logout">Đăng xuất</button></aside>
    <main class="admin-main p-3 p-lg-4"><div class="container-fluid"><header class="d-flex justify-content-between align-items-center mb-4">
    <h1 class="h3 m-0">${esc(links.find(([id]) => id === section)?.[1])}</h1><span class="text-secondary small">${esc(user?.fullName)}</span></header>
    <div id="notice" aria-live="polite"></div>${content}</div></main></div>`;
  document.querySelector('#logout').onclick = signOut;
}

function table(headings, rows) {
  if (!rows.length) return '<div class="alert alert-light border">Chưa có dữ liệu.</div>';
  return `<div class="table-responsive"><table class="table table-hover align-middle bg-white"><thead><tr>${headings.map((h) => `<th>${esc(h)}</th>`).join('')}</tr></thead><tbody>${rows.join('')}</tbody></table></div>`;
}

function login() {
  root.innerHTML = `<main class="login-screen d-flex align-items-center justify-content-center p-3"><form id="login" class="card shadow-sm p-4 login-card">
    <h1 class="h3">Meta Gym Admin</h1><p class="text-secondary">Đăng nhập bằng tài khoản Admin.</p>
    <div id="login-error" class="text-danger small" role="alert"></div>
    <label class="form-label">Email<input class="form-control mb-3" name="email" type="email" autocomplete="username" required></label>
    <label class="form-label">Mật khẩu<input class="form-control mb-3" name="password" type="password" autocomplete="current-password" required></label>
    <button class="btn btn-success w-100">Đăng nhập</button></form></main>`;
  document.querySelector('#login').onsubmit = async (event) => {
    event.preventDefault(); const form = new FormData(event.currentTarget);
    const button = event.currentTarget.querySelector('button'); button.disabled = true;
    try {
      const result = await api('/auth/sessions', 'POST', { email: form.get('email'), password: form.get('password') });
      if (result.data.user.role !== 'ADMIN') throw new Error('Tài khoản không có quyền Admin.');
      token = result.data.accessToken; user = result.data.user;
      sessionStorage.setItem('metagym_admin_token', token);
      location.hash = '/admin/dashboard'; await route();
    } catch (error) { document.querySelector('#login-error').textContent = error.message; }
    finally { button.disabled = false; }
  };
}

async function dashboard() {
  const { data } = await api('/admin/dashboard');
  const cards = [ ['Member hoạt động', data.members.active, 'members'],
    ['Coach hoạt động', data.coaches.active, 'coaches'],
    ['Gói đang hoạt động', data.activeMemberships, 'payments'],
    ['Yêu cầu kết thúc', data.pendingTerminationRequests, 'terminations'],
    ['Doanh thu', currency(data.revenue.amount), 'payments'] ];
  layout('dashboard', `<p class="text-secondary">${esc(data.from)} – ${esc(data.to)}</p><div class="row g-3 mb-4">${cards.map(([label, value, routeName]) =>
    `<div class="col-md-6 col-xl-4"><a class="card card-body stat-card text-decoration-none" href="#/admin/${routeName}"><span>${label}</span><strong class="h3 mb-0">${esc(value)}</strong></a></div>`).join('')}</div>
    <div class="card card-body"><h2 class="h5">Doanh thu theo ngày</h2><div class="chart-wrap"><canvas id="revenue-chart"></canvas></div></div>`);
  chart = new Chart(document.querySelector('#revenue-chart'), { type: 'bar', data: {
    labels: data.revenue.byDay.map((row) => row.day), datasets: [{ label: 'VND',
      data: data.revenue.byDay.map((row) => Number(row.amount)), backgroundColor: '#198754' }],
  }, options: { responsive: true, maintainAspectRatio: false } });
}

async function accounts(role, page = 1) {
  const section = role === 'COACH' ? 'coaches' : 'members';
  const result = await api(`/admin/users?role=${role}&page=${page}&pageSize=20`);
  layout(section, `${role === 'COACH' ? '<button id="create" class="btn btn-success mb-3">Tạo Coach</button>' : ''}
    ${table(['Tên', 'Email', 'Trạng thái', 'Thao tác'], result.data.map((row) => `<tr><td>${esc(row.fullName)}</td><td>${esc(row.email)}</td>
    <td>${esc(row.status)}</td><td><button class="btn btn-outline-primary btn-sm edit" data-id="${row.id}">Sửa</button>
    <button class="btn btn-outline-${row.status === 'ACTIVE' ? 'danger' : 'success'} btn-sm toggle" data-id="${row.id}" data-status="${row.status}">${row.status === 'ACTIVE' ? 'Khóa' : 'Mở'}</button>
    ${role === 'COACH' ? `<button class="btn btn-outline-secondary btn-sm reset" data-id="${row.id}">Mật khẩu tạm</button>` : ''}</td></tr>`))}
    <div class="d-flex justify-content-between align-items-center"><span>${result.pagination.totalItems} kết quả · trang ${page}</span>
    <div class="btn-group"><button id="prev" class="btn btn-outline-secondary btn-sm" ${page <= 1 ? 'disabled' : ''}>Trước</button>
    <button id="next" class="btn btn-outline-secondary btn-sm" ${page >= result.pagination.totalPages ? 'disabled' : ''}>Sau</button></div></div><div id="editor"></div>`);
  document.querySelector('#prev').onclick = () => accounts(role, page - 1);
  document.querySelector('#next').onclick = () => accounts(role, page + 1);
  function editor(row) {
    document.querySelector('#editor').innerHTML = `<form id="account-form" class="card card-body mt-3"><h2 class="h5">${row ? 'Sửa tài khoản' : 'Tạo Coach'}</h2>
      <input class="form-control mb-2" name="fullName" placeholder="Họ tên" value="${esc(row?.fullName)}" required minlength="2">
      ${row ? `<input class="form-control mb-2" name="phone" placeholder="Điện thoại" value="${esc(row.phone)}">` : `<input class="form-control mb-2" name="email" type="email" placeholder="Email" required><input class="form-control mb-2" name="password" type="password" placeholder="Mật khẩu (hoa, thường, số)" required minlength="8">`}
      <button class="btn btn-success align-self-start">Lưu</button></form>`;
    document.querySelector('#account-form').onsubmit = async (event) => {
      event.preventDefault(); const form = new FormData(event.currentTarget);
      const body = { fullName: form.get('fullName'), ...(row ? { phone: form.get('phone') || null } :
        { email: form.get('email'), password: form.get('password'), ...(role === 'COACH' ? { memberLimit: 8 } : {}) }) };
      try { await api(row ? `/admin/users/${row.id}` : '/admin/coaches', row ? 'PATCH' : 'POST', body);
        await accounts(role, page); notice('Đã lưu tài khoản.'); }
      catch (error) { notice(error.message, 'danger'); }
    };
  }
  document.querySelector('#create')?.addEventListener('click', () => editor(null));
  document.querySelectorAll('.edit').forEach((button) => button.onclick = () => editor(result.data.find((row) => row.id === button.dataset.id)));
  document.querySelectorAll('.toggle').forEach((button) => button.onclick = async () => {
    const status = button.dataset.status === 'ACTIVE' ? 'DISABLED' : 'ACTIVE';
    if (!confirm(`Xác nhận ${status === 'DISABLED' ? 'khóa' : 'mở'} tài khoản?`)) return;
    const body = { status };
    if (status === 'DISABLED') {
      const reason = prompt('Lý do khóa tài khoản:');
      if (reason === null) return;
      const trimmedReason = reason.trim();
      if (!trimmedReason || trimmedReason.length > 500) {
        notice('Lý do khóa tài khoản phải có từ 1 đến 500 ký tự.', 'danger');
        return;
      }
      body.reason = trimmedReason;
    }
    try { await api(`/admin/users/${button.dataset.id}/status`, 'PATCH', body);
      await accounts(role, page); notice('Đã cập nhật trạng thái.'); }
    catch (error) { notice(error.message, 'danger'); }
  });
  document.querySelectorAll('.reset').forEach((button) => button.onclick = async () => {
    if (!confirm('Đặt lại mật khẩu Coach và vô hiệu hóa các phiên cũ?')) return;
    try { const result = await api(`/admin/coaches/${button.dataset.id}/password-resets`, 'POST', {});
      document.querySelector('#editor').innerHTML = `<div class="alert alert-warning mt-3" role="status">Mật khẩu tạm, chỉ hiển thị một lần: <code>${esc(result.data.temporaryPassword)}</code></div>`; }
    catch (error) { notice(error.message, 'danger'); }
  });
}

async function nutritionFoods() {
  const { data } = await api('/admin/nutrition-foods');
  const entries = [...data, { name: '', kcalPer100g: '', active: true }];
  layout('nutrition-foods', `<div class="row g-3">${entries.map((row, index) => `
    <div class="col-md-6 col-xl-4"><form class="card card-body food-entry" data-index="${index}">
      <h2 class="h5">${row.id ? esc(row.name) : 'Thêm thực phẩm'}</h2>
      <label class="form-label">Tên<input class="form-control" name="name" maxlength="150" value="${esc(row.name)}" required></label>
      <label class="form-label">kcal mỗi 100 g<input class="form-control" name="kcal" type="number" min="0" max="1000" step="0.01" value="${esc(row.kcalPer100g)}" required></label>
      <label class="form-check"><input class="form-check-input" type="checkbox" name="active" ${row.active ? 'checked' : ''}> Cho phép chọn</label>
      <button class="btn btn-primary mt-2">Lưu</button>
    </form></div>`).join('')}</div>`);
  document.querySelectorAll('.food-entry').forEach((form) => {
    form.onsubmit = async (event) => {
      event.preventDefault();
      const row = entries[Number(form.dataset.index)];
      const values = new FormData(form);
      const button = form.querySelector('button');
      button.disabled = true;
      try {
        const { data: saved } = await api(row.id ? `/admin/nutrition-foods/${encodeURIComponent(row.id)}` : '/admin/nutrition-foods',
          row.id ? 'PATCH' : 'POST', {
            name: values.get('name').trim(), kcalPer100g: Number(values.get('kcal')), active: values.has('active'),
          });
        entries[Number(form.dataset.index)] = saved;
        form.querySelector('h2').textContent = saved.name;
        if (!row.id && location.hash === '#/admin/nutrition-foods') await nutritionFoods();
        notice('Đã lưu thực phẩm.');
      } catch (error) {
        notice(error.message, 'danger');
      } finally {
        button.disabled = false;
      }
    };
  });
}

async function coachPackages() {
  const { data } = await api('/admin/coach-packages');
  layout('coach-packages', `<div class="row g-3">${data.map((row, index) => `
    <div class="col-md-6 col-xl-4"><form class="card card-body coach-package" data-index="${index}">
      <h2 class="h5">${esc(row.name)}</h2>
      <p>${esc(row.sessionCount)} buổi · ${esc(row.durationDays)} ngày</p>
      <label class="form-label">Giá (VNĐ)
        <input class="form-control" name="price" type="number" min="0" max="${Number.MAX_SAFE_INTEGER}" step="1" value="${esc(row.price)}" required>
      </label>
      <label class="form-label">Trạng thái
        <select class="form-select" name="status">
          <option value="ACTIVE" ${row.status === 'ACTIVE' ? 'selected' : ''}>Đang bán</option>
          <option value="INACTIVE" ${row.status === 'INACTIVE' ? 'selected' : ''}>Ngừng bán</option>
        </select>
      </label>
      <button class="btn btn-primary mt-2">Lưu gói</button>
    </form></div>`).join('')}</div>`);
  document.querySelectorAll('.coach-package').forEach((form) => {
    form.onsubmit = async (event) => {
      event.preventDefault();
      const values = new FormData(form);
      const button = form.querySelector('button');
      button.disabled = true;
      try {
        const { code } = data[Number(form.dataset.index)];
        await api(`/admin/coach-packages/${encodeURIComponent(code)}`, 'PATCH', {
          price: Number(values.get('price')), status: values.get('status'),
        });
        notice('Đã lưu gói Coach.');
      } catch (error) {
        notice(error.message, 'danger');
      } finally {
        button.disabled = false;
      }
    };
  });
}

async function plans() {
  const { data } = await api('/admin/membership-plans?pageSize=100');
  layout('plans', `<button id="create" class="btn btn-success mb-3">Tạo gói</button>${table(['Tên', 'Giá', 'Ngày', 'Trạng thái', ''], data.map((row) =>
    `<tr><td>${esc(row.name)}</td><td>${currency(row.price)}</td><td>${row.durationDays}</td><td>${esc(row.status)}</td><td><button class="btn btn-outline-primary btn-sm edit" data-id="${row.id}">Sửa</button></td></tr>`))}<div id="editor"></div>`);
  function editor(row) {
    document.querySelector('#editor').innerHTML = `<form id="plan-form" class="card card-body mt-3"><h2 class="h5">${row ? 'Sửa' : 'Tạo'} gói tập</h2>
      <input class="form-control mb-2" name="name" value="${esc(row?.name)}" placeholder="Tên gói" required>
      <textarea class="form-control mb-2" name="description" placeholder="Mô tả">${esc(row?.description)}</textarea>
      <input class="form-control mb-2" name="price" type="number" min="0" value="${row?.price ?? ''}" placeholder="Giá VND" required>
      <input class="form-control mb-2" name="durationDays" type="number" min="1" value="${row?.durationDays ?? ''}" placeholder="Số ngày" required>
      <select class="form-select mb-2" name="status"><option value="ACTIVE" ${row?.status === 'ACTIVE' ? 'selected' : ''}>Đang bán</option><option value="INACTIVE" ${row?.status === 'INACTIVE' ? 'selected' : ''}>Ngừng bán</option></select>
      <button class="btn btn-success align-self-start">Lưu</button></form>`;
    document.querySelector('#plan-form').onsubmit = async (event) => {
      event.preventDefault(); const form = new FormData(event.currentTarget);
      try { await api(row ? `/admin/membership-plans/${row.id}` : '/admin/membership-plans', row ? 'PATCH' : 'POST', {
        name: form.get('name'), description: form.get('description') || null,
        price: Number(form.get('price')), durationDays: Number(form.get('durationDays')), status: form.get('status'),
      }); await plans(); notice('Đã lưu gói tập.'); }
      catch (error) { notice(error.message, 'danger'); }
    };
  }
  document.querySelector('#create').onclick = () => editor(null);
  document.querySelectorAll('.edit').forEach((button) => button.onclick = () => editor(data.find((row) => row.id === button.dataset.id)));
}

async function payments() {
  const [paymentsResult, plansResult, usersResult] = await Promise.all([
    api('/admin/payments'), api('/admin/membership-plans?pageSize=100'), api('/admin/users?role=MEMBER&pageSize=100'),
  ]);
  layout('payments', `<form id="front-desk" class="card card-body mb-4"><h2 class="h5">Thanh toán tại quầy</h2><div class="row g-2">
    <div class="col-md"><select class="form-select" name="memberId" required><option value="">Chọn Member</option>${usersResult.data.filter((row) => row.status === 'ACTIVE').map((row) =>
      `<option value="${row.id}">${esc(row.fullName)} · ${esc(row.email)}</option>`).join('')}</select></div>
    <div class="col-md"><select class="form-select" name="planId" required><option value="">Chọn gói</option>${plansResult.data.filter((row) => row.status === 'ACTIVE').map((row) =>
      `<option value="${row.id}">${esc(row.name)} · ${currency(row.price)}</option>`).join('')}</select></div>
    <div class="col-auto"><button class="btn btn-success">Ghi nhận</button></div></div></form>
    ${table(['Mã', 'Member', 'Gói', 'Số tiền', 'Trạng thái', 'Thao tác'], paymentsResult.data.map((row) =>
      `<tr><td>${esc(row.transactionCode)}</td><td class="small">${esc(row.memberId)}</td><td>${esc(row.planName)}</td><td>${currency(row.amount)}</td><td>${esc(row.status)}</td>
      <td>${row.status === 'PENDING' ? `<button class="btn btn-outline-danger btn-sm cancel" data-id="${row.id}">Hủy</button>` : '—'}</td></tr>`))}`);
  const submissionKey = crypto.randomUUID();
  document.querySelector('#front-desk').onsubmit = async (event) => {
    event.preventDefault(); const form = new FormData(event.currentTarget);
    if (!confirm('Xác nhận đã nhận thanh toán tại quầy?')) return;
    const button = event.currentTarget.querySelector('button'); button.disabled = true;
    try { await api('/admin/front-desk-payments', 'POST', { memberId: form.get('memberId'),
      planId: form.get('planId') }, submissionKey); await payments(); notice('Đã ghi nhận thanh toán.'); }
    catch (error) { notice(error.message, 'danger'); button.disabled = false; }
  };
  document.querySelectorAll('.cancel').forEach((button) => button.onclick = async () => {
    const reason = prompt('Lý do hủy giao dịch:');
    if (!reason?.trim()) return;
    try { await api(`/admin/payments/${button.dataset.id}`, 'PATCH', { status: 'CANCELLED', reason: reason.trim() });
      await payments(); notice('Đã hủy giao dịch.'); }
    catch (error) { notice(error.message, 'danger'); }
  });
}

async function relationships() {
  const [relationshipsResult, coachesResult, transfersResult] = await Promise.all([
    api('/admin/relationships'), api('/admin/users?role=COACH&pageSize=100'), api('/admin/coach-transfers'),
  ]);
  layout('relationships', `${table(['Member', 'Coach', 'Trạng thái', 'Bắt đầu', 'Thao tác'], relationshipsResult.data.map((row) =>
    `<tr><td>${esc(row.memberId)}</td><td>${esc(row.coachId)}</td><td>${esc(row.status)}</td><td>${esc(row.startedAt)}</td>
    <td>${row.status === 'ACTIVE' || row.status === 'PAUSED' ? `<button class="btn btn-outline-primary btn-sm transfer" data-member="${row.memberId}" data-coach="${row.coachId}">Chuyển Coach</button>` : '—'}</td></tr>`))}
    <div id="transfer-editor"></div><h2 class="h5 mt-4">Lịch sử chuyển Coach</h2>
    ${table(['Member', 'Coach cũ', 'Coach mới', 'Lý do'], transfersResult.data.map((row) =>
      `<tr><td>${esc(row.member_id)}</td><td>${esc(row.old_coach_id)}</td><td>${esc(row.new_coach_id)}</td><td>${esc(row.reason)}</td></tr>`))}`);
  document.querySelectorAll('.transfer').forEach((button) => button.onclick = () => {
    document.querySelector('#transfer-editor').innerHTML = `<form id="transfer-form" class="card card-body mt-3"><h2 class="h5">Chuyển Coach</h2>
      <p class="small text-secondary">Member: ${esc(button.dataset.member)}</p>
      <select class="form-select mb-2" name="newCoachId" required><option value="">Chọn Coach mới</option>${coachesResult.data.filter((row) =>
        row.status === 'ACTIVE' && row.id !== button.dataset.coach).map((row) => `<option value="${row.id}">${esc(row.fullName)}</option>`).join('')}</select>
      <textarea class="form-control mb-2" name="reason" placeholder="Lý do chuyển" required></textarea>
      <button class="btn btn-primary align-self-start">Chuyển Coach</button></form>`;
    document.querySelector('#transfer-form').onsubmit = async (event) => {
      event.preventDefault(); const form = new FormData(event.currentTarget);
      if (!confirm('Xác nhận chuyển Coach và kết thúc quan hệ cũ?')) return;
      try { await api('/admin/coach-transfers', 'POST', { memberId: button.dataset.member,
        newCoachId: form.get('newCoachId'), reason: form.get('reason') });
        await relationships(); notice('Đã chuyển Coach.'); }
      catch (error) { notice(error.message, 'danger'); }
    };
  });
}

async function terminations() {
  const { data } = await api('/admin/termination-requests');
  layout('terminations', table(['Coach', 'Lý do', 'Trạng thái', 'Thao tác'], data.map((row) =>
    `<tr><td>${esc(row.coach_id)}</td><td>${esc(row.reason)}</td><td>${esc(row.status)}</td><td>${row.status === 'PENDING' ?
      `<button class="btn btn-outline-success btn-sm decide" data-id="${row.id}" data-value="APPROVED">Duyệt</button> <button class="btn btn-outline-danger btn-sm decide" data-id="${row.id}" data-value="REJECTED">Từ chối</button>` : '—'}</td></tr>`)));
  document.querySelectorAll('.decide').forEach((button) => button.onclick = async () => {
    if (!confirm('Xác nhận xử lý yêu cầu?')) return;
    try { await api(`/admin/termination-requests/${button.dataset.id}`, 'PATCH', { decision: button.dataset.value });
      await terminations(); notice('Đã xử lý yêu cầu.'); }
    catch (error) { notice(error.message, 'danger'); }
  });
}

async function gym() {
  const { data } = await api('/gym-profile');
  layout('gym', `<form id="gym-form" class="card card-body"><label class="form-label">Tên phòng gym<input class="form-control" name="name" value="${esc(data.name)}" required></label>
    <label class="form-label">Địa chỉ<input class="form-control" name="address" value="${esc(data.address)}" required></label>
    <button class="btn btn-success align-self-start">Lưu</button></form>
    <section class="card card-body mt-3" id="checkin-print"><h2 class="h5">Mã QR điểm danh tại quầy</h2>
      <p class="text-secondary">In mã này và đặt tại quầy. Mỗi hội viên có gói tập còn hiệu lực quét để ghi nhận một ngày đến gym.</p>
      <div id="checkin-qr" aria-live="polite">Đang tải mã…</div>
      <div class="d-flex gap-2 mt-3 no-print"><button id="print-checkin" class="btn btn-primary" disabled>In mã QR</button>
      <button id="rotate-checkin" class="btn btn-outline-danger">Đổi mã</button></div>
      <p class="small text-secondary mt-2 no-print">Đổi mã sẽ làm các bản in cũ hết hiệu lực.</p></section>`);
  async function showCode(payload) {
    const dataUrl = await QRCode.toDataURL(payload, { width: 320, margin: 2,
      errorCorrectionLevel: 'M', color: { dark: '#0F1115', light: '#FFFFFF' } });
    document.querySelector('#checkin-qr').innerHTML = `<img src="${dataUrl}" alt="Mã QR điểm danh Meta Gym" width="320" height="320"><p class="fw-semibold mt-2">${esc(data.name)}</p><p>${esc(data.address)}</p>`;
    document.querySelector('#print-checkin').disabled = false;
  }
  try { await showCode((await api('/admin/gym-checkin-code')).data.payload); }
  catch (error) { document.querySelector('#checkin-qr').textContent = error.message; }
  document.querySelector('#print-checkin').onclick = () => window.print();
  document.querySelector('#rotate-checkin').onclick = async () => {
    if (!confirm('Đổi mã sẽ vô hiệu mọi bản đã in. Tiếp tục?')) return;
    try { await showCode((await api('/admin/gym-checkin-code/rotate', 'POST')).data.payload);
      notice('Đã đổi mã. Hãy in bản mới.'); }
    catch (error) { notice(error.message, 'danger'); }
  };
  document.querySelector('#gym-form').onsubmit = async (event) => {
    event.preventDefault(); const form = new FormData(event.currentTarget);
    try { await api('/admin/gym-profile', 'PATCH', { name: form.get('name'), address: form.get('address') });
      await gym(); notice('Đã cập nhật phòng gym.'); }
    catch (error) { notice(error.message, 'danger'); }
  };
}

async function equipment() {
  const { data } = await api('/admin/equipment?pageSize=100');
  layout('equipment', `<button id="create" class="btn btn-success mb-3">Thêm thiết bị</button>${table(['Tên', 'Nhóm', 'Trạng thái', ''], data.map((row) =>
    `<tr><td>${esc(row.name)}</td><td>${esc(row.category)}</td><td>${esc(row.status)}</td><td><button class="btn btn-outline-primary btn-sm edit" data-id="${row.id}">Sửa</button></td></tr>`))}<div id="editor"></div>`);
  function editor(row) {
    document.querySelector('#editor').innerHTML = `<form id="equipment-form" class="card card-body mt-3"><h2 class="h5">${row ? 'Sửa' : 'Thêm'} thiết bị</h2>
      <input class="form-control mb-2" name="name" value="${esc(row?.name)}" placeholder="Tên thiết bị" required>
      <input class="form-control mb-2" name="category" value="${esc(row?.category)}" placeholder="Nhóm" required>
      <textarea class="form-control mb-2" name="steps" placeholder="Các bước sử dụng, mỗi dòng một bước" required>${esc(row?.usageSteps?.join('\n'))}</textarea>
      <select class="form-select mb-2" name="status"><option value="ACTIVE" ${row?.status === 'ACTIVE' ? 'selected' : ''}>Hiển thị</option><option value="HIDDEN" ${row?.status === 'HIDDEN' ? 'selected' : ''}>Ẩn</option></select>
      <button class="btn btn-success align-self-start">Lưu</button></form>`;
    document.querySelector('#equipment-form').onsubmit = async (event) => {
      event.preventDefault(); const form = new FormData(event.currentTarget);
      try { await api(row ? `/admin/equipment/${row.id}` : '/admin/equipment', row ? 'PATCH' : 'POST', {
        name: form.get('name'), category: form.get('category'), status: form.get('status'),
        usageSteps: form.get('steps').split('\n').map((line) => line.trim()).filter(Boolean),
      }); await equipment(); notice('Đã lưu thiết bị.'); }
      catch (error) { notice(error.message, 'danger'); }
    };
  }
  document.querySelector('#create').onclick = () => editor(null);
  document.querySelectorAll('.edit').forEach((button) => button.onclick = () => editor(data.find((row) => row.id === button.dataset.id)));
}

async function profile() {
  const { data } = await api('/users/me');
  layout('profile', `<div class="card card-body mb-3"><strong>${esc(data.fullName)}</strong><span>${esc(data.email)}</span></div>
    <form id="password-form" class="card card-body"><h2 class="h5">Đổi mật khẩu</h2>
    <input class="form-control mb-2" name="currentPassword" type="password" placeholder="Mật khẩu hiện tại" required>
    <input class="form-control mb-2" name="newPassword" type="password" placeholder="Mật khẩu mới" required minlength="8">
    <button class="btn btn-success align-self-start">Đổi mật khẩu</button></form>`);
  document.querySelector('#password-form').onsubmit = async (event) => {
    event.preventDefault(); const form = new FormData(event.currentTarget);
    try { await api('/users/me/password', 'PATCH', { currentPassword: form.get('currentPassword'),
      newPassword: form.get('newPassword') }); signOut(); }
    catch (error) { notice(error.message, 'danger'); }
  };
}

async function route() {
  if (!token) { login(); return; }
  const section = location.hash.replace(/^#\/admin\/?/, '').split('/')[0] || 'dashboard';
  try {
    if (!user) {
      const result = await api('/users/me');
      if (result.data.role !== 'ADMIN') { signOut(); return; }
      user = result.data;
    }
    chart?.destroy(); chart = null;
    const pages = { dashboard, members: () => accounts('MEMBER'),
      coaches: () => accounts('COACH'), plans, 'coach-packages': coachPackages, payments, relationships,
      'nutrition-foods': nutritionFoods,
      terminations, gym, equipment, profile };
    if (!pages[section]) { location.hash = '/admin/dashboard'; return; }
    root.innerHTML = '<div class="p-5 text-secondary" role="status">Đang tải…</div>';
    await pages[section]();
  } catch (error) {
    root.innerHTML = `<div class="container py-5"><div class="alert alert-danger" role="alert">${esc(error.message)}</div><button id="retry" class="btn btn-outline-secondary">Thử lại</button></div>`;
    document.querySelector('#retry').onclick = route;
  }
}

window.addEventListener('hashchange', route);
route();
