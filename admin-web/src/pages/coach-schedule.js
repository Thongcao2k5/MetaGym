import { api, buildQuery, resolveApiAssetUrl } from '../services/api.js';
import { esc, formatDateVN, initials } from '../components/format.js';
import { icon } from '../components/icons.js';
import { openDrawer } from '../components/drawer.js';
import { renderEmptyState, renderErrorState } from '../components/states.js';
import { renderToggle } from '../components/toggle.js';
import { updateQuery } from '../state/router.js';

const WEEKDAY_NAMES = Object.freeze({
  1: 'Thứ 2',
  2: 'Thứ 3',
  3: 'Thứ 4',
  4: 'Thứ 5',
  5: 'Thứ 6',
  6: 'Thứ 7',
  7: 'Chủ nhật',
});

const SHORT_WEEKDAY = Object.freeze({
  1: 'T2',
  2: 'T3',
  3: 'T4',
  4: 'T5',
  5: 'T6',
  6: 'T7',
  7: 'CN',
});

function todayVnIso() {
  return new Date(Date.now() + 7 * 3600000).toISOString().slice(0, 10);
}

function shiftDateIso(dateIso, deltaDays) {
  const [y, m, d] = dateIso.split('-').map(Number);
  return new Date(Date.UTC(y, m - 1, d + deltaDays)).toISOString().slice(0, 10);
}

function shiftMonthStr(monthStr, deltaMonths) {
  const [y, m] = monthStr.split('-').map(Number);
  const dt = new Date(Date.UTC(y, m - 1 + deltaMonths, 1));
  return `${dt.getUTCFullYear()}-${String(dt.getUTCMonth() + 1).padStart(2, '0')}`;
}

function formatMonthLabel(monthStr) {
  const [y, m] = monthStr.split('-');
  return `Tháng ${Number(m)} / ${y}`;
}

function getSessionPeriod(startMinute) {
  if (startMinute < 720) return 'MORNING';
  if (startMinute < 1050) return 'AFTERNOON';
  return 'EVENING';
}

const PERIOD_META = Object.freeze({
  MORNING: { label: 'Ca Sáng', range: '05:00 – 12:30' },
  AFTERNOON: { label: 'Ca Chiều', range: '13:00 – 17:30' },
  EVENING: { label: 'Ca Tối', range: '17:30 – 22:00' },
});

function renderCoachAvatar(name, avatarUrl, size = 30) {
  const label = esc(initials(name, 'HLV'));
  const resolvedUrl = resolveApiAssetUrl(avatarUrl);
  if (resolvedUrl) {
    return `<span class="cs-avatar" style="width:${size}px;height:${size}px">
      <img src="${esc(resolvedUrl)}" alt="" loading="lazy" decoding="async" />
    </span>`;
  }
  return `<span class="cs-avatar is-monogram" style="width:${size}px;height:${size}px">${label}</span>`;
}

function shortenCoachName(fullName = '') {
  const parts = String(fullName || '').trim().split(/\s+/).filter(Boolean);
  if (parts.length <= 1) return parts[0] || 'Coach';
  return `${parts[parts.length - 2][0]}.${parts[parts.length - 1]}`;
}

