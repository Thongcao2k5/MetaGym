import { api, buildQuery } from '../services/api.js';
import { daysAgoVN, esc, formatDateVN, isoDateVN, vnd } from '../components/format.js';
import {
  bindDatePickers,
  bindDateRangePicker,
  renderDateInput,
  renderDateRangePicker,
  setDatePickerValue,
} from '../components/date-picker.js';
import { icon } from '../components/icons.js';
import { renderDashboardSkeleton, renderEmptyState } from '../components/states.js';
import { toast } from '../components/toast.js';
import { updateQuery } from '../state/router.js';

let activeChart = null;
let chartGranularity = 'day'; // day | week | month
let chartType = 'line'; // line | bar

function formatShortDay(isoDay) {
  const s = String(isoDay || '');
  if (/^\d{4}-\d{2}-\d{2}$/.test(s)) {
    return `${s.slice(8, 10)}/${s.slice(5, 7)}`;
  }
  return formatDateVN(s);
}

function getBucketKey(isoDay, granularity) {
  if (granularity === 'month') return String(isoDay || '').slice(0, 7);
  if (granularity === 'week') {
    const d = new Date(`${isoDay}T00:00:00Z`);
    if (Number.isNaN(d.getTime())) return isoDay;
    const dayOfWeek = (d.getUTCDay() + 6) % 7; // Monday = 0
    d.setUTCDate(d.getUTCDate() - dayOfWeek);
    return d.toISOString().slice(0, 10);
  }
  return isoDay;
}

function formatBucketLabel(key, granularity) {
  if (granularity === 'month' && /^\d{4}-\d{2}$/.test(key)) {
    return `${key.slice(5, 7)}/${key.slice(0, 4)}`;
  }
  if (granularity === 'week') {
    return `Tuần ${formatShortDay(key)}`;
  }
  return formatShortDay(key);
}

function groupRevenueSeries(byDay, granularity) {
  if (granularity === 'day') {
    return byDay.map((row) => ({
      label: formatShortDay(row.day),
      gross: Number(row.grossRevenue ?? row.amount ?? 0),
      net: Number(row.netRevenue ?? row.amount ?? 0),
      refund: Number(row.simulatedRefunds ?? 0),
    }));
  }
  const map = new Map();
  for (const row of byDay) {
    const key = getBucketKey(row.day, granularity);
    const cur = map.get(key) || { label: formatBucketLabel(key, granularity), gross: 0, net: 0, refund: 0 };
    cur.gross += Number(row.grossRevenue ?? row.amount ?? 0);
    cur.net += Number(row.netRevenue ?? row.amount ?? 0);
    cur.refund += Number(row.simulatedRefunds ?? 0);
    map.set(key, cur);
  }
  return Array.from(map.values());
}

function formatCompactVnd(value) {
  const num = Number(value || 0);
  const abs = Math.abs(num);
  const sign = num < 0 ? '-' : '';
  if (abs >= 1_000_000_000) return `${sign}${(abs / 1_000_000_000).toFixed(1).replace(/\.0$/, '')} Tỷ`;
  if (abs >= 1_000_000) return `${sign}${(abs / 1_000_000).toFixed(1).replace(/\.0$/, '')} Tr`;
  if (abs >= 1_000) return `${sign}${Math.round(abs / 1_000)}K`;
  return `${sign}${abs} ₫`;
}

function shiftIsoDate(isoDate, deltaDays) {
  const [year, month, day] = String(isoDate).split('-').map(Number);
  const utc = Date.UTC(year, month - 1, day + deltaDays);
  return new Date(utc).toISOString().slice(0, 10);
}

function diffIsoDaysInclusive(from, to) {
  const start = Date.parse(`${from}T00:00:00Z`);
  const end = Date.parse(`${to}T00:00:00Z`);
  if (Number.isNaN(start) || Number.isNaN(end) || end < start) return 1;
  return Math.round((end - start) / 86400000) + 1;
}

