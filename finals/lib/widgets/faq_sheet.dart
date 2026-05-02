import 'package:flutter/material.dart';
import '../constants/colors.dart';

// ─────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────
void showFaqSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    enableDrag: true,
    builder: (_) => const FaqSheet(),
  );
}

// ─────────────────────────────────────────────────────────────
// Data
// ─────────────────────────────────────────────────────────────
class _FaqItem {
  final String question;
  final String answer;
  final IconData icon;

  const _FaqItem({
    required this.question,
    required this.answer,
    required this.icon,
  });
}

const _faqs = [
  _FaqItem(
    icon: Icons.workspaces_rounded,
    question: 'How do I create a Space?',
    answer:
        'Tap the + button on the Spaces screen. Fill in the space name, description, accent color, and timeline. Once created, you can add members and tasks directly from inside the space.',
  ),
  _FaqItem(
    icon: Icons.link_rounded,
    question: 'How do I invite someone to my Space?',
    answer:
        'Open the space, then tap "Add Member". Enter the user\'s #ID (they can find it in the app drawer). You can also share your space\'s invite code so others can join directly.',
  ),
  _FaqItem(
    icon: Icons.login_rounded,
    question: 'How do I join a Space I was invited to?',
    answer:
        'You can join via the Spaces screen or from the app drawer under Spaces → Join Space. Enter the invite code shared by the space creator. Accepted invites also appear in your notifications.',
  ),
  _FaqItem(
    icon: Icons.task_alt_rounded,
    question: 'How do I add tasks to a Space?',
    answer:
        'Open the space and tap the Tasks section. Use the + button to add a new task, set its title, description, due date, and assign it to a member. Tasks can be updated and marked complete from the same screen.',
  ),
  _FaqItem(
    icon: Icons.person_rounded,
    question: 'Where do I find my User ID?',
    answer:
        'Your #ID is shown in the app drawer at the top of the screen below your name. Share this with others so they can add you as a member to their spaces.',
  ),
  _FaqItem(
    icon: Icons.notifications_rounded,
    question: 'Why am I not receiving notifications?',
    answer:
        'Make sure notifications are enabled in your device settings for this app. You can also check Reminder Settings in the drawer to configure alert preferences.',
  ),
  _FaqItem(
    icon: Icons.account_balance_wallet_rounded,
    question: 'What is the Wallet for?',
    answer:
        'The Wallet lets you track shared expenses and contributions within a space. You can log entries, view balances, and keep a record of who paid for what.',
  ),
  _FaqItem(
    icon: Icons.calendar_month_rounded,
    question: 'How does the Calendar work?',
    answer:
        'The Calendar shows all your tasks and events in a weekly view. Tap any day to see what\'s scheduled. Tasks with due dates automatically appear here.',
  ),
];

// ─────────────────────────────────────────────────────────────
// Sheet
// ─────────────────────────────────────────────────────────────
class FaqSheet extends StatefulWidget {
  const FaqSheet({super.key});

  @override
  State<FaqSheet> createState() => _FaqSheetState();
}

class _FaqSheetState extends State<FaqSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  int? _expanded;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        height: mq.size.height * 0.82,
        decoration: const BoxDecoration(
          color: Color(0xFF1A2D5A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: kWhite.withOpacity(0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: kTeal.withOpacity(0.14),
                      shape: BoxShape.circle,
                      border: Border.all(color: kTeal.withOpacity(0.3), width: 1.5),
                    ),
                    child: const Icon(Icons.help_outline_rounded,
                        color: kTeal, size: 21),
                  ),
                  const SizedBox(width: 13),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('FAQ',
                          style: TextStyle(
                              color: kWhite,
                              fontSize: 17,
                              fontWeight: FontWeight.bold)),
                      Text('Frequently asked questions',
                          style: TextStyle(
                              color: kWhite.withOpacity(0.4), fontSize: 12)),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: kWhite.withOpacity(0.07),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close_rounded,
                          color: kWhite.withOpacity(0.5), size: 17),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Divider(height: 1, color: kWhite.withOpacity(0.07)),

            // FAQ list
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: _faqs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _FaqTile(
                  item: _faqs[i],
                  isExpanded: _expanded == i,
                  onTap: () =>
                      setState(() => _expanded = _expanded == i ? null : i),
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
// Tile
// ─────────────────────────────────────────────────────────────
class _FaqTile extends StatelessWidget {
  final _FaqItem item;
  final bool isExpanded;
  final VoidCallback onTap;

  const _FaqTile({
    required this.item,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isExpanded
            ? kTeal.withOpacity(0.07)
            : kWhite.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded
              ? kTeal.withOpacity(0.3)
              : kWhite.withOpacity(0.08),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isExpanded
                            ? kTeal.withOpacity(0.18)
                            : kWhite.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(item.icon,
                          size: 16,
                          color: isExpanded
                              ? kTeal
                              : kWhite.withOpacity(0.45)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.question,
                        style: TextStyle(
                          color: isExpanded ? kWhite : kWhite.withOpacity(0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: isExpanded
                            ? kTeal
                            : kWhite.withOpacity(0.3),
                        size: 20,
                      ),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 12, left: 44),
                    child: Text(
                      item.answer,
                      style: TextStyle(
                        color: kWhite.withOpacity(0.6),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                  crossFadeState: isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}