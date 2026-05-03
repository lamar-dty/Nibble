import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../models/space.dart';

// ─────────────────────────────────────────────────────────────
// Sheet A: spaces list
// ─────────────────────────────────────────────────────────────
// Architecture: CustomScrollView at the root.
//
// The DraggableScrollableSheet requires its scrollController to attach to a
// scrollable that is the direct child of its builder. CustomScrollView
// satisfies this: dragging anywhere on the sheet — header or list — travels
// through a single scroll controller so sheet drag, header pinning, and list
// scroll all work from one axis with no nested-scroll conflicts.
//
// The header (drag handle + title row + filter chips) is rendered inside a
// SliverAppBar(pinned: true, collapseMode: CollapseMode.none) so it stays
// fixed at the top regardless of list scroll position.
//
// Space cards live in a SliverList; the empty state uses SliverFillRemaining
// so it fills the remaining viewport without introducing a nested scroller.
// ─────────────────────────────────────────────────────────────
class SpacesSheet extends StatefulWidget {
  /// The ScrollController provided by DraggableScrollableSheet's builder.
  /// Must be attached directly to the root CustomScrollView — never to a
  /// nested SingleChildScrollView — to avoid SliverGeometry crashes and
  /// nested-scroll conflicts.
  final ScrollController scrollController;

  final List<Space> spaces;
  final void Function(Space) onSpaceTap;
  final VoidCallback onAdd;
  final void Function(Space) onDelete;
  final int inProgress;
  final int completed;
  final int notStarted;

  const SpacesSheet({
    super.key,
    required this.scrollController,
    required this.spaces,
    required this.onSpaceTap,
    required this.onAdd,
    required this.onDelete,
    required this.inProgress,
    required this.completed,
    required this.notStarted,
  });

  @override
  State<SpacesSheet> createState() => _SpacesSheetState();
}

class _SpacesSheetState extends State<SpacesSheet> {
  String? _activeFilter;

  List<Space> get _filteredSpaces {
    if (_activeFilter == null) return widget.spaces;
    return widget.spaces.where((s) => s.status == _activeFilter).toList();
  }

  void _setFilter(String? filter) => setState(() => _activeFilter = filter);

  @override
  void didUpdateWidget(SpacesSheet old) {
    super.didUpdateWidget(old);
    // If all spaces were removed, clear any active filter so the empty state
    // shows "No spaces yet / Tap to add one" rather than "No X spaces / Try a
    // different filter".
    if (widget.spaces.isEmpty && _activeFilter != null) {
      _activeFilter = null;
    }
  }

  // ── Header height ──────────────────────────────────────────
  // Fixed pixel height for the pinned SliverAppBar.
  // Drag handle (4px pill + 12 top + 16 bottom margin) = 32
  // Title row (≈ 30px icon button)                      = 30
  // SizedBox below title                                = 16
  // Filter chips row (≈ 36px tap target)                = 36
  // SizedBox below chips                                = 12
  // Total                                               = 126
  static const double _headerHeight = 126.0;

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSpaces;

    return CustomScrollView(
      // The DraggableScrollableSheet scrollController attaches HERE — directly
      // to the root scrollable. This is the canonical requirement: one
      // controller, one scrollable at the root, no nesting.
      controller: widget.scrollController,
      physics: const ClampingScrollPhysics(),
      slivers: [
        // ── Pinned header sliver ─────────────────────────────────────────
        // SliverAppBar(pinned: true) keeps the drag handle, title row, and
        // filter chips visible while the space cards scroll beneath.
        // collapseMode: CollapseMode.none prevents FlexibleSpaceBar from
        // translating or fading the header content as the sheet scrolls —
        // the header must remain fully rendered at all times.
        // toolbarHeight is set to the exact measured height of the header
        // widget so the SliverAppBar reports the correct paintExtent and
        // avoids SliverGeometry layoutExtent > paintExtent crashes.
        SliverAppBar(
          pinned: true,
          automaticallyImplyLeading: false,
          backgroundColor: kWhite,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: _headerHeight,
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.none,
            background: _SpacesSheetHeader(
              spaces: widget.spaces,
              activeFilter: _activeFilter,
              inProgress: widget.inProgress,
              completed: widget.completed,
              notStarted: widget.notStarted,
              onSetFilter: _setFilter,
            ),
          ),
        ),

        // ── Content sliver ───────────────────────────────────────────────
        // Empty state: SliverFillRemaining fills the remaining viewport
        // height without a nested scroller — hasScrollBody: false prevents
        // it from claiming an unbounded scroll extent.
        if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: GestureDetector(
                  // Tapping the empty state when there is no filter active opens
                  // the create-space sheet directly, matching the hint text.
                  onTap: _activeFilter == null ? widget.onAdd : null,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.group_work_outlined,
                          size: 60, color: kNavyDark.withOpacity(0.1)),
                      const SizedBox(height: 14),
                      Text(
                        _activeFilter == null
                            ? 'No spaces yet'
                            : 'No $_activeFilter spaces',
                        style: TextStyle(
                            color: kNavyDark.withOpacity(0.4),
                            fontSize: 15,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _activeFilter == null
                            ? 'Tap to add one'
                            : 'Try a different filter',
                        style: TextStyle(
                            color: kNavyDark.withOpacity(0.25), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        else
          // Space cards + footer in a SliverList — no nested SingleChildScrollView.
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 80),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  // Footer item — rendered as the last child.
                  if (i == filtered.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'No More Spaces',
                          style: TextStyle(
                              color: Color(0xFFB0BAD3), fontSize: 13),
                        ),
                      ),
                    );
                  }
                  final s = filtered[i];
                  return SpaceCard(
                    space: s,
                    onTap: () => widget.onSpaceTap(s),
                    onDelete: s.isCreator ? () => widget.onDelete(s) : null,
                  );
                },
                childCount: filtered.length + 1, // +1 for footer
              ),
            ),
          ),
      ],
    );
  }
}

