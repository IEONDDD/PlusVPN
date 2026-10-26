import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:path_provider/path_provider.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key, required this.state});
  final AppState state;
  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool _loadingImage = false;
  AppState get state => widget.state;
  @override
  void initState() {
    super.initState();
    _recoverImage();
  }

  Future<void> _recoverImage() async {
    try {
      final lost = await ImagePicker().retrieveLostData();
      if (lost.files?.isNotEmpty == true) await _saveImage(lost.files!.first);
    } catch (_) {
      /* A cancelled picker leaves the existing background in place. */
    }
  }

  Future<void> _saveImage(XFile image) async {
    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/background_${DateTime.now().microsecondsSinceEpoch}.img';
    await image.saveTo(path);
    final previous = state.settings.wallpaper;
    Color? accent;
    if (state.settings.wallpaperColors) accent = await _extract(path);
    await state.updateSettings((s) {
      s.wallpaper = path;
      if (accent != null) s.accent = accent.toARGB32();
    });
    if (previous != null && previous != path && File(previous).existsSync()) {
      await File(previous).delete();
    }
  }

  Future<Color?> _extract(String path) async =>
      (await PaletteGenerator.fromImageProvider(
        FileImage(File(path)),
        size: const Size(200, 200),
        maximumColorCount: 12,
      )).dominantColor?.color;
  Future<void> _pickImage() async {
    setState(() => _loadingImage = true);
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 3000,
        imageQuality: 90,
      );
      if (image != null) await _saveImage(image);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Не удалось загрузить фон: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingImage = false);
    }
  }

  Future<void> _chooseApps() async {
    try {
      final apps = await state.engine.installedApps();
      if (!mounted) return;
      final selected = state.settings.excludedApps.toSet();
      var query = '';
      final result = await showPlusDialog<List<String>>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, change) {
            final filtered = apps
                .where(
                  (e) => '${e['label']} ${e['package']}'.toLowerCase().contains(
                    query.toLowerCase(),
                  ),
                )
                .toList();
            return PlusDialog(
              title: const Text('В обход VPN'),
              content: SizedBox(
                width: 460,
                height: MediaQuery.sizeOf(ctx).height * .4,
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Найти приложение',
                      ),
                      onChanged: (value) => change(() => query = value),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, index) {
                          final app = filtered[index];
                          final id = app['package']!;
                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(app['label']!),
                            subtitle: Text(
                              id,
                              style: const TextStyle(fontSize: 10),
                            ),
                            value: selected.contains(id),
                            onChanged: (value) => change(() {
                              if (value == true) {
                                selected.add(id);
                              } else {
                                selected.remove(id);
                              }
                            }),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, selected.toList()),
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        ),
      );
      if (result != null) {
        await state.updateSettings((s) => s.excludedApps = result);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось получить список приложений'),
          ),
        );
      }
    }
  }

  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: GlassCard(
      state: state,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
  Widget _text(
    String label,
    String value,
    void Function(AppSettings, String) setter, {
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextFormField(
      initialValue: value,
      maxLength: 80,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
      ),
      onChanged: (v) => state.updateSettings((s) => setter(s, v)),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final s = state.settings;
    return ListView(
      key: const PageStorageKey('settings'),
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
      children: [
        Text(
          'Настройки',
          style: TextStyle(
            fontSize: 32,
            fontWeight: context.isGlass ? FontWeight.w300 : FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),
        _section('Оформление', [
          SelectionField<InterfaceStyle>(
            label: 'Стиль интерфейса',
            value: s.interfaceStyle,
            options: const [
              SelectionOption(
                InterfaceStyle.liquidGlass,
                'Liquid Glass',
                subtitle: 'Прозрачные панели, блики и размытие',
                icon: Icons.blur_on_rounded,
              ),
              SelectionOption(
                InterfaceStyle.materialYou,
                'Material You',
                subtitle: 'Материальные поверхности и системная палитра',
                icon: Icons.palette_outlined,
              ),
            ],
            onChanged: (v) => state.updateSettings((s) {
              s.interfaceStyle = v;
              if (v == InterfaceStyle.materialYou) {
                s.dynamicColors = true;
                s.wallpaperColors = false;
              }
            }),
          ),
          const SizedBox(height: 14),
          SelectionField<ThemeMode>(
            label: 'Тема',
            value: s.theme,
            options: const [
              SelectionOption(
                ThemeMode.system,
                'Системная',
                icon: Icons.brightness_auto_rounded,
              ),
              SelectionOption(
                ThemeMode.light,
                'Светлая',
                icon: Icons.light_mode_outlined,
              ),
              SelectionOption(
                ThemeMode.dark,
                'Тёмная',
                icon: Icons.dark_mode_outlined,
              ),
            ],
            onChanged: (v) => state.updateSettings((s) => s.theme = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Системные цвета'),
            subtitle: const Text('Палитра Android 12+'),
            value: s.dynamicColors,
            onChanged: (v) => state.updateSettings((s) {
              s.dynamicColors = v;
              if (v) s.wallpaperColors = false;
            }),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Акцент из обоев'),
            value: s.wallpaperColors,
            onChanged: (v) async {
              await state.updateSettings((s) {
                s.wallpaperColors = v;
                if (v) s.dynamicColors = false;
              });
              if (v && s.wallpaper != null) {
                try {
                  final c = await _extract(s.wallpaper!);
                  if (c != null) {
                    await state.updateSettings((s) => s.accent = c.toARGB32());
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Не удалось извлечь цвет')),
                    );
                  }
                }
              }
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ...[
                0xffc1e899,
                0xff94d9df,
                0xffbfb3ff,
                0xffffb4c8,
                0xffffce8b,
                0xffa6c8ff,
              ].map(
                (c) => Semantics(
                  label: 'Выбрать цвет',
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: () => state.updateSettings((s) {
                      s.accent = c;
                      s.dynamicColors = false;
                      s.wallpaperColors = false;
                    }),
                    child: CircleAvatar(
                      backgroundColor: Color(c),
                      radius: 19,
                      child: s.accent == c && !s.dynamicColors
                          ? const Icon(
                              Icons.check,
                              color: Colors.black,
                              size: 18,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              IconButton.outlined(
                tooltip: 'Произвольный цвет',
                onPressed: () async {
                  final color = await showPlusDialog<Color>(
                    context: context,
                    builder: (_) => _ColorDialog(color: Color(s.accent)),
                  );
                  if (color != null) {
                    await state.updateSettings((s) {
                      s.accent = color.toARGB32();
                      s.dynamicColors = false;
                      s.wallpaperColors = false;
                    });
                  }
                },
                icon: const Icon(Icons.colorize),
              ),
            ],
          ),
        ]),
        if (context.isGlass)
          _section('Ваш фон', [
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _loadingImage ? null : _pickImage,
                  icon: const Icon(Icons.photo_outlined),
                  label: Text(_loadingImage ? 'Загрузка…' : 'Из галереи'),
                ),
                TextButton(
                  onPressed: s.wallpaper == null
                      ? null
                      : () async {
                          final old = s.wallpaper;
                          await state.updateSettings((s) => s.wallpaper = null);
                          if (old != null && File(old).existsSync()) {
                            await File(old).delete();
                          }
                        },
                  child: const Text('Сбросить'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Размытие: ${s.blur.round()}'),
            Slider(
              value: s.blur,
              min: 0,
              max: 40,
              divisions: 40,
              label: '${s.blur.round()}',
              onChanged: (v) => state.updateSettings((s) => s.blur = v),
            ),
            Text('Непрозрачность карточек: ${(s.opacity * 100).round()}%'),
            Slider(
              value: s.opacity,
              min: .02,
              max: .20,
              divisions: 18,
              label: '${(s.opacity * 100).round()}%',
              onChanged: (v) => state.updateSettings((s) => s.opacity = v),
            ),
          ]),
        _section('Слова на главной', [
          _text('Подзаголовок', s.subtitle, (s, v) => s.subtitle = v),
          _text(
            'Приветствие',
            s.greeting,
            (s, v) => s.greeting = v,
            hint: 'Пусто — по времени суток',
          ),
          _text('Нижняя надпись', s.word, (s, v) => s.word = v),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Показывать надпись'),
            value: s.showWord,
            onChanged: (v) => state.updateSettings((s) => s.showWord = v),
          ),
        ]),
        _section('Сеть и VPN', [
          const Text(
            'Изменения применяются при следующем подключении.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (state.servers.any((server) => server.xrayConfig != null))
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('DNS из JSON-профиля'),
              subtitle: const Text(
                'Сохранить настройки DNS, заданные подпиской',
              ),
              value: s.useProfileDns,
              onChanged: (v) =>
                  state.updateSettings((s) => s.useProfileDns = v),
            ),
          SelectionField<String>(
            label: 'DNS',
            value: s.dns,
            options: const [
              SelectionOption(
                '1.1.1.1',
                'Cloudflare · 1.1.1.1',
                icon: Icons.dns_outlined,
              ),
              SelectionOption(
                '8.8.8.8',
                'Google · 8.8.8.8',
                icon: Icons.dns_outlined,
              ),
            ],
            onChanged: (v) => state.updateSettings((s) {
              s.dns = v;
              s.useProfileDns = false;
            }),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Обход локальных сетей'),
            value: s.bypassLan,
            onChanged: (v) => state.updateSettings((s) => s.bypassLan = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Per-App Proxy'),
            subtitle: const Text('Выбранные приложения идут в обход VPN'),
            value: s.perApp,
            onChanged: (v) => state.updateSettings((s) => s.perApp = v),
          ),
          ListTile(
            enabled: s.perApp,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.apps),
            title: const Text('Исключённые приложения'),
            subtitle: Text(
              'Выбрано: ${s.excludedApps.length} · приложения с ярлыком',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: s.perApp ? _chooseApps : null,
          ),
        ]),
        const Center(
          child: Text(
            'PLUSVPN · 1.1.0',
            style: TextStyle(fontSize: 11, letterSpacing: 2),
          ),
        ),
      ],
    );
  }
}

class _ColorDialog extends StatefulWidget {
  const _ColorDialog({required this.color});
  final Color color;
  @override
  State<_ColorDialog> createState() => _ColorDialogState();
}

class _ColorDialogState extends State<_ColorDialog> {
  late HSVColor color = HSVColor.fromColor(widget.color);
  late final TextEditingController hex = TextEditingController(
    text: widget.color.toARGB32().toRadixString(16).substring(2),
  );
  @override
  void dispose() {
    hex.dispose();
    super.dispose();
  }

  void update(HSVColor c) => setState(() {
    color = c;
    hex.text = c.toColor().toARGB32().toRadixString(16).substring(2);
  });
  @override
  Widget build(BuildContext context) => PlusDialog(
    title: const Text('Цвет акцента'),
    content: SizedBox(
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: color.toColor(),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: hex,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'HEX',
              prefixText: '#',
            ),
            onChanged: (v) {
              if (RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(v)) {
                setState(
                  () => color = HSVColor.fromColor(
                    Color(0xff000000 | int.parse(v, radix: 16)),
                  ),
                );
              }
            },
          ),
          const Text('Оттенок'),
          Slider(
            value: color.hue,
            max: 360,
            onChanged: (v) => update(color.withHue(v)),
          ),
          const Text('Насыщенность'),
          Slider(
            value: color.saturation,
            onChanged: (v) => update(color.withSaturation(v)),
          ),
          const Text('Яркость'),
          Slider(
            value: color.value,
            onChanged: (v) => update(color.withValue(v)),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, color.toColor()),
        child: const Text('Выбрать'),
      ),
    ],
  );
}
