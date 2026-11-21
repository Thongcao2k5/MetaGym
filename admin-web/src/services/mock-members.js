const COACH_NAMES = [
  'Lê Hoàng Nam',
  'Nguyễn Minh Quân',
  'Trần Bảo Ngọc',
  'Phạm Gia Huy',
];

const FIRST_NAMES = ['Nguyễn', 'Trần', 'Lê', 'Phạm', 'Hoàng', 'Huỳnh', 'Võ', 'Đặng', 'Bùi', 'Đỗ'];
const MIDDLE_NAMES = ['Minh', 'Gia', 'Anh', 'Thảo', 'Quốc', 'Bảo', 'Ngọc', 'Thanh', 'Đức', 'Khánh'];
const LAST_NAMES = ['An', 'Bình', 'Châu', 'Dũng', 'Hà', 'Huy', 'Khang', 'Linh', 'Long', 'My', 'Nam', 'Nhi', 'Phúc', 'Trang'];

const MOCK_MEMBERS = Array.from({ length: 28 }, (_, idx) => {
  const i = idx + 1;
  const first = FIRST_NAMES[idx % FIRST_NAMES.length];
  const mid = MIDDLE_NAMES[(idx * 3) % MIDDLE_NAMES.length];
  const last = LAST_NAMES[idx % LAST_NAMES.length];
  const fullName = `${first} ${mid} ${last}`;
  const slug = `${last}.${first}.${i}`.toLowerCase()
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/đ/g, 'd');
  const isDisabled = i % 6 === 0;
  const hasGym = i % 5 !== 0;
  const relPattern = i % 4;
  const coachName = relPattern === 0 ? null : COACH_NAMES[idx % COACH_NAMES.length];

  let coachRelationshipStatus = 'NONE';
  let coachPauseReason = null;
  if (relPattern === 1) {
    coachRelationshipStatus = isDisabled ? 'PAUSED' : 'ACTIVE';
    coachPauseReason = isDisabled ? 'MEMBER_LOCKED' : null;
  } else if (relPattern === 2) {
    coachRelationshipStatus = 'PAUSED';
    coachPauseReason = isDisabled ? 'MEMBER_LOCKED' : (i % 8 === 2 ? 'COACH_LOCKED' : 'MEMBERSHIP_EXPIRED');
  } else if (relPattern === 3) {
    coachRelationshipStatus = 'ACTIVE';
  }

  return {
    id: `mock-member-${String(i).padStart(3, '0')}`,
    role: 'MEMBER',
    fullName,
    email: `${slug}@metagym.demo`,
    phone: `09${String(12000000 + i * 34567).slice(0, 8)}`,
    status: isDisabled ? 'DISABLED' : 'ACTIVE',
    createdAt: new Date(Date.UTC(2026, 8, (i % 28) + 1, 8, 30)).toISOString(),
    lastLoginAt: new Date(Date.UTC(2026, 10, (i % 20) + 1, 14, 15)).toISOString(),
    disabledAt: isDisabled ? new Date(Date.UTC(2026, 10, 18, 10, 0)).toISOString() : null,
    disabledReason: isDisabled ? 'Vi phạm nội quy check-in hoặc tạm khóa theo yêu cầu đối soát.' : null,
    activeMembershipEndDate: hasGym ? `2026-12-${String((i % 25) + 4).padStart(2, '0')}` : null,
    membershipStatus: hasGym ? 'ACTIVE' : 'EXPIRED',
    coachRelationshipStatus,
    coachPauseReason,
    coachName,
    recentAuditLogs: [
      {
        action: isDisabled ? 'ADMIN_DISABLE_USER' : 'MEMBER_CHECKIN',
        createdAt: new Date(Date.UTC(2026, 10, 19, 9, 0)).toISOString(),
        actorName: isDisabled ? 'Meta Gym Admin' : fullName,
      },
    ],
  };
});

