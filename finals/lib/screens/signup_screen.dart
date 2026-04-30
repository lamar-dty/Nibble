import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/colors.dart';
import '../store/auth_store.dart';
import 'login_screen.dart';
import '../main.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _emailController    = TextEditingController();
  final _passController     = TextEditingController();

  bool _obscure  = true;
  bool _loading  = false;
  String? _error;

  // Per-field inline validation state.
  String? _usernameError;
  bool    _usernameAvailable = false;
  bool    _usernameDirty     = false; // true once user has typed at least once

  late AnimationController _entryController;
  late Animation<double>   _cardFade;
  late Animation<double>   _cardSlide;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _cardFade  = CurvedAnimation(parent: _entryController, curve: Curves.easeIn);
    _cardSlide = CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic);
    _entryController.forward();

    _usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _entryController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  // ── Live username validation ──────────────────────────────

  void _onUsernameChanged() {
    if (!mounted) return;
    final raw = _usernameController.text;
    if (!_usernameDirty && raw.isEmpty) return;
    _usernameDirty = true;

    final formatError = AuthStore.instance.validateUsernameInput(raw);
    if (formatError != null) {
      setState(() {
        _usernameError     = formatError;
        _usernameAvailable = false;
      });
      return;
    }

    final available = AuthStore.instance.isUsernameAvailable(raw);
    setState(() {
      _usernameError     = available ? null : 'That username is already taken.';
      _usernameAvailable = available;
    });
  }

  // ── Submit ────────────────────────────────────────────────

  Future<void> _createAccount() async {
    final username = _usernameController.text.trim();
    final email    = _emailController.text.trim();
    final pass     = _passController.text;

    // Force dirty and run validation synchronously so the inline
    // error state is correct before we read it below.
    setState(() {
      _usernameDirty = true;
      final formatError = AuthStore.instance.validateUsernameInput(username);
      if (formatError != null) {
        _usernameError     = formatError;
        _usernameAvailable = false;
      } else {
        final available = AuthStore.instance.isUsernameAvailable(username);
        _usernameError     = available ? null : 'That username is already taken.';
        _usernameAvailable = available;
      }
    });

    if (username.isEmpty || email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    final usernameFormatError = AuthStore.instance.validateUsernameInput(username);
    if (usernameFormatError != null) {
      setState(() => _error = usernameFormatError);
      return;
    }
    if (!AuthStore.instance.isUsernameAvailable(username)) {
      setState(() => _error = 'That username is already taken.');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    // Pass username as both `name` (legacy param) and `username` so the
    // store's backwards-compatibility path is never triggered.
    final err = await AuthStore.instance.signUp(
      name:     username,
      username: username,
      email:    email,
      password: pass,
    );

    if (!mounted) return;
    if (err != null) {
      setState(() { _loading = false; _error = err; });
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
      backgroundColor: kNavyDark,
      resizeToAvoidBottomInset: true,
      body: AnimatedBuilder(
        animation: _entryController,
        builder: (context, _) {
          return Stack(
            children: [
              // ── Rabbit peeks from top ─────────────────────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
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

              // ── White card ───────────────────────────────
              Positioned(
                top: size.height * 0.22 + (1 - _cardSlide.value) * 50,
                left: 20,
                right: 20,
                bottom: 0,
                child: Opacity(
                  opacity: _cardFade.value,
                  child: SingleChildScrollView(
                    child: _SignupCard(
                      usernameController: _usernameController,
                      emailController:    _emailController,
                      passController:     _passController,
                      obscure:            _obscure,
                      loading:            _loading,
                      error:              _error,
                      usernameError:      _usernameDirty ? _usernameError : null,
                      usernameAvailable:  _usernameDirty && _usernameAvailable,
                      onToggleObscure: () => setState(() => _obscure = !_obscure),
                      onCreate: _createAccount,
                      onLogin:  () => Navigator.of(context).pop(),
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
class _SignupCard extends StatelessWidget {
  final TextEditingController usernameController;
  final TextEditingController emailController;
  final TextEditingController passController;
  final bool    obscure;
  final bool    loading;
  final String? error;
  final String? usernameError;
  final bool    usernameAvailable;
  final VoidCallback onToggleObscure;
  final VoidCallback onCreate;
  final VoidCallback onLogin;

  const _SignupCard({
    required this.usernameController,
    required this.emailController,
    required this.passController,
    required this.obscure,
    required this.loading,
    required this.error,
    required this.usernameError,
    required this.usernameAvailable,
    required this.onToggleObscure,
    required this.onCreate,
    required this.onLogin,
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
          const Text(
            'Create your account',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: kNavyDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Manage your tasks and budget efficiently',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 22),

          // ── Username ──────────────────────────────────────
          _FieldLabel(label: 'Username'),
          const SizedBox(height: 6),
          _UsernameField(
            controller:  usernameController,
            error:       usernameError,
            isAvailable: usernameAvailable,
          ),
          if (usernameError != null) ...[
            const SizedBox(height: 5),
            _InlineMessage(message: usernameError!, isError: true),
          ] else if (usernameAvailable) ...[
            const SizedBox(height: 5),
            _InlineMessage(message: 'Username is available!', isError: false),
          ] else ...[
            const SizedBox(height: 5),
            const Text(
              'Lowercase letters, numbers, and underscores only · 3–20 chars',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
          const SizedBox(height: 14),

          // ── Email ─────────────────────────────────────────
          _FieldLabel(label: 'Email'),
          const SizedBox(height: 6),
          _AuthField(
            controller: emailController,
            hint: 'you@example.com',
            obscure: false,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),

          // ── Password ──────────────────────────────────────
          _FieldLabel(label: 'Password'),
          const SizedBox(height: 6),
          _AuthField(
            controller: passController,
            hint: 'At least 6 characters',
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
            Text(error!,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],

          const SizedBox(height: 20),

          // ── Create Account button ─────────────────────────
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: loading ? null : onCreate,
              style: ElevatedButton.styleFrom(
                backgroundColor: kTeal,
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
                      'Create Account',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // ── OR divider ────────────────────────────────────
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.shade300)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('or',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
              Expanded(child: Divider(color: Colors.grey.shade300)),
            ],
          ),

          const SizedBox(height: 16),

          // ── Social icons ──────────────────────────────────
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

          // ── Log in link ───────────────────────────────────
          Center(
            child: GestureDetector(
              onTap: onLogin,
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 13, color: kNavyDark),
                  children: [
                    const TextSpan(text: 'Already have an account? '),
                    const TextSpan(
                      text: 'Log In',
                      style: TextStyle(
                        color: kTeal,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                        decorationColor: kTeal,
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
// Username field — enforces lowercase input at the OS level
// and shows a trailing availability indicator.
// ─────────────────────────────────────────────────────────────
class _UsernameField extends StatelessWidget {
  final TextEditingController controller;
  final String? error;
  final bool    isAvailable;

  const _UsernameField({
    required this.controller,
    required this.error,
    required this.isAvailable,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    final borderColor = hasError
        ? Colors.red
        : isAvailable
            ? Colors.green
            : kTeal.withOpacity(0.3);
    final focusBorderColor =
        hasError ? Colors.red : isAvailable ? Colors.green : kTeal;

    Widget? trailing;
    if (controller.text.isNotEmpty) {
      if (hasError) {
        trailing = const Icon(Icons.cancel_outlined, size: 18, color: Colors.red);
      } else if (isAvailable) {
        trailing = const Icon(Icons.check_circle_outline,
            size: 18, color: Colors.green);
      }
    }

    return TextField(
      controller:  controller,
      // Force lowercase at the input level — never rely on the user.
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
        _LowercaseFormatter(),
      ],
      autocorrect: false,
      enableSuggestions: false,
      style: const TextStyle(fontSize: 14, color: kNavyDark),
      decoration: InputDecoration(
        hintText: 'e.g. jane_doe (lowercase letters)',
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixText: '@',
        prefixStyle: const TextStyle(
            color: kTeal, fontWeight: FontWeight.w600, fontSize: 14),
        filled:      true,
        fillColor:   const Color(0xFFEFF6F6),
        suffixIcon:  trailing,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: focusBorderColor, width: 1.5),
        ),
      ),
    );
  }
}

// Forces any typed character to lowercase before it reaches the field.
class _LowercaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toLowerCase());
  }
}

// ─────────────────────────────────────────────────────────────
// Shared field label
// ─────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
          fontWeight: FontWeight.w600, fontSize: 14, color: kNavyDark),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Inline validation message (error or success)
// ─────────────────────────────────────────────────────────────
class _InlineMessage extends StatelessWidget {
  final String message;
  final bool   isError;
  const _InlineMessage({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          isError ? Icons.error_outline : Icons.check_circle_outline,
          size: 13,
          color: isError ? Colors.red : Colors.green,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            message,
            style: TextStyle(
              fontSize: 11,
              color: isError ? Colors.red : Colors.green,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Reused auth field
// ─────────────────────────────────────────────────────────────
class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String  hint;
  final bool    obscure;
  final Widget? suffix;
  final TextInputType keyboardType;

  const _AuthField({
    required this.controller,
    required this.hint,
    required this.obscure,
    this.suffix,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller:   controller,
      obscureText:  obscure,
      keyboardType: keyboardType,
      autocorrect:  false,
      enableSuggestions: false,
      style: const TextStyle(fontSize: 14, color: kNavyDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        filled:    true,
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
          borderSide: BorderSide(color: kTeal.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kTeal, width: 1.5),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Social icons (same as login)
// ─────────────────────────────────────────────────────────────
enum _SocialIcon { facebook, google, x }

class _SocialButton extends StatelessWidget {
  final _SocialIcon icon;
  const _SocialButton({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width:  48,
      height: 48,
      decoration: BoxDecoration(
        color: icon == _SocialIcon.x ? Colors.black : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(0.10),
              blurRadius: 6,
              offset:     const Offset(0, 2))
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