function openSlotDetailDrawer({ dateIso, slot, onOpenDay, onFilterCoach }) {
  const wd = new Date(`${dateIso}T00:00:00Z`).getUTCDay();
  const isoWd = wd === 0 ? 7 : wd;
  const coaches = Array.isArray(slot?.coaches) ? slot.coaches : [];

  openDrawer({
    title: `${WEEKDAY_NAMES[isoWd] || ''} · ${formatDateVN(dateIso)}`,
    subtitle: `Khung giờ ${slot.label} · Thời lượng 90 phút`,
    bodyHtml: `<div class="stack-16">
      <div class="cs-drawer-stats tabular">
        <div class="cs-dstat">
          <span class="cs-dstat-label">Trong ca</span>
          <strong class="cs-dstat-val">${slot.inShiftCount}</strong>
        </div>
        <div class="cs-dstat is-available">
          <span class="cs-dstat-label">Đang rảnh</span>
          <strong class="cs-dstat-val">${slot.availableCount}</strong>
        </div>
        <div class="cs-dstat is-busy">
          <span class="cs-dstat-label">Đã có lịch</span>
          <strong class="cs-dstat-val">${slot.busyCount}</strong>
        </div>
        ${slot.blockedCount > 0 ? `<div class="cs-dstat is-blocked">
          <span class="cs-dstat-label">Tạm chặn</span>
          <strong class="cs-dstat-val">${slot.blockedCount}</strong>
        </div>` : ''}
      </div>

      <div class="stack-8">
        <div class="field-label">Danh sách Coach trong khung giờ này (${coaches.length})</div>
        ${coaches.length === 0
          ? '<div class="impact-box"><span class="field-hint">Không có Coach nào đăng ký ca trong khung giờ này.</span></div>'
          : coaches.map((c) => {
            const stateClass = c.state === 'AVAILABLE' ? 'is-available' : c.state === 'BUSY' ? 'is-busy' : 'is-blocked';
            const badgeHtml = c.state === 'AVAILABLE'
              ? '<span class="meta-badge meta-badge-success">Đang rảnh</span>'
              : c.state === 'BUSY'
                ? `<span class="meta-badge meta-badge-coral">${c.bookingStatus === 'COMPLETED' ? 'Đã dạy' : 'Đang bận'}</span>`
                : '<span class="meta-badge meta-badge-warning">Tạm chặn</span>';
            const subText = c.state === 'BUSY'
              ? `Hội viên: ${esc(c.memberName || 'Hội viên')}`
              : c.state === 'BLOCKED'
                ? `Lý do: ${esc(c.reason || 'Tạm nghỉ')}`
                : 'Sẵn sàng nhận lịch buổi tập 90 phút';
            return `<div class="cs-drawer-coach-row ${stateClass}">
              <div class="person-cell" style="min-width:0;flex:1">
                ${renderCoachAvatar(c.coachName, c.avatarThumbnailUrl, 36)}
                <div style="min-width:0">
                  <div class="person-name">${esc(c.coachName)}</div>
                  <div class="person-sub">${subText}</div>
                </div>
              </div>
              <div class="cs-drawer-row-actions">
                ${badgeHtml}
                ${onFilterCoach && c.coachId ? `<button type="button" class="btn btn-graphite btn-sm" data-drawer-coach="${esc(c.coachId)}" title="Lọc lịch theo Coach này">Xem lịch</button>` : ''}
              </div>
            </div>`;
          }).join('')}
      </div>

      ${onOpenDay ? `<button type="button" class="btn btn-graphite" id="cs-drawer-open-day">${icon('calendar', 15)} Xem toàn bộ lịch ngày ${esc(formatDateVN(dateIso))}</button>` : ''}
    </div>`,
    onMount(drawer) {
      const btn = drawer?.panel?.querySelector('#cs-drawer-open-day');
      if (btn && onOpenDay) {
        btn.onclick = () => {
          drawer.close();
          onOpenDay(dateIso);
        };
      }
      if (onFilterCoach) {
        drawer?.panel?.querySelectorAll('[data-drawer-coach]').forEach((filterBtn) => {
          filterBtn.onclick = () => {
            const targetCoach = filterBtn.dataset.drawerCoach;
            drawer.close();
            if (targetCoach) onFilterCoach(targetCoach);
          };
        });
      }
    },
  });
}

function computeCoachFreeSlotsInPayload({ view, data }) {
  const counts = new Map();
  const bump = (coachId, state) => {
    if (!coachId) return;
    const prev = counts.get(coachId) || { available: 0, busy: 0, total: 0 };
    prev.total += 1;
    if (state === 'AVAILABLE') prev.available += 1;
    else if (state === 'BUSY') prev.busy += 1;
    counts.set(coachId, prev);
  };

  if (view === 'day') {
    for (const s of data.day?.slots || []) {
      for (const c of s.coaches || []) bump(c.coachId, c.state);
    }
  } else if (view === 'week') {
    for (const cell of Object.values(data.week?.cells || {})) {
      for (const c of cell?.coaches || []) bump(c.coachId, c.state);
    }
  }
  return counts;
}

function renderScheduleDataSkeleton(view) {
  if (view === 'day') {
    return `<div class="cs-day-list" aria-busy="true" aria-label="Đang tải lịch ngày">
      ${Array.from({ length: 5 }).map(() => `<div class="cs-day-row">
        <div class="cs-day-time">
          <div class="skel" style="height:18px;width:116px"></div>
          <div class="skel" style="height:4px;width:100%"></div>
          <div class="skel" style="height:20px;width:150px"></div>
        </div>
        <div class="cs-coaches-wrap">
          <div class="skel" style="height:46px;width:100%"></div>
          <div class="skel" style="height:46px;width:100%"></div>
        </div>
      </div>`).join('')}
    </div>`;
  }
  if (view === 'month') {
    return `<div class="cs-month-wrap" aria-busy="true" aria-label="Đang tải lịch tháng">
      <div class="cs-month-weekdays">
        ${[1, 2, 3, 4, 5, 6, 7].map((wd) => `<div class="${wd === 7 ? 'is-rest' : ''}">${WEEKDAY_NAMES[wd]}</div>`).join('')}
      </div>
      <div class="cs-month-grid">
        ${Array.from({ length: 14 }).map(() => `<div class="cs-month-cell">
          <div class="skel" style="height:16px;width:45%"></div>
          <div class="skel" style="height:14px;width:82%"></div>
          <div class="skel" style="height:4px;width:100%"></div>
        </div>`).join('')}
      </div>
    </div>`;
  }
  return `<div class="table-responsive cs-week-scroll" aria-busy="true" aria-label="Đang tải lịch tuần">
    <table class="meta-table cs-week-table">
      <thead>
        <tr>
          <th class="cs-week-sticky-col cs-week-corner">Khung 90p</th>
          ${[1, 2, 3, 4, 5, 6, 7].map((wd) => `<th class="cs-week-th ${wd === 7 ? 'is-rest-day' : ''}">
            <div class="cs-week-th-day"><span>${wd === 7 ? 'CN' : WEEKDAY_NAMES[wd]}</span></div>
            <div class="skel" style="height:11px;width:${wd === 7 ? 38 : 64}px;margin:6px auto 0"></div>
          </th>`).join('')}
        </tr>
      </thead>
      <tbody>
        ${Array.from({ length: 6 }).map(() => `<tr>
          <td class="cs-week-sticky-col cs-week-time-cell"><div class="skel" style="height:16px;width:88px"></div></td>
          ${[1, 2, 3, 4, 5, 6, 7].map((wd) => `<td class="cs-week-td ${wd === 7 ? 'is-rest-day' : ''}">
            ${wd === 7 ? '<span class="cs-cell-empty">—</span>' : '<div class="skel" style="height:64px;width:100%;border-radius:var(--meta-radius-sm)"></div>'}
          </td>`).join('')}
        </tr>`).join('')}
      </tbody>
    </table>
  </div>`;
}

