import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../store/wallet_store.dart' show SavingsEntry;

// ─────────────────────────────────────────────────────────────
// Data models (shared across wallet_screen.dart + wallet_sheet.dart)
// ─────────────────────────────────────────────────────────────
enum WalletExpenseStatus { overdue, unpaid, paid }

// ─────────────────────────────────────────────────────────────
// Expense category — drives icon, color, and chart grouping.
// ─────────────────────────────────────────────────────────────
enum WalletExpenseCategory {
  food,
  transport,
  school,
  health,
  other;

  bool get isHighPriority =>
      this == WalletExpenseCategory.school ||
      this == WalletExpenseCategory.health;

  IconData get icon {
    switch (this) {
      case WalletExpenseCategory.food:      return Icons.fastfood_rounded;
      case WalletExpenseCategory.transport: return Icons.directions_bus_rounded;
      case WalletExpenseCategory.school:    return Icons.school_rounded;
      case WalletExpenseCategory.health:    return Icons.favorite_rounded;
      case WalletExpenseCategory.other:     return Icons.receipt_long_rounded;
    }
  }

  Color get color {
    switch (this) {
      case WalletExpenseCategory.food:      return const Color(0xFFE87070);
      case WalletExpenseCategory.transport: return const Color(0xFF4A90D9);
      case WalletExpenseCategory.school:    return const Color(0xFF9B88E8);
      case WalletExpenseCategory.health:    return const Color(0xFF3BBFA3);
      case WalletExpenseCategory.other:     return const Color(0xFF6B7A99);
    }
  }

