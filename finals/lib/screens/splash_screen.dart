import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../store/auth_store.dart';
import 'login_screen.dart';
import '../main.dart';
import '../constants/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _arcController;
  late AnimationController _rabbitController;
  late AnimationController _textController;
  late AnimationController _fadeOutController;

  late Animation<double> _arcScale;
  late Animation<double> _rabbitSlide;
  late Animation<double> _textFade;
  late Animation<double> _fadeOut;

  @override
  void initState() {
    super.initState();

    // Arc/white bubble scales up
    _arcController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _arcScale = CurvedAnimation(parent: _arcController, curve: Curves.easeOutBack);

    // Rabbit bounces up from bottom
    _rabbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _rabbitSlide = CurvedAnimation(parent: _rabbitController, curve: Curves.easeOutBack);

    // Text fades in
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _textFade = CurvedAnimation(parent: _textController, curve: Curves.easeIn);

    // Whole screen fades out before navigation
    _fadeOutController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeOut = CurvedAnimation(parent: _fadeOutController, curve: Curves.easeIn);

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _arcController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _rabbitController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _textController.forward();
    // Hold for a moment then fade out
    await Future.delayed(const Duration(milliseconds: 1800));
    await _fadeOutController.forward();
    if (mounted) {
      if (AuthStore.instance.isLoggedIn) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainScaffold()),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const LoginScreen(),
            transitionDuration: Duration.zero,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _arcController.dispose();
    _rabbitController.dispose();
    _textController.dispose();
    _fadeOutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: _fadeOutController,
      builder: (context, child) => Opacity(
        opacity: 1.0 - _fadeOut.value,
        child: child,
      ),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Stack(
          children: [
            // ── White arc bubble (bottom half) ──────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _arcScale,
                builder: (_, __) => Transform.scale(
                  scale: _arcScale.value,
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    height: size.height * 0.55,
                    child: CustomPaint(
                      painter: _ArcPainter(),
                      size: Size(size.width, size.height * 0.55),
                    ),
                  ),
                ),
              ),
            ),

            // ── Nibble text + subtitle ───────────────────────
            Positioned(
              bottom: size.height * 0.32,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _textFade,
                builder: (_, __) => Opacity(
                  opacity: _textFade.value,
                  child: Column(
                    children: [
                      Text(
                        'Nibble',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontStyle: FontStyle.italic,
                          fontSize: 52,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'A student life management app.',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.icon,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Big rabbit (bottom) ──────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _rabbitSlide,
                builder: (_, __) {
                  final slideOffset = (1 - _rabbitSlide.value) * size.height * 0.4;
                  return Transform.translate(
                    offset: Offset(0, slideOffset),
                    child: SizedBox(
                      height: size.height * 0.28,
                      child: Image.asset(
                        'assets/images/main.png',
                        fit: BoxFit.contain,
                        alignment: Alignment.bottomCenter,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── White arch background ──────────────────────────────────────
class _ArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.lightFill;
    final path = Path();
    path.moveTo(0, size.height * 0.25);
    path.quadraticBezierTo(size.width / 2, -size.height * 0.05, size.width, size.height * 0.25);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => true;
}