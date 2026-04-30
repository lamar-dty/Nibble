import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../widgets/calendar/weekly_planner_calendar.dart';
import '../widgets/calendar/task_home_sheet.dart';
import '../store/task_store.dart';

class CalendarScreen extends StatefulWidget {
  final int calStartHour;
  final int calEndHour;
  final void Function(int start, int end) onRangeChanged;
  final ValueNotifier<int> tabNotifier;

  const CalendarScreen({
    super.key,
    required this.calStartHour,
    required this.calEndHour,
    required this.onRangeChanged,
    required this.tabNotifier,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const double _snapPeek = 0.20;
  static const double _snapHalf = 0.50;
  static const double _snapFull = 1.0;

  late DraggableScrollableController _sheetController;

  // Holds the ScrollController provided by DraggableScrollableSheet's builder.
  // Updated every time the builder runs; used to reset scroll position to top
  // before collapsing the sheet on tab-away so the drag handle stays visible.
  ScrollController? _sheetScrollController;

  double _sheetSize = _snapPeek;

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
    _sheetController.addListener(_onSheetSizeChanged);
    widget.tabNotifier.addListener(_onTabChanged);
    TaskStore.instance.addListener(_onStoreChanged);
  }

  void _onSheetSizeChanged() {
    if (!mounted) return;
    setState(() => _sheetSize = _sheetController.size);
  }

  // Collapse sheet when navigating away from Calendar tab (index 1).
  // Resets the internal scroll position to top first so the drag handle is
  // always visible after the sheet collapses.
  void _onTabChanged() {
    if (!mounted) return;
    if (widget.tabNotifier.value == 1) return; // staying on calendar — no-op
    if (!_sheetController.isAttached) return;

    // Reset the task list scroll to top before collapsing.
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

  void _onStoreChanged() {
    if (!mounted) return;
    // When a task open is requested, expand the sheet to half so the
    // TaskHomeSheet is visible before it opens the detail modal.
    if (TaskStore.instance.pendingOpenTaskId != null) {
      _sheetController.animateTo(
        _snapHalf,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _sheetController.removeListener(_onSheetSizeChanged);
    _sheetController.dispose();
    widget.tabNotifier.removeListener(_onTabChanged);
    TaskStore.instance.removeListener(_onStoreChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final sheetHeightPx = screenHeight * _sheetSize;

    return Stack(
      children: [
        // ── CALENDAR BACKGROUND ──────────────────────────────
        Positioned.fill(
          child: WeeklyPlannerCalendar(
            peekHeight: sheetHeightPx,
            startHour: widget.calStartHour,
            endHour: widget.calEndHour,
            onRangeChanged: widget.onRangeChanged,
          ),
        ),

        // ── DRAGGABLE TASK SHEET ─────────────────────────────
        DraggableScrollableSheet(
          controller: _sheetController,
          initialChildSize: _snapPeek,
          minChildSize: _snapPeek,
          maxChildSize: _snapFull,
          snap: true,
          snapSizes: const [_snapPeek, _snapHalf, _snapFull],
          builder: (context, scrollController) {
            // Cache the scroll controller so _onTabChanged can reset it.
            // This controller is passed directly to TaskHomeSheet's
            // CustomScrollView — only the list scrolls, not the entire sheet.
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
                  child: TaskHomeSheet(
                    scrollController: scrollController,
                  ),
                ),
              ),
            );
          },
        ),

        // ── NAV BAR TOUCH BLOCKER ────────────────────────────
        // Prevents taps in the BottomAppBar zone from leaking
        // through to the DraggableScrollableSheet behind it.
        // Does NOT restrict sheet height or dragging behavior.
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 56,
          child: AbsorbPointer(absorbing: true),
        ),
      ],
    );
  }
}