  String get label {
    switch (this) {
      case WalletExpenseCategory.food:      return 'Food';
      case WalletExpenseCategory.transport: return 'Transport';
      case WalletExpenseCategory.school:    return 'School';
      case WalletExpenseCategory.health:    return 'Health';
      case WalletExpenseCategory.other:     return 'Other';
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Sort options for expense lists
// ─────────────────────────────────────────────────────────────
enum _WalletSortBy { dueDate, amount, status, category }

class WalletExpense {
  final String name;
  final double amount;
  final String? savingNote;
  final String dateRange;
  final DateTime? dueDate;
  final WalletExpenseStatus status;
  final IconData icon;
  final Color iconColor;
  final WalletExpenseCategory category;
  final DateTime? paidAt; // set when status becomes paid

  const WalletExpense({
    required this.name,
    required this.amount,
    required this.dateRange,
    required this.status,
    required this.icon,
    required this.iconColor,
    this.savingNote,
    this.dueDate,
    this.paidAt,
    this.category = WalletExpenseCategory.other,
  });

  WalletExpense copyWith({
    String? name,
    double? amount,
    String? savingNote,
    String? dateRange,
    DateTime? dueDate,
    DateTime? paidAt,
    bool clearPaidAt = false,
    WalletExpenseStatus? status,
    IconData? icon,
    Color? iconColor,
    WalletExpenseCategory? category,
  }) {
    return WalletExpense(
      name:      name      ?? this.name,
      amount:    amount    ?? this.amount,
      dateRange: dateRange ?? this.dateRange,
      dueDate:   dueDate   ?? this.dueDate,
      paidAt:    clearPaidAt ? null : (paidAt ?? this.paidAt),
      status:    status    ?? this.status,
      icon:      icon      ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
      savingNote: savingNote ?? this.savingNote,
      category:  category  ?? this.category,
    );
  }

  Map<String, dynamic> toJson() => {
    'name':      name,
    'amount':    amount,
    'dateRange': dateRange,
    'status':    status.index,
    'icon':      icon.codePoint,
    'iconFontFamily': icon.fontFamily,
    'iconColor': iconColor.value,
    'category':  category.index,
    if (paidAt != null) 'paidAt': paidAt!.toIso8601String(),
    if (savingNote != null) 'savingNote': savingNote,
    if (dueDate != null) 'dueDate': dueDate!.toIso8601String(),
  };

  factory WalletExpense.fromJson(Map<String, dynamic> json) {
    final statusIndex = (json['status'] as num?)?.toInt() ?? 1;
    final status = WalletExpenseStatus.values[
        statusIndex.clamp(0, WalletExpenseStatus.values.length - 1)];

    // Parse dueDate — gracefully ignore corrupt values.
    DateTime? dueDate;
    final dueDateRaw = json['dueDate'] as String?;
    if (dueDateRaw != null) {
      try { dueDate = DateTime.parse(dueDateRaw); } catch (_) {}
    }

    final catIndex = (json['category'] as num?)?.toInt() ?? 5;
    final category = WalletExpenseCategory.values[
        catIndex.clamp(0, WalletExpenseCategory.values.length - 1)];

    DateTime? paidAt;
    final paidAtRaw = json['paidAt'] as String?;
    if (paidAtRaw != null) {
      try { paidAt = DateTime.parse(paidAtRaw); } catch (_) {}
    }

    return WalletExpense(
      name:       json['name']      as String,
      amount:     (json['amount']   as num).toDouble(),
      dateRange:  json['dateRange'] as String,
      dueDate:    dueDate,
      paidAt:     paidAt,
      status:     status,
      icon:       IconData(
        (json['icon'] as num).toInt(),
        fontFamily: json['iconFontFamily'] as String? ?? 'MaterialIcons',
      ),
      iconColor:  Color((json['iconColor'] as num).toInt()),
      savingNote: json['savingNote'] as String?,
      category:   category,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// WalletSheet
// ─────────────────────────────────────────────────────────────
class WalletSheet extends StatefulWidget {
  final ScrollController scrollController;

  final double dailyAllowance;
  final double savings;
  final double monthlyBudget;
  final double budgetUsed;

  final List<WalletExpense> upcoming;
  final List<WalletExpense> recent;
  final List<SavingsEntry> savingsLog;

  final void Function(int index)? onTogglePaid;
  final void Function(int index)? onDeleteExpense;
  final void Function(double amount, String? note)? onAddToSavings;
  final void Function(double amount, String? note)? onWithdrawFromSavings;
  final VoidCallback? onClearSavingsLog;

  const WalletSheet({
    super.key,
    required this.scrollController,
    required this.dailyAllowance,
    required this.savings,
    required this.monthlyBudget,
    required this.budgetUsed,
    required this.upcoming,
    required this.recent,
    required this.savingsLog,
    this.onTogglePaid,
    this.onDeleteExpense,
    this.onAddToSavings,
    this.onWithdrawFromSavings,
    this.onClearSavingsLog,
  });

  @override
  State<WalletSheet> createState() => _WalletSheetState();
}

class _WalletSheetState extends State<WalletSheet> {
  static const double _headerHeight = 147.0;

  _WalletSortBy _upcomingSort = _WalletSortBy.dueDate;
  _WalletSortBy _recentSort   = _WalletSortBy.dueDate;

  List<WalletExpense> _sorted(List<WalletExpense> list, _WalletSortBy sort) {
    final copy = List<WalletExpense>.from(list);
    switch (sort) {
      case _WalletSortBy.dueDate:
        copy.sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
        break;
      case _WalletSortBy.amount:
        copy.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case _WalletSortBy.status:
        const order = {
          WalletExpenseStatus.overdue: 0,
          WalletExpenseStatus.unpaid:  1,
          WalletExpenseStatus.paid:    2,
        };
        copy.sort((a, b) => order[a.status]!.compareTo(order[b.status]!));
        break;
      case _WalletSortBy.category:
        copy.sort((a, b) => a.category.label.compareTo(b.category.label));
        break;
    }
    return copy;
  }

  String _sortLabel(_WalletSortBy s) {
    switch (s) {
      case _WalletSortBy.dueDate:  return 'Due Date';
      case _WalletSortBy.amount:   return 'Amount';
      case _WalletSortBy.status:   return 'Status';
      case _WalletSortBy.category: return 'Category';
    }
  }

  void _showSortSheet({
    required _WalletSortBy current,
    required ValueChanged<_WalletSortBy> onChanged,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _WalletSortSheet(
        currentSort: current,
        onSortChanged: (s) {
          setState(() => onChanged(s));
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedUpcoming = _sorted(widget.upcoming, _upcomingSort);
    final sortedRecent   = _sorted(widget.recent,   _recentSort);

    return CustomScrollView(
      controller: widget.scrollController,
      physics: const ClampingScrollPhysics(),
      slivers: [
        // ── Pinned header ────────────────────────────────────────────────
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
              dailyAllowance: widget.dailyAllowance,
              savings: widget.savings,
              monthlyBudget: widget.monthlyBudget,
              budgetUsed: widget.budgetUsed,
              upcomingCount: widget.upcoming.length,
              onAddToSavings: widget.onAddToSavings,
            ),
          ),
        ),

        // ── Upcoming Expenses ────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _SheetSectionHeader(
            title: 'Upcoming Expenses',
            sortLabel: _sortLabel(_upcomingSort),
            onSort: widget.upcoming.isNotEmpty
                ? () => _showSortSheet(
                    current: _upcomingSort,
                    onChanged: (s) => _upcomingSort = s,
                  )
                : null,
          ),
        ),
        SliverToBoxAdapter(child: const SizedBox(height: 8)),

        if (sortedUpcoming.isEmpty)
          SliverToBoxAdapter(
            child: _SheetEmptyState(
              icon: Icons.event_available_rounded,
              message: 'No upcoming expenses',
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                // Cast to IndexedExpense so we read the real store index.
                // Extension getters are resolved statically in Dart and cannot
                // be overridden, so _storeIndex always returned null before.
                final item = sortedUpcoming[i] as IndexedExpense;
                final idx  = item.storeIndex;
                return _ExpenseItem(
                  expense: item,
                  onTogglePaid: widget.onTogglePaid != null
                      ? () => widget.onTogglePaid!(idx)
                      : null,
                  onDelete: widget.onDeleteExpense != null
                      ? () => widget.onDeleteExpense!(idx)
                      : null,
                );
              },
              childCount: sortedUpcoming.length,
            ),
          ),

        // ── Recent Expenses ──────────────────────────────────────────────
        SliverToBoxAdapter(child: const SizedBox(height: 20)),
        SliverToBoxAdapter(
          child: _SheetSectionHeader(
            title: 'Recent Expenses',
            sortLabel: _sortLabel(_recentSort),
            onSort: widget.recent.isNotEmpty
                ? () => _showSortSheet(
                    current: _recentSort,
                    onChanged: (s) => _recentSort = s,
                  )
                : null,
          ),
        ),
        SliverToBoxAdapter(child: const SizedBox(height: 8)),

        if (sortedRecent.isEmpty)
          SliverToBoxAdapter(
            child: _SheetEmptyState(
              icon: Icons.receipt_long_rounded,
              message: 'No recent expenses',
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final item = sortedRecent[i] as IndexedExpense;
                final idx  = item.storeIndex;
                return _ExpenseItem(
                  expense: item,
                  onTogglePaid: widget.onTogglePaid != null
                      ? () => widget.onTogglePaid!(idx)
                      : null,
                  onDelete: widget.onDeleteExpense != null
                      ? () => widget.onDeleteExpense!(idx)
                      : null,
                );
              },
              childCount: sortedRecent.length,
            ),
          ),

        // ── Savings Log ──────────────────────────────────────────────────
        SliverToBoxAdapter(child: const SizedBox(height: 20)),
        SliverToBoxAdapter(
          child: Builder(
            builder: (context) => _SheetSectionHeader(
              title: 'Savings Log',
              action: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.onClearSavingsLog != null && widget.savingsLog.isNotEmpty)
                    GestureDetector(
                      onTap: () async {
                        final confirmed = await showModalBottomSheet<bool>(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (ctx) => Container(
                            margin: const EdgeInsets.fromLTRB(12, 0, 12, 28),
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A2D5A),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Handle
                                Container(
                                  width: 36, height: 4,
                                  margin: const EdgeInsets.only(bottom: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                // Icon
                                Container(
                                  width: 52, height: 52,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE87070).withOpacity(0.14),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFE87070).withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Icon(Icons.delete_sweep_rounded,
                                      color: Color(0xFFE87070), size: 24),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Clear Savings Log?',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'All log entries will be removed. Your total savings amount won\'t be affected.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.55),
                                    fontSize: 13,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: 50,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(14),
                                            color: Colors.white.withOpacity(0.08),
                                            border: Border.all(
                                                color: Colors.white.withOpacity(0.12)),
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(14),
                                              onTap: () => Navigator.pop(ctx, false),
                                              child: const Center(
                                                child: Text('Cancel',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w500,
                                                    )),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: SizedBox(
                                        height: 50,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(14),
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFFE87070), Color(0xFFD45F5F)],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFFE87070).withOpacity(0.35),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(14),
                                              onTap: () => Navigator.pop(ctx, true),
                                              child: const Center(
                                                child: Text('Clear',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.bold,
                                                    )),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                        if (confirmed == true) widget.onClearSavingsLog!();
                      },
                      child: const Row(
                        children: [
                          Text('Clear',
                              style: TextStyle(
                                  color: Color(0xFF6B7A99),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500)),
                          SizedBox(width: 3),
                          Icon(Icons.delete_sweep_rounded,
                              color: Color(0xFF6B7A99), size: 16),
                        ],
                      ),
                    ),
                  if (widget.onClearSavingsLog != null && widget.savingsLog.isNotEmpty &&
                      widget.onAddToSavings != null)
                    const SizedBox(width: 12),
                  if (widget.onWithdrawFromSavings != null && widget.savings > 0)
                    GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => _WithdrawSheet(
                            savings: widget.savings,
                            onWithdraw: (amount, note) {
                              widget.onWithdrawFromSavings!(amount, note);
                            },
                          ),
                        );
                      },
                      child: const Row(
                        children: [
                          Text('Withdraw',
                              style: TextStyle(
                                  color: Color(0xFF9B88E8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          SizedBox(width: 3),
                          Icon(Icons.arrow_circle_down_rounded,
                              color: Color(0xFF9B88E8), size: 16),
                        ],
                      ),
                    ),
                  if (widget.onWithdrawFromSavings != null && widget.savings > 0 &&
                      widget.onAddToSavings != null)
                    const SizedBox(width: 12),
                  if (widget.onAddToSavings != null)
                    GestureDetector(
                      onTap: () {
                        final amountController = TextEditingController();
                        final noteController   = TextEditingController();
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => Padding(
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(context).viewInsets.bottom,
                            ),
                            child: Container(
                              margin: const EdgeInsets.fromLTRB(12, 0, 12, 28),
                              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1B2D5B),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Center(
                                    child: Container(
                                      width: 36, height: 4,
                                      margin: const EdgeInsets.only(bottom: 20),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                  const Text(
                                    'Add to Savings',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: amountController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      hintText: 'Amount (₱)',
                                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                                      prefixText: '₱ ',
                                      prefixStyle: const TextStyle(color: Color(0xFF3BBFA3)),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Color(0xFF3BBFA3)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: noteController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      hintText: 'Note (optional)',
                                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Color(0xFF3BBFA3)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF3BBFA3),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14)),
                                      ),
                                      onPressed: () {
                                        final amount = double.tryParse(
                                            amountController.text.trim());
                                        if (amount == null || amount <= 0) return;
                                        final note = noteController.text.trim().isEmpty
                                            ? null
                                            : noteController.text.trim();
                                        Navigator.pop(context);
                                        widget.onAddToSavings!(amount, note);
                                      },
                                      child: const Text('Save',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      child: const Row(
                        children: [
                          Text('Add',
                              style: TextStyle(
                                  color: Color(0xFF3BBFA3),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          SizedBox(width: 3),
                          Icon(Icons.add_circle_rounded,
                              color: Color(0xFF3BBFA3), size: 18),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(child: const SizedBox(height: 8)),

        if (widget.savingsLog.isEmpty)
          SliverToBoxAdapter(
            child: _SheetEmptyState(
              icon: Icons.savings_rounded,
              message: 'No savings recorded yet',
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final entry = widget.savingsLog[widget.savingsLog.length - 1 - i]; // newest first
                return _SavingsLogItem(entry: entry);
              },
              childCount: widget.savingsLog.length,
            ),
          ),

        // ── Bottom padding ───────────────────────────────────────────────
        SliverToBoxAdapter(child: const SizedBox(height: 80)),
      ],
    );
  }
}

// ── Pinned header widget ──────────────────────────────────────────────────────
class _WalletSheetHeader extends StatelessWidget {
  final double dailyAllowance;
  final double savings;
  final double monthlyBudget;
  final double budgetUsed;
  final int upcomingCount;
  final void Function(double, String?)? onAddToSavings;

  const _WalletSheetHeader({
    required this.dailyAllowance,
    required this.savings,
    required this.monthlyBudget,
    required this.budgetUsed,
    required this.upcomingCount,
    this.onAddToSavings,
  });

  void _showAddSavingsDialog(BuildContext context) {
    final amountController = TextEditingController();
    final noteController   = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 28),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          decoration: BoxDecoration(
            color: const Color(0xFF1B2D5B),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Add to Savings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Amount (₱)',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                  prefixText: '₱ ',
                  prefixStyle: const TextStyle(color: Color(0xFF3BBFA3)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF3BBFA3)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Note (optional)',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF3BBFA3)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3BBFA3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    final amount = double.tryParse(amountController.text.trim());
                    if (amount == null || amount <= 0) return;
                    final note = noteController.text.trim().isEmpty
                        ? null
                        : noteController.text.trim();
                    Navigator.pop(context);
                    onAddToSavings!(amount, note);
                  },
                  child: const Text('Save',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
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

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _CompactStat(
                icon: Icons.credit_card_rounded,
                iconColor: const Color(0xFF4A90D9),
                label: 'Daily Allowance',
                value: '₱${dailyAllowance.toStringAsFixed(2)}',
              ),
              const SizedBox(width: 8),
              _CompactStat(
                icon: Icons.savings_rounded,
                iconColor: const Color(0xFF3BBFA3),
                label: 'Savings',
                value: '₱${savings.toStringAsFixed(2)}',
                onAction: onAddToSavings != null
                    ? () => _showAddSavingsDialog(context)
                    : null,
              ),
              const SizedBox(width: 8),
              _CompactStat(
                icon: Icons.account_balance_wallet_rounded,
                iconColor: const Color(0xFF9B88E8),
                label: 'Monthly Budget',
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

// ── Compact stat chip ─────────────────────────────────────────────────────────
class _CompactStat extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool showProgress;
  final double progressValue;
  final VoidCallback? onAction;

  const _CompactStat({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.showProgress = false,
    this.progressValue = 0,
    this.onAction,
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
                if (onAction != null)
                  GestureDetector(
                    onTap: onAction,
                    child: Icon(Icons.add_circle_rounded,
                        size: 14, color: iconColor),
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
  final String? sortLabel;
  final VoidCallback? onSort;
  final Widget? action;

  const _SheetSectionHeader({required this.title, this.sortLabel, this.onSort, this.action});

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
          if (action != null)
            action!
          else
            GestureDetector(
              onTap: onSort,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: onSort != null ? 1.0 : 0.35,
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
                        sortLabel ?? 'Sort',
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
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sort sheet — mirrors _ManageSheet from task_home_sheet (sort only)
// ─────────────────────────────────────────────────────────────
class _WalletSortSheet extends StatelessWidget {
  final _WalletSortBy currentSort;
  final ValueChanged<_WalletSortBy> onSortChanged;

  const _WalletSortSheet({
    required this.currentSort,
    required this.onSortChanged,
  });

  static const _sorts = [
    (_WalletSortBy.dueDate,  Icons.schedule_rounded,          'Due Date',  'Earliest first'),
    (_WalletSortBy.amount,   Icons.attach_money_rounded,       'Amount',    'Highest first'),
    (_WalletSortBy.status,   Icons.timelapse_rounded,          'Status',    'Overdue → Paid'),
    (_WalletSortBy.category, Icons.label_rounded,              'Category',  'Food → Transport'),
  ];

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.70;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 28),
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2D5B),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
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
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3BBFA3).withOpacity(0.14),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF3BBFA3).withOpacity(0.3), width: 1.5),
                  ),
                  child: const Icon(Icons.tune_rounded, color: Color(0xFF3BBFA3), size: 21),
                ),
                const SizedBox(width: 13),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Sort Expenses', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  Text('Choose how to order the list', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                ]),
              ]),
            ),

            const SizedBox(height: 16),
            Divider(color: Colors.white.withOpacity(0.07), thickness: 1, indent: 22, endIndent: 22),
            const SizedBox(height: 6),

            // Sort by label
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 2, 22, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('SORT BY', style: TextStyle(color: Colors.white.withOpacity(0.28), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              ),
            ),

            // Sort options
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 22),
              child: Column(
                children: _sorts.map((s) {
                  final selected = s.$1 == currentSort;
                  const c = Color(0xFF3BBFA3);
                  return _WalletSortRow(
                    icon: s.$2,
                    iconColor: selected ? c : Colors.white.withOpacity(0.4),
                    label: s.$3,
                    subtitle: s.$4,
                    selected: selected,
                    accentColor: c,
                    onTap: () => onSortChanged(s.$1),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Single sort row ───────────────────────────────────────────
class _WalletSortRow extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final bool selected;
  final Color accentColor;
  final VoidCallback? onTap;

  const _WalletSortRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.accentColor,
    this.onTap,
  });

  @override
  State<_WalletSortRow> createState() => _WalletSortRowState();
}

class _WalletSortRowState extends State<_WalletSortRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.accentColor;
    final active = widget.selected || _pressed;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap?.call(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: active ? c.withOpacity(0.10) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? c.withOpacity(0.45) : Colors.white.withOpacity(0.07),
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
              color: Colors.white,
              fontSize: 14, fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: 2),
            Text(widget.subtitle, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11)),
          ])),
          if (widget.selected)
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
            )
          else
            Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.18), size: 18),
        ]),
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
// Long-press → bottom sheet with "Mark Paid / Mark Unpaid / Delete"
// ─────────────────────────────────────────────────────────────
class _ExpenseItem extends StatelessWidget {
  final WalletExpense expense;
  final VoidCallback? onTogglePaid;
  final VoidCallback? onDelete;

