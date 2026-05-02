import 'package:flutter/material.dart';
import 'task.dart';
import 'event.dart';

enum NotificationType {
  // ── Task ──────────────────────────────
  taskReminder,   // created / advance reminder
  taskOverdue,    // past due, not completed
  taskDueToday,   // due today
  taskCompleted,  // marked complete

  // ── Event ─────────────────────────────
  eventReminder,  // created / advance reminder
  eventToday,     // happening today

  // ── Space ─────────────────────────────
  spaceCreated,       // user created a new space
  spaceJoined,        // user joined a space
  spaceMemberRemoved, // a member was kicked
  spaceMemberJoined,  // a new member joined the space
  spaceChatMessage,   // new chat message from another member
  spaceTaskAdded,     // a new task was added to a space
  spaceTaskAssigned,  // current user was assigned to a task
  spaceTaskStatus,    // a task's status changed
  spaceTaskCompleted, // a task was marked completed
  spaceTaskDueSoon,   // a space task is due tomorrow
  spaceTaskOverdue,   // a space task is overdue
  spaceDeleted,       // the space was deleted by its creator
  spaceInviteReceived, // user B received an invite to join a space
  spaceInviteDeclined, // user B declined — notifies user A

  // ── Wallet ────────────────────────────
  walletExpenseAdded,        // new expense logged
  walletExpenseDueSoon,      // unpaid expense due tomorrow
  walletExpenseOverdue,      // unpaid expense passed due date
  walletExpensePaid,         // expense manually marked paid
  walletLinkedExpensePaid,   // expense auto-paid via linked task completion
  walletBudgetWarning,       // monthly spend crossed 80 % of budget
  walletBudgetExceeded,      // monthly spend crossed 100 % of budget
  walletDailyWarning,        // today's spend crossed 80 % of daily allowance
  walletDailyExceeded,       // today's spend exceeded daily allowance

  // ── Class Alerts ──────────────────────────────
  classReminder,             // upcoming class about to start
}

class AppNotification {
  final String id;
  final NotificationType type;

  /// Primary source ID:
  ///   - personal task/event → the task.id / event.id
  ///   - space notification  → the space.inviteCode
  final String sourceId;

  /// Secondary deep-link ID — optional, type-specific:
  ///   - spaceTaskAdded / spaceTaskAssigned / spaceTaskStatus /
  ///     spaceTaskCompleted / spaceTaskDueSoon / spaceTaskOverdue
  ///       → SpaceTask.title (used to locate the task inside the space)
  ///   - spaceChatMessage → message timestamp string (for scroll-to)
  ///   Future: commentId, mentionId, etc.
  ///
  /// When null the router falls back to opening the parent context
  /// (the space overview or personal task list) rather than crashing.
  final String? secondaryId;

  final String title;
  final String subtitle;
  final String detail;
  final DateTime createdAt;

  // Task-specific (null for event / space notifications)
  final TaskCategory? taskCategory;
  final TaskPriority? priority;

  // Event-specific (null for task / space notifications)
  final EventCategory? eventCategory;

  // Space-specific (null for task / event notifications)
  /// The invite code of the related space — used for routing / dedup.
  final String? spaceInviteCode;

  /// Accent colour of the space, used for icon tinting.
  final Color? spaceAccentColor;

  bool isRead;

  AppNotification({
    required this.id,
    required this.type,
    required this.sourceId,
    required this.title,
    required this.subtitle,
    required this.detail,
    this.secondaryId,
    this.taskCategory,
    this.priority,
    this.eventCategory,
    this.spaceInviteCode,
    this.spaceAccentColor,
    DateTime? createdAt,
    this.isRead = false,
  }) : createdAt = createdAt ?? DateTime.now();

