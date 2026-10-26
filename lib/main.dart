import 'dart:io';
import 'dart:ui';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'app_state.dart';
import 'models.dart';
import 'theme/app_theme.dart';
import 'tabs/home_tab.dart';
import 'tabs/servers_tab.dart';
import 'tabs/settings_tab.dart';
import 'widgets/common.dart';
import 'widgets/interface_scale.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    for (final font in [
      'inter',
      'dynapuff',
      'nunito',
      'rubikone',
      'comfortaa',
    ]) {
      yield LicenseEntryWithLineBreaks([
        font,
      ], await rootBundle.loadString('assets/licenses/$font-OFL.txt'));
    }
  });
  final state = AppState();
  await state.initialize();
  runApp(PlusVpnApp(state: state));
}

class PlusVpnApp extends StatelessWidget {
  const PlusVpnApp({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) => DynamicColorBuilder(
      builder: (light, dark) {
        final settings = state.settings;
        ColorScheme scheme(Brightness brightness) {
          final dynamicScheme = brightness == Brightness.dark ? dark : light;
          return settings.dynamicColors &&
                  !settings.wallpaperColors &&
                  dynamicScheme != null
              ? dynamicScheme
              : ColorScheme.fromSeed(
                  seedColor: Color(settings.accent),
                  brightness: brightness,
                );
        }

        return MaterialApp(
          title: 'PlusVPN',
          debugShowCheckedModeBanner: false,
          themeMode: settings.theme,
          theme: buildPlusTheme(scheme(Brightness.light), settings),
          darkTheme: buildPlusTheme(scheme(Brightness.dark), settings),
          builder: (context, child) => InterfaceScale(
            scale: settings.uiScale,
            child: child ?? const SizedBox.shrink(),
          ),
          home: AppShell(state: state),
        );
      },
    ),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.state});
  final AppState state;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    if (state.error case final String message) {
      state.clearError();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(seconds: 6),
            ),
          );
        }
      });
    }
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    final glass = state.settings.interfaceStyle == InterfaceStyle.liquidGlass;
    final navigation = NavigationBar(
      height: 72,
      selectedIndex: state.tab,
      onDestinationSelected: state.setTab,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.waves_outlined),
          selectedIcon: Icon(Icons.waves_rounded),
          label: 'Главная',
        ),
        NavigationDestination(
          icon: Icon(Icons.dns_outlined),
          selectedIcon: Icon(Icons.dns_rounded),
          label: 'Серверы',
        ),
        NavigationDestination(
          icon: Icon(Icons.tune_rounded),
          label: 'Настройки',
        ),
      ],
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
          ),
      child: Scaffold(
        body: Stack(
          children: [
            if (glass)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: dark
                          ? [
                              Color.lerp(
                                const Color(0xff0c151e),
                                colors.primary,
                                .08,
                              )!,
                              const Color(0xff172a2a),
                              const Color(0xff0c111b),
                            ]
                          : [
                              const Color(0xffe5f0f2),
                              Color.lerp(
                                const Color(0xfff2f5eb),
                                colors.primary,
                                .06,
                              )!,
                              const Color(0xffe3e9f4),
                            ],
                    ),
                  ),
                ),
              ),
            if (state.settings.wallpaper != null)
              Positioned.fill(
                child: RepaintBoundary(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: state.settings.blur,
                      sigmaY: state.settings.blur,
                    ),
                    child: Image.file(
                      File(state.settings.wallpaper!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            if (state.settings.wallpaper != null)
              Positioned.fill(
                child: ColoredBox(
                  color: (dark ? Colors.black : Colors.white).withValues(
                    alpha: dark ? .25 : .18,
                  ),
                ),
              ),
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      child: KeyedSubtree(
                        key: ValueKey(state.tab),
                        child: switch (state.tab) {
                          0 => HomeTab(state: state),
                          1 => ServersTab(state: state),
                          _ => SettingsTab(state: state),
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      glass ? 24 : 12,
                      8,
                      glass ? 24 : 12,
                      12,
                    ),
                    child: AppSurface(
                      radius: glass ? 36 : 28,
                      padding: EdgeInsets.zero,
                      child: navigation,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
