import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../store/task_store.dart';
import '../models/app_notification.dart';
import '../widgets/notification_item.dart';
import '../store/space_store.dart';
import '../store/auth_store.dart';
import '../store/space_chat_store.dart';
import '../services/notification_router.dart';
import '../store/wallet_store.dart';

class HomeScreen extends StatefulWidget {
  final ValueNotifier<int> tabNotifier;

  const HomeScreen({super.key, required this.tabNotifier});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const double _snapPeek = 0.20;
  static const double _snapHalf = 0.50;
  static const double _snapFull = 1.0;

  late DraggableScrollableController _sheetController;

  // Holds the ScrollController provided by DraggableScrollableSheet's builder.
  // Updated every time the builder runs; used to reset scroll position to top
  // before collapsing the sheet on tab-away so the drag handle stays visible.
  ScrollController? _sheetScrollController;

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
    widget.tabNotifier.addListener(_onTabChanged);
    // Drain the shared inbox so cross-user notifications (including
    // spaceDeleted alerts) appear immediately on the home tab.
    // Also drain deletion notices so the Spaces tab stays consistent even
    // if Home is the first tab the user opens after a space is deleted.
    TaskStore.instance.drainSharedInbox();
    SpaceStore.instance.drainDeletionNotices().then((removedCodes) {
      for (final code in removedCodes) {
        SpaceChatStore.instance.deleteMessagesFor(code);
        TaskStore.instance.clearSpaceNotifications(code);
      }
      if (mounted && removedCodes.isNotEmpty) setState(() {});
    });
  }

  // Collapse sheet when navigating away from this tab (index 0).
  // Resets the internal scroll position to top first so the drag handle is
  // always visible after the sheet collapses.
  void _onTabChanged() {
    if (!mounted) return;
    // Re-drain inbox whenever the user navigates TO the home tab (index 0)
    // so invite notifications pushed while on another tab appear immediately.
    if (widget.tabNotifier.value == 0) {
      TaskStore.instance.drainSharedInbox();
      return;
    }
    if (!_sheetController.isAttached) return;

    // Reset the notification list scroll to top before collapsing.
    // Guards: controller must have clients and position pixels must be above
    // minScrollExtent to avoid jumpTo exceptions on already-topped lists.
    final sc = _sheetScrollController;
    if (sc != null && sc.hasClients) {
      try {
        final pos = sc.position;
        if (pos.pixels > pos.minScrollExtent) {
          sc.jumpTo(pos.minScrollExtent);
        }
      } catch (_) {
        // Controller detached or position unavailable — safe to ignore.
      }
    }

    _sheetController.animateTo(
      _snapPeek,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    widget.tabNotifier.removeListener(_onTabChanged);
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        TaskStore.instance,
        SpaceStore.instance,
        WalletStore.instance,
      ]),
      builder: (context, _) {
        final store  = TaskStore.instance;
        final pct    = store.completionPercent;
        final total  = store.total;
        final spaces = SpaceStore.instance.spaces;
        final wallet = WalletStore.instance;

        // ── Wallet Balance ────────────────────────────────────
        final dailyRemaining   = wallet.dailyRemaining;
        final budgetFraction   = wallet.budgetUsedFraction;
        final dailySet         = wallet.dailyAllowance > 0;

        // ── Savings Increase ──────────────────────────────────
        // Compare latest two monthly savings snapshots for a delta %.
        // Falls back to total savings if history is too short.
        final savHist = wallet.savingsHistory;
        String savingsValue;
        String savingsSubtitle;
        if (savHist.length >= 2) {
          final prev = savHist[savHist.length - 2].value;
          final curr = savHist[savHist.length - 1].value;
          if (prev > 0) {
            final delta = ((curr - prev) / prev * 100);
            savingsValue    = '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}%';
            savingsSubtitle = 'vs last month';
          } else {
            savingsValue    = '₱${curr.toStringAsFixed(0)}';
            savingsSubtitle = 'Total saved';
          }
        } else {
          final total = wallet.savings;
          savingsValue    = '₱${total.toStringAsFixed(0)}';
          savingsSubtitle = total > 0 ? 'Total saved' : 'No savings yet';
        }

        // username is the canonical public identity — never fall back to displayName.
        final _username = AuthStore.instance.username;
        final greeting = _username.isNotEmpty
            ? 'Welcome back, $_username!'
            : 'Welcome back!';

        return Stack(
          children: [
            // ── BACKGROUND — header + stat cards ─────────────
            Positioned.fill(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            greeting,
                            style: const TextStyle(
                              color: kWhite,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Here's your overview for today",
                            style: TextStyle(color: kSubtitle, fontSize: 14),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _HomeStatCard(
                                icon: Icons.check_circle_outline_rounded,
                                iconColor: const Color(0xFFE87070),
                                title: 'Completed Tasks',
                                value: total == 0
                                    ? '0%'
                                    : '${(pct * 100).round()}%',
                                subtitle: total == 0
                                    ? 'No tasks yet'
                                    : '${store.completed} of $total done',
                              ),
                              const SizedBox(width: 10),
                              _HomeStatCard(
                                icon: Icons.account_balance_wallet_rounded,
                                iconColor: const Color(0xFF4A90D9),
                                title: 'Wallet Balance',
                                value: dailySet
                                    ? (dailyRemaining >= 0
                                        ? '₱${dailyRemaining.toStringAsFixed(2)}'
                                        : '-₱${(-dailyRemaining).toStringAsFixed(2)}')
                                    : '—',
                                subtitle: dailySet
                                    ? (dailyRemaining >= 0 ? 'left today' : 'over today')
                                    : 'No allowance set',
                                subtitleColor: dailySet && dailyRemaining < 0
                                    ? const Color(0xFFE87070)
                                    : null,
                                showProgress: dailySet && wallet.monthlyBudget > 0,
                                progressValue: budgetFraction,
                                progressColor: const Color(0xFF9B88E8),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _HomeStatCard(
                                icon: Icons.group_rounded,
                                iconColor: const Color(0xFF7070D8),
                                title: 'Spaces',
                                value: '${spaces.length}',
                                subtitle: spaces.isEmpty
                                    ? 'No spaces yet'
                                    : '${spaces.where((s) => !s.isCompleted).length} active now',
                              ),
                              const SizedBox(width: 10),
                              _HomeStatCard(
                                icon: savingsValue.startsWith('-')
                                    ? Icons.trending_down_rounded
                                    : Icons.trending_up_rounded,
                                iconColor: const Color(0xFF3BBFA3),
                                title: 'Savings',
                                value: savingsValue,
                                subtitle: savingsSubtitle,
                                subtitleColor: const Color(0xFF3BBFA3),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── DRAGGABLE NOTIFICATION SHEET ─────────────────
            DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: _snapPeek,
              minChildSize: _snapPeek,
              maxChildSize: _snapFull,
              snap: true,
              snapSizes: const [_snapPeek, _snapHalf, _snapFull],
              builder: (context, scrollController) {
                // Cache the scroll controller so _onTabChanged can reset it.
                // This controller is now passed directly to the notification
                // ListView — only the list scrolls, not the entire sheet.
                _sheetScrollController = scrollController;
                return DecoratedBox(
                  decoration: const BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 16,
                        offset: Offset(0, -4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                    child: ColoredBox(
                      color: kWhite,
                      child: _NotificationSheet(
                        notifications: store.notifications,
                        onClearAll: () => TaskStore.instance.clearNotifications(),
                        scrollController: scrollController,
                      ),
                    ),
                  ),
                );
              },
            ),
            // ── NAV BAR TOUCH BLOCKER ─────────────────────────
            // The DraggableScrollableSheet extends behind the BottomAppBar.
            // This invisible AbsorbPointer sits at the very bottom and
            // swallows any touches in the nav bar zone so they never reach
            // notification items underneath.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 56,
              child: AbsorbPointer(absorbing: true),
            ),
          ],
        );
      },
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────
class _HomeStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String subtitle;
  final Color? subtitleColor;
  final bool showProgress;
  final double progressValue;
  final Color? progressColor;

  const _HomeStatCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.subtitle,
    this.subtitleColor,
    this.showProgress = false,
    this.progressValue = 0,
    this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kNavyMid,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kWhite.withOpacity(0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 14),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: kWhite.withOpacity(0.65),
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: kWhite,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            if (showProgress) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progressValue,
                  minHeight: 3,
                  backgroundColor: kWhite.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(
                      progressColor ?? iconColor),
                ),
              ),
              const SizedBox(height: 3),
            ],
            Text(
              subtitle,
              style: TextStyle(
                color: subtitleColor ?? kWhite.withOpacity(0.45),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sort options ──────────────────────────────────────────────
enum _SortBy { newest, oldest, type }

// ── Notification sheet ────────────────────────────────────────
class _NotificationSheet extends StatefulWidget {
  final List<AppNotification> notifications;
  final VoidCallback onClearAll;
  // The DraggableScrollableSheet's scroll controller — drives only the
  // notification list so the drag handle and header remain fixed.
  final ScrollController scrollController;

  const _NotificationSheet({
    required this.notifications,
    required this.onClearAll,
    required this.scrollController,
  });

  @override
  State<_NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<_NotificationSheet> {
  _SortBy _sortBy = _SortBy.newest;

  List<AppNotification> get _sorted {
    final list = List<AppNotification>.from(widget.notifications);
    switch (_sortBy) {
      case _SortBy.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case _SortBy.oldest:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case _SortBy.type:
        int rank(NotificationType t) {
          switch (t) {
            // Task
            case NotificationType.taskOverdue:        return 0;
            case NotificationType.taskDueToday:       return 1;
            case NotificationType.taskReminder:       return 2;
            case NotificationType.taskCompleted:      return 3;
            // Event
            case NotificationType.eventToday:         return 4;
            case NotificationType.eventReminder:      return 5;
            // Space - urgent
            case NotificationType.spaceTaskOverdue:   return 6;
            case NotificationType.spaceTaskDueSoon:   return 7;
            case NotificationType.spaceTaskAssigned:  return 8;
            // Space - activity
            case NotificationType.spaceChatMessage:   return 9;
            case NotificationType.spaceTaskStatus:    return 10;
            case NotificationType.spaceTaskCompleted: return 11;
            case NotificationType.spaceTaskAdded:     return 12;
            // Space - membership
            case NotificationType.spaceMemberRemoved: return 13;
            case NotificationType.spaceMemberJoined:  return 14;
            case NotificationType.spaceJoined:        return 15;
            case NotificationType.spaceCreated:       return 16;
            // Space - lifecycle
            case NotificationType.spaceDeleted:       return 17;
            case NotificationType.spaceInviteReceived: return 18;
            case NotificationType.spaceInviteDeclined: return 19;
            // Wallet
            case NotificationType.walletExpenseOverdue:    return 20;
            case NotificationType.walletExpenseDueSoon:    return 21;
            case NotificationType.walletBudgetExceeded:    return 22;
            case NotificationType.walletDailyExceeded:     return 23;
            case NotificationType.walletBudgetWarning:     return 24;
            case NotificationType.walletDailyWarning:      return 25;
            case NotificationType.walletExpenseAdded:      return 26;
            case NotificationType.walletExpensePaid:       return 27;
            case NotificationType.walletLinkedExpensePaid:         return 28;
            case NotificationType.walletLinkedEventExpenseRemoved: return 29;
            // Class
            case NotificationType.classReminder:                   return 30;
          }
        }
        list.sort((a, b) => rank(a.type).compareTo(rank(b.type)));
        break;
    }
    return list;
  }

  String get _sortLabel {
    switch (_sortBy) {
      case _SortBy.newest: return 'Newest';
      case _SortBy.oldest: return 'Oldest';
      case _SortBy.type:   return 'Type';
    }
  }

  int get _unreadCount =>
      widget.notifications.where((n) => !n.isRead).length;

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SortSheet(
        current: _sortBy,
        onSelected: (v) {
          setState(() => _sortBy = v);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _confirmClearAll() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ClearConfirmSheet(onConfirm: widget.onClearAll),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifications = widget.notifications;
    final sorted = _sorted;
    final unread = _unreadCount;

    // ── Architecture: CustomScrollView at the root ────────────────────────
    // The DraggableScrollableSheet requires its scrollController to be
    // attached to a scrollable that is the direct child of its builder.
    // Using CustomScrollView satisfies this: dragging anywhere on the sheet
    // — header or list — travels through a single scroll controller so the
    // sheet drag, header interaction, and list scroll all work correctly.
    //
    // The header is a SliverPersistentHeader with pinned: true so it stays
    // visible at the top of the sheet regardless of list scroll position.
    // The notification items live in a SliverList (or SliverFillRemaining
    // for the empty state).
    return CustomScrollView(
      controller: widget.scrollController,
      physics: const ClampingScrollPhysics(),
      slivers: [
        // ── Pinned header sliver ─────────────────────────────────────────
        // Drag handle + title row + sort/clear controls + mark-all-read.
        // pinned: true keeps it visible; floating: false avoids re-appear
        // on scroll-up which would feel wrong for a notification panel.
        // SliverAppBar with pinned:true keeps the header visible while the
        // list scrolls. toolbarHeight matches the content: base height plus
        // the mark-all-read row when it is present.
        SliverAppBar(
          pinned: true,
          automaticallyImplyLeading: false,
          backgroundColor: kWhite,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: (unread > 0 && notifications.isNotEmpty) ? 116.0 : 84.0,
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.none,
            background: _NotificationSheetHeader(
              notifications: notifications,
              unread: unread,
              sortLabel: _sortLabel,
              onShowSort: _showSortSheet,
              onClearAll: _confirmClearAll,
              onMarkAllRead: () =>
                  TaskStore.instance.markAllNotificationsRead(),
            ),
          ),
        ),

        // ── Content sliver ───────────────────────────────────────────────
        if (notifications.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 72,
                      color: kNavyDark.withOpacity(0.12),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'No notifications yet',
                      style: TextStyle(
                        color: kNavyDark.withOpacity(0.4),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "It’s quiet here…",
                      style: TextStyle(
                        color: kNavyDark.withOpacity(0.28),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  // Footer item
                  if (i == sorted.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'No More Notifications',
                          style: TextStyle(
                            color: kNavyDark.withOpacity(0.28),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }
                  return Dismissible(
                    key: ValueKey(sorted[i].id),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) =>
                        TaskStore.instance.deleteNotification(sorted[i].id),
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFECEC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete_outline_rounded,
                          color: Color(0xFFE87070), size: 22),
                    ),
                    child: NotificationItem(
                      icon: sorted[i].icon,
                      iconBgColor: sorted[i].iconBgColor,
                      iconColor: sorted[i].iconColor,
                      subtitle: sorted[i].subtitle,
                      title: sorted[i].title,
                      detail: sorted[i].detail,
                      showDashedLine: i < sorted.length - 1,
                      priority: sorted[i].priority,
                      isRead: sorted[i].isRead,
                      onTap: () =>
                          NotificationRouter.instance.route(context, sorted[i]),
                    ),
                  );
                },
                childCount: sorted.length + 1, // +1 for footer
              ),
            ),
          ),
      ],
    );
  }
}

