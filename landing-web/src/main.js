import 'bootstrap/dist/css/bootstrap.min.css';
import './styles/main.css';
import { icon } from './components/icons.js';
import {
  APP_HIGHLIGHTS,
  COACH_TEAM,
  FAQ_ITEMS,
  FOOTER_DISCOVER_LINKS,
  FOOTER_POLICY_LINKS,
  FREE_AMENITIES,
  GYM_PLANS,
  HERO_METRICS,
  NAV_LINKS,
  NEWS_SKELETON,
  PT_PLANS,
  SERVICE_TABS,
  TRAINING_ZONES,
} from './data/landingData.js';

const ADMIN_PORTAL_URL = 'http://localhost:5173';

let activeServiceId = SERVICE_TABS[0].id;
let activePlanType = 'gym'; // 'gym' | 'pt'
let openFaqId = FAQ_ITEMS[0].id;

function renderNavbar() {
  return `
    <header class="mg-header">
      <nav class="mg-navbar" aria-label="Điều hướng chính">
        <a class="mg-brand" href="#top">
          <span class="mg-brand-mark">${icon('brand', 20)}</span>
          <span>Meta Gym</span>
        </a>

        <ul class="mg-nav-links">
          ${NAV_LINKS.map(
            (item) => `<li><a class="mg-nav-link" href="${item.href}">${item.label}</a></li>`
          ).join('')}
        </ul>

        <div class="mg-nav-actions">
          <a class="mg-btn mg-btn-ghost" href="#app-companion">
            Tải App
          </a>
          <button type="button" class="mg-btn mg-btn-primary" data-open-trial="Đăng ký tập thử miễn phí">
            Tập thử miễn phí
          </button>
        </div>

        <button
          type="button"
          class="mg-menu-toggle"
          id="mobile-menu-btn"
          aria-label="Mở menu điều hướng"
          aria-expanded="false"
          aria-controls="mobile-nav-overlay"
        >
          ${icon('menu', 20)}
        </button>
      </nav>
    </header>
  `;
}

function renderHero() {
  return `
    <section class="mg-hero" id="top">
      <div class="mg-hero-bg" aria-hidden="true">
        <img src="/images/hero-gym.jpg" alt="" fetchpriority="high" />
      </div>

      <div class="mg-container">
        <div class="row align-items-center g-4 g-lg-5">
          <div class="col-12 col-lg-6">
            <div class="mg-eyebrow">
              <span class="mg-eyebrow-dot" aria-hidden="true"></span>
              <span>Phòng tập Hiện đại &amp; Huấn luyện Cá nhân 1-1</span>
            </div>
            <h1 class="mg-h1">
              Nâng tầm vóc dáng.<br />
              Tập luyện chuẩn mực cùng Meta Gym.
            </h1>
            <p class="mg-lead" style="color: #D2D8E4;">
              Không gian thiết bị chuẩn quốc tế kết hợp cùng đội ngũ Huấn luyện viên 1-1 và ứng dụng theo dõi lịch tập,
              dinh dưỡng, check-in QR thông minh — giúp bạn đạt mục tiêu nhanh và bền vững hơn.
            </p>

            <div class="mg-hero-actions">
              <a class="mg-btn mg-btn-lg mg-btn-primary" href="#trial-section">
                Đăng ký tập thử miễn phí
                ${icon('arrowRight', 18)}
              </a>
              <a class="mg-btn mg-btn-lg mg-btn-secondary" href="#plans">
                Xem bảng giá gói tập
              </a>
            </div>

            <div class="mg-hero-metrics">
              ${HERO_METRICS.map(
                (m) => `
                  <div>
                    <div class="mg-metric-val tabular">${m.value}</div>
                    <div class="mg-metric-lbl">${m.label}</div>
                  </div>
                `
              ).join('')}
            </div>
          </div>

          <div class="col-12 col-lg-6">
            <div class="mg-hero-stage">
              <div class="mg-device-frame">
                <div class="mg-device-topbar">
                  <div class="mg-coach-badge">
                    <span class="mg-avatar-ln" aria-hidden="true">LN</span>
                    <div>
                      <div style="font-size: 14px; font-weight: 700; color: var(--meta-text-strong);">
                        Coach Lê Hoàng Nam
                      </div>
                      <div style="font-size: 12px; color: var(--meta-text-secondary);">
                        Đồng hành 1-1 · Còn <span class="tabular">2/8</span> suất nhận mới
                      </div>
                    </div>
                  </div>
                  <span class="mg-pill mg-pill--success">Đang tập</span>
                </div>

                <div class="mg-session-box">
                  <div class="d-flex justify-content-between align-items-center mb-1">
                    <span style="font-size: 13px; font-weight: 600; color: var(--meta-text-strong);">
                      Giáo án hôm nay · Push Strength
                    </span>
                    <span class="tabular" style="font-size: 12px; font-weight: 700; color: var(--meta-primary);">
                      4 / 5 bài
                    </span>
                  </div>
                  <div style="font-size: 13px; color: var(--meta-text-secondary);">
                    Incline Dumbbell Press · 4 hiệp × 10 lần · Nghỉ 90 giây
                  </div>
                </div>

                <div class="mg-session-box mb-0">
                  <div class="d-flex justify-content-between align-items-center">
                    <span style="font-size: 13px; font-weight: 600; color: var(--meta-text-strong);">
                      Dinh dưỡng &amp; Macro mục tiêu
                    </span>
                    <span class="tabular" style="font-size: 12px; font-weight: 700; color: var(--meta-success);">
                      1.890 / 2.300 kcal
                    </span>
                  </div>
                  <div class="mg-progress-track" aria-hidden="true">
                    <div class="mg-progress-fill-green"></div>
                  </div>
                </div>
              </div>

              <!-- Single compact Level 2 Performance Glass dock -->
              <div class="mg-hero-glass-dock">
                <div class="d-flex align-items-center gap-3">
                  <span class="mg-icon-box mg-icon-box--primary mb-0" style="width: 40px; height: 40px;">
                    ${icon('qr', 18)}
                  </span>
                  <div>
                    <div style="font-size: 13px; font-weight: 700; color: var(--meta-text-strong);">
                      Check-in QR &amp; Trợ lý AI Coach 24/7
                    </div>
                    <div style="font-size: 12px; color: var(--meta-text-secondary);">
                      Quét mã vào cửa tức thì · Tư vấn bài tập mọi lúc
                    </div>
                  </div>
                </div>
                <span class="mg-pill mg-pill--info tabular">05:30–22:00</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  `;
}

