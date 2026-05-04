import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/colors.dart';
import '../../models/event.dart';
import '../../store/task_store.dart';
import '../../store/wallet_store.dart';
import '../widgets/wallet/wallet_sheet.dart';

// ─────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────
void showCreateEventSheet(BuildContext context, {VoidCallback? onSaved}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    enableDrag: true,
    builder: (_) => _CreateEventSheet(onSaved: onSaved),
  );
}

// ─────────────────────────────────────────────────────────────
// Sheet widget
// ─────────────────────────────────────────────────────────────
class _CreateEventSheet extends StatefulWidget {
  final VoidCallback? onSaved;
  const _CreateEventSheet({this.onSaved});
  @override
  State<_CreateEventSheet> createState() => _CreateEventSheetState();
}

class _CreateEventSheetState extends State<_CreateEventSheet>
    with SingleTickerProviderStateMixin {

  final _titleCtrl    = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _notesCtrl    = TextEditingController();
  final _titleFocus   = FocusNode();

  EventCategory _category   = EventCategory.academic;
  DateTime      _startDate  = DateTime.now();
  DateTime      _endDate    = DateTime.now();
  TimeOfDay?    _startTime;
  TimeOfDay?    _endTime;
  bool          _showOptional = false;
  bool          _saving       = false;

  // ── Linked cost ───────────────────────────────────────────
  bool                  _addCost      = false;
  final _costCtrl       = TextEditingController();
  WalletExpenseCategory _costCategory = WalletExpenseCategory.other;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  // Accent colour for the event category
  static const Color _kEventAccent = Color(0xFF3BBFA3); // teal-green

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    _titleFocus.dispose();
    _costCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Save ───────────────────────────────────────────────────
  void _save() {
    if (_titleCtrl.text.trim().isEmpty) {
      HapticFeedback.lightImpact();
      FocusScope.of(context).requestFocus(_titleFocus);
      return;
    }
    // End date must not be before start date
    if (_endDate.isBefore(_startDate)) {
      setState(() => _endDate = _startDate);
    }
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    final eventId = DateTime.now().millisecondsSinceEpoch.toString();

    // ── Linked expense ─────────────────────────────────────
    String? linkedExpenseId;
    if (_addCost && _costCtrl.text.trim().isNotEmpty) {
      final amount = double.tryParse(_costCtrl.text.trim());
      if (amount != null && amount > 0) {
        linkedExpenseId = 'exp_evt_$eventId';
        const months = ['Jan','Feb','Mar','Apr','May','Jun',
                        'Jul','Aug','Sep','Oct','Nov','Dec'];
        final d = _startDate;
        final dateRange = '${months[d.month - 1]} ${d.day}, ${d.year}';
        WalletStore.instance.addExpense(WalletExpense(
          id:        linkedExpenseId,
          name:      _titleCtrl.text.trim(),
          amount:    amount,
          dateRange: dateRange,
          dueDate:   _startDate,
          status:    WalletExpenseStatus.unpaid,
          icon:      _costCategory.icon,
          iconColor: _costCategory.color,
          category:  _costCategory,
          eventId:   linkedExpenseId,
        ));
      }
    }

    final event = Event(
      id:               eventId,
      title:            _titleCtrl.text.trim(),
      category:         _category,
      startDate:        _startDate,
      endDate:          _endDate,
      startTime:        _startTime,
      endTime:          _endTime,
      location:         _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
      notes:            _notesCtrl.text.trim().isEmpty    ? null : _notesCtrl.text.trim(),
      linkedExpenseId:  linkedExpenseId,
    );

    TaskStore.instance.addEvent(event);
    Navigator.pop(context);
    widget.onSaved?.call();
  }

  // ── Date / time pickers ────────────────────────────────────
  Future<void> _pickStartDate() async {
    final picked = await _showDatePicker(context, initial: _startDate);
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await _showDatePicker(
      context,
      initial: _endDate.isBefore(_startDate) ? _startDate : _endDate,
      firstDate: _startDate,
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<DateTime?> _showDatePicker(BuildContext ctx,
      {required DateTime initial, DateTime? firstDate}) {
    return showModalBottomSheet<DateTime>(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _IosDatePickerSheet(
        initial:   initial,
        firstDate: firstDate ?? DateTime.now().subtract(const Duration(days: 365)),
        lastDate:  DateTime.now().add(const Duration(days: 365 * 3)),
      ),
    );
  }

  Future<void> _pickStartTime() async {
    final picked = await _showTimePicker(context,
        initial: _startTime ?? TimeOfDay.now());
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _pickEndTime() async {
    final picked = await _showTimePicker(context,
        initial: _endTime ?? _startTime ?? TimeOfDay.now());
    if (picked != null) setState(() => _endTime = picked);
  }

  Future<TimeOfDay?> _showTimePicker(BuildContext ctx,
      {required TimeOfDay initial}) {
    return showModalBottomSheet<TimeOfDay>(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _IosTimePickerSheet(initial: initial),
    );
  }

  // ── Formatting helpers ─────────────────────────────────────
  String _fmtDate(DateTime d) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dd    = DateTime(d.year, d.month, d.day);
    if (dd == today) return 'Today';
    if (dd == today.add(const Duration(days: 1))) return 'Tomorrow';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }

  String _fmtTime(TimeOfDay t) {
    final h      = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m      = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
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
        height: MediaQuery.of(context).size.height * 0.78,
        decoration: const BoxDecoration(
          color: Color(0xFF1A2D5A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // Handle
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                  color: kWhite.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(2)),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: _kEventAccent.withOpacity(0.14),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: _kEventAccent.withOpacity(0.3), width: 1.5),
                    ),
                    child: const Icon(Icons.event_rounded,
                        color: _kEventAccent, size: 21),
                  ),
                  const SizedBox(width: 13),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Add Event',
                          style: TextStyle(
                              color: kWhite,
                              fontSize: 17,
                              fontWeight: FontWeight.bold)),
                      Text('Schedule something on your calendar',
                          style: TextStyle(
                              color: kWhite.withOpacity(0.4), fontSize: 12)),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                          color: kWhite.withOpacity(0.07),
                          shape: BoxShape.circle),
                      child: Icon(Icons.close_rounded,
                          color: kWhite.withOpacity(0.5), size: 17),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Divider(height: 1, color: kWhite.withOpacity(0.07)),

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Event title ──────────────────────────
                    _FieldLabel(label: 'Event Title', icon: Icons.edit_rounded),
                    const SizedBox(height: 8),
                    _TitleField(
                        controller: _titleCtrl, focusNode: _titleFocus),

                    const SizedBox(height: 18),

                    // ── Category ────────────────────────────
                    _FieldLabel(
                        label: 'Category', icon: Icons.label_rounded),
                    const SizedBox(height: 8),
                    _EventCategoryDropdown(
                      value: _category,
                      onChanged: (v) => setState(() => _category = v),
                    ),

                    const SizedBox(height: 18),

                    // ── Date & time ──────────────────────────
                    _FieldLabel(
                        label: 'Date & Time',
                        icon: Icons.calendar_month_rounded),
                    const SizedBox(height: 10),
                    _EventDateTimeSection(
                      startDate:      _startDate,
                      endDate:        _endDate,
                      startTime:      _startTime,
                      endTime:        _endTime,
                      fmtDate:        _fmtDate,
                      fmtTime:        _fmtTime,
                      onPickStartDate: _pickStartDate,
                      onPickEndDate:   _pickEndDate,
                      onPickStartTime: _pickStartTime,
                      onPickEndTime:   _pickEndTime,
                      onClearStartTime: () =>
                          setState(() => _startTime = null),
                      onClearEndTime: () =>
                          setState(() => _endTime = null),
                    ),

                    const SizedBox(height: 12),

                    // ── More options toggle ──────────────────
                    GestureDetector(
                      onTap: () =>
                          setState(() => _showOptional = !_showOptional),
                      child: Row(children: [
                        Expanded(
                            child: Divider(color: kWhite.withOpacity(0.08))),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(children: [
                            Text(
                              _showOptional ? 'Less options' : 'More options',
                              style: TextStyle(
                                  color: _kEventAccent.withOpacity(0.8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 4),
                            AnimatedRotation(
                              turns: _showOptional ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: _kEventAccent.withOpacity(0.8),
                                  size: 17),
                            ),
                          ]),
                        ),
                        Expanded(
                            child: Divider(color: kWhite.withOpacity(0.08))),
                      ]),
                    ),

                    // ── Optional fields ──────────────────────
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: _EventOptionalSection(
                        locationCtrl: _locationCtrl,
                        notesCtrl:    _notesCtrl,
                      ),
                      crossFadeState: _showOptional
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 260),
                    ),

                    const SizedBox(height: 16),

                    // ── Add cost to wallet ───────────────────
                    _CostSection(
                      addCost:    _addCost,
                      costCtrl:   _costCtrl,
                      category:   _costCategory,
                      onToggle:   (v) => setState(() => _addCost = v),
                      onCategory: (v) => setState(() => _costCategory = v),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Save button ─────────────────────────────────
            Container(
              decoration: BoxDecoration(
                  border: Border(
                      top: BorderSide(color: kWhite.withOpacity(0.07)))),
              padding: EdgeInsets.fromLTRB(
                  20, 14, 20, 14 + mq.padding.bottom),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                        colors: [Color(0xFF3BBFA3), Color(0xFF2A9E85)]),
                    boxShadow: [
                      BoxShadow(
                          color: _kEventAccent.withOpacity(0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 4))
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
                                    valueColor: AlwaysStoppedAnimation(kWhite)))
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_rounded,
                                      color: kNavyDark, size: 18),
                                  SizedBox(width: 7),
                                  Text('Save Event',
                                      style: TextStyle(
                                          color: kNavyDark,
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
// Event date + time section
// ─────────────────────────────────────────────────────────────
class _EventDateTimeSection extends StatelessWidget {
  final DateTime startDate, endDate;
  final TimeOfDay? startTime, endTime;
  final String Function(DateTime) fmtDate;
  final String Function(TimeOfDay) fmtTime;
  final VoidCallback onPickStartDate, onPickEndDate;
  final VoidCallback onPickStartTime, onPickEndTime;
  final VoidCallback onClearStartTime, onClearEndTime;

  const _EventDateTimeSection({
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    required this.fmtDate,
    required this.fmtTime,
    required this.onPickStartDate,
    required this.onPickEndDate,
    required this.onPickStartTime,
    required this.onPickEndTime,
    required this.onClearStartTime,
    required this.onClearEndTime,
  });

  static const Color _accent = Color(0xFF3BBFA3);
  static const Color _timeAccent = Color(0xFF9B88E8);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kWhite.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kWhite.withOpacity(0.09)),
      ),
      child: Column(
        children: [
          // ── START ───────────────────────────────────────
          _SectionLabel(
              icon: Icons.play_circle_outline_rounded,
              label: 'START',
              accent: _accent),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: Row(
              children: [
                Expanded(
                  child: _DateChip(
                    label: 'Start Date',
                    value: fmtDate(startDate),
                    onTap: onPickStartDate,
                    accent: _accent,
                    icon: Icons.event_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: startTime != null
                      ? _TimeChipFilled(
                          value: fmtTime(startTime!),
                          accent: _timeAccent,
                          onTap: onPickStartTime,
                          onClear: onClearStartTime,
                        )
                      : _AddTimeChip(
                          label: 'Start time',
                          onTap: onPickStartTime),
                ),
              ],
            ),
          ),

          Divider(height: 1, indent: 14, endIndent: 14,
              color: kWhite.withOpacity(0.07)),

          // ── END ─────────────────────────────────────────
          _SectionLabel(
              icon: Icons.stop_circle_outlined,
              label: 'END',
              accent: const Color(0xFFE8A870)),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
            child: Row(
              children: [
                Expanded(
                  child: _DateChip(
                    label: 'End Date',
                    value: fmtDate(endDate),
                    onTap: onPickEndDate,
                    accent: const Color(0xFFE8A870),
                    icon: Icons.event_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: endTime != null
                      ? _TimeChipFilled(
                          value: fmtTime(endTime!),
                          accent: _timeAccent,
                          onTap: onPickEndTime,
                          onClear: onClearEndTime,
                        )
                      : _AddTimeChip(
                          label: 'End time', onTap: onPickEndTime),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  const _SectionLabel(
      {required this.icon, required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Row(children: [
        Icon(icon, color: accent, size: 13),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: accent.withOpacity(0.7),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0)),
      ]),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label, value;
  final VoidCallback onTap;
  final Color accent;
  final IconData? icon;
  const _DateChip(
      {required this.label,
      required this.value,
      required this.onTap,
      required this.accent,
      this.icon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.09),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withOpacity(0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  color: accent.withOpacity(0.6),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5)),
          const SizedBox(height: 3),
          Row(children: [
            if (icon != null) ...[
              Icon(icon, size: 11, color: accent.withOpacity(0.7)),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(value,
                  style: TextStyle(
                      color: accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _TimeChipFilled extends StatelessWidget {
  final String value;
  final Color accent;
  final VoidCallback onTap, onClear;
  const _TimeChipFilled(
      {required this.value,
      required this.accent,
      required this.onTap,
      required this.onClear});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 7, 6, 7),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.09),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withOpacity(0.3)),
        ),
        child: Row(children: [
          Icon(Icons.access_time_rounded,
              size: 11, color: accent.withOpacity(0.7)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis),
          ),
          GestureDetector(
            onTap: onClear,
            child: Icon(Icons.close_rounded,
                size: 13, color: accent.withOpacity(0.45)),
          ),
        ]),
      ),
    );
  }
}

class _AddTimeChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AddTimeChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: kWhite.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: kWhite.withOpacity(0.08)),
        ),
        child: Row(children: [
          Icon(Icons.add_circle_outline_rounded,
              size: 13, color: kWhite.withOpacity(0.25)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(label,
                style: TextStyle(
                    color: kWhite.withOpacity(0.3),
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Event category dropdown
// ─────────────────────────────────────────────────────────────
class _EventCategoryDropdown extends StatelessWidget {
  final EventCategory value;
  final ValueChanged<EventCategory> onChanged;
  const _EventCategoryDropdown(
      {required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = value.color;
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: c.withOpacity(0.09),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: c.withOpacity(0.35)),
        ),
        child: Row(children: [
          Container(
              width: 9,
              height: 9,
              decoration:
                  BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('EVENT CATEGORY',
                    style: TextStyle(
                        color: c.withOpacity(0.6),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5)),
                Text(value.label,
                    style: TextStyle(
                        color: c,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Icon(Icons.expand_more_rounded,
              color: c.withOpacity(0.6), size: 18),
        ]),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _EventCategorySheet(
        selected: value,
        onSelected: (v) {
          onChanged(v);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _EventCategorySheet extends StatelessWidget {
  final EventCategory selected;
  final ValueChanged<EventCategory> onSelected;
  const _EventCategorySheet(
      {required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 28),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2D5B),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: kWhite.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 40,
                offset: const Offset(0, -4))
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 14, bottom: 18),
                decoration: BoxDecoration(
                    color: kWhite.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                        color: const Color(0xFF3BBFA3).withOpacity(0.14),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color:
                                const Color(0xFF3BBFA3).withOpacity(0.3),
                            width: 1.5)),
                    child: const Icon(Icons.event_rounded,
                        color: Color(0xFF3BBFA3), size: 21),
                  ),
                  const SizedBox(width: 13),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Select Category',
                            style: TextStyle(
                                color: kWhite,
                                fontSize: 17,
                                fontWeight: FontWeight.bold)),
                        Text('What kind of event is this?',
                            style: TextStyle(
                                color: kWhite.withOpacity(0.4),
                                fontSize: 12)),
                      ]),
                ]),
              ),
              const SizedBox(height: 16),
              Divider(
                  color: kWhite.withOpacity(0.07),
                  thickness: 1,
                  indent: 22,
                  endIndent: 22),
              const SizedBox(height: 6),
              ...EventCategory.values.map((cat) => _EventCatCard(
                    cat: cat,
                    selected: selected,
                    onTap: () => onSelected(cat),
                  )),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventCatCard extends StatefulWidget {
  final EventCategory cat, selected;
  final VoidCallback onTap;
  const _EventCatCard(
      {required this.cat, required this.selected, required this.onTap});
  @override
  State<_EventCatCard> createState() => _EventCatCardState();
}

class _EventCatCardState extends State<_EventCatCard> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final c   = widget.cat.color;
    final sel = widget.cat == widget.selected;
    return GestureDetector(
      onTapDown:  (_) => setState(() => _pressed = true),
      onTapUp:    (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 9),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: (_pressed || sel) ? c.withOpacity(0.12) : kWhite.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: (_pressed || sel)
                  ? c.withOpacity(0.55)
                  : kWhite.withOpacity(0.08),
              width: 1.3),
        ),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
                color: c.withOpacity(0.13),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                    color: c.withOpacity(0.25), width: 1.2)),
            child: Icon(widget.cat.icon, color: c, size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.cat.label,
                      style: const TextStyle(
                          color: kWhite,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(widget.cat.description,
                      style: TextStyle(
                          color: kWhite.withOpacity(0.37), fontSize: 12)),
                ]),
          ),
          const SizedBox(width: 6),
          if (sel)
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded,
                  color: kWhite, size: 14))
          else
            Icon(Icons.chevron_right_rounded,
                color: kWhite.withOpacity(0.2), size: 20),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Optional section — location + notes
