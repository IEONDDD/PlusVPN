import 'dart:ui';
import 'package:flutter/material.dart';
import '../models.dart';

@immutable
class PlusVisuals extends ThemeExtension<PlusVisuals> {
  const PlusVisuals({required this.style, required this.opacity});
  final InterfaceStyle style;
  final double opacity;
  bool get glass => style == InterfaceStyle.liquidGlass;
  @override
  PlusVisuals copyWith({InterfaceStyle? style, double? opacity}) =>
      PlusVisuals(style: style ?? this.style, opacity: opacity ?? this.opacity);
  @override
  PlusVisuals lerp(covariant PlusVisuals? other, double t) => other == null
      ? this
      : PlusVisuals(
          style: t < .5 ? style : other.style,
          opacity: lerpDouble(opacity, other.opacity, t)!,
        );
}

extension PlusContext on BuildContext {
  PlusVisuals get visuals =>
      Theme.of(this).extension<PlusVisuals>() ??
      const PlusVisuals(style: InterfaceStyle.materialYou, opacity: .06);
  bool get isGlass => visuals.glass;
}

ThemeData buildPlusTheme(ColorScheme colors, AppSettings settings) {
  final glass = settings.interfaceStyle == InterfaceStyle.liquidGlass;
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(28),
  );
  final button = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(24),
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    brightness: colors.brightness,
    fontFamily: settings.font.family,
    fontFamilyFallback: settings.font.fallbackFamilies,
  );
  return base.copyWith(
    extensions: [
      PlusVisuals(style: settings.interfaceStyle, opacity: settings.opacity),
    ],
    scaffoldBackgroundColor: glass ? Colors.transparent : colors.surface,
    textTheme: base.textTheme.apply(
      bodyColor: colors.onSurface,
      displayColor: colors.onSurface,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: button,
        backgroundColor: glass
            ? colors.primary.withValues(alpha: .17)
            : colors.primary,
        foregroundColor: glass ? colors.primary : colors.onPrimary,
        side: glass
            ? BorderSide(color: colors.primary.withValues(alpha: .28))
            : BorderSide.none,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: button,
        side: BorderSide(
          color: colors.outlineVariant.withValues(alpha: glass ? .45 : 1),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: glass
            ? colors.primary.withValues(alpha: .08)
            : colors.surfaceContainerHigh,
        foregroundColor: colors.onSurface,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: glass
          ? colors.onSurface.withValues(alpha: .035)
          : colors.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(
          color: colors.outlineVariant.withValues(alpha: glass ? .35 : .8),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
    ),
    dialogTheme: DialogThemeData(
      shape: rounded,
      backgroundColor: colors.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      shape: rounded,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      selectedTileColor: colors.secondaryContainer,
      iconColor: colors.onSurfaceVariant,
    ),
    switchTheme: glass
        ? SwitchThemeData(
            thumbColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? colors.primary
                  : colors.onSurface.withValues(alpha: .65),
            ),
            trackColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? colors.primary.withValues(alpha: .23)
                  : colors.onSurface.withValues(alpha: .04),
            ),
            trackOutlineColor: WidgetStatePropertyAll(
              colors.onSurface.withValues(alpha: .18),
            ),
          )
        : base.switchTheme,
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      backgroundColor: glass ? Colors.transparent : colors.surfaceContainer,
      indicatorColor: glass
          ? colors.primary.withValues(alpha: .16)
          : colors.secondaryContainer,
      indicatorShape: const StadiumBorder(),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w400,
          color: states.contains(WidgetState.selected)
              ? colors.onSurface
              : colors.onSurfaceVariant,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: button,
      backgroundColor: colors.inverseSurface,
      contentTextStyle: TextStyle(color: colors.onInverseSurface),
      insetPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      showValueIndicator: ShowValueIndicator.onDrag,
    ),
    dividerTheme: DividerThemeData(
      color: colors.outlineVariant.withValues(alpha: glass ? .25 : 1),
      space: 24,
    ),
  );
}