function renderAmenitiesStrip() {
  return `
    <section class="mg-amenities-strip" aria-label="Tiện ích miễn phí đi kèm">
      <div class="mg-container">
        <div class="row g-3">
          ${FREE_AMENITIES.map(
            (item) => `
              <div class="col-6 col-lg-3">
                <div class="mg-amenity-item">
                  <span class="mg-check-icon">${icon('check', 16)}</span>
                  <div>
                    <div style="font-size: 14px; font-weight: 700; color: var(--meta-text-strong);">${item.title}</div>
                    <div style="font-size: 12px; color: var(--meta-text-secondary);">${item.detail}</div>
                  </div>
                </div>
              </div>
            `
          ).join('')}
        </div>
      </div>
    </section>
  `;
}

function renderZones() {
  return `
    <section class="mg-section" id="zones">
      <div class="mg-container">
        <div class="mg-section-header">
          <div class="mg-eyebrow">
            <span class="mg-eyebrow-dot" aria-hidden="true"></span>
            <span>Không gian &amp; Cơ sở vật chất</span>
          </div>
          <h2 class="mg-h2">Thiết kế tối ưu cho mọi mục tiêu tập luyện</h2>
          <p class="mg-lead">
            Từ khu tạ tự do chuyên sâu đến khu Cardio và không gian huấn luyện 1-1, mọi chi tiết tại Meta Gym đều hướng đến hiệu suất tập luyện cao nhất.
          </p>
        </div>

        <div class="row g-3 g-md-4">
          ${TRAINING_ZONES.map(
            (zone) => `
              <div class="col-12 col-lg-4">
                <article class="mg-card mg-zone-card d-flex flex-column p-0 overflow-hidden">
                  <div class="mg-zone-media">
                    <img src="${zone.image}" alt="${zone.imageAlt}" loading="lazy" />
                    <span class="mg-pill mg-pill--neutral mg-zone-badge">${zone.badge}</span>
                  </div>
                  <div class="p-3 p-md-4 d-flex flex-column flex-grow-1">
                    <h3 class="mg-h3">${zone.title}</h3>
                    <p class="mg-body">${zone.description}</p>
                    <ul class="mg-check-list mt-auto pt-3">
                      ${zone.points
                        .map(
                          (pt) => `
                            <li>
                              <span class="mg-check-icon">${icon('check', 16)}</span>
                              <span>${pt}</span>
                            </li>
                          `
                        )
                        .join('')}
                    </ul>
                  </div>
                </article>
              </div>
            `
          ).join('')}
        </div>
      </div>
    </section>
  `;
}

