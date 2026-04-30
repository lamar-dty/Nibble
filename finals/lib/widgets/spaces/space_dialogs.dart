import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/colors.dart';
import '../../models/space.dart';
import '../../models/app_notification.dart';
import '../../store/space_store.dart';
import '../../store/auth_store.dart';
import '../../store/task_store.dart';
import '../../widgets/spaces/space_detail_sheet.dart'; // for InviteCodeRow

// ─────────────────────────────────────────────────────────────
// Add Member
// ─────────────────────────────────────────────────────────────
void showAddMemberDialog(
  BuildContext context,
  Space space, {
  required VoidCallback onMemberAdded,
}) {
  final ctrl = TextEditingController();
  String? error;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlg) => Dialog(
        backgroundColor: const Color(0xFF1A2D5A),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.person_add_alt_1_rounded,
                    color: space.accentColor, size: 20),
                const SizedBox(width: 10),
                const Text(
                  'Add Member',
                  style: TextStyle(
                    color: kWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ]),

              const SizedBox(height: 16),

              Text(
                'Enter User ID',
                style: TextStyle(
                  color: kWhite.withOpacity(0.5),
                  fontSize: 11,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ask the user to share their #ID from the drawer.',
                style: TextStyle(
                  color: kWhite.withOpacity(0.3),
                  fontSize: 11,
                ),
              ),

              const SizedBox(height: 6),

              TextField(
                controller: ctrl,
                autofocus: false,
                maxLength: 9, // # + 8 hex chars
                inputFormatters: [
                  // Allow only # prefix + hex characters
                  FilteringTextInputFormatter.allow(RegExp(r'[#0-9a-fA-F]')),
                ],
                style: const TextStyle(
                  color: kWhite,
                  fontSize: 14,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: '#a1b2c3d4',
                  counterText: '',
                  hintStyle: TextStyle(
                    color: kWhite.withOpacity(0.25),
                  ),
                  filled: true,
                  fillColor: kWhite.withOpacity(0.06),

                  prefixIcon: Icon(
                    Icons.alternate_email_rounded,
                    color: kWhite.withOpacity(0.35),
                    size: 16,
                  ),

                  errorText: error,

                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),

                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: kWhite.withOpacity(0.1)),
                  ),

                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: kWhite.withOpacity(0.1)),
                  ),

                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: space.accentColor,
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Row(children: [
                Expanded(
                  child: Divider(
                    color: kWhite.withOpacity(0.1),
                    height: 1,
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'or share invite code',
                    style: TextStyle(
                      color: kWhite.withOpacity(0.3),
                      fontSize: 10,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: kWhite.withOpacity(0.1),
                    height: 1,
                  ),
                ),
              ]),

              const SizedBox(height: 12),

              InviteCodeRow(
                space: space,
                setDlg: setDlg,
              ),

              const SizedBox(height: 16),

              Row(children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: kWhite.withOpacity(0.45),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: space.accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      final raw = ctrl.text.trim();
                      if (raw.isEmpty) {
                        setDlg(() => error = 'Please enter a User ID');
                        return;
                      }

                      // Strip leading # then validate it's an 8-char hex ID.
                      final cleaned = raw.startsWith('#') ? raw.substring(1) : raw;
                      final validId = RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(cleaned);
                      if (!validId) {
                        setDlg(() => error = 'Enter a valid User ID');
                        return;
                      }

                      // Resolve the typed ID to a real display name.
                      final resolvedName = AuthStore.instance.nameForId(cleaned);
                      if (resolvedName == null) {
                        setDlg(() => error = 'No user found with that ID');
                        return;
                      }

                      // Don't add yourself or someone already in the space.
                      if (resolvedName == AuthStore.instance.displayName) {
                        setDlg(() => error = "That's you!");
                        return;
                      }
                      if (space.members.contains(resolvedName)) {
                        setDlg(() => error = 'Already a member');
                        return;
                      }

                      Navigator.pop(ctx);

                      // Add the resolved display name to the member list.
                      space.members.add(resolvedName);
                      SpaceStore.instance.save();

                      final invitedId = AuthStore.instance.userIdForName(resolvedName);
                      if (invitedId != null) {
                        // Push the space itself into the invitee's pending inbox
                        // so it appears automatically when they open the app.
                        await SpaceStore.instance.pushPendingInvite(invitedId, space);

                        // Also push a notification so they know they were added.
                        final notif = AppNotification(
                          id: 'space_invite_${space.inviteCode}_$resolvedName',
                          type: NotificationType.spaceMemberJoined,
                          sourceId: space.inviteCode,
                          spaceInviteCode: space.inviteCode,
                          spaceAccentColor: space.accentColor,
                          title: space.name,
                          subtitle: 'You were added to a space 🎉',
                          detail: '${AuthStore.instance.displayName} added you to "${space.name}".',
                        );
                        await TaskStore.instance.pushInviteNotification(invitedId, notif);
                      }

                      onMemberAdded();
                    },
                    child: const Text('Add'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// Add Task
// ─────────────────────────────────────────────────────────────
void showAddTaskDialog(
  BuildContext context,
  Space space, {
  required void Function(String title, String note) onAdd,
}) {
  final titleCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  String? error;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlg) => Dialog(
        backgroundColor: const Color(0xFF1A2D5A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.checklist_rounded, color: space.accentColor, size: 20),
                const SizedBox(width: 10),
                const Text('New Task',
                    style: TextStyle(
                        color: kWhite, fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 16),
              Text('Task Title',
                  style: TextStyle(
                      color: kWhite.withOpacity(0.5),
                      fontSize: 11,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              TextField(
                controller: titleCtrl,
                autofocus: false,
                style: const TextStyle(color: kWhite, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. Research references',
                  hintStyle: TextStyle(color: kWhite.withOpacity(0.25)),
                  filled: true,
                  fillColor: kWhite.withOpacity(0.06),
                  errorText: error,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: kWhite.withOpacity(0.1))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: kWhite.withOpacity(0.1))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: space.accentColor, width: 1.5)),
                ),
              ),
              const SizedBox(height: 12),
              Text('Note (Optional)',
                  style: TextStyle(
                      color: kWhite.withOpacity(0.5),
                      fontSize: 11,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              TextField(
                controller: noteCtrl,
                maxLines: 2,
                style: const TextStyle(color: kWhite, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Add a short note…',
                  hintStyle: TextStyle(color: kWhite.withOpacity(0.25)),
                  filled: true,
                  fillColor: kWhite.withOpacity(0.06),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: kWhite.withOpacity(0.1))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: kWhite.withOpacity(0.1))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: space.accentColor, width: 1.5)),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel',
                        style: TextStyle(color: kWhite.withOpacity(0.45))),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: space.accentColor,
                      foregroundColor: kWhite,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      final title = titleCtrl.text.trim();
                      if (title.isEmpty) {
                        setDlg(() => error = 'Title is required');
                        return;
                      }
                      onAdd(title, noteCtrl.text.trim());
                      Navigator.pop(ctx);
                    },
                    child: const Text('Add Task'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// Confirm Delete Space
// ─────────────────────────────────────────────────────────────
void showConfirmDeleteSpace(
  BuildContext context,
  Space space, {
  required VoidCallback onConfirm,
}) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: const Color(0xFF1A2D5A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.delete_rounded, color: Color(0xFFE87070), size: 36),
            const SizedBox(height: 12),
            const Text('Delete Space',
                style: TextStyle(
                    color: kWhite, fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to delete "${space.name}"? This cannot be undone.',
              textAlign: TextAlign.center,
              style: TextStyle(color: kWhite.withOpacity(0.6), fontSize: 13),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel',
                      style: TextStyle(color: kWhite.withOpacity(0.45))),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE87070),
                    foregroundColor: kWhite,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    onConfirm();
                  },
                  child: const Text('Delete'),
                ),
              ),
            ]),
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// Confirm Leave Space
// ─────────────────────────────────────────────────────────────
void showConfirmLeaveSpace(
  BuildContext context,
  Space space, {
  required VoidCallback onConfirm,
}) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: const Color(0xFF1A2D5A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.exit_to_app_rounded,
                color: Color(0xFFE87070), size: 36),
            const SizedBox(height: 12),
            const Text('Leave Space',
                style: TextStyle(
                    color: kWhite, fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to leave "${space.name}"?',
              textAlign: TextAlign.center,
              style: TextStyle(color: kWhite.withOpacity(0.6), fontSize: 13),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel',
                      style: TextStyle(color: kWhite.withOpacity(0.45))),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE87070),
                    foregroundColor: kWhite,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    onConfirm();
                  },
                  child: const Text('Leave'),
                ),
              ),
            ]),
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// Confirm Kick Member
// ─────────────────────────────────────────────────────────────
void showConfirmKickMember(
  BuildContext context,
  Space space,
  String member, {
  required VoidCallback onConfirm,
}) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: const Color(0xFF1A2D5A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_remove_rounded,
                color: Color(0xFFE87070), size: 36),
            const SizedBox(height: 12),
            const Text('Remove Member',
                style: TextStyle(
                    color: kWhite, fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Remove "$member" from this space?',
              textAlign: TextAlign.center,
              style: TextStyle(color: kWhite.withOpacity(0.6), fontSize: 13),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel',
                      style: TextStyle(color: kWhite.withOpacity(0.45))),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE87070),
                    foregroundColor: kWhite,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    onConfirm();
                  },
                  child: const Text('Remove'),
                ),
              ),
            ]),
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// Join Space
// ─────────────────────────────────────────────────────────────
void showJoinSpaceDialog(
  BuildContext context, {
  required bool Function(String code) isAlreadyJoined,
  required Future<String?> Function(String code) onJoin,
}) {
  final ctrl = TextEditingController();
  String? error;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlg) => Dialog(
        backgroundColor: const Color(0xFF1A2D5A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: kTeal.withOpacity(0.14),
                    shape: BoxShape.circle,
                    border: Border.all(color: kTeal.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.link_rounded, color: kTeal, size: 18),
                ),
                const SizedBox(width: 12),
                const Text('Join a Space',
                    style: TextStyle(
                        color: kWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 6),
              Text(
                'Enter the 8-character invite code shared by the space creator.',
                style:
                    TextStyle(color: kWhite.withOpacity(0.45), fontSize: 12),
              ),
              const SizedBox(height: 16),
              Text('Invite Code',
                  style: TextStyle(
                      color: kWhite.withOpacity(0.5),
                      fontSize: 11,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              TextField(
                controller: ctrl,
                autofocus: false,
                textCapitalization: TextCapitalization.characters,
                maxLength: 8,
                style: const TextStyle(
                  color: kWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
                decoration: InputDecoration(
                  hintText: 'XXXXXXXX',
                  hintStyle: TextStyle(
                      color: kWhite.withOpacity(0.2),
                      fontSize: 18,
                      letterSpacing: 4,
                      fontWeight: FontWeight.bold),
                  filled: true,
                  fillColor: kWhite.withOpacity(0.06),
                  counterText: '',
                  errorText: error,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: kWhite.withOpacity(0.1))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: kWhite.withOpacity(0.1))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: kTeal, width: 1.5)),
                  errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Color(0xFFE87070))),
                  focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFFE87070), width: 1.5)),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel',
                        style: TextStyle(color: kWhite.withOpacity(0.45))),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kTeal,
                      foregroundColor: kNavyDark,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final code = ctrl.text.trim().toUpperCase();
                      if (code.isEmpty) {
                        setDlg(() => error = 'Enter an invite code');
                        return;
                      }
                      if (code.length < 8) {
                        setDlg(() => error = 'Code must be 8 characters');
                        return;
                      }
                      if (isAlreadyJoined(code)) {
                        setDlg(() => error = "You're already in this space");
                        return;
                      }
                      final joinError = await onJoin(code);
                      if (joinError != null) {
                        setDlg(() => error = joinError);
                        return;
                      }
                      Navigator.pop(ctx);
                    },
                    child: const Text('Join',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    ),
  );
}

void showConfirmDeleteTask(
  BuildContext context,
  SpaceTask task, {
  required VoidCallback onConfirm,
}) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: const Color(0xFF1A2D5A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFE87070),
              size: 36,
            ),

            const SizedBox(height: 12),

            const Text(
              'Delete Task',
              style: TextStyle(
                color: kWhite,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Are you sure you want to delete "${task.title}"?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kWhite.withOpacity(0.6),
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: kWhite.withOpacity(0.45),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE87070),
                      foregroundColor: kWhite,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      onConfirm();
                    },
                    child: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}