import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/space.dart';
import 'auth_store.dart';
import 'storage_keys.dart';

// ─────────────────────────────────────────────────────────────
// Key accessors — resolved via StorageKeys so no raw strings
// are scattered through this file.
// ─────────────────────────────────────────────────────────────
String get _kSpaces => AuthStore.instance.keySpaceList();

// ─────────────────────────────────────────────────────────────
// SpaceStore
// ─────────────────────────────────────────────────────────────
class SpaceStore extends ChangeNotifier {
  SpaceStore._();
  static final SpaceStore instance = SpaceStore._();

  final List<Space> _spaces = [];

  List<Space> get spaces => _spaces;

  // ── Initialisation ────────────────────────────────────────

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(_kSpaces);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        for (final e in list) {
          try {
            _spaces.add(Space.fromJson(Map<String, dynamic>.from(e as Map)));
          } catch (_) {
            // Corrupt single entry — skip it, keep the rest.
          }
        }
        notifyListeners();
      }
    } catch (_) {
      // Corrupt top-level data — wipe and start clean so the app doesn't crash.
      _spaces.clear();
      await prefs.remove(_kSpaces);
    }
    await drainPendingInvites();
  }

  /// Clear in-memory state and reload for the current user.
  Future<void> reload() async {
    _spaces.clear();
    await load();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kSpaces, jsonEncode(_spaces.map((s) => s.toJson()).toList()));
  }

  // ── Global registry ───────────────────────────────────────

  Future<void> _registerGlobally(Space space) async {
    if (!space.isCreator) return;
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(kSpaceGlobalRegistry);
      final Map<String, dynamic> registry =
          raw != null ? Map<String, dynamic>.from(jsonDecode(raw) as Map) : {};
      registry[space.inviteCode] = space.toJson();
      await prefs.setString(kSpaceGlobalRegistry, jsonEncode(registry));
    } catch (_) {
      // Corrupt registry — overwrite with just this space rather than crash.
      try {
        await prefs.setString(
            kSpaceGlobalRegistry,
            jsonEncode({space.inviteCode: space.toJson()}));
      } catch (_) {}
    }
  }

  Future<void> _unregisterGlobally(String inviteCode) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(kSpaceGlobalRegistry);
      if (raw == null) return;
      final Map<String, dynamic> registry =
          Map<String, dynamic>.from(jsonDecode(raw) as Map);
      registry.remove(inviteCode);
      // Also clean up any shared patches for this space.
      try {
        final patchRaw = prefs.getString(kSpaceSharedPatches);
        if (patchRaw != null) {
          final patches =
              Map<String, dynamic>.from(jsonDecode(patchRaw) as Map);
          patches.remove(inviteCode);
          await prefs.setString(kSpaceSharedPatches, jsonEncode(patches));
        }
      } catch (_) {
        // Corrupt patches — leave as-is; they'll be ignored on next sync.
      }
      await prefs.setString(kSpaceGlobalRegistry, jsonEncode(registry));
    } catch (_) {
      // Corrupt registry — nothing to unregister from.
    }
  }

  /// Look up a space by invite code from the global registry.
  Future<Space?> lookupByCode(String code) async {
    if (code.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kSpaceGlobalRegistry);
    if (raw == null) return null;
    try {
      final Map<String, dynamic> registry =
          Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final entry = registry[code];
      if (entry == null) return null;
      return Space.fromJson(Map<String, dynamic>.from(entry as Map));
    } catch (_) {
      return null;
    }
  }

  // ── Shared patches ────────────────────────────────────────

  /// Public entry point used when a member leaves.
  Future<void> writeSharedPatchForLeave(Space space) =>
      _writeSharedPatch(space);

  Future<void> _writeSharedPatch(Space space) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(kSpaceSharedPatches);
      final Map<String, dynamic> patches =
          raw != null ? Map<String, dynamic>.from(jsonDecode(raw) as Map) : {};
      patches[space.inviteCode] = space.toJson();
      await prefs.setString(kSpaceSharedPatches, jsonEncode(patches));
    } catch (_) {
      // Corrupt patches blob — overwrite with just this space's patch.
      try {
        await prefs.setString(
            kSpaceSharedPatches,
            jsonEncode({space.inviteCode: space.toJson()}));
      } catch (_) {}
    }
  }

  Future<void> patchMembersInRegistry(
      String inviteCode, List<String> members) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kSpaceGlobalRegistry);
    if (raw == null) return;
    try {
      final Map<String, dynamic> registry =
          Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final entry = registry[inviteCode];
      if (entry == null) return;
      final Map<String, dynamic> updated =
          Map<String, dynamic>.from(entry as Map);
      updated['members'] = members;
      registry[inviteCode] = updated;
      await prefs.setString(kSpaceGlobalRegistry, jsonEncode(registry));
    } catch (_) {
      // Registry corrupted — ignore; the creator will overwrite on next save.
    }
  }

  /// Pull the latest state from shared patches into all in-memory spaces.
  /// Also prunes members from task assignments who no longer exist in the
  /// patched members list, preventing ghost UI states.
  Future<void> syncFromSharedPatches() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kSpaceSharedPatches);
    if (raw == null) return;
    Map<String, dynamic> patches;
    try {
      patches = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return; // corrupt patches — skip silently
    }

    bool changed = false;
    for (int i = 0; i < _spaces.length; i++) {
      final space = _spaces[i];
      final patch = patches[space.inviteCode];
      if (patch == null) continue;

      Space patched;
      try {
        patched = Space.fromJson(Map<String, dynamic>.from(patch as Map));
      } catch (_) {
        continue; // corrupt patch for this space — skip
      }

      final needsUpdate = patched.tasks.length != space.tasks.length ||
          patched.status != space.status ||
          patched.progress != space.progress ||
          patched.members.length != space.members.length;

      if (needsUpdate) {
        // Validate member names: strip assignedTo entries for any member no
        // longer in the updated members list (deleted / removed accounts).
        final validMembers = {
          patched.creatorName,
          ...patched.members,
        };
        for (final task in patched.tasks) {
          task.assignedTo
              .removeWhere((name) => !_isValidMember(name, validMembers));
        }

        final merged = Space(
          name: patched.name,
          description: patched.description,
          dateRange: patched.dateRange,
          dueDate: patched.dueDate,
          members: patched.members,
          isCreator: space.isCreator, // always keep local flag
          creatorName: patched.creatorName,
          status: patched.status,
          statusColor: patched.statusColor,
          accentColor: patched.accentColor,
          progress: patched.progress,
          completedTasks: patched.completedTasks,
          tasks: patched.tasks,
          inviteCode: space.inviteCode,
        );
        _spaces[i] = merged;
        changed = true;
      }
    }

    if (changed) {
      notifyListeners();
      await _save();
    }
  }

  /// A member name is valid if it appears in the authoritative set OR is a
  /// known sentinel ('You', 'You (Creator)').  Sentinels are display-time
  /// aliases and don't need to match a real member entry.
  bool _isValidMember(String name, Set<String> validMembers) {
    if (name == 'You' || name == 'You (Creator)') return true;
    // Strip the " (Creator)" suffix added by the assignment picker.
    final cleaned = name.endsWith(' (Creator)')
        ? name.substring(0, name.length - ' (Creator)'.length)
        : name;
    return validMembers.contains(cleaned);
  }

  // ── Pending invites ───────────────────────────────────────

  Future<void> pushPendingInvite(String recipientUserId, Space space) async {
    if (recipientUserId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = kInboxSpaceInvites(recipientUserId);
    List<dynamic> list;
    try {
      final raw = prefs.getString(key);
      list = raw != null ? (jsonDecode(raw) as List) : [];
    } catch (_) {
      list = []; // corrupt inbox — start fresh rather than drop the invite
    }
    if (!list.any((e) => (e as Map)['inviteCode'] == space.inviteCode)) {
      list.add(space.toJson());
      await prefs.setString(key, jsonEncode(list));
    }
  }

  Future<void> drainPendingInvites() async {
    final uid = AuthStore.instance.userId;
    if (uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = kInboxSpaceInvites(uid);
    final raw = prefs.getString(key);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List;
      bool changed = false;
      for (final e in list) {
        Space incoming;
        try {
          incoming =
              Space.fromJson(Map<String, dynamic>.from(e as Map));
        } catch (_) {
          continue; // corrupt entry — skip
        }
        if (_spaces.any((s) => s.inviteCode == incoming.inviteCode)) {
          continue; // already joined
        }
        // Always use the latest state from the global registry so the
        // invitee sees the most up-to-date tasks and member list.
        final latest = await lookupByCode(incoming.inviteCode) ?? incoming;
        final joined = Space(
          name: latest.name,
          description: latest.description,
          dateRange: latest.dateRange,
          dueDate: latest.dueDate,
          members: List<String>.from(latest.members),
          isCreator: false,
          creatorName: latest.creatorName,
          status: latest.status,
          statusColor: latest.statusColor,
          accentColor: latest.accentColor,
          progress: latest.progress,
          completedTasks: latest.completedTasks,
          tasks: latest.tasks,
          inviteCode: latest.inviteCode,
        );
        _spaces.add(joined);
        changed = true;
      }
      await prefs.remove(key);
      if (changed) {
        notifyListeners();
        await _save();
      }
    } catch (_) {
      await prefs.remove(key); // corrupt inbox — clear it
    }
  }

  // ── CRUD ──────────────────────────────────────────────────

  Future<void> addSpace(Space space) async {
    _spaces.add(space);
    notifyListeners();
    await _save();
    await _registerGlobally(space);
    await _writeSharedPatch(space);
  }

  Future<void> removeSpace(Space space) async {
    _spaces.remove(space);
    notifyListeners();
    await _save();
    if (space.isCreator) {
      // Before wiping global state, push a deletion notice to every member
      // so their device removes the space automatically on next focus.
      await _pushDeletionNoticesToMembers(space);
      await _unregisterGlobally(space.inviteCode);
    } else {
      final leavingName = AuthStore.instance.displayName;
      await _removeMemberFromRegistry(space.inviteCode, leavingName);
      await _removeMemberFromPatches(space.inviteCode, leavingName);
    }
  }

  // ── Deletion broadcast ────────────────────────────────────

  /// Write [space.inviteCode] into each member's deletion inbox so they
  /// remove the space from their list the next time the screen focuses.
  Future<void> _pushDeletionNoticesToMembers(Space space) async {
    final myId = AuthStore.instance.userId;
    for (final memberName in space.members) {
      final cleaned = memberName
          .replaceAll(RegExp(r'\s*\(Creator\)\s*$'), '')
          .trim();
      if (cleaned.isEmpty) continue;
      final memberId = AuthStore.instance.userIdForName(cleaned);
      if (memberId == null || memberId.isEmpty) continue;
      // Never send a deletion notice to the creator themselves.
      if (memberId == myId) continue;
      await _pushDeletionNotice(space.inviteCode, memberId);
    }
  }

  /// Write [inviteCode] into [recipientUserId]'s deletion inbox.
  Future<void> _pushDeletionNotice(
      String inviteCode, String recipientUserId) async {
    if (recipientUserId.isEmpty || inviteCode.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = kInboxSpaceDeletion(recipientUserId);
    List<dynamic> list;
    try {
      final raw = prefs.getString(key);
      list = raw != null ? (jsonDecode(raw) as List) : [];
    } catch (_) {
      list = []; // corrupt inbox — start fresh
    }
    if (!list.contains(inviteCode)) {
      list.add(inviteCode);
      await prefs.setString(key, jsonEncode(list));
    }
  }

  /// Drain the deletion inbox for the current user.
  ///
  /// Returns the set of invite codes that were removed so the caller can
  /// fire notifications and clean up dependent state (chat, task notifs).
  /// The inbox is cleared atomically after draining.
  Future<Set<String>> drainDeletionNotices() async {
    final uid = AuthStore.instance.userId;
    if (uid.isEmpty) return {};
    final prefs = await SharedPreferences.getInstance();
    final key = kInboxSpaceDeletion(uid);
    final raw = prefs.getString(key);
    if (raw == null) return {};

    Set<String> removed = {};
    try {
      final List<dynamic> codes = jsonDecode(raw) as List;
      for (final entry in codes) {
        // Tolerate non-String entries from corrupt / future-version data.
        final code = entry is String ? entry : null;
        if (code == null || code.isEmpty) continue;
        // Remove every matching space from the in-memory list.
        final before = _spaces.length;
        _spaces.removeWhere((s) => s.inviteCode == code);
        if (_spaces.length < before) removed.add(code);
      }
    } catch (_) {
      // Corrupt inbox — clear it and return empty so the screen doesn't crash.
    }
    // Always wipe the inbox after draining, even if nothing matched,
    // so stale entries don't replay on every subsequent launch.
    await prefs.remove(key);
    if (removed.isNotEmpty) {
      notifyListeners();
      await _save();
    }
    return removed;
  }

  Future<void> _removeMemberFromRegistry(
      String inviteCode, String memberName) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kSpaceGlobalRegistry);
    if (raw == null) return;
    try {
      final Map<String, dynamic> registry =
          Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final entry = registry[inviteCode];
      if (entry == null) return;
      final Map<String, dynamic> updated =
          Map<String, dynamic>.from(entry as Map);
      final members = List<String>.from(updated['members'] as List)
        ..remove(memberName);
      updated['members'] = members;
      registry[inviteCode] = updated;
      await prefs.setString(kSpaceGlobalRegistry, jsonEncode(registry));
    } catch (_) {}
  }

  Future<void> _removeMemberFromPatches(
      String inviteCode, String memberName) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kSpaceSharedPatches);
    if (raw == null) return;
    try {
      final Map<String, dynamic> patches =
          Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final entry = patches[inviteCode];
      if (entry == null) return;
      final Map<String, dynamic> updated =
          Map<String, dynamic>.from(entry as Map);
      final members = List<String>.from(updated['members'] as List)
        ..remove(memberName);
      updated['members'] = members;
      patches[inviteCode] = updated;
      await prefs.setString(kSpaceSharedPatches, jsonEncode(patches));
    } catch (_) {}
  }

  /// Call after any in-place mutation to a Space so changes are persisted
  /// and broadcast to other members via the shared patches store.
  void save() {
    notifyListeners();
    _save();
    for (final s in _spaces) {
      if (s.isCreator) _registerGlobally(s);
      _writeSharedPatch(s);
    }
  }

  /// Returns a set of all active invite codes for the current user's spaces.
  /// Use this to prune orphaned notifications after removing a space.
  Set<String> get activeInviteCodes =>
      _spaces.map((s) => s.inviteCode).toSet();
}