function renderServicePanel(service) {
  return `
    <div class="mg-card">
      <div class="row g-4 align-items-center">
        <div class="col-12 col-lg-6">
          <span class="mg-pill mg-pill--info mb-3">${service.eyebrow}</span>
          <h3 class="mg-h3" style="font-size: 24px;">${service.title}</h3>
          <p class="mg-body" style="font-size: 15px;">${service.description}</p>
          <ul class="mg-check-list">
            ${service.highlights
              .map(
                (h) => `
                  <li>
                    <span class="mg-check-icon">${icon('check', 16)}</span>
                    <span>${h}</span>
                  </li>
                `
              )
              .join('')}
          </ul>
        </div>
        <div class="col-12 col-lg-6">
          <div class="mg-session-box mb-0" style="padding: 20px;">
            <div class="d-flex align-items-center justify-content-between pb-3 mb-2 border-bottom" style="border-color: var(--meta-border) !important;">
              <span style="font-size: 15px; font-weight: 700; color: var(--meta-text-strong);">
                ${service.preview.header}
              </span>
              <span class="mg-pill mg-pill--${service.preview.statusTone}">${service.preview.status}</span>
            </div>
            <div>
              ${service.preview.rows
                .map(
                  (r) => `
                    <div class="mg-kv-row">
                      <span style="color: var(--meta-text-secondary);">${r.k}</span>
                      <strong class="tabular" style="color: var(--meta-text-strong); text-align: right;">${r.v}</strong>
                    </div>
                  `
                )
                .join('')}
            </div>
          </div>
        </div>
      </div>
    </div>
  `;
}

function renderServices() {
  const activeService = SERVICE_TABS.find((t) => t.id === activeServiceId) || SERVICE_TABS[0];

  return `
    <section class="mg-section" id="services">
      <div class="mg-container">
        <div class="mg-section-header">
          <div class="mg-eyebrow">
            <span class="mg-eyebrow-dot" aria-hidden="true"></span>
            <span>Dịch vụ &amp; Giải pháp tập luyện</span>
          </div>
          <h2 class="mg-h2">Lộ trình cá nhân hóa phù hợp với từng thể trạng</h2>
          <p class="mg-lead">
            Chọn hình thức tập luyện bạn quan tâm để xem cách Meta Gym đồng hành cùng bạn mỗi ngày.
          </p>
        </div>

        <div class="mg-tab-list" role="tablist" aria-label="Dịch vụ tại Meta Gym">
          ${SERVICE_TABS.map(
            (tab) => `
              <button
                type="button"
                class="mg-tab-btn"
                role="tab"
                data-service-tab="${tab.id}"
                aria-selected="${tab.id === activeService.id ? 'true' : 'false'}"
              >
                ${icon(tab.icon, 17)}
                <span>${tab.label}</span>
              </button>
            `
          ).join('')}
        </div>

        <div id="service-panel-slot" role="tabpanel">
          ${renderServicePanel(activeService)}
        </div>
      </div>
    </section>
  `;
}

function renderCoaches() {
  return `
    <section class="mg-section" id="coaches">
      <div class="mg-container">
        <div class="mg-section-header">
          <div class="mg-eyebrow">
            <span class="mg-eyebrow-dot" aria-hidden="true"></span>
            <span>Đội ngũ Huấn luyện viên</span>
          </div>
          <h2 class="mg-h2">Tận tâm đồng hành — Giới hạn tối đa 8 học viên / Coach</h2>
          <p class="mg-lead">
            Chúng tôi không nhận học viên ồ ạt. Mỗi Huấn luyện viên chỉ phụ trách tối đa 8 học viên để đảm bảo chất lượng giáo án và kết quả thực tế cho từng người.
          </p>
        </div>

        <div class="row g-3 g-md-4">
          ${COACH_TEAM.map(
            (coach) => `
              <div class="col-12 col-lg-4">
                <article class="mg-card d-flex flex-column">
                  <div class="d-flex align-items-center justify-content-between gap-3 mb-3">
                    <div class="d-flex align-items-center gap-3">
                      <span
                        class="mg-avatar-ln"
                        style="${coach.isPrimaryCoach ? '' : 'background: var(--meta-surface-raised); color: var(--meta-text-strong); border: 1px solid var(--meta-border-strong);'}"
                        aria-hidden="true"
                      >
                        ${coach.initials}
                      </span>
                      <div>
                        <h3 class="mg-h3 mb-0" style="font-size: 17px;">${coach.name}</h3>
                        <div style="font-size: 13px; color: var(--meta-text-secondary);">${coach.specialty}</div>
                      </div>
                    </div>
                  </div>
                  <div class="mb-3">
                    <span class="mg-pill mg-pill--neutral tabular">${coach.slots}</span>
                  </div>
                  <p class="mg-body">${coach.bio}</p>
                  <div class="d-flex flex-wrap gap-2 mt-auto pt-3">
                    ${coach.tags
                      .map((tag) => `<span class="mg-pill mg-pill--info">${tag}</span>`)
                      .join('')}
                  </div>
                </article>
              </div>
            `
          ).join('')}
        </div>
      </div>
    </section>
  `;
}

