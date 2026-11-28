import { api, getApiBaseUrl } from '../services/api.js';
import { esc, formatDateTimeVN, statusBadge } from '../components/format.js';
import { icon } from '../components/icons.js';
import { openDrawer } from '../components/drawer.js';
import { openConfirmModal, openModal } from '../components/modal.js';
import { renderEmptyState, renderErrorState, renderTableSkeleton } from '../components/states.js';
import { toast } from '../components/toast.js';
import { updateQuery } from '../state/router.js';

const ALL_SCOPES = [
  { id: 'images:read', label: 'images:read (Xem & tải ảnh)' },
  { id: 'images:write', label: 'images:write (Upload, sửa & transform)' },
  { id: 'images:delete', label: 'images:delete (Xóa ảnh & biến thể)' },
  { id: 'folders:read', label: 'folders:read (Xem thư mục)' },
  { id: 'folders:write', label: 'folders:write (Tạo/sửa/xóa thư mục)' },
  { id: 'albums:read', label: 'albums:read (Xem album)' },
  { id: 'albums:write', label: 'albums:write (Quản lý album)' },
];

function resolveFullUrl(path) {
  const base = getApiBaseUrl();
  const origin = globalThis.window?.location?.origin || '';
  if (path.startsWith('/api/v1')) return `${origin}${base}${path.slice('/api/v1'.length)}`;
  return `${origin}${base}${path}`;
}

async function copyText(text, label) {
  try {
    if (globalThis.navigator?.clipboard?.writeText) {
      await globalThis.navigator.clipboard.writeText(text);
    }
    toast(`Đã sao chép ${label}.`, 'success');
  } catch {
    toast(`Không thể sao chép ${label}.`, 'warning');
  }
}

