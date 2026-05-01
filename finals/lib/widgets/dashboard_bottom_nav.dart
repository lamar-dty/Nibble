import 'package:flutter/material.dart';
import '../store/task_store.dart';
import '../constants/colors.dart';
import 'create_task_sheet.dart';
import 'create_event_sheet.dart';
import 'create_space_sheet.dart';
import 'create_wallet_entry_sheet.dart';

class DashboardBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const DashboardBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Absorb any tap that lands on the bar background between icons
      // so nothing fires except the 4 _NavItem GestureDetectors.
      onTap: () {},
      behavior: HitTestBehavior.opaque,
      child: BottomAppBar(
      color: kTeal,
      shape: const CircularNotchedRectangle(),
      notchMargin: 10,
      elevation: 0,
      padding: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      child: SizedBox(
        height: 36,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _NavItem(icon: Icons.home_rounded,                   index: 0, selectedIndex: selectedIndex, onTap: onTap),
            _NavItem(icon: Icons.calendar_month_rounded,         index: 1, selectedIndex: selectedIndex, onTap: onTap),
            const SizedBox(width: 72),
            _NavItem(icon: Icons.group_rounded,                  index: 2, selectedIndex: selectedIndex, onTap: onTap),
            _NavItem(icon: Icons.account_balance_wallet_rounded, index: 3, selectedIndex: selectedIndex, onTap: onTap),
          ],
        ),
      ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final int index;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _NavItem({required this.icon, required this.index, required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool selected = index == selectedIndex;
    return ListenableBuilder(
      listenable: TaskStore.instance,
      builder: (context, _) {
        final bool hasNotif = index == 0
            && !selected
            && TaskStore.instance.hasUnreadNotifications;
        return GestureDetector(
          onTap: () => onTap(index),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: selected ? -14.0 : 0.0),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            builder: (context, dy, child) => Transform.translate(
              offset: Offset(0, dy),
              child: child,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: selected ? kWhite : Colors.transparent,
                    shape: BoxShape.circle,
                    boxShadow: selected
                        ? [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, spreadRadius: 1, offset: const Offset(0, 4))]
                        : [],
                  ),
                  child: Icon(icon, size: 30, color: selected ? kTeal : kNavyDark.withOpacity(0.7)),
                ),
                if (hasNotif)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE87070),
                        shape: BoxShape.circle,
                        border: Border.all(color: kTeal, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}


// ─────────────────────────────────────────────────────────────
// FAB
// ─────────────────────────────────────────────────────────────
class DashboardFAB extends StatelessWidget {
  final VoidCallback? onNavigateToCalendar;
  final VoidCallback? onNavigateToSpaces;
  final void Function(SpaceResult)? onSpaceSaved;
  const DashboardFAB({super.key, this.onNavigateToCalendar, this.onNavigateToSpaces, this.onSpaceSaved});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64, height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: kNavyDark,
        boxShadow: [BoxShadow(color: kNavyDark.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (_) => _AddMenuSheet(onNavigateToCalendar: onNavigateToCalendar, onNavigateToSpaces: onNavigateToSpaces, onSpaceSaved: onSpaceSaved),
          );
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: const CircleBorder(side: BorderSide(color: kWhite, width: 3)),
        child: const Icon(Icons.add_rounded, color: kWhite, size: 32),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Add Menu Sheet
// ─────────────────────────────────────────────────────────────
class _AddMenuSheet extends StatefulWidget {
  final VoidCallback? onNavigateToCalendar;
  final VoidCallback? onNavigateToSpaces;
  final void Function(SpaceResult)? onSpaceSaved;
  const _AddMenuSheet({this.onNavigateToCalendar, this.onNavigateToSpaces, this.onSpaceSaved});
  @override
  State<_AddMenuSheet> createState() => _AddMenuSheetState();
}

class _AddMenuSheetState extends State<_AddMenuSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late List<Animation<double>> _cardSlides;
  late List<Animation<double>> _cardFades;

  static const _items = [
    _AddItem(
      icon: Icons.task_alt_rounded,
      iconColor: Color(0xFF9B88E8),
      label: 'Create Task',
      description: 'To-do with due date & priority',
      tag: 'CALENDAR',
      tagColor: Color(0xFF9B88E8),
    ),
    _AddItem(
      icon: Icons.event_rounded,
      iconColor: Color(0xFF4A90D9),
      label: 'Add Event',
      description: 'Academic or personal event',
      tag: 'CALENDAR',
      tagColor: Color(0xFF4A90D9),
    ),
    _AddItem(
      icon: Icons.group_rounded,
      iconColor: Color(0xFF3BBFA3),
      label: 'Create Space',
      description: 'Group workspace & shared tasks',
      tag: 'SPACES',
      tagColor: Color(0xFF3BBFA3),
    ),
    _AddItem(
      icon: Icons.payments_rounded,
      iconColor: Color(0xFFE8A870),
      label: 'Log Transaction',
      description: 'Income, expense, or budget entry',
      tag: 'WALLET',
      tagColor: Color(0xFFE8A870),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

    _fade = CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.35, curve: Curves.easeIn));

    _cardSlides = List.generate(_items.length, (i) {
      final s = 0.08 + i * 0.13;
      return CurvedAnimation(parent: _ctrl,
          curve: Interval(s, (s + 0.45).clamp(0.0, 1.0), curve: Curves.easeOutBack));
    });
    _cardFades = List.generate(_items.length, (i) {
      final s = 0.08 + i * 0.13;
      return CurvedAnimation(parent: _ctrl,
          curve: Interval(s, (s + 0.35).clamp(0.0, 1.0), curve: Curves.easeIn));
    });

    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => FadeTransition(
        opacity: _fade,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 28),
          decoration: BoxDecoration(
            color: const Color(0xFF1B2D5B),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: kWhite.withOpacity(0.08)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 40, offset: const Offset(0, -4))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(top: 14, bottom: 18),
                decoration: BoxDecoration(color: kWhite.withOpacity(0.18), borderRadius: BorderRadius.circular(2)),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: kTeal.withOpacity(0.14),
                        shape: BoxShape.circle,
                        border: Border.all(color: kTeal.withOpacity(0.3), width: 1.5),
                      ),
                      child: const Icon(Icons.add_rounded, color: kTeal, size: 22),
                    ),
                    const SizedBox(width: 13),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('What are we adding?',
                            style: TextStyle(color: kWhite, fontSize: 17, fontWeight: FontWeight.bold)),
                        Text('Pick a category to get started',
                            style: TextStyle(color: kWhite.withOpacity(0.4), fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Divider(color: kWhite.withOpacity(0.07), thickness: 1, indent: 22, endIndent: 22),
              const SizedBox(height: 6),

              // Cards
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 22),
                child: Column(
                  children: List.generate(_items.length, (i) =>
                    SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.6), end: Offset.zero)
                          .animate(_cardSlides[i]),
                      child: FadeTransition(
                        opacity: _cardFades[i],
                        child: _AddCard(
                          item: _items[i],
                          onTap: () {
                            Navigator.pop(context);
                            if (i == 0) {
                              // Create Task
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                showCreateTaskSheet(
                                  context,
                                  onSaved: widget.onNavigateToCalendar,
                                );
                              });
                            } else if (i == 1) {
                              // Add Event
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                showCreateEventSheet(
                                  context,
                                  onSaved: widget.onNavigateToCalendar,
                                );
                              });
                            } else if (i == 2) {
                              // Create Space
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                showCreateSpaceSheet(context, onSaved: (result) {
                                  widget.onSpaceSaved?.call(result);
                                  widget.onNavigateToSpaces?.call();
                                });
                              });
                            } else if (i == 3) {
                              // Log Transaction
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                showCreateWalletEntrySheet(context);
                              });
                            }
                          },
                        ),
                      ),
                    ),
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

