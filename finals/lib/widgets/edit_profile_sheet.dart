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

  bool _saving = false;
  String? _errorBanner;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(
      text: AuthStore.instance.username,
    );
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorBanner = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final oldName = AuthStore.instance.username;
    final newName = _usernameCtrl.text.trim().toLowerCase();

    if (newName == oldName) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _saving = true);

    final error = await AuthStore.instance.updateUsername(newName);
    if (!mounted) return;

    if (error != null) {
      setState(() { _saving = false; _errorBanner = error; });
      return;
    }

    await SpaceStore.instance.renameUserInSpaces(oldName, newName);
    if (!mounted) return;

    // Rewrite chat message sender fields so isOwn / unread detection stays
    // correct for messages that were sent under the old username.
    final spaceCodes = SpaceStore.instance.spaces
        .map((s) => s.inviteCode)
        .toList();
    await SpaceChatStore.instance
        .renameSenderInMessages(oldName, newName, spaceCodes);
    if (!mounted) return;

    setState(() => _saving = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF1A2A5E),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12))),
        duration: Duration(seconds: 3),
        content: Text(
          'Username updated.',
          style: TextStyle(color: Colors.white, fontSize: 13),
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
                _ReadOnlyField(
                  label: 'Email',
                  value: AuthStore.instance.displayEmail,
                ),
                const SizedBox(height: 14),
                if (_errorBanner != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 12),
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
                TextFormField(
                  controller: _usernameCtrl,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  style: const TextStyle(color: kWhite, fontSize: 14),
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    labelStyle: TextStyle(color: kWhite.withOpacity(0.55), fontSize: 13),
                    hintText: 'lowercase letters, numbers, underscores',
                    hintStyle: TextStyle(color: kWhite.withOpacity(0.25), fontSize: 12),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  validator: (v) =>
                      AuthStore.instance.validateUsernameInput(v?.trim() ?? ''),
                ),
                const SizedBox(height: 6),
                Text(
                  '3–20 characters. Lowercase letters, numbers, underscores only.',
                  style: TextStyle(color: kWhite.withOpacity(0.35), fontSize: 11),
                ),
                const SizedBox(height: 28),
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
}

// ─────────────────────────────────────────────────────────────
// Read-only display field (email)
// ─────────────────────────────────────────────────────────────
class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyField({required this.label, required this.value});

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: kWhite.withOpacity(0.45), fontSize: 11)),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(color: kWhite.withOpacity(0.55), fontSize: 14)),
        ],
      ),
    );
  }
}