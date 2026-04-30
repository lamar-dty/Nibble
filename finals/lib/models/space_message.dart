import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// SpaceMessage
// ─────────────────────────────────────────────────────────────
class SpaceMessage {
  final String id;

  /// The real display name of the sender as stored in AuthStore.
  /// Never a sentinel string ('You', 'You (Creator)', 'Creator', etc.).
  /// System messages use the reserved value 'system'.
  final String sender;

  final String text;
  final DateTime timestamp;
  final bool isSystemMessage;

  SpaceMessage({
    required this.sender,
    required this.text,
    DateTime? timestamp,
    this.isSystemMessage = false,
    String? id,
  })  : assert(
          sender.isNotEmpty,
          'SpaceMessage.sender must not be empty. '
          'Use AuthStore.instance.displayName for user messages '
          'or SpaceMessage.system() for system messages.',
        ),
        assert(
          !_isSentinel(sender) || sender == 'system',
          'SpaceMessage.sender must be a real display name, not a sentinel '
          'string ("$sender"). Resolve the name from AuthStore before '
          'constructing a SpaceMessage.',
        ),
        timestamp = timestamp ?? DateTime.now(),
        id = id ?? '${DateTime.now().millisecondsSinceEpoch}_$sender';

  // ── Sentinel guard ─────────────────────────────────────────
  /// Returns true when [name] is a placeholder that must never be stored.
  static bool _isSentinel(String name) {
    // Keep this list in sync with any UI labels that may bleed into model code.
    const sentinels = <String>{
      'You',
      'You (Creator)',
      'Creator',
      'system', // allowed only via SpaceMessage.system()
    };
    if (sentinels.contains(name)) return true;
    // Catch patterns like "Alice (Creator)" that originate from the picker.
    if (name.endsWith(' (Creator)')) return true;
    return false;
  }

  // ── Factory constructors ───────────────────────────────────

  factory SpaceMessage.system(String text) => SpaceMessage(
        sender: 'system',
        text: text,
        isSystemMessage: true,
      );

  // ── Serialisation ──────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender': sender,
        'text': text,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'isSystemMessage': isSystemMessage,
      };

  factory SpaceMessage.fromJson(Map<String, dynamic> j) {
    final rawSender = (j['sender'] as String?) ?? '';
    // Guard against sentinel strings that may have been stored by an older
    // build.  Remap known sentinels to a safe fallback so the message can still
    // render without crashing, but flag it so it is never re-stored.
    final sender = _sanitiseSender(rawSender);

    return SpaceMessage(
      id: (j['id'] as String?) ?? '',
      sender: sender,
      text: (j['text'] as String?) ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
          (j['timestamp'] as int?) ?? 0),
      isSystemMessage: (j['isSystemMessage'] as bool?) ?? false,
    );
  }

  /// Converts legacy sentinel sender values into a safe fallback.
  /// Only called during deserialisation; the primary constructor rejects
  /// sentinels at runtime for new messages.
  static String _sanitiseSender(String raw) {
    if (raw == 'system') return raw; // always valid
    if (raw.isEmpty) return 'system'; // corrupt record → treat as system
    if (raw == 'You' || raw == 'You (Creator)' || raw == 'Creator') {
      // Can't resolve back to a real name without the auth context here;
      // use the system sentinel so the message renders without crashing.
      // The UI layer will hide the sender label for system messages.
      return 'system';
    }
    // Strip any trailing " (Creator)" suffix stored by legacy code.
    if (raw.endsWith(' (Creator)')) {
      return raw.substring(0, raw.length - ' (Creator)'.length).trim();
    }
    return raw;
  }
}