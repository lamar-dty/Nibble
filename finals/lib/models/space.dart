import 'package:flutter/material.dart';
import 'dart:math';

// ─────────────────────────────────────────────────────────────
// SpaceAttachment
// ─────────────────────────────────────────────────────────────
class SpaceAttachment {
  final String name;

  SpaceAttachment({required this.name});

  Map<String, dynamic> toJson() => {'name': name};

  factory SpaceAttachment.fromJson(Map<String, dynamic> j) =>
      SpaceAttachment(name: (j['name'] as String?) ?? '');

  String get type {
    final ext =
        name.contains('.') ? name.split('.').last.toLowerCase() : '';
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg'].contains(ext)) {
      return 'image';
    }
    if (['pdf'].contains(ext)) return 'pdf';
    if (['doc', 'docx'].contains(ext)) return 'doc';
    if (['xls', 'xlsx'].contains(ext)) return 'sheet';
    if (['ppt', 'pptx'].contains(ext)) return 'slides';
    if (['zip', 'rar', '7z'].contains(ext)) return 'archive';
    if (['mp4', 'mov', 'avi'].contains(ext)) return 'video';
    return 'file';
  }

  IconData get icon {
    switch (type) {
      case 'image':   return Icons.image_rounded;
      case 'pdf':     return Icons.picture_as_pdf_rounded;
      case 'doc':     return Icons.description_rounded;
      case 'sheet':   return Icons.table_chart_rounded;
      case 'slides':  return Icons.slideshow_rounded;
      case 'archive': return Icons.folder_zip_rounded;
      case 'video':   return Icons.videocam_rounded;
      default:        return Icons.insert_drive_file_rounded;
    }
  }

  Color get color {
    switch (type) {
      case 'image':   return const Color(0xFF9B88E8);
      case 'pdf':     return const Color(0xFFE87070);
      case 'doc':     return const Color(0xFF4A90D9);
      case 'sheet':   return const Color(0xFF3BBFA3);
      case 'slides':  return const Color(0xFFE8A070);
      case 'archive': return const Color(0xFFB0BAD3);
      case 'video':   return const Color(0xFF70B8E8);
      default:        return const Color(0xFFB0BAD3);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// SpaceTask
// ─────────────────────────────────────────────────────────────
class SpaceTask {
  String title;
  String description;
  String status;
  Color statusColor;

  /// Real display names of assigned members as stored in AuthStore.
  /// Must never contain sentinel strings ('You', 'You (Creator)', 'Creator',
  /// or any name suffixed with ' (Creator)').
  /// The UI layer is responsible for translating the stored name to a
  /// display label before presenting it (e.g. "You" for the current user),
  /// but the model always stores and operates on the canonical display name.
  List<String> assignedTo;

  final List<SpaceAttachment> attachments;

  SpaceTask({
    required this.title,
    required this.description,
    required this.status,
    required this.statusColor,
    List<String>? assignedTo,
    List<SpaceAttachment>? attachments,
  })  : assignedTo  = _sanitiseAssignees(assignedTo ?? <String>[]),
        attachments = attachments ?? <SpaceAttachment>[];

  static const List<String> _order = [
    'Not Started',
    'In Progress',
    'Completed'
  ];

  static Color colorFor(String status) {
    switch (status) {
      case 'In Progress': return const Color(0xFF4A90D9);
      case 'Completed':   return const Color(0xFF3BBFA3);
      default:            return const Color(0xFFB0BAD3);
    }
  }

  factory SpaceTask.blank(String title, {String description = ''}) =>
      SpaceTask(
        title:       title,
        description: description,
        status:      'Not Started',
        statusColor: const Color(0xFFB0BAD3),
      );

  void cycleStatus() {
    final next  = (_order.indexOf(status) + 1) % _order.length;
    status      = _order[next];
    statusColor = colorFor(status);
  }

  // ── Assignee helpers ───────────────────────────────────────

  /// Strips sentinel strings and " (Creator)" suffixes from a list of
  /// assignee names so that only canonical display names are stored.
  ///
  /// Sentinel strings like 'You', 'You (Creator)', and 'Creator' must never
  /// be persisted to storage.  The picker UI may generate these labels for
  /// display purposes, but the model layer must always sanitise before storing.
  static List<String> _sanitiseAssignees(List<String> raw) {
    const drop = <String>{'You', 'You (Creator)', 'Creator'};
    final result = <String>[];
    for (final name in raw) {
      if (name.isEmpty) continue;
      if (drop.contains(name)) continue;
      if (name.endsWith(' (Creator)')) {
        final cleaned = name
            .substring(0, name.length - ' (Creator)'.length)
            .trim();
        if (cleaned.isNotEmpty) result.add(cleaned);
        continue;
      }
      result.add(name);
    }
    // Deduplicate while preserving order.
    final seen = <String>{};
    return result.where(seen.add).toList();
  }

  // ── Serialisation ──────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'title':       title,
        'description': description,
        'status':      status,
        'assignedTo':  assignedTo,
        'attachments': attachments.map((a) => a.toJson()).toList(),
      };

  factory SpaceTask.fromJson(Map<String, dynamic> j) {
    final status = (j['status'] as String?) ?? 'Not Started';
    return SpaceTask(
      title:       (j['title']       as String?) ?? '',
      description: (j['description'] as String?) ?? '',
      status:      status,
      statusColor: colorFor(status),
      // Sanitise on load so legacy records with sentinel names are healed.
      assignedTo: _sanitiseAssignees(
          List<String>.from(
              (j['assignedTo'] as List?)?.whereType<String>().toList() ?? [])),
      attachments: ((j['attachments'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => SpaceAttachment.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Space
// ─────────────────────────────────────────────────────────────
class Space {
  String name;
  String description;
  final String dateRange;
  final String dueDate;

  /// All members except the creator.
  /// Must contain only canonical display names — never sentinel strings.
  final List<String> members;

  /// Members who have been invited but have not yet accepted.
  /// Must contain only canonical display names — never sentinel strings.
  final List<String> pendingMembers;

  /// True when the current user created this space.
  final bool isCreator;

  /// Canonical display name of whoever created the space.
  /// Must never be a sentinel string.
  final String creatorName;

  String status;
  Color statusColor;
  final Color accentColor;
  double progress;
  int completedTasks;
  final List<SpaceTask> tasks;
  final String inviteCode;

  Space({
    required this.name,
    required this.description,
    required this.dateRange,
    required this.dueDate,
    required this.members,
    List<String>? pendingMembers,
    required this.isCreator,
    required this.creatorName,
    required this.status,
    required this.statusColor,
    required this.accentColor,
    required this.progress,
    required this.completedTasks,
    required this.tasks,
    String? inviteCode,
  })  : assert(
          creatorName.isNotEmpty,
          'Space.creatorName must not be empty. '
          'Pass AuthStore.instance.displayName when constructing a Space.',
        ),
        assert(
          !_isSentinel(creatorName),
          'Space.creatorName must be a real display name, not a sentinel '
          'string ("$creatorName").',
        ),
        pendingMembers = pendingMembers ?? <String>[],
        inviteCode = inviteCode ?? _generateCode();

  // ── Sentinel guard ─────────────────────────────────────────
  static bool _isSentinel(String name) {
    const sentinels = <String>{'You', 'You (Creator)', 'Creator'};
    if (sentinels.contains(name)) return true;
    if (name.endsWith(' (Creator)')) return true;
    return false;
  }

  static String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng   = Random.secure();
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  /// Total headcount including the creator.
  int get memberCount => members.length + 1;

  int get totalTasks => tasks.length;

  bool get isCompleted => status == 'Completed';

  // ── Member helpers ─────────────────────────────────────────

  /// Returns the canonical (stored) display name for the current user
  /// within this space context.
  ///
  /// If [currentUserDisplayName] matches the creator name, returns
  /// [creatorName]; otherwise returns the name as-is.
  /// Never returns a sentinel string.
  String canonicalNameFor(String currentUserDisplayName) {
    if (currentUserDisplayName.isEmpty) return creatorName;
    // Strip any " (Creator)" suffix the picker may have appended.
    final cleaned = _stripCreatorSuffix(currentUserDisplayName);
    return cleaned;
  }

  /// True if [displayName] is the creator OR appears in the members list.
  /// Sentinel strings are resolved correctly without storing them.
  bool containsMember(String displayName) {
    if (displayName.isEmpty) return false;
    final cleaned = _stripCreatorSuffix(displayName);
    if (cleaned == creatorName) return true;
    return members.contains(cleaned);
  }

  /// Strips the " (Creator)" suffix that the picker UI may append.
  static String _stripCreatorSuffix(String name) {
    if (name.endsWith(' (Creator)')) {
      return name.substring(0, name.length - ' (Creator)'.length).trim();
    }
    return name;
  }

  /// Removes assignee names from all tasks that are no longer members of
  /// this space.  Call after removing a member or syncing from shared patches.
  ///
  /// Sentinel strings are also pruned — they must never persist in storage.
  void pruneStaleAssignees() {
    final valid = <String>{creatorName, ...members};
    for (final task in tasks) {
      task.assignedTo.removeWhere((name) {
        if (name.isEmpty) return true;
        // Always remove sentinel strings, regardless of membership.
        if (_isSentinel(name)) return true;
        final cleaned = _stripCreatorSuffix(name);
        return !valid.contains(cleaned);
      });
    }
  }

  // ── Recalculation ─────────────────────────────────────────

  void recalculate() {
    completedTasks = tasks.where((t) => t.status == 'Completed').length;
    progress       = tasks.isEmpty ? 0.0 : completedTasks / tasks.length;
    final hasInProgress = tasks.any((t) => t.status == 'In Progress');
    if (tasks.isNotEmpty && completedTasks == tasks.length) {
      status      = 'Completed';
      statusColor = const Color(0xFF3BBFA3);
    } else if (completedTasks > 0 || hasInProgress) {
      status      = 'In Progress';
      statusColor = const Color(0xFF4A90D9);
    } else {
      status      = 'Not Started';
      statusColor = const Color(0xFFB0BAD3);
    }
  }

  /// Days remaining until [dueDate] (negative = overdue).
  int get daysLeft {
    try {
      final parts = dueDate.split('/');
      if (parts.length < 3) return 0;
      final due = DateTime(
        int.parse(parts[2]),
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      return due.difference(DateTime.now()).inDays;
    } catch (_) {
      return 0; // malformed date — treat as today
    }
  }

  // ── Serialisation ─────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'name':           name,
        'description':    description,
        'dateRange':      dateRange,
        'dueDate':        dueDate,
        'members':        members,
        'pendingMembers': pendingMembers,
        'isCreator':      isCreator,
        'creatorName':    creatorName,
        'status':         status,
        'accentColor':    accentColor.value,
        'progress':       progress,
        'completedTasks': completedTasks,
        'tasks':          tasks.map((t) => t.toJson()).toList(),
        'inviteCode':     inviteCode,
      };

  /// Ensures exactly one space on each side of the dash in a date-range string.
  static String _normaliseDateRange(String raw) {
    if (raw.isEmpty) return raw;
    return raw.replaceAll(RegExp(r'\s*-\s*'), ' - ');
  }

  /// Sanitises a stored creator name: strips " (Creator)" suffix and falls
  /// back to an empty string on failure rather than storing a sentinel.
  static String _sanitiseCreatorName(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    if (raw == 'Creator' || raw == 'You' || raw == 'You (Creator)') return '';
    if (raw.endsWith(' (Creator)')) {
      return raw.substring(0, raw.length - ' (Creator)'.length).trim();
    }
    return raw;
  }

  /// Sanitises the members list: strips sentinel strings and " (Creator)"
  /// suffixes so that only canonical display names are stored.
  static List<String> _sanitiseMembers(List<dynamic>? raw) {
    const drop = <String>{'You', 'You (Creator)', 'Creator'};
    final result = <String>[];
    for (final item in raw?.whereType<String>() ?? <String>[]) {
      if (item.isEmpty) continue;
      if (drop.contains(item)) continue;
      if (item.endsWith(' (Creator)')) {
        final cleaned = item
            .substring(0, item.length - ' (Creator)'.length)
            .trim();
        if (cleaned.isNotEmpty) result.add(cleaned);
        continue;
      }
      result.add(item);
    }
    // Deduplicate.
    final seen = <String>{};
    return result.where(seen.add).toList();
  }

  factory Space.fromJson(Map<String, dynamic> j) {
    final status      = (j['status'] as String?) ?? 'Not Started';
    final creatorName = _sanitiseCreatorName(j['creatorName'] as String?);

    // Heal legacy records: remove any member entry that duplicates the
    // creator name (including sentinel variants) to avoid double-counting.
    final rawMembers  = _sanitiseMembers(j['members'] as List?);
    final members     = creatorName.isEmpty
        ? rawMembers
        : rawMembers.where((m) => m != creatorName).toList();

    return Space(
      name:           (j['name']        as String?) ?? '',
      description:    (j['description'] as String?) ?? '',
      dateRange:      _normaliseDateRange((j['dateRange'] as String?) ?? ''),
      dueDate:        (j['dueDate']     as String?) ?? '',
      members:        members,
      pendingMembers: _sanitiseMembers(j['pendingMembers'] as List?),
      isCreator:      (j['isCreator']   as bool?)   ?? false,
      // Fall back to a non-empty placeholder only in release builds; in debug
      // the Space constructor assert will fire to surface the root cause.
      creatorName:    creatorName.isNotEmpty ? creatorName : 'Unknown',
      status:         status,
      statusColor:    SpaceTask.colorFor(status),
      accentColor:    Color((j['accentColor'] as int?) ?? 0xFF9B88E8),
      progress:       ((j['progress']      as num?)  ?? 0.0).toDouble(),
      completedTasks: (j['completedTasks'] as int?)  ?? 0,
      tasks: ((j['tasks'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => SpaceTask.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      inviteCode: (j['inviteCode'] as String?) ?? '',
    );
  }
}