import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../constants/colors.dart';
import '../../models/space.dart';
import '../../store/space_store.dart';
import '../../store/auth_store.dart';
import 'space_painters.dart'; // SemiGaugePainter, DashedLinePainter
import '../../constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────
// Background B: selected space gauge + task list
// ─────────────────────────────────────────────────────────────
class SelectedBackground extends StatefulWidget {
  final Space space;
  final VoidCallback onBack;
  final void Function(SpaceTask) onTaskTap;
  final void Function(SpaceTask) onDeleteTask;
  final VoidCallback onAddTask;
  final VoidCallback onDelete;
  final VoidCallback onLeave;
  final void Function(String member) onKickMember;
  final VoidCallback onAddMember;
  final void Function(int oldIndex, int newIndex) onReorder;

  const SelectedBackground({
    super.key,
    required this.space,
    required this.onBack,
    required this.onTaskTap,
    required this.onDeleteTask,
    required this.onAddTask,
    required this.onDelete,
    required this.onLeave,
    required this.onKickMember,
    required this.onAddMember,
    required this.onReorder,
  });

  @override
  State<SelectedBackground> createState() => _SelectedBackgroundState();
}

class _SelectedBackgroundState extends State<SelectedBackground> {
  Space get space => widget.space;

  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  bool _isEditingName = false;
  bool _isEditingDesc = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: space.name);
    _descController = TextEditingController(text: space.description);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _saveName() {
    final trimmed = _nameController.text.trim();
    if (trimmed.isEmpty) {
      _nameController.text = space.name;
      setState(() => _isEditingName = false);
      return;
    }
    setState(() {
      space.name = trimmed;
      _isEditingName = false;
    });
  }

  void _saveDesc() {
    final trimmed = _descController.text.trim();
    setState(() {
      space.description = trimmed.isEmpty ? 'No description.' : trimmed;
      _isEditingDesc = false;
    });
    SpaceStore.instance.save();
  }

  @override
  Widget build(BuildContext context) {
    final daysLeft = space.daysLeft;
    final daysLabel = space.isCompleted
        ? 'Completed'
        : daysLeft < 0
            ? 'Overdue'
            : daysLeft == 0
                ? 'Due today'
                : '$daysLeft days left';
    final daysColor = space.isCompleted
        ? const Color(0xFF3BBFA3)
        : daysLeft <= 2
            ? const Color(0xFFE87070)
            : AppColors.subtitle;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button + delete/leave
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: widget.onBack,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.text.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppColors.text, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Text('Spaces',
                        style: TextStyle(
                            color: AppColors.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: space.isCreator ? widget.onDelete : widget.onLeave,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE87070).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFFE87070).withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        space.isCreator
                            ? Icons.delete_rounded
                            : Icons.exit_to_app_rounded,
                        color: const Color(0xFFE87070),
                        size: 13,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        space.isCreator ? 'Delete Space' : 'Leave Space',
                        style: const TextStyle(
                            color: Color(0xFFE87070),
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Semi-gauge
          Center(
            child: SizedBox(
              width: 240,
              height: 135,
              child: CustomPaint(
                painter: SemiGaugePainter(
                  completed: space.completedTasks,
                  total: space.totalTasks,
                  accentColor: space.accentColor,
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (space.totalTasks == 0) ...[
  Text(
    'No Tasks Yet',
    style: TextStyle(
      color: AppColors.text.withOpacity(0.9),
      fontSize: 24,
      fontWeight: FontWeight.bold,
    ),
  ),
  const SizedBox(height: 4),
  Text(
    'Tap + to start planning',
    style: TextStyle(
      color: AppColors.text.withOpacity(0.45),
      fontSize: 12,
    ),
  ),
] else ...[
  RichText(
    textAlign: TextAlign.center,
    text: TextSpan(children: [
      TextSpan(
        text: '${space.completedTasks} ',
        style: TextStyle(
            color: AppColors.text,
            fontSize: 32,
            fontWeight: FontWeight.bold),
      ),
      TextSpan(
        text: 'out of ',
        style:
            TextStyle(color: AppColors.subtitle, fontSize: 14),
      ),
      TextSpan(
        text: '${space.totalTasks}',
        style: TextStyle(
            color: AppColors.text,
            fontSize: 32,
            fontWeight: FontWeight.bold),
      ),
    ]),
  ),
  Text(
    'Tasks Completed',
    style: TextStyle(
      color: AppColors.subtitle,
      fontSize: 11,
    ),
  ),
],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Space name + due date badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isEditingName)
                      TextField(
                        controller: _nameController,
                        autofocus: true,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          hintText: 'Space name',
                          hintStyle: TextStyle(
                            color: AppColors.text.withOpacity(0.3),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onSubmitted: (_) => _saveName(),
                      )
                    else
                      GestureDetector(
                        onTap: space.isCreator
                            ? () => setState(() {
                                  _nameController.text = space.name;
                                  _isEditingName = true;
                                })
                            : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                space.name,
                                style: TextStyle(
                                    color: AppColors.text,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (space.isCreator) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.edit_rounded,
                                  color: AppColors.text.withOpacity(0.35), size: 13),
                            ],
                          ],
                        ),
                      ),
                    if (_isEditingName) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => setState(() {
                              _nameController.text = space.name;
                              _isEditingName = false;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.text.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: AppColors.text.withOpacity(0.15)),
                              ),
                              child: Text('Cancel',
                                  style: TextStyle(
                                      color: AppColors.text.withOpacity(0.5),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _saveName,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: space.accentColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: space.accentColor.withOpacity(0.35)),
                              ),
                              child: Text('Save',
                                  style: TextStyle(
                                      color: space.accentColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: daysColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: daysColor.withOpacity(0.4)),
                ),
                child: Text(daysLabel,
                    style: TextStyle(
                        color: daysColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),

          const SizedBox(height: 6),
          // Description inline editing
          if (space.isCreator) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!_isEditingDesc)
                  GestureDetector(
                    onTap: () => setState(() {
                      _descController.text = space.description == 'No description.' ? '' : space.description;
                      _isEditingDesc = true;
                    }),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_rounded,
                            color: space.accentColor, size: 11),
                        const SizedBox(width: 4),
                        Text('Edit',
                            style: TextStyle(
                                color: space.accentColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() {
                          _descController.text = space.description;
                          _isEditingDesc = false;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.text.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(20),
                            border:
                                Border.all(color: AppColors.text.withOpacity(0.15)),
                          ),
                          child: Text('Cancel',
                              style: TextStyle(
                                  color: AppColors.text.withOpacity(0.5),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _saveDesc,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: space.accentColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: space.accentColor.withOpacity(0.35)),
                          ),
                          child: Text('Save',
                              style: TextStyle(
                                  color: space.accentColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            decoration: BoxDecoration(
              color: _isEditingDesc
                  ? AppColors.text.withOpacity(0.08)
                  : AppColors.text.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _isEditingDesc
                      ? space.accentColor.withOpacity(0.4)
                      : AppColors.text.withOpacity(0.1)),
            ),
            padding: const EdgeInsets.all(14),
            child: _isEditingDesc
                ? TextField(
                    controller: _descController,
                    autofocus: true,
                    maxLines: null,
                    minLines: 3,
                    style:
                        TextStyle(color: AppColors.text.withOpacity(0.85), fontSize: 13),
                    cursorColor: space.accentColor,
                    decoration: InputDecoration.collapsed(
                      hintText: 'Add a description…',
                      hintStyle: TextStyle(
                          color: AppColors.text.withOpacity(0.3),
                          fontSize: 13,
                          fontStyle: FontStyle.italic),
                    ),
                  )
                : Text(
                    space.description,
                    style: TextStyle(
                      color: space.description == 'No description.'
                          ? AppColors.text.withOpacity(0.3)
                          : AppColors.subtitle,
                      fontSize: 12,
                      fontStyle: space.description == 'No description.'
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
          ),

          const SizedBox(height: 10),

          // Date range
          Row(
            children: [
              Icon(Icons.access_time_rounded,
                  color: AppColors.subtitle, size: 13),
              const SizedBox(width: 4),
              Text(space.dateRange,
                  style: TextStyle(color: AppColors.subtitle, fontSize: 12)),
            ],
          ),

          const SizedBox(height: 6),

          // Members header
          Row(
            children: [
              Icon(Icons.group_rounded, color: AppColors.subtitle, size: 13),
              const SizedBox(width: 4),
              Text(
                '${space.memberCount} ${space.memberCount == 1 ? 'Person' : 'People'}',
                style: TextStyle(color: AppColors.subtitle, fontSize: 12),
              ),
              if (space.pendingMembers.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8A870).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE8A870).withOpacity(0.35)),
                  ),
                  child: Text(
                    '${space.pendingMembers.length} pending',
                    style: const TextStyle(color: Color(0xFFE8A870), fontSize: 10),
                  ),
                ),
              ],
              if (space.isCreator) ...[
                const Spacer(),
                GestureDetector(
                  onTap: widget.onAddMember,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.text.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person_add_rounded,
                        color: AppColors.text, size: 14),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 10),

          Wrap(
  spacing: 8,
  runSpacing: 6,
  children: [
    MemberChip(
      name: space.isCreator
          ? '${AuthStore.instance.username} (Creator)'
          : '${space.creatorName} (Creator)',
      canKick: false,
      onKick: null,
    ),
    ...space.members.map(
      (m) => MemberChip(
        name: m,
        canKick: space.isCreator,
        onKick:
            space.isCreator ? () => widget.onKickMember(m) : null,
      ),
    ),
    ...space.pendingMembers.map(
      (m) => _PendingMemberChip(
        name: m,
        onCancel: space.isCreator
            ? () => SpaceStore.instance.cancelInvite(space, m)
            : null,
      ),
    ),
  ],
),

          const SizedBox(height: 24),

          // Team tasks header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Your Team's Tasks",
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
             if (space.isCreator)
  GestureDetector(
    onTap: widget.onAddTask,
    child: Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.text.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.add_rounded,
        color: AppColors.text,
        size: 18,
      ),
    ),
  ),
            ],
          ),

          const SizedBox(height: 14),

          // Task list or empty state
          if (space.tasks.isEmpty)
            GestureDetector(
              onTap: space.isCreator ? widget.onAddTask : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        space.isCreator
                            ? Icons.add_task_rounded
                            : Icons.hourglass_empty_rounded,
                        color: AppColors.text.withOpacity(0.25),
                        size: 36,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        space.isCreator
                            ? 'No tasks yet — tap to add one'
                            : 'No tasks yet',
                        style: TextStyle(color: AppColors.subtitle, fontSize: 13),
                      ),
                      if (!space.isCreator) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Tasks added by the creator will appear here',
                          style: TextStyle(
                              color: AppColors.subtitle.withOpacity(0.6),
                              fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            )
          else
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: widget.onReorder,
              proxyDecorator: (child, index, animation) =>
                  Material(color: Colors.transparent, child: child),
              children: List.generate(
                space.tasks.length,
                (i) => KeyedSubtree(
                  key: ValueKey(space.tasks[i].title + i.toString()),
                  child: SelectedTaskItem(
                    task: space.tasks[i],
                    index: i,
                    isLast: i == space.tasks.length - 1,
                    onTap: () => widget.onTaskTap(space.tasks[i]),
                    onDelete: () => widget.onDeleteTask(space.tasks[i]),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Task item (dark background, reorderable)
// ─────────────────────────────────────────────────────────────
class SelectedTaskItem extends StatelessWidget {
  final SpaceTask task;
  final int index;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const SelectedTaskItem({
    super.key,
    required this.task,
    required this.index,
    required this.isLast,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasAssignee = task.assignedTo.isNotEmpty;
    final hasAttachments = task.attachments.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status indicator + dashed connector
            SizedBox(
              width: 36,
              child: Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: task.statusColor.withOpacity(0.20),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: task.statusColor.withOpacity(0.4),
                          width: 1.5),
                    ),
                    child: Icon(
                      task.status == 'Completed'
                          ? Icons.check_rounded
                          : task.status == 'In Progress'
                              ? Icons.access_time_rounded
                              : Icons.radio_button_unchecked_rounded,
                      color: task.statusColor,
                      size: 16,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: CustomPaint(
                        painter: DashedLinePainter(color: task.statusColor),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + status badge + drag handle
                    Row(
                      children: [
                        Expanded(
                          child: Text(task.title,
                              style: TextStyle(
                                  color: AppColors.text,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: task.statusColor.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(task.status,
                                  style: TextStyle(
                                      color: task.statusColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(width: 4),
                              Icon(Icons.chevron_right_rounded,
                                  color: task.statusColor.withOpacity(0.7),
                                  size: 12),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        ReorderableDragStartListener(
                          index: index,
                          child: Icon(
                            Icons.drag_indicator_rounded,
                            color: AppColors.text.withOpacity(0.25),
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),

                    // Description
                    Text(
                      task.description.isNotEmpty
                          ? task.description
                          : 'No notes',
                      style: TextStyle(
                          color: AppColors.text.withOpacity(
                              task.description.isNotEmpty ? 0.55 : 0.25),
                          fontSize: 12,
                          fontStyle: task.description.isEmpty
                              ? FontStyle.italic
                              : FontStyle.normal),
                    ),

                    // Assignee + attachments
                    if (hasAssignee || hasAttachments) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (hasAssignee) ...[
                            Builder(builder: (_) {
                              final total = task.assignedTo.length;
                              final showCount = total > 3 ? 3 : total;
                              final overflow = total - showCount;
                              final slots =
                                  showCount + (overflow > 0 ? 1 : 0);
                              return SizedBox(
                                width: 16 + (slots - 1) * 10.0,
                                height: 16,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    if (overflow > 0)
                                      Positioned(
                                        left: showCount * 10.0,
                                        child: CircleAvatar(
                                          radius: 8,
                                          backgroundColor:
                                              AppColors.text.withOpacity(0.15),
                                          child: Text(
                                            '+$overflow',
                                            style: TextStyle(
                                                color: AppColors.text,
                                                fontSize: 6,
                                                fontWeight:
                                                    FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    for (int i = showCount - 1; i >= 0; i--)
                                      Positioned(
                                        left: i * 10.0,
                                        child: CircleAvatar(
                                          radius: 8,
                                          backgroundColor: [
                                            AppColors.link,
                                            const Color(0xFF3A5280),
                                            const Color(0xFF2A3D60),
                                          ][i % 3],
                                          child: Text(
                                            task.assignedTo[i][0]
                                                .toUpperCase(),
                                            style: TextStyle(
                                                color: AppColors.text,
                                                fontSize: 7,
                                                fontWeight:
                                                    FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(width: 6),
                          ],
                          if (hasAttachments)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.text.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.attach_file_rounded,
                                      color: AppColors.text.withOpacity(0.6),
                                      size: 11),
                                  const SizedBox(width: 4),
                                  Text('${task.attachments.length}',
                                      style: TextStyle(
                                          color: AppColors.text.withOpacity(0.75),
                                          fontSize: 10)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
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
// Member chip
// ─────────────────────────────────────────────────────────────
class MemberChip extends StatelessWidget {
  final String name;
  final bool canKick;
  final VoidCallback? onKick;

  const MemberChip({
    super.key,
    required this.name,
    required this.canKick,
    this.onKick,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.text.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.text.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_rounded, color: AppColors.subtitle, size: 12),
          const SizedBox(width: 5),
          Text(name, style: TextStyle(color: AppColors.text, fontSize: 11)),
          if (canKick) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onKick,
              child: const Icon(Icons.close_rounded,
                  color: Color(0xFFE87070), size: 13),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Pending member chip — dimmed, amber "Pending" badge
// ─────────────────────────────────────────────────────────────
class _PendingMemberChip extends StatelessWidget {
  final String name;
  final VoidCallback? onCancel;
  const _PendingMemberChip({required this.name, this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.text.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8A870).withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_outline_rounded,
              color: AppColors.text.withOpacity(0.35), size: 12),
          const SizedBox(width: 5),
          Text(name,
              style: TextStyle(color: AppColors.text.withOpacity(0.4), fontSize: 11)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFE8A870).withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Pending',
              style: TextStyle(color: Color(0xFFE8A870), fontSize: 9),
            ),
          ),
          if (onCancel != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onCancel,
              child: Icon(Icons.close_rounded,
                  size: 13, color: AppColors.text.withOpacity(0.4)),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Invite code row (used inside Add Member dialog)
// ─────────────────────────────────────────────────────────────
class InviteCodeRow extends StatefulWidget {
  final Space space;
  final void Function(void Function()) setDlg;

  const InviteCodeRow({
    super.key,
    required this.space,
    required this.setDlg,
  });

  @override
  State<InviteCodeRow> createState() => _InviteCodeRowState();
}

class _InviteCodeRowState extends State<InviteCodeRow> {
  bool _copied = false;

  Future<void> _onCopy() async {
    await Clipboard.setData(ClipboardData(text: widget.space.inviteCode));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.space.inviteCode;
    final display = code;
    final accent = widget.space.accentColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.key_rounded, color: accent.withOpacity(0.7), size: 15),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              display,
              style: TextStyle(
                color: accent,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.5,
              ),
            ),
          ),
          GestureDetector(
            onTap: _onCopy,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _copied
                  ? const Icon(Icons.check_rounded,
                      key: ValueKey('check'),
                      color: Color(0xFF3BBFA3),
                      size: 18)
                  : Icon(Icons.copy_rounded,
                      key: const ValueKey('copy'),
                      color: accent.withOpacity(0.6),
                      size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Task Detail Sheet
// ─────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────
// Permission model for TaskDetailSheet
//
// Centralises all edit-gating logic in one place so individual
// widgets never re-implement the same isCreator checks.
//
//  creator        → all actions
//  assignedMember → cycle status + add/remove attachments only
//  viewer         → read-only
// ─────────────────────────────────────────────────────────────
enum TaskPermission { creator, assignedMember, viewer }

class TaskDetailSheet extends StatefulWidget {
  final SpaceTask task;
  final Space space;
  final VoidCallback onCycleStatus;
  final void Function(List<String> members) onAssign;
  final void Function(String name) onAddAttachment;
  final void Function(SpaceAttachment a) onRemoveAttachment;
  final void Function(String notes) onUpdateNotes;
  final void Function(String title) onUpdateTitle;
  final VoidCallback onDelete;
  /// Raw display name of the currently logged-in user.
  /// Used to compute [TaskPermission] — never a sentinel string.
  final String currentUser;

  const TaskDetailSheet({
    super.key,
    required this.task,
    required this.space,
    required this.onCycleStatus,
    required this.onAssign,
    required this.onAddAttachment,
    required this.onRemoveAttachment,
    required this.onUpdateNotes,
    required this.onUpdateTitle,
    required this.onDelete,
    required this.currentUser,
  });

  @override
  State<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<TaskDetailSheet> {
  Color get _statusColor => widget.task.statusColor;

  late final TextEditingController _notesController;
  late final TextEditingController _titleController;
  bool _isEditingNotes = false;
  bool _isEditingTitle = false;

  /// Single source of truth for what the current user can do in this task.
  ///
  /// Computed lazily from [widget.space] and [widget.currentUser]:
  ///  - creator        → space.isCreator flag (set at join/create time)
  ///  - assignedMember → current user appears in task.assignedTo
  ///                     (raw name or with "(Creator)" suffix)
  ///  - viewer         → everyone else
  ///
  /// Uses a getter (not cached field) so it reacts to task.assignedTo
  /// mutations that happen while the sheet is open.
  TaskPermission get _permission {
    if (widget.space.isCreator) return TaskPermission.creator;
    final me = widget.currentUser; // raw displayName — never a sentinel
    final assigned = widget.task.assignedTo;

    // Only match the current user's real display name, or the name with the
    // "(Creator)" suffix the assignment picker appends for the creator slot.
    // We deliberately do NOT match bare 'You' / 'You (Creator)' sentinels
    // here — those are creator-side UI labels that may have been persisted
    // in assignedTo by an older build.  Matching them would grant
    // assignedMember rights to every non-creator user on any task where the
    // creator assigned themselves, which is a security / UX bug.
    final isAssigned = assigned.contains(me) ||
        assigned.contains('$me (Creator)');
    if (isAssigned) return TaskPermission.assignedMember;
    return TaskPermission.viewer;
  }

  bool get _canCycleStatus =>
      _permission == TaskPermission.creator ||
      _permission == TaskPermission.assignedMember;

  bool get _canManageAttachments =>
      _permission == TaskPermission.creator ||
      _permission == TaskPermission.assignedMember;

  bool get _canEditStructure => _permission == TaskPermission.creator;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.task.description);
    _titleController = TextEditingController(text: widget.task.title);
  }

  @override
  void dispose() {
    _notesController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _saveNotes() {
    final trimmed = _notesController.text.trim();
    widget.task.description = trimmed;
    widget.onUpdateNotes(trimmed);
    setState(() => _isEditingNotes = false);
  }

  void _saveTitle() {
    final trimmed = _titleController.text.trim();
    if (trimmed.isEmpty) {
      _titleController.text = widget.task.title;
      setState(() => _isEditingTitle = false);
      return;
    }
    widget.task.title = trimmed;
    widget.onUpdateTitle(trimmed);
    setState(() => _isEditingTitle = false);
  }

  // ── 1. Background color: AppColors.bgDeep ──────────────────
  // ── 2. Sheet sizes: initial 0.65 / min 0.4 / max 0.92 ──────
  // ── 3. Layout: SingleChildScrollView + Column ───────────────
  @override
  Widget build(BuildContext context) {
    final task = widget.task;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.55,
      maxChildSize: 0.92,
      shouldCloseOnMinExtent: true,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: AppColors.bgDeep,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.text.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 4. Header: title + description in Column,
                    //        status badge with status icon + text + swap icon ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Editable title ──
                              if (_isEditingTitle)
                                TextField(
                                  controller: _titleController,
                                  autofocus: true,
                                  style: TextStyle(
                                    color: AppColors.text,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                    border: InputBorder.none,
                                    hintText: 'Task title',
                                    hintStyle: TextStyle(
                                      color: AppColors.text.withOpacity(0.3),
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onSubmitted: (_) => _saveTitle(),
                                )
                              else
                                GestureDetector(
  onTap: _canEditStructure
      ? () => setState(() => _isEditingTitle = true)
      : null,
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          task.title,
                                          style: TextStyle(
                                            color: AppColors.text,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (_canEditStructure) ...[
  const SizedBox(width: 6),
  Icon(
    Icons.edit_rounded,
    color: AppColors.text.withOpacity(0.3),
    size: 14,
  ),
],
                                    ],
                                  ),
                                ),

                              // ── Save / Cancel row for title ──
                              if (_isEditingTitle) ...[
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onTap: () => setState(() {
                                        _titleController.text =
                                            widget.task.title;
                                        _isEditingTitle = false;
                                      }),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.text.withOpacity(0.06),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                              color:
                                                  AppColors.text.withOpacity(0.15)),
                                        ),
                                        child: Text('Cancel',
                                            style: TextStyle(
                                                color:
                                                    AppColors.text.withOpacity(0.5),
                                                fontSize: 11,
                                                fontWeight:
                                                    FontWeight.w600)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: _saveTitle,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: widget.space.accentColor
                                              .withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                              color: widget
                                                  .space.accentColor
                                                  .withOpacity(0.35)),
                                        ),
                                        child: Text('Save',
                                            style: TextStyle(
                                                color: widget
                                                    .space.accentColor,
                                                fontSize: 11,
                                                fontWeight:
                                                    FontWeight.w600)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                             
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Status badge: status icon + text + swap icon
                        GestureDetector(
  onTap: _canCycleStatus
      ? () {
          widget.onCycleStatus();
          setState(() {});
        }
      : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _statusColor.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: _statusColor.withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  task.status == 'Completed'
                                      ? Icons.check_rounded
                                      : task.status == 'In Progress'
                                          ? Icons.access_time_rounded
                                          : Icons.radio_button_unchecked_rounded,
                                  color: _statusColor,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  task.status,
                                  style: TextStyle(
                                    color: _statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.swap_horiz_rounded,
                                    color: _statusColor.withOpacity(0.7),
                                    size: 12),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Notes section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const _SectionLabel(label: 'Notes'),
if (!_isEditingNotes && _canEditStructure)                          GestureDetector(
                            onTap: () => setState(() => _isEditingNotes = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: widget.space.accentColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: widget.space.accentColor
                                        .withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit_rounded,
                                      color: widget.space.accentColor,
                                      size: 11),
                                  const SizedBox(width: 4),
                                  Text('Edit',
                                      style: TextStyle(
                                          color: widget.space.accentColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          )
else if (_canEditStructure)                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () => setState(() {
                                  _notesController.text =
                                      widget.task.description;
                                  _isEditingNotes = false;
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.text.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: AppColors.text.withOpacity(0.15)),
                                  ),
                                  child: Text('Cancel',
                                      style: TextStyle(
                                          color: AppColors.text.withOpacity(0.5),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _saveNotes,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: widget.space.accentColor
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: widget.space.accentColor
                                            .withOpacity(0.35)),
                                  ),
                                  child: Text('Save',
                                      style: TextStyle(
                                          color: widget.space.accentColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _isEditingNotes
                            ? AppColors.text.withOpacity(0.08)
                            : AppColors.text.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _isEditingNotes
                                ? widget.space.accentColor.withOpacity(0.4)
                                : AppColors.text.withOpacity(0.1)),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: _isEditingNotes
                          ? TextField(
                              controller: _notesController,
                              autofocus: true,
                              maxLines: null,
                              minLines: 3,
                              style: TextStyle(
                                  color: AppColors.text.withOpacity(0.85),
                                  fontSize: 13),
                              cursorColor: widget.space.accentColor,
                              decoration: InputDecoration.collapsed(
                                hintText: 'Add notes…',
                                hintStyle: TextStyle(
                                    color: AppColors.text.withOpacity(0.3),
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic),
                              ),
                            )
                          : Text(
                              task.description.isNotEmpty
                                  ? task.description
                                  : 'No notes added.',
                              style: TextStyle(
                                color: task.description.isNotEmpty
                                    ? AppColors.text.withOpacity(0.75)
                                    : AppColors.text.withOpacity(0.3),
                                fontSize: 13,
                                fontStyle: task.description.isEmpty
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                            ),
                    ),

                    // ── 6. Assignees: inline Wrap of tappable chips ──
                    const SizedBox(height: 20),
                    const _SectionLabel(label: 'Assigned To'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        // Unassigned chip to clear
                        GestureDetector(
                          onTap: _canEditStructure
    ? () {
        widget.onAssign([]);
        setState(() {});
      }
    : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: task.assignedTo.isEmpty
                                  ? AppColors.text.withOpacity(0.18)
                                  : AppColors.text.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: task.assignedTo.isEmpty
                                      ? AppColors.text.withOpacity(0.4)
                                      : AppColors.text.withOpacity(0.12)),
                            ),
                            child: Text(
                              'Unassigned',
                              style: TextStyle(
                                color: task.assignedTo.isEmpty
                                    ? AppColors.text
                                    : AppColors.text.withOpacity(0.4),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        // Member chips.
                        // [m]    = display label, may carry "(Creator)" suffix.
                        // [mKey] = bare name stored in task.assignedTo / model.
                        // All data operations use mKey; m is render-only.
...[widget.space.isCreator ? '${AuthStore.instance.username} (Creator)' : '${widget.space.creatorName} (Creator)', ...widget.space.members]                            .map((m) {
                          final mKey = m.endsWith(' (Creator)')
                              ? m.substring(0, m.length - ' (Creator)'.length)
                              : m;
                          // Check both bare name and suffixed form so old
                          // persisted data with the suffix still highlights.
                          final isSelected = task.assignedTo.contains(mKey) ||
                              task.assignedTo.contains(m);
                          return GestureDetector(
                            onTap: _canEditStructure
    ? () {
        // Build updated list using mKey (bare name) so the suffix
        // is never written into storage.
        final updated = List<String>.from(task.assignedTo)
          ..removeWhere((a) => a == mKey || a == m);
        if (!isSelected) updated.add(mKey);
        widget.onAssign(updated);
        setState(() {});
      }
    : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? widget.space.accentColor.withOpacity(0.2)
                                    : AppColors.text.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: isSelected
                                        ? widget.space.accentColor
                                            .withOpacity(0.5)
                                        : AppColors.text.withOpacity(0.12)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 8,
                                    backgroundColor: isSelected
                                        ? widget.space.accentColor
                                            .withOpacity(0.5)
                                        : AppColors.link,
                                    child: Text(
                                      mKey[0].toUpperCase(),
                                      style: TextStyle(
                                          color: AppColors.text,
                                          fontSize: 7,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(m,
                                      style: TextStyle(
                                          color: isSelected
                                              ? AppColors.text
                                              : AppColors.text.withOpacity(0.55),
                                          fontSize: 11)),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),

                    // ── 7. Attachments: FilePicker, Wrap of color-coded chips ──
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const _SectionLabel(label: 'Attachments'),
                        if (_canManageAttachments)
  GestureDetector(
    onTap: () => _pickAttachment(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: widget.space.accentColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: widget.space.accentColor
                                      .withOpacity(0.35)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.attach_file_rounded,
                                    color: widget.space.accentColor,
                                    size: 12),
                                const SizedBox(width: 4),
                                Text('Add file',
                                    style: TextStyle(
                                        color: widget.space.accentColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (task.attachments.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: task.attachments.map((a) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: a.color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: a.color.withOpacity(0.35)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(a.icon,
                                    color: a.color, size: 12),
                                const SizedBox(width: 5),
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 140),
                                  child: Text(
                                    a.name,
                                    style: TextStyle(
                                        color: AppColors.text.withOpacity(0.8),
                                        fontSize: 11),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                if (_canManageAttachments)
                                GestureDetector(
                                  onTap: () {
                                    widget.onRemoveAttachment(a);
                                    setState(() {});
                                  },
                                  child: Icon(Icons.close_rounded,
                                      color: const Color(0xFFE87070)
                                          .withOpacity(0.7),
                                      size: 13),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      )
                    else
                      Text('No attachments yet.',
                          style: TextStyle(
                              color: AppColors.text.withOpacity(0.3),
                              fontSize: 13,
                              fontStyle: FontStyle.italic)),

                  ],
                ),
              ),
            ),

            // ── 8. Delete button: pinned at bottom ──
            if (_canEditStructure)
  Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
    child: GestureDetector(
                onTap: widget.onDelete,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE87070).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                        color: const Color(0xFFE87070).withOpacity(0.35)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline_rounded,
                          color: Color(0xFFE87070), size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Delete Task',
                        style: TextStyle(
                            color: Color(0xFFE87070),
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 7. Real file picker ─────────────────────────────────────
  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.isNotEmpty) {
      final name = result.files.first.name;
      widget.onAddAttachment(name);
      setState(() {});
    }
  }
}

// ─────────────────────────────────────────────────────────────
// ── 5. Section label: AppColors.text.withOpacity(0.45), no accent ───
// ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
        label.toUpperCase(),
        style: TextStyle(
          color: AppColors.text.withOpacity(0.45),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      );
}

class _TaskSheetAssigneeChip extends StatelessWidget {
  final String name;
  const _TaskSheetAssigneeChip({required this.name});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.text.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.text.withOpacity(0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 8,
              backgroundColor: AppColors.link,
              child: Text(
                name[0].toUpperCase(),
                style: TextStyle(
                    color: AppColors.text, fontSize: 7, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 6),
            Text(name, style: TextStyle(color: AppColors.text, fontSize: 11)),
          ],
        ),
      );
}