// ─────────────────────────────────────────────────────────────
// Individual action card
// ─────────────────────────────────────────────────────────────
class _AddCard extends StatefulWidget {
  final _AddItem item;
  final VoidCallback onTap;
  const _AddCard({required this.item, required this.onTap});
  @override
  State<_AddCard> createState() => _AddCardState();
}

class _AddCardState extends State<_AddCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _pressed ? item.iconColor.withOpacity(0.10) : kWhite.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _pressed ? item.iconColor.withOpacity(0.6) : kWhite.withOpacity(0.08),
            width: 1.3,
          ),
        ),
        child: Row(
          children: [
            // Icon bubble
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: item.iconColor.withOpacity(0.13),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: item.iconColor.withOpacity(0.25), width: 1.2),
              ),
              child: Icon(item.icon, color: item.iconColor, size: 23),
            ),
            const SizedBox(width: 13),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(item.label,
                          style: const TextStyle(color: kWhite, fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.tagColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: item.tagColor.withOpacity(0.3)),
                        ),
                        child: Text(item.tag,
                            style: TextStyle(color: item.tagColor, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(item.description,
                      style: TextStyle(color: kWhite.withOpacity(0.37), fontSize: 12)),
                ],
              ),
            ),

            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: kWhite.withOpacity(0.2), size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────
class _AddItem {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String description;
  final String tag;
  final Color tagColor;

  const _AddItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.description,
    required this.tag,
    required this.tagColor,
  });
}