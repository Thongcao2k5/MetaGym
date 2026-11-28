import { api } from '../services/api.js';
import { esc, formatBytes, statusBadge } from '../components/format.js';
import { icon } from '../components/icons.js';
import { openConfirmModal, openModal } from '../components/modal.js';
import { renderEmptyState, renderErrorState, renderTableSkeleton } from '../components/states.js';
import { toast } from '../components/toast.js';
import { updateQuery } from '../state/router.js';

let activeCharts = [];

export function destroyAnalyticsCharts() {
  for (const chart of activeCharts) {
    try { chart?.destroy?.(); } catch { /* ignore */ }
  }
  activeCharts = [];
}

function downloadJsonFile(filename, dataObj) {
  if (!globalThis.document?.createElement || !globalThis.URL?.createObjectURL) return;
  const blob = new globalThis.Blob([JSON.stringify(dataObj, null, 2)], { type: 'application/json' });
  const url = globalThis.URL.createObjectURL(blob);
  const a = globalThis.document.createElement('a');
  a.href = url;
  a.download = filename;
  globalThis.document.body?.appendChild(a);
  a.click();
  a.remove();
  globalThis.URL.revokeObjectURL(url);
}

export async function renderMediaAnalyticsPage({ root, params, shell, ChartCtor }) {
  destroyAnalyticsCharts();
  const tab = params?.get('tab') === 'storage' ? 'storage' : 'analytics';

  const tabsHtml = `<div class="media-subnav" role="tablist" aria-label="Analytics và Lưu trữ">
    <button type="button" class="media-subnav-btn" role="tab" aria-selected="${tab === 'analytics'}" data-an-tab="analytics">${icon('chartLine', 15)} Thống kê & Analytics</button>
    <button type="button" class="media-subnav-btn" role="tab" aria-selected="${tab === 'storage'}" data-an-tab="storage">${icon('hardDrive', 15)} Quản lý Lưu trữ & Quota</button>
  </div>`;

  shell({
    section: 'media-analytics',
    contentHtml: `${tabsHtml}<div id="analytics-tab-body">${renderTableSkeleton(6)}</div>`,
  });

  const bodyEl = root.querySelector('#analytics-tab-body');
  root.querySelectorAll('[data-an-tab]').forEach((btn) => {
    btn.addEventListener('click', () => updateQuery({ tab: btn.getAttribute('data-an-tab') }, { replace: false }));
  });

  async function renderAnalyticsTab() {
    try {
      const [statsRes, anRes] = await Promise.all([api('/stats'), api('/analytics/overview')]);
      const stats = statsRes.data || {};
      const an = anRes.data || {};
      const apiReq = an.apiRequests || {};

      bodyEl.innerHTML = `
        <section class="media-kpi-strip mb-3">
          <article class="kpi-card">
            <div class="kpi-label">Lượt xem thực tế</div>
            <div class="kpi-value tabular" style="color:var(--meta-success)">${Number(an.realViews || 0)}</div>
          </article>
          <article class="kpi-card">
            <div class="kpi-label">Lượt truy cập Bot</div>
            <div class="kpi-value tabular" style="color:var(--meta-warning)">${Number(an.botViews || 0)}</div>
          </article>
          <article class="kpi-card">
            <div class="kpi-label">Băng thông phục vụ</div>
            <div class="kpi-value tabular">${formatBytes(an.totalBandwidthBytes || 0)}</div>
          </article>
          <article class="kpi-card">
            <div class="kpi-label">API Requests (${Number(apiReq.avgResponseMs || 0)} ms TB)</div>
            <div class="kpi-value tabular">${Number(apiReq.totalRequests || 0)}</div>
          </article>
        </section>

        <section class="media-charts-grid mb-3">
          <div class="meta-card p-3">
            <h3 class="card-title mb-2">Upload 14 ngày gần nhất</h3>
            <div class="chart-box"><canvas id="chart-uploads-daily"></canvas></div>
          </div>
          <div class="meta-card p-3">
            <h3 class="card-title mb-2">Lượt xem Thực tế vs Bot</h3>
            <div class="chart-box"><canvas id="chart-views-bot"></canvas></div>
          </div>
          <div class="meta-card p-3">
            <h3 class="card-title mb-2">Phân bổ HTTP Status Code API</h3>
            <div class="chart-box"><canvas id="chart-api-status"></canvas></div>
          </div>
        </section>

        <section class="media-collections-grid">
          <div class="meta-card p-3">
            <h3 class="card-title mb-2">Top ảnh được xem nhiều</h3>
            ${!an.topViewed?.length
              ? renderEmptyState({ title: 'Chưa có lượt xem nào', message: 'Lượt xem công khai hoặc qua link chia sẻ sẽ thống kê tại đây.' })
              : `<div class="table-responsive"><table class="table table-sm align-middle mb-0 tabular">
                  <thead><tr><th>Tên ảnh</th><th>Kích thước</th><th>Lượt xem</th><th>Lượt tải</th></tr></thead>
                  <tbody>${an.topViewed.map((r) => `<tr>
                    <td><strong>${esc(r.filename)}</strong></td>
                    <td>${formatBytes(r.sizeBytes)}</td>
                    <td>${Number(r.viewCount || 0)}</td>
                    <td>${Number(r.downloadCount || 0)}</td>
                  </tr>`).join('')}</tbody>
                </table></div>`}
          </div>

          <div class="meta-card p-3">
            <h3 class="card-title mb-2">Top ảnh được tải nhiều</h3>
            ${!an.topDownloaded?.length
              ? renderEmptyState({ title: 'Chưa có lượt tải nào', message: 'Số lượt tải xuống tệp gốc sẽ hiển thị tại đây.' })
              : `<div class="table-responsive"><table class="table table-sm align-middle mb-0 tabular">
                  <thead><tr><th>Tên ảnh</th><th>Kích thước</th><th>Lượt tải</th><th>Lượt xem</th></tr></thead>
                  <tbody>${an.topDownloaded.map((r) => `<tr>
                    <td><strong>${esc(r.filename)}</strong></td>
                    <td>${formatBytes(r.sizeBytes)}</td>
                    <td>${Number(r.downloadCount || 0)}</td>
                    <td>${Number(r.viewCount || 0)}</td>
                  </tr>`).join('')}</tbody>
                </table></div>`}
          </div>
        </section>
      `;

      if (typeof ChartCtor === 'function') {
        const gridColor = 'rgba(255, 255, 255, 0.08)';
        const textColor = '#8E95A5';

        const uploadCanvas = bodyEl.querySelector('#chart-uploads-daily');
        if (uploadCanvas) {
          const uploadDays = stats.uploadsByDay || [];
          activeCharts.push(new ChartCtor(uploadCanvas, {
            type: 'bar',
            data: {
              labels: uploadDays.map((d) => d.day.slice(5)),
              datasets: [{
                label: 'Số ảnh upload',
                data: uploadDays.map((d) => d.uploads),
                backgroundColor: '#FF5E36',
                borderRadius: 6,
              }],
            },
            options: {
              responsive: true,
              maintainAspectRatio: false,
              scales: {
                x: { grid: { color: gridColor }, ticks: { color: textColor } },
                y: { beginAtZero: true, grid: { color: gridColor }, ticks: { color: textColor, precision: 0 } },
              },
            },
          }));
        }

        const viewsCanvas = bodyEl.querySelector('#chart-views-bot');
        if (viewsCanvas) {
          const viewDays = an.viewsByDay || [];
          activeCharts.push(new ChartCtor(viewsCanvas, {
            type: 'line',
            data: {
              labels: viewDays.map((d) => d.day.slice(5)),
              datasets: [
                { label: 'Người dùng thật', data: viewDays.map((d) => d.realViews), borderColor: '#2ECC71', backgroundColor: 'rgba(46,204,113,0.18)', tension: 0.3 },
                { label: 'Bot / Crawler', data: viewDays.map((d) => d.botViews), borderColor: '#F39C12', backgroundColor: 'rgba(243,156,18,0.18)', tension: 0.3 },
              ],
            },
            options: {
              responsive: true,
              maintainAspectRatio: false,
              scales: {
                x: { grid: { color: gridColor }, ticks: { color: textColor } },
                y: { beginAtZero: true, grid: { color: gridColor }, ticks: { color: textColor, precision: 0 } },
              },
            },
          }));
        }

        const statusCanvas = bodyEl.querySelector('#chart-api-status');
        if (statusCanvas) {
          activeCharts.push(new ChartCtor(statusCanvas, {
            type: 'doughnut',
            data: {
              labels: ['2xx OK', '3xx Redirect', '4xx Client Err', '5xx Server Err'],
              datasets: [{
                data: [
                  Number(apiReq.status2xx || 0),
                  Number(apiReq.status3xx || 0),
                  Number(apiReq.status4xx || 0),
                  Number(apiReq.status5xx || 0),
                ],
                backgroundColor: ['#2ECC71', '#70AEE8', '#F39C12', '#F15B64'],
                borderWidth: 0,
              }],
            },
            options: { responsive: true, maintainAspectRatio: false },
          }));
        }
      }
    } catch (err) {
      bodyEl.innerHTML = renderErrorState({ title: 'Không tải được dữ liệu Analytics', message: err.message });
    }
  }

  async function renderStorageTab() {
    try {
      const [sumRes, usersRes] = await Promise.all([
        api('/admin/storage/summary'),
        api('/admin/image-users'),
      ]);
      const sum = sumRes.data || {};
      const users = usersRes.data || [];
      const health = sum.providerHealth || {};

      bodyEl.innerHTML = `
        <section class="media-kpi-strip mb-3">
          <article class="kpi-card">
            <div class="kpi-label">Storage Provider</div>
            <div class="kpi-value" style="font-size:20px">${esc((health.provider || 'local').toUpperCase())} ${statusBadge(health.status === 'healthy' ? 'ACTIVE' : 'FAILED', health.status || 'unknown')}</div>
          </article>
          <article class="kpi-card">
            <div class="kpi-label">Tổng dung lượng (Gốc + Biến thể)</div>
            <div class="kpi-value tabular">${formatBytes(sum.totalBytes || 0)}</div>
          </article>
          <article class="kpi-card">
            <div class="kpi-label">Ảnh gốc / Biến thể</div>
            <div class="kpi-value tabular">${Number(sum.imageCount || 0)} / ${Number(sum.variantCount || 0)}</div>
          </article>
          <article class="kpi-card">
            <div class="kpi-label">Thao tác bảo trì</div>
            <div class="d-flex flex-wrap gap-2 mt-2">
              <button type="button" class="btn btn-graphite btn-sm" id="btn-scan-orphans">${icon('search', 14)} Quét file mồ côi</button>
              <button type="button" class="btn btn-graphite btn-sm" id="btn-backup-meta">${icon('download', 14)} Backup JSON</button>
              <button type="button" class="btn btn-graphite btn-sm" id="btn-restore-meta">${icon('upload', 14)} Restore</button>
            </div>
          </article>
        </section>

        <div id="orphan-scan-box" hidden class="meta-card p-3 mb-3"></div>

        <section class="media-collections-grid mb-3">
          <div class="meta-card p-3">
            <h3 class="card-title mb-2">Phân bổ theo định dạng</h3>
            ${!sum.byFormat?.length
              ? renderEmptyState({ title: 'Chưa có tệp ảnh nào', message: 'Thống kê dung lượng theo định dạng sẽ xuất hiện sau khi upload.' })
              : `<div class="table-responsive"><table class="table table-sm align-middle mb-0 tabular">
                  <thead><tr><th>Định dạng</th><th>MIME</th><th>Số lượng</th><th>Dung lượng</th></tr></thead>
                  <tbody>${sum.byFormat.map((f) => `<tr>
                    <td><strong>${esc(f.extension.toUpperCase())}</strong></td>
                    <td><code>${esc(f.mimeType)}</code></td>
                    <td>${Number(f.count || 0)}</td>
                    <td>${formatBytes(f.totalBytes)}</td>
                  </tr>`).join('')}</tbody>
                </table></div>`}
          </div>

          <div class="meta-card p-3">
            <h3 class="card-title mb-2">Danh sách Storage Providers</h3>
            <div class="table-responsive"><table class="table table-sm align-middle mb-0">
              <thead><tr><th>Tên</th><th>Loại</th><th>Mặc định</th><th>Trạng thái</th></tr></thead>
              <tbody>${(sum.providers || []).map((p) => `<tr>
                <td><strong>${esc(p.name)}</strong></td>
                <td><code>${esc(p.type)}</code></td>
                <td>${p.is_default ? 'Mặc định' : '—'}</td>
                <td>${statusBadge(p.is_active ? 'ACTIVE' : 'INACTIVE', p.is_active ? 'Bật' : 'Tắt')}</td>
              </tr>`).join('')}</tbody>
            </table></div>
          </div>
        </section>

        <section class="meta-card p-3">
          <h3 class="card-title mb-2">Quản lý Quota người dùng</h3>
          <div class="table-responsive"><table class="table table-hover align-middle mb-0">
            <thead><tr>
              <th>Người dùng</th>
              <th>Vai trò RBAC</th>
              <th>Số ảnh</th>
              <th>Mức sử dụng Quota</th>
              <th>Thao tác</th>
            </tr></thead>
            <tbody>${users.map((u) => {
              const pct = u.storageQuotaBytes > 0 ? Math.min(100, Math.round((u.storageUsedBytes / u.storageQuotaBytes) * 100)) : 0;
              const cls = pct >= 90 ? 'full' : pct >= 70 ? 'near' : '';
              return `<tr>
                <td>
                  <div class="fw-semibold">${esc(u.fullName)}</div>
                  <div class="text-secondary" style="font-size:12px">${esc(u.email)}</div>
                </td>
                <td><code>${esc(u.roleCode)}</code></td>
                <td class="tabular">${Number(u.imageCount || 0)}</td>
                <td style="min-width:220px">
                  <div class="d-flex justify-content-between tabular" style="font-size:12px">
                    <span>${formatBytes(u.storageUsedBytes)} / ${formatBytes(u.storageQuotaBytes)}</span>
                    <span>${pct}%</span>
                  </div>
                  <div class="seat-track mt-1"><div class="seat-fill ${cls}" style="width:${pct}%"></div></div>
                </td>
                <td>
                  <button type="button" class="btn btn-graphite btn-sm edit-quota-btn" data-id="${esc(u.id)}" data-name="${esc(u.fullName)}" data-quota="${u.storageQuotaBytes}" data-role="${esc(u.roleCode)}">
                    ${icon('edit', 14)} Sửa Quota
                  </button>
                </td>
              </tr>`;
            }).join('')}</tbody>
          </table></div>
        </section>
      `;

      bodyEl.querySelectorAll('.edit-quota-btn').forEach((btn) => {
        btn.addEventListener('click', () => {
          const id = btn.getAttribute('data-id');
          const name = btn.getAttribute('data-name');
          const curMb = Math.round(Number(btn.getAttribute('data-quota') || 1073741824) / (1024 * 1024));
          const curRole = btn.getAttribute('data-role') || 'user';
          openModal({
            title: `Cập nhật Quota — ${name}`,
            maxWidth: '440px',
            bodyHtml: `<form id="quota-form">
              <div class="mb-3">
                <label class="form-label" for="qt-mb">Giới hạn dung lượng (MB)</label>
                <input type="number" id="qt-mb" class="form-control tabular" min="1" max="1048576" value="${curMb}" required />
              </div>
              <div class="mb-2">
                <label class="form-label" for="qt-role">Vai trò RBAC Image Server</label>
                <select id="qt-role" class="form-select">
                  <option value="user" ${curRole === 'user' ? 'selected' : ''}>user</option>
                  <option value="admin" ${curRole === 'admin' ? 'selected' : ''}>admin</option>
                  <option value="super_admin" ${curRole === 'super_admin' ? 'selected' : ''}>super_admin</option>
                </select>
              </div>
            </form>`,
            footerHtml: `<button type="button" class="btn btn-ghost" data-close-modal>Hủy</button>
              <button type="submit" form="quota-form" class="btn btn-primary">Lưu Quota</button>`,
            onMount: (modal) => {
              modal.dialog.querySelector('#quota-form')?.addEventListener('submit', async (e) => {
                e.preventDefault();
                const mb = Number(modal.dialog.querySelector('#qt-mb')?.value || 1024);
                try {
                  await api(`/admin/image-users/${id}/quota`, 'PATCH', {
                    storageQuotaBytes: mb * 1024 * 1024,
                    roleCode: modal.dialog.querySelector('#qt-role')?.value,
                  });
                  toast('Đã cập nhật quota lưu trữ.', 'success');
                  modal.close();
                  await renderStorageTab();
                } catch (err) {
                  toast(err.message || 'Không thể cập nhật quota.', 'danger');
                }
              });
            },
          });
        });
      });

      const scanBox = bodyEl.querySelector('#orphan-scan-box');
      bodyEl.querySelector('#btn-scan-orphans')?.addEventListener('click', async () => {
        try {
          const res = await api('/admin/storage/scan-orphans', 'POST');
          const d = res.data;
          if (scanBox) {
            scanBox.hidden = false;
            scanBox.innerHTML = `<div class="d-flex justify-content-between align-items-center mb-2">
              <strong>Kết quả quét file mồ côi</strong>
              ${d.orphanFiles?.length ? `<button type="button" class="btn btn-danger btn-sm" id="btn-clean-orphans">${icon('trash', 14)} Dọn ${d.orphanFiles.length} file mồ côi</button>` : ''}
            </div>
            <p class="mb-1 tabular" style="font-size:13px">Đã quét <strong>${d.scannedStorageCount}</strong> object trên Storage · <strong>${d.scannedDbCount}</strong> bản ghi trong DB.</p>
            <p class="mb-0 text-secondary" style="font-size:12px">File mồ côi trên storage: ${d.orphanFiles?.length || 0} · Bản ghi DB mất file: ${d.missingInStorage?.length || 0}</p>`;

            scanBox.querySelector('#btn-clean-orphans')?.addEventListener('click', () => {
              openConfirmModal({
                title: 'Xác nhận dọn file mồ côi',
                message: `Sẽ xóa ${d.orphanFiles.length} file trên Storage không còn liên kết trong Database.`,
                confirmLabel: 'Xóa file mồ côi',
                confirmClass: 'btn-danger',
                onConfirm: async () => {
                  await api('/admin/storage/cleanup-orphans', 'POST', { keys: d.orphanFiles });
                  toast('Đã dọn sạch file mồ côi.', 'success');
                  scanBox.hidden = true;
                },
              });
            });
          }
        } catch (err) {
          toast(err.message || 'Không thể quét file mồ côi.', 'danger');
        }
      });

      bodyEl.querySelector('#btn-backup-meta')?.addEventListener('click', async () => {
        try {
          const res = await api('/admin/storage/backup-metadata', 'POST');
          downloadJsonFile(`metagym-image-metadata-${new Date().toISOString().slice(0, 10)}.json`, res.data);
          toast('Đã xuất tệp sao lưu metadata JSON.', 'success');
        } catch (err) {
          toast(err.message || 'Không thể sao lưu metadata.', 'danger');
        }
      });

      bodyEl.querySelector('#btn-restore-meta')?.addEventListener('click', () => {
        openModal({
          title: 'Khôi phục Metadata từ JSON',
          maxWidth: '520px',
          bodyHtml: `<form id="restore-meta-form">
            <label class="form-label" for="rm-json">Dán nội dung JSON sao lưu metadata</label>
            <textarea id="rm-json" class="form-control" rows="8" required placeholder='{"systemSettings":{},"tags":[],"folders":[],"albums":[]}'></textarea>
          </form>`,
          footerHtml: `<button type="button" class="btn btn-ghost" data-close-modal>Hủy</button>
            <button type="submit" form="restore-meta-form" class="btn btn-primary">Khôi phục</button>`,
          onMount: (modal) => {
            modal.dialog.querySelector('#restore-meta-form')?.addEventListener('submit', async (e) => {
              e.preventDefault();
              let parsed;
              try {
                parsed = JSON.parse(modal.dialog.querySelector('#rm-json')?.value || '{}');
              } catch {
                toast('JSON không hợp lệ.', 'danger');
                return;
              }
              try {
                await api('/admin/storage/restore-metadata', 'POST', {
                  systemSettings: parsed.systemSettings,
                  tags: parsed.tags,
                  folders: parsed.folders,
                  albums: parsed.albums,
                });
                toast('Đã khôi phục metadata thành công.', 'success');
                modal.close();
                await renderStorageTab();
              } catch (err) {
                toast(err.message || 'Không thể khôi phục metadata.', 'danger');
              }
            });
          },
        });
      });
    } catch (err) {
      bodyEl.innerHTML = renderErrorState({ title: 'Không tải được thông tin lưu trữ', message: err.message });
    }
  }

  if (tab === 'storage') await renderStorageTab();
  else await renderAnalyticsTab();
}
