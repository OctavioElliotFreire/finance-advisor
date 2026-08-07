import 'package:flutter/material.dart';

/// Brand seed — kept as `Colors.teal`, refined into a full ColorScheme in
/// [AppTheme]. Negative/error semantics deliberately reuse [ColorScheme.error]
/// and info semantics reuse [ColorScheme.tertiary] rather than adding more
/// hues — see PLAN.md's design-system note: Restrained is the floor.
const Color appSeedColor = Color(0xFF009688);

/// Success/warning tokens Material's [ColorScheme] has no role for.
/// Tone-paired the same way M3 pairs error/onError/errorContainer/onErrorContainer.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
  });

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;

  static const AppSemanticColors light = AppSemanticColors(
    success: Color(0xFF2E7D53),
    onSuccess: Color(0xFFFFFFFF),
    successContainer: Color(0xFFC8F0D9),
    onSuccessContainer: Color(0xFF0B3D22),
    warning: Color(0xFF8A5300),
    onWarning: Color(0xFFFFFFFF),
    warningContainer: Color(0xFFFFDEA6),
    onWarningContainer: Color(0xFF2B1700),
  );

  static const AppSemanticColors dark = AppSemanticColors(
    success: Color(0xFF8FD9AE),
    onSuccess: Color(0xFF0B3D22),
    successContainer: Color(0xFF1E5B3B),
    onSuccessContainer: Color(0xFFC8F0D9),
    warning: Color(0xFFFFB74D),
    onWarning: Color(0xFF452B00),
    warningContainer: Color(0xFF663D00),
    onWarningContainer: Color(0xFFFFDEA6),
  );

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer: Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer: Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
    );
  }
}

/// Reads the app's semantic-color extension, falling back to [AppSemanticColors.light]
/// if a theme without the extension is somehow in scope (should not happen once
/// [AppTheme.light]/[AppTheme.dark] are wired into `MaterialApp`).
extension AppSemanticColorsContext on BuildContext {
  AppSemanticColors get semanticColors =>
      Theme.of(this).extension<AppSemanticColors>() ?? AppSemanticColors.light;
}
