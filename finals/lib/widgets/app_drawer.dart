import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../models/space.dart';
import '../screens/login_screen.dart';
import '../store/auth_store.dart';
import '../store/space_store.dart';
import 'spaces/space_dialogs.dart';
import 'faq_sheet.dart';
import 'contact_support_sheet.dart';
import 'language_sheet.dart';
import 'reminder_settings_sheet.dart';
import 'class_alerts_sheet.dart';
import '../store/task_store.dart';
import '../store/space_chat_store.dart';
import 'change_password_sheet.dart';
import 'edit_profile_sheet.dart';


class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;
  late List<Animation<double>> _sectionFades;
  late List<Animation<Offset>> _sectionSlides;
  late Animation<double> _logoutFade;
  late Animation<Offset> _logoutSlide;

  List<Space> _pendingInvites = [];
  bool _invitesExpanded = true;
  bool _loadingInvites = true;

  final List<_DrawerSection> _sections = [
    _DrawerSection(title: 'Account', items: [
      _DrawerItem(icon: Icons.edit_outlined,            label: 'Edit Profile'),
      _DrawerItem(icon: Icons.key_outlined,              label: 'Change Password'),
      _DrawerItem(icon: Icons.manage_accounts_outlined,  label: 'Manage Account'),
    ]),
    _DrawerSection(title: 'Notifications', items: [
      _DrawerItem(icon: Icons.notifications_outlined,   label: 'Reminder Settings'),
      _DrawerItem(icon: Icons.info_outline,             label: 'Class Alerts'),
    ]),
    _DrawerSection(title: 'App Settings', items: [
      _DrawerItem(icon: Icons.dark_mode_outlined,       label: 'Dark Mode'),
      _DrawerItem(icon: Icons.language_outlined,        label: 'Language'),
    ]),
    _DrawerSection(title: 'Help & Support', items: [
      _DrawerItem(icon: Icons.help_outline_rounded,     label: 'FAQ'),
      _DrawerItem(icon: Icons.support_agent_outlined,   label: 'Contact Support'),
    ]),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _headerFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
    ));
    _headerSlide = Tween<Offset>(
            begin: const Offset(-0.3, 0), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
    ));

    // +1 for the Spaces section which is built separately
    final totalSections = _sections.length + 1;
    _sectionFades = List.generate(totalSections, (i) {
      final start = 0.2 + (i * 0.1);
      final end = (start + 0.25).clamp(0.0, 1.0);
      return Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _controller,
        curve: Interval(start, end, curve: Curves.easeOut),
      ));
    });

    _sectionSlides = List.generate(totalSections, (i) {
      final start = 0.2 + (i * 0.1);
      final end = (start + 0.25).clamp(0.0, 1.0);
      return Tween<Offset>(
              begin: const Offset(-0.2, 0), end: Offset.zero)
          .animate(CurvedAnimation(
        parent: _controller,
        curve: Interval(start, end, curve: Curves.easeOut),
      ));
    });

    _logoutFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.8, 1.0, curve: Curves.easeOut),
    ));
    _logoutSlide =
        Tween<Offset>(begin: const Offset(-0.2, 0), end: Offset.zero)
            .animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.8, 1.0, curve: Curves.easeOut),
    ));

    _controller.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInvites());
  }

  Future<void> _loadInvites() async {
    final invites = await SpaceStore.instance.getPendingInvites();
    // Bug 3 fix: the stored invite snapshot was written at invite-send time and
    // may have a stale creatorName if the creator renamed since then. Refresh
    // creatorName from the registry (which is always kept up-to-date by
    // renameUserInSpaces) so the "Invited by" label is always current.
    final enriched = await Future.wait(invites.map((invite) async {
      final fresh = await SpaceStore.instance.lookupByCode(invite.inviteCode);
      if (fresh == null || fresh.creatorName == invite.creatorName) return invite;
      return Space(
        name:           invite.name,
        description:    invite.description,
        dateRange:      invite.dateRange,
        dueDate:        invite.dueDate,
        members:        invite.members,
        pendingMembers: invite.pendingMembers,
        isCreator:      invite.isCreator,
        creatorName:    fresh.creatorName,
        status:         invite.status,
        statusColor:    invite.statusColor,
        accentColor:    invite.accentColor,
        progress:       invite.progress,
        completedTasks: invite.completedTasks,
        tasks:          invite.tasks,
        inviteCode:     invite.inviteCode,
      );
    }));
    if (mounted) setState(() { _pendingInvites = enriched; _loadingInvites = false; });
  }

  Future<void> _accept(Space invite) async {
    await SpaceStore.instance.acceptInvite(invite);
    if (mounted) setState(() => _pendingInvites.remove(invite));
  }

  Future<void> _decline(Space invite) async {
    await SpaceStore.instance.declineInvite(invite);
    if (mounted) setState(() => _pendingInvites.remove(invite));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Build the full section list: static sections + Spaces section inserted at index 3
    final allSectionWidgets = <Widget>[];
    for (int i = 0; i < _sections.length; i++) {
      // Insert Spaces section before Help & Support (last static section)
      if (i == _sections.length - 1) {
        allSectionWidgets.add(FadeTransition(
          opacity: _sectionFades[i],
          child: SlideTransition(
            position: _sectionSlides[i],
            child: _buildSpacesSection(),
          ),
        ));
      }
      allSectionWidgets.add(FadeTransition(
        opacity: _sectionFades[i == _sections.length - 1 ? i + 1 : i],
        child: SlideTransition(
          position: _sectionSlides[i == _sections.length - 1 ? i + 1 : i],
          child: _buildSection(_sections[i]),
        ),
      ));
    }

    return Drawer(
      backgroundColor: kTeal,
      width: MediaQuery.of(context).size.width * 0.78,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER ──────────────────────────────────
            FadeTransition(
              opacity: _headerFade,
              child: SlideTransition(
                position: _headerSlide,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: kWhite, width: 2.5),
                        ),
                        child: ClipOval(
                          child: Image.network(
                            'https://api.dicebear.com/7.x/bottts/png?seed=bunny',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.person,
                              color: kWhite,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AuthStore.instance.username.isNotEmpty
                                ? AuthStore.instance.username
                                : 'Unknown',
                            style: const TextStyle(
                                color: kWhite,
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          () {
                            final tag = AuthStore.instance.userTag;
                            if (tag.isNotEmpty) {
                              return Text(tag,
                                  style: const TextStyle(
                                      color: kWhite, fontSize: 12));
                            }
                            return const SizedBox.shrink();
                          }(),
                          Text(AuthStore.instance.displayEmail,
                              style:
                                  const TextStyle(color: kWhite, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
            Divider(
                color: kWhite.withOpacity(0.3),
                thickness: 1,
                indent: 20,
                endIndent: 20),
            const SizedBox(height: 8),

            // ── SCROLLABLE MENU ──────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                physics: const ClampingScrollPhysics(),
                children: allSectionWidgets,
              ),
            ),

            // ── LOGOUT ───────────────────────────────────
            Divider(
                color: kWhite.withOpacity(0.3),
                thickness: 1,
                indent: 20,
                endIndent: 20),
            FadeTransition(
              opacity: _logoutFade,
              child: SlideTransition(
                position: _logoutSlide,
                child: InkWell(
                  onTap: () async {
                    await AuthStore.instance.logout();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                            builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Row(
                      children: const [
                        Icon(Icons.logout_rounded,
                            color: kWhite, size: 22),
                        SizedBox(width: 12),
                        Text('Log Out',
                            style: TextStyle(
                                color: kWhite,
                                fontSize: 16,
                                fontWeight: FontWeight.w500)),
                      ],
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

  // ── Spaces section with live invite cards ────────────────
  Widget _buildSpacesSection() {
    final count = _pendingInvites.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spaces',
              style: const TextStyle(
                  color: kWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),

          // ── Invites row (expandable) ──────────────────
          InkWell(
            onTap: () => setState(() => _invitesExpanded = !_invitesExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  const Icon(Icons.mail_outline_rounded, color: kWhite, size: 20),
                  const SizedBox(width: 12),
                  Text('Invites',
                      style: TextStyle(
                          color: kWhite.withOpacity(0.9), fontSize: 14)),
                  if (count > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: kNavyDark,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$count',
                          style: const TextStyle(
                              color: kWhite,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                  const Spacer(),
                  Icon(
                    _invitesExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: kWhite.withOpacity(0.6),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),

          // ── Invite cards ─────────────────────────────
          if (_invitesExpanded) ...[
            if (_loadingInvites)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: kWhite.withOpacity(0.5),
                    ),
                  ),
                ),
              )
            else if (_pendingInvites.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 0, 8),
                child: Text('No pending invites',
                    style: TextStyle(
                        color: kWhite.withOpacity(0.45), fontSize: 12)),
              )
            else
              ...(_pendingInvites.map((invite) => _InviteCard(
                    invite: invite,
                    onAccept: () => _accept(invite),
                    onDecline: () => _decline(invite),
                  ))),
            const SizedBox(height: 4),
          ],

          // ── Join Space ────────────────────────────────
          _buildItem(_DrawerItem(
              icon: Icons.link_rounded,
              label: 'Join Space',
              onTap: () {
                Navigator.pop(context); // close drawer first
                showJoinSpaceDialog(
                  context,
                  isAlreadyJoined: (code) =>
                      SpaceStore.instance.spaces.any((s) => s.inviteCode == code),
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
              })),

          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildSection(_DrawerSection section) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section.title,
              style: const TextStyle(
                  color: kWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          ...section.items.map((item) => _buildItem(item)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildItem(_DrawerItem item) {
    VoidCallback? tap = item.onTap;
    if (tap == null && item.label == 'Edit Profile') {
  tap = () {
    Navigator.pop(context);
    showEditProfileSheet(context);
  };
}
    if (tap == null && item.label == 'Change Password') {
  tap = () {
    Navigator.pop(context);
    showChangePasswordSheet(context);
  };
}
    if (tap == null && item.label == 'FAQ') {
      tap = () {
        Navigator.pop(context);
        showFaqSheet(context);
      };
    }
    if (tap == null && item.label == 'Contact Support') {
      tap = () {
        Navigator.pop(context);
        showContactSupportSheet(context);
      };
    }
    if (tap == null && item.label == 'Language') {
      tap = () {
        Navigator.pop(context);
        showLanguageSheet(context);
      };
    }
    if (tap == null && item.label == 'Reminder Settings') {
      tap = () {
        Navigator.pop(context);
        showReminderSettingsSheet(context);
      };
    }
    if (tap == null && item.label == 'Class Alerts') {
      tap = () {
        Navigator.pop(context);
        showClassAlertsSheet(context);
      };
    }
    return InkWell(
      onTap: tap ?? () {},
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(item.icon, color: kWhite, size: 20),
            const SizedBox(width: 12),
            Text(item.label,
                style: TextStyle(
                    color: kWhite.withOpacity(0.9), fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Invite card
// ─────────────────────────────────────────────────────────────
class _InviteCard extends StatelessWidget {
  final Space invite;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _InviteCard({
    required this.invite,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kNavyDark.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: invite.accentColor.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Space name + accent dot
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: invite.accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  invite.name,
                  style: const TextStyle(
                      color: kWhite,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Invited by
          Text(
            'Invited by ${invite.creatorName}',
            style: TextStyle(
                color: kWhite.withOpacity(0.5), fontSize: 11),
          ),
          const SizedBox(height: 10),
          // Accept / Decline buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onDecline,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: kWhite.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text('Decline',
                          style: TextStyle(
                              color: kWhite.withOpacity(0.55),
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: onAccept,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: invite.accentColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text('Accept',
                          style: TextStyle(
                              color: kWhite,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DrawerSection {
  final String title;
  final List<_DrawerItem> items;
  const _DrawerSection({required this.title, required this.items});
}

class _DrawerItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _DrawerItem({required this.icon, required this.label, this.onTap});
}