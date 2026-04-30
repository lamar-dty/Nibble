import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../screens/login_screen.dart';
import '../store/auth_store.dart';

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

  final List<_DrawerSection> _sections = const [
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
    _DrawerSection(title: 'Spaces', items: [
      _DrawerItem(icon: Icons.mail_outline_rounded,     label: 'Invites'),
      _DrawerItem(icon: Icons.link_rounded,             label: 'Join Space'),
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

    _sectionFades = List.generate(_sections.length, (i) {
      final start = 0.2 + (i * 0.1);
      final end = (start + 0.25).clamp(0.0, 1.0);
      return Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _controller,
        curve: Interval(start, end, curve: Curves.easeOut),
      ));
    });

    _sectionSlides = List.generate(_sections.length, (i) {
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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                          // Primary identity: username only.
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
                          // Secondary identity: Discord-style username#tag.
                          () {
                            final tag      = AuthStore.instance.userTag;
                            final username = AuthStore.instance.username;
                            if (username.isNotEmpty && tag.isNotEmpty) {
                              return Text(
                                '$username$tag',
                                style: const TextStyle(
                                    color: kWhite, fontSize: 12),
                              );
                            }
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
            // Key fix: Expanded + ListView with no shrinkWrap
            // so it scrolls naturally without stretching
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                physics: const ClampingScrollPhysics(),
                children: List.generate(_sections.length, (i) {
                  return FadeTransition(
                    opacity: _sectionFades[i],
                    child: SlideTransition(
                      position: _sectionSlides[i],
                      child: _buildSection(_sections[i]),
                    ),
                  );
                }),
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
    return InkWell(
      onTap: () {},
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

class _DrawerSection {
  final String title;
  final List<_DrawerItem> items;
  const _DrawerSection({required this.title, required this.items});
}

class _DrawerItem {
  final IconData icon;
  final String label;
  const _DrawerItem({required this.icon, required this.label});
}