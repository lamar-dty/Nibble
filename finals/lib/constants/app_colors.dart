import 'package:flutter/material.dart';
import 'colors.dart';
import '../store/theme_store.dart';

class AppColors {
  AppColors._();

  static bool get _dark => ThemeStore.instance.isDark;

  // ── Backgrounds ───────────────────────────────────────────
  // kNavyDark  #243D6D  →  #121212
  static Color get bg       => _dark ? const Color(0xFF121212) : kNavyDark;

  // kNavyMid   #1E3070  →  #181818
  static Color get bgMid    => _dark ? const Color(0xFF181818) : kNavyMid;

  // kNavyCard  #1E316B  →  #1E1E1E
  static Color get card     => _dark ? const Color(0xFF1E1E1E) : kNavyCard;

  // deep navy variants 0xFF1A2D5A / 0xFF1B2D5B / 0xFF1A2A5E  →  #0D0D0D
  static Color get bgDeep   => _dark ? const Color(0xFF0D0D0D) : const Color(0xFF1A2D5A);

  // ── Borders ───────────────────────────────────────────────
  // kCardBorder #2E4090  →  #303030
  static Color get border   => _dark ? const Color(0xFF303030) : kCardBorder;

  // ── Text ─────────────────────────────────────────────────
  // kWhite   #FFFFFF  →  #F0F0F0
  static Color get text     => _dark ? const Color(0xFFF0F0F0) : kWhite;

  // kSubtitle #B0BAD3  →  #888888
  static Color get subtitle => _dark ? const Color(0xFF909090) : kSubtitle;

  // 0xFF6B7A99 (mid icon/secondary)  →  #666666
  static Color get icon     => _dark ? const Color(0xFF666666) : const Color(0xFF6B7A99);

  // ── Accent ───────────────────────────────────────────────
  // kTeal #90D0CB  →  #E8E8E8
  static Color get accent   => _dark ? const Color(0xFFE8E8E8) : kTeal;

  // Blue link variants 0xFF4A90D9 / 0xFF3B6FD4 / 0xFF5B8EE6  →  #AAAAAA
  static Color get link     => _dark ? const Color(0xFFAAAAAA) : const Color(0xFF4A90D9);

  // Light fills 0xFFEEEEEE / 0xFFF4F5F7  →  #1A1A1A
  static Color get lightFill => _dark ? const Color(0xFF1A1A1A) : const Color(0xFFEEEEEE);

  // ── Semantic (unchanged in both modes) ───────────────────
  static const danger  = Color(0xFFE87070);
  static const purple  = Color(0xFF9B88E8);
  static const tealGreen = Color(0xFF3BBFA3);
  static const amber   = Color(0xFFE8A870);
  static const yellow  = Color(0xFFE8D870);
  static const pink    = Color(0xFFD96B8A);
}