// ─────────────────────────────────────────────────────────────
class _EventOptionalSection extends StatelessWidget {
  final TextEditingController locationCtrl, notesCtrl;
  const _EventOptionalSection(
      {required this.locationCtrl, required this.notesCtrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),

        // Location
        _FieldLabel(
            label: 'Location', icon: Icons.location_on_rounded),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: kWhite.withOpacity(0.05),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: kWhite.withOpacity(0.1)),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: TextField(
            controller: locationCtrl,
            style: const TextStyle(color: kWhite, fontSize: 14),
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Where is this event?',
              hintStyle: TextStyle(
                  color: kWhite.withOpacity(0.22), fontSize: 14),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),

        const SizedBox(height: 18),

        // Notes
        _FieldLabel(label: 'Notes', icon: Icons.notes_rounded),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: kWhite.withOpacity(0.05),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: kWhite.withOpacity(0.1)),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: TextField(
            controller: notesCtrl,
            style: const TextStyle(color: kWhite, fontSize: 13),
            maxLines: 3, minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Add extra details or a note…',
              hintStyle: TextStyle(
                  color: kWhite.withOpacity(0.22), fontSize: 13),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shared field label
// ─────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String label;
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
// Event title text field
// ─────────────────────────────────────────────────────────────
class _TitleField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  const _TitleField(
      {required this.controller, required this.focusNode});

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
            color: kWhite, fontSize: 17, fontWeight: FontWeight.w600),
        maxLines: 2, minLines: 1,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: 'What\'s the event?',
          hintStyle: TextStyle(
              color: kWhite.withOpacity(0.22),
              fontSize: 17,
              fontWeight: FontWeight.w600),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// iOS-style drum-roll time picker (reused from create_task_sheet)