export async function renderMediaSharingPage({ root, params, shell }) {
  const tab = params?.get('tab') === 'api-keys' ? 'api-keys' : 'shares';

  const tabsHtml = `<div class="media-subnav" role="tablist" aria-label="Chia sẻ và API Keys">
    <button type="button" class="media-subnav-btn" role="tab" aria-selected="${tab === 'shares'}" data-share-tab="shares">${icon('share', 15)} Liên kết chia sẻ</button>
    <button type="button" class="media-subnav-btn" role="tab" aria-selected="${tab === 'api-keys'}" data-share-tab="api-keys">${icon('key', 15)} API Keys & Public API</button>
  </div>`;

  const topbarActionsHtml = `<a class="btn btn-graphite btn-sm" href="/api-docs" target="_blank" rel="noopener">${icon('externalLink', 15)} Swagger API Docs</a>
    ${tab === 'api-keys' ? `<button type="button" class="btn btn-primary btn-sm" id="btn-create-apikey">${icon('plus', 15)} Tạo API Key</button>` : ''}`;

  shell({
    section: 'media-sharing',
    topbarActionsHtml,
    contentHtml: `${tabsHtml}<div id="sharing-tab-body">${renderTableSkeleton(5)}</div>`,
  });

  const bodyEl = root.querySelector('#sharing-tab-body');
  root.querySelectorAll('[data-share-tab]').forEach((btn) => {
    btn.addEventListener('click', () => updateQuery({ tab: btn.getAttribute('data-share-tab') }, { replace: false }));
  });

  async function renderSharesTab() {
    try {
      const res = await api('/shares');
      const shares = res.data || [];

      if (!shares.length) {
        bodyEl.innerHTML = renderEmptyState({
          title: 'Chưa có liên kết chia sẻ nào',
          message: 'Vào "Thư viện ảnh" và bấm biểu tượng Chia sẻ trên bất kỳ ảnh hoặc Album nào.',
        });
        return;
      }

      bodyEl.innerHTML = `<div class="meta-card p-0 overflow-hidden"><div class="table-responsive"><table class="table table-hover align-middle mb-0">
        <thead><tr>
          <th>Đối tượng</th>
          <th>Loại</th>
          <th>Bảo vệ</th>
          <th>Lượt truy cập</th>
          <th>Hết hạn</th>
          <th>Trạng thái</th>
          <th>Thao tác</th>
        </tr></thead>
        <tbody>${shares.map((s) => {
          const isRevoked = Boolean(s.revokedAt);
          const isExpired = s.expiresAt && new Date(s.expiresAt).getTime() <= Date.now();
          const statusHtml = isRevoked
            ? statusBadge('CANCELLED', 'Đã thu hồi')
            : isExpired
              ? statusBadge('EXPIRED', 'Hết hạn')
              : statusBadge('ACTIVE', 'Đang hoạt động');
          const fullUrl = resolveFullUrl(s.shareUrl);
          return `<tr>
            <td><strong>${esc(s.targetLabel)}</strong></td>
            <td>${s.targetType === 'album' ? 'Album' : 'Hình ảnh'}</td>
            <td>
              ${s.hasPassword ? '<span class="meta-badge meta-badge-warning">Có mật khẩu</span>' : '<span class="meta-badge meta-badge-neutral">Không MK</span>'}
              ${s.allowDownload ? '<span class="meta-badge meta-badge-info">Cho tải</span>' : '<span class="meta-badge meta-badge-neutral">Chặn tải</span>'}
            </td>
            <td class="tabular">${Number(s.accessCount || 0)}</td>
            <td class="tabular">${s.expiresAt ? formatDateTimeVN(s.expiresAt) : 'Vĩnh viễn'}</td>
            <td>${statusHtml}</td>
            <td>
              <div class="d-flex gap-1">
                <button type="button" class="btn btn-graphite btn-icon btn-sm share-copy-btn" data-url="${esc(fullUrl)}" title="Copy link">${icon('copy', 15)}</button>
                ${!isRevoked ? `<button type="button" class="btn btn-graphite btn-icon btn-sm share-revoke-btn" data-id="${esc(s.id)}" data-label="${esc(s.targetLabel)}" title="Thu hồi">${icon('trash', 15)}</button>` : ''}
              </div>
            </td>
          </tr>`;
        }).join('')}</tbody>
      </table></div></div>`;

      bodyEl.querySelectorAll('.share-copy-btn').forEach((btn) => {
        btn.addEventListener('click', () => copyText(btn.getAttribute('data-url'), 'link chia sẻ'));
      });
      bodyEl.querySelectorAll('.share-revoke-btn').forEach((btn) => {
        btn.addEventListener('click', () => {
          const id = btn.getAttribute('data-id');
          const label = btn.getAttribute('data-label');
          openConfirmModal({
            title: 'Thu hồi liên kết chia sẻ',
            message: `Liên kết chia sẻ cho "${label}" sẽ ngừng hoạt động ngay lập tức.`,
            confirmLabel: 'Thu hồi ngay',
            confirmClass: 'btn-danger',
            onConfirm: async () => {
              await api(`/shares/${id}`, 'DELETE');
              toast('Đã thu hồi liên kết chia sẻ.', 'success');
              await renderSharesTab();
            },
          });
        });
      });
    } catch (err) {
      bodyEl.innerHTML = renderErrorState({ title: 'Không tải được danh sách chia sẻ', message: err.message });
    }
  }

  async function renderApiKeysTab() {
    let createdSecretBanner = '';
    const renderKeyList = async (revealPayload = null) => {
      try {
        const res = await api('/api-keys');
        const keys = res.data || [];

        if (revealPayload?.apiKey) {
          createdSecretBanner = `<div class="meta-card p-3 mb-3 media-secret-banner">
            <div class="d-flex justify-content-between align-items-center mb-2">
              <strong>${icon('key', 16)} API Key mới đã được tạo — chỉ hiển thị 1 lần duy nhất!</strong>
              <button type="button" class="btn btn-graphite btn-sm" id="copy-new-apikey">${icon('copy', 15)} Sao chép Key</button>
            </div>
            <code class="d-block p-2" style="word-break:break-all">${esc(revealPayload.apiKey)}</code>
          </div>`;
        }

        const tableHtml = !keys.length
          ? renderEmptyState({
              title: 'Chưa có API Key nào',
              message: 'Tạo API Key với header X-API-Key để tích hợp Upload/Quản lý ảnh từ hệ thống ngoài.',
            })
          : `<div class="meta-card p-0 overflow-hidden"><div class="table-responsive"><table class="table table-hover align-middle mb-0">
              <thead><tr>
                <th>Tên Key</th>
                <th>Prefix</th>
                <th>Phạm vi (Scopes)</th>
                <th>Rate Limit</th>
                <th>Requests</th>
                <th>Dùng lần cuối</th>
                <th>Trạng thái</th>
                <th>Thao tác</th>
              </tr></thead>
              <tbody>${keys.map((k) => {
                const revoked = Boolean(k.revokedAt);
                const expired = k.expiresAt && new Date(k.expiresAt).getTime() <= Date.now();
                const statusHtml = revoked
                  ? statusBadge('CANCELLED', 'Đã thu hồi')
                  : expired
                    ? statusBadge('EXPIRED', 'Hết hạn')
                    : statusBadge('ACTIVE', 'Hoạt động');
                return `<tr>
                  <td><strong>${esc(k.name)}</strong></td>
                  <td><code>${esc(k.keyPrefix)}…</code></td>
                  <td><div class="d-flex flex-wrap gap-1">${(k.scopes || []).map((sc) => `<span class="meta-badge meta-badge-info">${esc(sc)}</span>`).join('')}</div></td>
                  <td class="tabular">${Number(k.rateLimitPerMinute || 60)}/phút</td>
                  <td class="tabular">${Number(k.requestCount || 0)}</td>
                  <td class="tabular">${k.lastUsedAt ? formatDateTimeVN(k.lastUsedAt) : 'Chưa dùng'}</td>
                  <td>${statusHtml}</td>
                  <td>
                    <div class="d-flex gap-1">
                      <button type="button" class="btn btn-graphite btn-icon btn-sm apikey-usage-btn" data-id="${esc(k.id)}" title="Lịch sử dùng">${icon('chartBar', 15)}</button>
                      ${!revoked ? `<button type="button" class="btn btn-graphite btn-icon btn-sm apikey-revoke-btn" data-id="${esc(k.id)}" data-name="${esc(k.name)}" title="Thu hồi">${icon('trash', 15)}</button>` : ''}
                    </div>
                  </td>
                </tr>`;
              }).join('')}</tbody>
            </table></div></div>`;

        bodyEl.innerHTML = `${createdSecretBanner}${tableHtml}`;

        bodyEl.querySelector('#copy-new-apikey')?.addEventListener('click', () => copyText(revealPayload.apiKey, 'API Key'));

        bodyEl.querySelectorAll('.apikey-usage-btn').forEach((btn) => {
          btn.addEventListener('click', async () => {
            const id = btn.getAttribute('data-id');
            openDrawer({ title: 'Thống kê API Key', bodyHtml: renderTableSkeleton(4) });
            try {
              const uRes = await api(`/api-keys/${id}/usage`);
              const u = uRes.data;
              openDrawer({
                title: `Usage — ${u.name}`,
                bodyHtml: `<div class="meta-card p-3 mb-3">
                  <dl class="detail-kv tabular mb-0">
                    <div><dt>Prefix</dt><dd><code>${esc(u.keyPrefix)}…</code></dd></div>
                    <div><dt>Tổng Request</dt><dd>${Number(u.requestCount || 0)}</dd></div>
                    <div><dt>Thành công (2xx/3xx)</dt><dd>${Number(u.summary?.ok_count || 0)}</dd></div>
                    <div><dt>Lỗi Client / Server</dt><dd>${Number(u.summary?.client_err_count || 0)} / ${Number(u.summary?.server_err_count || 0)}</dd></div>
                    <div><dt>Thời gian TB</dt><dd>${Math.round(Number(u.summary?.avg_ms || 0))} ms</dd></div>
                  </dl>
                </div>
                <h5 class="card-title mb-2">30 Request gần nhất</h5>
                ${!u.recentLogs?.length
                  ? '<p class="text-secondary">Chưa có log API nào.</p>'
                  : `<div class="table-responsive"><table class="table table-sm tabular">
                    <thead><tr><th>Method</th><th>Endpoint</th><th>Status</th><th>ms</th></tr></thead>
                    <tbody>${u.recentLogs.map((l) => `<tr><td><code>${esc(l.method)}</code></td><td><code>${esc(l.endpoint)}</code></td><td>${l.status_code}</td><td>${l.response_time_ms ?? 0}</td></tr>`).join('')}</tbody>
                  </table></div>`}`,
              });
            } catch (err) {
              openDrawer({ title: 'Thống kê API Key', bodyHtml: renderErrorState({ title: 'Lỗi tải usage', message: err.message }) });
            }
          });
        });

        bodyEl.querySelectorAll('.apikey-revoke-btn').forEach((btn) => {
          btn.addEventListener('click', () => {
            const id = btn.getAttribute('data-id');
            const name = btn.getAttribute('data-name');
            openConfirmModal({
              title: 'Thu hồi API Key',
              message: `API Key "${name}" sẽ ngừng hoạt động ngay lập tức.`,
              confirmLabel: 'Thu hồi API Key',
              confirmClass: 'btn-danger',
              onConfirm: async () => {
                await api(`/api-keys/${id}`, 'DELETE');
                toast('Đã thu hồi API Key.', 'success');
                createdSecretBanner = '';
                await renderKeyList();
              },
            });
          });
        });
      } catch (err) {
        bodyEl.innerHTML = renderErrorState({ title: 'Không tải được API Keys', message: err.message });
      }
    };

    root.querySelector('#btn-create-apikey')?.addEventListener('click', () => {
      openModal({
        title: 'Tạo API Key mới',
        maxWidth: '520px',
        bodyHtml: `<form id="create-apikey-form" class="meta-form-stack">
          <div class="mb-3">
            <label class="form-label" for="ak-name">Tên API Key</label>
            <input type="text" id="ak-name" class="form-control" required maxlength="120" placeholder="Ví dụ: Mobile App Production" />
          </div>
          <div class="mb-3">
            <label class="form-label" for="ak-rate">Giới hạn (requests / phút)</label>
            <input type="number" id="ak-rate" class="form-control tabular" min="1" max="10000" value="60" required />
          </div>
          <div class="mb-2">
            <span class="form-label d-block">Phạm vi quyền (Scopes)</span>
            <div class="d-flex flex-column gap-1">
              ${ALL_SCOPES.map((sc) => `<label class="form-check">
                <input type="checkbox" class="form-check-input ak-scope-cb" value="${esc(sc.id)}" ${sc.id === 'images:read' || sc.id === 'images:write' ? 'checked' : ''} />
                <span class="form-check-label">${esc(sc.label)}</span>
              </label>`).join('')}
            </div>
          </div>
        </form>`,
        footerHtml: `<button type="button" class="btn btn-ghost" data-close-modal>Hủy</button>
          <button type="submit" form="create-apikey-form" class="btn btn-primary">${icon('key', 15)} Tạo API Key</button>`,
        onMount: (modal) => {
          modal.dialog.querySelector('#create-apikey-form')?.addEventListener('submit', async (e) => {
            e.preventDefault();
            const scopes = [...modal.dialog.querySelectorAll('.ak-scope-cb')]
              .filter((cb) => cb.checked)
              .map((cb) => cb.value);
            if (!scopes.length) {
              toast('Vui lòng chọn ít nhất 1 quyền (scope).', 'warning');
              return;
            }
            try {
              const res = await api('/api-keys', 'POST', {
                name: modal.dialog.querySelector('#ak-name')?.value?.trim(),
                rateLimitPerMinute: Number(modal.dialog.querySelector('#ak-rate')?.value || 60),
                scopes,
              });
              toast('Đã tạo API Key mới.', 'success');
              modal.close();
              await renderKeyList(res.data);
            } catch (err) {
              toast(err.message || 'Không thể tạo API Key.', 'danger');
            }
          });
        },
      });
    });

    await renderKeyList();
  }

  if (tab === 'api-keys') await renderApiKeysTab();
  else await renderSharesTab();
}
