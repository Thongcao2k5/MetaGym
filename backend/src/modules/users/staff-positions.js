export const STAFF_POSITION_DEFINITIONS = Object.freeze([
  {
    code: 'ADMIN',
    roleCode: 'super_admin',
    userRole: 'ADMIN',
    priority: 1,
    title: 'Quản trị viên (Admin)',
    shortTitle: 'Quản trị viên',
    departmentDefault: 'Ban giám đốc',
    portal: 'Web Admin (Toàn quyền)',
    badgeKind: 'coral',
    maxCount: 1,
    description: 'Chủ sở hữu hệ thống duy nhất, nắm toàn quyền cấu hình lõi, bổ nhiệm Quản lý vận hành và xem toàn bộ nhật ký kiểm toán.',
    permissions: ['*'],
    sidebarHighlights: [
      'Toàn bộ 7 nhóm chức năng trên Web Admin',
      'Bổ nhiệm / khóa Quản lý vận hành & nhân sự',
      'Cấu hình thông tin hệ thống, Image Server & kiểm toán',
    ],
  },
  {
    code: 'MANAGER',
    roleCode: 'manager',
    userRole: 'STAFF',
    priority: 2,
    title: 'Quản lý vận hành / Trưởng ca',
    shortTitle: 'Quản lý vận hành',
    departmentDefault: 'Điều hành phòng tập',
    portal: 'Web Admin (Điều hành)',
    badgeKind: 'warning',
    maxCount: null,
    description: 'Điều phối vận hành hằng ngày: xử lý sự cố Coach, phân xử tranh chấp 72h, hoàn tiền mô phỏng, quản lý lễ tân/kỹ thuật viên và bảng giá.',
    permissions: [
      'dashboard:read', 'incidents:read', 'incidents:manage', 'disputes:read', 'disputes:manage',
      'refunds:read', 'refunds:manage', 'payments:read', 'payments:frontdesk', 'payments:void',
      'gym:read', 'gym:manage', 'members:read', 'members:manage', 'coaches:read', 'coaches:manage',
      'relationships:read', 'relationships:manage', 'transfers:read', 'transfers:manage',
      'plans:read', 'plans:manage', 'coach-packages:read', 'coach-packages:manage',
      'staff:read', 'staff:manage', 'equipment:manage', 'foods:manage',
      'media:read', 'media:manage', 'system:read', 'audit:read',
    ],
    sidebarHighlights: [
      'Ưu tiên xử lý (Sự cố, Tranh chấp 72h, Hoàn tiền)',
      'Quầy lễ tân, Hội viên, Gói dịch vụ & Chuyển Coach',
      'Quản lý nhân sự (Lễ tân, Kỹ thuật, Coach) & Audit',
    ],
  },
  {
    code: 'RECEPTIONIST',
    roleCode: 'receptionist',
    userRole: 'STAFF',
    priority: 3,
    title: 'Lễ tân & Thu ngân',
    shortTitle: 'Lễ tân & Thu ngân',
    departmentDefault: 'Quầy lễ tân',
    portal: 'Web Admin (Quầy)',
    badgeKind: 'info',
    maxCount: null,
    description: 'Trực quầy tiếp đón hội viên, mở mã QR điểm danh, thu tiền gói tập tại quầy, tra cứu quyền sử dụng gói Gym/Coach và lịch trực Coach.',
    permissions: [
      'dashboard:read', 'payments:read', 'payments:frontdesk',
      'gym:read', 'members:read', 'members:manage',
      'coaches:read', 'relationships:read', 'plans:read', 'coach-packages:read',
    ],
    sidebarHighlights: [
      'Giao dịch & Thu tại quầy, Phòng gym & QR điểm danh',
      'Tra cứu & cập nhật Hội viên, Quyền sử dụng gói Gym',
      'Xem danh sách Coach & quan hệ Member–Coach',
    ],
  },
  {
    code: 'COACH',
    roleCode: 'coach',
    userRole: 'COACH',
    priority: 4,
    title: 'Huấn luyện viên (Coach)',
    shortTitle: 'Huấn luyện viên',
    departmentDefault: 'Huấn luyện chuyên môn',
    portal: 'Ứng dụng Coach (Mobile)',
    badgeKind: 'success',
    maxCount: null,
    description: 'Phụ trách tối đa 8 hội viên đồng thời (trần cứng 8 suất), thiết lập lịch làm việc tuần 6 ngày, biên soạn giáo trình, thực đơn và theo dõi tiến độ.',
    permissions: ['mobile:coach'],
    sidebarHighlights: [
      'Làm việc trên ứng dụng MetaGym Coach (không vào Web Admin)',
      'Quản lý trực tiếp trên Web ở mục Nhân sự & Huấn luyện viên',
    ],
  },
  {
    code: 'TECHNICIAN',
    roleCode: 'technician',
    userRole: 'STAFF',
    priority: 5,
    title: 'Kỹ thuật viên & Nội dung',
    shortTitle: 'Kỹ thuật viên',
    departmentDefault: 'Thiết bị & Nội dung số',
    portal: 'Web Admin (Cơ sở & Media)',
    badgeKind: 'neutral',
    maxCount: null,
    description: 'Bảo trì máy tập, cập nhật danh mục thiết bị và hướng dẫn an toàn, quản lý thư viện bài tập, dữ liệu thực phẩm kcal và kho ảnh WebP.',
    permissions: [
      'gym:read', 'equipment:manage', 'foods:manage', 'media:read', 'media:manage', 'system:read',
    ],
    sidebarHighlights: [
      'Thiết bị phòng tập & Hướng dẫn sử dụng thiết bị',
      'Thư viện bài tập, Thực phẩm dinh dưỡng & Kho ảnh',
    ],
  },
]);

const POSITION_BY_CODE = new Map(STAFF_POSITION_DEFINITIONS.map((item) => [item.code, item]));

export const STAFF_ROLE_CODES = Object.freeze(['MANAGER', 'RECEPTIONIST', 'TECHNICIAN']);
export const CREATABLE_STAFF_POSITIONS = Object.freeze(['MANAGER', 'RECEPTIONIST', 'TECHNICIAN', 'COACH']);

export function getPositionDefinition(code) {
  return POSITION_BY_CODE.get(String(code || '').toUpperCase()) ?? null;
}

export function resolveUserStaffPosition(user) {
  if (!user) return null;
  if (user.role === 'ADMIN') return 'ADMIN';
  if (user.role === 'COACH') return 'COACH';
  if (user.role === 'STAFF') return user.position_code || user.staffPosition || 'RECEPTIONIST';
  return null;
}

export function resolveUserPermissions(user) {
  if (!user) return [];
  if (user.role === 'ADMIN') return ['*'];
  if (user.role === 'STAFF') {
    if (Array.isArray(user.role_permissions)) return user.role_permissions;
    const def = getPositionDefinition(resolveUserStaffPosition(user));
    return def ? [...def.permissions] : [];
  }
  if (user.role === 'COACH') return ['mobile:coach'];
  return [];
}

export function hasBackofficePermission(user, permission = null) {
  if (!user) return false;
  if (user.role === 'ADMIN') return true;
  if (user.role !== 'STAFF') return false;
  if (!permission) return true;
  const perms = resolveUserPermissions(user);
  return perms.includes('*') || perms.includes(permission);
}
