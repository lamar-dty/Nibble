import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../constants/colors.dart';
import '../models/class_schedule.dart';
import '../store/class_schedule_store.dart';
import '../constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────
void showClassAlertsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    enableDrag: true,
    builder: (_) => const ClassAlertsSheet(),
  );
}

// ─────────────────────────────────────────────────────────────
// Sheet
// ─────────────────────────────────────────────────────────────
class ClassAlertsSheet extends StatefulWidget {
  const ClassAlertsSheet({super.key});

  @override
  State<ClassAlertsSheet> createState() => _ClassAlertsSheetState();
}

class _ClassAlertsSheetState extends State<ClassAlertsSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  bool _showAddForm = false;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    ClassScheduleStore.instance.addListener(_onStoreChanged);
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ClassScheduleStore.instance.removeListener(_onStoreChanged);
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _openAddForm() => setState(() => _showAddForm = true);
  void _closeAddForm() => setState(() => _showAddForm = false);

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        height: mq.size.height * 0.88,
        decoration: BoxDecoration(
          color: AppColors.bgDeep,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // ── Handle ────────────────────────────────────
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: AppColors.text.withOpacity(0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── Header ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.14),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.accent.withOpacity(0.3), width: 1.5),
                    ),
                    child: Icon(Icons.school_rounded, color: AppColors.accent, size: 21),
                  ),
                  const SizedBox(width: 13),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Class Alerts',
                          style: TextStyle(
                              color: AppColors.text, fontSize: 17, fontWeight: FontWeight.bold)),
                      Text('Your weekly class schedule',
                          style: TextStyle(color: AppColors.text.withOpacity(0.4), fontSize: 12)),
                    ],
                  ),
                  const Spacer(),
                  // Add button
                  if (!_showAddForm)
                    GestureDetector(
                      onTap: _openAddForm,
                      child: Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.accent.withOpacity(0.35)),
                        ),
                        child: Icon(Icons.add_rounded, color: AppColors.accent, size: 20),
                      ),
                    ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.text.withOpacity(0.07),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close_rounded,
                          color: AppColors.text.withOpacity(0.5), size: 17),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Divider(height: 1, color: AppColors.text.withOpacity(0.07)),

            // ── Body ──────────────────────────────────────
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _showAddForm
                    ? _AddClassForm(
                        key: const ValueKey('form'),
                        onSaved: _closeAddForm,
                        onCancel: _closeAddForm,
                      )
                    : _ScheduleList(
                        key: const ValueKey('list'),
                        onAdd: _openAddForm,
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
// Schedule list view
// ─────────────────────────────────────────────────────────────
class _ScheduleList extends StatelessWidget {
  final VoidCallback onAdd;

  const _ScheduleList({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final schedules = ClassScheduleStore.instance.schedules;

    if (schedules.isEmpty) {
      return _EmptyState(onAdd: onAdd);
    }

    // Sort classes by their earliest day, then by time — each shown once.
    final sorted = List<ClassSchedule>.from(schedules)
      ..sort((a, b) {
        final aDay = (List<int>.from(a.days)..sort()).first;
        final bDay = (List<int>.from(b.days)..sort()).first;
        if (aDay != bDay) return aDay.compareTo(bDay);
        final aMin = a.time.hour * 60 + a.time.minute;
        final bMin = b.time.hour * 60 + b.time.minute;
        return aMin.compareTo(bMin);
      });

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.text.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.text.withOpacity(0.08)),
            ),
            child: _ClassCard(schedule: sorted[index]),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Single class card
// ─────────────────────────────────────────────────────────────
class _ClassCard extends StatelessWidget {
  final ClassSchedule schedule;

  const _ClassCard({required this.schedule});

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgDeep,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Remove Class',
            style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
          'Remove "${schedule.name}" from your schedule?',
          style: const TextStyle(color: Color(0x66FFFFFF), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0x73FFFFFF))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove',
                style: TextStyle(color: Color(0xFFE87070), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ClassScheduleStore.instance.remove(schedule.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Row(
        children: [
          // Time pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accent.withOpacity(0.25)),
            ),
            child: Text(
              schedule.timeLabel,
              style: TextStyle(
                  color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          // Name + room
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(schedule.name,
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                if (schedule.room != null && schedule.room!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 11, color: AppColors.text.withOpacity(0.35)),
                      const SizedBox(width: 3),
                      Text(schedule.room!,
                          style: TextStyle(
                              color: AppColors.text.withOpacity(0.4), fontSize: 11)),
                    ],
                  ),
                ],
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.notifications_outlined,
                        size: 11, color: AppColors.text.withOpacity(0.3)),
                    const SizedBox(width: 3),
                    Text('${schedule.reminderMinutes} min before',
                        style: TextStyle(
                            color: AppColors.text.withOpacity(0.3), fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
          // Days chips
          Wrap(
            spacing: 4,
            children: (List<int>.from(schedule.days)..sort()).map((d) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.bg.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(ClassSchedule.dayLabel(d),
                    style: TextStyle(
                        color: AppColors.text.withOpacity(0.45),
                        fontSize: 9,
                        fontWeight: FontWeight.w700)),
              );
            }).toList(),
          ),
          const SizedBox(width: 4),
          // Delete
          GestureDetector(
            onTap: () => _confirmDelete(context),
            child: Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFFE87070).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.delete_outline_rounded,
                  size: 16, color: const Color(0xFFE87070).withOpacity(0.6)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.accent.withOpacity(0.2)),
              ),
              child: Icon(Icons.school_rounded, color: AppColors.accent.withOpacity(0.6), size: 32),
            ),
            const SizedBox(height: 20),
            Text('No Classes Yet',
                style: TextStyle(
                    color: AppColors.text, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Add your class schedule and get notified before each one.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.text.withOpacity(0.4), fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent.withOpacity(0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: AppColors.accent, size: 18),
                    SizedBox(width: 8),
                    Text('Add a Class',
                        style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ],
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
// Add class form
// ─────────────────────────────────────────────────────────────
class _AddClassForm extends StatefulWidget {
  final VoidCallback onSaved;
  final VoidCallback onCancel;

  const _AddClassForm({super.key, required this.onSaved, required this.onCancel});

  @override
  State<_AddClassForm> createState() => _AddClassFormState();
}

class _AddClassFormState extends State<_AddClassForm> {
  final _nameController = TextEditingController();
  final _roomController = TextEditingController();

  final Set<int> _selectedDays = {};
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);
  int _reminderMinutes = 15;
  bool _saving = false;
  String? _error;

  static const _reminderOptions = [5, 10, 15, 30, 60];

  @override
  void dispose() {
    _nameController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  String _fmtTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _pickTime() async {
    final picked = await showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _IosTimePickerSheet(initial: _selectedTime),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a class name.');
      return;
    }
    if (_selectedDays.isEmpty) {
      setState(() => _error = 'Please select at least one day.');
      return;
    }
    setState(() { _saving = true; _error = null; });

    final schedule = ClassSchedule(
      id: const Uuid().v4(),
      name: name,
      days: _selectedDays.toList(),
      time: _selectedTime,
      reminderMinutes: _reminderMinutes,
      room: _roomController.text.trim().isEmpty ? null : _roomController.text.trim(),
    );

    await ClassScheduleStore.instance.add(schedule);
    if (mounted) {
      setState(() => _saving = false);
      widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Class Name ───────────────────────────
                _SectionLabel(label: 'CLASS NAME'),
                const SizedBox(height: 8),
                _InputField(
                  controller: _nameController,
                  hint: 'e.g. Data Structures',
                  icon: Icons.book_outlined,
                  onChanged: (_) => setState(() => _error = null),
                ),

                const SizedBox(height: 20),

                // ── Room (optional) ──────────────────────
                _SectionLabel(label: 'ROOM / LOCATION (OPTIONAL)'),
                const SizedBox(height: 8),
                _InputField(
                  controller: _roomController,
                  hint: 'e.g. Room 204',
                  icon: Icons.location_on_outlined,
                ),

                const SizedBox(height: 20),

                // ── Days ─────────────────────────────────
                _SectionLabel(label: 'DAYS'),
                const SizedBox(height: 10),
                Row(
                  children: List.generate(7, (i) {
                    final day = i + 1; // 1=Mon … 7=Sun
                    final selected = _selectedDays.contains(day);
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _error = null;
                            if (selected) {
                              _selectedDays.remove(day);
                            } else {
                              _selectedDays.add(day);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: EdgeInsets.only(right: i < 6 ? 5 : 0),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.accent.withOpacity(0.18)
                                : AppColors.text.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? AppColors.accent.withOpacity(0.5)
                                  : AppColors.text.withOpacity(0.08),
                            ),
                          ),
                          child: Text(
                            ClassSchedule.dayLabel(day),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: selected ? AppColors.accent : AppColors.text.withOpacity(0.4),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 20),

                // ── Time ─────────────────────────────────
                _SectionLabel(label: 'CLASS TIME'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickTime,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.text.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.text.withOpacity(0.08)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time_rounded,
                            color: AppColors.accent.withOpacity(0.8), size: 18),
                        const SizedBox(width: 10),
                        Text(
                          _fmtTime(_selectedTime),
                          style: TextStyle(
                              color: AppColors.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        Icon(Icons.chevron_right_rounded,
                            color: AppColors.text.withOpacity(0.3), size: 18),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Reminder ─────────────────────────────
                _SectionLabel(label: 'REMIND ME BEFORE'),
                const SizedBox(height: 10),
                Row(
                  children: _reminderOptions.asMap().entries.map((entry) {
                    final i = entry.key;
                    final mins = entry.value;
                    final selected = mins == _reminderMinutes;
                    final label = mins >= 60 ? '1 hr' : '$mins min';
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _reminderMinutes = mins),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: EdgeInsets.only(right: i < _reminderOptions.length - 1 ? 8 : 0),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.accent.withOpacity(0.18)
                                : AppColors.text.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? AppColors.accent.withOpacity(0.5)
                                  : AppColors.text.withOpacity(0.08),
                            ),
                          ),
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: selected ? AppColors.accent : AppColors.text.withOpacity(0.4),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                // ── Error ─────────────────────────────────
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 13, color: const Color(0xFFE87070).withOpacity(0.8)),
                      const SizedBox(width: 6),
                      Text(_error!,
                          style: const TextStyle(
                              color: Color(0xFFE87070), fontSize: 12)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),

        // ── Footer buttons ────────────────────────────────
        Divider(height: 1, color: AppColors.text.withOpacity(0.07)),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + mq.padding.bottom),
          child: Row(
            children: [
              // Cancel
              Expanded(
                child: GestureDetector(
                  onTap: widget.onCancel,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.text.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.text.withOpacity(0.1)),
                    ),
                    child: Center(
                      child: Text('Cancel',
                          style: TextStyle(
                              color: AppColors.text.withOpacity(0.55),
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Save
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: _saving ? null : _save,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        colors: [AppColors.accent, AppColors.accent.withOpacity(0.75)],
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.accent.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Center(
                      child: _saving
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text('Add Class',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Reusable sub-widgets
// ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: TextStyle(
            color: AppColors.text.withOpacity(0.35),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2));
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final ValueChanged<String>? onChanged;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.text.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.text.withOpacity(0.08)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(color: AppColors.text, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.text.withOpacity(0.28), fontSize: 14),
          prefixIcon: Icon(icon, color: AppColors.text.withOpacity(0.35), size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// iOS-style drum-roll time picker sheet (copied from create_task_sheet)
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

  late int _hour12;
  late int _minute;
  late int _amPm;

  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minuteCtrl;
  late FixedExtentScrollController _amPmCtrl;

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
    final hour = _hour12 % 12 + (_amPm == 1 ? 12 : 0);
    return TimeOfDay(hour: hour, minute: _minute);
  }

  String _formatPreview(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
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
          // Handle
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(color: AppColors.text.withOpacity(0.18), borderRadius: BorderRadius.circular(2)),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.14),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                  ),
                  child: Icon(Icons.access_time_rounded, color: AppColors.accent, size: 18),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Set Time', style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Scroll to choose', style: TextStyle(color: AppColors.text.withOpacity(0.38), fontSize: 12)),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(color: AppColors.text.withOpacity(0.07), shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, color: AppColors.text.withOpacity(0.45), size: 16),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          Divider(height: 1, color: AppColors.text.withOpacity(0.07)),
          const SizedBox(height: 8),

          // Drum rolls
          SizedBox(
            height: _listH,
            child: Stack(
              children: [
                // Selection highlight band
                Positioned(
                  top: _itemH * ((_visible - 1) / 2),
                  left: 16, right: 16,
                  height: _itemH,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.text.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.text.withOpacity(0.1)),
                    ),
                  ),
                ),
                // Top fade
                Positioned(
                  top: 0, left: 0, right: 0,
                  height: _itemH * 1.5,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [AppColors.bgDeep, AppColors.bgDeep.withOpacity(0)],
                        ),
                      ),
                    ),
                  ),
                ),
                // Bottom fade
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  height: _itemH * 1.5,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter, end: Alignment.topCenter,
                          colors: [AppColors.bgDeep, AppColors.bgDeep.withOpacity(0)],
                        ),
                      ),
                    ),
                  ),
                ),
                // Wheels row
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _Wheel(
                        controller: _hourCtrl,
                        itemCount: 12,
                        labelBuilder: (i) => '${(i % 12) + 1}',
                        onChanged: (i) => setState(() => _hour12 = (i % 12) + 1),
                      ),
                    ),
                    Text(':', style: TextStyle(color: AppColors.text.withOpacity(0.6), fontSize: 28, fontWeight: FontWeight.w300)),
                    Expanded(
                      flex: 3,
                      child: _Wheel(
                        controller: _minuteCtrl,
                        itemCount: 60,
                        labelBuilder: (i) => (i % 60).toString().padLeft(2, '0'),
                        onChanged: (i) => setState(() => _minute = i % 60),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _Wheel(
                        controller: _amPmCtrl,
                        itemCount: 2,
                        looping: false,
                        labelBuilder: (i) => i == 0 ? 'AM' : 'PM',
                        onChanged: (i) => setState(() => _amPm = i),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.text.withOpacity(0.07)),

          // Confirm button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: SizedBox(
              width: double.infinity, height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(colors: [AppColors.accent, AppColors.accent.withOpacity(0.75)]),
                  boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.pop(context, _result),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_rounded, color: AppColors.text, size: 18),
                          const SizedBox(width: 7),
                          Text(
                            _formatPreview(_result),
                            style: TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                          ),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Single drum-roll wheel
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
              children: List.generate(itemCount, (i) => _WheelItem(label: labelBuilder(i))),
            )
          : ListWheelChildListDelegate(
              children: List.generate(itemCount, (i) => _WheelItem(label: labelBuilder(i))),
            ),
    );
  }
}

class _WheelItem extends StatelessWidget {
  final String label;
  const _WheelItem({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.text,
          fontSize: 26,
          fontWeight: FontWeight.w300,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}