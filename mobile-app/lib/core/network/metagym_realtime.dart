import 'dart:async';

import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:supabase/supabase.dart';

class MetaGymRealtime {
  MetaGymRealtime(this._api, this._session) {
    _session.addListener(_syncSession);
    _syncSession();
  }

  final ApiClient _api;
  final SessionController _session;
  final _messages = StreamController<String>.broadcast();
  final _calls = StreamController<void>.broadcast();
  SupabaseClient? _client;
  Timer? _renewal;
  String? _userId;
  int _generation = 0;

  Stream<String> get messages => _messages.stream;
  Stream<void> get calls => _calls.stream;

  void _syncSession() {
    final user = _session.user;
    final id =
        _session.status == SessionStatus.authenticated &&
            (user?.role == UserRole.member || user?.role == UserRole.coach)
        ? user?.id
        : null;
    if (id == _userId) return;
    _userId = id;
    _reset();
    if (id != null) unawaited(_connect(_generation));
  }

  void _reset() {
    _generation++;
    _renewal?.cancel();
    _renewal = null;
    final client = _client;
    _client = null;
    if (client != null) unawaited(client.dispose());
  }

  Future<void> _connect(int generation) async {
    try {
      final settings = (await _api.get<Map<String, dynamic>?>(
        '/realtime/subscription',
        decode: (value) =>
            value == null ? null : Map<String, dynamic>.from(value as Map),
      )).data;
      if (generation != _generation || settings == null) return;
      final token = settings['token'] as String;
      final existing = _client;
      if (existing != null) {
        await existing.realtime.setAuth(token);
      } else {
        final client = SupabaseClient(
          settings['url'] as String,
          settings['key'] as String,
        );
        _client = client;
        await client.realtime.setAuth(token);
        if (generation != _generation) return;
        client
            .channel(
              settings['topic'] as String,
              opts: const RealtimeChannelConfig(private: true),
            )
            .onBroadcast(
              event: 'message',
              callback: (payload) {
                final conversationId = payload['conversationId'];
                if (generation == _generation && conversationId is String) {
                  _messages.add(conversationId);
                }
              },
            )
            .onBroadcast(
              event: 'incoming_call',
              callback: (_) {
                if (generation == _generation) _calls.add(null);
              },
            )
            .subscribe();
      }
      if (generation == _generation) {
        _renewal = Timer(
          const Duration(minutes: 3),
          () => _connect(generation),
        );
      }
    } catch (_) {
      if (generation == _generation) {
        _reset();
        final next = _generation;
        _renewal = Timer(const Duration(seconds: 30), () => _connect(next));
      }
    }
  }

  void dispose() {
    _session.removeListener(_syncSession);
    _reset();
    unawaited(_messages.close());
    unawaited(_calls.close());
  }
}
