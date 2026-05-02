import 'package:flutter/material.dart';
import '../constants/colors.dart';

// ─────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────
void showReminderSettingsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    enableDrag: true,
    builder: (_) => const ReminderSettingsSheet(),
  );
}

// ─────────────────────────────────────────────────────────────
// Sheet
// ─────────────────────────────────────────────────────────────
class ReminderSettingsSheet extends StatefulWidget {
  const ReminderSettingsSheet({super.key});

  @override
  State<ReminderSettingsSheet> createState() => _ReminderSettingsSheetState();
}

class _ReminderSettingsSheetState extends State<ReminderSettingsSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // ── Placeholder state ──────────────────────────────────────
  bool _taskDeadlines     = true;
  bool _spaceUpdates      = true;
  bool _memberActivity    = false;
  bool _dailySummary      = false;
  bool _chatMessages      = true;
  bool _walletActivity    = false;

  int _reminderLeadIndex  = 1; // 0=15m, 1=30m, 2=1h, 3=1d
  int _quietStart         = 22; // 10 PM
  int _quietEnd           = 7;  // 7 AM
  bool _quietHours        = false;

  static const _leadOptions = ['15 min', '30 min', '1 hour', '1 day'];

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

  String _fmtHour(int h) {
    final period = h >= 12 ? 'PM' : 'AM';
    final hour   = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$hour:00 $period';
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        height: mq.size.height * 0.88,
        decoration: const BoxDecoration(
          color: Color(0xFF1A2D5A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              width: 36, height: 4,
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
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8A870).withOpacity(0.14),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFFE8A870).withOpacity(0.3),
                          width: 1.5),
                    ),
                    child: const Icon(Icons.notifications_active_rounded,
                        color: Color(0xFFE8A870), size: 21),
                  ),
                  const SizedBox(width: 13),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Reminder Settings',
                          style: TextStyle(
                              color: kWhite,
                              fontSize: 17,
                              fontWeight: FontWeight.bold)),
                      Text('Manage your notification preferences',
                          style: TextStyle(
                              color: kWhite.withOpacity(0.4), fontSize: 12)),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32, height: 32,
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

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Notify Me About ──────────────────────
                    _SectionLabel(label: 'NOTIFY ME ABOUT'),
                    const SizedBox(height: 10),
                    _SettingsCard(children: [
                      _ToggleTile(
                        icon: Icons.task_alt_rounded,
                        iconColor: kTeal,
                        title: 'Task Deadlines',
                        subtitle: 'Get reminded before tasks are due',
                        value: _taskDeadlines,
                        onChanged: (v) => setState(() => _taskDeadlines = v),
                      ),
                      _Divider(),
                      _ToggleTile(
                        icon: Icons.workspaces_rounded,
                        iconColor: const Color(0xFF9B88E8),
                        title: 'Space Updates',
                        subtitle: 'Status changes and new members',
                        value: _spaceUpdates,
                        onChanged: (v) => setState(() => _spaceUpdates = v),
                      ),
                      _Divider(),
                      _ToggleTile(
                        icon: Icons.people_rounded,
                        iconColor: const Color(0xFF4A90D9),
                        title: 'Member Activity',
                        subtitle: 'When members complete tasks',
                        value: _memberActivity,
                        onChanged: (v) => setState(() => _memberActivity = v),
                      ),
                      _Divider(),
                      _ToggleTile(
                        icon: Icons.chat_bubble_rounded,
                        iconColor: const Color(0xFF3BBFA3),
                        title: 'Chat Messages',
                        subtitle: 'New messages in your spaces',
                        value: _chatMessages,
                        onChanged: (v) => setState(() => _chatMessages = v),
                      ),
                      _Divider(),
                      _ToggleTile(
                        icon: Icons.account_balance_wallet_rounded,
                        iconColor: const Color(0xFFE8D870),
                        title: 'Wallet Activity',
                        subtitle: 'New entries and expense updates',
                        value: _walletActivity,
                        onChanged: (v) => setState(() => _walletActivity = v),
                      ),
                      _Divider(),
                      _ToggleTile(
                        icon: Icons.wb_sunny_rounded,
                        iconColor: const Color(0xFFE8A870),
                        title: 'Daily Summary',
                        subtitle: 'Morning digest of your tasks',
                        value: _dailySummary,
                        onChanged: (v) => setState(() => _dailySummary = v),
                      ),
                    ]),

                    const SizedBox(height: 20),

                    // ── Reminder Lead Time ───────────────────
                    _SectionLabel(label: 'REMIND ME'),
                    const SizedBox(height: 10),
                    _SettingsCard(children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.timer_rounded,
                                  color: kTeal, size: 16),
                              const SizedBox(width: 8),
                              const Text('Before deadline',
                                  style: TextStyle(
                                      color: kWhite,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            ]),
                            const SizedBox(height: 12),
                            Row(
                              children: List.generate(_leadOptions.length, (i) {
                                final selected = i == _reminderLeadIndex;
                                return Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(
                                        () => _reminderLeadIndex = i),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 160),
                                      margin: EdgeInsets.only(
                                          right: i < _leadOptions.length - 1
                                              ? 8
                                              : 0),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 9),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? kTeal.withOpacity(0.18)
                                            : kWhite.withOpacity(0.05),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        border: Border.all(
                                          color: selected
                                              ? kTeal.withOpacity(0.5)
                                              : kWhite.withOpacity(0.08),
                                        ),
                                      ),
                                      child: Text(
                                        _leadOptions[i],
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: selected
                                              ? kTeal
                                              : kWhite.withOpacity(0.45),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    ]),

                    const SizedBox(height: 20),

                    // ── Quiet Hours ──────────────────────────
                    _SectionLabel(label: 'QUIET HOURS'),
                    const SizedBox(height: 10),
                    _SettingsCard(children: [
                      _ToggleTile(
                        icon: Icons.bedtime_rounded,
                        iconColor: const Color(0xFF9B88E8),
                        title: 'Enable Quiet Hours',
                        subtitle: 'Silence notifications during set hours',
                        value: _quietHours,
                        onChanged: (v) => setState(() => _quietHours = v),
                      ),
                      if (_quietHours) ...[
                        _Divider(),
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          child: Row(children: [
                            Expanded(
                              child: _TimeSelector(
                                label: 'FROM',
                                value: _fmtHour(_quietStart),
                                accent: const Color(0xFF9B88E8),
                                onTap: () async {
                                  final h = await _pickHour(
                                      context, _quietStart);
                                  if (h != null)
                                    setState(() => _quietStart = h);
                                },
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: Text('to',
                                  style: TextStyle(
                                      color: kWhite.withOpacity(0.3),
                                      fontSize: 13)),
                            ),
                            Expanded(
                              child: _TimeSelector(
                                label: 'UNTIL',
                                value: _fmtHour(_quietEnd),
                                accent: const Color(0xFF9B88E8),
                                onTap: () async {
                                  final h =
                                      await _pickHour(context, _quietEnd);
                                  if (h != null)
                                    setState(() => _quietEnd = h);
                                },
                              ),
                            ),
                          ]),
                        ),
                      ],
                    ]),

                    const SizedBox(height: 20),

                    // Coming soon note
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: kWhite.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: kWhite.withOpacity(0.07)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: kWhite.withOpacity(0.3), size: 15),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'These settings are a preview. Full notification control will be available in the next update.',
                              style: TextStyle(
                                color: kWhite.withOpacity(0.4),
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer save button
            Divider(height: 1, color: kWhite.withOpacity(0.07)),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + mq.padding.bottom),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFE8A870),
                        const Color(0xFFE8A870).withOpacity(0.75)
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFFE8A870).withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pop(context),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text('Save Settings',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
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
// Hour picker helper
// ─────────────────────────────────────────────────────────────
Future<int?> _pickHour(BuildContext context, int current) async {
  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: current, minute: 0),
    builder: (ctx, child) => MediaQuery(
      data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: false),
      child: child!,
    ),
  );
  return picked?.hour;
}

// ─────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(label,
          style: TextStyle(
              color: kWhite.withOpacity(0.35),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2)),
    ]);
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kWhite.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kWhite.withOpacity(0.08)),
      ),
      child: Column(children: children),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: kWhite,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        color: kWhite.withOpacity(0.4), fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: kTeal,
            activeTrackColor: kTeal.withOpacity(0.25),
            inactiveThumbColor: kWhite.withOpacity(0.3),
            inactiveTrackColor: kWhite.withOpacity(0.08),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, color: kWhite.withOpacity(0.06), indent: 14, endIndent: 14);
}

class _TimeSelector extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  final VoidCallback onTap;

  const _TimeSelector({
    required this.label,
    required this.value,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.09),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: accent.withOpacity(0.6),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
            const SizedBox(height: 3),
            Row(children: [
              Icon(Icons.access_time_rounded,
                  size: 12, color: accent.withOpacity(0.7)),
              const SizedBox(width: 5),
              Text(value,
                  style: TextStyle(
                      color: accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ]),
          ],
        ),
      ),
    );
  }
}