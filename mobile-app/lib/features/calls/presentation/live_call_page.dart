import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as rtc;
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/calls/data/calls_service.dart';
import 'package:meta_gym_app/features/calls/domain/call_log.dart';

class LiveCallPage extends StatefulWidget {
  const LiveCallPage({
    required this.api,
    required this.call,
    required this.currentUserId,
    this.peerName,
    this.room,
    super.key,
  });

  final CallsApi api;
  final CallLog call;
  final String currentUserId;
  final String? peerName;
  final rtc.Room? room;

  static final _open = <NavigatorState>{};

  static bool isOpen(NavigatorState navigator) => _open.contains(navigator);

  static Future<void> show(
    NavigatorState navigator, {
    required CallsApi api,
    required CallLog call,
    required String currentUserId,
    String? peerName,
  }) async {
    if (!_open.add(navigator)) return;
    try {
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => LiveCallPage(
            api: api,
            call: call,
            currentUserId: currentUserId,
            peerName: peerName,
          ),
        ),
      );
    } finally {
      _open.remove(navigator);
    }
  }

  @override
  State<LiveCallPage> createState() => _LiveCallPageState();
}

class _LiveCallPageState extends State<LiveCallPage> {
  late final rtc.Room _room = widget.room ?? rtc.Room();
  late final bool _ownsRoom = widget.room == null;
  late final _events = _room.createListener();
  late CallLog _call = widget.call;
  late final Timer _poll;
  Timer? _elapsedTimer;
  DateTime? _connectedAt;
  int _elapsedSeconds = 0;

  bool _requestInFlight = false;
  bool _updating = false;
  bool _joining = false;
  bool _updatingMedia = false;
  bool _microphone = false;
  bool _camera = false;
  late bool _speakerOn = widget.call.callType == 'VIDEO';
  rtc.CameraPosition _cameraPosition = rtc.CameraPosition.front;

  String? _error;
  String? _statusError;
  String? _microphoneError;
  String? _cameraError;

  bool get _video => _call.callType == 'VIDEO';
  bool get _incoming => _call.receiverId == widget.currentUserId;
  bool get _connected => _room.connectionState == rtc.ConnectionState.connected;
  bool get _reconnecting =>
      _room.connectionState == rtc.ConnectionState.reconnecting;

  String get _displayPeerName {
    final fromCall = _call.peerNameFor(widget.currentUserId);
    if (fromCall != null) return fromCall;
    final fromInitialCall = widget.call.peerNameFor(widget.currentUserId);
    if (fromInitialCall != null) return fromInitialCall;
    final provided = widget.peerName?.trim();
    if (provided != null && provided.isNotEmpty) return provided;
    return _video ? 'Cuộc gọi video' : 'Cuộc gọi thoại';
  }

  String get _peerInitial {
    final name = _displayPeerName;
    if (name.isEmpty) return 'MG';
    final parts = name
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _room.addListener(_roomChanged);
    _events.on<rtc.RoomDisconnectedEvent>((_) {
      if (mounted && !_call.isFinished && !_joining) {
        _stopDurationTimer();
        setState(() => _error = 'Đã mất kết nối. Bạn có thể kết nối lại.');
      }
    });
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
    _refresh();
  }

  void _roomChanged() {
    if (!mounted) return;
    if (_connected && !_call.isFinished) {
      _startDurationTimerIfNeeded();
    } else if (!_reconnecting) {
      _stopDurationTimer();
    }
    setState(() {});
  }