// ── Pinned header widget ──────────────────────────────────────────────────────
// Plain StatelessWidget rendered inside SliverAppBar's flexibleSpace.
// Using SliverAppBar(pinned: true) instead of SliverPersistentHeaderDelegate
// avoids the layoutExtent/paintExtent mismatch crash that occurs when the
// delegate's reported extent doesn't exactly match its painted content height.
class _SpacesSheetHeader extends StatelessWidget {
  final List<Space> spaces;
  final String? activeFilter;
  final int inProgress;
  final int completed;
  final int notStarted;
  final void Function(String?) onSetFilter;

  const _SpacesSheetHeader({
    required this.spaces,
    required this.activeFilter,
    required this.inProgress,
    required this.completed,
    required this.notStarted,
    required this.onSetFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle — always visible; sits at the very top of the sheet.
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Title row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your Spaces',
                style: TextStyle(
                    color: kNavyDark,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Quick filter chips — horizontal scroll, never wraps.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              SpaceFilterChip(
                label: 'All',
                count: spaces.length,
                color: kNavyDark,
                isActive: activeFilter == null,
                onTap: () => onSetFilter(null),
              ),
              const SizedBox(width: 8),
              SpaceFilterChip(
                label: 'In Progress',
                count: inProgress,
                color: const Color(0xFF4A90D9),
                isActive: activeFilter == 'In Progress',
                onTap: () => onSetFilter('In Progress'),
              ),
              const SizedBox(width: 8),
              SpaceFilterChip(
                label: 'Not Started',
                count: notStarted,
                color: const Color(0xFFB0BAD3),
                isActive: activeFilter == 'Not Started',
                onTap: () => onSetFilter('Not Started'),
              ),
              const SizedBox(width: 8),
              SpaceFilterChip(
                label: 'Completed',
                count: completed,
                color: const Color(0xFF3BBFA3),
                isActive: activeFilter == 'Completed',
                onTap: () => onSetFilter('Completed'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Space card
// ─────────────────────────────────────────────────────────────
class SpaceCard extends StatelessWidget {
  final Space space;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const SpaceCard({
    super.key,
    required this.space,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final daysLeft = space.daysLeft;
    final isUrgent = !space.isCompleted && daysLeft >= 0 && daysLeft <= 2;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUrgent
                ? const Color(0xFFE87070).withOpacity(0.5)
                : const Color(0xFFEEEEEE),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Colored left border accent
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: space.accentColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),

              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + status badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              space.name,
                              style: const TextStyle(
                                  color: kNavyDark,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: space.statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              space.status,
                              style: TextStyle(
                                  color: space.statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Progress bar + task count
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: space.progress,
                                minHeight: 5,
                                backgroundColor: const Color(0xFFEEEEEE),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    space.accentColor),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${space.completedTasks}/${space.totalTasks}',
                            style: TextStyle(
                                color: space.accentColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Meta row
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded,
                              size: 11, color: Color(0xFF6B7A99)),
                          const SizedBox(width: 3),
                          Text(
                            space.dateRange,
                            style: const TextStyle(
                                color: Color(0xFF6B7A99), fontSize: 10),
                          ),
                          const Spacer(),
                          const Icon(Icons.group_rounded,
                              size: 11, color: Color(0xFF6B7A99)),
                          const SizedBox(width: 3),
                          Text(
                            '${space.memberCount}',
                            style: const TextStyle(
                                color: Color(0xFF6B7A99), fontSize: 10),
                          ),
                          if (isUrgent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE87070)
                                    .withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                daysLeft == 0
                                    ? 'Due today!'
                                    : '$daysLeft days left!',
                                style: const TextStyle(
                                    color: Color(0xFFE87070),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Arrow
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: Color(0xFFB0BAD3)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Filter chip
// ─────────────────────────────────────────────────────────────
class SpaceFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const SpaceFilterChip({
    super.key,
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                  color: isActive ? kWhite : color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isActive
                    ? kWhite.withOpacity(0.25)
                    : color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                    color: isActive ? kWhite : color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}