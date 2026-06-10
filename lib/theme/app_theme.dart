import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:videoweb_flutter/services/app_prefs.dart';

/// 应用语义色（对应原生 values/colors.xml + values-night/colors.xml）
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color pageBgTop;
  final Color pageBg;
  final Color pageBgBottom;
  final Color glowWarm;
  final Color homeSearchBg;
  final Color homeSearchStroke;
  final Color homeTextHint;
  final Color homeCategorySelected;
  final Color homeCategoryNormal;
  final Color homeFilterChipBg;
  final Color homeFilterChipSelectedBg;
  final Color homeFilterChipText;
  final Color homeFilterChipTextSelected;
  final Color cardBg;
  final Color cardStroke;
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Color divider;
  final Color chipBg;
  final Color placeholderBg;
  final Color bottomNavBg;
  final Color bottomNavTopLine;
  final Color accent;
  final Color surface;
  final Color accentContainer;
  final Color profileHeaderStart;
  final Color profileHeaderEnd;
  final Color profileHeaderGlow;
  final Color profileStatRowBg;
  final Color profileStatDivider;
  final Color profileLoginChipBg;
  final Color avatarPlaceholderBg;
  final Color avatarPlaceholderFg;

  const AppColors({
    required this.pageBgTop,
    required this.pageBg,
    required this.pageBgBottom,
    required this.glowWarm,
    required this.homeSearchBg,
    required this.homeSearchStroke,
    required this.homeTextHint,
    required this.homeCategorySelected,
    required this.homeCategoryNormal,
    required this.homeFilterChipBg,
    required this.homeFilterChipSelectedBg,
    required this.homeFilterChipText,
    required this.homeFilterChipTextSelected,
    required this.cardBg,
    required this.cardStroke,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.divider,
    required this.chipBg,
    required this.placeholderBg,
    required this.bottomNavBg,
    required this.bottomNavTopLine,
    required this.accent,
    required this.surface,
    required this.accentContainer,
    required this.profileHeaderStart,
    required this.profileHeaderEnd,
    required this.profileHeaderGlow,
    required this.profileStatRowBg,
    required this.profileStatDivider,
    required this.profileLoginChipBg,
    required this.avatarPlaceholderBg,
    required this.avatarPlaceholderFg,
  });

  static const light = AppColors(
    pageBgTop: Color(0xFFFAFBFE),
    pageBg: Color(0xFFF3F5FA),
    pageBgBottom: Color(0xFFEBEEF5),
    glowWarm: Color(0x0CFF9A4A),
    homeSearchBg: Color(0xFFFFFFFF),
    homeSearchStroke: Color(0xFFD8DCE6),
    homeTextHint: Color(0xFF9A9EAD),
    homeCategorySelected: Color(0xFF2C2E36),
    homeCategoryNormal: Color(0xFF6B6E7A),
    homeFilterChipBg: Color(0xFFF0F2F7),
    homeFilterChipSelectedBg: Color(0xFFFFF0F3),
    homeFilterChipText: Color(0xFF6B6E7A),
    homeFilterChipTextSelected: Color(0xFFFF4D7D),
    cardBg: Color(0xFFFFFFFF),
    cardStroke: Color(0xFFE4E7EF),
    textPrimary: Color(0xFF2C2E36),
    textSecondary: Color(0xFF6B6E7A),
    textHint: Color(0xFF9A9EAD),
    divider: Color(0xFFE4E7EF),
    chipBg: Color(0xFFF0F2F7),
    placeholderBg: Color(0xFFE4E7EF),
    bottomNavBg: Color(0xFFFFFFFF),
    bottomNavTopLine: Color(0xFFEBEEF5),
    accent: Color(0xFFFF6B35),
    surface: Color(0xFFFFFFFF),
    accentContainer: Color(0x1AFF6B35),
    profileHeaderStart: Color(0xFFFFFFFF),
    profileHeaderEnd: Color(0xFFF4F6FB),
    profileHeaderGlow: Color(0x126B8FC4),
    profileStatRowBg: Color(0xFFE2E6F0),
    profileStatDivider: Color(0xFFCDD2DE),
    profileLoginChipBg: Color(0xFFF0F2F7),
    avatarPlaceholderBg: Color(0xFFD8DCE6),
    avatarPlaceholderFg: Color(0xFFFFFFFF),
  );

  static const dark = AppColors(
    pageBgTop: Color(0xFF1A1D28),
    pageBg: Color(0xFF12141C),
    pageBgBottom: Color(0xFF0C0E14),
    glowWarm: Color(0x14FF9A4A),
    homeSearchBg: Color(0x26FFFFFF),
    homeSearchStroke: Color(0x1AFFFFFF),
    homeTextHint: Color(0xFF9A9AA8),
    homeCategorySelected: Color(0xFFF5F5F7),
    homeCategoryNormal: Color(0xFF8E8E93),
    homeFilterChipBg: Color(0xFF2A2C36),
    homeFilterChipSelectedBg: Color(0xFF3D2A32),
    homeFilterChipText: Color(0xFF8E8E93),
    homeFilterChipTextSelected: Color(0xFFFF8FA8),
    cardBg: Color(0xFF24262F),
    cardStroke: Color(0x14FFFFFF),
    textPrimary: Color(0xFFF5F5F7),
    textSecondary: Color(0xFFB0B0BC),
    textHint: Color(0xFF9A9AA8),
    divider: Color(0xFF2E3038),
    chipBg: Color(0xFF2A2C36),
    placeholderBg: Color(0xFF24262F),
    bottomNavBg: Color(0xFF1A1D26),
    bottomNavTopLine: Color(0xFF2A2E38),
    accent: Color(0xFFFF7A4D),
    surface: Color(0xFF1E212B),
    accentContainer: Color(0x33FF7A4D),
    profileHeaderStart: Color(0xFF1E212B),
    profileHeaderEnd: Color(0xFF2A241C),
    profileHeaderGlow: Color(0x28FF7A4D),
    profileStatRowBg: Color(0xFF1A1E28),
    profileStatDivider: Color(0xFF2E323D),
    profileLoginChipBg: Color(0x26FFFFFF),
    avatarPlaceholderBg: Color(0xFF3D4352),
    avatarPlaceholderFg: Color(0xFFE8EAEF),
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color blend(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      pageBgTop: blend(pageBgTop, other.pageBgTop),
      pageBg: blend(pageBg, other.pageBg),
      pageBgBottom: blend(pageBgBottom, other.pageBgBottom),
      glowWarm: blend(glowWarm, other.glowWarm),
      homeSearchBg: blend(homeSearchBg, other.homeSearchBg),
      homeSearchStroke: blend(homeSearchStroke, other.homeSearchStroke),
      homeTextHint: blend(homeTextHint, other.homeTextHint),
      homeCategorySelected: blend(homeCategorySelected, other.homeCategorySelected),
      homeCategoryNormal: blend(homeCategoryNormal, other.homeCategoryNormal),
      homeFilterChipBg: blend(homeFilterChipBg, other.homeFilterChipBg),
      homeFilterChipSelectedBg: blend(homeFilterChipSelectedBg, other.homeFilterChipSelectedBg),
      homeFilterChipText: blend(homeFilterChipText, other.homeFilterChipText),
      homeFilterChipTextSelected: blend(homeFilterChipTextSelected, other.homeFilterChipTextSelected),
      cardBg: blend(cardBg, other.cardBg),
      cardStroke: blend(cardStroke, other.cardStroke),
      textPrimary: blend(textPrimary, other.textPrimary),
      textSecondary: blend(textSecondary, other.textSecondary),
      textHint: blend(textHint, other.textHint),
      divider: blend(divider, other.divider),
      chipBg: blend(chipBg, other.chipBg),
      placeholderBg: blend(placeholderBg, other.placeholderBg),
      bottomNavBg: blend(bottomNavBg, other.bottomNavBg),
      bottomNavTopLine: blend(bottomNavTopLine, other.bottomNavTopLine),
      accent: blend(accent, other.accent),
      surface: blend(surface, other.surface),
      accentContainer: blend(accentContainer, other.accentContainer),
      profileHeaderStart: blend(profileHeaderStart, other.profileHeaderStart),
      profileHeaderEnd: blend(profileHeaderEnd, other.profileHeaderEnd),
      profileHeaderGlow: blend(profileHeaderGlow, other.profileHeaderGlow),
      profileStatRowBg: blend(profileStatRowBg, other.profileStatRowBg),
      profileStatDivider: blend(profileStatDivider, other.profileStatDivider),
      profileLoginChipBg: blend(profileLoginChipBg, other.profileLoginChipBg),
      avatarPlaceholderBg: blend(avatarPlaceholderBg, other.avatarPlaceholderBg),
      avatarPlaceholderFg: blend(avatarPlaceholderFg, other.avatarPlaceholderFg),
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>() ?? AppColors.light;
}

/// 主题构建（对应 ThemeManager.kt + values/themes）
class AppTheme {
  static ThemeMode themeModeFromPrefs(String mode) {
    switch (mode) {
      case AppPrefs.themeLight:
        return ThemeMode.light;
      case AppPrefs.themeDark:
        return ThemeMode.dark;
      case AppPrefs.themeSystem:
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }

  static String themeHint(String mode) {
    switch (mode) {
      case AppPrefs.themeLight:
        return '当前浅色模式';
      case AppPrefs.themeDark:
        return '当前深色模式';
      default:
        return '当前跟随系统';
    }
  }

  static ThemeData light() => _build(AppColors.light, Brightness.light);

  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors colors, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: colors.accent,
      brightness: brightness,
      primary: colors.accent,
      surface: colors.cardBg,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.pageBg,
      extensions: [colors],
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: colors.textPrimary),
        bodyMedium: TextStyle(color: colors.textPrimary),
        bodySmall: TextStyle(color: colors.textSecondary),
        titleLarge: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600),
        labelLarge: TextStyle(color: colors.textPrimary),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: brightness == Brightness.light ? colors.textPrimary : colors.surface,
        contentTextStyle: TextStyle(color: brightness == Brightness.light ? colors.cardBg : colors.textPrimary),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colors.textPrimary,
        systemOverlayStyle: brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.bottomNavBg,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colors.accent.withOpacity(0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 0,
        height: 68,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? colors.accent : (brightness == Brightness.light ? const Color(0xFFA8ABB8) : const Color(0xFF6B7080)),
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? colors.accent : (brightness == Brightness.light ? const Color(0xFFA8ABB8) : const Color(0xFF6B7080)),
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: colors.cardBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(color: colors.divider, thickness: 1),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        backgroundColor: colors.chipBg,
        selectedColor: colors.homeFilterChipSelectedBg,
        side: BorderSide(color: colors.cardStroke),
        labelStyle: TextStyle(color: colors.textPrimary, fontSize: 13),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.accent),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: Colors.white,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.accent;
          return brightness == Brightness.light ? Colors.white : colors.chipBg;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.accent.withOpacity(0.45);
          }
          return colors.chipBg;
        }),
      ),
    );
  }
}

/// 首页渐变背景（对应 bg_home_page.xml）
class HomePageBackground extends StatelessWidget {
  final Widget child;

  const HomePageBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.pageBgTop, c.pageBg, c.pageBgBottom],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -60,
            top: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [c.glowWarm, c.glowWarm.withOpacity(0)],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
