import 'package:flutter/material.dart';
import '../../constants/colors.dart';

// ─────────────────────────────────────────────────────────────
// Data models (shared across wallet_screen.dart + wallet_sheet.dart)
// ─────────────────────────────────────────────────────────────
enum WalletExpenseStatus { overdue, unpaid, paid, deducted }

class WalletExpense {
  final String name;
  final double amount;
  final String? savingNote;
  final String dateRange;
  final WalletExpenseStatus status;
  final IconData icon;
  final Color iconColor;

  const WalletExpense({
    required this.name,
    required this.amount,
    required this.dateRange,
    required this.status,
    required this.icon,
    required this.iconColor,
    this.savingNote,
  });
}

// ─────────────────────────────────────────────────────────────
// WalletSheet
// ─────────────────────────────────────────────────────────────
// Architecture: CustomScrollView at the root.
//
// The DraggableScrollableSheet requires its scrollController to attach to the
// direct-child scrollable of its builder. CustomScrollView satisfies this:
// dragging anywhere on the sheet — pinned header or expense list — travels
// through a single scroll controller. No nested SingleChildScrollViews.
//
// Pinned header (SliverAppBar, pinned: true):
//   drag handle + "Wallet" title + compact financial summary
//
// Scrollable content (underneath the pinned header):
//   SliverToBoxAdapter — section header "Upcoming Expenses"
//   SliverList          — upcoming expense items  (or SliverToBoxAdapter empty state)
//   SliverToBoxAdapter — spacer + section header "Recent Expenses"
//   SliverList          — recent expense items    (or SliverToBoxAdapter empty state)
//   SliverToBoxAdapter — spacer + section header "Savings Deduction"
//   SliverList          — deduction items         (or SliverToBoxAdapter empty state)
//   SliverToBoxAdapter — bottom padding
// ─────────────────────────────────────────────────────────────
class WalletSheet extends StatelessWidget {
  /// The ScrollController provided by DraggableScrollableSheet's builder.
  /// Must attach directly to the root CustomScrollView — never to a nested
  /// scrollable — to prevent SliverGeometry crashes and gesture conflicts.
  final ScrollController scrollController;

  // Financial summary values forwarded from WalletScreen.
  final double dailyAllowance;
  final double savings;
  final double monthlyBudget;
  final double budgetUsed; // 0.0–1.0

  // Expense lists
  final List<WalletExpense> upcoming;
  final List<WalletExpense> recent;
  final List<WalletExpense> deductions;

  const WalletSheet({
    super.key,
    required this.scrollController,
    required this.dailyAllowance,
    required this.savings,
    required this.monthlyBudget,
    required this.budgetUsed,
    required this.upcoming,
    required this.recent,
    required this.deductions,
  });

  // ── Pinned header height ───────────────────────────────────
  // Measured height of _WalletSheetHeader content:
  //   drag handle pill   (4px + 12 top margin + 16 bottom margin) = 32
  //   "Wallet" title row (≈ 24px text + 4 above + 4 below)        = 32
  //   divider + gap                                                =  9
  //   summary stats row  (≈ 3 × 42px compact cards, tallest ~42)  = 42
  //   bottom padding                                               = 12
  //   overflow buffer (+20 measured from RenderFlex debug)        = 20
  //   Total                                                        = 147
  static const double _headerHeight = 147.0;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      // The DraggableScrollableSheet scrollController attaches HERE — directly
      // to the one root scrollable. This is the canonical requirement.
      controller: scrollController,
      physics: const ClampingScrollPhysics(),
      slivers: [
        // ── Pinned header ────────────────────────────────────────────────
        // collapseMode: CollapseMode.none keeps the header fully rendered at
        // all scroll positions — no translate/fade from FlexibleSpaceBar.
        // toolbarHeight matches _headerHeight so SliverAppBar reports the
        // correct paintExtent and avoids layoutExtent > paintExtent crashes.
        SliverAppBar(
          pinned: true,
          automaticallyImplyLeading: false,
          backgroundColor: kWhite,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.black12,
          elevation: 0.5,
          toolbarHeight: _headerHeight,
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.none,
            background: _WalletSheetHeader(
              dailyAllowance: dailyAllowance,
              savings: savings,
              monthlyBudget: monthlyBudget,
              budgetUsed: budgetUsed,
              upcomingCount: upcoming.length,
            ),
          ),
        ),

        // ── Upcoming Expenses ────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _SheetSectionHeader(
            title: 'Upcoming Expenses',
            onSort: () {},
          ),
        ),
        SliverToBoxAdapter(child: const SizedBox(height: 8)),

        if (upcoming.isEmpty)
          SliverToBoxAdapter(
            child: _SheetEmptyState(
              icon: Icons.event_available_rounded,
              message: 'No upcoming expenses',
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _ExpenseItem(expense: upcoming[i]),
              childCount: upcoming.length,
            ),
          ),

        // ── Recent Expenses ──────────────────────────────────────────────
        SliverToBoxAdapter(child: const SizedBox(height: 20)),
        SliverToBoxAdapter(
          child: _SheetSectionHeader(
            title: 'Recent Expenses',
            onSort: () {},
          ),
        ),
        SliverToBoxAdapter(child: const SizedBox(height: 8)),

        if (recent.isEmpty)
          SliverToBoxAdapter(
            child: _SheetEmptyState(
              icon: Icons.receipt_long_rounded,
              message: 'No recent expenses',
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _ExpenseItem(expense: recent[i]),
              childCount: recent.length,
            ),
          ),

        // ── Savings Deduction ────────────────────────────────────────────
        SliverToBoxAdapter(child: const SizedBox(height: 20)),
        SliverToBoxAdapter(
          child: _SheetSectionHeader(
            title: 'Savings Deduction',
            onSort: () {},
          ),
        ),
        SliverToBoxAdapter(child: const SizedBox(height: 8)),

        if (deductions.isEmpty)
          SliverToBoxAdapter(
            child: _SheetEmptyState(
              icon: Icons.savings_rounded,
              message: 'No deductions yet',
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _ExpenseItem(expense: deductions[i]),
              childCount: deductions.length,
            ),
          ),

        // ── Bottom padding ───────────────────────────────────────────────
        SliverToBoxAdapter(child: const SizedBox(height: 80)),
      ],
    );
  }
}