  const _ExpenseItem({
    required this.expense,
    this.onTogglePaid,
    this.onDelete,
  });

  Color get _badgeColor {
    switch (expense.status) {
      case WalletExpenseStatus.overdue:
        return const Color(0xFFE87070);
      case WalletExpenseStatus.unpaid:
        return const Color(0xFF4A90D9);
      case WalletExpenseStatus.paid:
        return const Color(0xFF3BBFA3);
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
    }
  }

  // ── Badge tap → action sheet ──────────────────────────────
  void _showActions(BuildContext context) {
    final isPaid = expense.status == WalletExpenseStatus.paid;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 28),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2D5B),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(top: 14, bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Expense name header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                expense.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            // Toggle paid / unpaid
            if (onTogglePaid != null)
              ListTile(
                leading: Icon(
                  isPaid
                      ? Icons.unpublished_rounded
                      : Icons.check_circle_rounded,
                  color: isPaid
                      ? const Color(0xFF4A90D9)
                      : const Color(0xFF3BBFA3),
                ),
                title: Text(
                  isPaid ? 'Mark as Unpaid' : 'Mark as Paid',
                  style: TextStyle(
                    color: isPaid
                        ? const Color(0xFF4A90D9)
                        : const Color(0xFF3BBFA3),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onTogglePaid!();
                },
              ),
            // Delete
            if (onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFE87070)),
                title: const Text(
                  'Delete Expense',
                  style: TextStyle(
                    color: Color(0xFFE87070),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onDelete!();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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
                      GestureDetector(
                        onTap: (onTogglePaid != null || onDelete != null)
                            ? () => _showActions(context)
                            : null,
                        child: Container(
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

// ─────────────────────────────────────────────────────────────
// Savings log item row
// ─────────────────────────────────────────────────────────────
class _SavingsLogItem extends StatelessWidget {
  final SavingsEntry entry;

  const _SavingsLogItem({required this.entry});

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${entry.date.day}/${entry.date.month}/${entry.date.year}';
    final isWithdrawal = entry.amount < 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isWithdrawal
                  ? const Color(0xFF9B88E8).withOpacity(0.12)
                  : const Color(0xFF3BBFA3).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isWithdrawal
                  ? Icons.arrow_circle_down_rounded
                  : Icons.savings_rounded,
              color: isWithdrawal
                  ? const Color(0xFF9B88E8)
                  : const Color(0xFF3BBFA3),
              size: 17,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.note ?? (isWithdrawal ? 'Withdrawal' : 'Savings'),
                      style: const TextStyle(
                        color: kNavyDark,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${isWithdrawal ? "–" : "+"}₱${entry.amount.abs().toStringAsFixed(2)}',
                      style: TextStyle(
                        color: isWithdrawal
                            ? const Color(0xFF9B88E8)
                            : const Color(0xFF3BBFA3),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 11, color: Color(0xFF6B7A99)),
                    const SizedBox(width: 3),
                    Text(
                      dateStr,
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

// ─────────────────────────────────────────────────────────────
// Internal extension: store index tag
// WalletScreen stamps each expense with its original list index
// before passing filtered sub-lists to WalletSheet, so the
// callbacks can address the right item in WalletStore.expenses.
// ─────────────────────────────────────────────────────────────
extension WalletExpenseIndexed on WalletExpense {
  // Carried as a transient field via _IndexedExpense wrapper below.
  int? get _storeIndex => null; // default; overridden by _IndexedExpense
}

/// Lightweight wrapper that tags a [WalletExpense] with its position
/// in [WalletStore.expenses] so filtered sheet lists can still call
/// the right store index.
class IndexedExpense extends WalletExpense {
  final int storeIndex;

  IndexedExpense({required WalletExpense expense, required this.storeIndex})
      : super(
          name:      expense.name,
          amount:    expense.amount,
          dateRange: expense.dateRange,
          dueDate:   expense.dueDate,
          paidAt:    expense.paidAt,
          status:    expense.status,
          icon:      expense.icon,
          iconColor: expense.iconColor,
          savingNote: expense.savingNote,
          category:  expense.category,
        );

  @override
  int? get _storeIndex => storeIndex;
}
// ─────────────────────────────────────────────────────────────
// Withdraw sheet — StatefulWidget so we can show inline errors
// ─────────────────────────────────────────────────────────────
class _WithdrawSheet extends StatefulWidget {
  final double savings;
  final void Function(double amount, String? note) onWithdraw;

  const _WithdrawSheet({required this.savings, required this.onWithdraw});

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  final _amountController = TextEditingController();
  final _noteController   = TextEditingController();
  String? _amountError;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final raw    = _amountController.text.trim();
    final amount = double.tryParse(raw);

    if (amount == null || amount <= 0) {
      setState(() => _amountError = 'Enter a valid amount');
      return;
    }
    if (amount > widget.savings) {
      setState(() => _amountError =
          'Exceeds your savings (₱${widget.savings.toStringAsFixed(2)})');
      return;
    }

    final note = _noteController.text.trim().isEmpty
        ? null
        : _noteController.text.trim();
    Navigator.pop(context);
    widget.onWithdraw(amount, note);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 28),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2D5B),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Withdraw from Savings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // ── Amount field with inline error ──────────────────────────
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              onChanged: (_) {
                if (_amountError != null) setState(() => _amountError = null);
              },
              decoration: InputDecoration(
                hintText: 'Amount (₱)',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                prefixText: '₱ ',
                prefixStyle: const TextStyle(color: Color(0xFF9B88E8)),
                errorText: _amountError,
                errorStyle: const TextStyle(
                  color: Color(0xFFE87070),
                  fontSize: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _amountError != null
                        ? const Color(0xFFE87070)
                        : Colors.white.withOpacity(0.15),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _amountError != null
                        ? const Color(0xFFE87070)
                        : const Color(0xFF9B88E8),
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE87070)),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE87070)),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Note field ──────────────────────────────────────────────
            TextField(
              controller: _noteController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Note (optional)',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF9B88E8)),
                ),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9B88E8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _submit,
                child: const Text(
                  'Withdraw',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}