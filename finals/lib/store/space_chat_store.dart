import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/space.dart';
import '../models/space_message.dart';
import 'task_store.dart';
import 'auth_store.dart';
import 'storage_keys.dart';

// Messages are shared across all members of a space — use the unscoped
// helper so every user reads/writes the same log for a given space code.
// Read cursors are per-user — use the scoped helper.
String get _kCursorsKey => AuthStore.instance.keyChatCursors();

// ── Sender resolution helper ───────────────────────────────────
// Returns the userId for a message sender name, checking current username
// and previousUsername (via AuthStore.userIdForName which already does both).
// Used so isOwn / unread checks survive username renames.
String? _senderUserId(String senderName) =>
    AuthStore.instance.userIdForName(senderName);

// ─────────────────────────────────────────────────────────────
// SpaceChatStore
// ─────────────────────────────────────────────────────────────
class SpaceChatStore extends ChangeNotifier {
  SpaceChatStore._();
  static final SpaceChatStore instance = SpaceChatStore._();

  final Map<String, List<SpaceMessage>> _messages    = {};
  final Map<String, int>                _readCursors = {};

  // ── Initialisation ────────────────────────────────────────

  Future<void> load(List<String> spaceCodes) async {
    final prefs = await SharedPreferences.getInstance();

    for (final code in spaceCodes) {
      if (code.isEmpty) continue;
      try {
        final raw = prefs.getString(kSpaceChatMessages(code));
        if (raw != null) {
          final list = jsonDecode(raw) as List;
          final messages = <SpaceMessage>[];
          for (final e in list) {
            try {
              messages.add(SpaceMessage.fromJson(
                  Map<String, dynamic>.from(e as Map)));
            } catch (_) {
              // Corrupt single message — skip it, keep the rest.
            }
          }
          _messages[code] = messages;
        }
      } catch (_) {
        // Corrupt message log for this space — start fresh.
        _messages.remove(code);
        await prefs.remove(kSpaceChatMessages(code));
      }
    }

    try {
      final rawCursors = prefs.getString(_kCursorsKey);
      if (rawCursors != null) {
        final map = jsonDecode(rawCursors) as Map<String, dynamic>;
        map.forEach((k, v) => _readCursors[k] = (v as num).toInt());
      }
    } catch (_) {
      _readCursors.clear();
      await prefs.remove(_kCursorsKey);
    }

    notifyListeners();
  }

  /// Clear in-memory state and reload for the current user / space set.
  Future<void> reload(List<String> spaceCodes) async {
    _messages.clear();
    _readCursors.clear();
    await load(spaceCodes);
  }

  Future<void> _saveMessages(String spaceCode) async {
    if (spaceCode.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final msgs = _messages[spaceCode] ?? [];
    await prefs.setString(
      kSpaceChatMessages(spaceCode),
      jsonEncode(msgs.map((m) => m.toJson()).toList()),
    );
  }

  Future<void> _saveCursors() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCursorsKey, jsonEncode(_readCursors));
  }

  /// Delete all messages and cursors for [spaceCode] when a space is
  /// deleted or the user leaves.
  Future<void> deleteMessagesFor(String spaceCode) async {
    if (spaceCode.isEmpty) return;
    _messages.remove(spaceCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kSpaceChatMessages(spaceCode));
    _readCursors.removeWhere((k, _) => k.startsWith('$spaceCode|'));
    await _saveCursors();
  }

  // ── Messages ────────────────────────────────────────────────

  List<SpaceMessage> messagesFor(String spaceCode) =>
      _messages.putIfAbsent(spaceCode, () => []);

  Future<void> addMessage(
    String spaceCode,
    SpaceMessage message, {
    Space? space,
    String? currentUser,
  }) async {
    if (spaceCode.isEmpty) return;
    messagesFor(spaceCode).add(message);

    if (space != null &&
        currentUser != null &&
        !message.isSystemMessage &&
        message.sender.isNotEmpty) {
      await TaskStore.instance.notifyNewChatMessage(
        space,
        message.sender,
        message.text,
      );
    }

    notifyListeners();
    _saveMessages(spaceCode);
  }

  void addSystemMessage(String spaceCode, String text) {
    addMessage(spaceCode, SpaceMessage.system(text));
  }

  // ── Unread tracking ─────────────────────────────────────────

  // Cursor keys are keyed by userId (stable across renames), not by username.
  // [currentUserId] must always be AuthStore.instance.userId.
  String _cursorKey(String spaceCode, String currentUserId) =>
      '$spaceCode|$currentUserId';

  /// [currentUserId] = AuthStore.instance.userId (stable UUID).
  void markAsRead(String spaceCode, String currentUserId) {
    if (spaceCode.isEmpty || currentUserId.isEmpty) return;
    final msgs      = messagesFor(spaceCode);
    final key       = _cursorKey(spaceCode, currentUserId);
    final lastIndex = msgs.length - 1;
    if (lastIndex > (_readCursors[key] ?? -1)) {
      _readCursors[key] = lastIndex;
      notifyListeners();
      _saveCursors();
    }
  }

  /// [currentUserId] = AuthStore.instance.userId (stable UUID).
  /// Counts non-system messages not sent by the current user that arrived
  /// after the read cursor.  Sender name is resolved to userId via
  /// AuthStore so messages sent under old usernames are still recognised
  /// as "own" after a rename.
  int unreadCountFor(String spaceCode, String currentUserId) {
    if (spaceCode.isEmpty || currentUserId.isEmpty) return 0;
    final msgs   = messagesFor(spaceCode);
    final cursor = _readCursors[_cursorKey(spaceCode, currentUserId)] ?? -1;
    var count = 0;
    for (var i = cursor + 1; i < msgs.length; i++) {
      final m = msgs[i];
      if (m.isSystemMessage) continue;
      // Resolve sender name → userId so renames don't break own-message detection.
      final senderId = _senderUserId(m.sender);
      if (senderId != currentUserId) count++;
    }
    return count;
  }

  /// Rewrites every stored chat message whose [sender] matches [oldName]
  /// to [newName], then re-persists the affected space logs.
  ///
  /// Call from [SpaceStore.renameUserInSpaces] immediately after updating
  /// space data, so that the chat history reflects the new username and
  /// [isOwn] / [unreadCountFor] comparisons stay correct even for
  /// messages sent before the rename.
  Future<void> renameSenderInMessages(
      String oldName, String newName, List<String> spaceCodes) async {
    if (oldName == newName || oldName.isEmpty || newName.isEmpty) return;
    for (final code in spaceCodes) {
      final msgs = _messages[code];
      if (msgs == null) continue;
      bool changed = false;
      for (int i = 0; i < msgs.length; i++) {
        if (msgs[i].sender == oldName) {
          msgs[i] = SpaceMessage(
            sender:    newName,
            text:      msgs[i].text,
            timestamp: msgs[i].timestamp,
          );
          changed = true;
        }
      }
      if (changed) await _saveMessages(code);
    }
    notifyListeners();
  }
}