function renderKpiCards(totals = {}, loading = false) {
  const dash = loading ? '–' : 0;
  return `<div class="cs-kpi-grid">
    <div class="kpi-card is-info cs-kpi-card">
      <div class="cs-kpi-head">
        <span class="cs-kpi-title">Coach hoạt động</span>
        <span class="cs-kpi-icon">${icon('users', 15)}</span>
      </div>
      <div class="cs-kpi-value tabular">${totals.configuredCoachCount ?? dash}<small> / ${totals.activeCoachCount ?? dash} đủ lịch tuần</small></div>
    </div>
    <div class="kpi-card is-warning cs-kpi-card">
      <div class="cs-kpi-head">
        <span class="cs-kpi-title">Tổng ca trực (90p)</span>
        <span class="cs-kpi-icon">${icon('calendar', 15)}</span>
      </div>
      <div class="cs-kpi-value tabular">${totals.inShiftSlots ?? dash}<small> lượt trực</small></div>
    </div>
    <div class="kpi-card is-success cs-kpi-card">
      <div class="cs-kpi-head">
        <span class="cs-kpi-title">Ca đang rảnh</span>
        <span class="cs-kpi-icon">${icon('check', 15)}</span>
      </div>
      <div class="cs-kpi-value tabular">${totals.availableSlots ?? dash}<small> còn nhận lịch</small></div>
    </div>
    <div class="kpi-card is-coral cs-kpi-card">
      <div class="cs-kpi-head">
        <span class="cs-kpi-title">Ca đã đặt / bận</span>
        <span class="cs-kpi-icon">${icon('clock', 15)}</span>
      </div>
      <div class="cs-kpi-value tabular">${totals.busySlots ?? dash}<small> · ${totals.busyRatePercent ?? dash}% lấp đầy</small></div>
    </div>
  </div>`;
}

