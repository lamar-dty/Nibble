import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../models/task.dart';
import '../../models/event.dart';
import '../../store/task_store.dart';
import 'task_detail_sheet.dart';

// ─────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────
class PlanCategory {
  final String id;
  final String name;
  final Color color;
  bool visible;

  PlanCategory({
    required this.id,
    required this.name,
    required this.color,
    this.visible = true,
  });
}

class PlanEvent {
  final String title;
  final String categoryId;
  final Color color;
  final int weekday;      // 1=Mon … 7=Sun
  final double startHour; // e.g. 9.0 = 9:00 AM
  final double endHour;   // e.g. 10.5 = 10:30 AM
  final String taskId;    // original task/event id — for deduplication
  final String? notes;
  final TaskPriority priority;
  final bool hasTime;
  final TaskStatus status;
  final bool isEvent;     // true = from EventStore, false = from TaskStore

  const PlanEvent({
    required this.title,
    required this.categoryId,
    required this.color,
    required this.weekday,
    required this.startHour,
    required this.endHour,
    required this.taskId,
    required this.priority,
    required this.hasTime,
    required this.status,
    this.notes,
    this.isEvent = false,
  });

  double get durationHours => endHour - startHour;
}

// Category ID constants — map 1:1 to TaskCategory enum
const _kCatAssignment   = 'assignment';
const _kCatProject      = 'project';
const _kCatAssessment   = 'assessment';
const _kCatPersonalTask = 'personal_task';

// Event category IDs
const _kCatEventAcademic = 'event_academic';
const _kCatEventPersonal = 'event_organization';
const _kCatEventSocial   = 'event_social';
const _kCatEventHealth   = 'event_health';
const _kCatEventOther    = 'event_other';

// ─────────────────────────────────────────────────────────────
// WeeklyPlannerCalendar
// ─────────────────────────────────────────────────────────────
class WeeklyPlannerCalendar extends StatefulWidget {
  final double peekHeight;
  final int startHour;
  final int endHour;
  final void Function(int start, int end) onRangeChanged;

  const WeeklyPlannerCalendar({
    super.key,
    this.peekHeight = 0,
    this.startHour = 6,
    this.endHour = 22,
    required this.onRangeChanged,
  });

  @override
  State<WeeklyPlannerCalendar> createState() => _WeeklyPlannerCalendarState();
}

