import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/order.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/qb_widgets.dart';

/// Admin overview: operational summary + cross-customer order list.
///
/// Uses the real backend endpoints:
/// - GET /api/v1/admin/summary (counts by status, outbox/retry/quarantine)
/// - GET /api/v1/admin/orders (paginated, status filter)
///
/// Route-protected: non-admin users are redirected by the router before
/// this screen builds. All values come from the API — nothing invented.
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  String? _statusFilter;
  int _page = 1;

  static const _statuses = [
    'PENDING',
    'PAID',
    'CONFIRMED',
    'DRIVER_ASSIGNED',
    'PAYMENT_FAILED',
    'FAILED',
    'CANCELLED',
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final user = ref.watch(authStateProvider).user;

    // Defensive: router already guards, but never render admin UI
    // for non-admins.
    if (user?.role != UserRole.admin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin')),
        body: QbEmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Access denied',
          message: 'This area is restricted to administrators.',
          actionLabel: 'Back to home',
          onAction: () => context.go('/'),
        ),
      );
    }

    final summaryAsync = ref.watch(adminSummaryProvider);
    final ordersAsync =
        ref.watch(adminOrdersProvider((page: _page, status: _statusFilter)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin overview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(adminSummaryProvider);
              ref.invalidate(adminOrdersProvider);
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(adminSummaryProvider);
              ref.invalidate(adminOrdersProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ---- Summary ----
                Text('Operations summary',
                    style:
                        Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                summaryAsync.when(
                  data: (s) => _SummaryGrid(summary: s),
                  loading: () => const SizedBox(
                    height: 120,
                    child:
                        QbLoading(message: 'Loading summary…'),
                  ),
                  error: (e, _) => _InlineError(
                    message:
                        'Could not load summary: ${_shortError(e)}',
                    onRetry: () =>
                        ref.invalidate(adminSummaryProvider),
                  ),
                ),
                const SizedBox(height: 28),

                // ---- Orders ----
                Row(
                  children: [
                    Expanded(
                      child: Text('All orders',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge),
                    ),
                    if (_statusFilter != null)
                      TextButton.icon(
                        icon:
                            const Icon(Icons.clear_rounded, size: 18),
                        label: const Text('Clear filter'),
                        onPressed: () => setState(() {
                          _statusFilter = null;
                          _page = 1;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Status filter chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: _statusFilter == null,
                      onTap: () => setState(() {
                        _statusFilter = null;
                        _page = 1;
                      }),
                    ),
                    for (final st in _statuses)
                      _FilterChip(
                        label: _prettyStatus(st),
                        selected: _statusFilter == st,
                        onTap: () => setState(() {
                          _statusFilter = st;
                          _page = 1;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                ordersAsync.when(
                  data: (page) => _OrderList(
                    page: page,
                    currentPage: _page,
                    onPage: (p) =>
                        setState(() => _page = p),
                  ),
                  loading: () => const SizedBox(
                    height: 200,
                    child:
                        QbLoading(message: 'Loading orders…'),
                  ),
                  error: (e, _) => _InlineError(
                    message:
                        'Could not load orders: ${_shortError(e)}',
                    onRetry: () =>
                        ref.invalidate(adminOrdersProvider),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _shortError(Object e) {
    final s = e.toString();
    return s.length > 120 ? '${s.substring(0, 120)}…' : s;
  }

  String _prettyStatus(String s) {
    return s
        .split('_')
        .map((w) =>
            w.isEmpty ? w : w[0] + w.substring(1).toLowerCase())
        .join(' ');
  }
}

/// Grid of summary stat cards.
class _SummaryGrid extends ConsumerWidget {
  final AdminSummary summary;
  const _SummaryGrid({required this.summary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);

    final statusCards = summary.byStatus.entries.map(
      (e) => _StatCard(
        label: _pretty(e.key),
        value: '${e.value}',
        icon: Icons.receipt_long_outlined,
        color: _statusColor(e.key, tokens),
      ),
    );

    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth > 800 ? 4 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: cols,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            ...statusCards,
            _StatCard(
              label: 'Total orders',
              value: '${summary.totalOrders}',
              icon: Icons.inventory_2_outlined,
              color: tokens.primary,
            ),
            _StatCard(
              label: 'Outbox pending',
              value: '${summary.outboxPending}',
              icon: Icons.outbox_rounded,
              color: summary.outboxPending > 0
                  ? tokens.warning
                  : tokens.success,
            ),
            _StatCard(
              label: 'Retry backlog',
              value: '${summary.retryPending}',
              icon: Icons.replay_rounded,
              color: summary.retryPending > 0
                  ? tokens.warning
                  : tokens.success,
            ),
            _StatCard(
              label: 'Quarantined',
              value: '${summary.quarantineCount}',
              icon: Icons.warning_amber_rounded,
              color: summary.quarantineCount > 0
                  ? tokens.danger
                  : tokens.success,
            ),
          ],
        );
      },
    );
  }

  String _pretty(String s) => s
      .split('_')
      .map((w) => w.isEmpty ? w : w[0] + w.substring(1).toLowerCase())
      .join(' ');

  Color _statusColor(String s, tokens) {
    switch (s) {
      case 'PENDING':
        return tokens.warning;
      case 'PAID':
      case 'CONFIRMED':
        return tokens.success;
      case 'DRIVER_ASSIGNED':
        return tokens.primary;
      default:
        return tokens.danger;
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return QbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .displayMedium
                  ?.copyWith(fontSize: 26)),
          Text(label,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _FilterChip extends ConsumerWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: tokens.primary,
      labelStyle: TextStyle(
        color: selected ? tokens.onPrimary : tokens.text,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
            color: selected ? tokens.primary : tokens.border),
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  final PaginatedOrders page;
  final int currentPage;
  final void Function(int) onPage;

  const _OrderList({
    required this.page,
    required this.currentPage,
    required this.onPage,
  });

  @override
  Widget build(BuildContext context) {
    if (page.items.isEmpty) {
      return QbEmptyState(
        icon: Icons.inbox_outlined,
        title: 'No orders',
        message: 'No orders match the current filter.',
      );
    }

    final totalPages =
        (page.total / page.pageSize).ceil().clamp(1, 1 << 30);

    return Column(
      children: [
        for (final order in page.items) ...[
          _AdminOrderCard(order: order),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        // Pagination
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: currentPage > 1
                  ? () => onPage(currentPage - 1)
                  : null,
              child: const Text('← Prev'),
            ),
            Flexible(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Page $currentPage of $totalPages (${page.total} total)',
                  style:
                      Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            TextButton(
              onPressed: currentPage < totalPages
                  ? () => onPage(currentPage + 1)
                  : null,
              child: const Text('Next →'),
            ),
          ],
        ),
      ],
    );
  }
}

class _AdminOrderCard extends ConsumerWidget {
  final Order order;
  const _AdminOrderCard({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    return QbCard(
      onTap: () => context.go('/order/${order.id}/tracking'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order #${order.id.length > 8 ? order.id.substring(0, 8) : order.id}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${order.items.length} items · v${order.version} · ${_date(order.createdAt)}',
                  style:
                      Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(formatInr(order.totalAmountMinor),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: tokens.primary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _statusColor(order.status, tokens)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _pretty(order.status),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _statusColor(order.status, tokens)),
            ),
          ),
        ],
      ),
    );
  }

  String _pretty(OrderStatus s) {
    final raw = s.toString().split('.').last;
    return raw
        .split(RegExp(r'(?=[A-Z])'))
        .join(' ')
        .trim();
  }

  Color _statusColor(OrderStatus s, tokens) {
    switch (s) {
      case OrderStatus.pending:
        return tokens.warning;
      case OrderStatus.paid:
      case OrderStatus.confirmed:
        return tokens.success;
      case OrderStatus.driverAssigned:
        return tokens.primary;
      default:
        return tokens.danger;
    }
  }

  String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

class _InlineError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _InlineError(
      {required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return QbCard(
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
          TextButton(
              onPressed: onRetry,
              child: const Text('Retry')),
        ],
      ),
    );
  }
}