// ─────────────────────────────────────────────────────────────
class _IosTimePickerSheet extends StatefulWidget {
  final TimeOfDay initial;
  const _IosTimePickerSheet({required this.initial});
  @override
  State<_IosTimePickerSheet> createState() => _IosTimePickerSheetState();
}

class _IosTimePickerSheetState extends State<_IosTimePickerSheet> {
  static const double _itemH   = 52.0;
  static const double _visible = 5;
  static const double _listH   = _itemH * _visible;

  late int _hour12, _minute, _amPm;
  late FixedExtentScrollController _hourCtrl, _minuteCtrl, _amPmCtrl;

  @override
  void initState() {
    super.initState();
    final h = widget.initial.hour;
    _amPm   = h >= 12 ? 1 : 0;
    _hour12 = h % 12 == 0 ? 12 : h % 12;
    _minute = widget.initial.minute;
    _hourCtrl   = FixedExtentScrollController(initialItem: 1200 + (_hour12 - 1));
    _minuteCtrl = FixedExtentScrollController(initialItem: 3000 + _minute);
    _amPmCtrl   = FixedExtentScrollController(initialItem: _amPm);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    _amPmCtrl.dispose();
    super.dispose();
  }

  TimeOfDay get _result {
    int hour = _hour12 % 12 + (_amPm == 1 ? 12 : 0);
    return TimeOfDay(hour: hour, minute: _minute);
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 40, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(color: kWhite.withOpacity(0.18), borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
            child: Row(children: [
              Container(width: 38, height: 38,
                decoration: BoxDecoration(color: const Color(0xFF9B88E8).withOpacity(0.14), shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF9B88E8).withOpacity(0.3))),
                child: const Icon(Icons.access_time_rounded, color: Color(0xFF9B88E8), size: 18)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Set Time', style: TextStyle(color: kWhite, fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Scroll to choose', style: TextStyle(color: kWhite.withOpacity(0.38), fontSize: 12)),
              ]),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(width: 30, height: 30,
                  decoration: BoxDecoration(color: kWhite.withOpacity(0.07), shape: BoxShape.circle),
                  child: Icon(Icons.close_rounded, color: kWhite.withOpacity(0.45), size: 16)),
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
                top: _itemH * ((_visible - 1) / 2), left: 16, right: 16, height: _itemH,
                child: Container(decoration: BoxDecoration(
                    color: kWhite.withOpacity(0.07), borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kWhite.withOpacity(0.1))))),
              Positioned(top: 0, left: 0, right: 0, height: _itemH * 1.5,
                child: IgnorePointer(child: Container(decoration: BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [const Color(0xFF1A2D5A), const Color(0xFF1A2D5A).withOpacity(0)]))))),
              Positioned(bottom: 0, left: 0, right: 0, height: _itemH * 1.5,
                child: IgnorePointer(child: Container(decoration: BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [const Color(0xFF1A2D5A), const Color(0xFF1A2D5A).withOpacity(0)]))))),
              Row(children: [
                Expanded(flex: 3, child: _Wheel(controller: _hourCtrl, itemCount: 12,
                    labelBuilder: (i) => '${(i % 12) + 1}', onChanged: (i) => setState(() => _hour12 = (i % 12) + 1))),
                Text(':', style: TextStyle(color: kWhite.withOpacity(0.6), fontSize: 28, fontWeight: FontWeight.w300)),
                Expanded(flex: 3, child: _Wheel(controller: _minuteCtrl, itemCount: 60,
                    labelBuilder: (i) => (i % 60).toString().padLeft(2, '0'), onChanged: (i) => setState(() => _minute = i % 60))),
                Expanded(flex: 2, child: _Wheel(controller: _amPmCtrl, itemCount: 2, looping: false,
                    labelBuilder: (i) => i == 0 ? 'AM' : 'PM', onChanged: (i) => setState(() => _amPm = i))),
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
                  gradient: const LinearGradient(colors: [Color(0xFF9B88E8), Color(0xFF7B6BC8)]),
                  boxShadow: [BoxShadow(color: const Color(0xFF9B88E8).withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Material(color: Colors.transparent, child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.pop(context, _result),
                  child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check_rounded, color: kWhite, size: 18),
                    const SizedBox(width: 7),
                    Text(_fmtPreview(_result),
                        style: const TextStyle(color: kWhite, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
                  ])),
                )),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtPreview(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
  }
}