function renderPlansContent() {
  const plans = activePlanType === 'pt' ? PT_PLANS : GYM_PLANS;

  return `
    <div class="row g-3 g-md-4">
      ${plans
        .map(
          (plan) => `
            <div class="col-12 col-lg-4">
              <article class="mg-card ${plan.featured ? 'mg-card-featured' : ''} d-flex flex-column">
                <div class="d-flex align-items-center justify-content-between gap-2 mb-2">
                  <h3 class="mg-h3 mb-0">${plan.name}</h3>
                  ${plan.badge ? `<span class="mg-pill mg-pill--primary">${plan.badge}</span>` : ''}
                </div>
                <div class="d-flex align-items-baseline gap-2 my-3">
                  <span class="mg-price tabular">${plan.price}</span>
                  <span style="font-size: 13px; color: var(--meta-text-secondary);">${plan.period}</span>
                </div>
                <p class="mg-body">${plan.summary}</p>
                <ul class="mg-check-list mb-4">
                  ${plan.features
                    .map(
                      (f) => `
                        <li>
                          <span class="mg-check-icon">${icon('check', 16)}</span>
                          <span>${f}</span>
                        </li>
                      `
                    )
                    .join('')}
                </ul>
                <button
                  type="button"
                  class="mg-btn ${plan.featured ? 'mg-btn-primary' : 'mg-btn-secondary'} w-100 mt-auto"
                  data-open-trial="Đăng ký ${plan.name}"
                >
                  ${plan.cta}
                </button>
              </article>
            </div>
          `
        )
        .join('')}
    </div>
  `;
}

function renderPlans() {
  return `
    <section class="mg-section" id="plans">
      <div class="mg-container">
        <div class="d-flex flex-column flex-md-row align-items-md-end justify-content-between gap-3 mb-4 mb-md-5">
          <div class="mg-section-header mb-0">
            <div class="mg-eyebrow">
              <span class="mg-eyebrow-dot" aria-hidden="true"></span>
              <span>Bảng giá minh bạch</span>
            </div>
            <h2 class="mg-h2 mb-0">Chọn gói tập phù hợp với mục tiêu của bạn</h2>
          </div>

          <div class="mg-segmented" role="group" aria-label="Chọn loại gói tập">
            <button
              type="button"
              class="mg-segmented-btn"
              data-plan-toggle="gym"
              aria-pressed="${activePlanType === 'gym' ? 'true' : 'false'}"
            >
              Gói tập Gym
            </button>
            <button
              type="button"
              class="mg-segmented-btn"
              data-plan-toggle="pt"
              aria-pressed="${activePlanType === 'pt' ? 'true' : 'false'}"
            >
              Gói PT 1-1 (Coach)
            </button>
          </div>
        </div>

        <div id="plans-grid-slot">
          ${renderPlansContent()}
        </div>
      </div>
    </section>
  `;
}