  void _startDurationTimerIfNeeded() {
    if (_elapsedTimer != null) return;
    final parsedAnsweredAt = _call.answeredAt != null
        ? DateTime.tryParse(_call.answeredAt!)
        : null;
    _connectedAt ??= parsedAnsweredAt ?? DateTime.now();
    _syncElapsedSeconds();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(_syncElapsedSeconds);
    });
  }

  void _syncElapsedSeconds() {
    final started = _connectedAt;
    if (started == null) return;
    final diff = DateTime.now().difference(started).inSeconds;
    _elapsedSeconds = diff < 0 ? 0 : diff;
  }

  void _stopDurationTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
  }

  @override
  void dispose() {
    _poll.cancel();
    _stopDurationTimer();
    _room.removeListener(_roomChanged);
    unawaited(_events.dispose());
    if (_ownsRoom) {
      unawaited(_room.dispose());
    }
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_requestInFlight || _updating || _call.isFinished) return;
    _requestInFlight = true;
    final previousStatus = _call.status;
    try {
      final call = await widget.api.getCall(_call.id);
      if (!mounted || _updating || _call.status != previousStatus) return;
      await _applyCall(call);
    } catch (_) {
      if (mounted && !_call.isFinished && _statusError == null) {
        setState(
          () => _statusError = 'Chưa cập nhật được trạng thái cuộc gọi.',
        );
      }
    } finally {
      _requestInFlight = false;
    }
  }

  Future<void> _applyCall(CallLog call) async {
    final previous = _call.status;
    setState(() {
      _call = call;
      _statusError = null;
    });
    if (call.isFinished) {
      _poll.cancel();
      _stopDurationTimer();
      await _room.disconnect();
    } else if (call.status == 'ANSWERED' && previous != 'ANSWERED') {
      unawaited(_join());
    }
  }

  Future<void> _join() async {
    if (_joining || _connected || _reconnecting || _call.status != 'ANSWERED') {
      return;
    }
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      final networks = await Connectivity().checkConnectivity();
      if (!mounted || _call.isFinished) return;
      if (networks.every((network) => network == ConnectivityResult.none)) {
        setState(
          () => _error = 'Thiết bị chưa có Internet. Bật Wi-Fi hoặc dữ liệu di động, rồi bấm Kết nối lại.',
        );
        return;
      }
      final access = await widget.api.getRoomAccess(_call.id);
      if (!mounted || _call.isFinished) return;
      await _room.connect(access.url, access.token);
      if (!mounted) return;
      if (_call.isFinished) {
        await _room.disconnect();
        return;
      }
      await _applySpeakerPreference(_speakerOn);
      await _setMedia(microphone: true);
      if (mounted && !_call.isFinished && _video) {
        await _setMedia(camera: true);
      }
      if (mounted && _connected && !_call.isFinished) {
        _startDurationTimerIfNeeded();
      }
    } on ApiException catch (error) {
      if (mounted && !_call.isFinished) setState(() => _error = error.message);
    } on rtc.ConnectException catch (error) {
      if (mounted && !_call.isFinished) {
        setState(
          () => _error = error.reason == rtc.ConnectionErrorReason.NotAllowed
              ? 'LiveKit từ chối quyền vào phòng. Hãy kết thúc và gọi lại.'
              : 'Không kết nối được với LiveKit. Hãy kiểm tra Internet rồi thử lại.',
        );
      }
    } catch (_) {
      if (mounted && !_call.isFinished) {
        setState(
          () => _error = 'Không thiết lập được đường truyền âm thanh hoặc video. Hãy kiểm tra Internet rồi thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _applySpeakerPreference(bool preferred) async {
    try {
      await rtc.AudioManager.instance.setSpeakerOutputPreferred(preferred);
    } catch (_) {
      // Bỏ qua trên nền tảng không hỗ trợ chuyển loa ngoài (web/test).
    }
  }

  Future<void> _toggleSpeaker() async {
    final next = !_speakerOn;
    setState(() => _speakerOn = next);
    await _applySpeakerPreference(next);
  }

  Future<void> _switchCamera() async {
    final track = _cameraTrack(_room.localParticipant);
    if (track is! rtc.LocalVideoTrack || _updatingMedia) return;
    final next = _cameraPosition == rtc.CameraPosition.front
        ? rtc.CameraPosition.back
        : rtc.CameraPosition.front;
    setState(() => _updatingMedia = true);
    try {
      await track.setCameraPosition(next);
      if (mounted) {
        setState(() {
          _cameraPosition = next;
          _cameraError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _cameraError = 'Không đổi được camera trước/sau.');
      }
    } finally {
      if (mounted) setState(() => _updatingMedia = false);
    }
  }

  Future<void> _setMedia({bool? microphone, bool? camera}) async {
    final participant = _room.localParticipant;
    if (participant == null || _call.isFinished || _updatingMedia) return;
    setState(() => _updatingMedia = true);
    try {
      if (microphone != null) {
        await participant.setMicrophoneEnabled(microphone);
        if (mounted && !_call.isFinished) {
          setState(() {
            _microphone = microphone;
            _microphoneError = null;
          });
        }
      }
      if (camera != null) {
        await participant.setCameraEnabled(camera);
        if (mounted && !_call.isFinished) {
          setState(() {
            _camera = camera;
            _cameraError = null;
          });
        }
      }
    } catch (_) {
      if (mounted && !_call.isFinished) {
        setState(() {
          if (microphone != null) {
            _microphoneError =
                'Không đổi được trạng thái mic. Hãy kiểm tra quyền micro.';
          } else {
            _cameraError =
                'Không đổi được trạng thái camera. Hãy kiểm tra quyền camera.';
          }
        });
      }
    } finally {
      if (mounted) setState(() => _updatingMedia = false);
    }
  }

  Future<void> _update(String status) async {
    if (_updating || _call.isFinished) return;
    setState(() {
      _updating = true;
      _error = null;
    });
    try {
      final call = await widget.api.updateStatus(_call.id, status);
      if (mounted) await _applyCall(call);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không cập nhật được cuộc gọi.');
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  rtc.VideoTrack? _cameraTrack(rtc.Participant? participant) {
    final track = participant?.getTrackPublicationBySource(
      rtc.TrackSource.camera,
    );
    final video = track?.track;
    return track?.muted == false && video is rtc.VideoTrack ? video : null;
  }

  String _formatDuration(int totalSeconds) {
    final safe = totalSeconds < 0 ? 0 : totalSeconds;
    final hours = safe ~/ 3600;
    final minutes = (safe % 3600) ~/ 60;
    final seconds = safe % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$mm:$ss';
    }
    return '$mm:$ss';
  }

  String get _statusLine {
    if (_call.isFinished) {
      final secs = _call.durationSeconds > 0
          ? _call.durationSeconds
          : _elapsedSeconds;
      return secs > 0
          ? '${_call.statusLabel} • ${_formatDuration(secs)}'
          : _call.statusLabel;
    }
    if (_reconnecting) return 'Đang khôi phục kết nối…';
    if (_joining) return 'Đang kết nối…';
    if (_call.status == 'RINGING') {
      return _incoming
          ? (_video ? 'Cuộc gọi video đến…' : 'Cuộc gọi thoại đến…')
          : 'Đang đổ chuông…';
    }
    if (_connected) {
      if (_room.remoteParticipants.isEmpty) {
        return 'Đang chờ người bên kia…';
      }
      return _formatDuration(_elapsedSeconds);
    }
    return _call.statusLabel;
  }

  List<String> get _activeErrors => [
    ?_error,
    if (_statusError != null)
      if (_connected)
        'LiveKit vẫn kết nối. MetaGym đang thử đồng bộ lại trạng thái cuộc gọi.'
      else
        'Chưa cập nhật được trạng thái cuộc gọi từ máy chủ MetaGym.',
    if (_connected) ...[?_microphoneError, ?_cameraError],
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _call.isFinished,
      child: Scaffold(
        backgroundColor: MetaGymTheme.darkCanvas,
        body: _video ? _buildVideoLayout(context) : _buildAudioLayout(context),
      ),
    );
  }

  Widget _buildAudioLayout(BuildContext context) {
    final waiting = _call.status == 'RINGING';
    final errors = _activeErrors;

    return Stack(
      fit: StackFit.expand,
      children: [
        const _CallBackdrop(),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 600;
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: compact ? 12 : 20,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              if (_call.isFinished)
                                IconButton(
                                  tooltip: 'Đóng',
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(
                                    Icons.arrow_back_rounded,
                                    color: MetaGymTheme.textPrimary,
                                  ),
                                )
                              else
                                const SizedBox(width: 48, height: 48),
                              const Spacer(),
                              const _CallModeChip(
                                icon: Icons.call_rounded,
                                label: 'Cuộc gọi thoại',
                              ),
                              const Spacer(),
                              const SizedBox(width: 48, height: 48),
                            ],
                          ),
                          SizedBox(height: compact ? 16 : 36),
                          _PeerAvatarRing(
                            initials: _peerInitial,
                            size: compact ? 72 : 88,
                            pulseActive: waiting || _connected,
                          ),
                          SizedBox(height: compact ? 12 : 18),
                          Text(
                            _displayPeerName,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: MetaGymTheme.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _statusLine,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: MetaGymTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                  fontFeatures: MetaGymTheme.tabularFigures,
                                ),
                          ),
                          if (errors.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _CallErrorPill(message: errors.first),
                          ],
                          const Spacer(),
                          if (waiting && _incoming)
                            _buildIncomingActions(isVideo: false)
                          else if (waiting)
                            _buildOutgoingRingingAudioActions(compact: compact)
                          else if (_call.status == 'ANSWERED')
                            _buildConnectedAudioActions(compact: compact)
                          else
                            _buildFinishedActions(),
                          SizedBox(height: compact ? 12 : 28),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOutgoingRingingAudioActions({required bool compact}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 32,
          runSpacing: 20,
          children: [
            _AudioGridButton(
              icon: _microphone ? Icons.mic_rounded : Icons.mic_off_rounded,
              label: 'Tắt tiếng',
              active: false,
              enabled: false,
              onTap: null,
            ),
            _AudioGridButton(
              icon: _speakerOn
                  ? Icons.volume_up_rounded
                  : Icons.volume_down_rounded,
              label: 'Loa ngoài',
              active: _speakerOn,
              enabled: true,
              onTap: _toggleSpeaker,
            ),
          ],
        ),
        SizedBox(height: compact ? 28 : 44),
        _CallActionCircle(
          icon: Icons.call_end_rounded,
          label: 'Hủy',
          backgroundColor: MetaGymTheme.dangerCoral,
          foregroundColor: Colors.white,
          size: 70,
          iconSize: 30,
          onTap: _updating ? null : () => _update('MISSED'),
        ),
      ],
    );
  }

  Widget _buildConnectedAudioActions({required bool compact}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 28,
          runSpacing: 20,
          children: [
            _AudioGridButton(
              icon: _microphone ? Icons.mic_rounded : Icons.mic_off_rounded,
              label: _microphone ? 'Tắt tiếng' : 'Đang tắt mic',
              active: _connected && !_microphone,
              enabled: _connected && !_updatingMedia,
              onTap: _connected && !_updatingMedia
                  ? () => _setMedia(microphone: !_microphone)
                  : null,
            ),
            _AudioGridButton(
              icon: _speakerOn
                  ? Icons.volume_up_rounded
                  : Icons.volume_down_rounded,
              label: 'Loa ngoài',
              active: _speakerOn,
              enabled: true,
              onTap: _toggleSpeaker,
            ),
            if (!_connected && !_joining && !_reconnecting)
              _AudioGridButton(
                icon: Icons.refresh_rounded,
                label: 'Kết nối lại',
                active: false,
                enabled: true,
                onTap: _join,
              ),
          ],
        ),
        SizedBox(height: compact ? 28 : 44),
        _CallActionCircle(
          icon: Icons.call_end_rounded,
          label: 'Kết thúc',
          backgroundColor: MetaGymTheme.dangerCoral,
          foregroundColor: Colors.white,
          size: 70,
          iconSize: 30,
          onTap: _updating ? null : () => _update('ENDED'),
        ),
      ],
    );
  }

  Widget _buildVideoLayout(BuildContext context) {
    final remote = _cameraTrack(_room.remoteParticipants.values.firstOrNull);
    final local = _cameraTrack(_room.localParticipant);
    final waiting = _call.status == 'RINGING';
    final errors = _activeErrors;
    final showPip =
        !_call.isFinished && (_camera || local != null || _connected);

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Video đối phương full-screen hoặc nền chờ Meta Gym
        if (remote != null && !_call.isFinished)
          rtc.VideoTrackRenderer(remote, fit: rtc.VideoViewFit.cover)
        else
          Stack(
            fit: StackFit.expand,
            children: [
              const _CallBackdrop(),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PeerAvatarRing(
                        initials: _peerInitial,
                        size: 92,
                        pulseActive: waiting || _connected,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _displayPeerName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: MetaGymTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _connected && _room.remoteParticipants.isNotEmpty
                            ? 'Camera đối phương đang tắt'
                            : _statusLine,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: MetaGymTheme.textSecondary,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

        // 2. Lớp phủ scrim phía trên để dễ đọc trên nền video
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Container(
              height: 140,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xBF080A0D), Colors.transparent],
                ),
              ),
            ),
          ),
        ),

        // 3. Lớp phủ scrim phía dưới cho cụm nút tròn
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Container(
              height: 180,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xD9080A0D), Colors.transparent],
                ),
              ),
            ),
          ),
        ),

        // 4. Thanh top gọn kiểu Messenger + timer cuộc gọi
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  if (_call.isFinished)
                    _TopGlassIconButton(
                      tooltip: 'Đóng',
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    )
                  else
                    const SizedBox(width: 48, height: 48),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _displayPeerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: MetaGymTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _statusLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: MetaGymTheme.textSecondary,
                                fontFeatures: MetaGymTheme.tabularFigures,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_connected && _camera && !_call.isFinished)
                    _TopGlassIconButton(
                      tooltip: 'Đổi camera',
                      icon: Icons.cameraswitch_outlined,
                      onTap: _updatingMedia ? null : _switchCamera,
                    )
                  else
                    const SizedBox(width: 48, height: 48),
                ],
              ),
            ),
          ),
        ),

        // 5. Khung PiP camera local góc phải phía trên cụm nút (kiểu Messenger)
        if (showPip)
          Positioned(
            right: 16,
            bottom: 128 + MediaQuery.paddingOf(context).bottom,
            width: 104,
            height: 148,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xF0241F1B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xA3A79D92), width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: local != null
                  ? rtc.VideoTrackRenderer(local, fit: rtc.VideoViewFit.cover)
                  : const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.videocam_off_rounded,
                            color: MetaGymTheme.textSecondary,
                            size: 24,
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Cam tắt',
                            style: TextStyle(
                              color: MetaGymTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),

        // 6. Banner báo lỗi (nếu có)
        if (errors.isNotEmpty)
          Positioned(
            left: 16,
            right: showPip ? 132 : 16,
            bottom: 128 + MediaQuery.paddingOf(context).bottom,
            child: _CallErrorPill(message: errors.first),
          ),

        // 7. Hàng nút điều khiển phía dưới cùng
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: waiting && _incoming
                  ? _buildIncomingActions(isVideo: true)
                  : waiting
                  ? Center(
                      child: _CallActionCircle(
                        icon: Icons.call_end_rounded,
                        label: 'Hủy',
                        backgroundColor: MetaGymTheme.dangerCoral,
                        foregroundColor: Colors.white,
                        size: 66,
                        iconSize: 28,
                        onTap: _updating ? null : () => _update('MISSED'),
                      ),
                    )
                  : _call.status == 'ANSWERED'
                  ? _buildVideoBottomControls()
                  : _buildFinishedActions(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoBottomControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CallActionCircle(
          icon: _microphone ? Icons.mic_rounded : Icons.mic_off_rounded,
          backgroundColor: !_microphone
              ? MetaGymTheme.textPrimary
              : const Color(0xB82B2622),
          foregroundColor: !_microphone
              ? const Color(0xFF090B0E)
              : MetaGymTheme.textPrimary,
          borderColor: const Color(0xA3A79D92),
          size: 56,
          iconSize: 24,
          tooltip: _microphone ? 'Tắt mic' : 'Bật mic',
          onTap: _connected && !_updatingMedia
              ? () => _setMedia(microphone: !_microphone)
              : null,
        ),
        const SizedBox(width: 20),
        _CallActionCircle(
          icon: Icons.call_end_rounded,
          backgroundColor: MetaGymTheme.dangerCoral,
          foregroundColor: Colors.white,
          size: 66,
          iconSize: 28,
          tooltip: 'Kết thúc',
          onTap: _updating ? null : () => _update('ENDED'),
        ),
        const SizedBox(width: 20),
        _CallActionCircle(
          icon: _camera ? Icons.videocam_rounded : Icons.videocam_off_rounded,
          backgroundColor: !_camera
              ? MetaGymTheme.textPrimary
              : const Color(0xB82B2622),
          foregroundColor: !_camera
              ? const Color(0xFF090B0E)
              : MetaGymTheme.textPrimary,
          borderColor: const Color(0xA3A79D92),
          size: 56,
          iconSize: 24,
          tooltip: _camera ? 'Tắt camera' : 'Bật camera',
          onTap: _connected && !_updatingMedia
              ? () => _setMedia(camera: !_camera)
              : null,
        ),
        if (!_connected && !_joining && !_reconnecting) ...[
          const SizedBox(width: 16),
          _CallActionCircle(
            icon: Icons.refresh_rounded,
            backgroundColor: const Color(0xB82B2622),
            foregroundColor: MetaGymTheme.textPrimary,
            borderColor: const Color(0xA3A79D92),
            size: 56,
            iconSize: 24,
            tooltip: 'Kết nối lại',
            onTap: _join,
          ),
        ] else ...[
          const SizedBox(width: 16),
          _CallActionCircle(
            icon: _speakerOn
                ? Icons.volume_up_rounded
                : Icons.volume_down_rounded,
            backgroundColor: _speakerOn
                ? const Color(0xB82B2622)
                : MetaGymTheme.textPrimary,
            foregroundColor: _speakerOn
                ? MetaGymTheme.textPrimary
                : const Color(0xFF090B0E),
            borderColor: const Color(0xA3A79D92),
            size: 56,
            iconSize: 24,
            tooltip: _speakerOn ? 'Tắt loa ngoài' : 'Bật loa ngoài',
            onTap: _toggleSpeaker,
          ),
        ],
      ],
    );
  }

  Widget _buildIncomingActions({required bool isVideo}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CallActionCircle(
          icon: Icons.call_end_rounded,
          label: 'Từ chối',
          backgroundColor: MetaGymTheme.dangerCoral,
          foregroundColor: Colors.white,
          size: 68,
          iconSize: 28,
          onTap: _updating ? null : () => _update('REJECTED'),
        ),
        const SizedBox(width: 56),
        _CallActionCircle(
          icon: isVideo ? Icons.videocam_rounded : Icons.call_rounded,
          label: 'Chấp nhận',
          backgroundColor: MetaGymTheme.progressGreen,
          foregroundColor: const Color(0xFF06261D),
          size: 68,
          iconSize: 28,
          onTap: _updating ? null : () => _update('ANSWERED'),
        ),
      ],
    );
  }

  Widget _buildFinishedActions() {
    return Center(
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: MetaGymTheme.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(160, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        onPressed: () => Navigator.of(context).pop(),
        child: const Text(
          'Đóng',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
    );
  }
}

class _CallBackdrop extends StatelessWidget {
  const _CallBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: MetaGymTheme.darkCanvas,
        gradient: RadialGradient(
          center: Alignment(0.75, -0.75),
          radius: 1.1,
          colors: [Color(0x1FA9C7E8), Color(0xFF0F1115)],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.85, 0.85),
            radius: 0.95,
            colors: [Color(0x14FF5E36), Colors.transparent],
          ),
        ),
      ),
    );
  }
}

