import 'package:meta_gym_app/features/messaging/data/messaging_service.dart';
import 'package:meta_gym_app/features/messaging/domain/chat_message.dart';

class ConversationThreadCacheEntry {
  const ConversationThreadCacheEntry({
    required this.messages,
    required this.hasMore,
    this.lastReadId,
  });

  final List<ChatMessage> messages;
  final bool hasMore;
  final String? lastReadId;
}

class MessagingSessionCache {
  static const int _maxConversationsPerAccount = 24;
  static const int _maxMessagesPerConversation = 80;
  static String? _activeAccountId;
  static final Map<String, Map<String, ConversationThreadCacheEntry>>
  _threadsByAccount = {};

  static String _accountBucketKey(String userId, MessagingService service) =>
      '$userId::${identityHashCode(service)}';

  static void ensureAccount(String userId) {
    final normalized = userId.trim();
    if (normalized.isEmpty) {
      clearAll();
      return;
    }
    if (_activeAccountId != null && _activeAccountId != normalized) {
      clearAll();
    }
    _activeAccountId = normalized;
  }

  static void clearAll() {
    _activeAccountId = null;
    _threadsByAccount.clear();
  }

  static ConversationThreadCacheEntry? readThread(
    String userId,
    MessagingService? service,
    String conversationKey,
  ) {
    if (service == null || userId.trim().isEmpty) return null;
    ensureAccount(userId);
    final bucket = _threadsByAccount[_accountBucketKey(userId.trim(), service)];
    return bucket?[conversationKey];
  }

  static void writeThread(
    String userId,
    MessagingService? service,
    String conversationKey, {
    required List<ChatMessage> messages,
    bool? hasMore,
    String? lastReadId,
  }) {
    if (service == null || userId.trim().isEmpty) return;
    final cleanUser = userId.trim();
    ensureAccount(cleanUser);
    final bucketKey = _accountBucketKey(cleanUser, service);
    final bucket = _threadsByAccount.putIfAbsent(bucketKey, () => {});
    final previous = bucket.remove(conversationKey);
    final bounded = messages.length > _maxMessagesPerConversation
        ? messages.sublist(0, _maxMessagesPerConversation)
        : messages;
    bucket[conversationKey] = ConversationThreadCacheEntry(
      messages: List<ChatMessage>.unmodifiable(bounded),
      hasMore: hasMore ?? previous?.hasMore ?? false,
      lastReadId: lastReadId ?? previous?.lastReadId,
    );
    while (bucket.length > _maxConversationsPerAccount) {
      bucket.remove(bucket.keys.first);
    }
  }
}
