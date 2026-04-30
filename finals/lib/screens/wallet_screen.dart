import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../constants/colors.dart';
import '../widgets/wallet/wallet_sheet.dart';

// ─────────────────────────────────────────────────────────────
// Re-export public types so call-sites that imported them from
// wallet_screen.dart continue to compile without changes.
// ─────────────────────────────────────────────────────────────
export '../widgets/wallet/wallet_sheet.dart'
    show WalletExpense, WalletExpenseStatus;

// ─────────────────────────────────────────────────────────────
// Private background-only data models
// ─────────────────────────────────────────────────────────────
class _BudgetCategory {
  final String label;
  final double amount;
  final Color color;

  const _BudgetCategory({
    required this.label,
    required this.amount,
    required this.color,
  });
}

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

// ─────────────────────────────────────────────────────────────
// Sample data
// ─────────────────────────────────────────────────────────────
const _kDailyAllowance = 0.0;
const _kSavings        = 0.0;
const _kMonthlyBudget  = 0.0;
const _kBudgetUsed     = 0.0;

const List<_BudgetCategory> _kBudgetCategories = [];
const List<_HighPriorityBreakdown> _kHighPriorityBreakdown = [];
final List<_SavingsPoint> _kSavingsHistory = [];

const List<WalletExpense> _kUpcoming   = [];
const List<WalletExpense> _kRecent     = [];
const List<WalletExpense> _kDeductions = [];

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
    _sheetController = DraggableScrollableController();
    _sheetController.addListener(() {
      if (mounted) setState(() => _sheetSize = _sheetController.size);
    });
    widget.tabNotifier.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    widget.tabNotifier.removeListener(_onTabChanged);
    _sheetController.dispose();
    super.dispose();
  }

  // Collapse sheet when navigating away from the Wallet tab (index 3).
  // Resets the internal scroll position to top first so the drag handle is
  // always visible after the sheet collapses.
  void _onTabChanged() {
    if (!mounted) return;
    if (widget.tabNotifier.value == 3) return; // staying on wallet tab — no-op
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

    return Stack(
      children: [
        // ── BACKGROUND ────────────────────────────────────────
        Positioned.fill(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.only(bottom: screenHeight * _sheetSize),
              child: const _WalletBackground(),
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
                    dailyAllowance: _kDailyAllowance,
                    savings: _kSavings,
                    monthlyBudget: _kMonthlyBudget,
                    budgetUsed: _kBudgetUsed,
                    upcoming: _kUpcoming,
                    recent: _kRecent,
                    deductions: _kDeductions,
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

// ─────────────────────────────────────────────────────────────
// Background: summary cards + bar chart + donut + savings graph
// ─────────────────────────────────────────────────────────────
class _WalletBackground extends StatelessWidget {
  const _WalletBackground();

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
                  value: '₱${_kDailyAllowance.toStringAsFixed(2)}',
                  subtitle: 'Current Balance',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryCard(
                  icon: Icons.savings_rounded,
                  iconColor: const Color(0xFF3BBFA3),
                  title: 'Savings',
                  value: '₱${_kSavings.toStringAsFixed(2)}',
                  subtitle: 'Saved',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryCard(
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: const Color(0xFF9B88E8),
                  title: 'Monthly Budget',
                  value: '₱${_kMonthlyBudget.toStringAsFixed(2)}',
                  subtitle: null,
                  showProgress: true,
                  progressValue: _kBudgetUsed,
                  progressLabel: '${(_kBudgetUsed * 100).round()}% Used',
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Budget Allocation bar chart ───────────────────
          _SectionCard(
            title: 'Budget Allocation',
            action: 'Edit',
            child: _kBudgetCategories.isEmpty
                ? const _EmptyState(
                    icon: Icons.bar_chart_rounded,
                    message: 'No budget set yet',
                  )
                : _BarChart(categories: _kBudgetCategories),
          ),

          const SizedBox(height: 16),

          // ── High Priority breakdown donut ─────────────────
          _SectionCard(
            title: 'High Priority Expenses Breakdown',
            child: _HighPrioritySection(items: _kHighPriorityBreakdown),
          ),

          const SizedBox(height: 16),

          // ── Savings overview line graph ───────────────────
          _SectionCard(
            title: 'Savings Overview',
            child: _kSavingsHistory.isEmpty
                ? const _EmptyState(
                    icon: Icons.show_chart_rounded,
                    message: 'No savings recorded yet',
                  )
                : _SavingsChart(points: _kSavingsHistory),
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

  const _SummaryCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    this.subtitle,
    this.showProgress = false,
    this.progressValue = 0,
    this.progressLabel,
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
          if (showProgress) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progressValue,
                minHeight: 4,
                backgroundColor: kWhite.withOpacity(0.12),
                valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFFE87070)),
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
          ] else
            Text(
              subtitle ?? '',
              style: TextStyle(
                color: kWhite.withOpacity(0.5),
                fontSize: 10,
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
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
    this.action,
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
                Text(
                  action!,
                  style: const TextStyle(
                    color: kTeal,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                    decorationColor: kTeal,
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
// Bar chart (Budget Allocation)
// ─────────────────────────────────────────────────────────────
class _BarChart extends StatelessWidget {
  final List<_BudgetCategory> categories;

  const _BarChart({required this.categories});

  @override
  Widget build(BuildContext context) {
    const maxVal = 60.0;
    const chartH = 120.0;
    const gridLines = [0.0, 15.0, 30.0, 45.0, 60.0];

    return SizedBox(
      height: 170,
      child: Column(
        children: [
          SizedBox(
            height: chartH,
            child: Stack(
              children: [
                ...gridLines.map((v) {
                  final y = chartH - (v / maxVal) * chartH;
                  return Positioned(
                    top: y,
                    left: 0,
                    right: 0,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text(
                            '${v.toInt()}',
                            style: TextStyle(
                              color: kWhite.withOpacity(0.3),
                              fontSize: 8,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: kWhite.withOpacity(0.08),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                Positioned.fill(
                  left: 28,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: categories.map((cat) {
                      final barH = (cat.amount / maxVal) * chartH;
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '₱${cat.amount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: kWhite,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            width: 36,
                            height: barH,
                            decoration: BoxDecoration(
                              color: cat.color,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(5),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: categories
                  .map((cat) => SizedBox(
                        width: 60,
                        child: Text(
                          cat.label,
                          style: TextStyle(
                            color: kWhite.withOpacity(0.55),
                            fontSize: 9,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// High Priority section: donut on left, balance cards on right
// ─────────────────────────────────────────────────────────────
class _HighPrioritySection extends StatelessWidget {
  final List<_HighPriorityBreakdown> items;

  const _HighPrioritySection({required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 5,
          child: _HighPriorityDonut(items: items),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Column(
            children: const [
              _BalanceCard(label: 'Academics', balance: null),
              SizedBox(height: 10),
              _BalanceCard(label: 'Discretionary', balance: null),
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
  final double? balance;

  const _BalanceCard({required this.label, this.balance});

  @override
  Widget build(BuildContext context) {
    final isEmpty = balance == null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kNavyDark.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kWhite.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: kWhite,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isEmpty ? '—' : '₱${balance!.toStringAsFixed(2)}',
            style: TextStyle(
              color: isEmpty ? kWhite.withOpacity(0.25) : kWhite,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Balance',
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
                    isEmpty
                        ? '0%'
                        : '${(items.reduce((a, b) => a.amount > b.amount ? a : b).amount / total * 100).round()}%',
                    style: const TextStyle(
                      color: kWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    isEmpty
                        ? 'No data'
                        : items.reduce((a, b) => a.amount > b.amount ? a : b).label,
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

        Flexible(
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
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.label,
                                      style: const TextStyle(
                                        color: kWhite,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '₱${item.amount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: kWhite.withOpacity(0.5),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
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
class _SavingsChart extends StatelessWidget {
  final List<_SavingsPoint> points;

  const _SavingsChart({required this.points});

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
  final List<_SavingsPoint> points;

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
      final x = leftPad + (i / (points.length - 1)) * chartW;
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
      final x = leftPad + (i / (points.length - 1)) * chartW;
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