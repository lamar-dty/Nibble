import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/space.dart';
import '../../models/space_message.dart';
import '../../store/space_chat_store.dart';
import '../../store/task_store.dart';             // ← Step 3: clear chat notification on open

// ─────────────────────────────────────────────────────────────
// Palette (matches the dark-navy app aesthetic)
// ─────────────────────────────────────────────────────────────
const _kBg = Color(0xFF0F1523);
const _kSurface = Color(0xFF1A2235);
const _kBubbleOwn = Color(0xFF3B6FD4);
const _kBubbleOther = Color(0xFF1E2D45);
const _kSystemBg = Color(0xFF1A2235);
const _kText = Color(0xFFE8ECF4);
const _kSubtext = Color(0xFF7A8BA8);
const _kInputBg = Color(0xFF1E2D45);
const _kDivider = Color(0xFF243045);
const _kSend = Color(0xFF3B6FD4);

// ─────────────────────────────────────────────────────────────
// SpaceChatSheet — opened from SpaceChatFab
// ─────────────────────────────────────────────────────────────
class SpaceChatSheet extends StatefulWidget {
  final Space space;
  final String currentUser; // name of the current user

  const SpaceChatSheet({
    super.key,
    required this.space,
    required this.currentUser,
  });

  @override
  State<SpaceChatSheet> createState() => _SpaceChatSheetState();
}