class _CallModeChip extends StatelessWidget {
  const _CallModeChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xC42B2622),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xA3A79D92)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: MetaGymTheme.reflectionBlue),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: MetaGymTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeerAvatarRing extends StatelessWidget {
  const _PeerAvatarRing({
    required this.initials,
    required this.size,
    required this.pulseActive,
  });

  final String initials;
  final double size;
  final bool pulseActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xC42B2622),
        border: Border.all(
          color: pulseActive
              ? const Color(0x99FF5E36)
              : const Color(0xA3A79D92),
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: MetaGymTheme.textPrimary,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AudioGridButton extends StatelessWidget {
  const _AudioGridButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = active
        ? MetaGymTheme.textPrimary
        : const Color(0xC42B2622);
    final fgColor = active
        ? const Color(0xFF090B0E)
        : enabled
        ? MetaGymTheme.textPrimary
        : const Color(0xFF9C948D);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            customBorder: const CircleBorder(),
            child: Ink(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bgColor,
                border: Border.all(
                  color: active
                      ? Colors.transparent
                      : const Color(0xA3A79D92),
                ),
              ),
              child: Icon(icon, size: 26, color: fgColor),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: enabled
                ? const Color(0xFFC8C2BC)
                : const Color(0xFF9C948D),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _CallActionCircle extends StatelessWidget {
  const _CallActionCircle({
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.size,
    required this.iconSize,
    required this.onTap,
    this.label,
    this.tooltip,
    this.borderColor,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final double size;
  final double iconSize;
  final VoidCallback? onTap;
  final String? label;
  final String? tooltip;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: backgroundColor,
            border: borderColor != null
                ? Border.all(color: borderColor!, width: 1)
                : null,
          ),
          child: Icon(icon, size: iconSize, color: foregroundColor),
        ),
      ),
    );

    final wrapped = tooltip != null
        ? Tooltip(message: tooltip!, child: button)
        : button;

    if (label == null) return wrapped;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        wrapped,
        const SizedBox(height: 8),
        Text(
          label!,
          style: const TextStyle(
            color: MetaGymTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _TopGlassIconButton extends StatelessWidget {
  const _TopGlassIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Ink(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0x9E2F2924),
              border: Border.all(color: const Color(0x95ADA295)),
            ),
            child: Icon(icon, size: 22, color: MetaGymTheme.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _CallErrorPill extends StatelessWidget {
  const _CallErrorPill({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xF0241F1B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x80F15B64)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: MetaGymTheme.dangerCoral,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              style: const TextStyle(
                color: MetaGymTheme.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
