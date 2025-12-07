import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';
import 'app_typography.dart';
import 'app_spacing.dart';
import 'app_radius.dart';

class ThemeController {
  ThemeController._internal();
  static final ThemeController instance = ThemeController._internal();

  final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  static const _prefsKey = 'app_theme_mode';

  /// Duration for animated theme transitions (300ms per requirements)
  static const Duration themeTransitionDuration = Duration(milliseconds: 300);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_prefsKey);
    switch (value) {
      case 'light':
        themeMode.value = ThemeMode.light;
        break;
      case 'dark':
        themeMode.value = ThemeMode.dark;
        break;
      default:
        themeMode.value = ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    switch (mode) {
      case ThemeMode.light:
        await prefs.setString(_prefsKey, 'light');
        break;
      case ThemeMode.dark:
        await prefs.setString(_prefsKey, 'dark');
        break;
      case ThemeMode.system:
        await prefs.remove(_prefsKey);
        break;
    }
  }

  /// Builds the light theme using design tokens
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: AppColors.lightColorScheme,
      textTheme: AppTypography.textTheme,
      cardTheme: _buildCardTheme(AppColors.lightColorScheme),
      inputDecorationTheme: _buildInputTheme(AppColors.lightColorScheme),
      elevatedButtonTheme: _buildElevatedButtonTheme(AppColors.lightColorScheme),
      filledButtonTheme: _buildFilledButtonTheme(AppColors.lightColorScheme),
      outlinedButtonTheme: _buildOutlinedButtonTheme(AppColors.lightColorScheme),
      textButtonTheme: _buildTextButtonTheme(AppColors.lightColorScheme),
      listTileTheme: _buildListTileTheme(),
      appBarTheme: _buildAppBarTheme(AppColors.lightColorScheme),
      navigationBarTheme: _buildNavigationBarTheme(AppColors.lightColorScheme),
      dialogTheme: _buildDialogTheme(),
      bottomSheetTheme: _buildBottomSheetTheme(AppColors.lightColorScheme),
      snackBarTheme: _buildSnackBarTheme(AppColors.lightColorScheme),
      chipTheme: _buildChipTheme(AppColors.lightColorScheme),
      dividerTheme: _buildDividerTheme(AppColors.lightColorScheme),
    );
  }

  /// Builds the dark theme using design tokens
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: AppColors.darkColorScheme,
      textTheme: AppTypography.textTheme,
      cardTheme: _buildCardTheme(AppColors.darkColorScheme),
      inputDecorationTheme: _buildInputTheme(AppColors.darkColorScheme),
      elevatedButtonTheme: _buildElevatedButtonTheme(AppColors.darkColorScheme),
      filledButtonTheme: _buildFilledButtonTheme(AppColors.darkColorScheme),
      outlinedButtonTheme: _buildOutlinedButtonTheme(AppColors.darkColorScheme),
      textButtonTheme: _buildTextButtonTheme(AppColors.darkColorScheme),
      listTileTheme: _buildListTileTheme(),
      appBarTheme: _buildAppBarTheme(AppColors.darkColorScheme),
      navigationBarTheme: _buildNavigationBarTheme(AppColors.darkColorScheme),
      dialogTheme: _buildDialogTheme(),
      bottomSheetTheme: _buildBottomSheetTheme(AppColors.darkColorScheme),
      snackBarTheme: _buildSnackBarTheme(AppColors.darkColorScheme),
      chipTheme: _buildChipTheme(AppColors.darkColorScheme),
      dividerTheme: _buildDividerTheme(AppColors.darkColorScheme),
    );
  }

  static CardThemeData _buildCardTheme(ColorScheme scheme) {
    return CardThemeData(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.listItemVertical),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.mediumBorderRadius,
      ),
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
    );
  }

  static InputDecorationTheme _buildInputTheme(ColorScheme scheme) {
    return InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: AppRadius.mediumBorderRadius,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.mediumBorderRadius,
        borderSide: BorderSide(color: scheme.outline, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.mediumBorderRadius,
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.mediumBorderRadius,
        borderSide: BorderSide(color: scheme.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadius.mediumBorderRadius,
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
    );
  }

  static ElevatedButtonThemeData _buildElevatedButtonTheme(ColorScheme scheme) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 1,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mediumBorderRadius,
        ),
      ),
    );
  }

  static FilledButtonThemeData _buildFilledButtonTheme(ColorScheme scheme) {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mediumBorderRadius,
        ),
      ),
    );
  }

  static OutlinedButtonThemeData _buildOutlinedButtonTheme(ColorScheme scheme) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mediumBorderRadius,
        ),
        side: BorderSide(color: scheme.outline),
      ),
    );
  }

  static TextButtonThemeData _buildTextButtonTheme(ColorScheme scheme) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.smallBorderRadius,
        ),
      ),
    );
  }

  static ListTileThemeData _buildListTileTheme() {
    return const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
    );
  }

  static AppBarTheme _buildAppBarTheme(ColorScheme scheme) {
    return AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
    );
  }

  static NavigationBarThemeData _buildNavigationBarTheme(ColorScheme scheme) {
    return NavigationBarThemeData(
      elevation: 0,
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    );
  }

  static DialogThemeData _buildDialogTheme() {
    return DialogThemeData(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.largeBorderRadius,
      ),
    );
  }

  static BottomSheetThemeData _buildBottomSheetTheme(ColorScheme scheme) {
    return BottomSheetThemeData(
      elevation: 2,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.large),
        ),
      ),
    );
  }

  static SnackBarThemeData _buildSnackBarTheme(ColorScheme scheme) {
    return SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.smallBorderRadius,
      ),
    );
  }

  static ChipThemeData _buildChipTheme(ColorScheme scheme) {
    return ChipThemeData(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.smallBorderRadius,
      ),
    );
  }

  static DividerThemeData _buildDividerTheme(ColorScheme scheme) {
    return DividerThemeData(
      color: scheme.outline,
      thickness: 1,
      space: 1,
    );
  }
}