function renderAppAndFaq() {
  return `
    <section class="mg-section" id="app-companion">
      <div class="mg-container">
        <div class="mg-section-header">
          <div class="mg-eyebrow">
            <span class="mg-eyebrow-dot" aria-hidden="true"></span>
            <span>Ứng dụng Meta Gym</span>
          </div>
          <h2 class="mg-h2">Trợ thủ tập luyện gọn nhẹ ngay trên điện thoại</h2>
          <p class="mg-lead">
            Mọi hội viên Meta Gym đều được sử dụng miễn phí ứng dụng di động để check-in, theo dõi buổi tập và kết nối với huấn luyện viên.
          </p>
        </div>

        <div class="row g-3 g-md-4 mb-5">
          ${APP_HIGHLIGHTS.map(
            (item) => `
              <div class="col-12 col-sm-6 col-lg-3">
                <article class="mg-card">
                  <span class="mg-icon-box">${icon(item.icon, 20)}</span>
                  <h3 class="mg-h3" style="font-size: 17px;">${item.title}</h3>
                  <p class="mg-body">${item.description}</p>
                </article>
              </div>
            `
          ).join('')}
        </div>

        <div id="faq" class="pt-3">
          <div class="mg-section-header mb-4">
            <div class="mg-eyebrow">
              <span class="mg-eyebrow-dot" aria-hidden="true"></span>
              <span>Câu hỏi thường gặp</span>
            </div>
            <h2 class="mg-h2">Giải đáp thắc mắc trước khi bắt đầu</h2>
          </div>

          <div class="d-flex flex-column gap-3">
            ${FAQ_ITEMS.map((item) => {
              const isOpen = item.id === openFaqId;
              return `
                <div class="mg-card p-0 overflow-hidden">
                  <button
                    type="button"
                    class="mg-faq-btn"
                    data-faq-btn="${item.id}"
                    aria-expanded="${isOpen ? 'true' : 'false'}"
                  >
                    <span>${item.question}</span>
                    <span class="mg-faq-chevron" aria-hidden="true">${icon('arrowRight', 18)}</span>
                  </button>
                  <div class="mg-faq-panel" data-faq-panel="${item.id}" ${isOpen ? '' : 'hidden'}>
                    <p class="mg-body" style="font-size: 15px;">${item.answer}</p>
                  </div>
                </div>
              `;
            }).join('')}
          </div>
        </div>
      </div>
    </section>
  `;
}

function renderNewsSkeleton() {
  return `
    <section class="mg-section pt-2" id="news">
      <div class="mg-container">
        <div class="d-flex flex-column flex-md-row align-items-md-end justify-content-between gap-3 mb-4">
          <div class="mg-section-header mb-0">
            <div class="mg-eyebrow">
              <span class="mg-eyebrow-dot" aria-hidden="true"></span>
              <span>Tin tức &amp; MetaRewards</span>
            </div>
            <h2 class="mg-h2 mb-0">Cập nhật sự kiện &amp; Cẩm nang tập luyện</h2>
          </div>
          <a class="mg-btn mg-btn-ghost" href="#trial-section">Xem thêm (Skeleton)</a>
        </div>

        <div class="row g-3 g-md-4">
          ${NEWS_SKELETON.map(
            (post) => `
              <div class="col-12 col-lg-4">
                <article class="mg-card d-flex flex-column">
                  <div class="d-flex align-items-center justify-content-between gap-2 mb-3">
                    <span class="mg-pill mg-pill--info">${post.tag}</span>
                    <span style="font-size: 12px; color: var(--meta-text-secondary);">${post.date}</span>
                  </div>
                  <h3 class="mg-h3" style="font-size: 18px;">${post.title}</h3>
                  <p class="mg-body mt-auto pt-2">${post.excerpt}</p>
                </article>
              </div>
            `
          ).join('')}
        </div>
      </div>
    </section>
  `;
}

