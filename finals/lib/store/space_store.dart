import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/space.dart';
import '../models/app_notification.dart';
import 'auth_store.dart';
import 'storage_keys.dart';
import 'task_store.dart';

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

      // Build a fingerprint of every task's assignee list so that a pure
      // assignment change (no task count / status / member count change)
      // still triggers a sync for user B.
      String assignFingerprint(List<SpaceTask> tasks) => tasks
          .map((t) => '${t.title}:${(List<String>.from(t.assignedTo)..sort()).join(',')}')
          .join('|');

      final needsUpdate = patched.tasks.length != space.tasks.length ||
          patched.status != space.status ||
          patched.progress != space.progress ||
          patched.members.length != space.members.length ||
          patched.pendingMembers.length != space.pendingMembers.length ||
          assignFingerprint(patched.tasks) != assignFingerprint(space.tasks);

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
          pendingMembers: patched.pendingMembers,
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

  /// Writes a pending invite into [recipientUserId]'s inbox.
  /// Does NOT auto-join — the recipient must explicitly accept.
  Future<void> pushPendingInvite(String recipientUserId, Space space) async {
    if (recipientUserId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = kInboxSpaceInvites(recipientUserId);
    List<dynamic> list;
    try {
      final raw = prefs.getString(key);
      list = raw != null ? (jsonDecode(raw) as List) : [];
    } catch (_) {
      list = [];
    }
    if (!list.any((e) => (e as Map)['inviteCode'] == space.inviteCode)) {
      list.add(space.toJson());
      await prefs.setString(key, jsonEncode(list));
    }
  }

  /// Returns all pending invite [Space] objects waiting for the current user.
  /// Does not remove them — call [acceptInvite] or [declineInvite] to act.
  Future<List<Space>> getPendingInvites() async {
    final uid = AuthStore.instance.userId;
    if (uid.isEmpty) return [];
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kInboxSpaceInvites(uid));
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      final result = <Space>[];
      for (final e in list) {
        try {
          final space = Space.fromJson(Map<String, dynamic>.from(e as Map));
          // Skip if already joined.
          if (_spaces.any((s) => s.inviteCode == space.inviteCode)) continue;
          result.add(space);
        } catch (_) {}
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  /// Accept a pending invite: adds the space, moves B into members on creator's
  /// side via shared patches, and notifies the creator.
  Future<void> acceptInvite(Space invite) async {
    final uid = AuthStore.instance.userId;
    final myName = AuthStore.instance.displayName;

    // 1. Remove from inbox.
    await _removeFromInviteInbox(uid, invite.inviteCode);

    // 2. Fetch latest space state from registry.
    final latest = await lookupByCode(invite.inviteCode) ?? invite;

    // 3. Add to local spaces as a non-creator member.
    if (!_spaces.any((s) => s.inviteCode == latest.inviteCode)) {
      final members = List<String>.from(latest.members);
      if (!members.contains(myName)) members.add(myName);
      final joined = Space(
        name:           latest.name,
        description:    latest.description,
        dateRange:      latest.dateRange,
        dueDate:        latest.dueDate,
        members:        members,
        isCreator:      false,
        creatorName:    latest.creatorName,
        status:         latest.status,
        statusColor:    latest.statusColor,
        accentColor:    latest.accentColor,
        progress:       latest.progress,
        completedTasks: latest.completedTasks,
        tasks:          latest.tasks,
        inviteCode:     latest.inviteCode,
      );
      _spaces.add(joined);
      notifyListeners();
      await _save();
    }

    // 4. Patch registry: move B from pendingMembers → members.
    await _acceptMemberInRegistry(latest.inviteCode, myName);

    // 5. Notify the creator.
    final creatorId = AuthStore.instance.userIdForName(latest.creatorName);
    if (creatorId != null && creatorId.isNotEmpty) {
      final notif = AppNotification(
        id:               'invite_accepted_${latest.inviteCode}_$myName',
        type:             NotificationType.spaceMemberJoined,
        sourceId:         latest.inviteCode,
        spaceInviteCode:  latest.inviteCode,
        spaceAccentColor: latest.accentColor,
        title:            latest.name,
        subtitle:         '$myName accepted your invite 🎉',
        detail:           '$myName has joined "${latest.name}".',
      );
      await TaskStore.instance.pushInviteNotification(creatorId, notif);
    }
  }

  /// Decline a pending invite: clears it from inbox, removes B from
  /// pendingMembers on creator's side, and notifies the creator.
  Future<void> declineInvite(Space invite) async {
    final uid = AuthStore.instance.userId;
    final myName = AuthStore.instance.displayName;

    // 1. Remove from inbox.
    await _removeFromInviteInbox(uid, invite.inviteCode);

    // 2. Patch registry: remove B from pendingMembers.
    await _declineMemberInRegistry(invite.inviteCode, myName);

    // 3. Notify the creator.
    final creatorId = AuthStore.instance.userIdForName(invite.creatorName);
    if (creatorId != null && creatorId.isNotEmpty) {
      final notif = AppNotification(
        id:               'invite_declined_${invite.inviteCode}_$myName',
        type:             NotificationType.spaceInviteDeclined,
        sourceId:         invite.inviteCode,
        spaceInviteCode:  invite.inviteCode,
        spaceAccentColor: invite.accentColor,
        title:            invite.name,
        subtitle:         '$myName declined your invite',
        detail:           '$myName chose not to join "${invite.name}".',
      );
      await TaskStore.instance.pushInviteNotification(creatorId, notif);
    }
  }

  /// Reads pending invites on load — but does NOT auto-join anymore.
  /// Just used to ensure the inbox is accessible after a reload.
  Future<void> drainPendingInvites() async {
    // No-op: invites now sit in inbox until accepted/declined by the user.
    // getPendingInvites() is used by the UI to surface them.
  }

  // ── Invite inbox helpers ──────────────────────────────────

  Future<void> _removeFromInviteInbox(String uid, String inviteCode) async {
    if (uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = kInboxSpaceInvites(uid);
    final raw = prefs.getString(key);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .where((e) => (e as Map)['inviteCode'] != inviteCode)
          .toList();
      await prefs.setString(key, jsonEncode(list));
    } catch (_) {
      await prefs.remove(key);
    }
  }

  Future<void> _acceptMemberInRegistry(
      String inviteCode, String memberName) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kSpaceGlobalRegistry);
    if (raw == null) return;
    try {
      final registry =
          Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final entry = registry[inviteCode];
      if (entry == null) return;
      final updated = Map<String, dynamic>.from(entry as Map);
      final members = List<String>.from(updated['members'] as List? ?? []);
      final pending = List<String>.from(updated['pendingMembers'] as List? ?? []);
      pending.remove(memberName);
      if (!members.contains(memberName)) members.add(memberName);
      updated['members'] = members;
      updated['pendingMembers'] = pending;
      registry[inviteCode] = updated;
      await prefs.setString(kSpaceGlobalRegistry, jsonEncode(registry));
      // Also update shared patches so the creator's UI reflects the change.
      await _patchRegistryIntoSharedPatches(inviteCode, updated);
    } catch (_) {}
  }

  Future<void> _declineMemberInRegistry(
      String inviteCode, String memberName) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kSpaceGlobalRegistry);
    if (raw == null) return;
    try {
      final registry =
          Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final entry = registry[inviteCode];
      if (entry == null) return;
      final updated = Map<String, dynamic>.from(entry as Map);
      final pending = List<String>.from(updated['pendingMembers'] as List? ?? []);
      pending.remove(memberName);
      updated['pendingMembers'] = pending;
      registry[inviteCode] = updated;
      await prefs.setString(kSpaceGlobalRegistry, jsonEncode(registry));
      await _patchRegistryIntoSharedPatches(inviteCode, updated);
    } catch (_) {}
  }

  /// Called by User A to cancel a pending invite they sent to [memberName].
  /// Removes [memberName] from the space's in-memory pendingMembers,
  /// persists, patches the registry + shared patches, and clears B's inbox.
  Future<void> cancelInvite(Space space, String memberName) async {
    // 1. Mutate in-memory immediately so A's UI updates.
    space.pendingMembers.remove(memberName);
    save();

    // 2. Patch registry so it's consistent.
    await _declineMemberInRegistry(space.inviteCode, memberName);

    // 3. Clear B's invite inbox entry so the card disappears in their drawer.
    final invitedId = AuthStore.instance.userIdForName(memberName);
    if (invitedId != null && invitedId.isNotEmpty) {
      await _removeFromInviteInbox(invitedId, space.inviteCode);
    }
  }

  Future<void> _patchRegistryIntoSharedPatches(
      String inviteCode, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(kSpaceSharedPatches);
      final patches =
          raw != null ? Map<String, dynamic>.from(jsonDecode(raw) as Map) : {};
      patches[inviteCode] = data;
      await prefs.setString(kSpaceSharedPatches, jsonEncode(patches));
    } catch (_) {}
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

  /// Push a space-removal notice into [kickedUserId]'s deletion inbox so
  /// that when they next open the app, drainDeletionNotices() removes the
  /// space from their local list automatically.
  Future<void> pushKickNotice(String inviteCode, String kickedUserId) =>
      _pushDeletionNotice(inviteCode, kickedUserId);

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