// ─────────────────────────────────────────────────────────────
// iOS-style drum-roll date picker
// ─────────────────────────────────────────────────────────────
class _IosDatePickerSheet extends StatefulWidget {
  final DateTime initial, firstDate, lastDate;
  const _IosDatePickerSheet(
      {required this.initial, required this.firstDate, required this.lastDate});
  @override
  State<_IosDatePickerSheet> createState() => _IosDatePickerSheetState();
}

class _IosDatePickerSheetState extends State<_IosDatePickerSheet> {
  static const double _itemH   = 52.0;
  static const double _visible = 5;
  static const double _listH   = _itemH * _visible;
  static const List<String> _months = [
    'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
  ];

  late int _month, _day, _year;
  late final int _firstYear, _lastYear;
  late FixedExtentScrollController _monthCtrl, _dayCtrl, _yearCtrl;

  @override
  void initState() {
    super.initState();
    _month = widget.initial.month;
    _day   = widget.initial.day;
    _year  = widget.initial.year;
    _firstYear = widget.firstDate.year;
    _lastYear  = widget.lastDate.year;
    _monthCtrl = FixedExtentScrollController(initialItem: 1200 + (_month - 1));
    _dayCtrl   = FixedExtentScrollController(initialItem: 3007 + (_day - 1));
    _yearCtrl  = FixedExtentScrollController(initialItem: _year - _firstYear);
  }