function renderEmbeddedTrialAndFooter() {
  return `
    <section class="mg-section pt-2" id="trial-section">
      <div class="mg-container">
        <div class="mg-cta-banner">
          <div class="row align-items-center g-4">
            <div class="col-12 col-lg-6">
              <div class="mg-eyebrow">
                <span class="mg-eyebrow-dot" aria-hidden="true"></span>
                <span>Ưu đãi hội viên mới</span>
              </div>
              <h2 class="mg-h2">Đăng ký tập thử miễn phí 1 buổi tại Meta Gym</h2>
              <p class="mg-lead mb-4">
                Trải nghiệm đầy đủ không gian máy tập, phòng tắm locker miễn phí và nhận tư vấn lộ trình tăng cơ, giảm mỡ trực tiếp cùng Huấn luyện viên Meta Gym.
              </p>
              <div class="d-flex flex-column gap-2" style="font-size: 14px; color: var(--meta-text-primary);">
                <div><strong>Giờ mở cửa:</strong> 05:30 – 22:00 (Thứ 2 – Chủ nhật)</div>
                <div><strong>Hotline tư vấn:</strong> <span class="tabular">1900 6868</span></div>
                <div><strong>Thanh toán hỗ trợ:</strong> VNPay · MoMo · ZaloPay · Tại quầy</div>
              </div>
            </div>

            <div class="col-12 col-lg-6">
              <form id="inline-trial-form" class="mg-card d-flex flex-column gap-3">
                <h3 class="mg-h3 mb-1">Nhận vé tập thử miễn phí</h3>
                <div>
                  <label for="inline-name" class="form-label" style="font-size: 13px; font-weight: 600;">Họ và tên</label>
                  <input id="inline-name" class="mg-form-control" type="text" placeholder="Ví dụ: Trần Minh Khoa" required />
                </div>
                <div>
                  <label for="inline-phone" class="form-label" style="font-size: 13px; font-weight: 600;">Số điện thoại</label>
                  <input id="inline-phone" class="mg-form-control" type="tel" placeholder="09xx xxx xxx" required />
                </div>
                <div>
                  <label for="inline-goal" class="form-label" style="font-size: 13px; font-weight: 600;">Mục tiêu tập luyện</label>
                  <select id="inline-goal" class="mg-form-control">
                    <option value="free-trial">Tham quan &amp; Tập thử miễn phí</option>
                    <option value="fat-loss">Giảm mỡ &amp; Cải thiện vóc dáng</option>
                    <option value="muscle">Tăng cơ &amp; Sức mạnh</option>
                    <option value="pt">Tư vấn gói PT 1-1 cùng Coach</option>
                  </select>
                </div>
                <div id="inline-trial-feedback" class="mg-pill mg-pill--success" hidden>
                  Đăng ký thành công! Bộ phận lễ tân Meta Gym sẽ liên hệ xác nhận lịch tập thử của bạn.
                </div>
                <button type="submit" class="mg-btn mg-btn-lg mg-btn-primary w-100">
                  Đăng ký tập thử ngay
                  ${icon('arrowRight', 18)}
                </button>
              </form>
            </div>
          </div>
        </div>
      </div>
    </section>

    <footer class="mg-footer">
      <div class="mg-container">
        <div class="row g-4 pb-4 border-bottom" style="border-color: var(--meta-border) !important;">
          <div class="col-12 col-lg-4">
            <div class="d-flex align-items-center gap-2 mb-3">
              <span class="mg-brand-mark" style="width: 32px; height: 32px; border-radius: 9px;">${icon('brand', 18)}</span>
              <span style="font-size: 17px; font-weight: 800; color: var(--meta-text-strong);">META GYM</span>
            </div>
            <p class="mg-body mb-2" style="color: var(--meta-text-primary); font-weight: 600;">
              HỆ THỐNG PHÒNG TẬP &amp; HUẤN LUYỆN CÁ NHÂN META GYM
            </p>
            <p class="mg-body mb-1">Mã số thuế: <em>Đang cập nhật</em></p>
            <p class="mg-body mb-1">Hotline: <span class="tabular">1900 6868</span> · Giờ mở cửa: <span class="tabular">05:30 – 22:00</span></p>
            <p class="mg-body mb-0">Địa chỉ CLB: Thành phố Hồ Chí Minh (cập nhật chi nhánh sau)</p>
          </div>

          <div class="col-6 col-md-4 col-lg-2">
            <h3 class="mg-h3" style="font-size: 14px; text-transform: uppercase; letter-spacing: 0.04em; color: var(--meta-text-secondary);">
              Khám phá
            </h3>
            <ul class="list-unstyled d-flex flex-column gap-1 mb-0">
              ${FOOTER_DISCOVER_LINKS.map(
                (l) => `<li><a class="mg-footer-link" href="${l.href}">${l.label}</a></li>`
              ).join('')}
            </ul>
          </div>

          <div class="col-6 col-md-4 col-lg-4">
            <h3 class="mg-h3" style="font-size: 14px; text-transform: uppercase; letter-spacing: 0.04em; color: var(--meta-text-secondary);">
              Danh mục &amp; Chính sách
            </h3>
            <ul class="list-unstyled d-flex flex-column gap-1 mb-0">
              ${FOOTER_POLICY_LINKS.map(
                (l) => `<li><a class="mg-footer-link" href="${l.href}">${l.label}</a></li>`
              ).join('')}
            </ul>
          </div>

          <div class="col-12 col-md-4 col-lg-2">
            <h3 class="mg-h3" style="font-size: 14px; text-transform: uppercase; letter-spacing: 0.04em; color: var(--meta-text-secondary);">
              Kết nối
            </h3>
            <ul class="list-unstyled d-flex flex-column gap-1 mb-0">
              <li><a class="mg-footer-link" href="#trial-section">Facebook (Skeleton)</a></li>
              <li><a class="mg-footer-link" href="#trial-section">YouTube (Skeleton)</a></li>
              <li><a class="mg-footer-link" href="#trial-section">TikTok (Skeleton)</a></li>
              <li><a class="mg-footer-link" href="${ADMIN_PORTAL_URL}" target="_blank" rel="noopener noreferrer">Cổng quản trị nội bộ</a></li>
            </ul>
          </div>
        </div>

        <div class="pt-3 d-flex flex-column flex-sm-row align-items-sm-center justify-content-between gap-2" style="font-size: 13px;">
          <span>© 2026 Meta Gym. Skeleton trang chủ sẵn sàng để các thành viên mở rộng trang con.</span>
          <span>Thanh toán hỗ trợ: VNPay · MoMo · ZaloPay</span>
        </div>
      </div>
    </footer>
  `;
}