class _SpaceChatSheetState extends State<SpaceChatSheet>
    with SingleTickerProviderStateMixin {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  late AnimationController _entryAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  List<SpaceMessage> get _messages =>
      SpaceChatStore.instance.messagesFor(widget.space.inviteCode);

  @override
  void initState() {
    super.initState();
    _entryAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryAnim, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _entryAnim, curve: Curves.easeOut);
    _entryAnim.forward();

    // Scroll to bottom, mark all messages as read, and clear the home
    // notification badge — all after the first frame so the message list
    // is fully built and the cursor advances against the real message count.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
      SpaceChatStore.instance
          .markAsRead(widget.space.inviteCode, widget.currentUser);
      TaskStore.instance
          .clearChatNotificationsFor(widget.space.inviteCode);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _entryAnim.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = false}) {
    if (!_scroll.hasClients) return;
    final target = _scroll.position.maxScrollExtent;
    if (animated) {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scroll.jumpTo(target);
    }
  }

  Future<void> _sendMessage() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    _input.clear();
    await SpaceChatStore.instance.addMessage(
      widget.space.inviteCode,
      SpaceMessage(sender: widget.currentUser, text: text),
      space: widget.space,
      currentUser: widget.currentUser,
    );
    setState(() {});
    // Own messages are immediately read — advance the cursor.
    SpaceChatStore.instance
        .markAsRead(widget.space.inviteCode, widget.currentUser);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollToBottom(animated: true));
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          decoration: const BoxDecoration(
            color: _kBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              _ChatHeader(space: widget.space),
              const Divider(color: _kDivider, height: 1),
              Expanded(
                child: _messages.isEmpty
                    ? _EmptyState(spaceName: widget.space.name)
                    : _MessageList(
                        messages: _messages,
                        currentUser: widget.currentUser,
                        scrollController: _scroll,
                        accentColor: widget.space.accentColor,
                        isCreator: widget.space.isCreator,
                      ),
              ),
              _InputBar(
                controller: _input,
                onSend: _sendMessage,
                extraBottom: bottom,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _ChatHeader
// ─────────────────────────────────────────────────────────────
class _ChatHeader extends StatelessWidget {
  final Space space;
  const _ChatHeader({required this.space});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
      child: Row(
        children: [
          // Drag handle
          Column(
            children: [
              const SizedBox(height: 2),
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: _kDivider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
          // Avatar + title
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: space.accentColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                space.name.isNotEmpty ? space.name[0].toUpperCase() : '#',
                style: TextStyle(
                  color: space.accentColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  space.name,
                  style: const TextStyle(
                    color: _kText,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${space.memberCount} members',
                  style: const TextStyle(color: _kSubtext, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: _kSubtext, size: 22),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _MessageList
// ─────────────────────────────────────────────────────────────
class _MessageList extends StatelessWidget {
  final List<SpaceMessage> messages;
  final String currentUser;
  final ScrollController scrollController;
  final Color accentColor;
  final bool isCreator;

  const _MessageList({
    required this.messages,
    required this.currentUser,
    required this.scrollController,
    required this.accentColor,
    required this.isCreator,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: messages.length,
      itemBuilder: (context, i) {
        final msg = messages[i];
        final prev = i > 0 ? messages[i - 1] : null;
        final showSender = !msg.isSystemMessage &&
            (prev == null ||
                prev.sender != msg.sender ||
                prev.isSystemMessage);
        final isOwn = msg.sender == currentUser;

        if (msg.isSystemMessage) {
          return _SystemBubble(text: msg.text);
        }

        return _MessageBubble(
          message: msg,
          isOwn: isOwn,
          showSender: showSender,
          accentColor: accentColor,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _MessageBubble
// ─────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final SpaceMessage message;
  final bool isOwn;
  final bool showSender;
  final Color accentColor;

  const _MessageBubble({
    required this.message,
    required this.isOwn,
    required this.showSender,
    required this.accentColor,
  });

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: showSender ? 12 : 2,
        bottom: 2,
      ),
      child: Row(
        mainAxisAlignment:
            isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isOwn) ...[
            _Avatar(name: message.sender, visible: showSender),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showSender && !isOwn)
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 4),
                    child: Text(
                      message.sender,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isOwn)
                      Padding(
                        padding: const EdgeInsets.only(right: 6, bottom: 4),
                        child: Text(
                          _formatTime(message.timestamp),
                          style:
                              const TextStyle(color: _kSubtext, fontSize: 10),
                        ),
                      ),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isOwn ? _kBubbleOwn : _kBubbleOther,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft: Radius.circular(isOwn ? 18 : 4),
                            bottomRight: Radius.circular(isOwn ? 4 : 18),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          message.text,
                          style: const TextStyle(
                            color: _kText,
                            fontSize: 14.5,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                    if (!isOwn)
                      Padding(
                        padding: const EdgeInsets.only(left: 6, bottom: 4),
                        child: Text(
                          _formatTime(message.timestamp),
                          style:
                              const TextStyle(color: _kSubtext, fontSize: 10),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (isOwn) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _Avatar
// ─────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String name;
  final bool visible;
  const _Avatar({required this.name, required this.visible});

  Color _colorFor(String s) {
    const palette = [
      Color(0xFF3B6FD4),
      Color(0xFF6C63FF),
      Color(0xFF3BBFA3),
      Color(0xFFE87070),
      Color(0xFFE8A070),
    ];
    return palette[s.codeUnitAt(0) % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox(width: 28);
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: _colorFor(name),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _SystemBubble
// ─────────────────────────────────────────────────────────────
class _SystemBubble extends StatelessWidget {
  final String text;
  const _SystemBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _kSystemBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kDivider),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: _kSubtext,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _EmptyState
// ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String spaceName;
  const _EmptyState({required this.spaceName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _kSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kDivider),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: _kSubtext,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No messages yet',
              style: const TextStyle(
                color: _kText,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start the conversation in $spaceName.',
              style: const TextStyle(color: _kSubtext, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _InputBar
// ─────────────────────────────────────────────────────────────
class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final double extraBottom;

  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.extraBottom,
  });

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      final has = widget.controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(
          16,
          10,
          16,
          10 +
              (widget.extraBottom > 0 ? widget.extraBottom : safeBottom)),
      decoration: const BoxDecoration(
        color: _kBg,
        border: Border(top: BorderSide(color: _kDivider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: _kInputBg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _kDivider),
              ),
              child: TextField(
                controller: widget.controller,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(color: _kText, fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Message...',
                  hintStyle: TextStyle(color: _kSubtext),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _hasText ? _kSend : _kInputBg,
              shape: BoxShape.circle,
              border: _hasText ? null : Border.all(color: _kDivider),
            ),
            child: IconButton(
              onPressed: _hasText ? widget.onSend : null,
              icon: Icon(
                Icons.arrow_upward_rounded,
                color: _hasText ? Colors.white : _kSubtext,
                size: 20,
              ),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}