import 'package:flutter/material.dart';
import '../models/app_notification.dart';
import '../store/task_store.dart';
import '../store/space_store.dart';

/// Callback signature that MainScaffold registers so the router can
/// switch tabs without knowing about the scaffold's internals.
typedef TabSwitchCallback = void Function(int tabIndex);

/// Callback signature that SpacesScreenState registers so the router
/// can open a specific space, task, or chat panel by invite code.
typedef OpenSpaceCallback     = void Function(String inviteCode);
typedef OpenSpaceChatCallback = void Function(String inviteCode);
typedef OpenSpaceTaskCallback = void Function(String inviteCode, String taskTitle);

/// ── NotificationRouter ────────────────────────────────────────────────────
///
/// Single responsibility: translate an [AppNotification] tap into the correct
/// in-app navigation action.
///
/// Architecture decisions:
///   • Singleton [ChangeNotifier] so any widget in the tree can listen.
///   • Holds a [pendingNotification] so terminated-app cold-launch taps are
///     queued and replayed once the UI is fully mounted.
///   • All navigation callbacks are registered at mount time and cleared at
///     unmount — no hard references to BuildContexts are stored.
///   • Every route action validates that the target still exists before
///     navigating; shows a graceful snackbar on missing items.
///
class NotificationRouter extends ChangeNotifier {
  NotificationRouter._();
  static final NotificationRouter instance = NotificationRouter._();

  // ── Pending deep-link (cold-start / terminated app) ───────
  /// Set this before runApp() when the app is launched from a push
  /// notification. MainScaffold will consume and clear it after mounting.
  AppNotification? pendingNotification;

  // ── Registered callbacks (set by mounted widgets) ─────────
  TabSwitchCallback?     _onSwitchTab;
  OpenSpaceCallback?     _onOpenSpace;
  OpenSpaceChatCallback? _onOpenSpaceChat;
  OpenSpaceTaskCallback? _onOpenSpaceTask;

  /// MainScaffold calls this in initState / didChangeDependencies.
  void registerTabSwitcher(TabSwitchCallback cb) => _onSwitchTab = cb;

  /// SpacesScreenState calls these in initState.
  void registerSpaceCallbacks({
    required OpenSpaceCallback     onOpenSpace,
    required OpenSpaceChatCallback onOpenSpaceChat,
    required OpenSpaceTaskCallback onOpenSpaceTask,
  }) {
    _onOpenSpace     = onOpenSpace;
    _onOpenSpaceChat = onOpenSpaceChat;
    _onOpenSpaceTask = onOpenSpaceTask;
  }

  /// Clears space callbacks when SpacesScreenState disposes — prevents
  /// stale references after logout / screen removal.
  void unregisterSpaceCallbacks() {
    _onOpenSpace     = null;
    _onOpenSpaceChat = null;
    _onOpenSpaceTask = null;
  }

  void unregisterTabSwitcher() => _onSwitchTab = null;

  // ── Public entry-point ────────────────────────────────────

  /// Call this from any notification tap. Safe to call from any widget.
  /// Validates target existence before navigating; shows a graceful
  /// [SnackBar] when the referenced item no longer exists.
  void route(BuildContext context, AppNotification notification) {
    // Mark as read immediately so UI updates whether routing succeeds or not.
    TaskStore.instance.markNotificationRead(notification.id);

    final type = notification.type;

    // ── Personal task notifications ───────────────────────
    if (_isPersonalTask(type)) {
      _routePersonalTask(context, notification);
      return;
    }

    // ── Personal event notifications ──────────────────────
    if (_isPersonalEvent(type)) {
      _routePersonalEvent(context, notification);
      return;
    }

    // ── Space notifications ───────────────────────────────
    if (notification.isSpaceNotification) {
      _routeSpace(context, notification);
      return;
    }

    // Fallback — should never reach here if all types are handled above.
    _showFallbackSnackBar(context, 'Could not open notification.');
  }

