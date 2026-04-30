import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../constants/colors.dart';
import '../../models/task.dart';
import '../../store/task_store.dart';
import 'task_detail_sheet.dart';
import '../create_task_sheet.dart';

// ─────────────────────────────────────────────────────────────
// TaskHomeSheet — live task list with timeline-style layout
// ─────────────────────────────────────────────────────────────
class TaskHomeSheet extends StatefulWidget {
  // The DraggableScrollableSheet's scroll controller — must be attached
  // directly to the root CustomScrollView so dragging the sheet and
  // scrolling the list share a single scroll position.  This eliminates
  // nested-scroll conflicts and keeps the drag handle always visible.
  final ScrollController scrollController;

  const TaskHomeSheet({super.key, required this.scrollController});

  @override
  State<TaskHomeSheet> createState() => _TaskHomeSheetState();
}

enum _SortBy { dueDate, priority, status, category }

class _TaskHomeSheetState extends State<TaskHomeSheet> {
  _SortBy _sortBy = _SortBy.dueDate;

  @override
  void initState() {
    super.initState();
    TaskStore.instance.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    TaskStore.instance.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (!mounted) return;
    // Consume any pending task-open request from NotificationRouter.
    final pendingId = TaskStore.instance.pendingOpenTaskId;
    if (pendingId != null) {
      TaskStore.instance.clearPendingOpenTask();
      // Wait for the sheet expand animation (350ms) before showing the modal.
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        final found = showTaskDetailSheet(context, pendingId);
        if (!found) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF1A2A5E),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              content: const Text('This task no longer exists.',
                  style: TextStyle(color: Colors.white, fontSize: 13)),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      });
    }
    setState(() {});
  }

  List<Task> _sorted(List<Task> tasks) {
    final list = List<Task>.from(tasks);
    switch (_sortBy) {
      case _SortBy.dueDate:
        list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        break;
      case _SortBy.priority:
        const order = {TaskPriority.high: 0, TaskPriority.medium: 1, TaskPriority.low: 2};
        list.sort((a, b) => order[a.priority]!.compareTo(order[b.priority]!));
        break;
      case _SortBy.status:
        const order = {TaskStatus.inProgress: 0, TaskStatus.notStarted: 1, TaskStatus.completed: 2};
        list.sort((a, b) => order[a.status]!.compareTo(order[b.status]!));
        break;
      case _SortBy.category:
        list.sort((a, b) => a.category.label.compareTo(b.category.label));
        break;
    }
    return list;
  }

  void _showManageSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ManageSheet(
        currentSort: _sortBy,
        hasCompleted: TaskStore.instance.completed > 0,
        hasTasks: TaskStore.instance.total > 0,
        onSortChanged: (s) { setState(() => _sortBy = s); Navigator.pop(context); },
        onClearCompleted: () {
          Navigator.pop(context);
          final ids = TaskStore.instance.tasks
              .where((t) => t.status == TaskStatus.completed)
              .map((t) => t.id)
              .toList();
          for (final id in ids) TaskStore.instance.deleteTask(id);
        },
        onClearAll: () {
          final ids = TaskStore.instance.tasks.map((t) => t.id).toList();
          for (final id in ids) TaskStore.instance.deleteTask(id);
        },
      ),
    );
  }

  String _sortLabel(_SortBy s) {
    switch (s) {
      case _SortBy.dueDate:  return 'Due Date';
      case _SortBy.priority: return 'Priority';
      case _SortBy.status:   return 'Status';
      case _SortBy.category: return 'Category';
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = TaskStore.instance;
    final tasks = _sorted(store.recentTasks);

    // ── Architecture: CustomScrollView at the root ────────────────────────
    // The DraggableScrollableSheet requires its scrollController to be
    // attached to a scrollable that is the direct child of its builder.
    // Using CustomScrollView satisfies this: dragging anywhere on the sheet
    // — header or list — travels through a single scroll controller so the
    // sheet drag, header interaction, and list scroll all work correctly.
    //
    // The header (drag handle + title row + donut + controls) lives in a
    // SliverAppBar with pinned: true so it stays visible at the top of the
    // sheet regardless of list scroll position.
    // The task items live in a SliverList (or SliverFillRemaining for
    // the empty state).
    return CustomScrollView(
      controller: widget.scrollController,
      physics: const ClampingScrollPhysics(),
      slivers: [
        // ── Pinned header sliver ─────────────────────────────────────────
        // SliverAppBar(pinned:true) + FlexibleSpaceBar(collapseMode:none)
        // is the canonical pattern from home_screen.dart.  It avoids the
        // layoutExtent/paintExtent SliverGeometry crash that SliverPersistentHeader
        // produces when minExtent/maxExtent don't exactly match painted height.
        //
        // toolbarHeight pixel breakdown (no-tasks / with-tasks):
        //   drag handle  : 12 top + 4 + 18 bottom           =  34
        //   header row   : plain text ~28                    =  28
        //   SizedBox(20) :                                   =  20
        //   Divider(h:1) :                                   =   1
        //   controls row : pad-top 8 + ~28 content + pad-b 6=  44
        //   ── no-tasks subtotal ──────────────────────────────  127  → 130 (+3 guard)
        //   donut block  : pad-top 14 + Row height 110       = 124
        //   ── with-tasks total ───────────────────────────────  251  → 268 (+17 guard)
        // The guard absorbs sub-pixel rounding and mild font-scale variance.
        SliverAppBar(
          pinned: true,
          automaticallyImplyLeading: false,
          backgroundColor: kWhite,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: store.total > 0 ? 268.0 : 130.0,
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.none,
            background: _TaskSheetHeader(
              store: store,
              tasks: tasks,
              sortBy: _sortBy,
              sortLabel: _sortLabel(_sortBy),
              onShowManage: _showManageSheet,
            ),
          ),
        ),

        // ── Content sliver ───────────────────────────────────────────────
        if (tasks.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            fillOverscroll: false,
            child: _EmptyState(context: context),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 80),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _TaskRow(
                  task: tasks[i],
                  isLast: i == tasks.length - 1,
                  onStatusChanged: (s) =>
                      TaskStore.instance.updateStatus(tasks[i].id, s),
                  onDelete: () => TaskStore.instance.deleteTask(tasks[i].id),
                ),
                childCount: tasks.length,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Pinned header widget ──────────────────────────────────────────────────────
// Plain StatelessWidget rendered inside a SliverAppBar's flexibleSpace.
// Using SliverAppBar(pinned:true) + FlexibleSpaceBar instead of
// SliverPersistentHeaderDelegate avoids the layoutExtent/paintExtent mismatch
// crash that occurs when the delegate's reported extent doesn't exactly match
// its painted content height.
class _TaskSheetHeader extends StatelessWidget {
  final dynamic store;
  final List<Task> tasks;
  final _SortBy sortBy;
  final String sortLabel;
  final VoidCallback onShowManage;

  const _TaskSheetHeader({
    required this.store,
    required this.tasks,
    required this.sortBy,
    required this.sortLabel,
    required this.onShowManage,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kWhite,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ─────────────────────────────────────
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 18),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.30),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header row ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Tasks',
                  style: TextStyle(
                      color: kNavyDark,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                if (store.total > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: kTeal.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kTeal.withOpacity(0.3)),
                    ),
                    child: Text(
                      '${(store.completionPercent * 100).round()}%',
                      style: const TextStyle(color: kTeal, fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
            ),
          ),

          // ── Donut + stat rows ────────────────────────────────
          if (store.total > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    height: 110,
                    child: CustomPaint(
                      painter: _DonutPainter(
                        inProgress: store.inProgress,
                        completed:  store.completed,
                        notStarted: store.notStarted,
                        total:      store.total,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(store.completionPercent * 100).round()}%',
                              style: const TextStyle(
                                color: kNavyDark,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'done',
                              style: TextStyle(
                                color: Color(0xFF6B7A99),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 20),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DonutStatRow(
                          color: const Color(0xFF4A90D9),
                          label: 'In Progress',
                          count: store.inProgress,
                          total: store.total,
                        ),
                        const SizedBox(height: 12),
                        _DonutStatRow(
                          color: const Color(0xFFB0BAD3),
                          label: 'Not Started',
                          count: store.notStarted,
                          total: store.total,
                        ),
                        const SizedBox(height: 12),
                        _DonutStatRow(
                          color: const Color(0xFF3BBFA3),
                          label: 'Completed',
                          count: store.completed,
                          total: store.total,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),
          Divider(height: 1, color: const Color(0xFF6B7A99).withOpacity(0.15), indent: 20, endIndent: 20),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tasks.isEmpty ? '' : '${tasks.length} task${tasks.length == 1 ? '' : 's'}',
                  style: TextStyle(color: const Color(0xFF6B7A99).withOpacity(0.6), fontSize: 11),
                ),
                GestureDetector(
                  onTap: store.total > 0 ? onShowManage : null,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: store.total > 0 ? 1.0 : 0.35,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B7A99).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF6B7A99).withOpacity(0.18)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sort_rounded, size: 12, color: Color(0xFF6B7A99)),
                          const SizedBox(width: 4),
                          Text(
                            sortLabel,
                            style: const TextStyle(color: Color(0xFF6B7A99), fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 3),
                          const Icon(Icons.keyboard_arrow_down_rounded, size: 12, color: Color(0xFF6B7A99)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Manage sheet — sort + bulk actions
// ─────────────────────────────────────────────────────────────
class _ManageSheet extends StatelessWidget {
  final _SortBy currentSort;
  final bool hasCompleted;
  final bool hasTasks;
  final ValueChanged<_SortBy> onSortChanged;
  final VoidCallback onClearCompleted;
  final VoidCallback onClearAll;

  const _ManageSheet({
    required this.currentSort,
    required this.hasCompleted,
    required this.hasTasks,
    required this.onSortChanged,
    required this.onClearCompleted,
    required this.onClearAll,
  });

  static const _sorts = [
    (_SortBy.dueDate,  Icons.schedule_rounded,         'Due Date',  'Earliest first'),
    (_SortBy.priority, Icons.flag_rounded,              'Priority',  'High → Low'),
    (_SortBy.status,   Icons.timelapse_rounded,         'Status',    'In Progress first'),
    (_SortBy.category, Icons.label_rounded,             'Category',  'Alphabetical'),
  ];

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.82;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 28),
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2D5B),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: kWhite.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 40, offset: const Offset(0, -4))],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(top: 14, bottom: 18),
              decoration: BoxDecoration(color: kWhite.withOpacity(0.18), borderRadius: BorderRadius.circular(2)),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: kTeal.withOpacity(0.14),
                    shape: BoxShape.circle,
                    border: Border.all(color: kTeal.withOpacity(0.3), width: 1.5),
                  ),
                  child: const Icon(Icons.tune_rounded, color: kTeal, size: 21),
                ),
                const SizedBox(width: 13),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Sort & Manage', style: TextStyle(color: kWhite, fontSize: 17, fontWeight: FontWeight.bold)),
                  Text('Organise your task list', style: TextStyle(color: kWhite.withOpacity(0.4), fontSize: 12)),
                ]),
              ]),
            ),

            const SizedBox(height: 16),
            Divider(color: kWhite.withOpacity(0.07), thickness: 1, indent: 22, endIndent: 22),
            const SizedBox(height: 6),

            // Sort by label
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 2, 22, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('SORT BY', style: TextStyle(color: kWhite.withOpacity(0.28), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              ),
            ),

            // Sort options
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: _sorts.map((s) {
                  final selected = s.$1 == currentSort;
                  const c = kTeal;
                  return _ManageRow(
                    icon: s.$2,
                    iconColor: selected ? c : kWhite.withOpacity(0.4),
                    label: s.$3,
                    subtitle: s.$4,
                    selected: selected,
                    accentColor: c,
                    onTap: () => onSortChanged(s.$1),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 4),
            Divider(color: kWhite.withOpacity(0.07), thickness: 1, indent: 22, endIndent: 22),
            const SizedBox(height: 6),

            // Actions label
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 2, 22, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('ACTIONS', style: TextStyle(color: kWhite.withOpacity(0.28), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              ),
            ),

            // Clear completed
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(children: [
                _ManageRow(
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: hasCompleted ? const Color(0xFF3BBFA3) : kWhite.withOpacity(0.2),
                  label: 'Clear Completed',
                  subtitle: 'Remove all finished tasks',
                  selected: false,
                  accentColor: const Color(0xFF3BBFA3),
                  enabled: hasCompleted,
                  onTap: hasCompleted ? onClearCompleted : null,
                  destructive: false,
                ),
                _ManageRow(
                  icon: Icons.delete_sweep_rounded,
                  iconColor: hasTasks ? const Color(0xFFE87070) : kWhite.withOpacity(0.2),
                  label: 'Clear All Tasks',
                  subtitle: 'Permanently remove everything',
                  selected: false,
                  accentColor: const Color(0xFFE87070),
                  enabled: hasTasks,
                  onTap: hasTasks
                      ? () => _confirmClearAll(context)
                      : null,
                  destructive: true,
                ),
              ]),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _confirmClearAll(BuildContext context) {
    Navigator.pop(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (confirmCtx) => Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 28),
          decoration: BoxDecoration(
            color: const Color(0xFF1B2D5B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: kWhite.withOpacity(0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 18),
                  decoration: BoxDecoration(color: kWhite.withOpacity(0.18), borderRadius: BorderRadius.circular(2))),
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFE87070).withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE87070).withOpacity(0.3), width: 1.5),
                ),
                child: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFE87070), size: 26),
              ),
              const SizedBox(height: 12),
              const Text('Clear All Tasks?', style: TextStyle(color: kWhite, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('This will permanently remove all tasks', style: TextStyle(color: kWhite.withOpacity(0.4), fontSize: 13)),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(confirmCtx),
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(color: kWhite.withOpacity(0.07), borderRadius: BorderRadius.circular(12)),
                        child: const Center(child: Text('Cancel', style: TextStyle(color: kWhite, fontWeight: FontWeight.w600))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () { Navigator.pop(confirmCtx); onClearAll(); },
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE87070).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE87070).withOpacity(0.4)),
                        ),
                        child: const Center(child: Text('Clear All', style: TextStyle(color: Color(0xFFE87070), fontWeight: FontWeight.bold))),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    });
  }
}

