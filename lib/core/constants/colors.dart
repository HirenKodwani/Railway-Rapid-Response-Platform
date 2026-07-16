import 'package:flutter/material.dart';

/// App color palette for the Indian Railways RRS
/// Inspired by Indian Railways official branding
class AppColors {
  AppColors._(); // Prevent instantiation

  // --- Primary Brand Colors ---

  /// Indian Railways Navy Blue — primary app color
  static const Color primaryNavy = Color(0xFF1A237E);

  /// Indian Railways Deep Blue — darker shade
  static const Color primaryDark = Color(0xFF0D1442);

  /// Indian Railways Saffron/Orange — accent color
  static const Color accentSaffron = Color(0xFFFF6F00);

  /// Light saffron for backgrounds
  static const Color accentSaffronLight = Color(0xFFFFF3E0);

  // --- Surface & Background Colors ---

  /// Main background — off-white
  static const Color background = Color(0xFFF5F5F5);

  /// Light primary color for backgrounds/highlights
  static const Color primaryLight = Color(0xFFE8EAF6);

  /// Border color for inputs and cards
  static const Color border = Color(0xFFE0E0E0);

  /// Card surface
  static const Color surface = Color(0xFFFFFFFF);

  /// Dark background for gradient
  static const Color backgroundDark = Color(0xFF121212);

  // --- Text Colors ---

  /// Primary text — near black
  static const Color textPrimary = Color(0xFF1A1A2E);

  /// Secondary text — medium gray
  static const Color textSecondary = Color(0xFF6B7280);

  /// Light text — for dark backgrounds
  static const Color textLight = Color(0xFFFFFFFF);

  /// Subtle text
  static const Color textSubtle = Color(0xFF9CA3AF);

  // --- Status Colors ---

  /// Success green
  static const Color success = Color(0xFF10B981);

  /// Error red
  static const Color error = Color(0xFFEF4444);

  /// Warning amber
  static const Color warning = Color(0xFFF59E0B);

  /// Info blue
  static const Color info = Color(0xFF3B82F6);

  // --- Role Colors (consistent across app) ---

  /// Master Admin — Navy Blue
  static const Color roleMasterAdmin = Color(0xFF1A237E);

  /// Super Admin — Deep Orange
  static const Color roleSuperAdmin = Color(0xFFE65100);

  /// Admin — Dark Green
  static const Color roleAdmin = Color(0xFF2E7D32);

  /// Lead Supervisor — Amber
  static const Color roleLeadSupervisor = Color(0xFFF9A825);

  /// Supervisor — Purple
  static const Color roleSupervisor = Color(0xFF6A1B9A);

  /// Operator — Teal
  static const Color roleOperator = Color(0xFF00695C);

  // --- Gradient Colors ---

  /// Primary gradient for login/header
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1A237E),
      Color(0xFF283593),
      Color(0xFF1565C0),
    ],
  );

  /// Saffron accent gradient
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFF6F00),
      Color(0xFFFF8F00),
      Color(0xFFFFA000),
    ],
  );

  /// Dark gradient for overlays
  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0D1442),
      Color(0xFF1A237E),
    ],
  );
}

/// Get the color associated with a role string
Color getRoleColor(String role) {
  switch (role) {
    case 'master_admin':
      return AppColors.roleMasterAdmin;
    case 'super_admin':
      return AppColors.roleSuperAdmin;
    case 'admin':
      return AppColors.roleAdmin;
    case 'lead_supervisor':
      return AppColors.roleLeadSupervisor;
    case 'supervisor':
      return AppColors.roleSupervisor;
    case 'operator':
      return AppColors.roleOperator;
    default:
      return AppColors.textSecondary;
  }
}