function computePreviousPeriod(from, to, overrideSpanDays = null) {
  const spanDays = overrideSpanDays || diffIsoDaysInclusive(from, to);
  const compareTo = shiftIsoDate(from, -1);
  const compareFrom = shiftIsoDate(compareTo, -(spanDays - 1));
  return { compareFrom, compareTo, spanDays };
}

function renderTrendLine(metricComparison, { invertTrend = false, formatPrev } = {}) {
  if (!metricComparison) return '';
  const delta = Number(metricComparison.delta ?? 0);
  const pct = Math.abs(Number(metricComparison.percentChange ?? 0));
  const pctText = pct.toFixed(1).replace(/\.0$/, '');
  const prevFormatted = formatPrev
    ? formatPrev(metricComparison.previous ?? 0)
    : String(metricComparison.previous ?? 0);

  let cls = 'is-flat';
  let trendIcon = '';
  let label = 'Không đổi 0%';

  if (delta > 0) {
    cls = invertTrend ? 'is-negative' : 'is-positive';
    trendIcon = icon('trendUp', 13);
    label = `Tăng ${pctText}%`;
  } else if (delta < 0) {
    cls = invertTrend ? 'is-positive' : 'is-negative';
    trendIcon = icon('trendDown', 13);
    label = `Giảm ${pctText}%`;
  }

  return `<div class="kpi-trend ${cls}">
    <span class="kpi-trend-pill">${trendIcon}${esc(label)}</span>
    <span class="kpi-trend-note">so với kỳ trước (${esc(prevFormatted)})</span>
  </div>`;
}

export function destroyDashboardChart() {
  if (activeChart?.destroy) {
    activeChart.destroy();
  }
  activeChart = null;
}

