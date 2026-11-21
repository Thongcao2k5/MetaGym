import { api, buildQuery } from '../services/api.js';
import { daysAgoVN, esc, formatDateVN, isoDateVN, vnd } from '../components/format.js';
import { icon } from '../components/icons.js';
import { renderBanner, renderEmptyState, renderErrorState, renderSkeletonPage } from '../components/states.js';
import { updateQuery } from '../state/router.js';

let activeChart = null;

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
    contentHtml: renderSkeletonPage({ cards: 3, rows: 4 }),
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
    const coachLockedRefundReq = Number(data?.actionQueue?.coachLockedRefundRequestedCount ?? 0);
    const disputedCount = Number(data?.actionQueue?.disputedTerminationCount ?? data?.pendingTerminationRequests ?? 0);

    // Support both T3 V2 revenue envelope and baseline revenue.amount safely
    const rev = data?.revenue || {};
    const grossRevenue = Number(rev.grossRevenue ?? rev.amount ?? 0);
    const totalRefunds = Number(rev.totalSimulatedRefunds ?? 0);
    const totalVoidReversals = Number(rev.totalVoidReversals ?? 0);
    const netRevenue = Number(rev.netRevenue ?? (grossRevenue - totalRefunds));
    const byDay = Array.isArray(rev.byDay) ? rev.byDay : [];

    const urgentTotal = coachLockedWaiting + disputedCount;
    const urgentBanner = urgentTotal > 0 ? renderBanner({
      kind: 'warn',
      iconName: 'alert',
      title: `Việc cần Admin xử lý ngay (${urgentTotal} hồ sơ)`,
      textHtml: `<strong>${coachLockedWaiting} hội viên</strong> đang đóng băng gói Coach do <code>COACH_LOCKED</code>${coachLockedRefundReq ? ` (${coachLockedRefundReq} yêu cầu hoàn mô phỏng)` : ''} và <strong>${disputedCount} tranh chấp</strong> kết thúc sớm (<code>DISPUTED</code>).`,
      actionsHtml: `
        ${coachLockedWaiting > 0 ? `<a class="btn btn-primary btn-sm" href="#/admin/coach-incidents?status=OPEN">Xử lý sự cố Coach (${coachLockedWaiting})</a>` : ''}
        ${disputedCount > 0 ? `<a class="btn btn-danger btn-sm" href="#/admin/relationships?tab=terminations&status=DISPUTED">Phân xử tranh chấp (${disputedCount})</a>` : ''}
      `,
      ariaLabel: 'Việc cần xử lý khẩn',
    }) : '';

    const kpis = [
      {
        label: 'Member hoạt động',
        value: String(membersActive),
        meta: `${membersActive + membersDisabled} tổng · ${membersDisabled} bị khóa`,
        iconName: 'users',
        href: '#/admin/members?status=ACTIVE',
      },
      {
        label: 'Coach hoạt động',
        value: String(coachesActive),
        meta: `${coachesDisabled} Coach đang bị khóa`,
        iconName: 'award',
        href: '#/admin/coaches?status=ACTIVE',
      },
      {
        label: 'Gói Gym đang hiệu lực',
        value: String(activeMemberships),
        meta: 'Hội viên có quyền tập hôm nay',
        iconName: 'card',
        href: '#/admin/plans?tab=entitlements&status=ACTIVE',
      },
      {
        label: 'Quan hệ Coach đang hoạt động',
        value: String(activeCoachRels),
        meta: `${Number(data?.pausedCoachRelationships?.total ?? 0)} quan hệ đang tạm ngưng`,
        iconName: 'dumbbell',
        href: '#/admin/coach-packages?tab=entitlements&status=ACTIVE',
      },
      {
        label: 'Member chờ (COACH_LOCKED)',
        value: String(coachLockedWaiting),
        meta: 'Gói Coach đóng băng · Gym vẫn chạy',
        iconName: 'alert',
        href: '#/admin/coach-incidents?status=OPEN',
        tone: coachLockedWaiting > 0 ? 'var(--meta-warning)' : null,
      },
      {
        label: 'Yêu cầu kết thúc / Tranh chấp',
        value: String(disputedCount),
        meta: 'Tranh chấp quá 72h cần phân xử (D5)',
        iconName: 'link',
        href: '#/admin/relationships?tab=terminations&status=DISPUTED',
        tone: disputedCount > 0 ? 'var(--meta-danger)' : null,
      },
    ];

    const paymentsLink = `#/admin/payments?from=${encodeURIComponent(data.from || from)}&to=${encodeURIComponent(data.to || to)}`;
    const monthStart = `${today.slice(0, 8)}01`;

    const contentHtml = `<div class="stack-20">
      <form class="filter-bar" id="dashboard-period-form">
        <div style="display:flex;align-items:center;gap:8px;flex-wrap:wrap;flex:1">
          <span class="meta-badge meta-badge-info">Asia/Ho_Chi_Minh (GMT+7)</span>
          <input type="date" id="dash-from" name="from" class="form-control tabular" style="max-width:170px" aria-label="Từ ngày" value="${esc(data.from || from)}" required />
          <span style="color:var(--meta-text-secondary)">đến</span>
          <input type="date" id="dash-to" name="to" class="form-control tabular" style="max-width:170px" aria-label="Đến ngày" value="${esc(data.to || to)}" required />
          <button type="submit" class="btn btn-graphite btn-sm">Áp dụng</button>
        </div>
        <div style="display:flex;gap:6px;flex-wrap:wrap">
          <button type="button" class="pill-toggle" data-quick-range="7">7 ngày</button>
          <button type="button" class="pill-toggle" data-quick-range="30">30 ngày</button>
          <button type="button" class="pill-toggle" data-quick-range="month">Tháng này</button>
        </div>
      </form>

      ${urgentBanner}

      <div class="grid-3">
        <a class="kpi-card" href="${paymentsLink}">
          <div class="kpi-top"><span class="kpi-label">Doanh thu gộp (Gross)</span><span class="kpi-icon">${icon('receipt', 17)}</span></div>
          <div class="kpi-val tabular">${vnd(grossRevenue)}</div>
          <div class="kpi-meta"><span>${totalVoidReversals > 0 ? `Đã trừ đảo D6: ${vnd(totalVoidReversals)}` : 'Gói Gym & Gói Coach trong kỳ'}</span><span class="kpi-link-hint">Xem giao dịch →</span></div>
        </a>
        <a class="kpi-card" href="#/admin/coach-incidents">
          <div class="kpi-top"><span class="kpi-label">Hoàn tiền mô phỏng (D3)</span><span class="kpi-icon" style="color:var(--meta-danger)">${icon('refund', 17)}</span></div>
          <div class="kpi-val tabular" style="color:var(--meta-danger-text)">${vnd(totalRefunds > 0 ? -totalRefunds : 0)}</div>
          <div class="kpi-meta"><span>Chỉ bút toán mô phỏng sự cố Coach</span><span class="kpi-link-hint">Xem chi tiết →</span></div>
        </a>
        <a class="kpi-card" href="${paymentsLink}">
          <div class="kpi-top"><span class="kpi-label">Doanh thu ròng (Net)</span><span class="kpi-icon" style="color:var(--meta-success)">${icon('check', 17)}</span></div>
          <div class="kpi-val tabular" style="color:var(--meta-success)">${vnd(netRevenue)}</div>
          <div class="kpi-meta"><span>Gross trừ hoàn tiền mô phỏng</span><span class="kpi-link-hint">Đối soát →</span></div>
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

      <section class="meta-card" aria-label="Biểu đồ doanh thu theo ngày">
        <div class="card-header-row">
          <div>
            <h2 class="card-title-text">Doanh thu theo ngày (${formatDateVN(data.from || from)} – ${formatDateVN(data.to || to)})</h2>
            <p class="card-sub">Theo dõi doanh thu gộp, hoàn tiền mô phỏng và doanh thu ròng theo ngày Việt Nam.</p>
          </div>
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

    const periodForm = root.querySelector('#dashboard-period-form');
    if (periodForm) {
      periodForm.onsubmit = (event) => {
        event.preventDefault();
        const nextFrom = root.querySelector('#dash-from')?.value;
        const nextTo = root.querySelector('#dash-to')?.value;
        if (nextFrom && nextTo && nextFrom <= nextTo) {
          updateQuery({ from: nextFrom, to: nextTo }, { replace: false });
          renderDashboardPage({ root, params: new URLSearchParams({ from: nextFrom, to: nextTo }), shell, ChartCtor });
        }
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

    const canvas = root.querySelector('#revenue-chart');
    if (canvas && byDay.length > 0 && ChartCtor) {
      try {
        activeChart = new ChartCtor(canvas, {
          type: 'bar',
          data: {
            labels: byDay.map((row) => formatDateVN(row.day)),
            datasets: [
              {
                label: 'Doanh thu gộp (VND)',
                data: byDay.map((row) => Number(row.grossRevenue ?? row.amount ?? 0)),
                backgroundColor: '#FF5E36',
                borderRadius: 6,
              },
              {
                label: 'Doanh thu ròng (VND)',
                data: byDay.map((row) => Number(row.netRevenue ?? row.amount ?? 0)),
                backgroundColor: '#2ECC71',
                borderRadius: 6,
              },
              ...(byDay.some((row) => Number(row.simulatedRefunds ?? 0) > 0) ? [{
                label: 'Hoàn mô phỏng (VND)',
                data: byDay.map((row) => Number(row.simulatedRefunds ?? 0)),
                backgroundColor: '#F15B64',
                borderRadius: 6,
              }] : []),
            ],
          },
          options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
              legend: { labels: { color: '#8E95A5', font: { family: 'Be Vietnam Pro', size: 12 } } },
            },
            scales: {
              x: { ticks: { color: '#8E95A5' }, grid: { color: 'rgba(38, 42, 52, 0.6)' } },
              y: { ticks: { color: '#8E95A5' }, grid: { color: 'rgba(38, 42, 52, 0.6)' } },
            },
          },
        });
      } catch {
        // Ignore headless canvas context errors in unit test harnesses
      }
    }
  } catch (error) {
    shell({
      section: 'dashboard',
      contentHtml: renderErrorState({
        title: 'Không tải được dữ liệu tổng quan',
        message: error.message,
      }),
    });
    const retry = root.querySelector('#retry-load-btn');
    if (retry) retry.onclick = () => renderDashboardPage({ root, params, shell, ChartCtor });
  }
}
