import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/wallet/wallet_sheet.dart';
import 'auth_store.dart';

// ─────────────────────────────────────────────────────────────
// Storage key
// ─────────────────────────────────────────────────────────────
String get _kWalletData => AuthStore.instance.scopedKey('wallet_data');

// ─────────────────────────────────────────────────────────────
// Savings history point
// ─────────────────────────────────────────────────────────────
class SavingsPoint {
  final String month; // e.g. "Jan", "Feb"
  final double value;
  const SavingsPoint(this.month, this.value);

  Map<String, dynamic> toJson() => {'month': month, 'value': value};
  factory SavingsPoint.fromJson(Map<String, dynamic> j) =>
      SavingsPoint(j['month'] as String, (j['value'] as num).toDouble());
}

// ─────────────────────────────────────────────────────────────
// Savings log entry — one record per addToSavings() call
// ─────────────────────────────────────────────────────────────
class SavingsEntry {
  final double amount;
  final DateTime date;
  final String? note;

  const SavingsEntry({required this.amount, required this.date, this.note});

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'date': date.toIso8601String(),
    if (note != null) 'note': note,
  };

  factory SavingsEntry.fromJson(Map<String, dynamic> j) => SavingsEntry(
    amount: (j['amount'] as num).toDouble(),
    date: DateTime.parse(j['date'] as String),
    note: j['note'] as String?,
  );
}

// ─────────────────────────────────────────────────────────────
// Monthly spend history point
// ─────────────────────────────────────────────────────────────
class MonthlySpendPoint {
  final String month; // e.g. "Jan 25", keyed by "yyyy-M" internally
  final double spent;
  final double budget;
  const MonthlySpendPoint(this.month, this.spent, this.budget);

  Map<String, dynamic> toJson() =>
      {'month': month, 'spent': spent, 'budget': budget};
  factory MonthlySpendPoint.fromJson(Map<String, dynamic> j) =>
      MonthlySpendPoint(
        j['month'] as String,
        (j['spent'] as num).toDouble(),
        (j['budget'] as num).toDouble(),
      );
}

// ─────────────────────────────────────────────────────────────
// WalletStore
// ─────────────────────────────────────────────────────────────
class WalletStore extends ChangeNotifier {
  WalletStore._();
  static final WalletStore instance = WalletStore._();

  double _dailyAllowance = 0.0;
  double _savings        = 0.0;
  double _monthlyBudget  = 0.0;
  final List<WalletExpense>      _expenses            = [];
  final List<SavingsPoint>       _savingsHistory      = [];
  final List<SavingsEntry>       _savingsLog          = [];
  final List<MonthlySpendPoint>  _monthlySpendHistory = [];
  String? _loadedUserId;

  // ── Locked-in spend accumulators ─────────────────────────
  // These are stamped at the moment of payment and never
  // reduced by deletions — only by explicitly un-marking paid.
  double _todaySpentAccum   = 0.0;
  String _todaySpentDate    = '';   // 'yyyy-M-d'
  double _monthlySpentAccum = 0.0;
  String _monthlySpentMonth = '';   // 'yyyy-M'

  double               get dailyAllowance       => _dailyAllowance;
  double               get savings              => _savings;
  double               get monthlyBudget        => _monthlyBudget;
  List<WalletExpense>  get expenses             => List.unmodifiable(_expenses);
  List<SavingsPoint>   get savingsHistory       => List.unmodifiable(_savingsHistory);
  List<SavingsEntry>   get savingsLog           => List.unmodifiable(_savingsLog);
  List<MonthlySpendPoint> get monthlySpendHistory =>
      List.unmodifiable(_monthlySpendHistory);

  // ── Monthly spend — locked in at payment time, unaffected by deletions ──
  double get monthlySpent {
    final now      = DateTime.now();
    final monthStr = '${now.year}-${now.month}';
    if (_monthlySpentMonth != monthStr) return 0.0;
    return _monthlySpentAccum;
  }

  // ── Budget progress bar (0.0–1.0, clamped) ───────────────
  double get budgetUsedFraction {
    if (_monthlyBudget <= 0) return 0.0;
    return (monthlySpent / _monthlyBudget).clamp(0.0, 1.0);
  }

  // ── TODAY's spend — locked in at payment time, unaffected by deletions ──
  double get todaySpent {
    final now      = DateTime.now();
    final todayStr = '${now.year}-${now.month}-${now.day}';
    if (_todaySpentDate != todayStr) return 0.0;
    return _todaySpentAccum;
  }

  // ── Daily remaining (can go negative if over-spent) ──────
  double get dailyRemaining => _dailyAllowance - todaySpent;

