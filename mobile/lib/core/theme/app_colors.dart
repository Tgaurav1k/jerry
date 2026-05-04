import 'package:flutter/material.dart';

/// Design tokens — Monolithic Editorial (Stitch Design System).
///
/// Dual-tone palette: dark theme (home/landing) with gold accents,
/// light theme (chats, history, directory) with monochrome.
abstract final class AppColors {
  // ── Primary (Core Authority) ──
  static const primary = Color(0xFF000000);
  static const onPrimary = Color(0xFFE2E2E2);
  static const primaryContainer = Color(0xFF3B3B3B);

  // ── Gold Accent (Stitch signature) ──
  static const gold = Color(0xFFC8A84E);
  static const goldLight = Color(0xFFD4A843);
  static const goldDim = Color(0xFFAA8A3A);

  // ── Dark Theme (Home/Landing) ──
  static const darkBg = Color(0xFF111111);
  static const darkSurface = Color(0xFF1A1A1A);
  static const darkCard = Color(0xFF222222);
  static const darkCardElevated = Color(0xFF2A2A2A);
  static const darkText = Color(0xFFFFFFFF);
  static const darkTextMuted = Color(0xFF999999);
  static const darkTextSecondary = Color(0xFF666666);

  // ── Surface hierarchy (Light Canvas) ──
  static const surface = Color(0xFFF9F9F9);
  static const surfaceDim = Color(0xFFDADADA);
  static const surfaceBright = Color(0xFFF9F9F9);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF3F3F3);
  static const surfaceContainer = Color(0xFFEEEEEE);
  static const surfaceContainerHigh = Color(0xFFE8E8E8);
  static const surfaceContainerHighest = Color(0xFFE2E2E2);

  // ── On-surface text ──
  static const onSurface = Color(0xFF1A1C1C);
  static const onSurfaceVariant = Color(0xFF474747);

  // ── Inverse (Deep Accents) ──
  static const inverseSurface = Color(0xFF2F3131);
  static const inverseOnSurface = Color(0xFFF1F1F1);
  static const inversePrimary = Color(0xFFC6C6C6);

  // ── Secondary ──
  static const secondary = Color(0xFF5F5E5E);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFFD7D4D3);
  static const onSecondaryContainer = Color(0xFF1C1B1B);

  // ── Tertiary ──
  static const tertiary = Color(0xFF3B3B3B);

  // ── Outline ──
  static const outline = Color(0xFF777777);
  static const outlineVariant = Color(0xFFC6C6C6);

  // ── Error ──
  static const error = Color(0xFFBA1A1A);
  static const onError = Color(0xFFFFFFFF);
  static const errorContainer = Color(0xFFFFDAD6);

  // ── Functional aliases ──
  static const background = surface;
  static const cardBackground = surfaceContainerLowest;
  static const cardBackgroundAlt = surfaceContainerLow;
  static const textPrimary = onSurface;
  static const textSecondary = secondary;
  static const textMuted = onSurfaceVariant;
  static const onlineGreen = Color(0xFF4CAF50);

  // ── Legacy aliases (maps old blue/slate tokens → monochrome) ──
  static const slate50 = surface;
  static const slate100 = surfaceContainerLow;
  static const slate200 = surfaceContainerHigh;
  static const slate300 = surfaceContainerHighest;
  static const slate400 = outlineVariant;
  static const slate500 = secondary;
  static const slate600 = onSurfaceVariant;
  static const slate700 = onSurface;
  static const slate800 = inverseSurface;

  static const blue50 = surfaceContainerLow;
  static const blue500 = primary;
  static const blue600 = primaryContainer;

  static const sage500 = onlineGreen;
}