export function handleMockApi(path, method = 'GET', body = null) {
  const [pathname, rawQuery = ''] = String(path || '').split('?');
  const params = new URLSearchParams(rawQuery);

  if (pathname === '/users/me' && method === 'GET') {
    return {
      data: {
        id: 'dev-mock-admin',
        email: 'minhthong0610.it@gmail.com',
        fullName: 'Meta Gym Admin (Demo)',
        role: 'ADMIN',
        status: 'ACTIVE',
      },
    };
  }

  if (pathname === '/admin/users' && method === 'GET') {
    const role = (params.get('role') || 'MEMBER').toUpperCase();
    if (role !== 'MEMBER') return null;

    const search = (params.get('search') || '').trim().toLowerCase();
    const status = (params.get('status') || '').trim().toUpperCase();
    const hasGym = params.get('hasGym') === '1';
    const hasCoach = params.get('hasCoach') === '1';
    const from = (params.get('from') || '').trim();
    const to = (params.get('to') || '').trim();
    const page = Math.max(1, Number(params.get('page') || 1));
    const pageSize = Math.max(1, Number(params.get('pageSize') || 10));

    const filtered = MOCK_MEMBERS.filter((m) => {
      if (status && status !== 'ALL' && m.status !== status) return false;
      if (hasGym && m.membershipStatus !== 'ACTIVE') return false;
      if (hasCoach && m.coachRelationshipStatus === 'NONE') return false;
      if (from || to) {
        const day = m.createdAt.slice(0, 10);
        if (from && day < from) return false;
        if (to && day > to) return false;
      }
      if (search) {
        const hay = `${m.fullName} ${m.email} ${m.phone}`.toLowerCase();
        if (!hay.includes(search)) return false;
      }
      return true;
    });

    const totalItems = filtered.length;
    const totalPages = Math.max(1, Math.ceil(totalItems / pageSize));
    const safePage = Math.min(page, totalPages);
    const start = (safePage - 1) * pageSize;

    return {
      data: filtered.slice(start, start + pageSize),
      pagination: {
        page: safePage,
        pageSize,
        totalItems,
        totalPages,
      },
      _mock: true,
    };
  }

  const detailMatch = pathname.match(/^\/admin\/users\/(mock-member-\d+)$/);
  if (detailMatch && method === 'GET') {
    const found = MOCK_MEMBERS.find((m) => m.id === detailMatch[1]);
    if (found) return { data: found, _mock: true };
  }

  const previewMatch = pathname.match(/^\/admin\/users\/(mock-member-\d+)\/lock-preview$/);
  if (previewMatch && method === 'GET') {
    const found = MOCK_MEMBERS.find((m) => m.id === previewMatch[1]);
    if (found) {
      return {
        data: {
          coachName: found.coachName,
          hasActiveRelationship: found.coachRelationshipStatus === 'ACTIVE',
          cancelledFutureBookingsCount: found.coachRelationshipStatus === 'ACTIVE' ? 2 : 0,
          cancelledHoldsCount: 0,
        },
        _mock: true,
      };
    }
  }

  const statusMatch = pathname.match(/^\/admin\/users\/(mock-member-\d+)\/status$/);
  if (statusMatch && method === 'PATCH') {
    const found = MOCK_MEMBERS.find((m) => m.id === statusMatch[1]);
    if (found) {
      const nextStatus = body?.status === 'DISABLED' ? 'DISABLED' : 'ACTIVE';
      found.status = nextStatus;
      found.disabledAt = nextStatus === 'DISABLED' ? new Date().toISOString() : null;
      found.disabledReason = nextStatus === 'DISABLED' ? (body?.reason || 'Khóa thử nghiệm trên dữ liệu ảo') : null;
      if (found.coachRelationshipStatus !== 'NONE') {
        found.coachRelationshipStatus = nextStatus === 'DISABLED' ? 'PAUSED' : 'ACTIVE';
        found.coachPauseReason = nextStatus === 'DISABLED' ? 'MEMBER_LOCKED' : null;
      }
      return {
        data: {
          user: found,
          effects: {
            sessionsRevoked: nextStatus === 'DISABLED',
            affectedRelationshipsCount: found.coachRelationshipStatus !== 'NONE' ? 1 : 0,
            relationshipStatus: found.coachRelationshipStatus,
            pauseReason: found.coachPauseReason,
          },
        },
        _mock: true,
      };
    }
  }

  return null;
}