function renderOverlays() {
  return `
    <!-- Mobile Navigation Overlay (Level 3 Glass) -->
    <div class="mg-overlay" id="mobile-nav-overlay" role="dialog" aria-modal="true" aria-label="Menu điều hướng" hidden>
      <div class="mg-overlay-panel">
        <div class="d-flex align-items-center justify-content-between mb-3">
          <span class="mg-brand">
            <span class="mg-brand-mark">${icon('brand', 18)}</span>
            <span>Meta Gym</span>
          </span>
          <button type="button" class="mg-menu-toggle" id="mobile-menu-close" aria-label="Đóng menu">
            ${icon('close', 20)}
          </button>
        </div>
        <div class="d-flex flex-column gap-2 mb-4">
          ${NAV_LINKS.map(
            (item) => `<a class="mg-btn mg-btn-ghost justify-content-start mobile-nav-item" href="${item.href}">${item.label}</a>`
          ).join('')}
        </div>
        <div class="d-flex flex-column gap-2">
          <a class="mg-btn mg-btn-secondary w-100 mobile-nav-item" href="#app-companion">
            Ứng dụng Meta Gym
          </a>
          <button type="button" class="mg-btn mg-btn-primary w-100" data-open-trial="Đăng ký tập thử miễn phí">
            Tập thử miễn phí
          </button>
        </div>
      </div>
    </div>

    <!-- Trial / Consultation Modal (Level 3 Overlay Glass) -->
    <div class="mg-overlay" id="trial-modal-overlay" role="dialog" aria-modal="true" aria-labelledby="trial-modal-title" hidden>
      <div class="mg-overlay-panel">
        <div class="d-flex align-items-center justify-content-between mb-3">
          <h2 class="mg-h3 mb-0" id="trial-modal-title">Đăng ký tập thử miễn phí</h2>
          <button type="button" class="mg-menu-toggle" id="trial-modal-close" aria-label="Đóng hộp thoại">
            ${icon('close', 20)}
          </button>
        </div>
        <p class="mg-body mb-3">
          Để lại thông tin bên dưới, đội ngũ Meta Gym sẽ liên hệ xác nhận lịch tập thử và tư vấn gói tập phù hợp nhất với bạn.
        </p>
        <form id="trial-form" class="d-flex flex-column gap-3">
          <div>
            <label for="trial-name" class="form-label" style="font-size: 13px; font-weight: 600;">Họ và tên</label>
            <input id="trial-name" class="mg-form-control" type="text" placeholder="Ví dụ: Nguyễn Minh Anh" required />
          </div>
          <div>
            <label for="trial-phone" class="form-label" style="font-size: 13px; font-weight: 600;">Số điện thoại liên hệ</label>
            <input id="trial-phone" class="mg-form-control" type="tel" placeholder="09xx xxx xxx" required />
          </div>
          <div>
            <label for="trial-goal" class="form-label" style="font-size: 13px; font-weight: 600;">Mục tiêu tập luyện của bạn</label>
            <select id="trial-goal" class="mg-form-control">
              <option value="fat-loss">Giảm mỡ &amp; Cải thiện vóc dáng</option>
              <option value="muscle">Tăng cơ &amp; Sức mạnh</option>
              <option value="pt">Tìm hiểu gói Huấn luyện viên 1-1 (PT)</option>
              <option value="free-trial">Tham quan phòng tập &amp; Tập thử 1 buổi</option>
            </select>
          </div>
          <div id="trial-feedback" class="mg-pill mg-pill--success" hidden>
            Đã nhận thông tin đăng ký! Lễ tân Meta Gym sẽ liên hệ xác nhận lịch tập thử với bạn trong ít phút.
          </div>
          <button type="submit" class="mg-btn mg-btn-primary w-100">Xác nhận đặt lịch tập thử</button>
        </form>
      </div>
    </div>
  `;
}

function mountApp() {
  const root = document.getElementById('app');
  root.innerHTML = `
    ${renderNavbar()}
    <main id="main-content">
      ${renderHero()}
      ${renderAmenitiesStrip()}
      ${renderZones()}
      ${renderServices()}
      ${renderCoaches()}
      ${renderPlans()}
      ${renderAppAndFaq()}
      ${renderNewsSkeleton()}
      ${renderEmbeddedTrialAndFooter()}
    </main>
    ${renderOverlays()}
  `;

  bindEvents();
}

