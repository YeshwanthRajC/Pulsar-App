import 'package:flutter/material.dart';

/// App color palette matching the Pulsar VoiceTask AI design specification:
/// - Cosmic Black (#080B14): Main background
/// - Nebula Navy (#111827): Cards and panels
/// - Pulsar Cyan (#67E8F9): Primary actions and active states
/// - Nebula Violet (#A78BFA): AI features and secondary accents
/// - Starlight White (#F8FAFC): Headings and important text
/// - Moonlight Grey (#94A3B8): Secondary text
class AppColors {
  // Dark Theme Palette
  static const Color cosmicBlack = Color(0xFF080B14);
  static const Color nebulaNavy = Color(0xFF111827);
  static const Color nebulaNavyBorder = Color(0xFF1F293D);
  static const Color pulsarCyan = Color(0xFF67E8F9);
  static const Color pulsarCyanDark = Color(0xFF06B6D4);
  static const Color nebulaViolet = Color(0xFFA78BFA);
  static const Color nebulaVioletDark = Color(0xFF7C3AED);
  static const Color starlightWhite = Color(0xFFF8FAFC);
  static const Color moonlightGrey = Color(0xFF94A3B8);
  static const Color slateCard = Color(0xFF172033);
  
  // Status Colors
  static const Color errorRed = Color(0xFFEF4444);
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningOrange = Color(0xFFF59E0B);

  // Light Theme Palette
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightCyan = Color(0xFF0891B2);
  static const Color lightViolet = Color(0xFF8B5CF6);
}
