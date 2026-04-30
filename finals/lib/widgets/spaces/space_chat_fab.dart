import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/space.dart';
import '../../store/space_chat_store.dart';
import 'space_chat_sheet.dart';

// ─────────────────────────────────────────────────────────────
// SpaceChatFab
// Floating action button that opens SpaceChatSheet.
// Drop-in replacement for the old stub SpaceChatFab.
// ─────────────────────────────────────────────────────────────
class SpaceChatFab extends StatefulWidget {
  final Space space;

  /// The display name of the current user (defaults to first member listed
  /// or "Me" if none).
  final String? currentUser;

  const SpaceChatFab({
    super.key,
    required this.space,
    this.currentUser,
  });

  @override
  State<SpaceChatFab> createState() => _SpaceChatFabState();
}

class _SpaceChatFabState extends State<SpaceChatFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scale;

  String get _resolvedUser =>
      widget.currentUser ??
      (widget.space.members.isNotEmpty ? widget.space.members.first : 'Me');

  /// Only counts non-system messages from OTHER users that arrived after the
  /// current user's read cursor. Returns 0 once the sheet has been opened.
  int get _unreadCount => SpaceChatStore.instance
      .unreadCountFor(widget.space.inviteCode, _resolvedUser);

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      lowerBound: 0.9,
      upperBound: 1.0,
      value: 1.0,
    );
    _scale = CurvedAnimation(parent: _pulse, curve: Curves.easeOutBack);

    // Rebuild whenever the store changes so the red dot reacts in real time.
    SpaceChatStore.instance.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    SpaceChatStore.instance.removeListener(_onStoreChanged);
    _pulse.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  void _openChat() async {
    HapticFeedback.mediumImpact();
    await _pulse.reverse();
    await _pulse.forward();
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
          space: widget.space,
          currentUser: _resolvedUser,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.space.accentColor;
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: _openChat,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accentColor, accentColor.withOpacity(0.75)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.45),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(
                Icons.chat_rounded,
                color: Colors.white,
                size: 24,
              ),
              if (_unreadCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE87070),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                        )
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}