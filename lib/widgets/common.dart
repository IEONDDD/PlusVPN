import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../theme/app_theme.dart';

class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 28,
    this.modal = false,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool modal;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final border = BorderRadius.circular(radius);
    if (!context.isGlass) {
      return Material(
        color: modal ? colors.surfaceContainerHigh : colors.surfaceContainerLow,
        borderRadius: border,
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      );
    }
    final dark = colors.brightness == Brightness.dark;
    final opacity = context.visuals.opacity;
    final baseAlpha = modal
        ? (dark ? 0.38 : 0.48)
        : (dark
            ? (0.20 + opacity * 1.4).clamp(0.20, 0.55)
            : (0.28 + opacity * 1.4).clamp(0.28, 0.65));
    final gradient = modal
        ? null
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(
                alpha: dark ? (0.10 + opacity * 0.8) : (0.35 + opacity * 0.8),
              ),
              (dark ? const Color(0xff141c26) : Colors.white).withValues(
                alpha: baseAlpha * 0.85,
              ),
              (dark ? const Color(0xff0d131b) : const Color(0xffe4ecf7))
                  .withValues(
                alpha: baseAlpha,
              ),
            ],
            stops: const [0.0, 0.45, 1.0],
          );
    final fallbackColor = modal
        ? (dark ? const Color(0xff10161c) : Colors.white).withValues(
            alpha: dark ? 0.35 : 0.45,
          )
        : null;
    return ClipRRect(
      borderRadius: border,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: modal ? 20 : 8,
          sigmaY: modal ? 20 : 8,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: border,
            color: fallbackColor,
            gradient: gradient,
            border: Border.all(
              color: Colors.white.withValues(alpha: dark ? .18 : .52),
              width: .8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.22 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

// Compatibility name for the reusable cards used across all three tabs.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    required this.state,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final AppState state;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) =>
      AppSurface(padding: padding, child: child);
}

class PlusDialog extends StatelessWidget {
  const PlusDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions = const [],
  });
  final Widget title, content;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    elevation: 0,
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 480,
        maxHeight: MediaQuery.sizeOf(context).height * .88,
      ),
      child: AppSurface(
        modal: true,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DefaultTextStyle(
              style: Theme.of(context).textTheme.titleLarge!,
              child: title,
            ),
            const SizedBox(height: 20),
            Flexible(child: SingleChildScrollView(child: content)),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class SelectionOption<T> {
  const SelectionOption(
    this.value,
    this.title, {
    this.subtitle,
    this.icon,
    this.textStyle,
  });
  final T value;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final TextStyle? textStyle;
}

Future<T?> showPlusDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => showDialog<T>(
  context: context,
  builder: builder,
  barrierColor: Colors.black.withValues(alpha: context.isGlass ? .18 : .4),
);

class SelectionField<T> extends StatelessWidget {
  const SelectionField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
  });
  final String label;
  final T value;
  final List<SelectionOption<T>> options;
  final ValueChanged<T> onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final selected = options.where((o) => o.value == value).firstOrNull;
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '$label: ${selected?.title ?? ''}',
      child: Material(
        color: context.isGlass
            ? colors.onSurface.withValues(alpha: .035)
            : colors.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: colors.outlineVariant.withValues(
              alpha: context.isGlass ? .28 : .65,
            ),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled
              ? () async {
                  final chosen = await showSelectionSheet<T>(
                    context,
                    title: label,
                    value: value,
                    options: options,
                  );
                  if (chosen != null) onChanged(chosen);
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                if (selected?.icon case final IconData icon) ...[
                  Icon(icon, size: 23),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selected?.title ?? '',
                        style:
                            selected?.textStyle ??
                            const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.unfold_more_rounded, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<T?> showSelectionSheet<T>(
  BuildContext context, {
  required String title,
  required T value,
  required List<SelectionOption<T>> options,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  barrierColor: Colors.black.withValues(alpha: context.isGlass ? .18 : .4),
  builder: (ctx) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * .75,
        ),
        child: AppSurface(
          modal: true,
          radius: 32,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    ctx,
                  ).colorScheme.onSurface.withValues(alpha: .22),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(ctx).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Закрыть',
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: options.map((option) {
                    final selected = option.value == value;
                    final colors = Theme.of(ctx).colorScheme;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Material(
                        color: selected
                            ? (ctx.isGlass
                                  ? colors.primary.withValues(alpha: .14)
                                  : colors.secondaryContainer)
                            : Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                          side: selected && ctx.isGlass
                              ? BorderSide(
                                  color: colors.primary.withValues(alpha: .25),
                                )
                              : BorderSide.none,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 7,
                          ),
                          leading: option.icon == null
                              ? null
                              : Icon(option.icon),
                          title: Text(option.title, style: option.textStyle),
                          subtitle: option.subtitle == null
                              ? null
                              : Text(option.subtitle!),
                          trailing: Icon(
                            selected
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            color: selected ? colors.primary : colors.outline,
                          ),
                          onTap: () => Navigator.pop(ctx, option.value),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

Future<void> showImportDialog(BuildContext context, AppState state) async {
  final input = TextEditingController();
  final result = await showDialog<(String, bool)>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: context.isGlass ? .18 : .4),
    builder: (ctx) => PlusDialog(
      title: const Text('Добавить подключение'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Вставьте ссылку подписки, ключ или JSON Xray.'),
            const SizedBox(height: 16),
            TextField(
              controller: input,
              minLines: 3,
              maxLines: 6,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Ссылка, ключ или JSON',
                hintText: 'https://… или [{"remarks": …}]',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (ctx.mounted) input.text = data?.text ?? '';
                  },
                  icon: const Icon(Icons.content_paste_rounded),
                  label: const Text('Из буфера'),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.pop(ctx, ('', true)),
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('JSON-файл'),
                ),
              ],
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
          onPressed: () => Navigator.pop(ctx, (input.text, false)),
          child: const Text('Добавить'),
        ),
      ],
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 300));
  input.dispose();
  if (result == null) return;
  String? content = result.$1;
  if (result.$2) {
    try {
      content = await state.engine.pickConfigFile();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть JSON-файл')),
        );
      }
      return;
    }
  }
  if (content == null || content.trim().isEmpty) return;
  final count = await state.importText(content);
  if (context.mounted && count != null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Добавлено профилей: $count')));
  }
}

Color pingColor(int? value) => value == null
    ? Colors.grey
    : value < 0
    ? Colors.redAccent
    : value < 150
    ? const Color(0xff7ecb87)
    : value < 350
    ? Colors.amber
    : Colors.redAccent;
String pingLabel(int? value) => value == null
    ? '—'
    : value < 0
    ? 'Нет ответа'
    : '$value ms';
String gigabytes(int bytes) => (bytes / 1073741824).toStringAsFixed(1);
