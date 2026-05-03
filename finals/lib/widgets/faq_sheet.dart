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
  // ── Account ───────────────────────────────────────────────
  _FaqItem(
    icon: Icons.person_rounded,
    question: 'Where do I find my User ID?',
    answer:
        'Your #ID is shown in the app drawer at the top of the screen, just below your username. Share it with others so they can add you as a member to their spaces.',
  ),
  _FaqItem(
    icon: Icons.edit_rounded,
    question: 'How do I change my username?',
    answer:
        'Open the app drawer and tap Edit Profile under the Account section. Type your new username — it must be 3–20 characters and can only contain lowercase letters, numbers, and underscores. Your username is your public identity across all spaces and tasks.',
  ),
  _FaqItem(
    icon: Icons.key_rounded,
    question: 'How do I change my password?',
    answer:
        'Go to the app drawer and tap Change Password. Enter your current password to verify, then type your new password. It must be at least 6 characters.',
  ),
  _FaqItem(
    icon: Icons.face_rounded,
    question: 'How do I change my avatar?',
    answer:
        'Open the app drawer and tap Manage Account. You\'ll see a grid of 12 preset avatars — tap one to preview it, then tap Save Avatar. Your avatar updates instantly everywhere in the app, including the home screen top bar and the drawer.',
  ),

  // ── Spaces ────────────────────────────────────────────────
  _FaqItem(
    icon: Icons.workspaces_rounded,
    question: 'How do I create a Space?',
    answer:
        'Tap the + button on the Spaces screen. Fill in the space name, description, accent color, and timeline (date range and due date). Once created, you can invite members, add tasks, and chat directly from inside the space.',
  ),
  _FaqItem(
    icon: Icons.link_rounded,
    question: 'How do I invite someone to my Space?',
    answer:
        'Open the space and tap Add Member. Enter the user\'s #ID (found in their app drawer) or share your space\'s invite code so others can join themselves. Only the space creator can add members.',
  ),
  _FaqItem(
    icon: Icons.login_rounded,
    question: 'How do I join a Space I was invited to?',
    answer:
        'You can join from the app drawer under Spaces → Join Space, or from the Spaces screen. Enter the invite code shared by the creator. Pending invites also appear in your app drawer where you can Accept or Decline.',
  ),
  _FaqItem(
    icon: Icons.manage_accounts_rounded,
    question: 'Can I kick a member or delete my Space?',
    answer:
        'Yes — both are creator-only actions. Open the space and tap the trash icon in the top bar to delete it. To remove a member, tap their name in the Members section and choose Kick. Deleted spaces are removed for all members and a notification is sent to them.',
  ),
  _FaqItem(
    icon: Icons.exit_to_app_rounded,
    question: 'How do I leave a Space I joined?',
    answer:
        'Open the space and tap the exit icon in the top bar. Confirm the prompt and you\'ll be removed from the space. The creator is notified that you left.',
  ),

  // ── Tasks ─────────────────────────────────────────────────
  _FaqItem(
    icon: Icons.task_alt_rounded,
    question: 'How do I add and manage tasks in a Space?',
    answer:
        'Open the space and tap the + button in the Tasks section (creator only). Set the title, note, due date, and assign it to a member. Tasks can be reordered by dragging. Tap a task to edit its title, update its status, or reassign it.',
  ),
  _FaqItem(
    icon: Icons.swap_horiz_rounded,
    question: 'How does task status work?',
    answer:
        'Each task cycles through three statuses: To Do → In Progress → Completed. Tap the status badge inside a task to advance it. The space progress bar updates automatically based on how many tasks are completed.',
  ),

  // ── Chat ──────────────────────────────────────────────────
  _FaqItem(
    icon: Icons.chat_bubble_outline_rounded,
    question: 'How do I use Space Chat?',
    answer:
        'Every space has a built-in chat. Open the space and tap the chat bubble button. Type your message and tap send. System messages appear automatically when members join, leave, or are removed. Unread messages show a badge on the space card.',
  ),

  // ── Calendar ──────────────────────────────────────────────
  _FaqItem(
    icon: Icons.calendar_month_rounded,
    question: 'How does the Calendar work?',
    answer:
        'The Calendar shows all your personal tasks and events in a weekly planner view. Tap any day to see what\'s scheduled. Tasks with due dates appear automatically. You can also create standalone events from the calendar.',
  ),

  // ── Wallet ────────────────────────────────────────────────
  _FaqItem(
    icon: Icons.account_balance_wallet_rounded,
    question: 'What is the Wallet for?',
    answer:
        'The Wallet helps you track personal finances. Log expenses across five categories — Food, Transport, School, Health, and Other — and set a daily allowance. The home screen shows your current wallet balance and remaining daily budget.',
  ),
  _FaqItem(
    icon: Icons.savings_rounded,
    question: 'How does the Savings feature work?',
    answer:
        'Inside the Wallet you can add to or withdraw from a savings total. Each transaction is recorded in a Savings Log so you can track your history. The home screen stat card shows your current savings balance.',
  ),
  _FaqItem(
    icon: Icons.sort_rounded,
    question: 'Can I sort or filter my expenses?',
    answer:
        'Yes — in the Wallet you can sort expenses by due date, amount, status, or category. Expenses are grouped into Upcoming and Recent sections so it\'s easy to see what needs attention.',
  ),

  // ── Notifications ─────────────────────────────────────────
  _FaqItem(
    icon: Icons.notifications_rounded,
    question: 'What kinds of notifications does the app send?',
    answer:
        'The app notifies you about task deadlines, space updates (new members, status changes), member activity (task completions), new chat messages, wallet activity, and a daily morning summary. You can control all of these in Reminder Settings.',
  ),
  _FaqItem(
    icon: Icons.tune_rounded,
    question: 'How do I configure Reminder Settings?',
    answer:
        'Open the app drawer and tap Reminder Settings. Toggle each notification type on or off, choose how far in advance to be reminded before deadlines (15 min, 30 min, 1 hour, or 1 day), and optionally set a Quiet Hours window so you aren\'t disturbed at night.',
  ),

  // ── Class Alerts ──────────────────────────────────────────
  _FaqItem(
    icon: Icons.school_rounded,
    question: 'What are Class Alerts?',
    answer:
        'Class Alerts let you set up a weekly class schedule with reminders. Open the app drawer and tap Class Alerts. Add each class with its name, room, days, time, and how many minutes before class you want to be reminded. Classes can be removed anytime.',
  ),

  // ── App Settings ──────────────────────────────────────────
  _FaqItem(
    icon: Icons.language_rounded,
    question: 'Can I change the app language?',
    answer:
        'Open the app drawer and tap Language under App Settings. Currently English is available. More languages will be added in a future update.',
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