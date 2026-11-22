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

  shell({
    section: 'dashboard',
    contentHtml: renderDashboardSkeleton(),
  });

  try {
    const query = buildQuery({ from, to });
    const { data } = await api(`/admin/dashboard${query}`);

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
    const byDay = Array.isArray(rev.byDay) ? rev.byDay : [];

    const kpis = [
      {
        label: 'Hội viên hoạt động',
        value: String(membersActive),
        meta: `${membersActive + membersDisabled} tổng · ${membersDisabled} đang khóa`,
        iconName: 'users',
        href: '#/admin/members?status=ACTIVE',
      },
      {
        label: 'Huấn luyện viên hoạt động',
        value: String(coachesActive),
        meta: `${coachesDisabled} đang bị khóa`,
        iconName: 'award',
        href: '#/admin/coaches?status=ACTIVE',
      },
      {
        label: 'Gói Gym đang sử dụng',
        value: String(activeMemberships),
        meta: 'Hội viên có quyền vào phòng tập',
        iconName: 'card',
        href: '#/admin/plans?tab=entitlements&status=ACTIVE',
      },
      {
        label: 'Đang tập cùng Coach',
        value: String(activeCoachRels),
        meta: `${Number(data?.pausedCoachRelationships?.total ?? 0)} cặp đang tạm ngưng`,
        iconName: 'dumbbell',
        href: '#/admin/coach-packages?tab=entitlements&status=ACTIVE',
      },
      {
        label: 'Chờ xử lý sự cố Coach',
        value: String(coachLockedWaiting),
        meta: 'Gói Coach tạm dừng do Coach bị khóa',
        iconName: 'alert',
        href: '#/admin/incidents?status=OPEN',
        tone: coachLockedWaiting > 0 ? 'var(--meta-warning)' : null,
      },
      {
        label: 'Tranh chấp cần phân xử',
        value: String(disputedCount),
        meta: 'Yêu cầu kết thúc sớm quá 72 giờ',
        iconName: 'link',
        href: '#/admin/relationships?tab=terminations&status=DISPUTED',
        tone: disputedCount > 0 ? 'var(--meta-danger)' : null,
      },
    ];

    const paymentsLink = `#/admin/payments?from=${encodeURIComponent(data.from || from)}&to=${encodeURIComponent(data.to || to)}`;
    const monthStart = `${today.slice(0, 8)}01`;

    const currentFrom = data.from || from;
    const currentTo = data.to || to;

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
        <div style="display:flex;gap:6px;flex-wrap:wrap">
          <button type="button" class="pill-toggle ${currentTo === today && currentFrom === daysAgoVN(6) ? 'active' : ''}" data-quick-range="7">7 ngày</button>
          <button type="button" class="pill-toggle ${currentTo === today && currentFrom === daysAgoVN(29) ? 'active' : ''}" data-quick-range="30">30 ngày</button>
          <button type="button" class="pill-toggle ${currentTo === today && currentFrom === monthStart ? 'active' : ''}" data-quick-range="month">Tháng này</button>
        </div>
      </form>

      <div class="grid-3">
        <a class="kpi-card" href="${paymentsLink}">
          <div class="kpi-top"><span class="kpi-label">Tổng thu</span><span class="kpi-icon">${icon('receipt', 17)}</span></div>
          <div class="kpi-val tabular">${vnd(grossRevenue)}</div>
          <div class="kpi-meta"><span>${totalVoidReversals > 0 ? `Đã trừ giao dịch hủy: ${vnd(totalVoidReversals)}${voidReversalCount ? ` (${voidReversalCount} GD)` : ''}` : 'Tổng tiền gói Gym & Coach'}</span><span class="kpi-link-hint">Xem giao dịch →</span></div>
        </a>
        <a class="kpi-card" href="#/admin/incidents?tab=refunds">
          <div class="kpi-top"><span class="kpi-label">Tiền đã hoàn</span><span class="kpi-icon" style="color:var(--meta-danger)">${icon('refund', 17)}</span></div>
          <div class="kpi-val tabular" style="color:var(--meta-danger-text)">${vnd(totalRefunds > 0 ? -totalRefunds : 0)}</div>
          <div class="kpi-meta"><span>${simulatedRefundCount > 0 ? `${simulatedRefundCount} lượt hoàn do sự cố Coach` : 'Các khoản hoàn tiền sự cố Coach'}</span><span class="kpi-link-hint">Xem chi tiết →</span></div>
        </a>
        <a class="kpi-card" href="${paymentsLink}">
          <div class="kpi-top"><span class="kpi-label">Doanh thu thực nhận</span><span class="kpi-icon" style="color:var(--meta-success)">${icon('check', 17)}</span></div>
          <div class="kpi-val tabular" style="color:var(--meta-success)">${vnd(netRevenue)}</div>
          <div class="kpi-meta"><span>Tổng thu sau khi trừ hoàn tiền & hủy</span><span class="kpi-link-hint">Đối soát →</span></div>
        </a>
      </div>

      <div class="grid-3">
        ${kpis.map((item) => `<a class="kpi-card" href="${item.href}">
          <div class="kpi-top">
            <span class="kpi-label">${esc(item.label)}</span>
            <span class="kpi-icon"${item.tone ? ` style="color:${item.tone}"` : ''}>${icon(item.iconName, 17)}</span>
          </div>
          <div class="kpi-val tabular"${item.tone ? ` style="color:${item.tone}"` : ''}>${esc(item.value)}</div>
          <div class="kpi-meta"><span>${esc(item.meta)}</span><span class="kpi-link-hint">Mở danh sách →</span></div>
        </a>`).join('')}
      </div>

      <section class="meta-card" aria-label="Biểu đồ doanh thu">
        <div class="card-header-row">
          <div>
            <h2 class="card-title-text">Doanh thu theo thời gian (${formatDateVN(data.from || from)} – ${formatDateVN(data.to || to)})</h2>
            <p class="card-sub">Tổng thu, tiền đã hoàn và doanh thu thực nhận.</p>
          </div>
          ${byDay.length > 0 ? `<div class="chart-controls">
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
        ${byDay.length === 0
          ? renderEmptyState({
            iconName: 'receipt',
            title: 'Chưa phát sinh doanh thu trong kỳ đã chọn',
            description: 'Chọn khoảng thời gian rộng hơn hoặc ghi nhận giao dịch gói Gym tại quầy.',
          })
          : '<div class="chart-wrap"><canvas id="revenue-chart"></canvas></div>'}
      </section>
    </div>`;

    shell({
      section: 'dashboard',
      contentHtml,
      badges: { incidents: coachLockedWaiting, disputes: disputedCount },
    });

    const applyPeriod = (nextFrom, nextTo) => {
      if (nextFrom && nextTo && nextFrom <= nextTo) {
        updateQuery({ from: nextFrom, to: nextTo }, { replace: false });
        renderDashboardPage({ root, params: new URLSearchParams({ from: nextFrom, to: nextTo }), shell, ChartCtor });
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
        const nextFrom = range === '7' ? daysAgoVN(6) : range === 'month' ? monthStart : daysAgoVN(29);
        updateQuery({ from: nextFrom, to: today }, { replace: false });
        renderDashboardPage({ root, params: new URLSearchParams({ from: nextFrom, to: today }), shell, ChartCtor });
      };
    });

    const drawChart = () => {
      const canvas = root.querySelector('#revenue-chart');
      if (!canvas || byDay.length === 0 || !ChartCtor) return;
      destroyDashboardChart();

      const series = groupRevenueSeries(byDay, chartGranularity);
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
                pointBorderColor: (ctx) => (Number(ctx.raw ?? 0) < 0 ? '#F15B64' : '#2ECC71'),
                segment: isLine ? {
                  borderColor: (ctx) => (
                    ctx.p0.parsed.y < 0 || ctx.p1.parsed.y < 0 ? '#F15B64' : '#2ECC71'
                  ),
                } : undefined,
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
                position: 'bottom',
                labels: {
                  color: tickColor,
                  usePointStyle: true,
                  boxWidth: 8,
                  padding: 16,
                  font: { family: 'Be Vietnam Pro', size: 12, weight: '600' },
                },
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
                ticks: { color: tickColor, font: { family: 'Be Vietnam Pro', size: 11.5 } },
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
