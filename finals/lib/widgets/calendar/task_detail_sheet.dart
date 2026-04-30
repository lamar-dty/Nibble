import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../models/task.dart';
import '../../models/event.dart';
import '../../store/task_store.dart';

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

  void _cycleStatus() {
    final next = _status == TaskStatus.notStarted
        ? TaskStatus.inProgress
        : _status == TaskStatus.inProgress
            ? TaskStatus.completed
            : TaskStatus.notStarted;
    TaskStore.instance.updateStatus(widget.task.id, next);
    setState(() => _status = next);
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2C5B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Task',
            style: TextStyle(color: kWhite, fontWeight: FontWeight.w700)),
        content: Text('Remove "${widget.task.name}"? This can\'t be undone.',
            style: TextStyle(color: kWhite.withOpacity(0.55), fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: kWhite.withOpacity(0.45))),
          ),
          TextButton(
            onPressed: () {
              TaskStore.instance.deleteTask(widget.task.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Delete',
                style: TextStyle(color: Color(0xFFE05C5C), fontWeight: FontWeight.w700)),
          ),
        ],
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
      case TaskStatus.notStarted: return const Color(0xFFB0BAD3);
      case TaskStatus.inProgress: return const Color(0xFFE8D870);
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
        color: const Color(0xFF1A2C5B),
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
              decoration: BoxDecoration(color: kWhite.withOpacity(0.18), borderRadius: BorderRadius.circular(2)),
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
                      style: const TextStyle(color: kWhite, fontSize: 22, fontWeight: FontWeight.w800, height: 1.2)),
                  if (widget.task.spaceName != null) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.folder_outlined, size: 13, color: kSubtitle),
                      const SizedBox(width: 5),
                      Text(widget.task.spaceName!,
                          style: const TextStyle(color: kSubtitle, fontSize: 12.5, fontWeight: FontWeight.w500)),
                    ]),
                  ],
                  const SizedBox(height: 20),
                  _StatusToggle(icon: _statusIcon, label: _statusLabel, color: _statusColor, onTap: _cycleStatus),
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
                        color: kTeal,
                      ),
                    _InfoTile(icon: Icons.flag_rounded, label: 'Priority',
                        value: _priorityLabel, color: _priorityColor),
                    _InfoTile(icon: Icons.repeat_rounded, label: 'Repeat',
                        value: widget.task.repeat.label, color: kSubtitle),
                  ]),
                  if (widget.task.notes != null && widget.task.notes!.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _NotesCard(notes: widget.task.notes!),
                  ],
                  const SizedBox(height: 20),
                  Center(
                    child: Text('Created ${_formatDate(widget.task.createdAt)}',
                        style: TextStyle(color: kWhite.withOpacity(0.22), fontSize: 11)),
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
// Event Detail Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _EventDetailSheet extends StatelessWidget {
  final Event event;
  const _EventDetailSheet({required this.event});

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2C5B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Event',
            style: TextStyle(color: kWhite, fontWeight: FontWeight.w700)),
        content: Text('Remove "${event.title}"? This can\'t be undone.',
            style: TextStyle(color: kWhite.withOpacity(0.55), fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: kWhite.withOpacity(0.45))),
          ),
          TextButton(
            onPressed: () {
              TaskStore.instance.deleteEvent(event.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Delete',
                style: TextStyle(color: Color(0xFFE05C5C), fontWeight: FontWeight.w700)),
          ),
        ],
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
        color: const Color(0xFF1A2C5B),
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
              decoration: BoxDecoration(color: kWhite.withOpacity(0.18), borderRadius: BorderRadius.circular(2)),
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
                  // Category chip + EVENT badge + close
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

                  // Title
                  Text(event.title,
                      style: const TextStyle(color: kWhite, fontSize: 22, fontWeight: FontWeight.w800, height: 1.2)),

                  // Location
                  if (event.location != null && event.location!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.location_on_outlined, size: 13, color: kSubtitle),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(event.location!,
                            style: const TextStyle(color: kSubtitle, fontSize: 12.5, fontWeight: FontWeight.w500)),
                      ),
                    ]),
                  ],

                  const SizedBox(height: 20),

                  // Info grid
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
                        color: kTeal,
                      ),
                    _InfoTile(
                      icon: event.category.icon,
                      label: 'Category',
                      value: event.category.label,
                      color: _catColor,
                    ),
                  ]),

                  // Notes
                  if (event.notes != null && event.notes!.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _NotesCard(notes: event.notes!),
                  ],

                  const SizedBox(height: 20),
                  Center(
                    child: Text('Created ${_formatDate(event.createdAt)}',
                        style: TextStyle(color: kWhite.withOpacity(0.22), fontSize: 11)),
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
          color: kWhite.withOpacity(0.08),
          shape: BoxShape.circle,
          border: Border.all(color: kWhite.withOpacity(0.1)),
        ),
        child: Icon(Icons.close_rounded, size: 16, color: kWhite.withOpacity(0.55)),
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
        color: kWhite.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kWhite.withOpacity(0.08), width: 0.5),
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
              style: const TextStyle(color: kWhite, fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.3)),
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
        color: kWhite.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kWhite.withOpacity(0.1), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.notes_rounded, size: 13, color: kTeal.withOpacity(0.75)),
            const SizedBox(width: 6),
            Text('NOTES',
                style: TextStyle(color: kTeal.withOpacity(0.65), fontSize: 9,
                    fontWeight: FontWeight.w800, letterSpacing: 0.8)),
          ]),
          const SizedBox(height: 10),
          Text(notes,
              style: TextStyle(color: kWhite.withOpacity(0.8), fontSize: 13, height: 1.55)),
        ],
      ),
    );
  }
}