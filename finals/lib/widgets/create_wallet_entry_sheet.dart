import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/colors.dart';
import '../widgets/wallet/wallet_sheet.dart';
import '../store/wallet_store.dart';

// ─────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────
Future<void> showCreateWalletEntrySheet(
  BuildContext context, {
  _EntryType initialType = _EntryType.expense,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    enableDrag: true,
    builder: (_) => _CreateWalletEntrySheet(initialType: initialType),
  );
}

/// Convenience shortcut — opens directly on the Budget tab.
Future<void> showBudgetEditSheet(BuildContext context) =>
    showCreateWalletEntrySheet(context, initialType: _EntryType.budget);

// ─────────────────────────────────────────────────────────────
// Entry type
// ─────────────────────────────────────────────────────────────
enum _EntryType { expense, allowance, savings, budget }

// ─────────────────────────────────────────────────────────────
// Sheet
// ─────────────────────────────────────────────────────────────
class _CreateWalletEntrySheet extends StatefulWidget {
  final _EntryType initialType;
  const _CreateWalletEntrySheet({this.initialType = _EntryType.expense});

  @override
  State<_CreateWalletEntrySheet> createState() => _CreateWalletEntrySheetState();
}

class _CreateWalletEntrySheetState extends State<_CreateWalletEntrySheet>
    with SingleTickerProviderStateMixin {

  late _EntryType _type;

  final _nameCtrl   = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _nameFocus  = FocusNode();

  DateTime?             _dueDate;
  // ── Now uses the PUBLIC WalletExpenseCategory from wallet_sheet.dart ──
  WalletExpenseCategory _category = WalletExpenseCategory.other;
  bool                  _saving   = false;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _nameFocus.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Validation ─────────────────────────────────────────────

  String? _validate() {
    final name   = _nameCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (_type == _EntryType.expense && name.isEmpty) return 'Please enter a name.';
    if (amount == null || amount <= 0) return 'Please enter a valid amount.';
    return null;
  }

  // ── Status from due date ───────────────────────────────────

  WalletExpenseStatus _derivedStatus() {
    if (_dueDate == null) return WalletExpenseStatus.unpaid;
    final today = DateTime.now();
    final due   = DateTime(_dueDate!.year, _dueDate!.month, _dueDate!.day);
    final now   = DateTime(today.year, today.month, today.day);
    return due.isBefore(now) ? WalletExpenseStatus.overdue : WalletExpenseStatus.unpaid;
  }

  // ── Save ───────────────────────────────────────────────────

  Future<void> _save() async {
    final error = _validate();
    if (error != null) {
      HapticFeedback.lightImpact();
      if (_type == _EntryType.expense && _nameCtrl.text.trim().isEmpty) {
        FocusScope.of(context).requestFocus(_nameFocus);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: const Color(0xFFE87070),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    final amount = double.parse(_amountCtrl.text.trim());

    switch (_type) {
      case _EntryType.expense:
        await WalletStore.instance.addExpense(WalletExpense(
          name:      _nameCtrl.text.trim(),
          amount:    amount,
          dateRange: _dueDate != null ? _formatDate(_dueDate!) : _todayLabel(),
          dueDate:   _dueDate,
          status:    _derivedStatus(),
          // ── Use category's icon and color directly from the enum ──
          icon:      _category.icon,
          iconColor: _category.color,
          category:  _category,           // ← NEW: pass category to store
        ));
        break;
      case _EntryType.allowance:
        await WalletStore.instance.setDailyAllowance(amount);
        break;
      case _EntryType.savings:
        await WalletStore.instance.setSavings(amount);
        break;
      case _EntryType.budget:
        await WalletStore.instance.setMonthlyBudget(amount);
        break;
    }

    if (mounted) Navigator.pop(context);
  }

  String _todayLabel() => _formatDate(DateTime.now());

  String _formatDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  Future<void> _pickDueDate() async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _IosDatePickerSheet(
        initial: _dueDate ?? DateTime.now(),
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      ),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq     = MediaQuery.of(context);
    final bottom = mq.viewInsets.bottom;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        margin: EdgeInsets.only(bottom: bottom),
        height: mq.size.height * 0.78,
        decoration: const BoxDecoration(
          color: Color(0xFF1A2D5A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // ── Handle ─────────────────────────────────────────
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: kWhite.withOpacity(0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── Header ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8A870).withOpacity(0.14),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFE8A870).withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(Icons.payments_rounded,
                        color: Color(0xFFE8A870), size: 21),
                  ),
                  const SizedBox(width: 13),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Log Transaction',
                          style: TextStyle(
                              color: kWhite,
                              fontSize: 17,
                              fontWeight: FontWeight.bold)),
                      Text('Fill in the details below',
                          style: TextStyle(
                              color: kWhite.withOpacity(0.4),
                              fontSize: 12)),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: kWhite.withOpacity(0.07),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close_rounded,
                          color: kWhite.withOpacity(0.5), size: 17),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Divider(height: 1, color: kWhite.withOpacity(0.07)),

            // ── Scrollable body ─────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Type selector ─────────────────────────────
                    _FieldLabel(
                        label: 'Transaction Type',
                        icon:  Icons.swap_horiz_rounded),
                    const SizedBox(height: 8),
                    _TypeSelector(
                      selected: _type,
                      onChanged: (t) => setState(() {
                        _type = t;
                        _amountCtrl.clear();
                        _nameCtrl.clear();
                      }),
                    ),

                    const SizedBox(height: 18),

                    // ── Animated content ──────────────────────────
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) =>
                          FadeTransition(opacity: anim, child: child),
                      child: KeyedSubtree(
                        key: ValueKey(_type),
                        child: _type == _EntryType.expense
                            ? _ExpenseSection(
                                nameCtrl:          _nameCtrl,
                                amountCtrl:        _amountCtrl,
                                nameFocus:         _nameFocus,
                                dueDate:           _dueDate,
                                category:          _category,
                                onDueDateTap:      _pickDueDate,
                                onClearDueDate:
                                    () => setState(() => _dueDate = null),
                                onCategoryChanged: (c) =>
                                    setState(() => _category = c),
                              )
                            : _SimpleSection(
                                ctrl:      _amountCtrl,
                                entryType: _type,
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Save button ─────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(color: kWhite.withOpacity(0.07))),
              ),
              padding: EdgeInsets.fromLTRB(
                  20, 14, 20, 14 + mq.padding.bottom),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                        colors: [Color(0xFFE8A870), Color(0xFFD4906A)]),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE8A870).withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _saving ? null : _save,
                      child: Center(
                        child: _saving
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation(kWhite)))
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_rounded,
                                      color: kWhite, size: 18),
                                  SizedBox(width: 7),
                                  Text('Save',
                                      style: TextStyle(
                                          color: kWhite,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.3)),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Expense section
