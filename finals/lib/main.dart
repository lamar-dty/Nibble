import 'package:flutter/material.dart';
import 'constants/colors.dart';
import 'constants/app_colors.dart';
import 'screens/home_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/spaces_screen.dart';
import 'screens/wallet_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'widgets/app_drawer.dart';
import 'widgets/dashboard_appbar.dart';
import 'widgets/dashboard_bottom_nav.dart';
import 'store/theme_store.dart';
import 'store/task_store.dart';
import 'store/space_store.dart';
import 'store/space_chat_store.dart';
import 'store/auth_store.dart';
import 'store/wallet_store.dart';
import 'store/class_schedule_store.dart';
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
      // Pull latest shared patches on every login so renames, task updates,
      // and member changes made by other users are visible immediately.
      await SpaceStore.instance.syncFromSharedPatches();
      await SpaceChatStore.instance.reload(
        SpaceStore.instance.spaces.map((s) => s.inviteCode).toList(),
      );
      await WalletStore.instance.reload();
      await ClassScheduleStore.instance.reload(); // load schedules for logged-in user
    },
    onLogout: () async {
      await TaskStore.instance.reload();
      await SpaceStore.instance.reload();
      await SpaceChatStore.instance.reload([]);
      await WalletStore.instance.clear();
      await ClassScheduleStore.instance.clear(); // wipe schedules on logout
    },
  );

  // Load persisted data before showing any UI.
  await TaskStore.instance.load();
  await SpaceStore.instance.load();
  await SpaceChatStore.instance.load(
    SpaceStore.instance.spaces.map((s) => s.inviteCode).toList(),
  );
  await ClassScheduleStore.instance.load();

  await ThemeStore.instance.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeStore.instance,
      builder: (context, _) => MaterialApp(
        key: ValueKey(ThemeStore.instance.isDark),
        title: 'Nibble',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          scaffoldBackgroundColor: AppColors.bg,
          fontFamily: 'SF Pro Display',
          scrollbarTheme: const ScrollbarThemeData(),
          colorScheme: ColorScheme.dark(
            surface: AppColors.bg,
            background: AppColors.bg,
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: AppColors.bg,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
          ),
        ),
        scrollBehavior: const ScrollBehaviorNoGlow(),
        home: const SplashScreen(),
        routes: {
          '/login': (_) => const LoginScreen(),
          '/main': (_) => const MainScaffold(),
        },
      ),
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

  final ValueNotifier<int> _tabNotifier = ValueNotifier<int>(0);

  int _calStartHour = 6;
  int _calEndHour   = 22;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
    _tabNotifier.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      backgroundColor: AppColors.bg,
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