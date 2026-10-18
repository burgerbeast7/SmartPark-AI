import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/formatters.dart';
import '../models/daily_summary.dart';
import '../providers/parking_provider.dart';
import 'reports_screen.dart';
import 'tariff_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardMetrics? _metrics;
  bool _isLoading = true;
  int _lastRevision = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.watch<ParkingProvider>();
    if (_lastRevision != provider.revision || _metrics == null) {
      _lastRevision = provider.revision;
      _loadMetrics();
    }
  }

  Future<void> _loadMetrics() async {
    setState(() => _isLoading = true);
    final provider = context.read<ParkingProvider>();
    final metrics = await provider.getDashboardMetrics();
    if (!mounted) return;
    setState(() {
      _metrics = metrics;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = _metrics ?? DashboardMetrics.empty();

    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartPark AI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'Reports',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Tariff Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TariffScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading && _metrics == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMetrics,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Occupancy Card
                  _buildOccupancyCard(context, metrics),
                  const SizedBox(height: 16),

                  // Today's Collection Card (Hero card)
                  _buildMetricCard(
                    context,
                    title: "Today's Collection",
                    value: AppFormatters.formatCurrency(metrics.todayCollection),
                    icon: Icons.currency_rupee_rounded,
                    color: AppConstants.primarySeedColor,
                    isHero: true,
                  ),
                  const SizedBox(height: 12),

                  // Grid of Active, Entries, Exits
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          context,
                          title: 'Active Parked',
                          value: '${metrics.activeVehicles}',
                          icon: Icons.local_parking_rounded,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          context,
                          title: 'Entries Today',
                          value: '${metrics.entriesToday}',
                          icon: Icons.login_rounded,
                          color: Colors.teal.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          context,
                          title: 'Exits Today',
                          value: '${metrics.exitsToday}',
                          icon: Icons.logout_rounded,
                          color: Colors.indigo.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          context,
                          title: 'Available Spots',
                          value: '${(metrics.capacity - metrics.activeVehicles).clamp(0, metrics.capacity)}',
                          icon: Icons.event_seat_rounded,
                          color: Colors.deepPurple.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Shortcut Action Buttons
                  Text(
                    'Quick Actions',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: AppConstants.primarySeedColor,
                          ),
                          icon: const Icon(Icons.add_circle_outline_rounded),
                          label: const Text('Vehicle Entry'),
                          onPressed: () {
                            context.read<ParkingProvider>().setTabIndex(1);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                          icon: const Icon(Icons.exit_to_app_rounded),
                          label: const Text('Vehicle Exit'),
                          onPressed: () {
                            context.read<ParkingProvider>().setTabIndex(2);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildOccupancyCard(BuildContext context, DashboardMetrics metrics) {
    final theme = Theme.of(context);
    final ratio = metrics.capacity > 0 ? (metrics.activeVehicles / metrics.capacity).clamp(0.0, 1.0) : 0.0;
    final isOver = metrics.isOverCapacity;
    final progressColor = isOver ? Colors.red.shade600 : AppConstants.primarySeedColor;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Lot Occupancy',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${metrics.activeVehicles} / ${metrics.capacity} • ${metrics.occupancyPercentage}%',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isOver ? Colors.red.shade700 : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 12,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
            if (isOver) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red.shade700),
                  const SizedBox(width: 6),
                  Text(
                    'Facility is over capacity!',
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool isHero = false,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: isHero
          ? color.withValues(alpha: 0.12)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isHero ? BorderSide(color: color.withValues(alpha: 0.4)) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: isHero ? 30 : 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: (isHero ? theme.textTheme.headlineMedium : theme.textTheme.titleLarge)?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isHero ? color : theme.colorScheme.onSurface,
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