// ── Single manage row ─────────────────────────────────────────
class _ManageRow extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final bool selected;
  final Color accentColor;
  final bool destructive;
  final bool enabled;
  final VoidCallback? onTap;

  const _ManageRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.accentColor,
    this.destructive = false,
    this.enabled = true,
    this.onTap,
  });

  @override
  State<_ManageRow> createState() => _ManageRowState();
}

class _ManageRowState extends State<_ManageRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.accentColor;
    final active = widget.selected || _pressed;
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.enabled ? (_) { setState(() => _pressed = false); widget.onTap?.call(); } : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: active ? c.withOpacity(0.10) : kWhite.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? c.withOpacity(0.45) : kWhite.withOpacity(0.07),
            width: 1.2,
          ),
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: widget.iconColor.withOpacity(active ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(widget.icon, color: widget.iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.label, style: TextStyle(
              color: widget.enabled ? (widget.destructive ? const Color(0xFFE87070) : kWhite) : kWhite.withOpacity(0.25),
              fontSize: 14, fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: 2),
            Text(widget.subtitle, style: TextStyle(color: kWhite.withOpacity(widget.enabled ? 0.35 : 0.18), fontSize: 11)),
          ])),
          if (widget.selected)
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: kWhite, size: 13),
            )
          else
            Icon(
              Icons.chevron_right_rounded,
              color: kWhite.withOpacity(widget.enabled ? 0.18 : 0.08), size: 18,
            ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Donut painter — matches spaces_screen _DonutPainter exactly
// ─────────────────────────────────────────────────────────────
class _DonutPainter extends CustomPainter {
  final int inProgress;
  final int completed;
  final int notStarted;
  final int total;

  const _DonutPainter({
    required this.inProgress,
    required this.completed,
    required this.notStarted,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const stroke = 18.0;
    const pi = math.pi;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Grey track ring
    canvas.drawArc(rect, 0, 2 * pi, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = const Color(0xFFE8EBF2));

    if (total == 0) return;

    void arc(double start, double sweep, Color color) {
      if (sweep <= 0) return;
      canvas.drawArc(rect, start, sweep, false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round
            ..color = color);
    }

    double start = -pi / 2;
    final ipSweep = 2 * pi * (inProgress / total);
    final nsSweep = 2 * pi * (notStarted / total);
    final cSweep  = 2 * pi * (completed / total);

    arc(start, ipSweep, const Color(0xFF4A90D9));
    start += ipSweep + 0.05;
    arc(start, nsSweep, const Color(0xFFB0BAD3));
    start += nsSweep + 0.05;
    arc(start, cSweep, const Color(0xFF3BBFA3));
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─────────────────────────────────────────────────────────────
// Donut stat row — matches spaces_screen _StatRow style
// ─────────────────────────────────────────────────────────────
class _DonutStatRow extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  final int total;

  const _DonutStatRow({
    required this.color,
    required this.label,
    required this.count,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(label,
                    style: const TextStyle(color: Color(0xFF6B7A99), fontSize: 11)),
              ],
            ),
            Text('$count/$total',
                style: const TextStyle(
                  color: kNavyDark,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                )),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: total > 0 ? count / total : 0,
            minHeight: 4,
            backgroundColor: const Color(0xFFE8EBF2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final BuildContext context;
  const _EmptyState({required this.context});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: GestureDetector(
          onTap: () => showCreateTaskSheet(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.task_alt_rounded,
                  size: 60, color: kNavyDark.withOpacity(0.1)),
              const SizedBox(height: 14),
              Text('No tasks yet',
                  style: TextStyle(
                      color: kNavyDark.withOpacity(0.4),
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('Tap to add your first task',
                  style: TextStyle(
                      color: kNavyDark.withOpacity(0.25), fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Task row — timeline style matching the screenshot
// ─────────────────────────────────────────────────────────────
class _TaskRow extends StatefulWidget {
  final Task task;
  final bool isLast;
  final ValueChanged<TaskStatus> onStatusChanged;
  final VoidCallback onDelete;

  const _TaskRow({
    required this.task,
    required this.isLast,
    required this.onStatusChanged,
    required this.onDelete,
  });

  @override
  State<_TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends State<_TaskRow> {
  bool _pressed = false;

  // ── Status config ──────────────────────────────────────────
  static const _statusLabel = {
    TaskStatus.notStarted: 'Not Started',
    TaskStatus.inProgress: 'In Progress',
    TaskStatus.completed:  'Completed',
  };

  static const _statusColor = {
    TaskStatus.notStarted: Color(0xFF8FA6C8),
    TaskStatus.inProgress: Color(0xFF4A90D9),
    TaskStatus.completed:  Color(0xFF3BBFA3),
  };

  static const _statusIcon = {
    TaskStatus.notStarted: Icons.radio_button_unchecked_rounded,
    TaskStatus.inProgress: Icons.timelapse_rounded,
    TaskStatus.completed:  Icons.check_circle_rounded,
  };

  String _formatDateRange(Task t) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dd    = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
    final diff  = dd.difference(today).inDays;

    String dateStr;
    if (diff == 0)      dateStr = 'Today';
    else if (diff == 1) dateStr = 'Tomorrow';
    else {
      final m  = t.dueDate.month.toString().padLeft(2, '0');
      final d  = t.dueDate.day.toString().padLeft(2, '0');
      final y  = (t.dueDate.year % 100).toString().padLeft(2, '0');
      dateStr = '$m/$d/$y';
    }

    if (t.dueTime != null) {
      final h    = t.dueTime!.hour;
      final m2   = t.dueTime!.minute;
      final ampm = h >= 12 ? 'p.m.' : 'a.m.';
      final hh   = h > 12 ? h - 12 : (h == 0 ? 12 : h);
      dateStr += '  ${hh}:${m2.toString().padLeft(2, '0')} $ampm';
    }

    return dateStr;
  }

  void _showStatusMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _StatusPickerSheet(
        current: widget.task.status,
        onSelected: (s) {
          Navigator.pop(context);
          widget.onStatusChanged(s);
        },
      ),
    );
  }

  void _showTaskActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        final task = widget.task;
        final catColor = task.category.color;
        final sColor = _statusColor[task.status]!;
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 28),
          decoration: BoxDecoration(
            color: const Color(0xFF1B2D5B),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: kWhite.withOpacity(0.08)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 40, offset: const Offset(0, -4))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(top: 14, bottom: 16),
                decoration: BoxDecoration(color: kWhite.withOpacity(0.18), borderRadius: BorderRadius.circular(2)),
              ),

              // Task preview header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Row(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: catColor.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: catColor.withOpacity(0.25), width: 1.2),
                    ),
                    child: Icon(_statusIcon[task.status]!, color: catColor, size: 20),
                  ),
                  const SizedBox(width: 13),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      task.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: kWhite, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 3),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: catColor.withOpacity(0.13),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(task.category.label, style: TextStyle(color: catColor, fontSize: 9, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: sColor.withOpacity(0.13),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(_statusLabel[task.status]!, style: TextStyle(color: sColor, fontSize: 9, fontWeight: FontWeight.w800)),
                      ),
                    ]),
                  ])),
                ]),
              ),

              const SizedBox(height: 16),
              Divider(color: kWhite.withOpacity(0.07), thickness: 1, indent: 20, endIndent: 20),
              const SizedBox(height: 10),

              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                child: Column(children: [
                  _ActionRow(
                    icon: Icons.swap_horiz_rounded,
                    iconColor: kTeal,
                    label: 'Change Status',
                    subtitle: 'Update task progress',
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _showStatusMenu(context);
                      });
                    },
                  ),
                  _ActionRow(
                    icon: Icons.delete_outline_rounded,
                    iconColor: const Color(0xFFE87070),
                    label: 'Remove Task',
                    subtitle: 'Permanently delete this task',
                    destructive: true,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _showDeleteConfirm(context);
                      });
                    },
                  ),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (confirmCtx) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 28),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2D5B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kWhite.withOpacity(0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 18),
                decoration: BoxDecoration(color: kWhite.withOpacity(0.18), borderRadius: BorderRadius.circular(2))),
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFE87070).withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE87070).withOpacity(0.3), width: 1.5),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE87070), size: 26),
            ),
            const SizedBox(height: 12),
            const Text('Remove Task?', style: TextStyle(color: kWhite, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('This cannot be undone', style: TextStyle(color: kWhite.withOpacity(0.4), fontSize: 13)),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(confirmCtx),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(color: kWhite.withOpacity(0.07), borderRadius: BorderRadius.circular(12)),
                      child: const Center(child: Text('Cancel', style: TextStyle(color: kWhite, fontWeight: FontWeight.w600))),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () { Navigator.pop(confirmCtx); widget.onDelete(); },
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE87070).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE87070).withOpacity(0.4)),
                      ),
                      child: const Center(child: Text('Delete', style: TextStyle(color: Color(0xFFE87070), fontWeight: FontWeight.bold))),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final task    = widget.task;
    final isDone  = task.status == TaskStatus.completed;
    final catColor = task.category.color;
    final sColor  = _statusColor[task.status]!;

    return GestureDetector(
      onLongPress: () => _showTaskActions(context),
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _pressed ? const Color(0xFF6B7A99).withOpacity(0.05) : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Timeline column ──────────────────────────
              Column(
                children: [
                  const SizedBox(height: 4),
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: sColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: sColor.withOpacity(0.35), width: 1.5),
                    ),
                    child: Icon(_statusIcon[task.status]!, color: sColor, size: 18),
                  ),
                  if (!widget.isLast)
                    Container(
                      width: 2,
                      height: 52,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [sColor.withOpacity(0.35), sColor.withOpacity(0.06)],
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 13),

              // ── Content ──────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),

                      Text(
                        task.name,
                        style: TextStyle(
                          color: isDone ? const Color(0xFF8FA6C8) : kNavyDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                          decorationColor: const Color(0xFF8FA6C8),
                          decorationThickness: 2,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        _formatDateRange(task),
                        style: TextStyle(
                          color: task.isOverdue
                              ? const Color(0xFFE87070)
                              : const Color(0xFF6B7A99),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      if (task.notes != null && task.notes!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(task.notes!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFF8FA6C8), fontSize: 11)),
                      ],

                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: catColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(task.category.label,
                                style: TextStyle(color: catColor, fontSize: 10, fontWeight: FontWeight.w800)),
                          ),

                          const SizedBox(width: 6),

                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: task.priority.color.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Container(width: 5, height: 5, decoration: BoxDecoration(color: task.priority.color, shape: BoxShape.circle)),
                                const SizedBox(width: 4),
                                Text(task.priority.label,
                                    style: TextStyle(color: task.priority.color, fontSize: 10, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),

                          const Spacer(),

                          GestureDetector(
                            onTap: () => _showStatusMenu(context),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: sColor.withOpacity(0.13),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: sColor.withOpacity(0.4), width: 1.2),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _statusLabel[task.status]!,
                                    style: TextStyle(color: sColor, fontSize: 11, fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(width: 3),
                                  Icon(Icons.expand_more_rounded, color: sColor, size: 13),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Action row — used inside the task action sheet
// ─────────────────────────────────────────────────────────────
class _ActionRow extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final bool destructive;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.iconColor;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _pressed ? c.withOpacity(0.10) : kWhite.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _pressed ? c.withOpacity(0.45) : kWhite.withOpacity(0.07),
            width: 1.2,
          ),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: c.withOpacity(_pressed ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(widget.icon, color: c, size: 19),
          ),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.label, style: TextStyle(
              color: widget.destructive ? const Color(0xFFE87070) : kWhite,
              fontSize: 14, fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: 2),
            Text(widget.subtitle, style: TextStyle(color: kWhite.withOpacity(0.35), fontSize: 11)),
          ])),
          Icon(Icons.chevron_right_rounded, color: kWhite.withOpacity(0.18), size: 18),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Status picker sheet — styled like the add-menu sheet