  @override
  void dispose() {
    _monthCtrl.dispose(); _dayCtrl.dispose(); _yearCtrl.dispose();
    super.dispose();
  }

  int get _daysInMonth => DateTime(_year, _month + 1, 0).day;
  DateTime get _result => DateTime(_year, _month, _day.clamp(1, _daysInMonth));

  String _fmtResult(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dd = DateTime(d.year, d.month, d.day);
    if (dd == today) return 'Today';
    if (dd == today.add(const Duration(days: 1))) return 'Tomorrow';
    return '${_months[d.month - 1]} ${d.day}, ${d.year}';
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 40, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(color: kWhite.withOpacity(0.18), borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
            child: Row(children: [
              Container(width: 38, height: 38,
                decoration: BoxDecoration(color: kTeal.withOpacity(0.14), shape: BoxShape.circle,
                    border: Border.all(color: kTeal.withOpacity(0.3))),
                child: const Icon(Icons.calendar_today_rounded, color: kTeal, size: 17)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Set Date', style: TextStyle(color: kWhite, fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Scroll to choose', style: TextStyle(color: kWhite.withOpacity(0.38), fontSize: 12)),
              ]),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(width: 30, height: 30,
                  decoration: BoxDecoration(color: kWhite.withOpacity(0.07), shape: BoxShape.circle),
                  child: Icon(Icons.close_rounded, color: kWhite.withOpacity(0.45), size: 16)),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          Divider(height: 1, color: kWhite.withOpacity(0.07)),
          const SizedBox(height: 8),
          SizedBox(
            height: _listH,
            child: Stack(children: [
              Positioned(top: _itemH * ((_visible - 1) / 2), left: 16, right: 16, height: _itemH,
                child: Container(decoration: BoxDecoration(color: kWhite.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(14), border: Border.all(color: kWhite.withOpacity(0.1))))),
              Positioned(top: 0, left: 0, right: 0, height: _itemH * 1.5,
                child: IgnorePointer(child: Container(decoration: BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [const Color(0xFF1A2D5A), const Color(0xFF1A2D5A).withOpacity(0)]))))),
              Positioned(bottom: 0, left: 0, right: 0, height: _itemH * 1.5,
                child: IgnorePointer(child: Container(decoration: BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [const Color(0xFF1A2D5A), const Color(0xFF1A2D5A).withOpacity(0)]))))),
              Row(children: [
                Expanded(flex: 3, child: _Wheel(controller: _monthCtrl, itemCount: 12,
                    labelBuilder: (i) => _months[i % 12], onChanged: (i) => setState(() => _month = (i % 12) + 1))),
                Expanded(flex: 2, child: ListWheelScrollView.useDelegate(
                  controller: _dayCtrl, itemExtent: _itemH,
                  physics: const FixedExtentScrollPhysics(), diameterRatio: 1.4, perspective: 0.003,
                  onSelectedItemChanged: (i) => setState(() => _day = (i % 31) + 1),
                  childDelegate: ListWheelChildLoopingListDelegate(
                    children: List.generate(31, (i) => _WheelItem(
                      label: '${i + 1}', dimmed: (i + 1) > _daysInMonth))),
                )),
                Expanded(flex: 3, child: _Wheel(controller: _yearCtrl,
                    itemCount: _lastYear - _firstYear + 1, looping: false,
                    labelBuilder: (i) => '${_firstYear + i}',
                    onChanged: (i) => setState(() => _year = _firstYear + i))),
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
                  gradient: const LinearGradient(colors: [kTeal, Color(0xFF6AB8B3)]),
                  boxShadow: [BoxShadow(color: kTeal.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Material(color: Colors.transparent, child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.pop(context, _result),
                  child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check_rounded, color: kNavyDark, size: 18),
                    const SizedBox(width: 7),
                    Text(_fmtResult(_result),
                        style: const TextStyle(color: kNavyDark, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
                  ])),
                )),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shared drum-roll wheel widget
// ─────────────────────────────────────────────────────────────
class _Wheel extends StatelessWidget {
  final FixedExtentScrollController controller;
  final int itemCount;
  final String Function(int) labelBuilder;
  final ValueChanged<int> onChanged;
  final bool looping;

  const _Wheel({
    required this.controller,
    required this.itemCount,
    required this.labelBuilder,
    required this.onChanged,
    this.looping = true,
  });

  @override
  Widget build(BuildContext context) {
    const double itemH = _IosTimePickerSheetState._itemH;
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: itemH,
      physics: const FixedExtentScrollPhysics(),
      diameterRatio: 1.4,
      perspective: 0.003,
      squeeze: 1.0,
      onSelectedItemChanged: onChanged,
      childDelegate: looping
          ? ListWheelChildLoopingListDelegate(
              children: List.generate(itemCount, (i) => _WheelItem(label: labelBuilder(i))))
          : ListWheelChildListDelegate(
              children: List.generate(itemCount, (i) => _WheelItem(label: labelBuilder(i)))),
    );
  }
}

class _WheelItem extends StatelessWidget {
  final String label;
  final bool dimmed;
  const _WheelItem({required this.label, this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(label,
          style: TextStyle(
              color: dimmed ? kWhite.withOpacity(0.18) : kWhite,
              fontSize: 26,
              fontWeight: FontWeight.w300,
              letterSpacing: 0.5)),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Cost Section — mirrors create_task_sheet _CostSection exactly
// ─────────────────────────────────────────────────────────────
class _CostSection extends StatelessWidget {
  final bool addCost;
  final TextEditingController costCtrl;
  final WalletExpenseCategory category;
  final ValueChanged<bool> onToggle;
  final ValueChanged<WalletExpenseCategory> onCategory;

  const _CostSection({
    required this.addCost,
    required this.costCtrl,
    required this.category,
    required this.onToggle,
    required this.onCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle row
        GestureDetector(
          onTap: () => onToggle(!addCost),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: kWhite.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet_rounded,
                    size: 18, color: kWhite.withOpacity(0.5)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Add cost to wallet',
                      style: TextStyle(
                          color: kWhite.withOpacity(0.65),
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                ),
                AnimatedRotation(
                  turns: addCost ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      color: kWhite.withOpacity(0.4), size: 20),
                ),
              ],
            ),
          ),
        ),

        // Expanded fields
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 240),
          crossFadeState:
              addCost ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Amount field
                Container(
                  decoration: BoxDecoration(
                    color: kWhite.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  child: Row(children: [
                    Text('₱',
                        style: TextStyle(
                            color: kWhite.withOpacity(0.6),
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: costCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: kWhite, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Amount (e.g. 250.00)',
                          hintStyle:
                              TextStyle(color: kWhite.withOpacity(0.3), fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                // Category chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: WalletExpenseCategory.values.map((cat) {
                    final selected = cat == category;
                    return GestureDetector(
                      onTap: () => onCategory(cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: selected
                              ? cat.color.withOpacity(0.2)
                              : kWhite.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected ? cat.color : Colors.transparent,
                            width: 1.4,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(cat.icon,
                                size: 13,
                                color: selected
                                    ? cat.color
                                    : kWhite.withOpacity(0.45)),
                            const SizedBox(width: 5),
                            Text(cat.label,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: selected
                                        ? cat.color
                                        : kWhite.withOpacity(0.55),
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.w400)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}