// ── Pinned header widget ──────────────────────────────────────────────────────
// Plain StatelessWidget rendered inside a SliverAppBar's flexibleSpace.
// Using SliverAppBar(pinned:true) instead of SliverPersistentHeaderDelegate
// avoids the layoutExtent/paintExtent mismatch crash that occurs when the
// delegate's reported extent doesn't exactly match its painted content height.
class _NotificationSheetHeader extends StatelessWidget {
  final List<AppNotification> notifications;
  final int unread;
  final String sortLabel;
  final VoidCallback onShowSort;
  final VoidCallback onClearAll;
  final VoidCallback onMarkAllRead;

  const _NotificationSheetHeader({
    required this.notifications,
    required this.unread,
    required this.sortLabel,
    required this.onShowSort,
    required this.onClearAll,
    required this.onMarkAllRead,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kWhite,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title + controls row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Row(
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        color: kNavyDark,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (unread > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE87070),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$unread',
                          style: const TextStyle(
                            color: kWhite,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const Spacer(),
                if (notifications.isNotEmpty) ...[
                  GestureDetector(
                    onTap: onShowSort,
                    child: Row(
                      children: [
                        Text(
                          'Sorted by: $sortLabel',
                          style: const TextStyle(
                            color: Color(0xFF6B7A99),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(Icons.arrow_drop_down,
                            color: Color(0xFF6B7A99), size: 20),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: onClearAll,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFECEC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Clear',
                        style: TextStyle(
                          color: Color(0xFFE87070),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Mark all read — only when there are unread items
          if (unread > 0 && notifications.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: GestureDetector(
                onTap: onMarkAllRead,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.done_all_rounded,
                        size: 15, color: Color(0xFF9B88E8)),
                    SizedBox(width: 5),
                    Text(
                      'Mark all as read',
                      style: TextStyle(
                        color: Color(0xFF9B88E8),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Sort bottom sheet ─────────────────────────────────────────
class _SortSheet extends StatelessWidget {
  final _SortBy current;
  final ValueChanged<_SortBy> onSelected;

  const _SortSheet({required this.current, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 28),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 30,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Sort Notifications',
                style: TextStyle(
                  color: kNavyDark,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          _SortOption(
            label: 'Newest first',
            icon: Icons.arrow_downward_rounded,
            selected: current == _SortBy.newest,
            onTap: () => onSelected(_SortBy.newest),
          ),
          _SortOption(
            label: 'Oldest first',
            icon: Icons.arrow_upward_rounded,
            selected: current == _SortBy.oldest,
            onTap: () => onSelected(_SortBy.oldest),
          ),
          _SortOption(
            label: 'By type',
            icon: Icons.filter_list_rounded,
            selected: current == _SortBy.type,
            onTap: () => onSelected(_SortBy.type),
            subtitle: 'Overdue → Due today → Upcoming → Done',
            isLast: true,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  final String label;
  final String? subtitle;
  final IconData icon;
  final bool selected;
  final bool isLast;
  final VoidCallback onTap;

  const _SortOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF9B88E8).withOpacity(0.12)
                        : const Color(0xFFF4F5F7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon,
                      color: selected
                          ? const Color(0xFF9B88E8)
                          : const Color(0xFF6B7A99),
                      size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: kNavyDark,
                          fontSize: 15,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            color: Color(0xFF6B7A99),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_rounded,
                      color: Color(0xFF9B88E8), size: 20),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(height: 1, indent: 20, endIndent: 20,
              color: Colors.grey.withOpacity(0.12)),
      ],
    );
  }
}

// ── Clear confirm sheet ───────────────────────────────────────
class _ClearConfirmSheet extends StatelessWidget {
  final VoidCallback onConfirm;
  const _ClearConfirmSheet({required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 28),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 30,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: 56, height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFFFECEC),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.delete_sweep_rounded,
                color: Color(0xFFE87070), size: 28),
          ),
          const SizedBox(height: 14),
          const Text(
            'Clear all notifications?',
            style: TextStyle(
              color: kNavyDark,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'This will remove all notifications.\nThis action cannot be undone.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: kNavyDark.withOpacity(0.45),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // Cancel
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F5F7),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Center(
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Color(0xFF6B7A99),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Clear
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      onConfirm();
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE87070),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Center(
                        child: Text(
                          'Clear All',
                          style: TextStyle(
                            color: kWhite,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}