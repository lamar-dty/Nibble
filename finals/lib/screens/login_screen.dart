import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/colors.dart';
import '../store/auth_store.dart';
import 'signup_screen.dart';
import '../main.dart';
import '../constants/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _identifierController = TextEditingController();
  final _passController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  String? _identifierError;

  late AnimationController _entryController;
  late Animation<double> _rabbitSlide;
  late Animation<double> _cardSlide;
  late Animation<double> _cardFade;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _rabbitSlide = CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack));
    _cardSlide = CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic));
    _cardFade = CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn));
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _identifierController.dispose();
    _passController.dispose();
    super.dispose();
  }

  /// Returns true if [value] looks like an email address.
  bool _looksLikeEmail(String value) => value.contains('@');

  /// Validates the identifier field. Returns an error string or null.
  String? _validateIdentifier(String value) {
    if (value.isEmpty) return 'Please enter your email or username.';
    if (_looksLikeEmail(value)) return null; // defer email validation to server
    // Username rules: lowercase, letters/numbers/underscore, 3-20 chars.
    final usernameRegex = RegExp(r'^[a-z0-9_]{3,20}$');
    if (!usernameRegex.hasMatch(value)) {
      if (value.length < 3) return 'Username must be at least 3 characters.';
      if (value.length > 20) return 'Username must be 20 characters or fewer.';
      return 'Username may only contain lowercase letters, numbers, and underscores.';
    }
    return null;
  }

  void _onIdentifierChanged(String value) {
    // Auto-lowercase when the user types a username (no @).
    if (!_looksLikeEmail(value)) {
      final lowered = value.toLowerCase();
      if (lowered != value) {
        _identifierController.value = _identifierController.value.copyWith(
          text: lowered,
          selection: TextSelection.collapsed(offset: lowered.length),
        );
      }
    }
    // Clear field-level error on change.
    if (_identifierError != null) {
      setState(() => _identifierError = null);
    }
  }

  Future<void> _login() async {
    final raw = _identifierController.text.trim();
    final identifier =
        _looksLikeEmail(raw) ? raw : raw.toLowerCase();
    final pass = _passController.text;

    // Local validation.
    final idErr = _validateIdentifier(identifier);
    if (idErr != null) {
      setState(() {
        _identifierError = idErr;
        _error = null;
      });
      return;
    }
    if (pass.isEmpty) {
      setState(() {
        _error = 'Please enter your password.';
        _identifierError = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _identifierError = null;
    });

    final err = await AuthStore.instance.login(
      identifier: identifier,
      password: pass,
    );

    if (!mounted) return;

    if (err != null) {
      setState(() {
        _loading = false;
        _error = err;
      });
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScaffold()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.bg,
      resizeToAvoidBottomInset: true,
      body: AnimatedBuilder(
        animation: _entryController,
        builder: (context, _) {
          return Stack(
            children: [
              // ── Rabbit peeks from top ──────────────────────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Transform.translate(
                  offset: Offset(0, (1 - _rabbitSlide.value) * -120),
                  child: SizedBox(
                    height: size.height * 0.22,
                    child: ClipRect(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        heightFactor: 0.6,
                        child: Image.asset(
                          'assets/images/login.png',
                          fit: BoxFit.fitWidth,
                          width: size.width * 0.30,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── White card slides up ───────────────────────
              Positioned(
                top: size.height * 0.22 + (1 - _cardSlide.value) * 60,
                left: 20,
                right: 20,
                child: Opacity(
                  opacity: _cardFade.value,
                  child: _LoginCard(
                    identifierController: _identifierController,
                    passController: _passController,
                    obscure: _obscure,
                    loading: _loading,
                    error: _error,
                    identifierError: _identifierError,
                    onIdentifierChanged: _onIdentifierChanged,
                    onToggleObscure: () =>
                        setState(() => _obscure = !_obscure),
                    onLogin: _login,
                    onSignUp: () => Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (_, a, __) => const SignupScreen(),
                        transitionsBuilder: (_, anim, __, child) =>
                            FadeTransition(opacity: anim, child: child),
                        transitionDuration: const Duration(milliseconds: 300),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
class _LoginCard extends StatelessWidget {
  final TextEditingController identifierController;
  final TextEditingController passController;
  final bool obscure;
  final bool loading;
  final String? error;
  final String? identifierError;
  final ValueChanged<String> onIdentifierChanged;
  final VoidCallback onToggleObscure;
  final VoidCallback onLogin;
  final VoidCallback onSignUp;

  const _LoginCard({
    required this.identifierController,
    required this.passController,
    required this.obscure,
    required this.loading,
    required this.error,
    required this.identifierError,
    required this.onIdentifierChanged,
    required this.onToggleObscure,
    required this.onLogin,
    required this.onSignUp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'Welcome back',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.bg,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Sign in to continue to Nibble',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),

          // Username or Email
          Text(
            'Username or Email',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.bg),
          ),
          const SizedBox(height: 6),
          _AuthField(
            controller: identifierController,
            hint: '@username or email',
            obscure: false,
            errorText: identifierError,
            onChanged: onIdentifierChanged,
            inputFormatters: [
              // Strip leading whitespace on-the-fly.
              FilteringTextInputFormatter.deny(RegExp(r'^\s')),
            ],
          ),
          const SizedBox(height: 16),

          // Password
          Text(
            'Password',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.bg),
          ),
          const SizedBox(height: 6),
          _AuthField(
            controller: passController,
            hint: 'Password',
            obscure: obscure,
            suffix: IconButton(
              icon: Icon(
                obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
                color: Colors.grey,
              ),
              onPressed: onToggleObscure,
            ),
          ),

          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],

          const SizedBox(height: 20),

          // Login button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: loading ? null : onLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text(
                      'Log in',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 20),

          // Social icons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SocialButton(icon: _SocialIcon.facebook),
              const SizedBox(width: 16),
              _SocialButton(icon: _SocialIcon.google),
              const SizedBox(width: 16),
              _SocialButton(icon: _SocialIcon.x),
            ],
          ),

          const SizedBox(height: 18),

          // Sign up link
          Center(
            child: GestureDetector(
              onTap: onSignUp,
              child: RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 13, color: AppColors.bg),
                  children: [
                    const TextSpan(text: "Need an account? "),
                    TextSpan(
                      text: 'Sign Up',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shared auth text field
// ─────────────────────────────────────────────────────────────
class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final Widget? suffix;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;

  const _AuthField({
    required this.controller,
    required this.hint,
    required this.obscure,
    this.suffix,
    this.errorText,
    this.onChanged,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          obscureText: obscure,
          onChanged: onChanged,
          inputFormatters: inputFormatters,
          autocorrect: false,
          enableSuggestions: false,
          style: TextStyle(fontSize: 14, color: AppColors.bg),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            filled: true,
            fillColor: const Color(0xFFEFF6F6),
            suffixIcon: suffix,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: errorText != null
                    ? Colors.red.shade300
                    : AppColors.accent.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: errorText != null ? Colors.red : AppColors.accent,
                width: 1.5,
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: const TextStyle(color: Colors.red, fontSize: 11),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Social icons
// ─────────────────────────────────────────────────────────────
enum _SocialIcon { facebook, google, x }

class _SocialButton extends StatelessWidget {
  final _SocialIcon icon;
  const _SocialButton({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: icon == _SocialIcon.x ? Colors.black : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Center(child: _iconWidget()),
    );
  }

  Widget _iconWidget() {
    switch (icon) {
      case _SocialIcon.facebook:
        return const Icon(Icons.facebook, color: Color(0xFF1877F2), size: 26);
      case _SocialIcon.google:
        return const Text('G',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFFEA4335)));
      case _SocialIcon.x:
        return const Text('𝕏',
            style: TextStyle(fontSize: 20, color: Colors.white));
    }
  }
}