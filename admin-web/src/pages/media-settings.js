import { api } from '../services/api.js';
import { esc } from '../components/format.js';
import { icon } from '../components/icons.js';
import { renderErrorState, renderTableSkeleton } from '../components/states.js';
import { renderToggle } from '../components/toggle.js';
import { toast } from '../components/toast.js';

const ALL_FORMATS = ['jpeg', 'png', 'webp', 'avif', 'gif', 'svg'];

export async function renderMediaSettingsPage({ root, shell }) {
  shell({
    section: 'media-settings',
    contentHtml: `<div id="settings-container">${renderTableSkeleton(6)}</div>`,
  });

  const container = root.querySelector('#settings-container');

  async function loadAndRender() {
    try {
      const res = await api('/admin/settings');
      const s = res.data || {};
      const branding = s.site_branding || {};
      const limits = s.upload_limits || {};
      const proc = s.image_processing || {};
      const smtp = s.smtp || {};
      const rate = s.rate_limits || {};
      const maint = s.maintenance_mode || {};
      const allowedSet = new Set(limits.allowedFormats || ALL_FORMATS);

      container.innerHTML = `<form id="media-settings-form" class="media-settings-grid">
        <section class="meta-card p-3">
          <h3 class="card-title mb-3">Thương hiệu & Giao diện</h3>
          <div class="mb-2">
            <label class="form-label" for="set-site-name">Tên hệ thống</label>
            <input type="text" id="set-site-name" class="form-control" value="${esc(branding.siteName || 'Meta Gym Image Server')}" required />
          </div>
          <div class="mb-2">
            <label class="form-label" for="set-logo-url">Logo URL</label>
            <input type="text" id="set-logo-url" class="form-control" value="${esc(branding.logoUrl || '')}" placeholder="https://..." />
          </div>
          <div class="mb-2">
            <label class="form-label" for="set-favicon-url">Favicon URL</label>
            <input type="text" id="set-favicon-url" class="form-control" value="${esc(branding.faviconUrl || '')}" placeholder="https://..." />
          </div>
        </section>

        <section class="meta-card p-3">
          <h3 class="card-title mb-3">Giới hạn Upload & Định dạng</h3>
          <div class="row g-2 mb-2">
            <div class="col-6">
              <label class="form-label" for="set-max-mb">Tối đa mỗi ảnh (MB)</label>
              <input type="number" id="set-max-mb" class="form-control tabular" min="1" max="100" value="${Number(limits.maxFileSizeMb || 10)}" required />
            </div>
            <div class="col-6">
              <label class="form-label" for="set-max-files">Số file tối đa / lần</label>
              <input type="number" id="set-max-files" class="form-control tabular" min="1" max="50" value="${Number(limits.maxFilesPerUpload || 20)}" required />
            </div>
          </div>
          <div class="mb-2">
            <label class="form-label" for="set-def-vis">Quyền truy cập mặc định</label>
            <select id="set-def-vis" class="form-select">
              <option value="private" ${limits.defaultVisibility === 'private' ? 'selected' : ''}>Private</option>
              <option value="public" ${limits.defaultVisibility === 'public' ? 'selected' : ''}>Public</option>
            </select>
          </div>
          <div class="mb-2">
            <span class="form-label d-block">Định dạng cho phép</span>
            <div class="d-flex flex-wrap gap-3">
              ${ALL_FORMATS.map((fmt) => `<label class="form-check">
                <input type="checkbox" class="form-check-input set-fmt-cb" value="${fmt}" ${allowedSet.has(fmt) ? 'checked' : ''} />
                <span class="form-check-label">${fmt.toUpperCase()}</span>
              </label>`).join('')}
            </div>
          </div>
          <div class="mt-2">
            ${renderToggle({ id: 'set-url-import', label: 'Cho phép nhập ảnh từ URL bên ngoài', checked: limits.allowUrlImport !== false })}
          </div>
        </section>

        <section class="meta-card p-3">
          <h3 class="card-title mb-3">Xử lý ảnh Sharp</h3>
          <div class="row g-2 mb-2">
            <div class="col-6">
              <label class="form-label" for="set-thumb-size">Kích thước Thumbnail (px)</label>
              <input type="number" id="set-thumb-size" class="form-control tabular" min="100" max="1200" value="${Number(proc.thumbnailSize || 400)}" required />
            </div>
            <div class="col-6">
              <label class="form-label" for="set-quality">Chất lượng nén mặc định (%)</label>
              <input type="number" id="set-quality" class="form-control tabular" min="10" max="100" value="${Number(proc.defaultQuality || 75)}" required />
            </div>
          </div>
          <div class="d-flex flex-column gap-2 mt-2">
            ${renderToggle({ id: 'set-auto-webp', label: 'Tự động sinh biến thể WebP khi upload', checked: Boolean(proc.autoWebp) })}
            ${renderToggle({ id: 'set-auto-avif', label: 'Tự động sinh biến thể AVIF khi upload', checked: Boolean(proc.autoAvif) })}
            ${renderToggle({ id: 'set-strip-exif', label: 'Tự động gỡ thông tin GPS/EXIF nhạy cảm', checked: Boolean(proc.stripGpsExif) })}
          </div>
        </section>

        <section class="meta-card p-3">
          <h3 class="card-title mb-3">SMTP, Rate Limit & Bảo trì</h3>
          <div class="row g-2 mb-2">
            <div class="col-6">
              <label class="form-label" for="set-rate-api">Rate limit Public API (/phút)</label>
              <input type="number" id="set-rate-api" class="form-control tabular" min="1" max="10000" value="${Number(rate.publicApiPerMinute || 60)}" required />
            </div>
            <div class="col-6">
              <label class="form-label" for="set-rate-upload">Rate limit Upload (/phút)</label>
              <input type="number" id="set-rate-upload" class="form-control tabular" min="1" max="1000" value="${Number(rate.uploadPerMinute || 30)}" required />
            </div>
          </div>
          <div class="row g-2 mb-2">
            <div class="col-8">
              <label class="form-label" for="set-smtp-host">SMTP Host</label>
              <input type="text" id="set-smtp-host" class="form-control" value="${esc(smtp.host || '')}" placeholder="smtp.gmail.com" />
            </div>
            <div class="col-4">
              <label class="form-label" for="set-smtp-port">Port</label>
              <input type="number" id="set-smtp-port" class="form-control tabular" min="1" max="65535" value="${Number(smtp.port || 587)}" />
            </div>
          </div>
          <div class="mb-2">
            <label class="form-label" for="set-smtp-email">Email gửi thông báo</label>
            <input type="text" id="set-smtp-email" class="form-control" value="${esc(smtp.fromEmail || '')}" placeholder="noreply@metagym.vn" />
          </div>
          <div class="d-flex flex-column gap-2 mb-2">
            ${renderToggle({ id: 'set-smtp-enabled', label: 'Bật gửi thông báo qua SMTP', checked: Boolean(smtp.enabled) })}
            ${renderToggle({ id: 'set-maint-enabled', label: 'Chế độ bảo trì (Maintenance Mode)', checked: Boolean(maint.enabled) })}
          </div>
          <div class="mb-2">
            <label class="form-label" for="set-maint-msg">Thông báo bảo trì</label>
            <input type="text" id="set-maint-msg" class="form-control" value="${esc(maint.message || '')}" />
          </div>
        </section>

        <div class="media-settings-footer">
          <button type="submit" class="btn btn-primary" id="btn-save-settings">${icon('check', 16)} Lưu toàn bộ cấu hình</button>
        </div>
      </form>`;

      container.querySelector('#media-settings-form')?.addEventListener('submit', async (event) => {
        event.preventDefault();
        const allowedFormats = [...container.querySelectorAll('.set-fmt-cb')]
          .filter((cb) => cb.checked)
          .map((cb) => cb.value);
        if (!allowedFormats.length) {
          toast('Vui lòng chọn ít nhất 1 định dạng ảnh cho phép.', 'warning');
          return;
        }
        const saveBtn = container.querySelector('#btn-save-settings');
        if (saveBtn) saveBtn.disabled = true;
        try {
          await api('/admin/settings', 'PATCH', {
            site_branding: {
              siteName: container.querySelector('#set-site-name')?.value?.trim(),
              logoUrl: container.querySelector('#set-logo-url')?.value?.trim() || '',
              faviconUrl: container.querySelector('#set-favicon-url')?.value?.trim() || '',
            },
            upload_limits: {
              maxFileSizeMb: Number(container.querySelector('#set-max-mb')?.value || 10),
              maxFilesPerUpload: Number(container.querySelector('#set-max-files')?.value || 20),
              allowedFormats,
              defaultVisibility: container.querySelector('#set-def-vis')?.value || 'private',
              allowUrlImport: Boolean(container.querySelector('#set-url-import')?.checked),
            },
            image_processing: {
              thumbnailSize: Number(container.querySelector('#set-thumb-size')?.value || 400),
              defaultQuality: Number(container.querySelector('#set-quality')?.value || 75),
              autoWebp: Boolean(container.querySelector('#set-auto-webp')?.checked),
              autoAvif: Boolean(container.querySelector('#set-auto-avif')?.checked),
              stripGpsExif: Boolean(container.querySelector('#set-strip-exif')?.checked),
            },
            smtp: {
              enabled: Boolean(container.querySelector('#set-smtp-enabled')?.checked),
              host: container.querySelector('#set-smtp-host')?.value?.trim() || '',
              port: Number(container.querySelector('#set-smtp-port')?.value || 587),
              secure: Boolean(smtp.secure),
              fromEmail: container.querySelector('#set-smtp-email')?.value?.trim() || '',
            },
            rate_limits: {
              publicApiPerMinute: Number(container.querySelector('#set-rate-api')?.value || 60),
              uploadPerMinute: Number(container.querySelector('#set-rate-upload')?.value || 30),
            },
            maintenance_mode: {
              enabled: Boolean(container.querySelector('#set-maint-enabled')?.checked),
              message: container.querySelector('#set-maint-msg')?.value?.trim() || '',
            },
          });
          toast('Đã lưu cấu hình Image Server.', 'success');
        } catch (err) {
          toast(err.message || 'Không thể lưu cấu hình.', 'danger');
        } finally {
          if (saveBtn) saveBtn.disabled = false;
        }
      });
    } catch (err) {
      container.innerHTML = renderErrorState({ title: 'Không tải được cấu hình hệ thống', message: err.message });
      container.querySelector('#retry-load-btn')?.addEventListener('click', loadAndRender);
    }
  }

  await loadAndRender();
}