// ─────────────────────────────────────────────────────────────
class _ExpenseSection extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController amountCtrl;
  final FocusNode             nameFocus;
  final DateTime?             dueDate;
  final WalletExpenseCategory category;          // ← now public type
  final VoidCallback          onDueDateTap;
  final VoidCallback          onClearDueDate;
  final ValueChanged<WalletExpenseCategory> onCategoryChanged; // ← now public type

  const _ExpenseSection({
    required this.nameCtrl,
    required this.amountCtrl,
    required this.nameFocus,
    required this.dueDate,
    required this.category,
    required this.onDueDateTap,
    required this.onClearDueDate,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        _FieldLabel(label: 'Expense Name', icon: Icons.label_outline_rounded),
        const SizedBox(height: 8),
        _NameField(controller: nameCtrl, focusNode: nameFocus),

        const SizedBox(height: 18),

        _FieldLabel(label: 'Amount', icon: Icons.payments_outlined),
        const SizedBox(height: 8),
        _AmountField(ctrl: amountCtrl),

        const SizedBox(height: 18),

        Row(children: [
          _FieldLabel(label: 'Due Date', icon: Icons.schedule_rounded),
          const Spacer(),
          Text('optional',
              style: TextStyle(
                  color: kWhite.withOpacity(0.25),
                  fontSize: 10,
                  fontStyle: FontStyle.italic)),
          if (dueDate != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onClearDueDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kWhite.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.close_rounded,
                      size: 11, color: kWhite.withOpacity(0.35)),
                  const SizedBox(width: 3),
                  Text('Clear',
                      style: TextStyle(
                          color: kWhite.withOpacity(0.35),
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 10),
        _DueDateRow(dueDate: dueDate, onTap: onDueDateTap),

        const SizedBox(height: 18),

        _FieldLabel(label: 'Category', icon: Icons.label_rounded),
        const SizedBox(height: 8),
        _CategoryChips(selected: category, onChanged: onCategoryChanged),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Simple section — allowance / savings / budget
// ─────────────────────────────────────────────────────────────
class _SimpleSection extends StatelessWidget {
  final TextEditingController ctrl;
  final _EntryType entryType;

  const _SimpleSection({required this.ctrl, required this.entryType});

  @override
  Widget build(BuildContext context) {
    final cfg   = _tabConfig[entryType]!;
    final store = WalletStore.instance;

    final double current = switch (entryType) {
      _EntryType.allowance => store.dailyAllowance,
      _EntryType.savings   => store.savings,
      _EntryType.budget    => store.monthlyBudget,
      _EntryType.expense   => 0,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        _FieldLabel(label: cfg.fieldLabel, icon: cfg.icon),
        const SizedBox(height: 8),
        _AmountField(ctrl: ctrl),

        const SizedBox(height: 18),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cfg.color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cfg.color.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: cfg.color.withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(cfg.icon, color: cfg.color, size: 17),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(cfg.currentLabel,
                      style: TextStyle(
                          color: kWhite.withOpacity(0.4),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6)),
                  Text(
                    current == 0
                        ? 'Not set'
                        : '₱${current.toStringAsFixed(2)}${cfg.valueSuffix}',
                    style: TextStyle(
                        color: current == 0
                            ? kWhite.withOpacity(0.3)
                            : cfg.color,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ]),
              ]),

              if (entryType == _EntryType.budget) ...[
                const SizedBox(height: 14),
                _BudgetProgress(color: cfg.color),
              ],

              const SizedBox(height: 14),
              Divider(height: 1, color: cfg.color.withOpacity(0.15)),
              const SizedBox(height: 10),

              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.notifications_outlined,
                    color: cfg.color.withOpacity(0.55), size: 12),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(cfg.tip,
                      style: TextStyle(
                          color: kWhite.withOpacity(0.4),
                          fontSize: 11.5,
                          height: 1.45,
                          fontStyle: FontStyle.italic)),
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Budget progress
// ─────────────────────────────────────────────────────────────
class _BudgetProgress extends StatelessWidget {
  final Color color;
  const _BudgetProgress({required this.color});

  @override
  Widget build(BuildContext context) {
    final store    = WalletStore.instance;
    final fraction = store.budgetUsedFraction;
    final spent    = store.monthlySpent;
    final budget   = store.monthlyBudget;

    final barColor = fraction >= 0.9
        ? const Color(0xFFE87070)
        : fraction >= 0.7
            ? const Color(0xFFE8A870)
            : color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('This month',
              style: TextStyle(
                  color: kWhite.withOpacity(0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3)),
          Text(
            budget > 0
                ? '₱${spent.toStringAsFixed(2)} / ₱${budget.toStringAsFixed(2)}'
                : '₱${spent.toStringAsFixed(2)} spent',
            style: TextStyle(
                color: barColor, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: kWhite.withOpacity(0.08),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Due date row
// ─────────────────────────────────────────────────────────────
class _DueDateRow extends StatelessWidget {
  final DateTime?    dueDate;
  final VoidCallback onTap;
  const _DueDateRow({required this.dueDate, required this.onTap});

  String _label() {
    if (dueDate == null) return 'Set due date';
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return 'Due: ${months[dueDate!.month - 1]} ${dueDate!.day}, ${dueDate!.year}';
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFE8A870);
    final set    = dueDate != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: set
              ? accent.withOpacity(0.09)
              : kWhite.withOpacity(0.04),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
              color: set ? accent.withOpacity(0.3) : kWhite.withOpacity(0.09)),
        ),
        child: Row(children: [
          Icon(
            set ? Icons.event_rounded : Icons.add_circle_outline_rounded,
            size: 14,
            color: set ? accent : kWhite.withOpacity(0.28),
          ),
          const SizedBox(width: 9),
          Text(_label(),
              style: TextStyle(
                  color: set ? accent : kWhite.withOpacity(0.32),
                  fontSize: 13,
                  fontWeight:
                      set ? FontWeight.w700 : FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Tab config
// ─────────────────────────────────────────────────────────────
class _TabConfig {
  final String   fieldLabel;
  final String   currentLabel;
  final String   valueSuffix;
  final String   tip;
  final IconData icon;
  final Color    color;
  const _TabConfig({
    required this.fieldLabel,
    required this.currentLabel,
    required this.valueSuffix,
    required this.tip,
    required this.icon,
    required this.color,
  });
}

const _tabConfig = <_EntryType, _TabConfig>{
  _EntryType.allowance: _TabConfig(
    fieldLabel:   'Daily Allowance',
    currentLabel: 'CURRENT ALLOWANCE',
    valueSuffix:  ' / day',
    tip: 'Sets your daily spending limit. The wallet uses this to show how much you have left today.',
    icon:  Icons.credit_card_rounded,
    color: Color(0xFF4A90D9),
  ),
  _EntryType.savings: _TabConfig(
    fieldLabel:   'Savings Amount',
    currentLabel: 'CURRENT SAVINGS',
    valueSuffix:  '',
    tip: 'Update your total saved amount. Useful for tracking a savings goal or a separate fund.',
    icon:  Icons.savings_rounded,
    color: Color(0xFF3BBFA3),
  ),
  _EntryType.budget: _TabConfig(
    fieldLabel:   'Monthly Budget',
    currentLabel: 'CURRENT BUDGET',
    valueSuffix:  ' / month',
    tip: 'Sets how much you plan to spend this month. Paid expenses count toward this limit.',
    icon:  Icons.account_balance_wallet_rounded,
    color: Color(0xFF9B88E8),
  ),
};

// ─────────────────────────────────────────────────────────────
// Type selector
// ─────────────────────────────────────────────────────────────
class _TypeSelector extends StatelessWidget {
  final _EntryType selected;
  final ValueChanged<_EntryType> onChanged;

  const _TypeSelector({required this.selected, required this.onChanged});

  static const _tabs = [
    (type: _EntryType.expense,   label: 'Expense',   icon: Icons.receipt_rounded),
    (type: _EntryType.allowance, label: 'Allowance', icon: Icons.credit_card_rounded),
    (type: _EntryType.savings,   label: 'Savings',   icon: Icons.savings_rounded),
    (type: _EntryType.budget,    label: 'Budget',    icon: Icons.account_balance_wallet_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kWhite.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kWhite.withOpacity(0.08)),
      ),
      child: Row(
        children: _tabs.map((tab) {
          final sel = selected == tab.type;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(tab.type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: sel
                      ? const Color(0xFFE8A870)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(tab.icon,
                        size: 14,
                        color: sel ? kWhite : kWhite.withOpacity(0.4)),
                    const SizedBox(width: 5),
                    Text(tab.label,
                        style: TextStyle(
                          color: sel ? kWhite : kWhite.withOpacity(0.4),
                          fontSize: 12,
                          fontWeight: sel
                              ? FontWeight.bold
                              : FontWeight.normal,
                        )),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Field label
// ─────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String   label;
  final IconData icon;
  const _FieldLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: kSubtitle, size: 12),
      const SizedBox(width: 5),
      Text(label,
          style: const TextStyle(
              color: kSubtitle,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// Name field
// ─────────────────────────────────────────────────────────────
class _NameField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode             focusNode;
  const _NameField({required this.controller, required this.focusNode});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kWhite.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kWhite.withOpacity(0.1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        style: const TextStyle(
            color: kWhite, fontSize: 15, fontWeight: FontWeight.w600),
        maxLines: 1,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: 'e.g. Electric bill, School fee…',
          hintStyle: TextStyle(
              color: kWhite.withOpacity(0.22),
              fontSize: 15,
              fontWeight: FontWeight.w600),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Amount field
// ─────────────────────────────────────────────────────────────
class _AmountField extends StatelessWidget {
  final TextEditingController ctrl;
  const _AmountField({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kWhite.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kWhite.withOpacity(0.1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(children: [
        Text('₱',
            style: TextStyle(
                color: kWhite.withOpacity(0.45),
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        const SizedBox(width: 6),
        Expanded(
          child: TextField(
            controller: ctrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                  RegExp(r'^\d*\.?\d{0,2}'))
            ],
            style: const TextStyle(
                color: kWhite, fontSize: 17, fontWeight: FontWeight.w600),
            cursorColor: const Color(0xFFE8A870),
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: TextStyle(
                  color: kWhite.withOpacity(0.22),
                  fontSize: 17,
                  fontWeight: FontWeight.w600),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Category chips
// Now uses the public WalletExpenseCategory from wallet_sheet.dart.
// The private _ExpenseCategory enum has been removed entirely.
// ─────────────────────────────────────────────────────────────
class _CategoryChips extends StatelessWidget {
  final WalletExpenseCategory selected;
  final ValueChanged<WalletExpenseCategory> onChanged;
  const _CategoryChips({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: WalletExpenseCategory.values.map((cat) {
        final sel = selected == cat;
        return GestureDetector(
          onTap: () => onChanged(cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: sel
                  ? cat.color.withOpacity(0.14)
                  : kWhite.withOpacity(0.04),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                  color: sel
                      ? cat.color.withOpacity(0.55)
                      : kWhite.withOpacity(0.08),
                  width: sel ? 1.5 : 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(cat.icon,
                  size: 13,
                  color: sel ? cat.color : kWhite.withOpacity(0.3)),
              const SizedBox(width: 5),
              Text(cat.label,
                  style: TextStyle(
                      color: sel ? cat.color : kWhite.withOpacity(0.35),
                      fontSize: 12,
                      fontWeight: sel
                          ? FontWeight.w700
                          : FontWeight.normal)),
            ]),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// iOS-style date picker sheet
// ─────────────────────────────────────────────────────────────
class _IosDatePickerSheet extends StatefulWidget {
  final DateTime initial;
  final DateTime firstDate;
  final DateTime lastDate;

  const _IosDatePickerSheet({
    required this.initial,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_IosDatePickerSheet> createState() => _IosDatePickerSheetState();
}

class _IosDatePickerSheetState extends State<_IosDatePickerSheet> {
  static const _itemH   = 44.0;
  static const _visible = 5;
  static const _listH   = _itemH * _visible;
  static const _monthNames = [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December',
  ];

  late int _month, _day, _year, _firstYear, _lastYear;
  late FixedExtentScrollController _monthCtrl, _dayCtrl, _yearCtrl;

  @override
  void initState() {
    super.initState();
    _month     = widget.initial.month;
    _day       = widget.initial.day;
    _year      = widget.initial.year;
    _firstYear = widget.firstDate.year;
    _lastYear  = widget.lastDate.year;
    _monthCtrl = FixedExtentScrollController(initialItem: _month - 1);
    _dayCtrl   = FixedExtentScrollController(initialItem: _day - 1);
    _yearCtrl  = FixedExtentScrollController(initialItem: _year - _firstYear);
  }

  @override
  void dispose() {
    _monthCtrl.dispose(); _dayCtrl.dispose(); _yearCtrl.dispose();
    super.dispose();
  }

  int get _daysInMonth => DateTime(_year, _month + 1, 0).day;
  DateTime get _result =>
      DateTime(_year, _month, _day.clamp(1, _daysInMonth));

  String _fmtResult(DateTime d) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dd    = DateTime(d.year, d.month, d.day);
    if (dd == today) return 'Today';
    if (dd == today.add(const Duration(days: 1))) return 'Tomorrow';
    return '${_monthNames[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      margin: EdgeInsets.fromLTRB(12, 0, 12, 24 + mq.padding.bottom),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2D5A),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: kWhite.withOpacity(0.08)),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 40,
            offset: const Offset(0, -4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 36, height: 4,
          margin: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
              color: kWhite.withOpacity(0.18),
              borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFE8A870).withOpacity(0.14),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFFE8A870).withOpacity(0.3)),
              ),
              child: const Icon(Icons.calendar_today_rounded,
                  color: Color(0xFFE8A870), size: 17),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Set Due Date',
                  style: TextStyle(
                      color: kWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              Text('Scroll to choose',
                  style: TextStyle(
                      color: kWhite.withOpacity(0.38), fontSize: 12)),
            ]),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                    color: kWhite.withOpacity(0.07),
                    shape: BoxShape.circle),
                child: Icon(Icons.close_rounded,
                    color: kWhite.withOpacity(0.45), size: 16),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        Divider(height: 1, color: kWhite.withOpacity(0.07)),
        const SizedBox(height: 8),

        SizedBox(
          height: _listH,
          child: Stack(children: [
            Positioned(
              top: _itemH * ((_visible - 1) / 2),
              left: 16, right: 16, height: _itemH,
              child: Container(
                decoration: BoxDecoration(
                  color: kWhite.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kWhite.withOpacity(0.1)),
                ),
              ),
            ),
            Positioned(
              top: 0, left: 0, right: 0, height: _itemH * 1.5,
              child: IgnorePointer(
                child: Container(decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [const Color(0xFF1A2D5A), const Color(0xFF1A2D5A).withOpacity(0)],
                  ),
                )),
              ),
            ),
            Positioned(
              bottom: 0, left: 0, right: 0, height: _itemH * 1.5,
              child: IgnorePointer(
                child: Container(decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [const Color(0xFF1A2D5A), const Color(0xFF1A2D5A).withOpacity(0)],
                  ),
                )),
              ),
            ),
            Row(children: [
              Expanded(flex: 3, child: _Wheel(
                controller: _monthCtrl, itemCount: 12,
                labelBuilder: (i) => _monthNames[i % 12],
                onChanged: (i) => setState(() => _month = (i % 12) + 1),
              )),
              Expanded(flex: 2, child: ListWheelScrollView.useDelegate(
                controller: _dayCtrl, itemExtent: _itemH,
                physics: const FixedExtentScrollPhysics(),
                diameterRatio: 1.4, perspective: 0.003,
                onSelectedItemChanged: (i) =>
                    setState(() => _day = (i % 31) + 1),
                childDelegate: ListWheelChildLoopingListDelegate(
                  children: List.generate(31, (i) => _WheelItem(
                      label: '${i + 1}', dimmed: (i + 1) > _daysInMonth)),
                ),
              )),
              Expanded(flex: 3, child: _Wheel(
                controller: _yearCtrl,
                itemCount: _lastYear - _firstYear + 1,
                looping: false,
                labelBuilder: (i) => '${_firstYear + i}',
                onChanged: (i) => setState(() => _year = _firstYear + i),
              )),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        Divider(height: 1, color: kWhite.withOpacity(0.07)),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: SizedBox(
            width: double.infinity, height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                    colors: [Color(0xFFE8A870), Color(0xFFD4906A)]),
                boxShadow: [BoxShadow(
                    color: const Color(0xFFE8A870).withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4))],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.pop(context, _result),
                  child: Center(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.check_rounded,
                          color: kWhite, size: 18),
                      const SizedBox(width: 7),
                      Text(_fmtResult(_result),
                          style: const TextStyle(
                              color: kWhite,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Wheel widget
// ─────────────────────────────────────────────────────────────
class _Wheel extends StatelessWidget {
  final FixedExtentScrollController controller;
  final int                         itemCount;
  final String Function(int)        labelBuilder;
  final ValueChanged<int>           onChanged;
  final bool                        looping;
  static const _itemH = 44.0;

  const _Wheel({
    required this.controller,
    required this.itemCount,
    required this.labelBuilder,
    required this.onChanged,
    this.looping = true,
  });

  @override
  Widget build(BuildContext context) {
    final items = List.generate(
        itemCount, (i) => _WheelItem(label: labelBuilder(i)));
    if (looping) {
      return ListWheelScrollView.useDelegate(
        controller: controller, itemExtent: _itemH,
        physics: const FixedExtentScrollPhysics(),
        diameterRatio: 1.4, perspective: 0.003,
        onSelectedItemChanged: onChanged,
        childDelegate: ListWheelChildLoopingListDelegate(children: items),
      );
    }
    return ListWheelScrollView(
      controller: controller, itemExtent: _itemH,
      physics: const FixedExtentScrollPhysics(),
      diameterRatio: 1.4, perspective: 0.003,
      onSelectedItemChanged: onChanged,
      children: items,
    );
  }
}

class _WheelItem extends StatelessWidget {
  final String label;
  final bool   dimmed;
  const _WheelItem({required this.label, this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(label,
          style: TextStyle(
            color: dimmed
                ? kWhite.withOpacity(0.18)
                : kWhite.withOpacity(0.85),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          )),
    );
  }
}