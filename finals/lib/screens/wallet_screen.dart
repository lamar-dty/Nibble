import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../constants/colors.dart';
import '../widgets/wallet/wallet_sheet.dart';
import '../store/wallet_store.dart'; // also imports SavingsPoint
import '../widgets/create_wallet_entry_sheet.dart';

// ─────────────────────────────────────────────────────────────
// Re-export public types so call-sites that imported them from
// wallet_screen.dart continue to compile without changes.
// ─────────────────────────────────────────────────────────────
export '../widgets/wallet/wallet_sheet.dart'
    show WalletExpense, WalletExpenseStatus, WalletExpenseCategory;

// ─────────────────────────────────────────────────────────────
// Private background-only data models
// ─────────────────────────────────────────────────────────────
class _SavingsPoint {
  final String month;
  final double value;
  const _SavingsPoint(this.month, this.value);
}

class _HighPriorityBreakdown {
  final String label;
  final double amount;
  final Color color;
  const _HighPriorityBreakdown(this.label, this.amount, this.color);
}

// (All data now comes from WalletStore.instance — no hardcoded constants.)

// ─────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────
// Owns:
//   • tabNotifier listener + _onTabChanged collapse logic
//   • DraggableScrollableController + snapping logic
//   • scroll-reset guard on tab navigation
//   • DecoratedBox → ClipRRect → ColoredBox → WalletSheet structure
//   • background summary cards / charts
//
// Does NOT own:
//   • CustomScrollView (lives in WalletSheet)
//   • SliverAppBar     (lives in WalletSheet)
//   • expense sections (live in WalletSheet)
// ─────────────────────────────────────────────────────────────
class WalletScreen extends StatefulWidget {
  final ValueNotifier<int> tabNotifier;

  const WalletScreen({super.key, required this.tabNotifier});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  static const double _snapPeek = 0.20;
  static const double _snapHalf = 0.50;
  static const double _snapFull = 1.0;

  late DraggableScrollableController _sheetController;
  double _sheetSize = _snapPeek;

  // Holds the ScrollController provided by DraggableScrollableSheet's builder.
  // Retained so a future tab-change listener can reset scroll to top before
  // collapsing the sheet, keeping the drag handle always visible.
  ScrollController? _sheetScrollController;

  @override
  void initState() {
    super.initState();
    WalletStore.instance.load();
    _sheetController = DraggableScrollableController();
    _sheetController.addListener(() {
      if (mounted) setState(() => _sheetSize = _sheetController.size);
    });
    widget.tabNotifier.addListener(_onTabChanged);
    WalletStore.instance.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    widget.tabNotifier.removeListener(_onTabChanged);
    WalletStore.instance.removeListener(_onStoreChanged);
    _sheetController.dispose();
    super.dispose();
  }

