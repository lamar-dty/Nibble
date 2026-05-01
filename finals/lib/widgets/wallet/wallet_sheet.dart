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
class WalletSheet extends StatelessWidget {
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
    this.onClearSavingsLog,
  });

  static const double _headerHeight = 147.0;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: scrollController,
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
              dailyAllowance: dailyAllowance,
              savings: savings,
              monthlyBudget: monthlyBudget,
              budgetUsed: budgetUsed,
              upcomingCount: upcoming.length,
              onAddToSavings: onAddToSavings,
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
              (context, i) {
                // Cast to IndexedExpense so we read the real store index.
                // Extension getters are resolved statically in Dart and cannot
                // be overridden, so _storeIndex always returned null before.
                final item = upcoming[i] as IndexedExpense;
                final idx  = item.storeIndex;
                return _ExpenseItem(
                  expense: item,
                  onTogglePaid: onTogglePaid != null
                      ? () => onTogglePaid!(idx)
                      : null,
                  onDelete: onDeleteExpense != null
                      ? () => onDeleteExpense!(idx)
                      : null,
                );
              },
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
              (context, i) {
                final item = recent[i] as IndexedExpense;
                final idx  = item.storeIndex;
                return _ExpenseItem(
                  expense: item,
                  onTogglePaid: onTogglePaid != null
                      ? () => onTogglePaid!(idx)
                      : null,
                  onDelete: onDeleteExpense != null
                      ? () => onDeleteExpense!(idx)
                      : null,
                );
              },
              childCount: recent.length,
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
                  if (onClearSavingsLog != null && savingsLog.isNotEmpty)
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
                        if (confirmed == true) onClearSavingsLog!();
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
                  if (onClearSavingsLog != null && savingsLog.isNotEmpty &&
                      onAddToSavings != null)
                    const SizedBox(width: 12),
                  if (onAddToSavings != null)
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
                                        onAddToSavings!(amount, note);
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

        if (savingsLog.isEmpty)
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
                final entry = savingsLog[savingsLog.length - 1 - i]; // newest first
                return _SavingsLogItem(entry: entry);
              },
              childCount: savingsLog.length,
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
  final VoidCallback? onSort;
  final Widget? action;

  const _SheetSectionHeader({required this.title, this.onSort, this.action});

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF3BBFA3).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.savings_rounded,
                color: Color(0xFF3BBFA3), size: 17),
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
                      entry.note ?? 'Savings',
                      style: const TextStyle(
                        color: kNavyDark,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '+₱${entry.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFF3BBFA3),
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