function bindEvents() {
  // Service tabs
  document.querySelectorAll('[data-service-tab]').forEach((btn) => {
    btn.addEventListener('click', () => {
      activeServiceId = btn.dataset.serviceTab;
      document.querySelectorAll('[data-service-tab]').forEach((t) => {
        t.setAttribute('aria-selected', t.dataset.serviceTab === activeServiceId ? 'true' : 'false');
      });
      const service = SERVICE_TABS.find((t) => t.id === activeServiceId) || SERVICE_TABS[0];
      document.getElementById('service-panel-slot').innerHTML = renderServicePanel(service);
    });
  });

  // Plan type toggle (Gym vs PT 1-1)
  document.querySelectorAll('[data-plan-toggle]').forEach((btn) => {
    btn.addEventListener('click', () => {
      activePlanType = btn.dataset.planToggle;
      document.querySelectorAll('[data-plan-toggle]').forEach((b) => {
        b.setAttribute('aria-pressed', b.dataset.planToggle === activePlanType ? 'true' : 'false');
      });
      document.getElementById('plans-grid-slot').innerHTML = renderPlansContent();
      bindTrialTriggers();
    });
  });

  // FAQ accordion
  document.querySelectorAll('[data-faq-btn]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const targetId = btn.dataset.faqBtn;
      openFaqId = openFaqId === targetId ? null : targetId;
      document.querySelectorAll('[data-faq-btn]').forEach((b) => {
        const isOpen = b.dataset.faqBtn === openFaqId;
        b.setAttribute('aria-expanded', isOpen ? 'true' : 'false');
        const panel = document.querySelector(`[data-faq-panel="${b.dataset.faqBtn}"]`);
        if (panel) panel.hidden = !isOpen;
      });
    });
  });

  // Inline trial form
  document.getElementById('inline-trial-form')?.addEventListener('submit', (e) => {
    e.preventDefault();
    document.getElementById('inline-trial-feedback').hidden = false;
  });

  // Mobile nav overlay
  const mobileOverlay = document.getElementById('mobile-nav-overlay');
  const mobileBtn = document.getElementById('mobile-menu-btn');
  const closeMobileMenu = () => {
    mobileOverlay.hidden = true;
    mobileBtn.setAttribute('aria-expanded', 'false');
  };

  mobileBtn?.addEventListener('click', () => {
    mobileOverlay.hidden = false;
    mobileBtn.setAttribute('aria-expanded', 'true');
  });
  document.getElementById('mobile-menu-close')?.addEventListener('click', closeMobileMenu);
  mobileOverlay?.addEventListener('click', (e) => {
    if (e.target === mobileOverlay) closeMobileMenu();
  });
  document.querySelectorAll('.mobile-nav-item').forEach((link) => {
    link.addEventListener('click', closeMobileMenu);
  });

  // Trial modal
  const trialOverlay = document.getElementById('trial-modal-overlay');
  const trialFeedback = document.getElementById('trial-feedback');
  const closeTrialModal = () => {
    trialOverlay.hidden = true;
  };
  document.getElementById('trial-modal-close')?.addEventListener('click', closeTrialModal);
  trialOverlay?.addEventListener('click', (e) => {
    if (e.target === trialOverlay) closeTrialModal();
  });
  document.getElementById('trial-form')?.addEventListener('submit', (e) => {
    e.preventDefault();
    trialFeedback.hidden = false;
  });

  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      closeMobileMenu();
      closeTrialModal();
    }
  });

  bindTrialTriggers();
}

function bindTrialTriggers() {
  const trialOverlay = document.getElementById('trial-modal-overlay');
  const mobileOverlay = document.getElementById('mobile-nav-overlay');
  const titleEl = document.getElementById('trial-modal-title');
  const feedbackEl = document.getElementById('trial-feedback');

  document.querySelectorAll('[data-open-trial]').forEach((btn) => {
    if (btn.dataset.boundTrial === 'true') return;
    btn.dataset.boundTrial = 'true';
    btn.addEventListener('click', () => {
      mobileOverlay.hidden = true;
      feedbackEl.hidden = true;
      titleEl.textContent = btn.dataset.openTrial || 'Đăng ký tập thử miễn phí';
      trialOverlay.hidden = false;
      document.getElementById('trial-name')?.focus();
    });
  });
}

mountApp();