// ── Pinned header widget ──────────────────────────────────────────────────────
// Plain StatelessWidget inside SliverAppBar's flexibleSpace.
// Using SliverAppBar(pinned: true) + FlexibleSpaceBar(collapseMode: none)
// avoids the layoutExtent/paintExtent mismatch crash from delegates.
class _WalletSheetHeader extends StatelessWidget {
  final double dailyAllowance;
  final double savings;
  final double monthlyBudget;
  final double budgetUsed;
  final int upcomingCount;

  const _WalletSheetHeader({
    required this.dailyAllowance,
    required this.savings,
    required this.monthlyBudget,
    required this.budgetUsed,
    required this.upcomingCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle — always visible at top of sheet.
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Title row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Wallet',
                style: TextStyle(
                  color: kNavyDark,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Upcoming badge
              if (upcomingCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A90D9).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$upcomingCount upcoming',
                    style: const TextStyle(
                      color: Color(0xFF4A90D9),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 4),
        const Divider(height: 1, indent: 20, endIndent: 20,
            color: Color(0xFFEEEEEE)),
        const SizedBox(height: 8),

        // Compact financial summary — 3 inline stat chips.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _CompactStat(
                icon: Icons.credit_card_rounded,
                iconColor: const Color(0xFF4A90D9),
                label: 'Allowance',
                value: '₱${dailyAllowance.toStringAsFixed(2)}',
              ),
              const SizedBox(width: 8),
              _CompactStat(
                icon: Icons.savings_rounded,
                iconColor: const Color(0xFF3BBFA3),
                label: 'Savings',
                value: '₱${savings.toStringAsFixed(2)}',
              ),
              const SizedBox(width: 8),
              _CompactStat(
                icon: Icons.account_balance_wallet_rounded,
                iconColor: const Color(0xFF9B88E8),
                label: 'Budget',
                value: '₱${monthlyBudget.toStringAsFixed(2)}',
                showProgress: true,
                progressValue: budgetUsed,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
      ],
    );
  }
}

// ── Compact stat chip (inside pinned header) ──────────────────────────────────
class _CompactStat extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool showProgress;
  final double progressValue;

  const _CompactStat({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.showProgress = false,
    this.progressValue = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 11, color: iconColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF6B7A99),
                      fontSize: 9,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: kNavyDark,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (showProgress) ...[
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progressValue,
                  minHeight: 3,
                  backgroundColor: const Color(0xFFEEEEEE),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFE87070)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sheet section header
// ─────────────────────────────────────────────────────────────
class _SheetSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSort;

  const _SheetSectionHeader({required this.title, this.onSort});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: kNavyDark,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          GestureDetector(
            onTap: onSort,
            child: const Row(
              children: [
                Text('Sorted by',
                    style: TextStyle(color: Color(0xFF6B7A99), fontSize: 12)),
                SizedBox(width: 3),
                Icon(Icons.arrow_drop_down,
                    color: Color(0xFF6B7A99), size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Empty state — inside white sheet
// ─────────────────────────────────────────────────────────────
class _SheetEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _SheetEmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: kNavyDark.withOpacity(0.1)),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                  color: kNavyDark.withOpacity(0.3), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Expense item row
// ─────────────────────────────────────────────────────────────
class _ExpenseItem extends StatelessWidget {
  final WalletExpense expense;

  const _ExpenseItem({required this.expense});

  Color get _badgeColor {
    switch (expense.status) {
      case WalletExpenseStatus.overdue:
        return const Color(0xFFE87070);
      case WalletExpenseStatus.unpaid:
        return const Color(0xFF4A90D9);
      case WalletExpenseStatus.paid:
        return const Color(0xFF3BBFA3);
      case WalletExpenseStatus.deducted:
        return const Color(0xFF9B88E8);
    }
  }

  String get _badgeLabel {
    switch (expense.status) {
      case WalletExpenseStatus.overdue:
        return 'Overdue ⚠';
      case WalletExpenseStatus.unpaid:
        return 'Unpaid';
      case WalletExpenseStatus.paid:
        return 'Paid';
      case WalletExpenseStatus.deducted:
        return 'Deducted';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon circle
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: expense.iconColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(expense.icon,
                      color: expense.iconColor, size: 17),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        expense.name,
                        style: const TextStyle(
                          color: kNavyDark,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _badgeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _badgeColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        _badgeLabel,
                        style: TextStyle(
                          color: _badgeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 3),

                // Amount + saving note
                Row(
                  children: [
                    Text(
                      '₱${expense.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: kNavyDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (expense.savingNote != null) ...[
                      const Text(' – ',
                          style: TextStyle(
                              color: Color(0xFF6B7A99), fontSize: 12)),
                      Text(
                        expense.savingNote!,
                        style: const TextStyle(
                          color: Color(0xFF6B7A99),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 2),

                // Date
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 11, color: Color(0xFF6B7A99)),
                    const SizedBox(width: 3),
                    Text(
                      expense.dateRange,
                      style: const TextStyle(
                          color: Color(0xFF6B7A99), fontSize: 11),
                    ),
                  ],
                ),

                const Divider(height: 16, color: Color(0xFFEEEEEE)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}