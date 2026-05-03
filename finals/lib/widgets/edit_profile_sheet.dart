import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../store/auth_store.dart';
import '../store/space_chat_store.dart';
import '../store/space_store.dart';

// ─────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────
void showEditProfileSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    enableDrag: true,
    builder: (_) => const EditProfileSheet(),
  );
}

// ─────────────────────────────────────────────────────────────
// Sheet
// ─────────────────────────────────────────────────────────────
class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({super.key});

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passwordCtrl;

  bool _saving = false;
  String? _errorBanner;
  bool _editingEmail = false;
  bool _obscurePassword = true;

  // Track whether any field has diverged from the saved values so we know
  // when to show the password confirmation field.
  bool get _hasChanges {
    final usernameChanged =
        _usernameCtrl.text.trim().toLowerCase() != AuthStore.instance.username;
    final emailChanged = _editingEmail &&
        _emailCtrl.text.trim().toLowerCase() !=
            AuthStore.instance.displayEmail;
    return usernameChanged || emailChanged;
  }

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(text: AuthStore.instance.username);
    _emailCtrl    = TextEditingController(text: AuthStore.instance.displayEmail);
    _passwordCtrl = TextEditingController();

    // Rebuild when text changes so _hasChanges stays reactive.
    _usernameCtrl.addListener(() => setState(() {}));
    _emailCtrl.addListener(() => setState(() {}));

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorBanner = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final oldName      = AuthStore.instance.username;
    final newName      = _usernameCtrl.text.trim().toLowerCase();
    final newEmail     = _emailCtrl.text.trim().toLowerCase();
    final currentEmail = AuthStore.instance.displayEmail;
    final password     = _passwordCtrl.text;

    final usernameChanged = newName != oldName;
    final emailChanged    = _editingEmail && newEmail != currentEmail;

    if (!usernameChanged && !emailChanged) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _saving = true);

    // ── Update email (requires password) ──────────────────
    if (emailChanged) {
      final error = await AuthStore.instance.updateEmail(
        newEmail: newEmail,
        currentPassword: password,
      );
      if (!mounted) return;
      if (error != null) {
        setState(() { _saving = false; _errorBanner = error; });
        return;
      }
    }

    // ── Update username (requires password) ───────────────
    if (usernameChanged) {
      final error = await AuthStore.instance.updateUsername(
        newName,
        currentPassword: password,
      );
      if (!mounted) return;
      if (error != null) {
        setState(() { _saving = false; _errorBanner = error; });
        return;
      }

      await SpaceStore.instance.renameUserInSpaces(oldName, newName);
      if (!mounted) return;

      final spaceCodes = SpaceStore.instance.spaces
          .map((s) => s.inviteCode)
          .toList();
      await SpaceChatStore.instance
          .renameSenderInMessages(oldName, newName, spaceCodes);
      if (!mounted) return;
    }

    setState(() => _saving = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1A2A5E),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12))),
        duration: const Duration(seconds: 3),
        content: Text(
          emailChanged && usernameChanged
              ? 'Profile updated.'
              : emailChanged
                  ? 'Email updated.'
                  : 'Username updated.',
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return FadeTransition(
      opacity: _fadeAnim,
      child: Padding(
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
                // Drag handle
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
                const Text(
                  'Edit Profile',
                  style: TextStyle(
                    color: kWhite,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your username is your public identity across spaces and tasks.',
                  style: TextStyle(color: kWhite.withOpacity(0.55), fontSize: 13),
                ),
                const SizedBox(height: 24),

                // ── Email field ──────────────────────────────
                if (!_editingEmail) ...[
                  _ReadOnlyField(
                    label: 'Email',
                    value: AuthStore.instance.displayEmail,
                    onEdit: () => setState(() { _editingEmail = true; }),
                  ),
                ] else ...[
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(color: kWhite, fontSize: 14),
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: _inputDecoration(
                      label: 'New Email',
                      hint: 'you@example.com',
                    ),
                    validator: (v) {
                      final trimmed = v?.trim() ?? '';
                      if (trimmed.isEmpty) return 'Email must not be empty.';
                      if (!trimmed.contains('@') || !trimmed.contains('.')) {
                        return 'Please enter a valid email address.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => setState(() {
                      _editingEmail = false;
                      _emailCtrl.text = AuthStore.instance.displayEmail;
                      _passwordCtrl.clear();
                    }),
                    child: Text(
                      'Cancel email change',
                      style: TextStyle(
                        color: kTeal.withOpacity(0.8),
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                        decorationColor: kTeal.withOpacity(0.5),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // ── Error banner ─────────────────────────────
                if (_errorBanner != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.redAccent.withOpacity(0.45)),
                    ),
                    child: Text(
                      _errorBanner!,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 13),
                    ),
                  ),
                ],

                // ── Username field ───────────────────────────
                TextFormField(
                  controller: _usernameCtrl,
                  textInputAction:
                      _hasChanges ? TextInputAction.next : TextInputAction.done,
                  onFieldSubmitted: (_) =>
                      _hasChanges ? FocusScope.of(context).nextFocus() : _submit(),
                  style: const TextStyle(color: kWhite, fontSize: 14),
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: _inputDecoration(
                    label: 'Username',
                    hint: 'lowercase letters, numbers, underscores',
                  ),
                  validator: (v) =>
                      AuthStore.instance.validateUsernameInput(v?.trim() ?? ''),
                ),
                const SizedBox(height: 6),
                Text(
                  '3–20 characters. Lowercase letters, numbers, underscores only.',
                  style: TextStyle(
                      color: kWhite.withOpacity(0.35), fontSize: 11),
                ),
                const SizedBox(height: 14),

                // ── Password confirmation (shown when any change is pending) ──
                if (_hasChanges) ...[
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    style: const TextStyle(color: kWhite, fontSize: 14),
                    decoration: _inputDecoration(
                      label: 'Current Password',
                      hint: 'Required to save changes',
                    ).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: kWhite.withOpacity(0.45),
                          size: 20,
                        ),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Password is required to save changes.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                ],

                const SizedBox(height: 14),

                // ── Save button ──────────────────────────────
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
                            'Save Changes',
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

  InputDecoration _inputDecoration(
      {required String label, required String hint}) {
    return InputDecoration(
      labelText: label,
      labelStyle:
          TextStyle(color: kWhite.withOpacity(0.55), fontSize: 13),
      hintText: hint,
      hintStyle:
          TextStyle(color: kWhite.withOpacity(0.25), fontSize: 12),
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
        borderSide:
            const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      errorStyle:
          const TextStyle(color: Colors.redAccent, fontSize: 11),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Read-only display field (with optional "Change" button)
// ─────────────────────────────────────────────────────────────
class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onEdit;

  const _ReadOnlyField({
    required this.label,
    required this.value,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: kNavyDark.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kCardBorder.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: kWhite.withOpacity(0.45), fontSize: 11)),
                const SizedBox(height: 3),
                Text(value,
                    style: TextStyle(
                        color: kWhite.withOpacity(0.55), fontSize: 14)),
              ],
            ),
          ),
          if (onEdit != null)
            GestureDetector(
              onTap: onEdit,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: kTeal.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kTeal.withOpacity(0.35)),
                ),
                child: Text(
                  'Change',
                  style: TextStyle(
                    color: kTeal.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