class _WeeklyPlannerCalendarState extends State<WeeklyPlannerCalendar>
    with SingleTickerProviderStateMixin {
  late DateTime _focusedMonth;
  late DateTime _selectedDay;
  late AnimationController _fadeCtrl;


  final List<PlanCategory> _categories = [
    PlanCategory(id: _kCatAssignment,    name: 'Assignment',      color: const Color(0xFF9B88E8)),
    PlanCategory(id: _kCatProject,       name: 'Project',         color: const Color(0xFFE8D870)),
    PlanCategory(id: _kCatAssessment,    name: 'Assessment',      color: const Color(0xFF90D0CB)),
    PlanCategory(id: _kCatPersonalTask,  name: 'Personal Task',   color: const Color(0xFFE8A870)),
    PlanCategory(id: _kCatEventAcademic, name: 'Academic', color: const Color(0xFF4A90D9)),
    PlanCategory(id: _kCatEventPersonal, name: 'Organization', color: const Color(0xFFE8A870)),
    PlanCategory(id: _kCatEventSocial,   name: 'Social',   color: const Color(0xFFD96B8A)),
    PlanCategory(id: _kCatEventHealth,   name: 'Health',   color: const Color(0xFF3BBFA3)),
    PlanCategory(id: _kCatEventOther,    name: 'Other',    color: const Color(0xFFB0BAD3)),
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _selectedDay  = now;
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    TaskStore.instance.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    TaskStore.instance.removeListener(_onStoreChanged);
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _onStoreChanged() => setState(() {});

  // ── Category helpers ──────────────────────────────────────
  String _categoryId(TaskCategory cat) {
    switch (cat) {
      case TaskCategory.assignment:   return _kCatAssignment;
      case TaskCategory.project:      return _kCatProject;
      case TaskCategory.assessment:   return _kCatAssessment;
      case TaskCategory.personalTask: return _kCatPersonalTask;
    }
  }

  String _eventCategoryId(EventCategory cat) {
    switch (cat) {
      case EventCategory.academic: return _kCatEventAcademic;
      case EventCategory.organization: return _kCatEventPersonal;
      case EventCategory.social:   return _kCatEventSocial;
      case EventCategory.health:   return _kCatEventHealth;
      case EventCategory.other:    return _kCatEventOther;
    }
  }

  bool _isCategoryVisible(String catId) {
    final cat = _categories.firstWhere((c) => c.id == catId, orElse: () => _categories.first);
    return cat.visible;
  }

  void _toggleCategory(PlanCategory cat) {
    setState(() => cat.visible = !cat.visible);
  }

  /// Convert tasks from TaskStore into PlanEvents for the selected week.
  List<PlanEvent> get _visibleEvents {
    final weekDays = _weekDays();
    final weekStart = DateTime(weekDays.first.year, weekDays.first.month, weekDays.first.day);
    final weekEnd   = DateTime(weekDays.last.year,  weekDays.last.month,  weekDays.last.day);

    final events = <PlanEvent>[];
    for (final task in TaskStore.instance.tasks) {
      final catId = _categoryId(task.category);
      if (!_isCategoryVisible(catId)) continue;

      final taskStart = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
      final taskEnd   = task.endDate != null
          ? DateTime(task.endDate!.year, task.endDate!.month, task.endDate!.day)
          : taskStart;

      // Skip tasks entirely outside this week
      if (taskEnd.isBefore(weekStart) || taskStart.isAfter(weekEnd)) continue;

      // Clamp the task range to the visible week
      final clampedStart = taskStart.isBefore(weekStart) ? weekStart : taskStart;
      final clampedEnd   = taskEnd.isAfter(weekEnd) ? weekEnd : taskEnd;

      // Generate one event per day in the clamped range
      DateTime cursor = clampedStart;
      while (!cursor.isAfter(clampedEnd)) {
        double startHour;
        double endHour;

        if (task.dueTime != null) {
          startHour = task.dueTime!.hour + task.dueTime!.minute / 60.0;
          if (task.endTime != null) {
            endHour = task.endTime!.hour + task.endTime!.minute / 60.0;
            if (endHour <= startHour) endHour = startHour + 1.0;
          } else {
            endHour = startHour + 1.0;
          }
        } else {
          // No time — show as 1-hour block so text is readable
          startHour = 8.0;
          endHour   = 9.0;
        }

        // Clamp to grid bounds
        startHour = startHour.clamp(widget.startHour.toDouble(), widget.endHour.toDouble());
        endHour   = endHour.clamp(startHour, widget.endHour.toDouble());

        events.add(PlanEvent(
          title:      task.name,
          categoryId: catId,
          color:      task.category.color,
          weekday:    cursor.weekday,
          startHour:  startHour,
          endHour:    endHour,
          taskId:     task.id,
          notes:      task.notes,
          priority:   task.priority,
          hasTime:    task.dueTime != null,
          status:     task.status,
        ));

        cursor = cursor.add(const Duration(days: 1));
      }
    }
    // ── Events from EventStore ───────────────────────────────
    for (final event in TaskStore.instance.events) {
      final catId = _eventCategoryId(event.category);
      if (!_isCategoryVisible(catId)) continue;

      final evStart = DateTime(event.startDate.year, event.startDate.month, event.startDate.day);
      final evEnd   = DateTime(event.endDate.year,   event.endDate.month,   event.endDate.day);

      if (evEnd.isBefore(weekStart) || evStart.isAfter(weekEnd)) continue;

      final clampedStart = evStart.isBefore(weekStart) ? weekStart : evStart;
      final clampedEnd   = evEnd.isAfter(weekEnd) ? weekEnd : evEnd;

      DateTime cursor = clampedStart;
      while (!cursor.isAfter(clampedEnd)) {
        double startHour;
        double endHour;

        if (event.startTime != null) {
          startHour = event.startTime!.hour + event.startTime!.minute / 60.0;
          if (event.endTime != null) {
            endHour = event.endTime!.hour + event.endTime!.minute / 60.0;
            if (endHour <= startHour) endHour = startHour + 1.0;
          } else {
            endHour = startHour + 1.0;
          }
        } else {
          startHour = 8.0;
          endHour   = 9.0;
        }

        startHour = startHour.clamp(widget.startHour.toDouble(), widget.endHour.toDouble());
        endHour   = endHour.clamp(startHour, widget.endHour.toDouble());

        events.add(PlanEvent(
          title:      event.title,
          categoryId: catId,
          color:      event.category.color,
          weekday:    cursor.weekday,
          startHour:  startHour,
          endHour:    endHour,
          taskId:     event.id,
          notes:      event.notes,
          priority:   TaskPriority.medium,
          hasTime:    event.startTime != null,
          status:     TaskStatus.notStarted,
          isEvent:    true,
        ));

        cursor = cursor.add(const Duration(days: 1));
      }
    }

    return events;
  }

  /// Unique task count (excludes events).
  int get _visibleTaskCount => _visibleEvents.where((e) => !e.isEvent).map((e) => e.taskId).toSet().length;

  /// Unique event count (from EventStore only).
  int get _visibleEventCount => _visibleEvents.where((e) => e.isEvent).map((e) => e.taskId).toSet().length;

  /// Total tasks in the selected week regardless of filter.
  int get _totalWeekTaskCount {
    final store = TaskStore.instance;
    return _weekDays().expand((d) => store.tasksForDay(d)).map((t) => t.id).toSet().length;
  }

  // ── Date helpers ──────────────────────────────────────────
  List<DateTime> _daysInMonth(DateTime month) {
    final first  = DateTime(month.year, month.month, 1);
    final last   = DateTime(month.year, month.month + 1, 0);
    final offset = (first.weekday - 1) % 7;
    final days   = <DateTime>[];
    for (int i = offset; i > 0; i--) days.add(first.subtract(Duration(days: i)));
    for (int i = 0; i < last.day; i++) days.add(DateTime(month.year, month.month, i + 1));
    final rem = 42 - days.length;
    for (int i = 1; i <= rem; i++) days.add(last.add(Duration(days: i)));
    return days;
  }

  List<DateTime> _weekDays() {
    final monday = _selectedDay.subtract(Duration(days: _selectedDay.weekday - 1));
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  String _fullMonth(int m) => const [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ][m];

  String _shortMonth(int m) => const [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ][m];

  // ── Calendar settings sheet ───────────────────────────────
  void _openCalendarSettings() {
    int tempStart = widget.startHour;
    int tempEnd   = widget.endHour;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            String _fmt(int h) {
              if (h == 0)  return '12 AM';
              if (h < 12)  return '$h AM';
              if (h == 12) return '12 PM';
              return '${h - 12} PM';
            }

            return Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              decoration: BoxDecoration(
                color: const Color(0xFF1B2D5B),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: kWhite.withOpacity(0.08)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: kWhite.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Title
                  Row(
                    children: [
                      const Icon(Icons.tune_rounded, color: kTeal, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'Calendar Hours',
                        style: TextStyle(
                          color: kWhite,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Set the visible time range for your weekly planner.',
                    style: TextStyle(color: kWhite.withOpacity(0.45), fontSize: 12),
                  ),

                  const SizedBox(height: 28),

                  // Start hour
                  Text('Start time', style: TextStyle(color: kWhite.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  _HourSlider(
                    value: tempStart,
                    min: 0,
                    max: tempEnd - 1,
                    formatter: _fmt,
                    onChanged: (v) => setModal(() => tempStart = v),
                  ),

                  const SizedBox(height: 24),

                  // End hour
                  Text('End time', style: TextStyle(color: kWhite.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  _HourSlider(
                    value: tempEnd,
                    min: tempStart + 1,
                    max: 24,
                    formatter: _fmt,
                    onChanged: (v) => setModal(() => tempEnd = v),
                  ),

                  const SizedBox(height: 8),

                  // Range preview
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: kTeal.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kTeal.withOpacity(0.25)),
                      ),
                      child: Text(
                        '${_fmt(tempStart)} → ${_fmt(tempEnd)}  ·  ${tempEnd - tempStart}h visible',
                        style: const TextStyle(color: kTeal, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Buttons
                  Row(
                    children: [
                      // Reset to default
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setModal(() { tempStart = 6; tempEnd = 22; }),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: kWhite.withOpacity(0.2)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text('Reset', style: TextStyle(color: kWhite.withOpacity(0.6), fontSize: 14)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Apply
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            widget.onRangeChanged(tempStart, tempEnd);
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kTeal,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                          ),
                          child: const Text('Apply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final days     = _daysInMonth(_focusedMonth);
    final now      = DateTime.now();
    final weekDays = _weekDays();
    final screenW  = MediaQuery.of(context).size.width;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Mini calendar + filter panel ──────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 55,
                  child: _MiniCalendar(
                    days: days,
                    focusedMonth: _focusedMonth,
                    selectedDay: _selectedDay,
                    now: now,
                    monthLabel: '${_fullMonth(_focusedMonth.month)} ${_focusedMonth.year}',
                    visibleEvents: _visibleEvents,
                    allTasks: TaskStore.instance.tasks,
                    onPrev: () => setState(() =>
                      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1)),
                    onNext: () => setState(() =>
                      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1)),
                    onDayTap: (d) {
                      _fadeCtrl.forward(from: 0);
                      setState(() => _selectedDay = d);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                _LegendPanel(categories: _categories, onToggle: _toggleCategory),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Week header bar ───────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Container(
                  width: 3, height: 14,
                  decoration: BoxDecoration(
                    color: kTeal, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 8),
                Text(
                  'Week of ${weekDays.first.day} ${_shortMonth(weekDays.first.month)}',
                  style: TextStyle(
                    color: kWhite.withOpacity(0.75),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                // Task + Event badges
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_visibleTaskCount > 0)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          key: ValueKey('t$_visibleTaskCount'),
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: kTeal.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: kTeal.withOpacity(0.3)),
                          ),
                          child: Text(
                            '$_visibleTaskCount task${_visibleTaskCount == 1 ? '' : 's'}',
                            style: const TextStyle(
                                color: kTeal, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    if (_visibleTaskCount > 0 && _visibleEventCount > 0)
                      const SizedBox(width: 5),
                    if (_visibleEventCount > 0)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          key: ValueKey('e$_visibleEventCount'),
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A90D9).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF4A90D9).withOpacity(0.3)),
                          ),
                          child: Text(
                            '$_visibleEventCount event${_visibleEventCount == 1 ? '' : 's'}',
                            style: const TextStyle(
                                color: Color(0xFF4A90D9), fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    if (_visibleTaskCount == 0 && _visibleEventCount == 0 && _totalWeekTaskCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: kTeal.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kTeal.withOpacity(0.3)),
                        ),
                        child: const Text(
                          '0 tasks',
                          style: TextStyle(
                              color: kTeal, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
                // Settings button
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _openCalendarSettings,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: kWhite.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kWhite.withOpacity(0.1)),
                    ),
                    child: Icon(Icons.access_time_rounded,
                        color: kWhite.withOpacity(0.55), size: 14),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Weekly grid — explicit tall height, scrolls with page ─
          FadeTransition(
            opacity: CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn),
            child: _WeeklyGrid(
              weekDays: weekDays,
              now: now,
              visibleEvents: _visibleEvents,
              startHour: widget.startHour,
              endHour: widget.endHour,
              screenWidth: screenW,
              onEventTap: (taskId, isEvent) {
                if (isEvent) {
                  showEventDetailSheet(context, taskId);
                } else {
                  showTaskDetailSheet(context, taskId);
                }
              },
            ),
          ),

          // Bottom padding so last hours aren't hidden under the task sheet
          SizedBox(height: widget.peekHeight + 20),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Hour slider row
// ─────────────────────────────────────────────────────────────
class _HourSlider extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final String Function(int) formatter;
  final ValueChanged<int> onChanged;

  const _HourSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.formatter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            formatter(value),
            style: const TextStyle(
              color: kTeal,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: kTeal,
              inactiveTrackColor: kWhite.withOpacity(0.1),
              thumbColor: kTeal,
              overlayColor: kTeal.withOpacity(0.15),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value.toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: max - min,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Mini calendar
// ─────────────────────────────────────────────────────────────
class _MiniCalendar extends StatelessWidget {
  final List<DateTime> days;
  final DateTime focusedMonth, selectedDay, now;
  final String monthLabel;
  final List<PlanEvent> visibleEvents;
  final List<Task> allTasks;
  final VoidCallback onPrev, onNext;
  final void Function(DateTime) onDayTap;

  const _MiniCalendar({
    required this.days,
    required this.focusedMonth,
    required this.selectedDay,
    required this.now,
    required this.monthLabel,
    required this.visibleEvents,
    required this.allTasks,
    required this.onPrev,
    required this.onNext,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _IconBtn(icon: Icons.chevron_left_rounded, onTap: onPrev),
            Text(monthLabel,
              style: const TextStyle(
                color: kWhite, fontSize: 13,
                fontWeight: FontWeight.bold, letterSpacing: 0.1)),
            _IconBtn(icon: Icons.chevron_right_rounded, onTap: onNext),
          ],
        ),
        const SizedBox(height: 8),

        Row(
          children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
              .map((d) => Expanded(
                    child: Center(
                      child: Text(d,
                        style: TextStyle(
                          color: kTeal.withOpacity(0.6),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        )),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            childAspectRatio: 1.08,
          ),
          itemCount: days.length,
          itemBuilder: (_, index) {
            final day    = days[index];
            final isCur  = day.month == focusedMonth.month;
            final isToday = day.year == now.year && day.month == now.month && day.day == now.day;
            final isSel  = day.year == selectedDay.year &&
                day.month == selectedDay.month && day.day == selectedDay.day;

            final dots = isCur
                ? allTasks
                    .where((t) =>
                        t.dueDate.year  == day.year &&
                        t.dueDate.month == day.month &&
                        t.dueDate.day   == day.day)
                    .map((t) => t.category.color)
                    .take(3)
                    .toList()
                : <Color>[];

            return GestureDetector(
              onTap: () => onDayTap(day),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: isSel
                      ? kTeal
                      : isToday
                          ? kWhite.withOpacity(0.12)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${day.day}',
                      style: TextStyle(
                        color: isSel
                            ? kNavyDark
                            : isCur
                                ? kWhite
                                : kWhite.withOpacity(0.18),
                        fontSize: 11,
                        fontWeight: isToday || isSel
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    if (dots.isNotEmpty && !isSel) ...[
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: dots
                            .map((c) => Container(
                                  width: 3.5, height: 3.5,
                                  margin: const EdgeInsets.only(right: 1),
                                  decoration: BoxDecoration(
                                      color: c, shape: BoxShape.circle),
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Icon button
// ─────────────────────────────────────────────────────────────
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: kWhite.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: kWhite.withOpacity(0.7), size: 18),
        ),
      );
}

// ─────────────────────────────────────────────────────────────
// Legend / filter panel
// ─────────────────────────────────────────────────────────────
class _LegendPanel extends StatefulWidget {
  final List<PlanCategory> categories;
  final void Function(PlanCategory) onToggle;

  const _LegendPanel({required this.categories, required this.onToggle});

  @override
  State<_LegendPanel> createState() => _LegendPanelState();
}

class _LegendPanelState extends State<_LegendPanel> {
  bool _tasksExpanded = true;
  bool _eventsExpanded = true;

  static const _taskIds = {
    _kCatAssignment,
    _kCatProject,
    _kCatAssessment,
    _kCatPersonalTask,
  };
  static const _eventIds = {
    _kCatEventAcademic,
    _kCatEventPersonal,
    _kCatEventSocial,
    _kCatEventHealth,
    _kCatEventOther,
  };

  bool get _allTasksVisible =>
      widget.categories.where((c) => _taskIds.contains(c.id)).every((c) => c.visible);
  bool get _someTasksVisible =>
      widget.categories.where((c) => _taskIds.contains(c.id)).any((c) => c.visible);

  bool get _allEventsVisible =>
      widget.categories.where((c) => _eventIds.contains(c.id)).every((c) => c.visible);
  bool get _someEventsVisible =>
      widget.categories.where((c) => _eventIds.contains(c.id)).any((c) => c.visible);

  void _toggleAllTasks() {
    final target = !_allTasksVisible;
    for (final cat in widget.categories) {
      if (_taskIds.contains(cat.id) && cat.visible != target) {
        widget.onToggle(cat);
      }
    }
  }

  void _toggleAllEvents() {
    final target = !_allEventsVisible;
    for (final cat in widget.categories) {
      if (_eventIds.contains(cat.id) && cat.visible != target) {
        widget.onToggle(cat);
      }
    }
  }

  Widget _buildCheckbox(PlanCategory cat) {
    return GestureDetector(
      onTap: () => widget.onToggle(cat),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 5.0),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 12, height: 12,
              decoration: BoxDecoration(
                color: cat.visible ? cat.color : Colors.transparent,
                border: Border.all(
                  color: cat.visible ? cat.color : cat.color.withOpacity(0.35),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(3),
              ),
              child: cat.visible
                  ? const Icon(Icons.check_rounded, size: 8, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 160),
                style: TextStyle(
                  color: cat.visible ? kNavyDark : kNavyDark.withOpacity(0.25),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
                child: Text(cat.name, overflow: TextOverflow.ellipsis, maxLines: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParentRow({
    required String label,
    required bool allVisible,
    required bool someVisible,
    required Color color,
    required bool expanded,
    required VoidCallback onToggleAll,
    required VoidCallback onToggleExpand,
  }) {
    final parentColor = (allVisible || someVisible) ? color : color.withOpacity(0.3);
    return GestureDetector(
      onTap: onToggleExpand,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggleAll,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 12, height: 12,
              decoration: BoxDecoration(
                color: (allVisible || someVisible) ? parentColor : Colors.transparent,
                border: Border.all(color: parentColor, width: 1.5),
                borderRadius: BorderRadius.circular(3),
              ),
              child: allVisible
                  ? const Icon(Icons.check_rounded, size: 8, color: Colors.white)
                  : someVisible
                      ? const Icon(Icons.remove_rounded, size: 8, color: Colors.white)
                      : null,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(label,
              style: TextStyle(
                color: (allVisible || someVisible) ? kNavyDark : kNavyDark.withOpacity(0.25),
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          AnimatedRotation(
            turns: expanded ? 0 : -0.25,
            duration: const Duration(milliseconds: 160),
            child: Icon(Icons.expand_more_rounded, size: 13, color: kNavyDark.withOpacity(0.4)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskCats  = widget.categories.where((c) => _taskIds.contains(c.id)).toList();
    final eventCats = widget.categories.where((c) => _eventIds.contains(c.id)).toList();

    return Container(
      width: 120,
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 15.6),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 10, color: kNavyDark.withOpacity(0.4)),
              const SizedBox(width: 4),
              Text('FILTER',
                style: TextStyle(
                  color: kNavyDark.withOpacity(0.38),
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── TASKS group ─────────────────────────────
          _buildParentRow(
            label: 'Tasks',
            allVisible: _allTasksVisible,
            someVisible: _someTasksVisible,
            color: const Color(0xFF9B88E8),
            expanded: _tasksExpanded,
            onToggleAll: _toggleAllTasks,
            onToggleExpand: () => setState(() => _tasksExpanded = !_tasksExpanded),
          ),
          AnimatedCrossFade(
            firstChild: Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: taskCats.map(_buildCheckbox).toList(),
              ),
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: _tasksExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 180),
          ),

          // ── EVENTS group ────────────────────────────
          const SizedBox(height: 6),
          _buildParentRow(
            label: 'Events',
            allVisible: _allEventsVisible,
            someVisible: _someEventsVisible,
            color: const Color(0xFF4A90D9),
            expanded: _eventsExpanded,
            onToggleAll: _toggleAllEvents,
            onToggleExpand: () => setState(() => _eventsExpanded = !_eventsExpanded),
          ),
          AnimatedCrossFade(
            firstChild: Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: eventCats.map(_buildCheckbox).toList(),
              ),
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: _eventsExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Weekly time grid — fixed height, scrolls with the page
// ─────────────────────────────────────────────────────────────
class _WeeklyGrid extends StatefulWidget {
  final List<DateTime> weekDays;
  final DateTime now;
  final List<PlanEvent> visibleEvents;
  final int startHour;
  final int endHour;
  final double screenWidth;
  final void Function(String taskId, bool isEvent) onEventTap;

  const _WeeklyGrid({
    required this.weekDays,
    required this.now,
    required this.visibleEvents,
    required this.startHour,
    required this.endHour,
    required this.screenWidth,
    required this.onEventTap,
  });

  @override
  State<_WeeklyGrid> createState() => _WeeklyGridState();
}

class _WeeklyGridState extends State<_WeeklyGrid> {
  static const double _rowH  = 50.0;
  static const double _timeW = 36.0;
  static const double _gap   = 5.0;

  int get _hours => widget.endHour - widget.startHour;

  String _timeLabel(int hour) {
    if (hour < 12) return '${hour}am';
    if (hour == 12) return '12pm';
    return '${hour - 12}pm';
  }

  @override
  Widget build(BuildContext context) {
    const dayNames = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final gridW = widget.screenWidth - 28; // 14px padding each side
    final colW  = (gridW - _timeW - _gap) / 7;
    final totalH = _rowH * (_hours + 1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Day header ───────────────────────────────────
          Row(
            children: [
              SizedBox(width: _timeW + _gap),
              ...List.generate(7, (i) {
                final d = widget.weekDays[i];
                final isToday = d.year == widget.now.year &&
                    d.month == widget.now.month && d.day == widget.now.day;
                return Expanded(
                  child: Column(
                    children: [
                      Text(dayNames[i],
                        style: TextStyle(
                          color: isToday ? kTeal : kWhite.withOpacity(0.38),
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          color: isToday ? kTeal : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text('${d.day}',
                            style: TextStyle(
                              color: isToday ? kNavyDark : kWhite,
                              fontSize: 11,
                              fontWeight: isToday
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),

          const SizedBox(height: 4),

          // ── All-day strip (tasks with no time set) ────────
          _buildAllDayStrip(colW, gridW),

          const SizedBox(height: 4),

          // ── Full-height grid — scrolls with the page ──────
          SizedBox(
            width: gridW,
            height: totalH,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                ..._buildBackground(),
                ..._buildTimeLine(colW),
                ..._buildTimedEvents(colW),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBackground() {
    return List.generate(_hours + 1, (i) {
      final hour = widget.startHour + i;
      return Positioned(
        top: i * _rowH,
        left: 0,
        right: 0,
        height: _rowH,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _timeW,
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(_timeLabel(hour),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: kWhite.withOpacity(0.50),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SizedBox(width: _gap),
            ...List.generate(7, (col) {
              final isWknd = col >= 5;
              final isHalfHour = false; // placeholder for future
              return Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isWknd ? kWhite.withOpacity(0.03) : Colors.transparent,
                    border: Border(
                      top: BorderSide(
                        color: i == 0
                            ? kWhite.withOpacity(0.22)
                            : kWhite.withOpacity(0.07),
                        width: 0.5,
                      ),
                      left: BorderSide(
                        color: col == 0
                            ? kWhite.withOpacity(0.12)
                            : kWhite.withOpacity(0.06),
                        width: 0.5,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      );
    });
  }

  List<Widget> _buildTimeLine(double colW) {
    final todayIdx = widget.weekDays.indexWhere(
        (d) => d.day == widget.now.day &&
               d.month == widget.now.month &&
               d.year == widget.now.year);
    if (todayIdx < 0) return [];

    final fraction = (widget.now.hour + widget.now.minute / 60.0) - widget.startHour;
    if (fraction < 0 || fraction > _hours) return [];

    final top  = fraction * _rowH;
    final left = _timeW + _gap + todayIdx * colW;

    return [
      Positioned(
        top: top,
        left: left,
        width: colW,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 7, height: 7,
              decoration: const BoxDecoration(
                  color: kTeal, shape: BoxShape.circle),
            ),
            Expanded(child: Container(height: 1.5, color: kTeal)),
          ],
        ),
      ),
    ];
  }

  /// All-day strip — shows tasks that have no time set
  Widget _buildAllDayStrip(double colW, double gridW) {
    final allDayEvents = widget.visibleEvents.where((e) => !e.hasTime).toList();

    // Group by weekday column
    final Map<int, List<PlanEvent>> byCol = {};
    for (final e in allDayEvents) {
      final col = e.weekday - 1;
      if (col >= 0 && col <= 6) byCol.putIfAbsent(col, () => []).add(e);
    }

    final hasAny = byCol.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Time column label
        SizedBox(
          width: _timeW + _gap,
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              hasAny ? 'ALL\nDAY' : '',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: kWhite.withOpacity(0.35),
                fontSize: 7,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
        ),
        // 7 day columns
        ...List.generate(7, (col) {
          final events = byCol[col] ?? [];
          return SizedBox(
            width: colW,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: events.take(2).map((e) {
                return GestureDetector(
                  onTap: () => widget.onEventTap(e.taskId, e.isEvent),
                  child: Container(
                  margin: const EdgeInsets.only(bottom: 2, right: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                  decoration: BoxDecoration(
                    color: e.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: e.color.withOpacity(0.5), width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 3, height: 3,
                        margin: const EdgeInsets.only(right: 2),
                        decoration: BoxDecoration(color: e.color, shape: BoxShape.circle),
                      ),
                      Expanded(
                        child: Text(
                          e.title,
                          style: TextStyle(
                            color: e.color.withOpacity(0.9),
                            fontSize: 7,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _StatusPill(status: e.status),
                    ],
                  ),
                  ),
                );
              }).toList(),
            ),
          );
        }),
      ],
    );
  }

  List<Widget> _buildTimedEvents(double colW) {
    return widget.visibleEvents
        .where((e) => e.hasTime) // only timed tasks go in the grid
        .map((event) {
      final col = event.weekday - 1;
      if (col < 0 || col > 6) return const SizedBox.shrink();

      final top    = (event.startHour - widget.startHour) * _rowH;
      final height = (event.durationHours * _rowH - 4).clamp(18.0, double.infinity);
      final left   = _timeW + _gap + col * colW + 1.5;

      if (top > _rowH * _hours || top + height < 0) return const SizedBox.shrink();

      return Positioned(
        top: top,
        left: left,
        width: colW - 3,
        height: height,
        child: GestureDetector(
          onTap: () => widget.onEventTap(event.taskId, event.isEvent),
          child: _EventBlock(event: event),
        ),
      );
    }).toList();
  }
}

// ─────────────────────────────────────────────────────────────
// Event block
// ─────────────────────────────────────────────────────────────
class _EventBlock extends StatelessWidget {
  final PlanEvent event;
  const _EventBlock({required this.event});

  String _priorityLabel(TaskPriority p) {
    switch (p) {
      case TaskPriority.high:   return '!!!';
      case TaskPriority.medium: return '!!';
      case TaskPriority.low:    return '!';
    }
  }

  Color _priorityColor(TaskPriority p) {
    switch (p) {
      case TaskPriority.high:   return const Color(0xFFE87070);
      case TaskPriority.medium: return const Color(0xFFE8D870);
      case TaskPriority.low:    return const Color(0xFF3BBFA3);
    }
  }

  Color _statusColor(TaskStatus s) {
    switch (s) {
      case TaskStatus.completed:  return const Color(0xFF3BBFA3);
      case TaskStatus.inProgress: return const Color(0xFFE8D870);
      case TaskStatus.notStarted: return const Color(0xFF4A5568);
    }
  }

  String _formatHour(double h) {
    final hour   = h.floor();
    final minute = ((h - hour) * 60).round();
    final period = hour < 12 ? 'AM' : 'PM';
    final h12    = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return minute == 0 ? '$h12$period' : '$h12:${minute.toString().padLeft(2, '0')}$period';
  }

  @override
  Widget build(BuildContext context) {
    final priorityColor = _priorityColor(event.priority);
    final tall = event.durationHours >= 1.0;
    final veryTall = event.durationHours >= 1.5;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Background fill + uniform border
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: event.color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: event.color.withOpacity(0.3), width: 0.5),
              ),
            ),
          ),
          // Left accent bar
          Positioned(
            left: 0, top: 0, bottom: 0,
            width: 3,
            child: Container(color: event.color),
          ),
          // Status stripe — top edge coloured by task status
          Positioned(
            left: 3, top: 0, right: 0,
            height: 2.5,
            child: Container(
              decoration: BoxDecoration(
                color: _statusColor(event.status),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(6),
                ),
              ),
            ),
          ),
          // Content — clipped to box, no Expanded, no unbounded flex
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 2, 3, 2),
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minHeight: 0,
                maxHeight: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Priority dot + time row
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5, height: 5,
                          decoration: BoxDecoration(
                            color: priorityColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (tall && event.hasTime) ...[
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              '${_formatHour(event.startHour)}–${_formatHour(event.endHour)}',
                              style: TextStyle(
                                color: event.color.withOpacity(0.8),
                                fontSize: 7,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Title
                    Text(
                      event.title,
                      style: TextStyle(
                        color: event.color.withOpacity(0.95),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                      maxLines: tall ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Notes
                    if (veryTall && event.notes != null && event.notes!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        event.notes!,
                        style: TextStyle(
                          color: event.color.withOpacity(0.55),
                          fontSize: 7,
                          height: 1.3,
                          fontStyle: FontStyle.italic,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────
// Status pill — for all-day strip chips
// ─────────────────────────────────────────────────────────────
class _StatusPill extends StatelessWidget {
  final TaskStatus status;
  const _StatusPill({required this.status});

  Color get _color {
    switch (status) {
      case TaskStatus.completed:  return const Color(0xFF3BBFA3);
      case TaskStatus.inProgress: return const Color(0xFFE8D870);
      case TaskStatus.notStarted: return const Color(0xFF4A5568);
    }
  }

  String get _label {
    switch (status) {
      case TaskStatus.completed:  return '✓';
      case TaskStatus.inProgress: return '▶';
      case TaskStatus.notStarted: return '○';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 1),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: _color.withOpacity(0.5), width: 0.5),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: _color,
          fontSize: 6,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      ),
    );
  }
}