function renderControlsCard({
  view,
  date,
  month,
  coachId,
  onlyAvailable,
  periodHeading,
  coaches = [],
  coachPeriodStats = new Map(),
}) {
  const rosterStripHtml = coaches.length > 0 ? `<div class="cs-roster-strip" aria-label="Lọc nhanh theo Coach">
    <button type="button" class="cs-roster-chip ${!coachId ? 'active' : ''}" data-cs-coach-chip="">
      <span class="cs-roster-all-dot"></span>
      <span>Tất cả Coach</span>
      <span class="cs-roster-badge tabular">${coaches.length}</span>
    </button>
    ${coaches.map((c) => {
      const stat = coachPeriodStats.get(c.id);
      const statText = view === 'month'
        ? `${c.weeklySlotCount || 0} ca/tuần`
        : stat
          ? `Rảnh ${stat.available}/${stat.total}`
          : '0 ca';
      return `<button type="button" class="cs-roster-chip ${coachId === c.id ? 'active' : ''}" data-cs-coach-chip="${esc(c.id)}">
        ${renderCoachAvatar(c.fullName, c.avatarThumbnailUrl, 24)}
        <span class="cs-roster-name">${esc(c.fullName)}</span>
        <span class="cs-roster-badge tabular">${esc(statText)}</span>
      </button>`;
    }).join('')}
  </div>` : '';

  return `<section class="meta-card stack-12 cs-control-card">
    <div class="cs-toolbar">
      <div class="chart-segmented" role="group" aria-label="Chế độ xem lịch">
        <button type="button" class="chart-seg-btn ${view === 'day' ? 'active' : ''}" data-cs-view="day">Theo ngày</button>
        <button type="button" class="chart-seg-btn ${view === 'week' ? 'active' : ''}" data-cs-view="week">Theo tuần</button>
        <button type="button" class="chart-seg-btn ${view === 'month' ? 'active' : ''}" data-cs-view="month">Theo tháng</button>
      </div>

      <div class="cs-nav-cluster">
        <button type="button" class="btn btn-graphite btn-sm" id="cs-prev-btn" aria-label="Kỳ trước">${icon('chevronLeft', 16)}</button>
        <button type="button" class="btn btn-graphite btn-sm" id="cs-today-btn">Hôm nay</button>
        <button type="button" class="btn btn-graphite btn-sm" id="cs-next-btn" aria-label="Kỳ sau">${icon('chevronRight', 16)}</button>
        <span class="cs-period-title tabular">${esc(periodHeading)}</span>
      </div>

      <div class="cs-filter-cluster">
        ${view === 'month'
          ? `<input id="cs-month-picker" class="form-control tabular cs-toolbar-date" type="month" value="${esc(month)}" aria-label="Chọn tháng" />`
          : `<input id="cs-date-picker" class="form-control tabular cs-toolbar-date" type="date" value="${esc(date)}" aria-label="Chọn ngày" />`}
        <select id="cs-coach-filter" class="form-select cs-toolbar-select" aria-label="Lọc theo Huấn luyện viên">
          <option value="">Tất cả Coach (${coaches.length})</option>
          ${coaches.map((c) => `<option value="${esc(c.id)}" ${coachId === c.id ? 'selected' : ''}>${esc(c.fullName)}${c.scheduleConfigured ? '' : ' (Chưa đủ lịch)'}</option>`).join('')}
        </select>
      </div>
    </div>

    ${rosterStripHtml}

    <div class="cs-legend-row">
      <div class="cs-legend-pills">
        <span class="cs-operating-pill">${icon('clock', 13)} Ca chuẩn: <strong>05:00 – 22:00</strong> · 90 phút/ca · <strong>Thứ 2 – Thứ 7</strong></span>
        <span class="cs-legend-item"><i class="cs-dot is-available"></i> Đang rảnh</span>
        <span class="cs-legend-item"><i class="cs-dot is-busy"></i> Đang bận (đã đặt)</span>
        <span class="cs-legend-item"><i class="cs-dot is-blocked"></i> Tạm chặn / Nghỉ</span>
      </div>
      <div>
        ${renderToggle({ id: 'cs-only-avail', checked: onlyAvailable, label: 'Chỉ hiện khung còn Coach rảnh' })}
      </div>
    </div>
  </section>`;
}

function bindScheduleControls({ root, view, today, date, month, coachId, navigateParams }) {
  root.querySelectorAll('[data-cs-view]').forEach((btn) => {
    btn.onclick = () => {
      const nextView = btn.dataset.csView;
      navigateParams({ view: nextView, date, month: date.slice(0, 7) });
    };
  });

  root.querySelectorAll('[data-cs-coach-chip]').forEach((chip) => {
    chip.onclick = () => {
      const clickedId = chip.dataset.csCoachChip || '';
      const nextCoach = clickedId === coachId ? '' : clickedId;
      navigateParams({ coachId: nextCoach });
    };
  });

  const prevBtn = root.querySelector('#cs-prev-btn');
  const nextBtn = root.querySelector('#cs-next-btn');
  const todayBtn = root.querySelector('#cs-today-btn');

  if (prevBtn) {
    prevBtn.onclick = () => {
      if (view === 'month') navigateParams({ month: shiftMonthStr(month, -1) });
      else if (view === 'week') navigateParams({ date: shiftDateIso(date, -7) });
      else navigateParams({ date: shiftDateIso(date, -1) });
    };
  }
  if (nextBtn) {
    nextBtn.onclick = () => {
      if (view === 'month') navigateParams({ month: shiftMonthStr(month, 1) });
      else if (view === 'week') navigateParams({ date: shiftDateIso(date, 7) });
      else navigateParams({ date: shiftDateIso(date, 1) });
    };
  }
  if (todayBtn) {
    todayBtn.onclick = () => {
      navigateParams({ date: today, month: today.slice(0, 7) });
    };
  }

  const datePicker = root.querySelector('#cs-date-picker');
  if (datePicker) datePicker.onchange = (e) => { if (e.target.value) navigateParams({ date: e.target.value }); };

  const monthPicker = root.querySelector('#cs-month-picker');
  if (monthPicker) monthPicker.onchange = (e) => { if (e.target.value) navigateParams({ month: e.target.value }); };

  const coachSelect = root.querySelector('#cs-coach-filter');
  if (coachSelect) coachSelect.onchange = (e) => { navigateParams({ coachId: e.target.value || '' }); };

  const availToggle = root.querySelector('#cs-only-avail');
  if (availToggle) availToggle.onchange = (e) => { navigateParams({ onlyAvailable: e.target.checked ? '1' : '' }); };
}