export async function renderDashboardPage({ root, params, shell, ChartCtor }) {
  destroyDashboardChart();

  const today = isoDateVN();
  const from = params.get('from') || daysAgoVN(29);
  const to = params.get('to') || today;
  const compareFromParam = params.get('compareFrom') || '';
  const compareToParam = params.get('compareTo') || '';
  const isComparing = Boolean(compareFromParam && compareToParam);

  shell({
    section: 'dashboard',
    contentHtml: renderDashboardSkeleton(),
  });

  try {
    let data;
    let comparison = null;
    let activeCompareFrom = compareFromParam;
    let activeCompareTo = compareToParam;

    if (isComparing) {
      const compareQuery = buildQuery({
        from,
        to,
        compareFrom: compareFromParam,
        compareTo: compareToParam,
      });
      const response = await api(`/admin/dashboard/compare${compareQuery}`);
      const payload = response?.data || {};
      data = payload?.current?.dashboard || payload?.dashboard || {};
      comparison = payload?.comparison || null;
      activeCompareFrom = payload?.previous?.from || compareFromParam;
      activeCompareTo = payload?.previous?.to || compareToParam;
    } else {
      const query = buildQuery({ from, to });
      const response = await api(`/admin/dashboard${query}`);
      data = response?.data || {};
    }

    const membersActive = Number(data?.members?.active ?? 0);
    const membersDisabled = Number(data?.members?.disabled ?? 0);
    const coachesActive = Number(data?.coaches?.active ?? 0);
    const coachesDisabled = Number(data?.coaches?.disabled ?? 0);
    const activeMemberships = Number(data?.activeMemberships ?? 0);
    const activeCoachRels = Number(data?.activeCoachRelationships ?? 0);

    const coachLockedWaiting = Number(data?.actionQueue?.coachLockedWaitingCount ?? data?.pausedCoachRelationships?.coachLocked ?? 0);
    const disputedCount = Number(data?.actionQueue?.disputedTerminationCount ?? data?.pendingTerminationRequests ?? 0);

    // Support both T3 V2 revenue envelope and baseline revenue.amount safely
    const rev = data?.revenue || {};
    const grossRevenue = Number(rev.grossRevenue ?? rev.amount ?? 0);
    const totalRefunds = Number(rev.totalSimulatedRefunds ?? 0);
    const totalVoidReversals = Number(rev.totalVoidReversals ?? 0);
    const voidReversalCount = Number(rev.voidReversalCount ?? 0);
    const simulatedRefundCount = Number(rev.simulatedRefundCount ?? 0);
    const netRevenue = Number(rev.netRevenue ?? (grossRevenue - totalRefunds));
    const revChart = data?.revenueChart || {};
    const chartByDay = Array.isArray(revChart.byDay)
      ? revChart.byDay
      : (Array.isArray(rev.byDay) ? rev.byDay : []);
    const chartFrom = revChart.from || shiftIsoDate(today, -180);
    const chartTo = revChart.to || today;

    const kpis = [
      {
        label: 'Hội viên hoạt động',
        value: String(membersActive),
        meta: `${membersActive + membersDisabled} tổng · ${membersDisabled} đang khóa`,
        iconName: 'users',
        variant: 'is-info',
        href: '#/admin/members?status=ACTIVE',
        trend: comparison?.membersActive,
        invertTrend: false,
      },
      {
        label: 'Huấn luyện viên hoạt động',
        value: String(coachesActive),
        meta: `${coachesDisabled} đang bị khóa`,
        iconName: 'award',
        variant: 'is-gold',
        href: '#/admin/coaches?status=ACTIVE',
        trend: comparison?.coachesActive,
        invertTrend: false,
      },
      {
        label: 'Gói Gym đang sử dụng',
        value: String(activeMemberships),
        meta: 'Hội viên có quyền vào phòng tập',
        iconName: 'card',
        variant: 'is-coral',
        href: '#/admin/plans?tab=entitlements&status=ACTIVE',
        trend: comparison?.activeMemberships,
        invertTrend: false,
      },
    ];

    const currentFrom = data.from || from;
    const currentTo = data.to || to;
    const paymentsLink = `#/admin/payments?from=${encodeURIComponent(currentFrom)}&to=${encodeURIComponent(currentTo)}`;
    const monthStart = `${today.slice(0, 8)}01`;
    const autoPrev = computePreviousPeriod(currentFrom, currentTo);

    const chartHasRefunds = chartByDay.some((row) => Number(row.simulatedRefunds ?? 0) > 0);
    const chartLegendHtml = chartByDay.length > 0 ? `<div class="chart-legend" aria-label="Chú thích biểu đồ">
      <span class="chart-legend-item"><span class="chart-legend-dot" style="background:#2ECC71"></span>Doanh thu thực nhận</span>
      <span class="chart-legend-item"><span class="chart-legend-dot" style="background:#FF5E36"></span>Tổng thu</span>
      ${chartHasRefunds ? '<span class="chart-legend-item"><span class="chart-legend-dot" style="background:#F15B64"></span>Tiền đã hoàn</span>' : ''}
    </div>` : '';

    const contentHtml = `<div class="stack-20">
      <form class="filter-bar" id="dashboard-period-form">
        <div class="desktop-filters" style="display:flex;align-items:center;gap:8px;flex-wrap:wrap;flex:1">
          ${renderDateInput({ id: 'dash-from', name: 'from', value: currentFrom, ariaLabel: 'Từ ngày' })}
          <span style="color:var(--meta-text-secondary)">đến</span>
          ${renderDateInput({ id: 'dash-to', name: 'to', value: currentTo, ariaLabel: 'Đến ngày' })}
          <button type="submit" class="btn btn-graphite btn-sm">Áp dụng</button>
        </div>
        <div class="mobile-filters" style="flex:1;width:100%">
          ${renderDateRangePicker({ id: 'dash-range', from: currentFrom, to: currentTo })}
        </div>
        <div style="display:flex;gap:6px;flex-wrap:wrap;align-items:center">
          <button type="button" class="pill-toggle ${currentTo === today && currentFrom === daysAgoVN(6) ? 'active' : ''}" data-quick-range="7">7 ngày</button>
          <button type="button" class="pill-toggle ${currentTo === today && currentFrom === daysAgoVN(29) ? 'active' : ''}" data-quick-range="30">30 ngày</button>
          <button type="button" class="pill-toggle ${currentTo === today && currentFrom === daysAgoVN(59) ? 'active' : ''}" data-quick-range="60">60 ngày</button>
          <button type="button" class="pill-toggle ${currentTo === today && currentFrom === daysAgoVN(89) ? 'active' : ''}" data-quick-range="90">90 ngày</button>
          <button type="button" class="pill-toggle ${currentTo === today && currentFrom === monthStart ? 'active' : ''}" data-quick-range="month">Tháng này</button>
          <button type="button" class="pill-toggle dash-compare-toggle ${isComparing ? 'active' : ''}" id="dash-compare-btn" aria-pressed="${isComparing ? 'true' : 'false'}" title="So sánh với kỳ trước (${formatDateVN(autoPrev.compareFrom)} – ${formatDateVN(autoPrev.compareTo)})">
            ${icon('swap', 14)} ${isComparing ? `Kỳ trước (${formatShortDay(activeCompareFrom)}–${formatShortDay(activeCompareTo)})` : 'So sánh kỳ trước'}
          </button>
        </div>
      </form>

      <div class="grid-3">
        <a class="kpi-card is-coral" href="${paymentsLink}">
          <span class="kpi-watermark" aria-hidden="true">${icon('receipt', 88)}</span>
          <div class="kpi-top"><span class="kpi-label">Tổng thu</span><span class="kpi-icon">${icon('receipt', 17)}</span></div>
          <div class="kpi-val tabular">${vnd(grossRevenue)}</div>
          ${renderTrendLine(comparison?.grossRevenue, { invertTrend: false, formatPrev: vnd })}
          <div class="kpi-meta"><span>${totalVoidReversals > 0 ? `Đã trừ giao dịch hủy: ${vnd(totalVoidReversals)}${voidReversalCount ? ` (${voidReversalCount} GD)` : ''}` : 'Tổng tiền gói Gym & Coach'}</span><span class="kpi-link-hint">Xem giao dịch →</span></div>
        </a>
        <a class="kpi-card is-danger" href="#/admin/incidents?tab=refunds">
          <span class="kpi-watermark" aria-hidden="true">${icon('refund', 88)}</span>
          <div class="kpi-top"><span class="kpi-label">Tiền đã hoàn</span><span class="kpi-icon">${icon('refund', 17)}</span></div>
          <div class="kpi-val tabular" style="color:var(--meta-danger-text)">${vnd(totalRefunds > 0 ? -totalRefunds : 0)}</div>
          ${renderTrendLine(comparison?.totalSimulatedRefunds, { invertTrend: true, formatPrev: vnd })}
          <div class="kpi-meta"><span>${simulatedRefundCount > 0 ? `${simulatedRefundCount} lượt hoàn do sự cố Coach` : 'Các khoản hoàn tiền sự cố Coach'}</span><span class="kpi-link-hint">Xem chi tiết →</span></div>
        </a>
        <a class="kpi-card is-success" href="${paymentsLink}">
          <span class="kpi-watermark" aria-hidden="true">${icon('check', 88)}</span>
          <div class="kpi-top"><span class="kpi-label">Doanh thu thực nhận</span><span class="kpi-icon">${icon('check', 17)}</span></div>
          <div class="kpi-val tabular" style="color:var(--meta-success)">${vnd(netRevenue)}</div>
          ${renderTrendLine(comparison?.netRevenue, { invertTrend: false, formatPrev: vnd })}
          <div class="kpi-meta"><span>Tổng thu sau khi trừ hoàn tiền & hủy</span><span class="kpi-link-hint">Đối soát →</span></div>
        </a>
      </div>

      <div class="grid-3">
        ${kpis.map((item) => `<a class="kpi-card ${item.variant || ''}" href="${item.href}">
          <span class="kpi-watermark" aria-hidden="true">${icon(item.iconName, 88)}</span>
          <div class="kpi-top">
            <span class="kpi-label">${esc(item.label)}</span>
            <span class="kpi-icon">${icon(item.iconName, 17)}</span>
          </div>
          <div class="kpi-val tabular"${item.tone ? ` style="color:${item.tone}"` : ''}>${esc(item.value)}</div>
          ${renderTrendLine(item.trend, { invertTrend: item.invertTrend })}
          <div class="kpi-meta"><span>${esc(item.meta)}</span><span class="kpi-link-hint">Mở danh sách →</span></div>
        </a>`).join('')}
      </div>

      <section class="meta-card" aria-label="Biểu đồ doanh thu">
        <div class="card-header-row">
          <div>
            <h2 class="card-title-text">Doanh thu theo thời gian (6 tháng gần nhất: ${formatDateVN(chartFrom)} – ${formatDateVN(chartTo)})</h2>
            <p class="card-sub">Tổng thu, tiền đã hoàn và doanh thu thực nhận trong vòng 6 tháng gần nhất (không phụ thuộc bộ lọc kỳ phía trên).</p>
          </div>
          ${chartByDay.length > 0 ? `<div class="chart-controls">
            <div class="chart-segmented" role="group" aria-label="Nhóm thời gian">
              <button type="button" class="chart-seg-btn ${chartGranularity === 'month' ? 'active' : ''}" data-chart-gran="month">Tháng</button>
              <button type="button" class="chart-seg-btn ${chartGranularity === 'week' ? 'active' : ''}" data-chart-gran="week">Tuần</button>
              <button type="button" class="chart-seg-btn ${chartGranularity === 'day' ? 'active' : ''}" data-chart-gran="day">Ngày</button>
            </div>
            <div class="chart-segmented" role="group" aria-label="Kiểu biểu đồ">
              <button type="button" class="chart-seg-btn chart-seg-icon ${chartType === 'bar' ? 'active' : ''}" data-chart-type="bar" aria-label="Biểu đồ cột" title="Biểu đồ cột">${icon('chartBar', 16)}</button>
              <button type="button" class="chart-seg-btn chart-seg-icon ${chartType === 'line' ? 'active' : ''}" data-chart-type="line" aria-label="Biểu đồ đường" title="Biểu đồ đường">${icon('chartLine', 16)}</button>
            </div>
          </div>` : ''}
        </div>
        ${chartLegendHtml}
        ${chartByDay.length === 0
          ? renderEmptyState({
            iconName: 'receipt',
            title: 'Chưa phát sinh doanh thu trong 6 tháng gần nhất',
            description: 'Ghi nhận giao dịch gói Gym hoặc gói Coach tại quầy để hiển thị biểu đồ.',
          })
          : '<div class="chart-scroll" id="revenue-chart-scroll"><div class="chart-wrap" id="revenue-chart-wrap"><canvas id="revenue-chart"></canvas></div></div>'}
      </section>
    </div>`;

    shell({
      section: 'dashboard',
      contentHtml,
      badges: { incidents: coachLockedWaiting, disputes: disputedCount },
    });

    const navigateDashboard = (nextQuery) => {
      updateQuery(nextQuery, { replace: false });
      const searchParams = new URLSearchParams();
      Object.entries(nextQuery).forEach(([k, v]) => {
        if (v) searchParams.set(k, v);
      });
      renderDashboardPage({ root, params: searchParams, shell, ChartCtor });
    };

    const applyPeriod = (nextFrom, nextTo) => {
      if (nextFrom && nextTo && nextFrom <= nextTo) {
        if (isComparing) {
          const nextPrev = computePreviousPeriod(nextFrom, nextTo);
          navigateDashboard({
            from: nextFrom,
            to: nextTo,
            compareFrom: nextPrev.compareFrom,
            compareTo: nextPrev.compareTo,
          });
        } else {
          navigateDashboard({ from: nextFrom, to: nextTo, compareFrom: null, compareTo: null });
        }
      }
    };

    bindDatePickers(root, {
      onChange: ({ id, value }) => {
        if (id === 'dash-from' || id === 'dash-to') {
          const nextFrom = id === 'dash-from' ? value : root.querySelector('#dash-from')?.value;
          const nextTo = id === 'dash-to' ? value : root.querySelector('#dash-to')?.value;
          if (nextFrom && nextTo && nextFrom > nextTo) {
            if (id === 'dash-from') setDatePickerValue(root, 'dash-to', nextFrom);
            else setDatePickerValue(root, 'dash-from', nextTo);
          }
        }
      },
    });

    bindDateRangePicker(root, {
      id: 'dash-range',
      onChange: ({ from: nextFrom, to: nextTo }) => {
        setDatePickerValue(root, 'dash-from', nextFrom);
        setDatePickerValue(root, 'dash-to', nextTo);
        applyPeriod(nextFrom, nextTo);
      },
    });

    const periodForm = root.querySelector('#dashboard-period-form');
    if (periodForm) {
      periodForm.onsubmit = (event) => {
        event.preventDefault();
        const nextFrom = root.querySelector('#dash-from')?.value;
        const nextTo = root.querySelector('#dash-to')?.value;
        applyPeriod(nextFrom, nextTo);
      };
    }

    root.querySelectorAll('[data-quick-range]').forEach((btn) => {
      btn.onclick = () => {
        const range = btn.dataset.quickRange;
        const nextFrom = range === '7'
          ? daysAgoVN(6)
          : range === '60'
            ? daysAgoVN(59)
            : range === '90'
              ? daysAgoVN(89)
              : range === 'month'
                ? monthStart
                : daysAgoVN(29);
        applyPeriod(nextFrom, today);
      };
    });

    const compareBtn = root.querySelector('#dash-compare-btn');
    if (compareBtn) {
      compareBtn.onclick = () => {
        if (isComparing) {
          navigateDashboard({ from: currentFrom, to: currentTo, compareFrom: null, compareTo: null });
        } else {
          navigateDashboard({
            from: currentFrom,
            to: currentTo,
            compareFrom: autoPrev.compareFrom,
            compareTo: autoPrev.compareTo,
          });
        }
      };
    }

    const drawChart = () => {
      const canvas = root.querySelector('#revenue-chart');
      if (!canvas || chartByDay.length === 0 || !ChartCtor) return;
      destroyDashboardChart();

      const series = groupRevenueSeries(chartByDay, chartGranularity);
      const pxPerPoint = chartGranularity === 'month' ? 96 : chartGranularity === 'week' ? 84 : 56;
      const chartScroll = root.querySelector('#revenue-chart-scroll');
      const chartWrap = root.querySelector('#revenue-chart-wrap');
      if (chartWrap?.style) {
        const minTrackWidth = Math.max(series.length * pxPerPoint, 0);
        chartWrap.style.width = minTrackWidth > 0 ? `${minTrackWidth}px` : '100%';
      }
      const isLight = globalThis.document?.documentElement?.getAttribute?.('data-bs-theme') === 'light';
      const surfaceColor = isLight ? '#FFFFFF' : '#181B22';
      const tickColor = isLight ? '#4D5968' : '#8E95A5';
      const gridColor = isLight ? 'rgba(17, 21, 26, 0.08)' : 'rgba(255, 255, 255, 0.08)';
      const isLine = chartType === 'line';
      const hasRefunds = series.some((row) => row.refund > 0);
      const netData = series.map((row) => row.net);

      try {
        activeChart = new ChartCtor(canvas, {
          type: chartType,
          data: {
            labels: series.map((row) => row.label),
            datasets: [
              {
                label: 'Doanh thu thực nhận',
                data: netData,
                borderColor: '#2ECC71',
                backgroundColor: isLine ? 'rgba(46, 204, 113, 0.08)' : '#2ECC71',
                borderWidth: isLine ? 2.4 : 0,
                borderRadius: isLine ? 0 : 6,
                maxBarThickness: 28,
                tension: 0.12,
                pointRadius: isLine ? 4 : 0,
                pointHoverRadius: isLine ? 6 : 0,
                pointBorderWidth: 2.2,
                pointBackgroundColor: surfaceColor,
                pointBorderColor: '#2ECC71',
              },
              {
                label: 'Tổng thu',
                data: series.map((row) => row.gross),
                borderColor: '#FF5E36',
                backgroundColor: isLine ? 'transparent' : '#FF5E36',
                borderWidth: isLine ? 2 : 0,
                borderRadius: isLine ? 0 : 6,
                maxBarThickness: 28,
                tension: 0.12,
                pointRadius: isLine ? 3.5 : 0,
                pointHoverRadius: isLine ? 5.5 : 0,
                pointBorderWidth: 2,
                pointBackgroundColor: surfaceColor,
                pointBorderColor: '#FF5E36',
              },
              ...(hasRefunds ? [{
                label: 'Tiền đã hoàn',
                data: series.map((row) => row.refund),
                borderColor: '#F15B64',
                backgroundColor: isLine ? 'transparent' : '#F15B64',
                borderWidth: isLine ? 2 : 0,
                borderRadius: isLine ? 0 : 6,
                maxBarThickness: 28,
                tension: 0.12,
                pointRadius: isLine ? 3.5 : 0,
                pointHoverRadius: isLine ? 5.5 : 0,
                pointBorderWidth: 2,
                pointBackgroundColor: surfaceColor,
                pointBorderColor: '#F15B64',
              }] : []),
            ],
          },
          options: {
            responsive: true,
            maintainAspectRatio: false,
            animation: { duration: 180 },
            interaction: { mode: 'index', intersect: false },
            hover: { mode: 'index', intersect: false, animationDuration: 0 },
            plugins: {
              legend: {
                display: false,
              },
              tooltip: {
                animation: false,
                backgroundColor: isLight ? '#11151A' : '#1F232C',
                titleFont: { family: 'Be Vietnam Pro', size: 12, weight: '700' },
                bodyFont: { family: 'Be Vietnam Pro', size: 12 },
                padding: 10,
                cornerRadius: 10,
                callbacks: {
                  label: (ctx) => `${ctx.dataset.label}: ${vnd(ctx.parsed.y)}`,
                },
              },
            },
            scales: {
              x: {
                ticks: {
                  color: tickColor,
                  font: { family: 'Be Vietnam Pro', size: 11.5 },
                  autoSkip: false,
                  maxRotation: 0,
                },
                grid: { display: false },
                border: { display: false },
              },
              y: {
                ticks: {
                  color: tickColor,
                  font: { family: 'Be Vietnam Pro', size: 11.5 },
                  callback: (val) => formatCompactVnd(val),
                },
                grid: { color: gridColor, tickLength: 0 },
                border: { display: false, dash: [4, 4] },
              },
            },
          },
        });

        canvas.onmouseleave = () => {
          if (!activeChart) return;
          activeChart.setActiveElements?.([]);
          activeChart.tooltip?.setActiveElements?.([], { x: 0, y: 0 });
          activeChart.update?.('none');
        };

        if (chartScroll && typeof chartScroll.scrollWidth === 'number') {
          chartScroll.scrollLeft = chartScroll.scrollWidth;
        }
      } catch {
        // Ignore headless canvas context errors in unit test harnesses
      }
    };

    drawChart();

    root.querySelectorAll('[data-chart-gran]').forEach((btn) => {
      btn.onclick = () => {
        chartGranularity = btn.dataset.chartGran || 'day';
        root.querySelectorAll('[data-chart-gran]').forEach((b) => {
          b.classList.toggle('active', b === btn);
        });
        drawChart();
      };
    });

    root.querySelectorAll('[data-chart-type]').forEach((btn) => {
      btn.onclick = () => {
        chartType = btn.dataset.chartType || 'line';
        root.querySelectorAll('[data-chart-type]').forEach((b) => {
          b.classList.toggle('active', b === btn);
        });
        drawChart();
      };
    });
  } catch (error) {
    shell({
      section: 'dashboard',
      topbarActionsHtml: `<button type="button" class="btn btn-graphite btn-sm" id="retry-load-btn">${icon('refresh', 16)} Thử lại</button>`,
      contentHtml: renderDashboardSkeleton(),
    });
    toast(error?.message || 'Không tải được dữ liệu tổng quan.', 'danger');
    const retry = root.querySelector('#retry-load-btn');
    if (retry) retry.onclick = () => renderDashboardPage({ root, params, shell, ChartCtor });
  }
}