  // ── Icon ──────────────────────────────────────────────────
  IconData get icon {
    switch (type) {
      // Task
      case NotificationType.taskReminder:  return Icons.assignment_outlined;
      case NotificationType.taskOverdue:   return Icons.warning_amber_rounded;
      case NotificationType.taskDueToday:  return Icons.today_rounded;
      case NotificationType.taskCompleted: return Icons.check_circle_rounded;
      // Event
      case NotificationType.eventReminder: return Icons.event_outlined;
      case NotificationType.eventToday:    return Icons.event_available_rounded;
      // Space
      case NotificationType.spaceCreated:       return Icons.rocket_launch_rounded;
      case NotificationType.spaceJoined:        return Icons.login_rounded;
      case NotificationType.spaceMemberRemoved: return Icons.person_remove_rounded;
      case NotificationType.spaceMemberJoined:  return Icons.person_add_rounded;
      case NotificationType.spaceChatMessage:   return Icons.chat_rounded;
      case NotificationType.spaceTaskAdded:     return Icons.playlist_add_rounded;
      case NotificationType.spaceTaskAssigned:  return Icons.person_pin_rounded;
      case NotificationType.spaceTaskStatus:    return Icons.sync_rounded;
      case NotificationType.spaceTaskCompleted: return Icons.task_alt_rounded;
      case NotificationType.spaceTaskDueSoon:   return Icons.schedule_rounded;
      case NotificationType.spaceTaskOverdue:   return Icons.warning_amber_rounded;
      case NotificationType.spaceDeleted:       return Icons.delete_forever_rounded;
      case NotificationType.spaceInviteReceived: return Icons.mail_rounded;
      case NotificationType.spaceInviteDeclined: return Icons.person_remove_rounded;
      // Wallet
      case NotificationType.walletExpenseAdded:      return Icons.receipt_long_rounded;
      case NotificationType.walletExpenseDueSoon:    return Icons.schedule_rounded;
      case NotificationType.walletExpenseOverdue:    return Icons.warning_amber_rounded;
      case NotificationType.walletExpensePaid:       return Icons.check_circle_rounded;
      case NotificationType.walletLinkedExpensePaid: return Icons.task_alt_rounded;
      case NotificationType.walletBudgetWarning:     return Icons.account_balance_wallet_rounded;
      case NotificationType.walletBudgetExceeded:    return Icons.account_balance_wallet_rounded;
      case NotificationType.walletDailyWarning:      return Icons.credit_card_rounded;
      case NotificationType.walletDailyExceeded:     return Icons.credit_card_rounded;
      // Class
      case NotificationType.classReminder:           return Icons.school_rounded;
    }
  }

  // ── Colour helpers ────────────────────────────────────────
  Color get iconColor {
    if (spaceAccentColor != null) return spaceAccentColor!;
    if (eventCategory != null) return eventCategory!.color;
    switch (type) {
      case NotificationType.classReminder:
        return const Color(0xFF90D0CB); // kTeal
      case NotificationType.walletExpenseAdded:
      case NotificationType.walletExpenseDueSoon:
      case NotificationType.walletExpensePaid:
      case NotificationType.walletLinkedExpensePaid:
        return const Color(0xFF3BBFA3); // teal
      case NotificationType.walletExpenseOverdue:
      case NotificationType.walletBudgetExceeded:
      case NotificationType.walletDailyExceeded:
        return const Color(0xFFE87070); // red
      case NotificationType.walletBudgetWarning:
      case NotificationType.walletDailyWarning:
        return const Color(0xFFE8A870); // amber
      default:
        return taskCategory?.color ?? const Color(0xFF9B88E8);
    }
  }

  Color get iconBgColor => iconColor.withOpacity(0.15);

  // ── Convenience ───────────────────────────────────────────
  /// True only when a non-empty invite code is present — empty string is
  /// treated as absent so routing never attempts to open a ghost space.
  bool get isSpaceNotification =>
      spaceInviteCode != null && spaceInviteCode!.isNotEmpty;