export async function renderCoachSchedulePage({ root, params, shell }) {
  const view = ['day', 'week', 'month'].includes(params?.get('view')) ? params.get('view') : 'week';
  const today = todayVnIso();
  const date = params?.get('date') || today;
  const month = params?.get('month') || date.slice(0, 7);
  const coachId = params?.get('coachId') || '';
  const onlyAvailable = params?.get('onlyAvailable') === '1' || params?.get('onlyAvailable') === 'true';

  const navigateParams = (patch = {}) => {
    const next = {
      view,
      date,
      month,
      coachId,
      onlyAvailable: onlyAvailable ? '1' : '',
      ...patch,
    };
    updateQuery({
      view: next.view,
      date: next.view === 'month' ? '' : next.date,
      month: next.view === 'month' ? next.month : '',
      coachId: next.coachId || '',
      onlyAvailable: next.onlyAvailable ? '1' : '',
    }, { replace: false });
  };

  const initialPeriodHeading = view === 'month'
    ? formatMonthLabel(month)
    : view === 'day'
      ? formatDateVN(date)
      : `Tuần ${formatDateVN(date)}`;

  const existingBody = root.querySelector('#cs-view-body');
  const existingControls = root.querySelector('#cs-controls-slot');
  if (existingBody && existingControls) {
    root.querySelectorAll('[data-cs-view]').forEach((btn) => {
      btn.classList.toggle('active', btn.dataset.csView === view);
    });
    root.querySelectorAll('[data-cs-coach-chip]').forEach((chip) => {
      chip.classList.toggle('active', (chip.dataset.csCoachChip || '') === coachId);
    });
    const availEl = root.querySelector('#cs-only-avail');
    if (availEl) availEl.checked = onlyAvailable;
    existingBody.innerHTML = renderScheduleDataSkeleton(view);
  } else {
    shell({
      section: 'coach-schedule',
      contentHtml: `<div class="stack-20">
        <div id="cs-kpi-slot">${renderKpiCards({}, true)}</div>
        <div id="cs-controls-slot">${renderControlsCard({
          view,
          date,
          month,
          coachId,
          onlyAvailable,
          periodHeading: initialPeriodHeading,
        })}</div>
        <section class="meta-card stack-12 cs-canvas-card" id="cs-view-body">
          ${renderScheduleDataSkeleton(view)}
        </section>
      </div>`,
    });
    bindScheduleControls({ root, view, today, date, month, coachId, navigateParams });
  }

  try {
    const qs = buildQuery({
      view,
      date,
      month,
      ...(coachId ? { coachId } : {}),
      ...(onlyAvailable ? { onlyAvailable: '1' } : {}),
    });
    const res = await api(`/admin/coach-schedule/overview${qs}`);
    const data = res?.data || {};
    const coaches = data.coaches || [];
    const totals = data.totals || {};
    const coachPeriodStats = computeCoachFreeSlotsInPayload({ view, data });

    const periodHeading = view === 'day'
      ? `${WEEKDAY_NAMES[data.day?.weekday] || ''} · ${formatDateVN(data.date || date)}`
      : view === 'week'
        ? `Tuần ${formatDateVN(data.week?.startDate || date).slice(0, 5)} – ${formatDateVN(data.week?.endDate || date)}`
        : formatMonthLabel(data.month || month);

    const kpiHtml = renderKpiCards(totals, false);
    const controlsHtml = renderControlsCard({
      view,
      date,
      month,
      coachId,
      onlyAvailable,
      periodHeading,
      coaches,
      coachPeriodStats,
    });

    let viewBodyHtml = '';

    if (view === 'day') {
      const slots = data.day?.slots || [];
      if (slots.length === 0) {
        viewBodyHtml = renderEmptyState({
          iconName: 'calendar',
          title: 'Không có khung ca Coach trong ngày này',
          description: onlyAvailable
            ? 'Không còn khung giờ nào có Coach rảnh. Thử tắt bộ lọc "Chỉ hiện khung còn Coach rảnh" hoặc chọn ngày khác.'
            : 'Chưa có Coach nào đăng ký lịch làm việc vào ngày này (lịch chuẩn phục vụ Thứ 2 – Thứ 7).',
        });
      } else {
        const grouped = { MORNING: [], AFTERNOON: [], EVENING: [] };
        for (const s of slots) {
          grouped[getSessionPeriod(s.startMinute)].push(s);
        }

        const renderSlotRow = (slot) => {
          const availPct = slot.inShiftCount > 0 ? Math.round((slot.availableCount / slot.inShiftCount) * 100) : 0;
          return `<div class="cs-day-row">
            <div class="cs-day-time">
              <div class="cs-day-time-top">
                <span class="cs-time-label tabular">${esc(slot.label)}</span>
                <span class="cs-shift-total tabular">${slot.inShiftCount} trực</span>
              </div>
              <div class="cs-cell-bar" aria-hidden="true"><span style="width:${availPct}%"></span></div>
              <div class="cs-day-counts tabular">
                <span class="meta-badge meta-badge-success">Rảnh ${slot.availableCount}</span>
                <span class="meta-badge meta-badge-coral">Bận ${slot.busyCount}</span>
                ${slot.blockedCount > 0 ? `<span class="meta-badge meta-badge-warning">Chặn ${slot.blockedCount}</span>` : ''}
              </div>
            </div>
            <div class="cs-coaches-wrap">
              ${slot.coaches.map((c) => {
                const stateCls = c.state === 'AVAILABLE' ? 'is-available' : c.state === 'BUSY' ? 'is-busy' : 'is-blocked';
                const subText = c.state === 'AVAILABLE'
                  ? 'Đang rảnh · Sẵn sàng'
                  : c.state === 'BUSY'
                    ? `Bận · ${c.memberName}`
                    : `Chặn · ${c.reason}`;
                return `<button type="button" class="cs-coach-chip ${stateCls}" data-day-slot="${slot.startMinute}">
                  <span class="cs-chip-avatar-wrap">
                    ${renderCoachAvatar(c.coachName, c.avatarThumbnailUrl, 30)}
                    <span class="cs-chip-status-dot ${stateCls}"></span>
                  </span>
                  <span class="cs-chip-body">
                    <span class="cs-chip-name">${esc(c.coachName)}</span>
                    <span class="cs-chip-meta">${esc(subText)}</span>
                  </span>
                </button>`;
              }).join('')}
            </div>
          </div>`;
        };

        const groupSections = ['MORNING', 'AFTERNOON', 'EVENING']
          .filter((key) => grouped[key].length > 0)
          .map((key) => `<div class="cs-period-section">
            <div class="cs-period-divider">
              <span class="cs-period-badge">${PERIOD_META[key].label}</span>
              <span class="cs-period-range tabular">${PERIOD_META[key].range} · ${grouped[key].length} khung</span>
            </div>
            <div class="cs-day-list">
              ${grouped[key].map(renderSlotRow).join('')}
            </div>
          </div>`).join('');

        viewBodyHtml = `<div class="stack-20">${groupSections}</div>`;
      }
    } else if (view === 'week') {
      const days = data.week?.days || [];
      const slotMinutes = data.week?.slotMinutes || [];
      const cells = data.week?.cells || {};

      const dayColTotals = days.map((d) => {
        let inShift = 0;
        let avail = 0;
        for (const sm of slotMinutes) {
          const cell = cells[`${d.date}:${sm.startMinute}`];
          if (cell) {
            inShift += cell.inShiftCount || 0;
            avail += cell.availableCount || 0;
          }
        }
        return { inShift, avail };
      });

      viewBodyHtml = slotMinutes.length === 0
        ? renderEmptyState({
            iconName: 'calendar',
            title: 'Chưa có dữ liệu lịch làm việc trong tuần này',
            description: 'Các Coach chưa thiết lập ca làm việc 90 phút hoặc không khớp bộ lọc hiện tại.',
          })
        : `<div class="table-responsive cs-week-scroll">
            <table class="meta-table cs-week-table">
              <thead>
                <tr>
                  <th class="cs-week-sticky-col cs-week-corner">Khung 90p</th>
                  ${days.map((d, idx) => {
                    const colStat = dayColTotals[idx];
                    const isRestDay = d.weekday === 7 && colStat.inShift === 0;
                    const isTodayCol = d.date === today;
                    const colAvailRatio = colStat.inShift > 0 ? Math.round((colStat.avail / colStat.inShift) * 100) : 0;
                    return `<th class="cs-week-th ${isTodayCol ? 'is-today' : ''} ${isRestDay ? 'is-rest-day' : ''}">
                      <div class="cs-week-th-day">
                        <span>${esc(isRestDay ? 'CN' : (WEEKDAY_NAMES[d.weekday] || ''))}</span>
                        ${isTodayCol ? '<span class="cs-today-pill">Hôm nay</span>' : ''}
                      </div>
                      <div class="cs-week-th-sub tabular">${esc(formatDateVN(d.date).slice(0, 5))}${isRestDay ? ' · Nghỉ' : ''}</div>
                      ${isRestDay ? '' : `<div class="cs-week-th-cap tabular">
                        <span class="cs-th-cap-text">Rảnh ${colStat.avail}/${colStat.inShift}</span>
                        <span class="cs-th-cap-bar"><i style="width:${colAvailRatio}%"></i></span>
                      </div>`}
                    </th>`;
                  }).join('')}
                </tr>
              </thead>
              <tbody>
                ${slotMinutes.map((sm, rowIdx) => {
                  const periodKey = getSessionPeriod(sm.startMinute);
                  const prevPeriodKey = rowIdx > 0 ? getSessionPeriod(slotMinutes[rowIdx - 1].startMinute) : null;
                  const showGroupBanner = periodKey !== prevPeriodKey;
                  const groupRowHtml = showGroupBanner
                    ? `<tr class="cs-week-group-row">
                        <td class="cs-week-sticky-col cs-week-group-lead">
                          <span class="cs-week-group-pill">${PERIOD_META[periodKey].label}</span>
                        </td>
                        <td colspan="${days.length}" class="cs-week-group-bar">
                          <span class="cs-week-group-range tabular">${PERIOD_META[periodKey].range}</span>
                        </td>
                      </tr>`
                    : '';

                  return `${groupRowHtml}<tr>
                    <td class="cs-week-sticky-col tabular cs-week-time-cell">
                      <span class="cs-week-clock-main">${esc(sm.label)}</span>
                    </td>
                    ${days.map((d, idx) => {
                      const isRestDay = d.weekday === 7 && dayColTotals[idx].inShift === 0;
                      const isTodayCol = d.date === today;
                      const cell = cells[`${d.date}:${sm.startMinute}`];
                      if (!cell || cell.inShiftCount === 0) {
                        return `<td class="cs-week-td ${isRestDay ? 'is-rest-day' : ''} ${isTodayCol ? 'is-today-col' : ''}"><span class="cs-cell-empty">—</span></td>`;
                      }
                      const tone = cell.availableCount === 0
                        ? 'is-full'
                        : cell.busyCount > 0 || cell.blockedCount > 0
                          ? 'is-mixed'
                          : 'is-free';
                      const freeRatio = cell.inShiftCount > 0 ? Math.round((cell.availableCount / cell.inShiftCount) * 100) : 0;
                      const cellCoaches = Array.isArray(cell.coaches) ? cell.coaches : [];
                      const coachPreviewHtml = cellCoaches.length === 1
                        ? `<div class="cs-wcell-single">
                            <span class="cs-wcell-dot is-${cellCoaches[0].state.toLowerCase()}"></span>
                            <span class="cs-wcell-sname">${esc(shortenCoachName(cellCoaches[0].coachName))}</span>
                          </div>`
                        : cellCoaches.length > 1
                          ? `<div class="cs-wcell-stack">
                              <span class="cs-wcell-avatars">
                                ${cellCoaches.slice(0, 3).map((c) => `<span class="cs-mini-dot-av is-${c.state.toLowerCase()}" title="${esc(c.coachName)}">${esc(initials(c.coachName, 'C'))}</span>`).join('')}
                                ${cellCoaches.length > 3 ? `<span class="cs-mini-more tabular">+${cellCoaches.length - 3}</span>` : ''}
                              </span>
                              <span class="cs-wcell-total tabular">${cell.inShiftCount} trực</span>
                            </div>`
                          : `<div class="cs-cell-sub tabular">Ca: ${cell.inShiftCount}</div>`;

                      return `<td class="cs-week-td ${isTodayCol ? 'is-today-col' : ''}">
                        <button type="button" class="cs-week-cell ${tone}" data-week-cell="${esc(`${d.date}:${sm.startMinute}`)}" title="Bấm xem chi tiết ${esc(cell.inShiftCount)} Coach trong ca">
                          <div class="cs-cell-top tabular">
                            <span class="cs-cell-avail">${cell.availableCount} rảnh</span>
                            ${cell.busyCount > 0
                              ? `<span class="cs-cell-busy">${cell.busyCount} bận</span>`
                              : cell.blockedCount > 0
                                ? `<span class="cs-cell-blocked">${cell.blockedCount} chặn</span>`
                                : '<span class="cs-cell-clean">Trống</span>'}
                          </div>
                          ${coachPreviewHtml}
                          <div class="cs-cell-bar"><span style="width:${freeRatio}%"></span></div>
                        </button>
                      </td>`;
                    }).join('')}
                  </tr>`;
                }).join('')}
              </tbody>
            </table>
          </div>`;
    } else {
      const gridDays = data.monthGrid?.days || [];
      const firstWd = Number(data.monthGrid?.firstWeekday || 1);
      const leadingEmpties = Array.from({ length: Math.max(0, firstWd - 1) }, () => '<div class="cs-month-cell is-pad" aria-hidden="true"></div>').join('');

      viewBodyHtml = gridDays.length === 0
        ? renderEmptyState({
            iconName: 'calendar',
            title: 'Không có ngày nào khớp bộ lọc trong tháng này',
            description: 'Thử tắt bộ lọc "Chỉ hiện khung còn Coach rảnh" để xem toàn bộ lịch tháng.',
          })
        : `<div class="cs-month-wrap">
            <div class="cs-month-weekdays">
              ${[1, 2, 3, 4, 5, 6, 7].map((wd) => `<div class="${wd === 7 ? 'is-rest' : ''}">${WEEKDAY_NAMES[wd]}</div>`).join('')}
            </div>
            <div class="cs-month-grid">
              ${onlyAvailable ? '' : leadingEmpties}
              ${gridDays.map((d) => {
                const isToday = d.date === today;
                const isSundayOff = d.weekday === 7 && d.inShiftSlots === 0;
                const tone = d.inShiftSlots === 0
                  ? 'is-off'
                  : d.availableSlots === 0
                    ? 'is-full'
                    : d.busySlots > 0 || d.blockedSlots > 0
                      ? 'is-mixed'
                      : 'is-free';
                return `<button type="button" class="cs-month-cell ${tone} ${isToday ? 'is-today' : ''} ${isSundayOff ? 'is-sunday' : ''}" data-open-day="${esc(d.date)}">
                  <div class="cs-month-cell-head">
                    <span class="cs-month-daynum tabular">
                      ${esc(d.date.slice(8, 10))}
                      <small class="cs-month-mobile-wd">${SHORT_WEEKDAY[d.weekday] || ''}</small>
                      ${isToday ? '<span class="cs-today-pill">Hôm nay</span>' : ''}
                    </span>
                    ${d.inShiftCoachCount > 0 ? `<span class="cs-month-coach-pill tabular">${d.inShiftCoachCount} Coach</span>` : ''}
                  </div>
                  ${d.inShiftSlots === 0
                    ? `<div class="cs-month-off">${d.weekday === 7 ? 'Nghỉ CN' : 'Không có ca'}</div>`
                    : `<div class="cs-month-metrics tabular">
                        <span class="cs-m-avail">Rảnh ${d.availableSlots}</span>
                        <span class="cs-m-busy">Bận ${d.busySlots}</span>
                      </div>
                      <div class="cs-cell-bar"><span style="width:${100 - d.busyRatePercent}%"></span></div>
                      <div class="cs-month-sub tabular">Tổng ${d.inShiftSlots} ca${d.blockedSlots > 0 ? ` · Chặn ${d.blockedSlots}` : ''}</div>`}
                </button>`;
              }).join('')}
            </div>
          </div>`;
    }

    const kpiSlot = root.querySelector('#cs-kpi-slot');
    const controlsSlot = root.querySelector('#cs-controls-slot');
    const viewBodyEl = root.querySelector('#cs-view-body');
    if (kpiSlot && controlsSlot && viewBodyEl) {
      kpiSlot.innerHTML = kpiHtml;
      controlsSlot.innerHTML = controlsHtml;
      viewBodyEl.innerHTML = viewBodyHtml;
    } else {
      shell({
        section: 'coach-schedule',
        contentHtml: `<div class="stack-20">
          <div id="cs-kpi-slot">${kpiHtml}</div>
          <div id="cs-controls-slot">${controlsHtml}</div>
          <section class="meta-card stack-12 cs-canvas-card" id="cs-view-body">
            ${viewBodyHtml}
          </section>
        </div>`,
      });
    }

    // Bind Controls
    bindScheduleControls({ root, view, today, date, month, coachId, navigateParams });

    // Bind interactive slots
    if (view === 'day') {
      const slotMap = new Map((data.day?.slots || []).map((s) => [String(s.startMinute), s]));
      root.querySelectorAll('[data-day-slot]').forEach((btn) => {
        btn.onclick = () => {
          const slot = slotMap.get(btn.dataset.daySlot);
          if (slot) {
            openSlotDetailDrawer({
              dateIso: date,
              slot,
              onFilterCoach: (cid) => navigateParams({ coachId: cid }),
            });
          }
        };
      });
    } else if (view === 'week') {
      const cells = data.week?.cells || {};
      root.querySelectorAll('[data-week-cell]').forEach((btn) => {
        btn.onclick = () => {
          const key = btn.dataset.weekCell;
          const cell = cells[key];
          if (!cell) return;
          const [dIso] = key.split(':');
          openSlotDetailDrawer({
            dateIso: dIso,
            slot: cell,
            onOpenDay: (targetDate) => navigateParams({ view: 'day', date: targetDate }),
            onFilterCoach: (cid) => navigateParams({ coachId: cid }),
          });
        };
      });
    } else {
      root.querySelectorAll('[data-open-day]').forEach((btn) => {
        btn.onclick = () => navigateParams({ view: 'day', date: btn.dataset.openDay });
      });
    }
  } catch (err) {
    const viewBodyEl = root.querySelector('#cs-view-body');
    if (viewBodyEl) {
      viewBodyEl.innerHTML = renderErrorState({ title: 'Không tải được Lịch Coach', message: err.message });
    } else {
      shell({
        section: 'coach-schedule',
        contentHtml: renderErrorState({ title: 'Không tải được Lịch Coach', message: err.message }),
      });
    }
    const retry = root.querySelector('#retry-load-btn');
    if (retry) retry.onclick = () => renderCoachSchedulePage({ root, params, shell });
  }
}