// ─────────────────────────────────────────────────────────────
class _StatusPickerSheet extends StatelessWidget {
  final TaskStatus current;
  final ValueChanged<TaskStatus> onSelected;

  const _StatusPickerSheet({required this.current, required this.onSelected});

  static const _label = {
    TaskStatus.notStarted: 'Not Started',
    TaskStatus.inProgress: 'In Progress',
    TaskStatus.completed:  'Completed',
  };
  static const _color = {
    TaskStatus.notStarted: Color(0xFF8FA6C8),
    TaskStatus.inProgress: Color(0xFF4A90D9),
    TaskStatus.completed:  Color(0xFF3BBFA3),
  };
  static const _icon = {
    TaskStatus.notStarted: Icons.radio_button_unchecked_rounded,
    TaskStatus.inProgress: Icons.timelapse_rounded,
    TaskStatus.completed:  Icons.check_circle_rounded,
  };
  static const _desc = {
    TaskStatus.notStarted: 'Task has not been started yet',
    TaskStatus.inProgress: 'Currently working on this',
    TaskStatus.completed:  'All done!',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 28),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2D5B),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: kWhite.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 40, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(top: 14, bottom: 18),
            decoration: BoxDecoration(color: kWhite.withOpacity(0.18), borderRadius: BorderRadius.circular(2)),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: kTeal.withOpacity(0.14),
                    shape: BoxShape.circle,
                    border: Border.all(color: kTeal.withOpacity(0.3), width: 1.5),
                  ),
                  child: const Icon(Icons.swap_horiz_rounded, color: kTeal, size: 22),
                ),
                const SizedBox(width: 13),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Update Status',
                        style: TextStyle(color: kWhite, fontSize: 17, fontWeight: FontWeight.bold)),
                    Text('Tap to change task progress',
                        style: TextStyle(color: kWhite.withOpacity(0.4), fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Divider(color: kWhite.withOpacity(0.07), thickness: 1, indent: 22, endIndent: 22),
          const SizedBox(height: 8),

          // Status cards — same style as _AddCard
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 22),
            child: Column(
              children: TaskStatus.values.map((s) {
                final isCurrent = s == current;
                final c = _color[s]!;
                return _StatusCard(
                  icon: _icon[s]!,
                  iconColor: c,
                  label: _label[s]!,
                  description: _desc[s]!,
                  selected: isCurrent,
                  onTap: () => onSelected(s),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status card — mirrors _AddCard visual exactly ─────────────
class _StatusCard extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _StatusCard({
    required this.icon, required this.iconColor, required this.label,
    required this.description, required this.selected, required this.onTap,
  });

  @override
  State<_StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends State<_StatusCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.iconColor;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: (_pressed || widget.selected) ? c.withOpacity(0.12) : kWhite.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (_pressed || widget.selected) ? c.withOpacity(0.55) : kWhite.withOpacity(0.08),
            width: 1.3,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: c.withOpacity(0.13),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: c.withOpacity(0.25), width: 1.2),
              ),
              child: Icon(widget.icon, color: c, size: 22),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.label,
                      style: const TextStyle(color: kWhite, fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(widget.description,
                      style: TextStyle(color: kWhite.withOpacity(0.37), fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            if (widget.selected)
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: kWhite, size: 14),
              )
            else
              Icon(Icons.chevron_right_rounded, color: kWhite.withOpacity(0.2), size: 20),
          ],
        ),
      ),
    );
  }
}