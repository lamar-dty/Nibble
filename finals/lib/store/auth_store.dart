import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'storage_keys.dart';

// ─────────────────────────────────────────────────────────────
// Username validation
// ─────────────────────────────────────────────────────────────

/// Rules: lowercase letters, digits, underscores; 3–20 characters.
final RegExp _usernameRegex = RegExp(r'^[a-z0-9_]{3,20}$');

/// Normalises a raw username input before validation or lookup.
/// Strips whitespace and converts to lowercase.
String _normaliseUsername(String raw) => raw.trim().toLowerCase();

/// Returns null when [username] is valid, or a human-readable error string.
String? validateUsername(String username) {
  final n = _normaliseUsername(username);
  if (n.isEmpty) return 'Username must not be empty.';
  if (n.length < 3) return 'Username must be at least 3 characters.';
  if (n.length > 20) return 'Username must be 20 characters or fewer.';
  if (!_usernameRegex.hasMatch(n)) {
    return 'Username may only contain lowercase letters, numbers, and underscores.';
  }
  return null;
}

// ─────────────────────────────────────────────────────────────
// User model
// ─────────────────────────────────────────────────────────────
class UserRecord {
  final String id;             // stable UUID assigned at signup
  final String username;       // unique public handle  e.g. "jane_doe"
  final String? displayName;   // optional human-readable override
  final String email;
  final String passwordHash;

  UserRecord({
    required this.id,
    required this.username,
    this.displayName,
    required this.email,
    required this.passwordHash,
  });

  /// The name surfaces in UI and in cross-user references
  /// (Space.creatorName, SpaceTask.assignedTo, SpaceMessage.sender, etc.).
  /// Always returns [username] — displayName is retained in storage for
  /// future use but is no longer the active public identity.
  String get effectiveName => username;

  Map<String, dynamic> toJson() => {
        'id':           id,
        'username':     username,
        if (displayName != null) 'displayName': displayName,
        'email':        email,
        'passwordHash': passwordHash,
      };

  /// Deserialises a stored record.
  ///
  /// MIGRATION SAFETY: records written by the previous schema stored the
  /// human-readable name under the key 'name' and had no 'username' field.
  /// If 'username' is absent we promote 'name' as the username candidate;
  /// if that too is absent we fall back to the local part of the email so
  /// the app can never crash on old data.
  factory UserRecord.fromJson(Map<String, dynamic> json) {
    // Resolve username with migration fallback.
    String username;
    if (json.containsKey('username') &&
        (json['username'] as String?)?.isNotEmpty == true) {
      username = json['username'] as String;
    } else if (json.containsKey('name') &&
        (json['name'] as String?)?.isNotEmpty == true) {
      // Pre-username-system record: sanitise legacy name into a valid username.
      final legacyName = (json['name'] as String).trim().toLowerCase();
      // Replace any character not in [a-z0-9_] with '_', then clamp length.
      final sanitised = legacyName
          .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
      username = sanitised.isEmpty
          ? 'user'
          : sanitised.substring(0, sanitised.length.clamp(0, 20));
      if (username.length < 3) username = username.padRight(3, '0');
    } else {
      // Last-resort: derive from email local part.
      final email = (json['email'] as String? ?? '').split('@').first;
      final sanitised = email
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
          .substring(0, email.length.clamp(0, 20));
      username = sanitised.length >= 3 ? sanitised : 'usr';
    }

    // Resolve displayName: use stored 'displayName', or migrate from 'name'
    // if it differs from the resolved username.
    String? displayName = json['displayName'] as String?;
    if ((displayName == null || displayName.isEmpty) &&
        json.containsKey('name')) {
      final legacyName = (json['name'] as String?)?.trim() ?? '';
      if (legacyName.isNotEmpty && legacyName != username) {
        displayName = legacyName;
      }
    }

    return UserRecord(
      id:           json['id'] as String,
      username:     username,
      displayName:  displayName?.isEmpty == true ? null : displayName,
      email:        json['email'] as String,
      passwordHash: json['passwordHash'] as String,
    );
  }
}

