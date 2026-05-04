import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../models/task.dart';
import '../../models/event.dart';
import '../../store/task_store.dart';
import '../../store/wallet_store.dart';
import '../wallet/wallet_sheet.dart';
import '../../constants/app_colors.dart';

/// Shows a modal bottom sheet with full task details.
/// Returns false if the task no longer exists (caller can show a snackbar).
bool showTaskDetailSheet(BuildContext context, String taskId) {
  final task = TaskStore.instance.tasks
      .where((t) => t.id == taskId)
      .firstOrNull;
  if (task == null) return false;
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _TaskDetailSheet(task: task),
  );
  return true;
}

/// Shows a modal bottom sheet with full event details.
/// Returns false if the event no longer exists.
bool showEventDetailSheet(BuildContext context, String eventId) {
  final event = TaskStore.instance.events
      .where((e) => e.id == eventId)
      .firstOrNull;
  if (event == null) return false;
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _EventDetailSheet(event: event),
  );
  return true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Task Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _TaskDetailSheet extends StatefulWidget {
  final Task task;
  const _TaskDetailSheet({required this.task});

  @override
  State<_TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<_TaskDetailSheet> {
  late TaskStatus _status;

  @override
  void initState() {
    super.initState();
    _status = widget.task.status;
  }

  void _openStatusPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _StatusPickerSheet(
        current: _status,
        onSelected: (s) {
          Navigator.pop(context);
          TaskStore.instance.updateStatus(widget.task.id, s);
          setState(() => _status = s);
        },
      ),
    );
  }

  Color get _catColor => widget.task.category.color;

  Color get _priorityColor {
    switch (widget.task.priority) {
      case TaskPriority.high:   return const Color(0xFFE87070);
      case TaskPriority.medium: return const Color(0xFFE8D870);
      case TaskPriority.low:    return const Color(0xFF3BBFA3);
    }
  }

  String get _priorityLabel => widget.task.priority.label;

  void _confirmDelete(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (confirmCtx) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 28),
        decoration: BoxDecoration(
          color: AppColors.bgDeep,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.text.withOpacity(0.08)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 40, offset: const Offset(0, -4))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(top: 14, bottom: 20),
              decoration: BoxDecoration(color: AppColors.text.withOpacity(0.18), borderRadius: BorderRadius.circular(2)),
            ),
            // Icon
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFE87070).withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE87070).withOpacity(0.3), width: 1.5),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE87070), size: 26),
            ),
            const SizedBox(height: 14),
            Text('Remove Task?',
                style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('This cannot be undone',
                style: TextStyle(color: AppColors.text.withOpacity(0.4), fontSize: 13)),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(confirmCtx),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.text.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.text.withOpacity(0.1)),
                      ),
                      child: Center(
                        child: Text('Cancel',
                            style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      TaskStore.instance.deleteTask(widget.task.id);
                      Navigator.pop(confirmCtx);
                      Navigator.pop(context);
                    },
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE87070).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE87070).withOpacity(0.4)),
                      ),
                      child: const Center(
                        child: Text('Delete',
                            style: TextStyle(
                                color: Color(0xFFE87070), fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  String get _statusLabel {
    switch (_status) {
      case TaskStatus.notStarted: return 'Not Started';
      case TaskStatus.inProgress: return 'In Progress';
      case TaskStatus.completed:  return 'Completed';
    }
  }

  Color get _statusColor {
    switch (_status) {
      case TaskStatus.notStarted: return AppColors.subtitle;
      case TaskStatus.inProgress: return AppColors.link;
      case TaskStatus.completed:  return const Color(0xFF3BBFA3);
    }
  }

  IconData get _statusIcon {
    switch (_status) {
      case TaskStatus.notStarted: return Icons.radio_button_unchecked_rounded;
      case TaskStatus.inProgress: return Icons.timelapse_rounded;
      case TaskStatus.completed:  return Icons.check_circle_rounded;
    }
  }

  String _formatDate(DateTime d) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const weekdays = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[d.weekday]}, ${months[d.month]} ${d.day}, ${d.year}';
  }

  String _formatTime(TimeOfDay t) {
    final h12  = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
    final mins = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour < 12 ? 'AM' : 'PM';
    return '$h12:$mins $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.bgDeep,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _catColor.withOpacity(0.25), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 32, offset: const Offset(0, -8)),
          BoxShadow(color: _catColor.withOpacity(0.08), blurRadius: 40, spreadRadius: -4),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 38, height: 4,
              decoration: BoxDecoration(color: AppColors.text.withOpacity(0.18), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.72),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(22, 0, 22, 24 + bottomPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _CategoryChip(label: widget.task.category.label, color: _catColor),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _confirmDelete(context),
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE05C5C).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE05C5C).withOpacity(0.25)),
                          ),
                          child: const Icon(Icons.delete_outline_rounded,
                              color: Color(0xFFE05C5C), size: 16),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _CloseButton(onTap: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(widget.task.name,
                      style: TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.w800, height: 1.2)),
                  if (widget.task.spaceName != null) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.folder_outlined, size: 13, color: AppColors.subtitle),
                      const SizedBox(width: 5),
                      Text(widget.task.spaceName!,
                          style: TextStyle(color: AppColors.subtitle, fontSize: 12.5, fontWeight: FontWeight.w500)),
                    ]),
                  ],
                  const SizedBox(height: 20),
                  // ── Status toggle — opens StatusPickerSheet on tap ──
                  _StatusToggle(
                    icon: _statusIcon,
                    label: _statusLabel,
                    color: _statusColor,
                    onTap: () => _openStatusPicker(context),
                  ),
                  const SizedBox(height: 16),
                  _InfoGrid(children: [
                    _InfoTile(icon: Icons.calendar_today_rounded, label: 'Due Date',
                        value: _formatDate(widget.task.dueDate), color: _catColor),
                    if (widget.task.isMultiDay)
                      _InfoTile(icon: Icons.event_rounded, label: 'End Date',
                          value: _formatDate(widget.task.endDate!), color: _catColor),
                    if (widget.task.dueTime != null)
                      _InfoTile(
                        icon: Icons.access_time_rounded,
                        label: widget.task.endTime != null ? 'Time Range' : 'Time',
                        value: widget.task.endTime != null
                            ? '${_formatTime(widget.task.dueTime!)} – ${_formatTime(widget.task.endTime!)}'
                            : _formatTime(widget.task.dueTime!),
                        color: AppColors.accent,
                      ),
                    _InfoTile(icon: Icons.flag_rounded, label: 'Priority',
                        value: _priorityLabel, color: _priorityColor),
                    _InfoTile(icon: Icons.repeat_rounded, label: 'Repeat',
                        value: widget.task.repeat.label, color: AppColors.subtitle),
                  ]),
                  if (widget.task.notes != null && widget.task.notes!.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _NotesCard(notes: widget.task.notes!),
                  ],
                  // ── Linked expense card ──────────────────────
                  if (widget.task.linkedExpenseId != null) ...[
                    const SizedBox(height: 18),
                    _LinkedExpenseCard(
                      taskId:   widget.task.linkedExpenseId!,
                      taskDone: _status == TaskStatus.completed,
                    ),
                  ],
                  const SizedBox(height: 20),
                  Center(
                    child: Text('Created ${_formatDate(widget.task.createdAt)}',
                        style: TextStyle(color: AppColors.text.withOpacity(0.22), fontSize: 11)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status Picker Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _StatusPickerSheet extends StatelessWidget {
  final TaskStatus current;
  final ValueChanged<TaskStatus> onSelected;

  const _StatusPickerSheet({required this.current, required this.onSelected});

  static const _label = {
    TaskStatus.notStarted: 'Not Started',
    TaskStatus.inProgress: 'In Progress',
    TaskStatus.completed:  'Completed',
  };
  static final _color = {
    TaskStatus.notStarted: AppColors.subtitle,
    TaskStatus.inProgress: AppColors.link,
    TaskStatus.completed:  Color(0xFF3BBFA3),
  };
  static const _icon = {
    TaskStatus.notStarted: Icons.radio_button_unchecked_rounded,
    TaskStatus.inProgress: Icons.timelapse_rounded,
    TaskStatus.completed:  Icons.check_circle_rounded,
  };
  static const _desc = {
    TaskStatus.notStarted: 'Task has not been started yet',
    TaskStatus.inProgress: 'Currently working on this',
    TaskStatus.completed:  'All done!',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 28),
      decoration: BoxDecoration(
        color: AppColors.bgDeep,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.text.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 40, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(top: 14, bottom: 18),
            decoration: BoxDecoration(color: AppColors.text.withOpacity(0.18), borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.14),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accent.withOpacity(0.3), width: 1.5),
                  ),
                  child: Icon(Icons.swap_horiz_rounded, color: AppColors.accent, size: 22),
                ),
                const SizedBox(width: 13),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Update Status',
                        style: TextStyle(color: AppColors.text, fontSize: 17, fontWeight: FontWeight.bold)),
                    Text('Tap to change task progress',
                        style: TextStyle(color: AppColors.text.withOpacity(0.4), fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: AppColors.text.withOpacity(0.07), thickness: 1, indent: 22, endIndent: 22),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 22),
            child: Column(
              children: TaskStatus.values.map((s) {
                final isCurrent = s == current;
                final c = _color[s]!;
                return _StatusCard(
                  icon: _icon[s]!,
                  iconColor: c,
                  label: _label[s]!,
                  description: _desc[s]!,
                  selected: isCurrent,
                  onTap: () => onSelected(s),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _StatusCard({
    required this.icon, required this.iconColor, required this.label,
    required this.description, required this.selected, required this.onTap,
  });

  @override
  State<_StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends State<_StatusCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.iconColor;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: (_pressed || widget.selected) ? c.withOpacity(0.12) : AppColors.text.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (_pressed || widget.selected) ? c.withOpacity(0.55) : AppColors.text.withOpacity(0.08),
            width: 1.3,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: c.withOpacity(0.13),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: c.withOpacity(0.25), width: 1.2),
              ),
              child: Icon(widget.icon, color: c, size: 22),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.label,
                      style: TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(widget.description,
                      style: TextStyle(color: AppColors.text.withOpacity(0.37), fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            if (widget.selected)
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                child: Icon(Icons.check_rounded, color: AppColors.text, size: 14),
              )
            else
              Icon(Icons.chevron_right_rounded, color: AppColors.text.withOpacity(0.2), size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Event Detail Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _EventDetailSheet extends StatelessWidget {
  final Event event;
  const _EventDetailSheet({required this.event});

  void _confirmDelete(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (confirmCtx) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 28),
        decoration: BoxDecoration(
          color: AppColors.bgDeep,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.text.withOpacity(0.08)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 40, offset: const Offset(0, -4))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(top: 14, bottom: 20),
              decoration: BoxDecoration(color: AppColors.text.withOpacity(0.18), borderRadius: BorderRadius.circular(2)),
            ),
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFE87070).withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE87070).withOpacity(0.3), width: 1.5),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE87070), size: 26),
            ),
            const SizedBox(height: 14),
            Text('Remove Event?',
                style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('This cannot be undone',
                style: TextStyle(color: AppColors.text.withOpacity(0.4), fontSize: 13)),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(confirmCtx),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.text.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.text.withOpacity(0.1)),
                      ),
                      child: Center(
                        child: Text('Cancel',
                            style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      TaskStore.instance.deleteEvent(event.id);
                      Navigator.pop(confirmCtx);
                      Navigator.pop(context);
                    },
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE87070).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE87070).withOpacity(0.4)),
                      ),
                      child: const Center(
                        child: Text('Delete',
                            style: TextStyle(
                                color: Color(0xFFE87070), fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Color get _catColor => event.category.color;

  String _formatDate(DateTime d) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const weekdays = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[d.weekday]}, ${months[d.month]} ${d.day}, ${d.year}';
  }

  String _formatTime(TimeOfDay t) {
    final h12  = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
    final mins = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour < 12 ? 'AM' : 'PM';
    return '$h12:$mins $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.bgDeep,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _catColor.withOpacity(0.25), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 32, offset: const Offset(0, -8)),
          BoxShadow(color: _catColor.withOpacity(0.08), blurRadius: 40, spreadRadius: -4),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 38, height: 4,
              decoration: BoxDecoration(color: AppColors.text.withOpacity(0.18), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.72),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(22, 0, 22, 24 + bottomPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _CategoryChip(
                        label: event.category.label,
                        color: _catColor,
                        icon: event.category.icon,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _catColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _catColor.withOpacity(0.25)),
                        ),
                        child: Text('EVENT',
                          style: TextStyle(
                            color: _catColor.withOpacity(0.8),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _confirmDelete(context),
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE05C5C).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE05C5C).withOpacity(0.25)),
                          ),
                          child: const Icon(Icons.delete_outline_rounded,
                              color: Color(0xFFE05C5C), size: 16),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _CloseButton(onTap: () => Navigator.pop(context)),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Text(event.title,
                      style: TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.w800, height: 1.2)),

                  if (event.location != null && event.location!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.location_on_outlined, size: 13, color: AppColors.subtitle),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(event.location!,
                            style: TextStyle(color: AppColors.subtitle, fontSize: 12.5, fontWeight: FontWeight.w500)),
                      ),
                    ]),
                  ],

                  const SizedBox(height: 20),

                  _InfoGrid(children: [
                    _InfoTile(
                      icon: Icons.calendar_today_rounded,
                      label: event.isMultiDay ? 'Start Date' : 'Date',
                      value: _formatDate(event.startDate),
                      color: _catColor,
                    ),
                    if (event.isMultiDay)
                      _InfoTile(icon: Icons.event_rounded, label: 'End Date',
                          value: _formatDate(event.endDate), color: _catColor),
                    if (event.startTime != null)
                      _InfoTile(
                        icon: Icons.access_time_rounded,
                        label: event.endTime != null ? 'Time Range' : 'Start Time',
                        value: event.endTime != null
                            ? '${_formatTime(event.startTime!)} – ${_formatTime(event.endTime!)}'
                            : _formatTime(event.startTime!),
                        color: AppColors.accent,
                      ),
                    _InfoTile(
                      icon: event.category.icon,
                      label: 'Category',
                      value: event.category.label,
                      color: _catColor,
                    ),
                  ]),

                  if (event.notes != null && event.notes!.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _NotesCard(notes: event.notes!),
                  ],

                  // ── Linked expense card ──────────────────────
                  if (event.linkedExpenseId != null) ...[
                    const SizedBox(height: 18),
                    _LinkedEventExpenseCard(
                      eventId: event.linkedExpenseId!,
                    ),
                  ],

                  const SizedBox(height: 20),
                  Center(
                    child: Text('Created ${_formatDate(event.createdAt)}',
                        style: TextStyle(color: AppColors.text.withOpacity(0.22), fontSize: 11)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const _CategoryChip({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 11, color: color)
          else
            Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: AppColors.text.withOpacity(0.08),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.text.withOpacity(0.1)),
        ),
        child: Icon(Icons.close_rounded, size: 16, color: AppColors.text.withOpacity(0.55)),
      ),
    );
  }
}

