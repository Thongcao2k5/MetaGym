import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/admin/data/admin_service.dart';
import 'package:meta_gym_app/features/admin/domain/admin_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:provider/provider.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({this.service, super.key});

  final AdminService? service;

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  AdminService? _service;

  List<AdminUserItem> _users = const [];
  List<AdminPlanItem> _plans = const [];
  bool _loading = true;
  String? _error;

  String _searchQuery = '';
  String? _roleFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? AdminApi(context.read<ApiClient>());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await _service!.getUsers(role: _roleFilter);
      final plans = await _service!.getPlans();
      if (!mounted) return;
      setState(() {
        _users = users;
        _plans = plans;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể tải dữ liệu quản trị.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF162232),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Đăng xuất quản trị',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản Quản trị viên không?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Colors.white60)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF453A),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<SessionController>().signOut();
    }
  }

  Future<void> _showCreateCoachDialog() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final limitCtrl = TextEditingController(text: '15');
    final formKey = GlobalKey<FormState>();
    bool busy = false;
    String? dialogError;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF162232),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(Icons.person_add_alt_1, color: MetaGymTheme.brandOrange),
              SizedBox(width: 10),
              Text(
                'Thêm Huấn luyện viên',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dialogError != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0x33FF453A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        dialogError!,
                        style: const TextStyle(
                          color: Color(0xFFFF857D),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  TextFormField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Họ và tên *',
                      labelStyle: TextStyle(color: Colors.white60),
                    ),
                    validator: (v) => (v == null || v.trim().length < 2)
                        ? 'Nhập họ tên'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: emailCtrl,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email *',
                      labelStyle: TextStyle(color: Colors.white60),
                    ),
                    validator: (v) => (v == null || !v.contains('@'))
                        ? 'Email không hợp lệ'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: passCtrl,
                    style: const TextStyle(color: Colors.white),
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText:
                          'Mật khẩu (ít nhất 8 ký tự: Hoa, thường, số) *',
                      labelStyle: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                    validator: (v) => (v == null || v.length < 8)
                        ? 'Tối thiểu 8 ký tự'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: limitCtrl,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Giới hạn số học viên tối đa',
                      labelStyle: TextStyle(color: Colors.white60),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: const Text('Hủy', style: TextStyle(color: Colors.white60)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: MetaGymTheme.brandOrange,
              ),
              onPressed: busy
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        busy = true;
                        dialogError = null;
                      });
                      try {
                        await _service!.createCoach(
                          email: emailCtrl.text,
                          fullName: nameCtrl.text,
                          password: passCtrl.text,
                          memberLimit: int.tryParse(limitCtrl.text) ?? 15,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _loadAll();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã tạo tài khoản HLV thành công!'),
                              backgroundColor: Color(0xFF34C759),
                            ),
                          );
                        }
                      } on ApiException catch (e) {
                        setDialogState(() {
                          busy = false;
                          dialogError = e.message;
                        });
                      } catch (_) {
                        setDialogState(() {
                          busy = false;
                          dialogError = 'Tạo tài khoản thất bại. Kiểm tra định dạng mật khẩu.';
                        });
                      }
                    },
              child: Text(busy ? 'Đang tạo…' : 'Tạo tài khoản'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPlanDialog([AdminPlanItem? plan]) async {
    final nameCtrl = TextEditingController(text: plan?.name);
    final priceCtrl = TextEditingController(
      text: plan?.price.toInt().toString(),
    );
    final daysCtrl = TextEditingController(
      text: (plan?.durationDays ?? 30).toString(),
    );
    final descCtrl = TextEditingController(text: plan?.description);
    final formKey = GlobalKey<FormState>();
    bool busy = false;
    String? dialogError;

    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF162232),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.card_membership,
                color: MetaGymTheme.brandOrange,
              ),
              const SizedBox(width: 10),
              Text(
                plan == null ? 'Thêm gói tập mới' : 'Sửa gói tập',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dialogError != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0x33FF453A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        dialogError!,
                        style: const TextStyle(
                          color: Color(0xFFFF857D),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  TextFormField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Tên gói tập *',
                      labelStyle: TextStyle(color: Colors.white60),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Nhập tên gói' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: priceCtrl,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Giá tiền (VNĐ) *',
                      labelStyle: TextStyle(color: Colors.white60),
                    ),
                    validator: (v) => (v == null || int.tryParse(v) == null)
                        ? 'Nhập giá hợp lệ'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: daysCtrl,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Thời hạn (Số ngày) *',
                      labelStyle: TextStyle(color: Colors.white60),
                    ),
                    validator: (v) => (v == null || int.tryParse(v) == null)
                        ? 'Nhập số ngày'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: descCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Mô tả quyền lợi',
                      labelStyle: TextStyle(color: Colors.white60),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: const Text('Hủy', style: TextStyle(color: Colors.white60)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: MetaGymTheme.brandOrange,
              ),
              onPressed: busy
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        busy = true;
                        dialogError = null;
                      });
                      try {
                        final price = int.parse(priceCtrl.text);
                        final durationDays = int.parse(daysCtrl.text);
                        if (plan == null) {
                          await _service!.createPlan(
                            name: nameCtrl.text,
                            price: price,
                            durationDays: durationDays,
                            description: descCtrl.text,
                          );
                        } else {
                          await _service!.updatePlan(
                            planId: plan.id,
                            name: nameCtrl.text,
                            price: price,
                            durationDays: durationDays,
                            description: descCtrl.text,
                          );
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _loadAll();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã lưu gói tập.'),
                              backgroundColor: Color(0xFF34C759),
                            ),
                          );
                        }
                      } on ApiException catch (e) {
                        if (!ctx.mounted) return;
                        setDialogState(() {
                          busy = false;
                          dialogError = e.message;
                        });
                      } catch (_) {
                        if (!ctx.mounted) return;
                        setDialogState(() {
                          busy = false;
                          dialogError = 'Không lưu được gói tập.';
                        });
                      }
                    },
              child: Text(busy ? 'Đang lưu…' : 'Lưu gói tập'),
            ),
          ],
        ),
      ),
    );
    await Navigator.of(context, rootNavigator: true).push(route);
    await route.completed;
    nameCtrl.dispose();
    priceCtrl.dispose();
    daysCtrl.dispose();
    descCtrl.dispose();
  }

  Future<void> _toggleUserStatus(AdminUserItem user) async {
    final targetStatus = user.isActive ? 'DISABLED' : 'ACTIVE';
    final actionName = user.isActive ? 'Khóa tài khoản' : 'Mở khóa tài khoản';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF162232),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '$actionName?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Bạn có chắc chắn muốn $actionName của ${user.fullName} (${user.email})?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Colors.white60)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: user.isActive
                  ? const Color(0xFFFF453A)
                  : const Color(0xFF34C759),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(actionName),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _service!.updateUserStatus(userId: user.id, status: targetStatus);
        await _loadAll();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không cập nhật được trạng thái người dùng.'),
              backgroundColor: Color(0xFFFF453A),
            ),
          );
        }
      }
    }
  }

  Future<void> _togglePlanStatus(AdminPlanItem plan) async {
    final targetStatus = plan.isActive ? 'INACTIVE' : 'ACTIVE';
    try {
      await _service!.updatePlanStatus(planId: plan.id, status: targetStatus);
      await _loadAll();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không cập nhật được trạng thái gói tập.'),
            backgroundColor: Color(0xFFFF453A),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user;
    final money = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    final filteredUsers = _users.where((u) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final match =
            u.fullName.toLowerCase().contains(query) ||
            u.email.toLowerCase().contains(query);
        if (!match) return false;
      }
      return true;
    }).toList();

    final coachCount = _users.where((u) => u.isCoach).length;
    final memberCount = _users.where((u) => u.isMember).length;

    return Scaffold(
      backgroundColor: MetaGymTheme.darkCanvas,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Không gian quản trị viên',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Làm mới',
            onPressed: _loadAll,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFFF6961)),
            tooltip: 'Đăng xuất',
            onPressed: () => _confirmSignOut(context),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: MetaGymTheme.brandOrange,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          tabs: const [
            Tab(icon: Icon(Icons.people_alt, size: 20), text: 'Người dùng'),
            Tab(icon: Icon(Icons.card_membership, size: 20), text: 'Gói tập'),
            Tab(
              icon: Icon(Icons.dashboard_customize, size: 20),
              text: 'Hệ thống',
            ),
          ],
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: MetaGymTheme.brandOrange,
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: NGƯỜI DÙNG & HLV
                      RefreshIndicator(
                        color: MetaGymTheme.brandOrange,
                        onRefresh: _loadAll,
                        child: ListView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          children: [
                            if (_error != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0x33FF453A),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Color(0xFFFF857D),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            // Header stats
                            MetaGymGlassCard(
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Text(
                                          '${_users.length}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 22,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Tổng tài khoản',
                                          style: TextStyle(
                                            color: Colors.white60,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 36,
                                    color: const Color(0x38D4E4FF),
                                  ),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Text(
                                          '$coachCount',
                                          style: const TextStyle(
                                            color: MetaGymTheme.brandOrange,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 22,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Huấn luyện viên',
                                          style: TextStyle(
                                            color: Colors.white60,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 36,
                                    color: const Color(0x38D4E4FF),
                                  ),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Text(
                                          '$memberCount',
                                          style: const TextStyle(
                                            color: Color(0xFF34C759),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 22,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Hội viên',
                                          style: TextStyle(
                                            color: Colors.white60,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Nút tạo Coach
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: MetaGymTheme.brandOrange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _showCreateCoachDialog,
                              icon: const Icon(Icons.person_add_rounded),
                              label: const Text(
                                'Thêm Huấn luyện viên mới',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Bộ lọc & Search
                            MetaGymGlassCard(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 14),
                              child: Column(
                                children: [
                                  TextField(
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      hintText: 'Tìm theo tên hoặc email…',
                                      hintStyle: const TextStyle(
                                        color: Colors.white38,
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.search,
                                        color: MetaGymTheme.brandOrange,
                                      ),
                                      filled: true,
                                      fillColor: const Color(0x26000000),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onChanged: (v) =>
                                        setState(() => _searchQuery = v),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      ChoiceChip(
                                        label: const Text('Tất cả'),
                                        selected: _roleFilter == null,
                                        selectedColor: MetaGymTheme.brandOrange,
                                        backgroundColor: const Color(
                                          0x33162232,
                                        ),
                                        labelStyle: TextStyle(
                                          color: _roleFilter == null
                                              ? Colors.white
                                              : Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        onSelected: (_) {
                                          setState(() => _roleFilter = null);
                                          _loadAll();
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      ChoiceChip(
                                        label: const Text('HLV'),
                                        selected: _roleFilter == 'COACH',
                                        selectedColor: MetaGymTheme.brandOrange,
                                        backgroundColor: const Color(
                                          0x33162232,
                                        ),
                                        labelStyle: TextStyle(
                                          color: _roleFilter == 'COACH'
                                              ? Colors.white
                                              : Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        onSelected: (_) {
                                          setState(() => _roleFilter = 'COACH');
                                          _loadAll();
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      ChoiceChip(
                                        label: const Text('Hội viên'),
                                        selected: _roleFilter == 'MEMBER',
                                        selectedColor: MetaGymTheme.brandOrange,
                                        backgroundColor: const Color(
                                          0x33162232,
                                        ),
                                        labelStyle: TextStyle(
                                          color: _roleFilter == 'MEMBER'
                                              ? Colors.white
                                              : Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        onSelected: (_) {
                                          setState(
                                            () => _roleFilter = 'MEMBER',
                                          );
                                          _loadAll();
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Danh sách User
                            if (filteredUsers.isEmpty)
                              const MetaGymGlassCard(
                                padding: EdgeInsets.all(20),
                                child: Center(
                                  child: Text(
                                    'Không tìm thấy người dùng phù hợp.',
                                    style: TextStyle(color: Colors.white60),
                                  ),
                                ),
                              )
                            else
                              for (final u in filteredUsers)
                                MetaGymGlassCard(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: u.isCoach
                                            ? MetaGymTheme.brandOrange
                                                  .withValues(alpha: 0.2)
                                            : const Color(0x3334C759),
                                        child: Text(
                                          u.fullName.isNotEmpty
                                              ? u.fullName[0].toUpperCase()
                                              : 'U',
                                          style: TextStyle(
                                            color: u.isCoach
                                                ? MetaGymTheme.brandOrange
                                                : const Color(0xFF34C759),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    u.fullName,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 15,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: u.isCoach
                                                        ? const Color(
                                                            0x33FF5A36,
                                                          )
                                                        : const Color(
                                                            0x3334C759,
                                                          ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    u.roleLabel,
                                                    style: TextStyle(
                                                      color: u.isCoach
                                                          ? MetaGymTheme
                                                                .brandOrange
                                                          : const Color(
                                                              0xFF34C759,
                                                            ),
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              u.email,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 13,
                                              ),
                                            ),
                                            if (u.phone != null &&
                                                u.phone!.isNotEmpty)
                                              Text(
                                                'SĐT: ${u.phone}',
                                                style: const TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 12,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          u.isActive
                                              ? Icons.lock_open_rounded
                                              : Icons.lock_outline_rounded,
                                          color: u.isActive
                                              ? const Color(0xFF34C759)
                                              : const Color(0xFFFF453A),
                                          size: 22,
                                        ),
                                        tooltip: u.isActive
                                            ? 'Khóa tài khoản'
                                            : 'Mở khóa tài khoản',
                                        onPressed: () => _toggleUserStatus(u),
                                      ),
                                    ],
                                  ),
                                ),
                          ],
                        ),
                      ),

                      // TAB 2: QUẢN LÝ GÓI TẬP
                      RefreshIndicator(
                        color: MetaGymTheme.brandOrange,
                        onRefresh: _loadAll,
                        child: ListView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          children: [
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: MetaGymTheme.brandOrange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => _showPlanDialog(),
                              icon: const Icon(Icons.add_card_rounded),
                              label: const Text(
                                'Thêm Gói tập mới',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_plans.isEmpty)
                              const MetaGymGlassCard(
                                padding: EdgeInsets.all(20),
                                child: Center(
                                  child: Text(
                                    'Chưa có gói tập nào.',
                                    style: TextStyle(color: Colors.white60),
                                  ),
                                ),
                              )
                            else
                              for (final plan in _plans)
                                MetaGymGlassCard(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: plan.isActive
                                              ? const Color(0x26FF5A36)
                                              : const Color(0x26FFFFFF),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.fitness_center,
                                          color: plan.isActive
                                              ? MetaGymTheme.brandOrange
                                              : Colors.white38,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              plan.name,
                                              style: TextStyle(
                                                color: plan.isActive
                                                    ? Colors.white
                                                    : Colors.white60,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${money.format(plan.price)} • ${plan.durationDays} ngày',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 13,
                                              ),
                                            ),
                                            if (plan.description != null &&
                                                plan.description!.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 2,
                                                ),
                                                child: Text(
                                                  plan.description!,
                                                  style: const TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: 12,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Sửa gói tập',
                                        onPressed: () => _showPlanDialog(plan),
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                      Switch(
                                        value: plan.isActive,
                                        activeThumbColor:
                                            MetaGymTheme.brandOrange,
                                        onChanged: (_) =>
                                            _togglePlanStatus(plan),
                                      ),
                                    ],
                                  ),
                                ),
                          ],
                        ),
                      ),

                      // TAB 3: HỆ THỐNG & ĐĂNG XUẤT
                      ListView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        children: [
                          MetaGymGlassCard(
                            padding: const EdgeInsets.all(20),
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: MetaGymTheme.brandOrange
                                      .withValues(alpha: 0.2),
                                  child: const Icon(
                                    Icons.admin_panel_settings_rounded,
                                    color: MetaGymTheme.brandOrange,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user?.fullName ?? 'Quản trị viên',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 17,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        user?.email ?? 'a@a.com',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: MetaGymTheme.brandOrange
                                              .withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: const Text(
                                          'HỆ THỐNG QUẢN TRỊ VIÊN',
                                          style: TextStyle(
                                            color: MetaGymTheme.brandOrange,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          MetaGymGlassCard(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: const Icon(
                                Icons.fitness_center_rounded,
                                color: MetaGymTheme.brandOrange,
                              ),
                              title: const Text(
                                'Quản lý thiết bị phòng tập',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: const Text(
                                'Xem danh mục trang thiết bị, tình trạng bảo trì',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: Colors.white54,
                              ),
                              onTap: () => context.push('/member/features/gym'),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Nút Đăng xuất nổi bật
                          MetaGymGlassCard(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0x33FF453A),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.logout_rounded,
                                  color: Color(0xFFFF6961),
                                  size: 22,
                                ),
                              ),
                              title: const Text(
                                'Đăng xuất khỏi hệ thống',
                                style: TextStyle(
                                  color: Color(0xFFFF6961),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: const Text(
                                'Thoát phiên đăng nhập của Quản trị viên',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                              onTap: () => _confirmSignOut(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
