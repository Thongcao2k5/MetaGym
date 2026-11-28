import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:meta_gym_app/core/network/api_cache_interceptor.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/storage/offline_mutation_queue.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:provider/provider.dart';

/// Gắn callback tự động tải lại dữ liệu màn hình mỗi khi đồng bộ nền hoàn tất.
SyncRevisionBinding bindApiCacheSync(BuildContext context, VoidCallback onSync) {
  ApiCacheStatusController? controller;
  try {
    controller = context.read<ApiCacheStatusController?>();
  } catch (_) {
    controller = null;
  }
  return SyncRevisionBinding(controller: controller, onSync: onSync);
}

class SyncRevisionBinding {
  SyncRevisionBinding({required this.controller, required this.onSync})
    : _lastRevision = controller?.syncRevision ?? 0 {
    controller?.addListener(_handleChange);
  }

  final ApiCacheStatusController? controller;
  final VoidCallback onSync;
  int _lastRevision;

  void _handleChange() {
    final current = controller;
    if (current == null || current.syncRevision == _lastRevision) return;
    _lastRevision = current.syncRevision;
    onSync();
  }

  void dispose() {
    controller?.removeListener(_handleChange);
  }
}

/// Báo cáo kết quả một lượt đồng bộ dữ liệu ngoại tuyến.
class OfflineSyncReport {
  const OfflineSyncReport({
    required this.syncedCount,
    required this.droppedCount,
    required this.remainingCount,
  });

  final int syncedCount;
  final int droppedCount;
  final int remainingCount;
}

/// Quản lý phát hiện mạng tức thời và tự động đồng bộ hàng đợi khi có kết nối trở lại.
class OfflineSyncManager with WidgetsBindingObserver {
  OfflineSyncManager({
    required this.apiClient,
    required this.mutationQueue,
    required this.statusController,
    required this.sessionController,
    this.onRefreshControllers,
    this.connectivityStream,
    this.checkConnectivity,
    this.periodicInterval = const Duration(seconds: 30),
    bool? enableAutoSync,
    DateTime Function()? now,
  }) : _enableAutoSync = enableAutoSync ?? !MetaGymTheme.isFlutterTestEnvironment,
       _now = now ?? (() => DateTime.now().toUtc());

  final ApiClient apiClient;
  final OfflineMutationQueue mutationQueue;
  final ApiCacheStatusController statusController;
  final SessionController sessionController;
  final Future<void> Function()? onRefreshControllers;
  final Stream<List<ConnectivityResult>>? connectivityStream;
  final Future<List<ConnectivityResult>> Function()? checkConnectivity;
  final Duration periodicInterval;
  final bool _enableAutoSync;
  final DateTime Function() _now;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _periodicTimer;
  Future<OfflineSyncReport>? _syncInFlight;
  bool _started = false;
  bool _disposed = false;
  bool _inForeground = true;

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;

    final pending = await mutationQueue.listAll();
    if (_disposed) return;
    statusController.setPendingMutationCount(pending.length);

    if (_enableAutoSync) {
      WidgetsBinding.instance.addObserver(this);
      final stream =
          connectivityStream ?? Connectivity().onConnectivityChanged;
      _connectivitySub = stream.listen(_handleConnectivityChanged);
      _periodicTimer = Timer.periodic(periodicInterval, (_) {
        if (_inForeground &&
            !statusController.isDeviceOffline &&
            sessionController.status == SessionStatus.authenticated) {
          unawaited(syncNow());
        }
      });
    } else if (connectivityStream != null) {
      _connectivitySub = connectivityStream!.listen(_handleConnectivityChanged);
    }

    if (_enableAutoSync || checkConnectivity != null) {
      try {
        final results = await (checkConnectivity?.call() ??
            Connectivity().checkConnectivity());
        if (!_disposed) {
          await _handleConnectivityChanged(results, initialCheck: true);
        }
      } catch (_) {
        // Non-fatal: giữ nguyên trạng thái mặc định nếu plugin không phản hồi.
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _inForeground = state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    if (state == AppLifecycleState.resumed && !statusController.isDeviceOffline) {
      unawaited(syncNow(forceRefresh: true));
    }
  }

  Future<void> _handleConnectivityChanged(
    List<ConnectivityResult> results, {
    bool initialCheck = false,
  }) async {
    if (_disposed) return;
    final hasNetwork = results.any((item) => item != ConnectivityResult.none);
    final wasOffline = statusController.isDeviceOffline;
    statusController.setDeviceOffline(!hasNetwork);

    if (hasNetwork && (wasOffline || (!initialCheck && statusController.pendingMutationCount > 0))) {
      await syncNow(forceRefresh: true);
    }
  }

  /// Thực thi đồng bộ hàng đợi FIFO và tự động làm mới dữ liệu đang hiển thị.
  Future<OfflineSyncReport> syncNow({bool forceRefresh = false}) {
    final existing = _syncInFlight;
    if (existing != null) return existing;

    final future = _performSync(forceRefresh: forceRefresh);
    _syncInFlight = future;
    return future.whenComplete(() {
      if (identical(_syncInFlight, future)) {
        _syncInFlight = null;
      }
    });
  }

  Future<OfflineSyncReport> _performSync({required bool forceRefresh}) async {
    if (_disposed || statusController.isDeviceOffline) {
      final remaining = (await mutationQueue.listAll()).length;
      statusController.setPendingMutationCount(remaining);
      return OfflineSyncReport(
        syncedCount: 0,
        droppedCount: 0,
        remainingCount: remaining,
      );
    }

    var syncedCount = 0;
    var droppedCount = 0;
    final queued = await mutationQueue.listAll();
    if (queued.isNotEmpty) {
      statusController.setSyncing(true);
    }

    try {
      for (final mutation in queued) {
        if (_disposed || statusController.isDeviceOffline) break;
        if (sessionController.status != SessionStatus.authenticated) break;

        try {
          await apiClient.replayQueuedMutation(mutation);
          await mutationQueue.remove(mutation.id);
          syncedCount += 1;
        } on ApiException catch (error) {
          if (error.kind == ApiExceptionKind.sessionExpired ||
              error.kind == ApiExceptionKind.forbidden) {
            break;
          }
          if (error.kind == ApiExceptionKind.validation ||
              error.kind == ApiExceptionKind.request) {
            await mutationQueue.remove(mutation.id);
            droppedCount += 1;
          } else {
            await mutationQueue.incrementRetry(mutation.id);
            break;
          }
        } catch (_) {
          await mutationQueue.incrementRetry(mutation.id);
          break;
        }
      }

      final remainingList = await mutationQueue.listAll();
      final remaining = remainingList.length;
      statusController.setPendingMutationCount(remaining);

      if (!_disposed &&
          sessionController.status == SessionStatus.authenticated &&
          (syncedCount > 0 || forceRefresh)) {
        try {
          await onRefreshControllers?.call();
        } catch (_) {}
        if (remaining == 0 && !statusController.isDeviceOffline) {
          statusController.recordLiveSuccess(_now().toUtc());
        }
        statusController.notifyDataSynced();
      }

      return OfflineSyncReport(
        syncedCount: syncedCount,
        droppedCount: droppedCount,
        remainingCount: remaining,
      );
    } finally {
      if (!_disposed) {
        statusController.setSyncing(false);
      }
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _periodicTimer?.cancel();
    _periodicTimer = null;
    unawaited(_connectivitySub?.cancel());
    _connectivitySub = null;
    if (_started && _enableAutoSync) {
      WidgetsBinding.instance.removeObserver(this);
    }
  }
}