// ── UUID v4 generator (no external package) ───────────────────
String _generateUuid() {
  final rng   = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
  String hex(int b) => b.toRadixString(16).padLeft(2, '0');
  return '${bytes.sublist(0, 4).map(hex).join()}'
      '-${bytes.sublist(4, 6).map(hex).join()}'
      '-${bytes.sublist(6, 8).map(hex).join()}'
      '-${bytes.sublist(8, 10).map(hex).join()}'
      '-${bytes.sublist(10, 16).map(hex).join()}';
}

// ── Lightweight deterministic hash (avoids storing plaintext) ─
String _hashPassword(String pass) {
  var h = 5381;
  for (final c in pass.codeUnits) {
    h = ((h << 5) + h + c) & 0xFFFFFFFF;
  }
  return h.toRadixString(16);
}

// ─────────────────────────────────────────────────────────────
// AuthStore
// ─────────────────────────────────────────────────────────────
class AuthStore extends ChangeNotifier {
  AuthStore._();
  static final AuthStore instance = AuthStore._();

  final List<UserRecord> _users = [];
  UserRecord? _currentUser;

  // ── Identity accessors ─────────────────────────────────────

  bool get isLoggedIn => _currentUser != null;

  /// Stable UUID of the authenticated user, or empty string when logged out.
  String get userId => _currentUser?.id ?? '';

  /// Public username handle (e.g. "jane_doe").
  /// Returns empty string when no user is logged in.
  String get username => _currentUser?.username ?? '';

  /// Canonical public name of the authenticated user.
  ///
  /// This is the value that must be stored in Space.creatorName,
  /// Space.members, SpaceTask.assignedTo, and SpaceMessage.sender.
  /// Never use sentinel strings ('You', 'You (Creator)', 'Creator') in place
  /// of this value in any model or storage layer.
  ///
  /// Always resolves to [username] — displayName preference has been
  /// disabled; username is the sole public identity.
  /// Returns empty string when no user is logged in.  Callers that need a
  /// guaranteed non-empty value should guard with [isLoggedIn].
  String get displayName => _currentUser?.effectiveName ?? '';

  String get displayEmail => _currentUser?.email ?? '';

  /// Stripped UUID (no dashes), 32 hex chars — used as storage namespace.
  /// IMPORTANT: never use username as a storage key; always use this prefix.
  String get _storagePrefix =>
      _currentUser?.id.replaceAll('-', '') ?? '';

  /// Short tag shown in the drawer — first 8 chars of the stripped UUID,
  /// or an empty placeholder when no user is logged in.
  String get userTag => isLoggedIn && _storagePrefix.length >= 8
      ? '#${_storagePrefix.substring(0, 8)}'
      : '';

  // ── Username helpers ───────────────────────────────────────

  /// Returns null when [username] passes all rules, or an error string.
  /// This is a pure validation check — does not consult the user list.
  String? validateUsernameInput(String username) =>
      validateUsername(username);

  /// Returns true when [username] is not yet claimed by any registered user.
  bool isUsernameAvailable(String username) {
    final n = _normaliseUsername(username);
    if (n.isEmpty) return false;
    return !_users.any((u) => u.username == n);
  }

  /// Look up a [UserRecord] by exact username (case-insensitive).
  /// Returns null if not found.
  UserRecord? userForUsername(String username) {
    final n = _normaliseUsername(username);
    if (n.isEmpty) return null;
    try {
      return _users.firstWhere((u) => u.username == n);
    } catch (_) {
      return null;
    }
  }

  // ── Cross-user lookups ─────────────────────────────────────

  /// All registered accounts: username → userId.
  /// Used by TaskStore to address cross-user notifications.
  /// Keys are always usernames (effectiveName == username).
  Map<String, String> get allUserIds =>
      {for (final u in _users) u.effectiveName: u.id};

  /// Look up a userId by effective display name. Returns null if not found.
  String? userIdForName(String name) {
    if (name.isEmpty) return null;
    try {
      return _users.firstWhere((u) => u.effectiveName == name).id;
    } catch (_) {
      return null;
    }
  }

  /// Look up a userId by username. Returns null if not found.
  String? userIdForUsername(String username) {
    final record = userForUsername(username);
    return record?.id;
  }

