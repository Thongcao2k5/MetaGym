import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/metagym_realtime.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/calls/data/calls_service.dart';
import 'package:meta_gym_app/features/calls/presentation/live_call_page.dart';

class IncomingCallListener extends StatefulWidget {
  const IncomingCallListener({
    required this.navigatorKey,
    required this.session,
    required this.api,
    this.realtime,
    required this.child,
    super.key,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final SessionController session;
  final CallsApi api;
  final MetaGymRealtime? realtime;
  final Widget child;

  @override
  State<IncomingCallListener> createState() => _IncomingCallListenerState();
}

class _IncomingCallListenerState extends State<IncomingCallListener> {
  late final AppLifecycleListener _lifecycle;
  Timer? _timer;
  StreamSubscription<void>? _realtimeSubscription;
  StreamSubscription<String>? _messageSubscription;
  bool _checking = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        _foreground = state == AppLifecycleState.resumed;
        _syncTimer();
      },
    );
    widget.session.addListener(_syncTimer);
    _realtimeSubscription = widget.realtime?.calls.listen((_) => _check());
    _messageSubscription = widget.realtime?.messages.listen((_) {
      final navigator = widget.navigatorKey.currentState;
      if (!mounted ||
          !_canListen ||
          navigator == null ||
          LiveCallPage.isOpen(navigator)) {
        return;
      }
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(const SnackBar(content: Text('Bạn có tin nhắn mới.')));
    });
    _syncTimer();
  }

  bool get _canListen {
    final role = widget.session.user?.role;
    return _foreground &&
        widget.session.status == SessionStatus.authenticated &&
        (role == UserRole.member || role == UserRole.coach);
  }

  void _syncTimer() {
    if (_canListen) {
      _timer ??= Timer.periodic(const Duration(seconds: 3), (_) => _check());
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> _check() async {
    final navigator = widget.navigatorKey.currentState;
    final userId = widget.session.user?.id;
    if (!_canListen ||
        _checking ||
        userId == null ||
        navigator == null ||
        LiveCallPage.isOpen(navigator)) {
      return;
    }
    _checking = true;
    try {
      final call = await widget.api.getIncoming();
      if (!mounted ||
          !_canListen ||
          !navigator.mounted ||
          widget.session.user?.id != userId ||
          call == null) {
        return;
      }
      await LiveCallPage.show(
        navigator,
        api: widget.api,
        call: call,
        currentUserId: userId,
        peerName: call.peerNameFor(userId),
      );
    } catch (_) {
      // Retry when the next foreground poll runs.
    } finally {
      _checking = false;
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_syncTimer);
    _timer?.cancel();
    unawaited(_realtimeSubscription?.cancel());
    unawaited(_messageSubscription?.cancel());
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
