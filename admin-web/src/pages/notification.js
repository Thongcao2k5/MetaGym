import {
  getNotificationPageHtml,
  bindNotificationPageEvents,
  refreshNotifications,
} from '../components/notifications.js';
import { icon } from '../components/icons.js';

export async function renderNotificationPage({ root, shell }) {
  shell({
    section: 'notification',
    topbarActionsHtml: `<button type="button" class="btn btn-graphite btn-sm" id="notif-page-refresh">${icon('refresh', 16)} Làm mới</button>`,
    contentHtml: `<div class="meta-card stack-16" id="notif-page-root">${getNotificationPageHtml()}</div>`,
  });

  bindNotificationPageEvents(root);

  const topRefresh = root.querySelector?.('#notif-page-refresh');
  if (topRefresh) {
    topRefresh.onclick = () => refreshNotifications({ force: true });
  }

  await refreshNotifications({ force: true });
}