  /// Look up the public username by userId or the short 8-char
  /// userTag prefix. Returns null if not found.
  /// NOTE: since effectiveName == username, this now always returns the username.
  String? nameForId(String id) {
    if (id.isEmpty) return null;
    final cleaned = id.startsWith('#') ? id.substring(1) : id;
    try {
      return _users
          .firstWhere((u) {
            final stripped = u.id.replaceAll('-', '');
            return u.id == cleaned ||
                (stripped.length >= 8 && stripped.substring(0, 8) == cleaned);
          })
          .effectiveName;
    } catch (_) {
      return null;
    }
  }

  /// Look up a username by userId or the short 8-char userTag prefix.
  /// Returns null if not found.
  String? usernameForId(String id) {
    if (id.isEmpty) return null;
    final cleaned = id.startsWith('#') ? id.substring(1) : id;
    try {
      return _users
          .firstWhere((u) {
            final stripped = u.id.replaceAll('-', '');
            return u.id == cleaned ||
                (stripped.length >= 8 && stripped.substring(0, 8) == cleaned);
          })
          .username;
    } catch (_) {
      return null;
    }
  }

  // ── Initialisation ────────────────────────────────────────

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    // Restore registered accounts.  A schema mismatch must never prevent
    // the app from launching — wipe corrupted data cleanly.
    try {
      final rawUsers = prefs.getString(kAuthUsers);
      if (rawUsers != null) {
        final list = jsonDecode(rawUsers) as List;
        _users.addAll(
          list.map((e) =>
              UserRecord.fromJson(Map<String, dynamic>.from(e as Map))),
        );
      }

      // Post-load: repair username uniqueness collisions that could arise from
      // migration (two legacy records whose sanitised usernames collide).
      _deduplicateUsernames();
    } catch (_) {
      _users.clear();
      await prefs.remove(kAuthUsers);
      await prefs.remove(kAuthSessionUser);
      notifyListeners();
      return;
    }

    // Restore session.
    final sessionEmail = prefs.getString(kAuthSessionUser);
    if (sessionEmail != null) {
      _currentUser =
          _users.where((u) => u.email == sessionEmail).firstOrNull;
    }

