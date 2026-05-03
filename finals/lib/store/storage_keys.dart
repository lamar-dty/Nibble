// ─────────────────────────────────────────────────────────────
// storage_keys.dart
//
// SINGLE SOURCE OF TRUTH for every SharedPreferences key used
// across the app.  All keys are generated through this file so:
//   • No key is ever hardcoded in a store or widget.
//   • User-scoped vs. device-shared semantics are explicit.
//   • A future "wipe user data" feature only needs to enumerate
//     the user-scoped generators here.
//
// Key namespacing convention
// ──────────────────────────
//   Device-shared (intentionally cross-user):
//     <domain>_<resource>
//     e.g. space_global_registry, space_shared_patches_{code}
//
//   User-scoped (never leak between accounts):
//     u_{userId}_{domain}_{resource}
//     e.g. u_abc12345_task_tasks, u_abc12345_space_chat_cursors
//
//   Cross-user inbox (written by sender, read by recipient):
//     inbox_{domain}_{recipientUserId}
//     e.g. inbox_notif_abc12345, inbox_space_abc12345
//
// ─────────────────────────────────────────────────────────────

/// Namespace prefix for a user-scoped key.
/// [userId] must be the stable UUID (dashes stripped).
String _u(String userId) => 'u_${userId}_';

// ═════════════════════════════════════════════════════════════
// AUTH STORE
// ═════════════════════════════════════════════════════════════

/// Global list of registered accounts (JSON array).
/// Intentionally device-scoped — all accounts on this device
/// need to be visible at login time regardless of who is logged in.
const kAuthUsers = 'auth_users';

/// Email of the last logged-in user (session cookie).
const kAuthSessionUser = 'auth_session_user';

// ═════════════════════════════════════════════════════════════
// TASK STORE  (user-scoped)
// ═════════════════════════════════════════════════════════════

String kTaskTasks(String userId)         => '${_u(userId)}task_tasks';
String kTaskEvents(String userId)        => '${_u(userId)}task_events';
String kTaskNotifications(String userId) => '${_u(userId)}task_notifications';

// ═════════════════════════════════════════════════════════════
// SPACE STORE
// ═════════════════════════════════════════════════════════════

/// Per-user list of spaces the account has joined or created.
String kSpaceList(String userId) => '${_u(userId)}space_list';

/// Device-global registry: inviteCode → Space JSON.
/// Written only by the creator; readable by anyone on the device.
const kSpaceGlobalRegistry = 'space_global_registry';

/// Device-global shared patches: inviteCode → Space JSON.
/// Any member writes here after a mutation; all members read on sync.
const kSpaceSharedPatches = 'space_shared_patches';

// ═════════════════════════════════════════════════════════════
// SPACE CHAT STORE
// ═════════════════════════════════════════════════════════════

/// Messages for a space — shared across all members of that space.
/// inviteCode is the discriminator so all members read the same log.
String kSpaceChatMessages(String inviteCode) => 'space_chat_msgs_$inviteCode';

/// Per-user read cursors: scoped so each account tracks its own position.
String kSpaceChatCursors(String userId) => '${_u(userId)}space_chat_cursors';

// ═════════════════════════════════════════════════════════════
// CROSS-USER INBOXES  (written by sender, drained by recipient)
// ═════════════════════════════════════════════════════════════

/// Notification inbox for [recipientUserId].
String kInboxNotifications(String recipientUserId) =>
    'inbox_notif_$recipientUserId';

/// Pending space invite inbox for [recipientUserId].
String kInboxSpaceInvites(String recipientUserId) =>
    'inbox_space_$recipientUserId';

/// Space deletion inbox for [recipientUserId].
/// Written by the creator when they delete a space; drained by each member
/// on next screen focus to force-remove the space from their list.
/// Stores a JSON array of invite-code strings.
String kInboxSpaceDeletion(String recipientUserId) =>
    'inbox_space_del_$recipientUserId';

/// Maps userId → name-at-invite-time for each space's pendingMembers.
/// Structure: { inviteCode: { userId: nameAtInviteTime } }
/// Written by the creator on pushPendingInvite; read at accept/decline to
/// find the old pending name even if the invitee renamed in the meantime.
const kSpacePendingMemberIds = 'space_pending_member_ids';