class _StatusToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _StatusToggle({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.35), width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(color: color, fontSize: 13.5, fontWeight: FontWeight.w700)),
            const Spacer(),
            Row(children: [
              Text('Tap to change', style: TextStyle(color: color.withOpacity(0.5), fontSize: 10.5)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.5), size: 14),
            ]),
          ],
        ),
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  final List<Widget> children;
  const _InfoGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (int i = 0; i < children.length; i += 2) {
      rows.add(Row(children: [
        Expanded(child: children[i]),
        const SizedBox(width: 10),
        Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox.shrink()),
      ]));
      if (i + 2 < children.length) rows.add(const SizedBox(height: 10));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoTile({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.text.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.text.withOpacity(0.08), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 5),
            Text(label.toUpperCase(),
                style: TextStyle(color: color.withOpacity(0.65), fontSize: 9,
                    fontWeight: FontWeight.w800, letterSpacing: 0.8)),
          ]),
          const SizedBox(height: 5),
          Text(value,
              style: TextStyle(color: AppColors.text, fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.3)),
        ],
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  final String notes;
  const _NotesCard({required this.notes});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.text.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.text.withOpacity(0.1), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.notes_rounded, size: 13, color: AppColors.accent.withOpacity(0.75)),
            const SizedBox(width: 6),
            Text('NOTES',
                style: TextStyle(color: AppColors.accent.withOpacity(0.65), fontSize: 9,
                    fontWeight: FontWeight.w800, letterSpacing: 0.8)),
          ]),
          const SizedBox(height: 10),
          Text(notes,
              style: TextStyle(color: AppColors.text.withOpacity(0.8), fontSize: 13, height: 1.55)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Linked Expense Card
// ─────────────────────────────────────────────────────────────
class _LinkedExpenseCard extends StatefulWidget {
  final String taskId;
  final bool taskDone;
  const _LinkedExpenseCard({required this.taskId, required this.taskDone});

  @override
  State<_LinkedExpenseCard> createState() => _LinkedExpenseCardState();
}

class _LinkedExpenseCardState extends State<_LinkedExpenseCard> {
  WalletExpense? _expense;
  int _index = -1;

  @override
  void initState() {
    super.initState();
    _resolve();
    WalletStore.instance.addListener(_resolve);
  }

  @override
  void dispose() {
    WalletStore.instance.removeListener(_resolve);
    super.dispose();
  }

  void _resolve() {
    final idx = WalletStore.instance.findExpenseIndexByTaskId(widget.taskId);
    setState(() {
      _index   = idx;
      _expense = idx == -1 ? null : WalletStore.instance.expenses[idx];
    });
  }

  Future<void> _toggle() async {
    if (_index == -1) return;
    await WalletStore.instance.toggleExpensePaidUnpaid(_index);
  }

  @override
  Widget build(BuildContext context) {
    if (_expense == null) return const SizedBox.shrink();

    final e      = _expense!;
    final isPaid = e.status == WalletExpenseStatus.paid;
    final isOverdue = e.status == WalletExpenseStatus.overdue;
    final statusColor = isPaid
        ? const Color(0xFF3BBFA3)
        : isOverdue
            ? const Color(0xFFE87070)
            : const Color(0xFFE8D870);
    final statusLabel = isPaid ? 'Paid' : isOverdue ? 'Overdue' : 'Unpaid';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.text.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.25), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.account_balance_wallet_rounded,
                size: 13, color: statusColor.withOpacity(0.75)),
            const SizedBox(width: 6),
            Text('LINKED EXPENSE',
                style: TextStyle(
                    color: statusColor.withOpacity(0.65),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Icon(e.icon, size: 20, color: e.iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.name,
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(e.category.label,
                      style: TextStyle(
                          color: AppColors.text.withOpacity(0.4), fontSize: 12)),
                ],
              ),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₱${e.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(statusLabel,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ]),
          if (!isPaid) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _toggle,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF3BBFA3).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF3BBFA3).withOpacity(0.35),
                      width: 1),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 15, color: Color(0xFF3BBFA3)),
                    SizedBox(width: 6),
                    Text('Mark as Paid',
                        style: TextStyle(
                            color: Color(0xFF3BBFA3),
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// Linked Event Expense Card
// ─────────────────────────────────────────────────────────────────────────────
class _LinkedEventExpenseCard extends StatefulWidget {
  final String eventId;
  const _LinkedEventExpenseCard({required this.eventId});

  @override
  State<_LinkedEventExpenseCard> createState() =>
      _LinkedEventExpenseCardState();
}

class _LinkedEventExpenseCardState extends State<_LinkedEventExpenseCard> {
  WalletExpense? _expense;
  int _index = -1;

  @override
  void initState() {
    super.initState();
    _resolve();
    WalletStore.instance.addListener(_resolve);
  }

  @override
  void dispose() {
    WalletStore.instance.removeListener(_resolve);
    super.dispose();
  }

  void _resolve() {
    final idx =
        WalletStore.instance.findExpenseIndexByEventId(widget.eventId);
    setState(() {
      _index   = idx;
      _expense = idx == -1 ? null : WalletStore.instance.expenses[idx];
    });
  }

  Future<void> _toggle() async {
    if (_index == -1) return;
    await WalletStore.instance.toggleExpensePaidUnpaid(_index);
  }

  @override
  Widget build(BuildContext context) {
    if (_expense == null) return const SizedBox.shrink();

    final e           = _expense!;
    final isPaid      = e.status == WalletExpenseStatus.paid;
    final isOverdue   = e.status == WalletExpenseStatus.overdue;
    final statusColor = isPaid
        ? const Color(0xFF3BBFA3)
        : isOverdue
            ? const Color(0xFFE87070)
            : const Color(0xFFE8D870);
    final statusLabel = isPaid ? 'Paid' : isOverdue ? 'Overdue' : 'Unpaid';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.text.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.25), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.account_balance_wallet_rounded,
                size: 13, color: statusColor.withOpacity(0.75)),
            const SizedBox(width: 6),
            Text('LINKED EXPENSE',
                style: TextStyle(
                    color: statusColor.withOpacity(0.65),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Icon(e.icon, size: 20, color: e.iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.name,
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(e.category.label,
                      style: TextStyle(
                          color: AppColors.text.withOpacity(0.4), fontSize: 12)),
                ],
              ),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₱${e.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(statusLabel,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ]),
          if (!isPaid) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _toggle,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF3BBFA3).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF3BBFA3).withOpacity(0.35),
                      width: 1),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 15, color: Color(0xFF3BBFA3)),
                    SizedBox(width: 6),
                    Text('Mark as Paid',
                        style: TextStyle(
                            color: Color(0xFF3BBFA3),
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}