    notifyListeners();
  }

  /// Ensures all loaded records have unique usernames by appending a numeric
  /// suffix to duplicates (in insertion order, so earlier records win).
  void _deduplicateUsernames() {
    final seen = <String>{};
    for (var i = 0; i < _users.length; i++) {
      var candidate = _users[i].username;
      if (seen.contains(candidate)) {
        var suffix = 2;
        while (seen.contains('${candidate}_$suffix')) {
          suffix++;
        }
        candidate = '${candidate}_$suffix';
        // Clamp to 20 chars if the base was close to the limit.
        if (candidate.length > 20) {
          final base = candidate.substring(0, 20 - suffix.toString().length - 1);
          candidate = '${base}_$suffix';
        }
        _users[i] = UserRecord(
          id:           _users[i].id,
          username:     candidate,
          displayName:  _users[i].displayName,
          email:        _users[i].email,
          passwordHash: _users[i].passwordHash,
        );
      }
      seen.add(candidate);
    }
  }

  Future<void> _saveUsers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        kAuthUsers, jsonEncode(_users.map((u) => u.toJson()).toList()));
  }

  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_currentUser != null) {
      await prefs.setString(kAuthSessionUser, _currentUser!.email);
    } else {
      await prefs.remove(kAuthSessionUser);
    }
  }

  // ── Sign up ───────────────────────────────────────────────

  /// Returns null on success, or an error message string.
  ///
  /// [name] is accepted as a legacy parameter but is no longer stored as
  /// displayName on new records — username is the sole public identity.
  /// [username] is the required public handle.
  ///
  /// For backwards compatibility with callers that have not yet been updated,
  /// if [username] is omitted the [name] value is sanitised and used as the
  /// username — but the sign-up form should always pass an explicit username.
  Future<String?> signUp({
    required String name,
    required String email,
    required String password,
    String? username,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();

    // ── Resolve & validate username ──────────────────────────
    final String resolvedUsername;
    if (username != null && username.isNotEmpty) {
      resolvedUsername = _normaliseUsername(username);
    } else {
      // Derive from name as a fallback (legacy callers).
      final trimmedName = name.trim();
      resolvedUsername = _normaliseUsername(
        trimmedName
            .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
            .replaceAll(RegExp(r'_+'), '_')
            .replaceAll(RegExp(r'^_|_$'), ''),
      );
    }

    final usernameError = validateUsername(resolvedUsername);
    if (usernameError != null) return usernameError;

    if (_users.any((u) => u.email == trimmedEmail)) {
      return 'An account with that email already exists.';
    }
    if (!isUsernameAvailable(resolvedUsername)) {
      return 'That username is already taken.';
    }

    final record = UserRecord(
      id:           _generateUuid(),
      username:     resolvedUsername,
      displayName:  null, // displayName disabled — username is sole identity
      email:        trimmedEmail,
      passwordHash: _hashPassword(password),
    );
    _users.add(record);
    await _saveUsers();
    _currentUser = record;
    await _saveSession();
    await _reloadStores();
    notifyListeners();
    return null;
  }

  // ── Log in ────────────────────────────────────────────────

  /// Returns null on success, or an error message string.
  ///
  /// [identifier] accepts either a registered email address or a username.
  Future<String?> login({
    required String identifier,
    required String password,
  }) async {
    final trimmed = identifier.trim();
    if (trimmed.isEmpty) return 'Please enter your email or username.';

    UserRecord? user;

    // Determine lookup strategy: if the input contains '@' treat it as email,
    // otherwise attempt username lookup, then fall back to email (edge case
    // where a legacy email has no '@', which is invalid but defensive).
    if (trimmed.contains('@')) {
      final lowerEmail = trimmed.toLowerCase();
      user = _users.where((u) => u.email == lowerEmail).firstOrNull;
    } else {
      user = userForUsername(trimmed);
      // If nothing found by username, still try as email (robustness).
      if (user == null) {
        final lowerEmail = trimmed.toLowerCase();
        user = _users.where((u) => u.email == lowerEmail).firstOrNull;
      }
    }

    if (user == null || user.passwordHash != _hashPassword(password)) {
      return 'Invalid email/username or password.';
    }
    _currentUser = user;
    await _saveSession();
    await _reloadStores();
    notifyListeners();
    return null;
  }

  // ── Log out ───────────────────────────────────────────────

  Future<void> logout() async {
    _currentUser = null;
    await _saveSession();
    await _clearStores();
    notifyListeners();
  }

  // ── Store lifecycle helpers ───────────────────────────────

  Future<void> _reloadStores() async {
    if (_onLogin != null) await _onLogin!();
  }

  Future<void> _clearStores() async {
    if (_onLogout != null) await _onLogout!();
  }

  Future<void> Function()? _onLogin;
  Future<void> Function()? _onLogout;

  /// Register lifecycle callbacks from main.dart to avoid circular imports.
  void registerStoreCallbacks({
    required Future<void> Function() onLogin,
    required Future<void> Function() onLogout,
  }) {
    _onLogin  = onLogin;
    _onLogout = onLogout;
  }

  // ── Storage key helpers ───────────────────────────────────
  // These delegate to the StorageKeys file so AuthStore remains
  // the single point-of-entry for callers who don't import StorageKeys.
  // IMPORTANT: all keys are scoped to the stripped UUID (_storagePrefix),
  // never to the username, so renaming a username never orphans stored data.

  String keyTasks()         => kTaskTasks(_storagePrefix);
  String keyEvents()        => kTaskEvents(_storagePrefix);
  String keyNotifications() => kTaskNotifications(_storagePrefix);
  String keySpaceList()     => kSpaceList(_storagePrefix);
  String keyChatCursors()   => kSpaceChatCursors(_storagePrefix);

  /// Generic user-scoped key for one-off preferences.
  /// Prefer the typed helpers above for structured stores.
  String scopedKey(String base) {
    if (_currentUser == null) return 'guest_$base';
    return '${_storagePrefix}_$base';
  }
}