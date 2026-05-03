import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../store/auth_store.dart';

// ─────────────────────────────────────────────────────────────
// Entry point  (matches the pattern used by language_sheet,
// reminder_settings_sheet, faq_sheet, etc.)
// ─────────────────────────────────────────────────────────────
void showChangePasswordSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    enableDrag: true,
    builder: (_) => const ChangePasswordSheet(),
  );
}

// ─────────────────────────────────────────────────────────────
// Sheet
// ─────────────────────────────────────────────────────────────
class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key});

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet>
    with SingleTickerProviderStateMixin {
  // ── animation ──────────────────────────────────────────────
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // ── form ───────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl     = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _showCurrent = false;
  bool _showNew     = false;
  bool _showConfirm = false;
  bool _saving      = false;
  String? _errorBanner;

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
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── submit ─────────────────────────────────────────────────
  Future<void> _submit() async {
    setState(() => _errorBanner = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final error = await AuthStore.instance.changePassword(
      currentPassword: _currentCtrl.text,
      newPassword:     _newCtrl.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      setState(() => _errorBanner = error);
      return;
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF1A2A5E),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12))),
        duration: Duration(seconds: 3),
        content: Text(
          'Password updated successfully.',
          style: TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
    );
  }

  // ── build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return FadeTransition(
      opacity: _fadeAnim,
      child: Padding(
        // Slide up when the keyboard appears
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A2D5A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(24, 20, 24, mq.padding.bottom + 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── drag handle ──────────────────────────
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: kWhite.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── title ────────────────────────────────
                const Text(
                  'Change Password',
                  style: TextStyle(
                    color: kWhite,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enter your current password, then choose a new one.',
                  style: TextStyle(color: kWhite.withOpacity(0.55), fontSize: 13),
                ),
                const SizedBox(height: 24),

                // ── error banner ─────────────────────────
                if (_errorBanner != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.45)),
                    ),
                    child: Text(
                      _errorBanner!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                    ),
                  ),
                ],

                // ── current password ─────────────────────
                _PasswordField(
                  controller: _currentCtrl,
                  label: 'Current password',
                  visible: _showCurrent,
                  onToggle: () => setState(() => _showCurrent = !_showCurrent),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter your current password.';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // ── new password ─────────────────────────
                _PasswordField(
                  controller: _newCtrl,
                  label: 'New password',
                  visible: _showNew,
                  onToggle: () => setState(() => _showNew = !_showNew),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter a new password.';
                    if (v.length < 6) return 'Password must be at least 6 characters.';
                    if (v == _currentCtrl.text) {
                      return 'New password must differ from the current one.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // ── confirm new password ─────────────────
                _PasswordField(
                  controller: _confirmCtrl,
                  label: 'Confirm new password',
                  visible: _showConfirm,
                  onToggle: () => setState(() => _showConfirm = !_showConfirm),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please confirm your new password.';
                    if (v != _newCtrl.text) return 'Passwords do not match.';
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                // ── submit button ────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kTeal,
                      foregroundColor: kNavyDark,
                      disabledBackgroundColor: kTeal.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: kNavyDark,
                            ),
                          )
                        : const Text(
                            'Update Password',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Reusable password text-field
// ─────────────────────────────────────────────────────────────
class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool visible;
  final VoidCallback onToggle;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final void Function(String)? onFieldSubmitted;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.visible,
    required this.onToggle,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: !visible,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      style: const TextStyle(color: kWhite, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: kWhite.withOpacity(0.55), fontSize: 13),
        filled: true,
        fillColor: kNavyDark.withOpacity(0.55),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kCardBorder.withOpacity(0.6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kCardBorder.withOpacity(0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kTeal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        suffixIcon: IconButton(
          icon: Icon(
            visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: kWhite.withOpacity(0.45),
            size: 20,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }
}