import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../store/auth_store.dart';

// ─────────────────────────────────────────────────────────────
// Preset avatar definitions
// ─────────────────────────────────────────────────────────────

class _AvatarDef {
  final String seed;
  final IconData icon;
  final Color bg;
  final Color fg;
  const _AvatarDef(this.seed, this.icon, this.bg, this.fg);
}

const List<_AvatarDef> kAvatarPresets = [
  _AvatarDef('bunny',   Icons.cruelty_free_outlined,      Color(0xFF5B8EE6), kWhite),
  _AvatarDef('fox',     Icons.pets_outlined,               Color(0xFFE07B43), kWhite),
  _AvatarDef('wave',    Icons.water_outlined,              Color(0xFF3ABFBF), kWhite),
  _AvatarDef('star',    Icons.star_outline_rounded,        Color(0xFFF4C542), kNavyDark),
  _AvatarDef('moon',    Icons.nightlight_round_outlined,   Color(0xFF7B6EE8), kWhite),
  _AvatarDef('leaf',    Icons.eco_outlined,                Color(0xFF45A86E), kWhite),
  _AvatarDef('bolt',    Icons.bolt_outlined,               Color(0xFFE8A020), kWhite),
  _AvatarDef('gem',     Icons.diamond_outlined,            Color(0xFFD64FA0), kWhite),
  _AvatarDef('rocket',  Icons.rocket_launch_outlined,      Color(0xFF3D6CB5), kWhite),
  _AvatarDef('fire',    Icons.local_fire_department_outlined, Color(0xFFE05C3A), kWhite),
  _AvatarDef('flower',  Icons.local_florist_outlined,      Color(0xFFE878B4), kWhite),
  _AvatarDef('snow',    Icons.ac_unit_outlined,            Color(0xFF55B8E8), kWhite),
];

/// Looks up the [_AvatarDef] for [seed]; falls back to the first preset.
_AvatarDef _defFor(String seed) {
  return kAvatarPresets.firstWhere(
    (a) => a.seed == seed,
    orElse: () => kAvatarPresets.first,
  );
}

// ─────────────────────────────────────────────────────────────
// Public avatar widget — use anywhere in the app
// ─────────────────────────────────────────────────────────────

/// Renders the circular avatar for [seed] at [size].
/// Wraps an icon inside a coloured circle with an optional white border.
class AppAvatar extends StatelessWidget {
  final String seed;
  final double size;
  final bool showBorder;

  const AppAvatar({
    super.key,
    required this.seed,
    this.size = 48,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final def = _defFor(seed);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: def.bg,
        border: showBorder
            ? Border.all(color: kWhite, width: size * 0.04)
            : null,
      ),
      child: Icon(def.icon, color: def.fg, size: size * 0.52),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Manage Account bottom sheet
// ─────────────────────────────────────────────────────────────

void showManageAccountSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ManageAccountSheet(),
  );
}

class _ManageAccountSheet extends StatefulWidget {
  const _ManageAccountSheet();

  @override
  State<_ManageAccountSheet> createState() => _ManageAccountSheetState();
}

class _ManageAccountSheetState extends State<_ManageAccountSheet> {
  late String _selectedSeed;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedSeed = AuthStore.instance.avatarSeed;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await AuthStore.instance.updateAvatarSeed(_selectedSeed);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: kNavyDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: kWhite.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title row
              Row(
                children: [
                  const Icon(Icons.manage_accounts_outlined,
                      color: kTeal, size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    'Manage Account',
                    style: TextStyle(
                      color: kWhite,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Avatar section ────────────────────────
              const Text(
                'Choose Avatar',
                style: TextStyle(
                  color: kTeal,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),

              // Preview
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: anim,
                    child: child,
                  ),
                  child: AppAvatar(
                    key: ValueKey(_selectedSeed),
                    seed: _selectedSeed,
                    size: 80,
                    showBorder: true,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: kAvatarPresets.length,
                itemBuilder: (_, i) {
                  final def = kAvatarPresets[i];
                  final selected = def.seed == _selectedSeed;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedSeed = def.seed),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? kTeal : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: kTeal.withOpacity(0.45),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                      child: AppAvatar(seed: def.seed, size: 48),
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTeal,
                    foregroundColor: kNavyDark,
                    disabledBackgroundColor: kTeal.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: kNavyDark,
                          ),
                        )
                      : const Text(
                          'Save Avatar',
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
    );
  }
}