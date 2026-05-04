import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────
// Result model (returned to caller)
// ─────────────────────────────────────────────────────────────
class SpaceResult {
  final String name;
  final String description;
  final Color accentColor;
  final DateTime startDate;
  final DateTime endDate;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;

  const SpaceResult({
    required this.name,
    required this.description,
    required this.accentColor,
    required this.startDate,
    required this.endDate,
    this.startTime,
    this.endTime,
  });
}

// ─────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────
void showCreateSpaceSheet(BuildContext context, {void Function(SpaceResult)? onSaved}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    enableDrag: true,
    builder: (_) => CreateSpaceSheet(onSaved: onSaved),
  );
}

// ─────────────────────────────────────────────────────────────
// Sheet
// ─────────────────────────────────────────────────────────────
class CreateSpaceSheet extends StatefulWidget {
  final void Function(SpaceResult)? onSaved;
  const CreateSpaceSheet({super.key, this.onSaved});
  @override
  State<CreateSpaceSheet> createState() => _CreateSpaceSheetState();
}

class _CreateSpaceSheetState extends State<CreateSpaceSheet>
    with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  static final _palette = [
    Color(0xFF9B88E8),
    AppColors.link,
    Color(0xFF3BBFA3),
    Color(0xFFE8D870),
    Color(0xFFE8A870),
    Color(0xFFD96B8A),
    AppColors.accent,
    AppColors.subtitle,
  ];
  int _colorIdx = 0;

  DateTime _startDate = DateTime.now();
  DateTime _endDate   = DateTime.now();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  Color get _accent => _palette[_colorIdx];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  // ── Formatting ─────────────────────────────────────────────
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

  // ── Pickers ────────────────────────────────────────────────
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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq     = MediaQuery.of(context);
    final bottom = mq.viewInsets.bottom;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        margin: EdgeInsets.only(bottom: bottom),
        height: mq.size.height * 0.78,
        decoration: BoxDecoration(
          color: AppColors.bgDeep,
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
              color: AppColors.text.withOpacity(0.18),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.14),
                    shape: BoxShape.circle,
                    border: Border.all(color: _accent.withOpacity(0.3), width: 1.5),
                  ),
                  child: Icon(Icons.workspaces_rounded, color: _accent, size: 21),
                ),
                const SizedBox(width: 13),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Create Space',
                      style: TextStyle(color: AppColors.text, fontSize: 17, fontWeight: FontWeight.bold)),
                    Text('Set up a new project workspace',
                      style: TextStyle(color: AppColors.text.withOpacity(0.4), fontSize: 12)),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.text.withOpacity(0.07),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded, color: AppColors.text.withOpacity(0.5), size: 17),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Divider(height: 1, color: AppColors.text.withOpacity(0.07)),

          // Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Space Name
                  _FieldLabel(label: 'Space Name', icon: Icons.drive_file_rename_outline_rounded),
                  const SizedBox(height: 8),
                  _SpaceTextField(controller: _nameCtrl, hint: 'e.g. Thesis Research, OJT Project'),

                  const SizedBox(height: 18),

                  // Description
                  _FieldLabel(label: 'Description', icon: Icons.notes_rounded),
                  const SizedBox(height: 8),
                  _SpaceTextField(controller: _descCtrl, hint: 'What is this space for?', maxLines: 3),

                  const SizedBox(height: 18),

                  // Accent Color
                  _FieldLabel(label: 'Accent Color', icon: Icons.palette_rounded),
                  const SizedBox(height: 10),
                  Row(
                    children: List.generate(_palette.length, (i) {
                      final selected = i == _colorIdx;
                      return GestureDetector(
                        onTap: () => setState(() => _colorIdx = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: selected ? 34 : 28,
                          height: selected ? 34 : 28,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: _palette[i],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected ? AppColors.text : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: selected
                                ? [BoxShadow(color: _palette[i].withOpacity(0.5), blurRadius: 8)]
                                : null,
                          ),
                          child: selected
                              ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                              : null,
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 18),

                  // Timeline
                  _FieldLabel(label: 'Timeline', icon: Icons.calendar_month_rounded),
                  const SizedBox(height: 10),
                  _SpaceDateTimeSection(
                    startDate:        _startDate,
                    endDate:          _endDate,
                    startTime:        _startTime,
                    endTime:          _endTime,
                    accent:           _accent,
                    fmtDate:          _fmtDate,
                    fmtTime:          _fmtTime,
                    onPickStartDate:  _pickStartDate,
                    onPickEndDate:    _pickEndDate,
                    onPickStartTime:  _pickStartTime,
                    onPickEndTime:    _pickEndTime,
                    onClearStartTime: () => setState(() => _startTime = null),
                    onClearEndTime:   () => setState(() => _endTime = null),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Footer
          Divider(height: 1, color: AppColors.text.withOpacity(0.07)),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + mq.padding.bottom),
            child: SizedBox(
              width: double.infinity, height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [_accent, _accent.withOpacity(0.75)],
                  ),
                  boxShadow: [
                    BoxShadow(color: _accent.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 4)),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      if (_nameCtrl.text.trim().isEmpty) return;
                      final result = SpaceResult(
                        name:        _nameCtrl.text.trim(),
                        description: _descCtrl.text.trim(),
                        accentColor: _accent,
                        startDate:   _startDate,
                        endDate:     _endDate,
                        startTime:   _startTime,
                        endTime:     _endTime,
                      );
                      Navigator.pop(context);
                      widget.onSaved?.call(result);
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.workspaces_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Create Space',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                      ],
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
// Date + Time section card (matches event sheet style)
// ─────────────────────────────────────────────────────────────
class _SpaceDateTimeSection extends StatelessWidget {
  final DateTime startDate, endDate;
  final TimeOfDay? startTime, endTime;
  final Color accent;
  final String Function(DateTime) fmtDate;
  final String Function(TimeOfDay) fmtTime;
  final VoidCallback onPickStartDate, onPickEndDate;
  final VoidCallback onPickStartTime, onPickEndTime;
  final VoidCallback onClearStartTime, onClearEndTime;

  static const Color _timeAccent = Color(0xFF9B88E8);

  const _SpaceDateTimeSection({
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    required this.accent,
    required this.fmtDate,
    required this.fmtTime,
    required this.onPickStartDate,
    required this.onPickEndDate,
    required this.onPickStartTime,
    required this.onPickEndTime,
    required this.onClearStartTime,
    required this.onClearEndTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.text.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.text.withOpacity(0.09)),
      ),
      child: Column(
        children: [
          // START
          _SectionLabel(icon: Icons.play_circle_outline_rounded, label: 'START', accent: accent),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: Row(children: [
              Expanded(
                child: _DateChip(
                  label: 'Start Date', value: fmtDate(startDate),
                  onTap: onPickStartDate, accent: accent, icon: Icons.event_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: startTime != null
                    ? _TimeChipFilled(
                        value: fmtTime(startTime!), accent: _timeAccent,
                        onTap: onPickStartTime, onClear: onClearStartTime)
                    : _AddTimeChip(label: 'Start time', onTap: onPickStartTime),
              ),
            ]),
          ),

          Divider(height: 1, indent: 14, endIndent: 14, color: AppColors.text.withOpacity(0.07)),

          // END
          _SectionLabel(icon: Icons.stop_circle_outlined, label: 'END',
              accent: const Color(0xFFE8A870)),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
            child: Row(children: [
              Expanded(
                child: _DateChip(
                  label: 'End Date', value: fmtDate(endDate),
                  onTap: onPickEndDate, accent: const Color(0xFFE8A870), icon: Icons.event_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: endTime != null
                    ? _TimeChipFilled(
                        value: fmtTime(endTime!), accent: _timeAccent,
                        onTap: onPickEndTime, onClear: onClearEndTime)
                    : _AddTimeChip(label: 'End time', onTap: onPickEndTime),
              ),
            ]),
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
  const _SectionLabel({required this.icon, required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Row(children: [
        Icon(icon, color: accent, size: 13),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: accent.withOpacity(0.7), fontSize: 10,
          fontWeight: FontWeight.w800, letterSpacing: 1.0)),
      ]),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label, value;
  final VoidCallback onTap;
  final Color accent;
  final IconData? icon;
  const _DateChip({required this.label, required this.value, required this.onTap,
      required this.accent, this.icon});

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
          Text(label, style: TextStyle(color: accent.withOpacity(0.6), fontSize: 9,
              fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          const SizedBox(height: 3),
          Row(children: [
            if (icon != null) ...[
              Icon(icon, size: 11, color: accent.withOpacity(0.7)),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(value, style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w700),
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
  const _TimeChipFilled({required this.value, required this.accent,
      required this.onTap, required this.onClear});

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
          Icon(Icons.access_time_rounded, size: 11, color: accent.withOpacity(0.7)),
          const SizedBox(width: 4),
          Expanded(child: Text(value, style: TextStyle(color: accent, fontSize: 12,
              fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
          GestureDetector(onTap: onClear,
            child: Icon(Icons.close_rounded, size: 13, color: accent.withOpacity(0.45))),
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
          color: AppColors.text.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.text.withOpacity(0.08)),
        ),
        child: Row(children: [
          Icon(Icons.add_circle_outline_rounded, size: 13, color: AppColors.text.withOpacity(0.25)),
          const SizedBox(width: 5),
          Flexible(child: Text(label, style: TextStyle(color: AppColors.text.withOpacity(0.3),
              fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Field helpers
// ─────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _FieldLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 13, color: AppColors.text.withOpacity(0.4)),
      const SizedBox(width: 6),
      Text(label.toUpperCase(),
        style: TextStyle(color: AppColors.text.withOpacity(0.4), fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 0.8)),
    ]);
  }
}

class _SpaceTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  const _SpaceTextField({required this.controller, required this.hint, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: AppColors.text, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.text.withOpacity(0.25), fontSize: 14),
        filled: true,
        fillColor: AppColors.text.withOpacity(0.05),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.text.withOpacity(0.1))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.text.withOpacity(0.1))),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: AppColors.accent, width: 1.5)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// iOS drum-roll time picker
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
    _hourCtrl.dispose(); _minuteCtrl.dispose(); _amPmCtrl.dispose();
    super.dispose();
  }

  TimeOfDay get _result {
    final hour = _hour12 % 12 + (_amPm == 1 ? 12 : 0);
    return TimeOfDay(hour: hour, minute: _minute);
  }

  String _fmtPreview(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      margin: EdgeInsets.fromLTRB(12, 0, 12, 24 + mq.padding.bottom),
      decoration: BoxDecoration(
        color: AppColors.bgDeep,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.text.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 40, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(color: AppColors.text.withOpacity(0.18), borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
            child: Row(children: [
              Container(width: 38, height: 38,
                decoration: BoxDecoration(color: const Color(0xFF9B88E8).withOpacity(0.14),
                  shape: BoxShape.circle, border: Border.all(color: const Color(0xFF9B88E8).withOpacity(0.3))),
                child: const Icon(Icons.access_time_rounded, color: Color(0xFF9B88E8), size: 18)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Set Time', style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Scroll to choose', style: TextStyle(color: AppColors.text.withOpacity(0.38), fontSize: 12)),
              ]),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(width: 30, height: 30,
                  decoration: BoxDecoration(color: AppColors.text.withOpacity(0.07), shape: BoxShape.circle),
                  child: Icon(Icons.close_rounded, color: AppColors.text.withOpacity(0.45), size: 16)),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          Divider(height: 1, color: AppColors.text.withOpacity(0.07)),
          const SizedBox(height: 8),
          SizedBox(
            height: _listH,
            child: Stack(children: [
              Positioned(top: _itemH * ((_visible - 1) / 2), left: 16, right: 16, height: _itemH,
                child: Container(decoration: BoxDecoration(color: AppColors.text.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.text.withOpacity(0.1))))),
              Positioned(top: 0, left: 0, right: 0, height: _itemH * 1.5,
                child: IgnorePointer(child: Container(decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [AppColors.bgDeep, AppColors.bgDeep.withOpacity(0)]))))),
              Positioned(bottom: 0, left: 0, right: 0, height: _itemH * 1.5,
                child: IgnorePointer(child: Container(decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  colors: [AppColors.bgDeep, AppColors.bgDeep.withOpacity(0)]))))),
              Row(children: [
                Expanded(flex: 3, child: _Wheel(controller: _hourCtrl, itemCount: 12,
                  labelBuilder: (i) => '${(i % 12) + 1}',
                  onChanged: (i) => setState(() => _hour12 = (i % 12) + 1))),
                Text(':', style: TextStyle(color: AppColors.text.withOpacity(0.6), fontSize: 28, fontWeight: FontWeight.w300)),
                Expanded(flex: 3, child: _Wheel(controller: _minuteCtrl, itemCount: 60,
                  labelBuilder: (i) => (i % 60).toString().padLeft(2, '0'),
                  onChanged: (i) => setState(() => _minute = i % 60))),
                Expanded(flex: 2, child: _Wheel(controller: _amPmCtrl, itemCount: 2, looping: false,
                  labelBuilder: (i) => i == 0 ? 'AM' : 'PM',
                  onChanged: (i) => setState(() => _amPm = i))),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.text.withOpacity(0.07)),
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
                    Icon(Icons.check_rounded, color: AppColors.text, size: 18),
                    const SizedBox(width: 7),
                    Text(_fmtPreview(_result),
                      style: TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
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
// iOS drum-roll date picker
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
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dd    = DateTime(d.year, d.month, d.day);
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
        color: AppColors.bgDeep,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.text.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 40, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(color: AppColors.text.withOpacity(0.18), borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
            child: Row(children: [
              Container(width: 38, height: 38,
                decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.14), shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accent.withOpacity(0.3))),
                child: Icon(Icons.calendar_today_rounded, color: AppColors.accent, size: 17)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Set Date', style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Scroll to choose', style: TextStyle(color: AppColors.text.withOpacity(0.38), fontSize: 12)),
              ]),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(width: 30, height: 30,
                  decoration: BoxDecoration(color: AppColors.text.withOpacity(0.07), shape: BoxShape.circle),
                  child: Icon(Icons.close_rounded, color: AppColors.text.withOpacity(0.45), size: 16)),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          Divider(height: 1, color: AppColors.text.withOpacity(0.07)),
          const SizedBox(height: 8),
          SizedBox(
            height: _listH,
            child: Stack(children: [
              Positioned(top: _itemH * ((_visible - 1) / 2), left: 16, right: 16, height: _itemH,
                child: Container(decoration: BoxDecoration(color: AppColors.text.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.text.withOpacity(0.1))))),
              Positioned(top: 0, left: 0, right: 0, height: _itemH * 1.5,
                child: IgnorePointer(child: Container(decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [AppColors.bgDeep, AppColors.bgDeep.withOpacity(0)]))))),
              Positioned(bottom: 0, left: 0, right: 0, height: _itemH * 1.5,
                child: IgnorePointer(child: Container(decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  colors: [AppColors.bgDeep, AppColors.bgDeep.withOpacity(0)]))))),
              Row(children: [
                Expanded(flex: 3, child: _Wheel(controller: _monthCtrl, itemCount: 12,
                  labelBuilder: (i) => _months[i % 12],
                  onChanged: (i) => setState(() => _month = (i % 12) + 1))),
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
          Divider(height: 1, color: AppColors.text.withOpacity(0.07)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: SizedBox(
              width: double.infinity, height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(colors: [AppColors.accent, Color(0xFF6AB8B3)]),
                  boxShadow: [BoxShadow(color: AppColors.accent, blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Material(color: Colors.transparent, child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.pop(context, _result),
                  child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_rounded, color: AppColors.bg, size: 18),
                    const SizedBox(width: 7),
                    Text(_fmtResult(_result),
                      style: TextStyle(color: AppColors.bg, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
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
          color: dimmed ? AppColors.text.withOpacity(0.18) : AppColors.text,
          fontSize: 26,
          fontWeight: FontWeight.w300,
          letterSpacing: 0.5,
        )),
    );
  }
}