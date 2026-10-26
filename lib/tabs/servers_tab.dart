import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class ServersTab extends StatelessWidget {
  const ServersTab({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final sub = state.activeSubscription;
    final list = state.visibleServers;
    return CustomScrollView(
      key: const PageStorageKey('servers'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Серверы',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: context.isGlass
                              ? FontWeight.w300
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Добавить',
                      onPressed: state.busy
                          ? null
                          : () => showImportDialog(context, state),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                GlassCard(
                  state: state,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: SelectionField<String>(
                              label: 'Подписка',
                              value: state.activeSubscriptionId ?? '',
                              onChanged: (id) =>
                                  state.setFilter(id == '' ? null : id),
                              options: [
                                const SelectionOption(
                                  '',
                                  'Все серверы',
                                  icon: Icons.public_rounded,
                                ),
                                ...state.subscriptions.map(
                                  (s) => SelectionOption(
                                    s.id,
                                    s.title,
                                    icon: Icons.folder_outlined,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (sub != null) ...[
                            IconButton(
                              tooltip: 'Обновить подписку',
                              onPressed: state.busy
                                  ? null
                                  : () => state.importText(sub.url),
                              icon: const Icon(Icons.refresh),
                            ),
                            IconButton(
                              tooltip: 'Удалить подписку',
                              onPressed: state.busy
                                  ? null
                                  : () async {
                                      final confirm = await showPlusDialog<bool>(
                                        context: context,
                                        builder: (ctx) => PlusDialog(
                                          title: const Text(
                                            'Удалить подписку?',
                                          ),
                                          content: Text(
                                            'Будут удалены все серверы «${sub.title}».',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text('Отмена'),
                                            ),
                                            FilledButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text('Удалить'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await state.removeSubscription(sub);
                                      }
                                    },
                              icon: const Icon(Icons.delete_outline, size: 20),
                            ),
                          ],
                        ],
                      ),
                      if (sub != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          '${gigabytes(sub.used)} ГБ / ${sub.total > 0 ? '${gigabytes(sub.total)} ГБ' : 'Безлимит'}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        const SizedBox(height: 14),
                        LinearProgressIndicator(
                          value: sub.progress,
                          borderRadius: BorderRadius.circular(9),
                          minHeight: 6,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          sub.daysLeft == null
                              ? 'Срок действия не указан'
                              : sub.daysLeft! <= 0
                              ? 'Подписка истекла'
                              : 'Осталось дней: ${sub.daysLeft}',
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        Text(
                          '${state.servers.length} серверов · ${state.subscriptions.length} подписок',
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: state.pinging || list.isEmpty
                            ? null
                            : state.pingAll,
                        icon: state.pinging
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.bolt),
                        label: Text(
                          state.pinging ? 'Проверка…' : 'Проверить пинг',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: state.sortByPing
                          ? 'Сортировка по пингу'
                          : 'Сортировка по имени',
                      onPressed: state.toggleSort,
                      icon: Icon(
                        state.sortByPing ? Icons.speed : Icons.sort_by_alpha,
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'TCP-пинг до сервера · включая DNS',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
                if (state.busy) const LinearProgressIndicator(),
              ],
            ),
          ),
        ),
        if (list.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.public, size: 52),
                    const SizedBox(height: 16),
                    const Text(
                      'Ваш следующий маршрут',
                      style: TextStyle(fontSize: 22),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Добавьте ключ или подписку, чтобы начать',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: state.busy
                          ? null
                          : () => showImportDialog(context, state),
                      child: const Text('Добавить сервер'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            sliver: SliverList.builder(
              itemCount: list.length,
              itemBuilder: (context, index) {
                final s = list[index];
                final selected = state.selectedId == s.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    state: state,
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 7,
                      ),
                      onTap: state.busy || state.transitioning
                          ? null
                          : () => state.select(s),
                      leading: Text(
                        s.flag,
                        style: const TextStyle(fontSize: 28),
                      ),
                      title: Text(
                        s.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Row(
                          children: [
                            Text(
                              s.protocolLabel,
                              style: const TextStyle(fontSize: 11),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              pingLabel(s.ping),
                              style: TextStyle(
                                color: pingColor(s.ping),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (selected)
                            Icon(
                              Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          IconButton(
                            tooltip: 'Удалить сервер',
                            onPressed: state.busy
                                ? null
                                : () => state.removeServer(s),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