  // Called whenever WalletStore notifies — checks for a pending open signal
  // and expands the sheet to half-height, mirroring calendar_screen behaviour.
  void _onStoreChanged() {
    if (!mounted) return;
    if (!WalletStore.instance.pendingOpenWallet) return;
    WalletStore.instance.clearPendingOpenWallet();
    if (!_sheetController.isAttached) return;
    _sheetController.animateTo(
      _snapHalf,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  // Collapse sheet when navigating away from the Wallet tab (index 3).
  // Resets the internal scroll position to top first so the drag handle is
  // always visible after the sheet collapses.
  void _onTabChanged() {
    if (!mounted) return;
    if (widget.tabNotifier.value == 3) {
      // Navigated to wallet tab — sweep for newly overdue / due-soon expenses.
      WalletStore.instance.recomputeOverdue();
      return;
    }
    if (!_sheetController.isAttached) return;

    // Reset the expense list scroll to top before collapsing.
    // Guards: controller must have clients and position pixels must be above
    // minScrollExtent to avoid jumpTo exceptions on already-topped lists.
    _resetScrollToTop();

    _sheetController.animateTo(
      _snapPeek,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  // Scroll-reset guard — called by _onTabChanged before animateTo(_snapPeek).
  // Mirrors the pattern in HomeScreen / SpacesScreen.
  void _resetScrollToTop() {
    final sc = _sheetScrollController;
    if (sc == null || !sc.hasClients) return;
    try {
      final pos = sc.position;
      if (pos.pixels > pos.minScrollExtent) {
        sc.jumpTo(pos.minScrollExtent);
      }
    } catch (_) {
      // Controller detached or position unavailable — safe to ignore.
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return ListenableBuilder(
      listenable: WalletStore.instance,
      builder: (context, _) {
        final wallet = WalletStore.instance;

    return Stack(
      children: [
        // ── BACKGROUND ────────────────────────────────────────
        Positioned.fill(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.only(bottom: screenHeight * _sheetSize),
              child: _WalletBackground(
                dailyAllowance:    wallet.dailyAllowance,
                dailyRemaining:    wallet.dailyRemaining,
                savings:           wallet.savings,
                monthlyBudget:     wallet.monthlyBudget,
                budgetUsedFraction: wallet.budgetUsedFraction,
                monthlySpent:      wallet.monthlySpent,
                highPriorityBreakdown: [
                  for (final cat in WalletExpenseCategory.values)
                    if (cat.isHighPriority && wallet.totalForCategory(cat) > 0)
                      _HighPriorityBreakdown(
                        cat.label,
                        wallet.totalForCategory(cat),
                        cat.color,
                      ),
                ],
                savingsHistory:      wallet.savingsHistory,
                monthlySpendHistory: wallet.monthlySpendHistory,
                schoolTotal: wallet.totalForCategory(WalletExpenseCategory.school),
                healthTotal: wallet.totalForCategory(WalletExpenseCategory.health),
              ),
            ),
          ),
        ),

        // ── DRAGGABLE WALLET SHEET ────────────────────────────────────────
        // Canonical architecture: DecoratedBox (shadow) → ClipRRect (rounded
        // corners) → ColoredBox → WalletSheet (CustomScrollView root).
        // The DraggableScrollableSheet scrollController is cached in
        // _sheetScrollController and passed directly into WalletSheet so it
        // attaches to the CustomScrollView root — the only scrollable that
        // drives sheet drag, header pinning, and list scroll from one axis.
        DraggableScrollableSheet(
          controller: _sheetController,
          initialChildSize: _snapPeek,
          minChildSize: _snapPeek,
          maxChildSize: _snapFull,
          snap: true,
          snapSizes: const [_snapPeek, _snapHalf, _snapFull],
          builder: (context, scrollController) {
            // Cache for scroll-reset guard.
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
                  child: WalletSheet(
                    scrollController: scrollController,
                    dailyAllowance: wallet.dailyAllowance,
                    savings: wallet.savings,
                    monthlyBudget: wallet.monthlyBudget,
                    budgetUsed: wallet.budgetUsedFraction,
                    // Tag each expense with its original store index so the
                    // filtered sub-lists can still address the right item.
                    upcoming: [
                      for (int i = 0; i < wallet.expenses.length; i++)
                        if (wallet.expenses[i].status == WalletExpenseStatus.unpaid ||
                            wallet.expenses[i].status == WalletExpenseStatus.overdue)
                          IndexedExpense(expense: wallet.expenses[i], storeIndex: i),
                    ],
                    recent: [
                      for (int i = 0; i < wallet.expenses.length; i++)
                        if (wallet.expenses[i].status == WalletExpenseStatus.paid)
                          IndexedExpense(expense: wallet.expenses[i], storeIndex: i),
                    ],
                    savingsLog: wallet.savingsLog,
                    onTogglePaid: (index) =>
                        WalletStore.instance.toggleExpensePaidUnpaid(index),
                    onDeleteExpense: (index) =>
                        WalletStore.instance.removeExpense(index),
                    onAddToSavings: (amount, note) =>
                        WalletStore.instance.addToSavings(amount, note: note),
                    onWithdrawFromSavings: (amount, note) =>
                        WalletStore.instance.withdrawFromSavings(amount, note: note),
                    onClearSavingsLog: () =>
                        WalletStore.instance.clearSavingsLog(),
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
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Background: summary cards + bar chart + donut + savings graph
// ─────────────────────────────────────────────────────────────
class _WalletBackground extends StatelessWidget {
  final double dailyAllowance;
  final double dailyRemaining;
  final double savings;
  final double monthlyBudget;
  final double budgetUsedFraction;
  final double monthlySpent;
  final List<_HighPriorityBreakdown> highPriorityBreakdown;
  final List<SavingsPoint> savingsHistory;
  final List<MonthlySpendPoint> monthlySpendHistory;
  final double schoolTotal;
  final double healthTotal;

  const _WalletBackground({
    required this.dailyAllowance,
    required this.dailyRemaining,
    required this.savings,
    required this.monthlyBudget,
    required this.budgetUsedFraction,
    required this.monthlySpent,
    required this.highPriorityBreakdown,
    required this.savingsHistory,
    required this.monthlySpendHistory,
    required this.schoolTotal,
    required this.healthTotal,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Summary cards row ─────────────────────────────
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  icon: Icons.credit_card_rounded,
                  iconColor: const Color(0xFF4A90D9),
                  title: 'Daily Allowance',
                  value: '₱${dailyAllowance.toStringAsFixed(2)}',
                  subtitle: dailyRemaining >= 0
                      ? '₱${dailyRemaining.toStringAsFixed(2)} left today'
                      : '₱${(-dailyRemaining).toStringAsFixed(2)} over today',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryCard(
                  icon: Icons.savings_rounded,
                  iconColor: const Color(0xFF3BBFA3),
                  title: 'Savings',
                  value: '₱${savings.toStringAsFixed(2)}',
                  subtitle: 'Total saved',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryCard(
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: budgetUsedFraction >= 1.0
                      ? const Color(0xFFE87070)
                      : budgetUsedFraction >= 0.8
                          ? const Color(0xFFF5A623)
                          : const Color(0xFF9B88E8),
                  title: 'Monthly Budget',
                  value: '₱${monthlyBudget.toStringAsFixed(2)}',
                  subtitle: null,
                  showProgress: true,
                  progressValue: budgetUsedFraction,
                  progressColor: budgetUsedFraction >= 1.0
                      ? const Color(0xFFE87070)
                      : budgetUsedFraction >= 0.8
                          ? const Color(0xFFF5A623)
                          : const Color(0xFF9B88E8),
                  progressLabel: monthlyBudget > 0
                      ? '₱${monthlySpent.toStringAsFixed(2)} spent'
                      : 'Not set',
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Monthly Spending History line chart ───────────
          _SectionCard(
            title: 'Monthly Spending History',
            child: monthlySpendHistory.isEmpty
                ? const _EmptyState(
                    icon: Icons.bar_chart_rounded,
                    message: 'History builds at each month rollover',
                  )
                : _MonthlySpendLineChart(points: monthlySpendHistory),
          ),

          const SizedBox(height: 16),

          // ── High Priority breakdown donut ─────────────────
          _SectionCard(
            title: 'High Priority Expenses Breakdown',
            child: _HighPrioritySection(
              items: highPriorityBreakdown,
              schoolTotal: schoolTotal,
              healthTotal: healthTotal,
            ),
          ),

          const SizedBox(height: 16),

          // ── Savings overview line graph ───────────────────
          _SectionCard(
            title: 'Savings Overview',
            child: savingsHistory.isEmpty
                ? const _EmptyState(
                    icon: Icons.show_chart_rounded,
                    message: 'No savings recorded yet',
                  )
                : _SavingsLineChart(points: savingsHistory),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Summary card (top row — navy background)
// ─────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String? subtitle;
  final bool showProgress;
  final double progressValue;
  final String? progressLabel;

  final Color? progressColor;

  const _SummaryCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    this.subtitle,
    this.showProgress = false,
    this.progressValue = 0,
    this.progressLabel,
    this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
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
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: kWhite.withOpacity(0.7),
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: kWhite,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          // Fixed-height bottom section keeps all three cards the same height.
          SizedBox(
            height: 24,
            child: showProgress
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progressValue,
                          minHeight: 4,
                          backgroundColor: kWhite.withOpacity(0.12),
                          valueColor: AlwaysStoppedAnimation<Color>(
                              progressColor ?? const Color(0xFFE87070)),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        progressLabel ?? '',
                        style: TextStyle(
                          color: kWhite.withOpacity(0.5),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  )
                : Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      subtitle ?? '',
                      style: TextStyle(
                        color: kWhite.withOpacity(0.5),
                        fontSize: 10,
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
// Section card wrapper (navy card with title + optional action)
// ─────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kNavyMid,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kWhite.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: kWhite,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (action != null)
                GestureDetector(
                  onTap: onAction,
                  child: Text(
                    action!,
                    style: const TextStyle(
                      color: kTeal,
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                      decorationColor: kTeal,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Monthly Spending History line chart
// ─────────────────────────────────────────────────────────────
class _MonthlySpendLineChart extends StatelessWidget {
  final List<MonthlySpendPoint> points;

  const _MonthlySpendLineChart({required this.points});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: CustomPaint(
        painter: _MonthlySpendLinePainter(points: points),
        child: Container(),
      ),
    );
  }
}

class _MonthlySpendLinePainter extends CustomPainter {
  final List<MonthlySpendPoint> points;

  const _MonthlySpendLinePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const leftPad   = 36.0;
    const bottomPad = 20.0;
    final chartW = size.width - leftPad;
    final chartH = size.height - bottomPad;

    // Determine max value across spent + budget for Y axis.
    double maxVal = 0;
    for (final p in points) {
      if (p.spent  > maxVal) maxVal = p.spent;
      if (p.budget > maxVal) maxVal = p.budget;
    }
    if (maxVal <= 0) maxVal = 1000;
    // Round up to a nice ceiling.
    maxVal = (maxVal * 1.15).ceilToDouble();

    double yOf(double v) =>
        chartH - (v / maxVal * chartH).clamp(0.0, chartH);

    double xOf(int i) => points.length == 1
        ? leftPad + chartW / 2
        : leftPad + (i / (points.length - 1)) * chartW;

    final gridPaint = Paint()
      ..color = kWhite.withOpacity(0.08)
      ..strokeWidth = 1;

    final labelStyle = TextStyle(
      color: kWhite.withOpacity(0.35),
      fontSize: 8,
    );

    // ── 4 grid lines ────────────────────────────────────────
    for (int g = 0; g <= 4; g++) {
      final v = maxVal * g / 4;
      final y = yOf(v);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), gridPaint);
      final label = v >= 1000
          ? '${(v / 1000).toStringAsFixed(1)}k'
          : v.toStringAsFixed(0);
      final tp = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - 5));
    }

    // ── Month labels on X axis ───────────────────────────────
    for (int i = 0; i < points.length; i++) {
      final tp = TextPainter(
        text: TextSpan(text: points[i].month, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(xOf(i) - tp.width / 2, size.height - 14));
    }

    // ── Budget line (dashed purple) ──────────────────────────
    final budgetPts = <Offset>[
      for (int i = 0; i < points.length; i++)
        Offset(xOf(i), yOf(points[i].budget)),
    ];
    final budgetPaint = Paint()
      ..color = const Color(0xFF9B88E8).withOpacity(0.55)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const dashLen = 5.0;
    const gapLen  = 4.0;
    for (int i = 0; i < budgetPts.length - 1; i++) {
      final a = budgetPts[i];
      final b = budgetPts[i + 1];
      final dx = b.dx - a.dx;
      final dy = b.dy - a.dy;
      final dist = math.sqrt(dx * dx + dy * dy);
      double drawn = 0;
      bool drawing = true;
      while (drawn < dist) {
        final seg = math.min(drawing ? dashLen : gapLen, dist - drawn);
        final t0 = drawn / dist;
        final t1 = (drawn + seg) / dist;
        if (drawing) {
          canvas.drawLine(
            Offset(a.dx + dx * t0, a.dy + dy * t0),
            Offset(a.dx + dx * t1, a.dy + dy * t1),
            budgetPaint,
          );
        }
        drawn += seg;
        drawing = !drawing;
      }
    }

    // ── Spent line (solid teal) ──────────────────────────────
    final spentPts = <Offset>[
      for (int i = 0; i < points.length; i++)
        Offset(xOf(i), yOf(points[i].spent)),
    ];

    final fillPath = Path();
    final linePath = Path();

    fillPath.moveTo(spentPts[0].dx, chartH);
    fillPath.lineTo(spentPts[0].dx, spentPts[0].dy);
    linePath.moveTo(spentPts[0].dx, spentPts[0].dy);

    for (int i = 1; i < spentPts.length; i++) {
      final cp1 = Offset(
          (spentPts[i - 1].dx + spentPts[i].dx) / 2, spentPts[i - 1].dy);
      final cp2 =
          Offset((spentPts[i - 1].dx + spentPts[i].dx) / 2, spentPts[i].dy);
      linePath.cubicTo(
          cp1.dx, cp1.dy, cp2.dx, cp2.dy, spentPts[i].dx, spentPts[i].dy);
      fillPath.cubicTo(
          cp1.dx, cp1.dy, cp2.dx, cp2.dy, spentPts[i].dx, spentPts[i].dy);
    }
    fillPath.lineTo(spentPts.last.dx, chartH);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [kTeal.withOpacity(0.30), kTeal.withOpacity(0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    canvas.drawPath(
      linePath,
      Paint()
        ..color = kTeal
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (final pt in spentPts) {
      canvas.drawCircle(pt, 3, Paint()..color = kTeal);
      canvas.drawCircle(
          pt,
          3,
          Paint()
            ..color = kWhite
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => true;
}

// ─────────────────────────────────────────────────────────────
// High Priority section: donut on left, balance cards on right
// ─────────────────────────────────────────────────────────────
class _HighPrioritySection extends StatelessWidget {
  final List<_HighPriorityBreakdown> items;
  final double schoolTotal;
  final double healthTotal;

  const _HighPrioritySection({
    required this.items,
    required this.schoolTotal,
    required this.healthTotal,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 7,
          child: _HighPriorityDonut(items: items),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _BalanceCard(
                label: 'School',
                icon: Icons.school_rounded,
                color: const Color(0xFF9B88E8),
                total: schoolTotal > 0 ? schoolTotal : null,
              ),
              const SizedBox(height: 10),
              _BalanceCard(
                label: 'Health',
                icon: Icons.favorite_rounded,
                color: const Color(0xFF3BBFA3),
                total: healthTotal > 0 ? healthTotal : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Small rounded balance card
// ─────────────────────────────────────────────────────────────
class _BalanceCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final double? total;

  const _BalanceCard({
    required this.label,
    required this.icon,
    required this.color,
    this.total,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = total == null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: kNavyDark.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kWhite.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isEmpty ? '—' : '₱${total!.toStringAsFixed(2)}',
            style: TextStyle(
              color: isEmpty ? kWhite.withOpacity(0.25) : kWhite,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Total spent',
            style: TextStyle(
              color: kWhite.withOpacity(0.4),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// High Priority donut + legend
// ─────────────────────────────────────────────────────────────
class _HighPriorityDonut extends StatelessWidget {
  final List<_HighPriorityBreakdown> items;

  const _HighPriorityDonut({required this.items});

  @override
  Widget build(BuildContext context) {
    final isEmpty = items.isEmpty;
    final total = isEmpty ? 0.0 : items.fold(0.0, (s, i) => s + i.amount);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: CustomPaint(
            painter: _HighPriorityDonutPainter(items: items, total: total),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isEmpty ? '₱0' : '₱${total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: kWhite,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Total',
                    style: TextStyle(
                      color: kWhite.withOpacity(0.6),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: isEmpty
              ? Text(
                  'No expenses\nadded yet',
                  style: TextStyle(
                    color: kWhite.withOpacity(0.3),
                    fontSize: 12,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: items
                      .map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: item.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.label,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: kWhite,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '₱${item.amount.toStringAsFixed(0)}  ·  ${(item.amount / total * 100).round()}%',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: kWhite.withOpacity(0.5),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _HighPriorityDonutPainter extends CustomPainter {
  final List<_HighPriorityBreakdown> items;
  final double total;

  const _HighPriorityDonutPainter({required this.items, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const stroke = 20.0;
    const pi = math.pi;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(rect, 0, 2 * pi, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = kWhite.withOpacity(0.12));

    if (total == 0) return;

    double start = -pi / 2;
    for (final item in items) {
      final sweep = 2 * pi * (item.amount / total);
      if (sweep <= 0) continue;
      canvas.drawArc(rect, start, sweep, false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round
            ..color = item.color);
      start += sweep + 0.05;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─────────────────────────────────────────────────────────────
// Savings line chart
// ─────────────────────────────────────────────────────────────
class _SavingsLineChart extends StatelessWidget {
  final List<SavingsPoint> points;

  const _SavingsLineChart({required this.points});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: CustomPaint(
        painter: _SavingsLinePainter(points: points),
        child: Container(),
      ),
    );
  }
}

class _SavingsLinePainter extends CustomPainter {
  final List<SavingsPoint> points;

  const _SavingsLinePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final gridValues = [0.0, 10.0, 100.0, 1000.0, 10000.0];
    const maxVal = 10000.0;
    const leftPad = 36.0;
    const bottomPad = 20.0;
    final chartW = size.width - leftPad;
    final chartH = size.height - bottomPad;

    double logY(double v) {
      if (v <= 0) return chartH;
      final logMax = math.log(maxVal + 1);
      final logV = math.log(v + 1);
      return chartH - (logV / logMax) * chartH;
    }

    final gridPaint = Paint()
      ..color = kWhite.withOpacity(0.08)
      ..strokeWidth = 1;

    final labelStyle = TextStyle(
      color: kWhite.withOpacity(0.35),
      fontSize: 8,
    );

    for (final v in gridValues) {
      final y = logY(v);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(
            text: v >= 1000
                ? '${(v / 1000).toStringAsFixed(0)}k'
                : v.toStringAsFixed(0),
            style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - 5));
    }

    for (int i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? leftPad + chartW / 2
          : leftPad + (i / (points.length - 1)) * chartW;
      final tp = TextPainter(
        text: TextSpan(text: points[i].month, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - 14));
    }

    final path = Path();
    final fillPath = Path();
    final pts = <Offset>[];

    for (int i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? leftPad + chartW / 2
          : leftPad + (i / (points.length - 1)) * chartW;
      final y = logY(points[i].value);
      pts.add(Offset(x, y));
    }

    path.moveTo(pts[0].dx, pts[0].dy);
    fillPath.moveTo(pts[0].dx, chartH);
    fillPath.lineTo(pts[0].dx, pts[0].dy);

    for (int i = 1; i < pts.length; i++) {
      final cp1 = Offset((pts[i - 1].dx + pts[i].dx) / 2, pts[i - 1].dy);
      final cp2 = Offset((pts[i - 1].dx + pts[i].dx) / 2, pts[i].dy);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i].dx, pts[i].dy);
      fillPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i].dx, pts[i].dy);
    }

    fillPath.lineTo(pts.last.dx, chartH);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            kTeal.withOpacity(0.35),
            kTeal.withOpacity(0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = kTeal
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    for (final pt in pts) {
      canvas.drawCircle(pt, 3, Paint()..color = kTeal);
      canvas.drawCircle(
          pt,
          3,
          Paint()
            ..color = kWhite
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─────────────────────────────────────────────────────────────
// Empty state — inside navy section card (background only)
// ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: kWhite.withOpacity(0.12)),
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(color: kWhite.withOpacity(0.3), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}