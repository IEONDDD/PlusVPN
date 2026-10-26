import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../services/vpn_engine.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.state});
  final AppState state;
  String get greeting {
    if (state.settings.greeting.trim().isNotEmpty) {
      return state.settings.greeting;
    }
    final hour = DateTime.now().hour;
    return hour < 5
        ? 'Good night'
        : hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final title = state.connected
        ? 'Connected'
        : state.transitioning
        ? 'Connecting…'
        : 'Disconnected';
    final sub = state.subscriptions
        .where((s) => s.id == state.selected?.subscriptionId)
        .firstOrNull;
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, box.maxHeight - 36),
          ),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'PlusVPN',
                      key: const Key('brand-wordmark'),
                      style: TextStyle(
                        fontFamily: state.settings.font.family,
                        fontFamilyFallback:
                            state.settings.font.fallbackFamilies,
                        letterSpacing: -.8,
                        fontSize: 28,
                        fontWeight: state.settings.font.brandWeight,
                        color: color.onSurface,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.shield_outlined,
                      color: color.onSurface.withValues(alpha: .4),
                    ),
                  ],
                ),
                const Spacer(),
                const SizedBox(height: 60),
                Text(
                  state.settings.subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    letterSpacing: 2,
                    color: color.onSurface.withValues(alpha: .55),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  greeting,
                  style: TextStyle(
                    fontSize: context.isGlass ? 44 : 38,
                    height: 1.1,
                    fontWeight: context.isGlass
                        ? FontWeight.w300
                        : FontWeight.w500,
                    letterSpacing: -1.5,
                  ),
                ),
                const SizedBox(height: 26),
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: _Chip(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: state.connected
                                    ? color.primary
                                    : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                title,
                                maxLines: 1,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      flex: 4,
                      child: _Chip(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.schedule, size: 13),
                            const SizedBox(width: 5),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  state.duration,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      flex: 3,
                      child: _Chip(
                        child: Text(
                          pingLabel(state.selected?.ping),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                GlassCard(
                  state: state,
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: state.busy
                            ? null
                            : () => showImportDialog(context, state),
                        icon: const Icon(Icons.add),
                        style: IconButton.styleFrom(
                          fixedSize: const Size(48, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(15),
                          onTap: () => state.setTab(1),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${sub?.title ?? 'Мои серверы'} →',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: color.onSurface.withValues(
                                      alpha: .5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  state.selected?.label ??
                                      'Добавьте первый сервер',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => state.setTab(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                WaveButton(state: state),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    state.connected
                        ? '↓ ${(state.downloadSpeed / 1024).toStringAsFixed(0)} KB/s    ↑ ${(state.uploadSpeed / 1024).toStringAsFixed(0)} KB/s'
                        : 'Ваше пространство. Ваше соединение.',
                    style: TextStyle(
                      fontSize: 11,
                      color: color.onSurface.withValues(alpha: .45),
                    ),
                  ),
                ),
                if (state.settings.showWord)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          state.settings.word,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: context.isGlass ? 68 : 48,
                            height: 1.45,
                            letterSpacing: context.isGlass ? -4 : -1.5,
                            fontWeight: context.isGlass
                                ? FontWeight.w200
                                : FontWeight.w400,
                            color: color.onSurface.withValues(alpha: .75),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => AppSurface(
    radius: 30,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: SizedBox(height: 36, child: Center(child: child)),
  );
}

class WaveButton extends StatefulWidget {
  const WaveButton({super.key, required this.state});
  final AppState state;
  @override
  State<WaveButton> createState() => _WaveButtonState();
}

class _WaveButtonState extends State<WaveButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );
  void _update() {
    if (widget.state.connected &&
        !WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .disableAnimations) {
      if (!_animation.isAnimating) _animation.repeat();
    } else {
      _animation.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _update();
  }

  @override
  void didUpdateWidget(covariant WaveButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final c = Theme.of(context).colorScheme;
    final foreground = context.isGlass ? c.primary : c.onPrimary;
    final button = FilledButton(
      onPressed: s.busy || s.transitioning
          ? null
          : () async {
              final wasConnected = s.connected;
              await s.toggle();
              if (!wasConnected && s.connected && context.mounted) {
                await _checkBatteryOptimization(context, s);
              }
            },
      style: FilledButton.styleFrom(
        shape: const StadiumBorder(),
        backgroundColor: context.isGlass
            ? c.primary.withValues(alpha: .10)
            : c.primary,
        foregroundColor: foreground,
        padding: const EdgeInsets.symmetric(horizontal: 30),
      ),
      child: s.transitioning || s.busy
          ? SizedBox(
              width: 25,
              height: 25,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: foreground,
              ),
            )
          : AnimatedBuilder(
              animation: _animation,
              builder: (_, _) => CustomPaint(
                size: const Size(double.infinity, 50),
                painter: _WavePainter(
                  phase: _animation.value * math.pi * 2,
                  color: foreground,
                  connected: s.connected,
                ),
              ),
            ),
    );
    return Semantics(
      button: true,
      label: s.connected ? 'Отключить VPN' : 'Подключить VPN',
      child: SizedBox(
        width: double.infinity,
        height: 90,
        child: context.isGlass
            ? AppSurface(radius: 50, padding: EdgeInsets.zero, child: button)
            : button,
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.phase,
    required this.color,
    required this.connected,
  });
  final double phase;
  final Color color;
  final bool connected;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (var x = 0.0; x <= size.width; x += 1) {
      final taper = math.sin(math.pi * x / size.width);
      final y =
          size.height / 2 +
          math.sin(x / size.width * math.pi * 7 + phase) *
              (connected ? 15 : 9) *
              taper;
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.color != color ||
      oldDelegate.connected != connected;
}

Future<void> _checkBatteryOptimization(
  BuildContext context,
  AppState state,
) async {
  if (state.settings.batteryPromptDismissed) return;
  final ignoring = await VpnEngine.isIgnoringBatteryOptimizations();
  if (ignoring || !context.mounted) return;

  await showPlusDialog<void>(
    context: context,
    builder: (ctx) => PlusDialog(
      title: const Row(
        children: [
          Icon(Icons.battery_charging_full_rounded, size: 26),
          SizedBox(width: 10),
          Expanded(child: Text('Работа в фоне')),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Чтобы Android не отключал VPN при выключенном экране или в спящем режиме, снимите ограничения расхода батареи для PlusVPN.',
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
          SizedBox(height: 12),
          Text(
            'В окне системы выберите «Разрешить» (или установите «Без ограничений» в настройках батареи).',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            state.updateSettings((s) => s.batteryPromptDismissed = true);
            Navigator.pop(ctx);
          },
          child: const Text('Позже'),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.pop(ctx);
            state.updateSettings((s) => s.batteryPromptDismissed = true);
            await VpnEngine.requestIgnoreBatteryOptimizations();
          },
          child: const Text('Снять ограничения'),
        ),
      ],
    ),
  );
}