  // ─────────────────────────────────────────────────────────
  // Category-level aggregators
  // These power the Budget Allocation bar chart and the
  // High Priority Expenses donut / balance cards.
  // ─────────────────────────────────────────────────────────

  // Total amount of all ACTIVE (unpaid + overdue) expenses per category.
  // Use this for "what do I still owe" — e.g. high-priority balance cards.
  double totalForCategory(WalletExpenseCategory cat) {
    return _expenses
        .where((e) =>
            e.category == cat &&
            (e.status == WalletExpenseStatus.unpaid ||
             e.status == WalletExpenseStatus.overdue))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  // Total committed this month per category — ALL statuses.
  // Paid + unpaid + overdue = the full picture of what you've allocated.
  // This is what the Budget Allocation bar chart should show so that marking
  // an expense paid doesn't make its bar disappear.
  double committedThisMonthForCategory(WalletExpenseCategory cat) {
    final now = DateTime.now();
    return _expenses
        .where((e) =>
            e.category == cat)
        .where((e) {
          final ref = e.dueDate ?? DateTime.now();
          return ref.year == now.year && ref.month == now.month;
        })
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  // Total PAID this month per category.
  double paidThisMonthForCategory(WalletExpenseCategory cat) {
    final now = DateTime.now();
    return _expenses
        .where((e) =>
            e.category == cat &&
            e.status == WalletExpenseStatus.paid)
        .where((e) {
          final ref = e.dueDate ?? DateTime.now();
          return ref.year == now.year && ref.month == now.month;
        })
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  // All active expenses that are high priority (school + health).
  // Powers the High Priority donut chart.
  List<WalletExpense> get highPriorityExpenses => _expenses
      .where((e) =>
          e.category.isHighPriority &&
          (e.status == WalletExpenseStatus.unpaid ||
           e.status == WalletExpenseStatus.overdue))
      .toList();

  // Convenience: total owed per high-priority category.
  // Used by the Academics and Health balance cards.
  double remainingForCategory(WalletExpenseCategory cat) {
    // How much of the monthly budget is "available" for this category,
    // defined as: (paid this month in cat) subtracted from nothing —
    // we return the raw unpaid total since there's no per-category
    // sub-budget yet. Step 2 will add that.
    return totalForCategory(cat);
  }

  // ─────────────────────────────────────────────────────────
  // Initialisation
  // ─────────────────────────────────────────────────────────

  Future<void> load() async {
    if (!AuthStore.instance.isLoggedIn) return;
    final currentUserId = AuthStore.instance.userId;
    if (_loadedUserId == currentUserId) return;
    _loadedUserId = currentUserId;

    _dailyAllowance = 0.0;
    _savings        = 0.0;
    _monthlyBudget  = 0.0;
    _expenses.clear();
    _savingsHistory.clear();
    _monthlySpendHistory.clear();

    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(_kWalletData);
      if (raw != null) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _dailyAllowance = (map['dailyAllowance'] as num?)?.toDouble() ?? 0.0;
        _savings        = (map['savings']        as num?)?.toDouble() ?? 0.0;
        _monthlyBudget  = (map['monthlyBudget']  as num?)?.toDouble() ?? 0.0;
        _todaySpentAccum   = (map['todaySpentAccum']   as num?)?.toDouble() ?? 0.0;
        _todaySpentDate    =  map['todaySpentDate']    as String? ?? '';
        _monthlySpentAccum = (map['monthlySpentAccum'] as num?)?.toDouble() ?? 0.0;
        _monthlySpentMonth =  map['monthlySpentMonth'] as String? ?? '';
        final list      = map['expenses'] as List? ?? [];
        _expenses.addAll(list.map(
            (e) => WalletExpense.fromJson(Map<String, dynamic>.from(e as Map))));
        final histList  = map['savingsHistory'] as List? ?? [];
        _savingsHistory.addAll(histList.map(
            (e) => SavingsPoint.fromJson(Map<String, dynamic>.from(e as Map))));
        final logList   = map['savingsLog'] as List? ?? [];
        _savingsLog.addAll(logList.map(
            (e) => SavingsEntry.fromJson(Map<String, dynamic>.from(e as Map))));
        final mspList   = map['monthlySpendHistory'] as List? ?? [];
        _monthlySpendHistory.addAll(mspList.map(
            (e) => MonthlySpendPoint.fromJson(Map<String, dynamic>.from(e as Map))));
      }
    } catch (_) {
      _dailyAllowance = 0.0;
      _savings        = 0.0;
      _expenses.clear();
      _savingsHistory.clear();
      _savingsLog.clear();
      _monthlySpendHistory.clear();
      await prefs.remove(_kWalletData);
    }

    _recomputeOverdue();
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────
  // Overdue recomputation
  // ─────────────────────────────────────────────────────────

  Future<void> recomputeOverdue() async {
    final changed = _recomputeOverdue();
    if (changed) {
      notifyListeners();
      await save();
    }
  }

  bool _recomputeOverdue() {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    bool anyChanged = false;

    for (int i = 0; i < _expenses.length; i++) {
      final e = _expenses[i];

      if (e.status == WalletExpenseStatus.paid) continue;

      final due = e.dueDate;
      if (due == null) continue;

      final dueDate = DateTime(due.year, due.month, due.day);

      if (dueDate.isBefore(todayDate) &&
          e.status != WalletExpenseStatus.overdue) {
        _expenses[i] = e.copyWith(status: WalletExpenseStatus.overdue);
        anyChanged = true;
      } else if (!dueDate.isBefore(todayDate) &&
          e.status == WalletExpenseStatus.overdue) {
        _expenses[i] = e.copyWith(status: WalletExpenseStatus.unpaid);
        anyChanged = true;
      }
    }
    return anyChanged;
  }

  // ─────────────────────────────────────────────────────────
  // Persistence
  // ─────────────────────────────────────────────────────────

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kWalletData,
      jsonEncode({
        'dailyAllowance': _dailyAllowance,
        'savings':        _savings,
        'monthlyBudget':  _monthlyBudget,
        'todaySpentAccum':   _todaySpentAccum,
        'todaySpentDate':    _todaySpentDate,
        'monthlySpentAccum': _monthlySpentAccum,
        'monthlySpentMonth': _monthlySpentMonth,
        'expenses':             _expenses.map((e) => e.toJson()).toList(),
        'savingsHistory':       _savingsHistory.map((p) => p.toJson()).toList(),
        'savingsLog':           _savingsLog.map((e) => e.toJson()).toList(),
        'monthlySpendHistory':  _monthlySpendHistory.map((p) => p.toJson()).toList(),
      }),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Reload / clear
  // ─────────────────────────────────────────────────────────

  Future<void> reload() async => load();

  // ─────────────────────────────────────────────────────────
  // Mutators
  // ─────────────────────────────────────────────────────────

  Future<void> setDailyAllowance(double value) async {
    _dailyAllowance = value;
    notifyListeners();
    await save();
  }

  Future<void> setSavings(double value) async {
    _savings = value;
    _appendSavingsSnapshot();
    notifyListeners();
    await save();
  }

  // Appends a savings snapshot for the current month.
  // Replaces any existing entry for the same month so there's at most one
  // point per month on the chart.
  void _appendSavingsSnapshot() {
    const monthLabels = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    final now   = DateTime.now();
    final label = monthLabels[now.month - 1];
    // Replace existing point for the same month, otherwise append.
    final idx = _savingsHistory.indexWhere((p) => p.month == label);
    if (idx >= 0) {
      _savingsHistory[idx] = SavingsPoint(label, _savings);
    } else {
      _savingsHistory.add(SavingsPoint(label, _savings));
    }
  }

  // Snapshots the current month's spend + budget into history before the
  // accumulator is about to be reset (month rollover).  Replaces any existing
  // entry for the same label so there's at most one point per month.
  void _appendMonthlySpendSnapshot() {
    const monthLabels = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    final now   = DateTime.now();
    final label = '${monthLabels[now.month - 1]} ${now.year.toString().substring(2)}';
    final idx   = _monthlySpendHistory.indexWhere((p) => p.month == label);
    final point = MonthlySpendPoint(label, _monthlySpentAccum, _monthlyBudget);
    if (idx >= 0) {
      _monthlySpendHistory[idx] = point;
    } else {
      _monthlySpendHistory.add(point);
      // Keep at most 12 months of history.
      if (_monthlySpendHistory.length > 12) _monthlySpendHistory.removeAt(0);
    }
  }

  // Manually record a savings snapshot (e.g. called at month-end).
  Future<void> recordSavingsSnapshot() async {
    _appendSavingsSnapshot();
    notifyListeners();
    await save();
  }

  Future<void> setMonthlyBudget(double value) async {
    _monthlyBudget = value;
    notifyListeners();
    await save();
  }

  Future<void> addExpense(WalletExpense expense) async {
    _expenses.add(expense);
    notifyListeners();
    await save();
  }

  Future<void> markExpensePaid(int index) async {
    if (index < 0 || index >= _expenses.length) return;
    final e = _expenses[index];
    final now = DateTime.now();
    _expenses[index] = e.copyWith(
      status: WalletExpenseStatus.paid,
      paidAt: now,
    );

    final todayStr = '${now.year}-${now.month}-${now.day}';
    final monthStr = '${now.year}-${now.month}';

    if (_todaySpentDate != todayStr) {
      _todaySpentAccum = 0.0;
      _todaySpentDate  = todayStr;
    }
    if (_monthlySpentMonth != monthStr) {
      _appendMonthlySpendSnapshot();
      _monthlySpentAccum = 0.0;
      _monthlySpentMonth = monthStr;
    }

    _todaySpentAccum   += e.amount;
    _monthlySpentAccum += e.amount;

    notifyListeners();
    await save();
  }

  Future<void> toggleExpensePaidUnpaid(int index) async {
    if (index < 0 || index >= _expenses.length) return;
    final e = _expenses[index];
    WalletExpenseStatus next;

    if (e.status == WalletExpenseStatus.paid) {
      // Unpaying — revert to overdue or unpaid, and clear paidAt.
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      if (e.dueDate != null) {
        final dueDate = DateTime(e.dueDate!.year, e.dueDate!.month, e.dueDate!.day);
        next = dueDate.isBefore(todayDate)
            ? WalletExpenseStatus.overdue
            : WalletExpenseStatus.unpaid;
      } else {
        next = WalletExpenseStatus.unpaid;
      }
      _expenses[index] = e.copyWith(status: next, clearPaidAt: true);

      // Reverse the locked-in spend only if it was paid today/this month.
      final paidAt = e.paidAt;
      if (paidAt != null) {
        final now      = DateTime.now();
        final todayStr = '${now.year}-${now.month}-${now.day}';
        final monthStr = '${now.year}-${now.month}';
        final pDayStr  = '${paidAt.year}-${paidAt.month}-${paidAt.day}';
        final pMonStr  = '${paidAt.year}-${paidAt.month}';
        if (_todaySpentDate == todayStr && pDayStr == todayStr) {
          _todaySpentAccum = (_todaySpentAccum - e.amount).clamp(0.0, double.infinity);
        }
        if (_monthlySpentMonth == monthStr && pMonStr == monthStr) {
          _monthlySpentAccum = (_monthlySpentAccum - e.amount).clamp(0.0, double.infinity);
        }
      }
    } else {
      // Paying — stamp paidAt and lock in the spend.
      final now = DateTime.now();
      _expenses[index] = e.copyWith(
        status: WalletExpenseStatus.paid,
        paidAt: now,
      );

      final todayStr = '${now.year}-${now.month}-${now.day}';
      final monthStr = '${now.year}-${now.month}';

      // Reset accumulators if crossing into a new day or month.
      if (_todaySpentDate != todayStr) {
        _todaySpentAccum = 0.0;
        _todaySpentDate  = todayStr;
      }
      if (_monthlySpentMonth != monthStr) {
        _appendMonthlySpendSnapshot();
        _monthlySpentAccum = 0.0;
        _monthlySpentMonth = monthStr;
      }

      _todaySpentAccum   += e.amount;
      _monthlySpentAccum += e.amount;
    }

    notifyListeners();
    await save();
  }

  // ── Add directly to savings — replaces the old "deduct expense" flow ────
  Future<void> addToSavings(double amount, {String? note}) async {
    _savings += amount;
    _savingsLog.add(SavingsEntry(amount: amount, date: DateTime.now(), note: note));
    _appendSavingsSnapshot();
    notifyListeners();
    await save();
  }

  Future<void> removeExpense(int index) async {
    if (index < 0 || index >= _expenses.length) return;
    _expenses.removeAt(index);
    notifyListeners();
    await save();
  }

  Future<void> withdrawFromSavings(double amount, {String? note}) async {
    _savings = (_savings - amount).clamp(0.0, double.infinity);
    _savingsLog.add(SavingsEntry(
      amount: -amount,
      date: DateTime.now(),
      note: note ?? 'Withdrawal',
    ));
    _appendSavingsSnapshot();
    notifyListeners();
    await save();
  }

  Future<void> clearSavingsLog() async {
    _savingsLog.clear();
    notifyListeners();
    await save();
  }

  Future<void> clear() async {
    _dailyAllowance = 0.0;
    _savings        = 0.0;
    _monthlyBudget  = 0.0;
    _todaySpentAccum   = 0.0;
    _todaySpentDate    = '';
    _monthlySpentAccum = 0.0;
    _monthlySpentMonth = '';
    _expenses.clear();
    _savingsHistory.clear();
    _savingsLog.clear();
    _monthlySpendHistory.clear();
    _loadedUserId   = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kWalletData);
    notifyListeners();
  }
}