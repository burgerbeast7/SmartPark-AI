import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/constants.dart';
import '../core/formatters.dart';
import '../models/daily_summary.dart';
import '../providers/parking_provider.dart';
import '../services/csv_service.dart';

enum ReportTimeWindow { today, sevenDays, thirtyDays }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportTimeWindow _timeWindow = ReportTimeWindow.today;
  ReportSummary? _summary;
  bool _isLoading = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  int get _fromMs {
    switch (_timeWindow) {
      case ReportTimeWindow.today:
        return AppFormatters.startOfTodayMs();
      case ReportTimeWindow.sevenDays:
        return AppFormatters.startOfDaysAgoMs(7);
      case ReportTimeWindow.thirtyDays:
        return AppFormatters.startOfDaysAgoMs(30);
    }
  }

  int get _toMs => AppFormatters.endOfTodayMs();

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    final provider = context.read<ParkingProvider>();
    final summary = await provider.getReports(fromMs: _fromMs, toMs: _toMs);
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _isLoading = false;
    });
  }

  Future<void> _exportCsv() async {
    setState(() => _isExporting = true);
    final provider = context.read<ParkingProvider>();

    try {
      final sessions = await provider.getHistory(
        fromMs: _fromMs,
        toMs: _toMs,
        limit: 10000,
      );

      if (sessions.isEmpty) {
        if (!mounted) return;
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No completed sessions to export for this period.')),
        );
        return;
      }

      final csvFile = await CsvService.writeCsvToTempFile(sessions);
      if (!mounted) return;
      setState(() => _isExporting = false);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(csvFile.path)],
          text: 'SmartPark AI Transaction Report',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = _summary ?? ReportSummary.empty();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        actions: [
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
            tooltip: 'Export CSV',
            onPressed: _isExporting ? null : _exportCsv,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Today'),
                  selected: _timeWindow == ReportTimeWindow.today,
                  onSelected: (val) {
                    if (val) {
                      setState(() => _timeWindow = ReportTimeWindow.today);
                      _loadReports();
                    }
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Last 7 Days'),
                  selected: _timeWindow == ReportTimeWindow.sevenDays,
                  onSelected: (val) {
                    if (val) {
                      setState(() => _timeWindow = ReportTimeWindow.sevenDays);
                      _loadReports();
                    }
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Last 30 Days'),
                  selected: _timeWindow == ReportTimeWindow.thirtyDays,
                  onSelected: (val) {
                    if (val) {
                      setState(() => _timeWindow = ReportTimeWindow.thirtyDays);
                      _loadReports();
                    }
                  },
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadReports,
                    child: ListView(
                      padding: const EdgeInsets.all(16.0),
                      children: [
                        // Summary Card
                        Card(
                          elevation: 0,
                          color: AppConstants.primarySeedColor.withValues(alpha: 0.08),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: AppConstants.primarySeedColor.withValues(alpha: 0.3)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Financial Summary',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppConstants.primarySeedColor,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildMetricTile(
                                        'Completed Exits',
                                        '${summary.completedCount}',
                                        Colors.blue.shade700,
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildMetricTile(
                                        'Total Billed',
                                        AppFormatters.formatCurrency(summary.totalBilled),
                                        Colors.purple.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildMetricTile(
                                        'Collected',
                                        AppFormatters.formatCurrency(summary.totalCollected),
                                        Colors.green.shade700,
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildMetricTile(
                                        'Pending / Unpaid',
                                        AppFormatters.formatCurrency(summary.totalUnpaid),
                                        Colors.orange.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Export CSV Action Card
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.file_download_rounded),
                          label: const Text('Export RFC 4180 CSV via Share Sheet'),
                          onPressed: _isExporting ? null : _exportCsv,
                        ),
                        const SizedBox(height: 24),

                        // Daily Totals Section
                        Text(
                          'Daily Breakdown',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),

                        if (summary.dailyRows.isEmpty) ...[
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 36.0),
                              child: Text(
                                'No completed sessions in this date range.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: theme.colorScheme.outlineVariant),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: summary.dailyRows.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (ctx, idx) {
                                final row = summary.dailyRows[idx];
                                return ListTile(
                                  title: Text(row.dateString, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('${row.exitsCount} exits • Collected: ₹${row.totalCollected}'),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        AppFormatters.formatCurrency(row.totalBilled),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      if (row.totalUnpaid > 0)
                                        Text(
                                          'Unpaid: ₹${row.totalUnpaid}',
                                          style: TextStyle(color: Colors.orange.shade800, fontSize: 11),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
