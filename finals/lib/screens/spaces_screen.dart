import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../models/space.dart';
import '../models/space_message.dart';
import '../store/space_chat_store.dart';
import '../store/task_store.dart';
import '../widgets/create_space_sheet.dart';
import '../widgets/spaces/space_painters.dart';
import '../widgets/spaces/space_summary_background.dart';
import '../widgets/spaces/spaces_list_sheet.dart';
import '../widgets/spaces/space_detail_sheet.dart';
import '../widgets/spaces/space_dialogs.dart';
import '../widgets/spaces/space_chat_fab.dart';
import '../widgets/spaces/space_chat_sheet.dart';
import '../store/space_store.dart';
import '../store/auth_store.dart';
import '../services/notification_router.dart';

// ─────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────
class SpacesScreen extends StatefulWidget {
  final ValueNotifier<int> tabNotifier;

  const SpacesScreen({super.key, required this.tabNotifier});

  @override
  State<SpacesScreen> createState() => SpacesScreenState();
}

class SpacesScreenState extends State<SpacesScreen>
    with SingleTickerProviderStateMixin {
  static const double _snapPeek = 0.20;
  static const double _snapHalf = 0.50;
  static const double _snapFull = 1.0;

  late DraggableScrollableController _sheetController;
  late AnimationController _switchAnim;
  double _sheetSize = _snapPeek;
  Space? _selectedSpace;

  // Holds the ScrollController provided by DraggableScrollableSheet's builder.
  // Updated every time the builder runs; used to reset scroll position to top
  // before collapsing the sheet on tab-away so the drag handle stays visible.
  ScrollController? _sheetScrollController;

  List<Space> get _spaces => SpaceStore.instance.spaces;

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
    _sheetController.addListener(() {
      if (mounted) setState(() => _sheetSize = _sheetController.size);
    });
    widget.tabNotifier.addListener(_onTabChanged);
    _switchAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    // Register deep-link callbacks so NotificationRouter can open spaces,
    // tasks, and chat panels from notification taps.
    NotificationRouter.instance.registerSpaceCallbacks(
      onOpenSpace:     openSpaceByCode,
      onOpenSpaceChat: openSpaceChatByCode,
      onOpenSpaceTask: openSpaceTaskByCode,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // ── Step 1: Drain deletion notices FIRST.
    SpaceStore.instance.drainDeletionNotices().then((removedCodes) async {
      if (removedCodes.isEmpty) return;
      await TaskStore.instance.drainSharedInbox();
      for (final code in removedCodes) {
        SpaceChatStore.instance.deleteMessagesFor(code);
        TaskStore.instance.clearSpaceNotifications(code);
      }
      if (mounted) setState(() {});
    });

    // ── Step 2: Pull latest patches for spaces that still exist.
    SpaceStore.instance.syncFromSharedPatches().then((_) {
      if (mounted) setState(() {});
    });

    // ── Step 3: Accept any new space invites pushed to this user.
    SpaceStore.instance.drainPendingInvites().then((_) {
      if (mounted) setState(() {});
    });

    // ── Step 4: Drain remaining cross-user notifications (assignments etc).
    TaskStore.instance.drainSharedInbox();

    // ── Step 5: Prune stale notifications for any already-removed spaces.
    TaskStore.instance.pruneOrphanedSpaceNotifications(
      SpaceStore.instance.activeInviteCodes,
    );
  }

  @override
  void dispose() {
    NotificationRouter.instance.unregisterSpaceCallbacks();
    widget.tabNotifier.removeListener(_onTabChanged);
    _sheetController.dispose();
    _switchAnim.dispose();
    super.dispose();
  }

  // Collapse sheet when navigating away from Spaces tab (index 2).
  // Resets the internal scroll position to top first so the drag handle is
  // always visible after the sheet collapses.
  void _onTabChanged() {
    if (!mounted) return;
    if (widget.tabNotifier.value == 2) return; // staying on spaces — no-op
    if (!_sheetController.isAttached) return;

    // Reset the spaces list scroll to top before collapsing.
    // Guards: controller must have clients and position pixels must be above
    // minScrollExtent to avoid jumpTo exceptions on already-topped lists.
    final sc = _sheetScrollController;
    if (sc != null && sc.hasClients) {
      try {
        final pos = sc.position;
        if (pos.pixels > pos.minScrollExtent) {
          sc.jumpTo(pos.minScrollExtent);
        }
      } catch (_) {
        // Controller detached or position unavailable — safe to ignore.
      }
    }

    _sheetController.animateTo(
      _snapPeek,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  // ── Public entry point for create_space_sheet ──────────────
  Future<void> addSpace(SpaceResult result) async {
    final space = _spaceFromResult(result);
    await SpaceStore.instance.addSpace(space);
    setState(() {});
    TaskStore.instance.notifySpaceCreated(space);
    TaskStore.instance.generateSpaceTaskDeadlineAlerts(space);
    await _pushInvitesToAddedMembers(space);
  }

  // ── Deep-link public API (called by NotificationRouter) ───
  void openSpaceByCode(String inviteCode) {
    final space = SpaceStore.instance.spaces
        .where((s) => s.inviteCode == inviteCode)
        .firstOrNull;
    if (space == null) return;
    _selectSpace(space);
  }

  void openSpaceChatByCode(String inviteCode) {
    final space = SpaceStore.instance.spaces
        .where((s) => s.inviteCode == inviteCode)
        .firstOrNull;
    if (space == null) return;
    _selectSpace(space);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        useSafeArea: false,
        builder: (_) => DraggableScrollableSheet(
          initialChildSize: 0.92,
          minChildSize: 0.5,
          maxChildSize: 1.0,
          expand: false,
          snap: true,
          snapSizes: const [0.5, 0.92, 1.0],
          builder: (ctx, scrollController) => SpaceChatSheet(
            space: space,
            currentUser: _resolvedCurrentUser(space),
          ),
        ),
      );
    });
  }

  void openSpaceTaskByCode(String inviteCode, String taskTitle) {
    final space = SpaceStore.instance.spaces
        .where((s) => s.inviteCode == inviteCode)
        .firstOrNull;
    if (space == null) return;
    _selectSpace(space);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final task = space.tasks
          .where((t) => t.title == taskTitle)
          .firstOrNull;
      if (task == null) return;
      _onTaskTapped(space, task);
    });
  }

  // ── Navigation ─────────────────────────────────────────────
  void _selectSpace(Space space) {
    setState(() => _selectedSpace = space);
    _switchAnim.forward(from: 0);
    _sheetController.animateTo(
      _snapPeek,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _backToSpaces() {
    setState(() => _selectedSpace = null);
    _switchAnim.reverse();
    _sheetController.animateTo(
      _snapPeek,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  // ── Task mutations ─────────────────────────────────────────
  void _saveSpaces() => SpaceStore.instance.save();

  void _deleteTask(Space space, SpaceTask task) {
    setState(() {
      space.tasks.remove(task);
      space.recalculate();
    });
    _saveSpaces();
  }

  void _reorderTask(Space space, int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final task = space.tasks.removeAt(oldIndex);
      space.tasks.insert(newIndex, task);
    });
    _saveSpaces();
  }

  void _addTaskToSpace(Space space, String title, String note) {
    final task = SpaceTask(
      title: title,
      description: note,
      status: 'Not Started',
      statusColor: const Color(0xFFB0BAD3),
    );
    setState(() {
      space.tasks.add(task);
      space.recalculate();
    });
    _saveSpaces();
    TaskStore.instance.notifySpaceTaskAdded(space, task);
    TaskStore.instance.refreshDeadlineAlertFor(space, task);
  }

  // ── Space mutations ────────────────────────────────────────
  Future<void> _removeSpace(Space space) async {
    if (!space.isCreator) {
      final leavingName = AuthStore.instance.displayName;
      for (final task in space.tasks) {
        task.assignedTo.remove(leavingName);
      }
      space.members.remove(leavingName);
      await SpaceStore.instance.writeSharedPatchForLeave(space);
      await TaskStore.instance.notifyMemberLeft(space, leavingName);
    }
    TaskStore.instance.clearSpaceNotifications(space.inviteCode);
    SpaceChatStore.instance.deleteMessagesFor(space.inviteCode);

    if (space.isCreator) {
      for (final memberName in space.members) {
        final cleaned = memberName
            .replaceAll(RegExp(r'\s*\(Creator\)\s*$'), '')
            .trim();
        if (cleaned.isEmpty) continue;
        final memberId = AuthStore.instance.userIdForName(cleaned);
        if (memberId == null || memberId.isEmpty) continue;
        await TaskStore.instance.notifySpaceDeletedForMember(
          spaceName:   space.name,
          creatorName: space.creatorName,
          accentColor: space.accentColor,
          inviteCode:  space.inviteCode,
          memberUserId: memberId,
        );
      }
    }

    await SpaceStore.instance.removeSpace(space);
    TaskStore.instance.pruneOrphanedSpaceNotifications(
      SpaceStore.instance.activeInviteCodes,
    );
    setState(() {
      if (_selectedSpace == space) _selectedSpace = null;
    });

    // Reset scroll to top so the sheet's drag gesture isn't locked by a
    // stale scroll offset left over from the deleted space's content.
    final sc = _sheetScrollController;
    if (sc != null && sc.hasClients) {
      try {
        final pos = sc.position;
        if (pos.pixels > pos.minScrollExtent) {
          sc.jumpTo(pos.minScrollExtent);
        }
      } catch (_) {
        // Controller detached — safe to ignore.
      }
    }

    // Re-seat the sheet at peek so DraggableScrollableSheet re-registers
    // its drag correctly after the list content changes.
    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        _snapPeek,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // ── Dialog bridges ─────────────────────────────────────────
  void _onTaskTapped(Space space, SpaceTask task) {
    final currentUser = _resolvedCurrentUser(space);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (sheetCtx) => TaskDetailSheet(
        task: task,
        space: space,
        onCycleStatus: () {
          setState(() {
            task.cycleStatus();
            space.recalculate();
          });
          _saveSpaces();
          if (task.status == 'Completed') {
            TaskStore.instance.notifySpaceTaskCompleted(space, task);
          } else {
            TaskStore.instance.notifySpaceTaskStatusChanged(space, task);
          }
          TaskStore.instance.refreshDeadlineAlertFor(space, task);
        },
        onAssign: (members) {
          setState(() => task.assignedTo = members);
          _saveSpaces();
          TaskStore.instance.notifySpaceTaskAssigned(space, task, currentUser);
        },
        onUpdateNotes: (notes) {
          setState(() => task.description = notes);
          _saveSpaces();
        },
        onUpdateTitle: (title) {
          setState(() => task.title = title);
          _saveSpaces();
        },
        onAddAttachment: (name) {
          setState(() => task.attachments.add(SpaceAttachment(name: name)));
          _saveSpaces();
        },
        onRemoveAttachment: (a) {
          setState(() => task.attachments.remove(a));
          _saveSpaces();
        },
        onDelete: () {
          showConfirmDeleteTask(
            context,
            task,
            onConfirm: () {
              Navigator.pop(sheetCtx);
              _deleteTask(space, task);
            },
          );
        },
        currentUser: currentUser,
      ),
    );
  }

  void _onAddTask(Space space) {
    showAddTaskDialog(
      context,
      space,
      onAdd: (title, note) => _addTaskToSpace(space, title, note),
    );
  }

  void _onAddMember(Space space) {
    showAddMemberDialog(
      context,
      space,
      onMemberAdded: () => setState(() {}),
    );
  }

  void _onDeleteSpace(Space space) {
    showConfirmDeleteSpace(
      context,
      space,
      onConfirm: () => _removeSpace(space),
    );
  }

  void _onLeaveSpace(Space space) {
    showConfirmLeaveSpace(
      context,
      space,
      onConfirm: () => _removeSpace(space),
    );
  }

  void _onKickMember(Space space, String member) {
    showConfirmKickMember(
      context,
      space,
      member,
      onConfirm: () {
        setState(() {
          final strippedMember =
              member.replaceAll(RegExp(r'\s*\(Creator\)\s*$'), '').trim();
          space.members.removeWhere((m) {
            final stripped = m.replaceAll(RegExp(r'\s*\(Creator\)\s*$'), '').trim();
            return stripped == strippedMember;
          });
          SpaceChatStore.instance.addSystemMessage(
            space.inviteCode,
            '$member was removed from the space.',
          );
          for (final task in space.tasks) {
            task.assignedTo.removeWhere((a) {
              final stripped = a.replaceAll(RegExp(r'\s*\(Creator\)\s*$'), '').trim();
              return stripped == strippedMember;
            });
          }
          space.pruneStaleAssignees();
          space.recalculate();
        });
        _saveSpaces();
        TaskStore.instance.notifyMemberRemoved(space, member);
      },
    );
  }

  void _onJoinSpace() {
    showJoinSpaceDialog(
      context,
      isAlreadyJoined: (code) => _spaces.any((s) => s.inviteCode == code),
      onJoin: (code) async {
        final found = await SpaceStore.instance.lookupByCode(code);
        if (found == null) return 'No space found with that invite code';

        final joined = Space(
          name: found.name,
          description: found.description,
          dateRange: found.dateRange,
          dueDate: found.dueDate,
          members: List<String>.from(found.members)
            ..add(AuthStore.instance.displayName),
          isCreator: false,
          creatorName: found.creatorName,
          status: found.status,
          statusColor: found.statusColor,
          accentColor: found.accentColor,
          progress: found.progress,
          completedTasks: found.completedTasks,
          tasks: found.tasks,
          inviteCode: found.inviteCode,
        );

        await SpaceStore.instance.addSpace(joined);
        await SpaceStore.instance.patchMembersInRegistry(
          joined.inviteCode,
          joined.members,
        );
        setState(() {});
        TaskStore.instance.notifySpaceJoined(joined);
        await TaskStore.instance.notifyMemberJoined(
          joined,
          AuthStore.instance.displayName,
          joined.creatorName,
        );
        TaskStore.instance.generateSpaceTaskDeadlineAlerts(joined);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          SpaceChatStore.instance.addSystemMessage(
            joined.inviteCode,
            '${AuthStore.instance.displayName} joined the space.',
          );
        });
        return null;
      },
    );
  }

  void _onAddSpace() {
    showCreateSpaceSheet(context, onSaved: (result) async {
      final space = _spaceFromResult(result);
      await SpaceStore.instance.addSpace(space);
      setState(() {});
      SpaceChatStore.instance.addSystemMessage(
        space.inviteCode,
        '${space.creatorName} created the space.',
      );
      TaskStore.instance.notifySpaceCreated(space);
      TaskStore.instance.generateSpaceTaskDeadlineAlerts(space);
      await _pushInvitesToAddedMembers(space);
    });
  }

  // ── Factory ────────────────────────────────────────────────
  Future<void> _pushInvitesToAddedMembers(Space space) async {
    final creatorName = AuthStore.instance.displayName;
    for (final memberName in space.members) {
      final cleaned = memberName
          .replaceAll(RegExp(r'\s*\(Creator\)\s*$'), '')
          .trim();
      if (cleaned == creatorName || cleaned == 'You' || cleaned.isEmpty) {
        continue;
      }
      final recipientId = AuthStore.instance.userIdForName(cleaned);
      if (recipientId == null || recipientId.isEmpty) continue;
      await SpaceStore.instance.pushPendingInvite(recipientId, space);
      await TaskStore.instance.notifyAddedToSpace(space, cleaned, recipientId);
    }
  }

  Space _spaceFromResult(SpaceResult r) {
    String fmt(DateTime d) =>
        '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year.toString().substring(2)}';

    return Space(
      name: r.name,
      description:
          r.description.isEmpty ? 'No description.' : r.description,
      dateRange: '${fmt(r.startDate)} - ${fmt(r.endDate)}',
      dueDate: '${r.endDate.month}/${r.endDate.day}/${r.endDate.year}',
      members: List<String>.from(r.members),
      isCreator: true,
      creatorName: AuthStore.instance.displayName,
      status: 'Not Started',
      statusColor: const Color(0xFFB0BAD3),
      accentColor: r.accentColor,
      progress: 0.0,
      completedTasks: 0,
      tasks: r.checklistTitles.asMap().entries.map((e) => SpaceTask(
            title: e.value,
            description: r.checklistNotes.length > e.key
                ? r.checklistNotes[e.key]
                : '',
            status: 'Not Started',
            statusColor: const Color(0xFFB0BAD3),
          )).toList(),
    );
  }

  // ── Helpers ────────────────────────────────────────────────
  String _resolvedCurrentUser(Space space) => AuthStore.instance.displayName;

  // ── Computed stats ─────────────────────────────────────────
  int get _inProgressCount =>
      _spaces.where((s) => s.status == 'In Progress').length;
  int get _completedCount =>
      _spaces.where((s) => s.status == 'Completed').length;
  int get _notStartedCount =>
      _spaces.where((s) => s.status == 'Not Started').length;
  double get _overallProgress => _spaces.isEmpty
      ? 0.0
      : _spaces.fold(0.0, (sum, s) => sum + s.progress) / _spaces.length;

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final space = _selectedSpace;

    return Stack(
      children: [
        // Background
        Positioned.fill(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.only(bottom: screenHeight * _sheetSize),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: space == null
                    ? SummaryBackground(
                        key: const ValueKey('summary'),
                        inProgress: _inProgressCount,
                        completed: _completedCount,
                        notStarted: _notStartedCount,
                        totalSpaces: _spaces.length,
                        overallProgress: _overallProgress,
                      )
                    : SelectedBackground(
                        key: ValueKey(space.name),
                        space: space,
                        onBack: _backToSpaces,
                        onTaskTap: (task) => _onTaskTapped(space, task),
                        onDeleteTask: (task) => _deleteTask(space, task),
                        onAddTask: () => _onAddTask(space),
                        onDelete: () => _onDeleteSpace(space),
                        onLeave: () => _onLeaveSpace(space),
                        onKickMember: (member) => _onKickMember(space, member),
                        onAddMember: () => _onAddMember(space),
                        onReorder: (oldIndex, newIndex) =>
                            _reorderTask(space, oldIndex, newIndex),
                      ),
              ),
            ),
          ),
        ),

        // ── DRAGGABLE SPACES SHEET ────────────────────────────────────────
        // Canonical architecture: DecoratedBox (shadow) → ClipRRect (rounded
        // corners) → ColoredBox → SpacesSheet (CustomScrollView root).
        // The DraggableScrollableSheet scrollController is cached in
        // _sheetScrollController and passed directly into SpacesSheet so it
        // attaches to the CustomScrollView root — the only scrollable that
        // drives sheet drag, header pinning, and list scroll from one axis.
        DraggableScrollableSheet(
          controller: _sheetController,
          initialChildSize: _snapPeek,
          minChildSize: _snapPeek,
          maxChildSize: _snapFull,
          snap: true,
          snapSizes: const [_snapPeek, _snapHalf, _snapFull],
          builder: (context, scrollController) {
            // Cache for scroll-reset guard in _onTabChanged.
            _sheetScrollController = scrollController;
            return DecoratedBox(
              decoration: const BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                child: ColoredBox(
                  color: kWhite,
                  child: SpacesSheet(
                    key: const ValueKey('spacesSheet'),
                    scrollController: scrollController,
                    spaces: _spaces,
                    onSpaceTap: _selectSpace,
                    onAdd: _onAddSpace,
                    onJoin: _onJoinSpace,
                    onDelete: _onDeleteSpace,
                    inProgress: _inProgressCount,
                    completed: _completedCount,
                    notStarted: _notStartedCount,
                  ),
                ),
              ),
            );
          },
        ),

        // Chat FAB
        if (space != null)
          Positioned(
            right: 20,
            bottom: screenHeight * _sheetSize + 16,
            child: SpaceChatFab(
              space: space,
              currentUser: _resolvedCurrentUser(space),
            ),
          ),

        // ── NAV BAR TOUCH BLOCKER ────────────────────────────
        // Prevents taps in the BottomAppBar zone from leaking
        // through to the DraggableScrollableSheet behind it.
        // Does NOT restrict sheet height or dragging behavior.
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 56,
          child: AbsorbPointer(absorbing: true),
        ),
      ],
    );
  }
}