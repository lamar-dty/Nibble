import 'package:flutter/material.dart';
import 'constants/colors.dart';
import 'screens/home_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/spaces_screen.dart';
import 'screens/wallet_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'widgets/app_drawer.dart';
import 'widgets/dashboard_appbar.dart';
import 'widgets/dashboard_bottom_nav.dart';
import 'store/task_store.dart';
import 'store/space_store.dart';
import 'store/space_chat_store.dart';
import 'store/auth_store.dart';
import 'services/notification_router.dart';

class ScrollBehaviorNoGlow extends ScrollBehavior {
  const ScrollBehaviorNoGlow();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
  @override
  Widget buildOverscrollIndicator(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load auth first so we know if there's an active session.
  await AuthStore.instance.load();

  // Register callbacks so AuthStore can reload/clear stores on login & logout
  // without creating a circular import.
  AuthStore.instance.registerStoreCallbacks(
    onLogin: () async {
      await TaskStore.instance.reload();
      await SpaceStore.instance.reload();
      await SpaceChatStore.instance.reload(
        SpaceStore.instance.spaces.map((s) => s.inviteCode).toList(),
      );
    },
    onLogout: () async {
      await TaskStore.instance.reload();
      await SpaceStore.instance.reload();
      await SpaceChatStore.instance.reload([]);
    },
  );

  // Load persisted data before showing any UI.
  await TaskStore.instance.load();
  await SpaceStore.instance.load();
  // Chat messages are keyed per space; load for all already-persisted spaces.
  await SpaceChatStore.instance.load(
    SpaceStore.instance.spaces.map((s) => s.inviteCode).toList(),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nibble',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: kNavyDark,
        fontFamily: 'SF Pro Display',
        scrollbarTheme: const ScrollbarThemeData(),
      ),
      scrollBehavior: const ScrollBehaviorNoGlow(),
      home: const SplashScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/main': (_) => const MainScaffold(),
      },
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<SpacesScreenState> _spacesKey = GlobalKey<SpacesScreenState>();

  // Notifies all tab screens whenever the active tab changes so each
  // screen can collapse its DraggableScrollableSheet.  Using a
  // ValueNotifier<int> (the newly-selected index) keeps screens fully
  // decoupled from MainScaffold — no GlobalKey or public State method needed.
  final ValueNotifier<int> _tabNotifier = ValueNotifier<int>(0);

  // ── Persisted calendar time range ────────────────────────
  int _calStartHour = 6;
  int _calEndHour   = 22;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // Register the tab switcher so NotificationRouter can switch tabs
    // from a notification tap without knowing MainScaffold's internals.
    NotificationRouter.instance.registerTabSwitcher((index) {
      if (mounted) {
        setState(() => _selectedIndex = index);
        _tabNotifier.value = index;
      }
    });
    _pages = [
      HomeScreen(tabNotifier: _tabNotifier),
      CalendarScreen(
        calStartHour: _calStartHour,
        calEndHour: _calEndHour,
        onRangeChanged: (s, e) => setState(() {
          _calStartHour = s;
          _calEndHour   = e;
        }),
        tabNotifier: _tabNotifier,
      ),
      SpacesScreen(key: _spacesKey, tabNotifier: _tabNotifier),
      WalletScreen(tabNotifier: _tabNotifier),
    ];
  }

  @override
  void dispose() {
    NotificationRouter.instance.unregisterTabSwitcher();
    _tabNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      backgroundColor: kNavyDark,
      appBar: DashboardAppBar(
        onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      drawer: const AppDrawer(),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: MediaQuery(
        data: MediaQuery.of(context).copyWith(padding: EdgeInsets.zero),
        child: DashboardBottomNav(
          selectedIndex: _selectedIndex,
          onTap: (i) {
            setState(() => _selectedIndex = i);
            _tabNotifier.value = i;
            // Drain inbox + deletion notices every time the home tab is
            // opened so spaceDeleted alerts appear regardless of which tab
            // the user visits first.
            if (i == 0) {
              TaskStore.instance.drainSharedInbox();
              SpaceStore.instance.drainDeletionNotices().then((removed) {
                for (final code in removed) {
                  SpaceChatStore.instance.deleteMessagesFor(code);
                  TaskStore.instance.clearSpaceNotifications(code);
                }
                if (removed.isNotEmpty) setState(() {});
              });
            }
          },
        ),
      ),
      floatingActionButton: DashboardFAB(
        onNavigateToCalendar: () => setState(() => _selectedIndex = 1),
        onNavigateToSpaces: () => setState(() => _selectedIndex = 2),
        onSpaceSaved: (result) {
          _spacesKey.currentState?.addSpace(result);
          setState(() => _selectedIndex = 2);
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}