  /// Consume the pending cold-start notification.
  /// Called by MainScaffold.initState after the widget tree is ready.
  void consumePending(BuildContext context) {
    final pending = pendingNotification;
    if (pending == null) return;
    pendingNotification = null;
    // Delay one frame so all callbacks are registered.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) route(context, pending);
    });
  }

  // ── Personal task routing ─────────────────────────────────

  void _routePersonalTask(BuildContext context, AppNotification n) {
    final tasks = TaskStore.instance.tasks;
    final task  = tasks.where((t) => t.id == n.sourceId).firstOrNull;

    if (task == null) {
      _showMissingSnackBar(context, 'task');
      return;
    }

    // Switch to Home tab (index 0) then open task detail sheet.
    _switchTab(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      // Dispatch event so HomeScreen/CalendarScreen can highlight the task.
      // The HomeScreen listens to TaskStore; passing the task ID via the
      // router is enough for it to open the detail sheet programmatically.
      TaskStore.instance.requestOpenTask(task.id);
    });
  }

  // ── Personal event routing ────────────────────────────────

  void _routePersonalEvent(BuildContext context, AppNotification n) {
    final events = TaskStore.instance.events;
    final event  = events.where((e) => e.id == n.sourceId).firstOrNull;

    if (event == null) {
      _showMissingSnackBar(context, 'event');
      return;
    }

    // Switch to Calendar tab (index 1) then open event detail.
    _switchTab(1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      TaskStore.instance.requestOpenEvent(event.id);
    });
  }

  // ── Space routing ─────────────────────────────────────────

  void _routeSpace(BuildContext context, AppNotification n) {
    final inviteCode = n.spaceInviteCode;
    if (inviteCode == null || inviteCode.isEmpty) {
      _showFallbackSnackBar(context, 'Could not open notification.');
      return;
    }
    final spaces     = SpaceStore.instance.spaces;
    final space      = spaces.where((s) => s.inviteCode == inviteCode).firstOrNull;

    if (space == null) {
      // Space deleted or user was removed.
      _showMissingSnackBar(context, 'space');
      return;
    }

    // Always switch to Spaces tab first.
    _switchTab(2);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;

      if (n.isSpaceChatNotification) {
        // Open the space chat panel directly.
        _openSpaceChatSafe(context, inviteCode);
        return;
      }

      if (n.isSpaceTaskNotification) {
        final taskTitle = n.secondaryId;
        if (taskTitle != null && taskTitle.isNotEmpty) {
          _openSpaceTaskSafe(context, inviteCode, taskTitle);
        } else {
          // secondaryId absent (old notification) — fall back to space overview.
          _openSpaceSafe(context, inviteCode);
        }
        return;
      }

      // Default: open space overview (created, joined, member events, deleted notice, etc.)
      _openSpaceSafe(context, inviteCode);
    });
  }

  // ── Callback guards ───────────────────────────────────────

  void _switchTab(int index) {
    _onSwitchTab?.call(index);
  }

  // Maximum number of deferred frames to wait for SpacesScreen to mount
  // before giving up. Prevents unbounded addPostFrameCallback chains when
  // the screen never registers its callbacks (e.g. unmounted before retrying).
  static const int _kMaxOpenRetries = 5;

  void _openSpaceSafe(BuildContext context, String inviteCode,
      [int retries = 0]) {
    if (_onOpenSpace == null) {
      if (retries >= _kMaxOpenRetries || !context.mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) _openSpaceSafe(context, inviteCode, retries + 1);
      });
      return;
    }
    _onOpenSpace!.call(inviteCode);
  }

  void _openSpaceChatSafe(BuildContext context, String inviteCode,
      [int retries = 0]) {
    if (_onOpenSpaceChat == null) {
      if (retries >= _kMaxOpenRetries || !context.mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          _openSpaceChatSafe(context, inviteCode, retries + 1);
        }
      });
      return;
    }
    _onOpenSpaceChat!.call(inviteCode);
  }

  void _openSpaceTaskSafe(
      BuildContext context, String inviteCode, String taskTitle,
      [int retries = 0]) {
    if (_onOpenSpaceTask == null) {
      if (retries >= _kMaxOpenRetries || !context.mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          _openSpaceTaskSafe(context, inviteCode, taskTitle, retries + 1);
        }
      });
      return;
    }
    _onOpenSpaceTask!.call(inviteCode, taskTitle);
  }

  // ── Type helpers ──────────────────────────────────────────

  bool _isPersonalTask(NotificationType t) {
    switch (t) {
      case NotificationType.taskReminder:
      case NotificationType.taskOverdue:
      case NotificationType.taskDueToday:
      case NotificationType.taskCompleted:
        return true;
      default:
        return false;
    }
  }

  bool _isPersonalEvent(NotificationType t) {
    switch (t) {
      case NotificationType.eventReminder:
      case NotificationType.eventToday:
        return true;
      default:
        return false;
    }
  }

  // ── Snack helpers ─────────────────────────────────────────

  void _showMissingSnackBar(BuildContext context, String itemType) {
    _showSnackBar(
      context,
      'This $itemType no longer exists.',
      icon: Icons.info_outline_rounded,
    );
  }

  void _showFallbackSnackBar(BuildContext context, String message) {
    _showSnackBar(context, message, icon: Icons.warning_amber_rounded);
  }

  void _showSnackBar(BuildContext context, String message,
      {required IconData icon}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1A2A5E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}