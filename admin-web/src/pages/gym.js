import { api } from '../services/api.js';
import { esc } from '../components/format.js';
import { icon } from '../components/icons.js';
import { openConfirmModal } from '../components/modal.js';
import { renderBanner, renderErrorState, renderSkeletonPage } from '../components/states.js';
import { toast } from '../components/toast.js';

export async function renderGymPage({ root, params, shell, QRCodeLib }) {
  shell({ section: 'gym', contentHtml: renderSkeletonPage({ cards: 0, rows: 5 }) });

  try {
    const { data } = await api('/gym-profile');
    const hoursText = typeof data.openingHours === 'string'
      ? data.openingHours
      : (data.openingHours?.summary || (data.openingHours ? JSON.stringify(data.openingHours) : ''));

    const contentHtml = `<div class="grid-split">
      <form id="gym-form" class="meta-card stack-16 no-print" novalidate>
        <div>
          <h2 class="card-title-text">Thông tin phòng gym công khai</h2>
          <p class="card-sub">Đồng bộ trực tiếp lên ứng dụng Member và Coach sau khi lưu.</p>
        </div>
        <div class="field"><label class="field-label" for="gym-name">Tên phòng gym</label><input id="gym-name" class="form-control" name="name" value="${esc(data.name || '')}" required /></div>
        <div class="field"><label class="field-label" for="gym-address">Địa chỉ</label><input id="gym-address" class="form-control" name="address" value="${esc(data.address || '')}" required /></div>
        <div class="grid-2">
          <div class="field"><label class="field-label" for="gym-phone">Số điện thoại</label><input id="gym-phone" class="form-control tabular" name="phone" value="${esc(data.phone || '')}" /></div>
          <div class="field"><label class="field-label" for="gym-email">Email liên hệ</label><input id="gym-email" class="form-control" name="email" type="email" value="${esc(data.email || '')}" /></div>
        </div>
        <div class="field"><label class="field-label" for="gym-desc">Mô tả phòng gym</label><textarea id="gym-desc" class="form-control" name="description">${esc(data.description || '')}</textarea></div>
        <div class="field"><label class="field-label" for="gym-rules">Nội quy phòng tập</label><textarea id="gym-rules" class="form-control" name="rules">${esc(data.rules || '')}</textarea></div>
        <div style="display:flex;justify-content:flex-end">
          <button type="submit" class="btn btn-primary" id="gym-save-btn">${icon('check', 16)} Lưu hồ sơ phòng gym</button>
        </div>
      </form>

      <div class="stack-20">
        <section class="meta-card print-only-card stack-16" id="checkin-print" aria-label="Mã QR điểm danh tại quầy">
          <div class="no-print">
            <h2 class="card-title-text">Mã QR điểm danh tại quầy</h2>
            <p class="card-sub">In mã này và đặt tại quầy lễ tân. Hội viên có gói Gym hiệu lực quét để điểm danh hằng ngày.</p>
          </div>
          <div id="checkin-qr" class="qr-plate" aria-live="polite">Đang tải mã QR…</div>
          <div class="no-print" style="display:flex;gap:10px;flex-wrap:wrap">
            <button type="button" id="print-checkin" class="btn btn-primary" style="flex:1" disabled>${icon('printer', 16)} In mã QR</button>
            <button type="button" id="rotate-checkin" class="btn btn-danger" style="flex:1">${icon('refresh', 16)} Đổi mã QR</button>
          </div>
          <p class="card-sub no-print" style="margin:0">Đổi mã sẽ làm toàn bộ các bản in QR cũ mất hiệu lực ngay lập tức.</p>
        </section>

        <section class="meta-card no-print stack-12" aria-label="Xem trước công khai">
          <h2 class="card-title-text">Xem trước trên ứng dụng</h2>
          <div class="impact-box">
            <div style="font-size:16px;font-weight:700;color:var(--meta-text-strong)">${esc(data.name || '')}</div>
            <div style="font-size:13px;color:var(--meta-text-secondary)">${esc(data.address || '')}</div>
            ${hoursText ? `<div class="field-hint">Giờ mở cửa: ${esc(hoursText)}</div>` : ''}
            ${data.phone ? `<div class="field-hint tabular">Hotline: ${esc(data.phone)}</div>` : ''}
          </div>
        </section>
      </div>
    </div>`;

    shell({ section: 'gym', contentHtml });

    async function showCode(payload) {
      const qrBox = root.querySelector('#checkin-qr');
      const printBtn = root.querySelector('#print-checkin');
      if (!qrBox) return;
      if (QRCodeLib?.toDataURL) {
        const dataUrl = await QRCodeLib.toDataURL(payload, {
          width: 300,
          margin: 2,
          errorCorrectionLevel: 'M',
          color: { dark: '#0F1115', light: '#FFFFFF' },
        });
        qrBox.innerHTML = `<img src="${dataUrl}" alt="Mã QR điểm danh Meta Gym" width="280" height="280" /><h3>${esc(data.name)}</h3><p>${esc(data.address)}</p>`;
      } else {
        qrBox.innerHTML = `<code>${esc(payload)}</code><h3>${esc(data.name)}</h3><p>${esc(data.address)}</p>`;
      }
      if (printBtn) printBtn.disabled = false;
    }

    try {
      const res = await api('/admin/gym-checkin-code');
      await showCode(res.data.payload);
    } catch (error) {
      const qrBox = root.querySelector('#checkin-qr');
      if (qrBox) qrBox.textContent = error.message;
    }

    const printBtn = root.querySelector('#print-checkin');
    if (printBtn) printBtn.onclick = () => globalThis.window?.print?.();

    const rotateBtn = root.querySelector('#rotate-checkin');
    if (rotateBtn) {
      rotateBtn.onclick = () => {
        openConfirmModal({
          title: 'Xác nhận đổi mã QR điểm danh tại quầy',
          subtitle: 'Mọi bản QR đã in trước đây sẽ mất hiệu lực ngay lập tức',
          bannerHtml: renderBanner({
            kind: 'danger',
            iconName: 'alert',
            title: 'Vô hiệu hóa bản in cũ',
            text: 'Sau khi đổi mã, hãy bấm In mã QR để thay thế bảng QR tại quầy lễ tân.',
          }),
          confirmLabel: 'Đổi mã QR ngay',
          confirmVariant: 'danger-solid',
          confirmIcon: 'refresh',
          onConfirm: async () => {
            const res = await api('/admin/gym-checkin-code/rotate', 'POST');
            await showCode(res.data.payload);
            toast('Đã đổi mã QR. Hãy in bản mới đặt tại quầy.', 'warn');
          },
        });
      };
    }

    const form = root.querySelector('#gym-form');
    if (form) {
      form.onsubmit = async (event) => {
        event.preventDefault();
        const saveBtn = root.querySelector('#gym-save-btn');
        if (saveBtn) saveBtn.disabled = true;
        try {
          const payload = {
            name: (form.querySelector('[name="name"]')?.value || '').trim(),
            address: (form.querySelector('[name="address"]')?.value || '').trim(),
            phone: (form.querySelector('[name="phone"]')?.value || '').trim() || null,
            email: (form.querySelector('[name="email"]')?.value || '').trim() || null,
            description: (form.querySelector('[name="description"]')?.value || '').trim() || null,
            rules: (form.querySelector('[name="rules"]')?.value || '').trim() || null,
          };
          await api('/admin/gym-profile', 'PATCH', payload);
          toast('Đã cập nhật hồ sơ phòng gym.');
          await renderGymPage({ root, params, shell, QRCodeLib });
        } catch (error) {
          toast(error.message, 'danger');
          if (saveBtn) saveBtn.disabled = false;
        }
      };
    }
  } catch (error) {
    shell({ section: 'gym', contentHtml: renderErrorState({ title: 'Không tải được thông tin phòng gym', message: error.message }) });
    const retry = root.querySelector('#retry-load-btn');
    if (retry) retry.onclick = () => renderGymPage({ root, params, shell, QRCodeLib });
  }
}