  /// Returns true for notification types that should route to a specific
  /// space task rather than just the space overview.
  bool get isSpaceTaskNotification {
    switch (type) {
      case NotificationType.spaceTaskAdded:
      case NotificationType.spaceTaskAssigned:
      case NotificationType.spaceTaskStatus:
      case NotificationType.spaceTaskCompleted:
      case NotificationType.spaceTaskDueSoon:
      case NotificationType.spaceTaskOverdue:
        return true;
      default:
        return false;
    }
  }

  /// Returns true for types that should open the space chat directly.
  bool get isSpaceChatNotification =>
      type == NotificationType.spaceChatMessage;

  /// Returns true when this notification carries a pending space invite
  /// that the recipient can accept or decline.
  bool get isSpaceInviteNotification =>
      type == NotificationType.spaceInviteReceived;

  bool get isClassNotification =>
      type == NotificationType.classReminder;

  // ── Serialisation ─────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.index,
        'sourceId': sourceId,
        'secondaryId': secondaryId,
        'title': title,
        'subtitle': subtitle,
        'detail': detail,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'isRead': isRead,
        'taskCategory': taskCategory?.index,
        'priority': priority?.index,
        'eventCategory': eventCategory?.index,
        'spaceInviteCode': spaceInviteCode,
        'spaceAccentColor': spaceAccentColor?.value,
      };

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    // ── type — guard against out-of-range index from future enum versions ──
    final typeIndex = (j['type'] as num?)?.toInt() ?? 0;
    final type = (typeIndex >= 0 && typeIndex < NotificationType.values.length)
        ? NotificationType.values[typeIndex]
        : NotificationType.taskReminder; // safe fallback

    // ── taskCategory — guard against out-of-range or missing index ─────────
    final taskCatRaw = j['taskCategory'];
    final taskCatIndex = taskCatRaw != null ? (taskCatRaw as num).toInt() : -1;
    final taskCategory = (taskCatIndex >= 0 &&
            taskCatIndex < TaskCategory.values.length)
        ? TaskCategory.values[taskCatIndex]
        : null;

    // ── priority — guard against out-of-range or missing index ─────────────
    final priorityRaw = j['priority'];
    final priorityIndex =
        priorityRaw != null ? (priorityRaw as num).toInt() : -1;
    final priority =
        (priorityIndex >= 0 && priorityIndex < TaskPriority.values.length)
            ? TaskPriority.values[priorityIndex]
            : null;

    // ── eventCategory — guard against out-of-range or missing index ────────
    final evtCatRaw = j['eventCategory'];
    final evtCatIndex =
        evtCatRaw != null ? (evtCatRaw as num).toInt() : -1;
    final eventCategory = (evtCatIndex >= 0 &&
            evtCatIndex < EventCategory.values.length)
        ? EventCategory.values[evtCatIndex]
        : null;

    // ── spaceAccentColor — guard against wrong runtime type ─────────────────
    final colorRaw = j['spaceAccentColor'];
    final spaceAccentColor =
        colorRaw != null ? Color((colorRaw as num).toInt()) : null;

    // ── createdAt — use num.toInt() to tolerate JSON double coercion ────────
    final createdAt = DateTime.fromMillisecondsSinceEpoch(
        (j['createdAt'] as num).toInt());

    // ── isRead — tolerate legacy int (0/1) encoding ─────────────────────────
    final isReadRaw = j['isRead'];
    final isRead = isReadRaw is bool
        ? isReadRaw
        : (isReadRaw is num ? isReadRaw != 0 : false);

    return AppNotification(
      id: (j['id'] as String?) ?? '',
      type: type,
      sourceId: (j['sourceId'] as String?) ?? '',
      secondaryId: j['secondaryId'] as String?,
      title: (j['title'] as String?) ?? '',
      subtitle: (j['subtitle'] as String?) ?? '',
      detail: (j['detail'] as String?) ?? '',
      createdAt: createdAt,
      isRead: isRead,
      taskCategory: taskCategory,
      priority: priority,
      eventCategory: eventCategory,
      spaceInviteCode: j['spaceInviteCode'] as String?,
      spaceAccentColor: spaceAccentColor,
    );
  }
}