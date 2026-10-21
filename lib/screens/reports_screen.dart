import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/constants.dart';
import '../core/formatters.dart';
import '../models/daily_summary.dart';
import '../providers/parking_provider.dart';
import '../services/csv_service.dart';
import '../widgets/ambient_background.dart';
import '../widgets/glass_container.dart';

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
          text: 'SmartPark AI Transaction Report • ${AppConstants.copyrightShort}',
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Reports & Analytics',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.3),
        ),
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
      body: AmbientBackground(
        child: Column(
          children: [
            // Filter Pills inside GlassContainer
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 6.0, 16.0, 10.0),
              child: GlassContainer(
                borderRadius: 16,
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _buildTimeTab('Today', ReportTimeWindow.today),
                    const SizedBox(width: 4),
                    _buildTimeTab('7 Days', ReportTimeWindow.sevenDays),
                    const SizedBox(width: 4),
                    _buildTimeTab('30 Days', ReportTimeWindow.thirtyDays),
                  ],
                ),
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadReports,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 32.0),
                        children: [
                          // Financial Summary Glass Card
                          GlassContainer(
                            borderRadius: 22,
                            padding: const EdgeInsets.all(18.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: AppConstants.primarySeedColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.analytics_rounded,
                                        size: 18,
                                        color: AppConstants.primarySeedColor,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Financial Overview',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildMetricTile(
                                        'Completed Exits',
                                        '${summary.completedCount}',
                                        const Color(0xFF0284C7),
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildMetricTile(
                                        'Total Billed',
                                        AppFormatters.formatCurrency(summary.totalBilled),
                                        const Color(0xFF6366F1),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildMetricTile(
                                        'Collected',
                                        AppFormatters.formatCurrency(summary.totalCollected),
                                        const Color(0xFF10B981),
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildMetricTile(
                                        'Pending / Unpaid',
                                        AppFormatters.formatCurrency(summary.totalUnpaid),
                                        const Color(0xFFF59E0B),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Export CSV Button with subtle glow
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppConstants.primarySeedColor.withValues(alpha: 0.25),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                                backgroundColor: AppConstants.primarySeedColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(Icons.file_download_rounded),
                              label: const Text(
                                'Export RFC 4180 CSV via Share Sheet',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              onPressed: _isExporting ? null : _exportCsv,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Daily Totals Section
                          Text(
                            'Daily Breakdown',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 12),

                          if (summary.dailyRows.isEmpty) ...[
                            GlassContainer(
                              borderRadius: 20,
                              padding: const EdgeInsets.symmetric(vertical: 36.0, horizontal: 20.0),
                              child: Center(
                                child: Text(
                                  'No completed sessions in this date range.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ] else ...[
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: summary.dailyRows.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (ctx, idx) {
                                final row = summary.dailyRows[idx];
                                return GlassContainer(
                                  borderRadius: 16,
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            row.dateString,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${row.exitsCount} exits • Collected: ₹${row.totalCollected}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            AppFormatters.formatCurrency(row.totalBilled),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                              color: AppConstants.primarySeedColor,
                                            ),
                                          ),
                                          if (row.totalUnpaid > 0)
                                            Text(
                                              'Unpaid: ₹${row.totalUnpaid}',
                                              style: const TextStyle(
                                                color: Color(0xFFD97706),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 11,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                          const SizedBox(height: 28),

                          // Kunal Chauhan Copyright Footer
                          Center(
                            child: Text(
                              'SmartPark AI • ${AppConstants.copyrightNotice}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2,
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeTab(String label, ReportTimeWindow window) {
    final isSelected = _timeWindow == window;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!isSelected) {
            setState(() => _timeWindow = window);
            _loadReports();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppConstants.primarySeedColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppConstants.primarySeedColor.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color color) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
            color: color,
          ),
        ),
      ],
    );
  }
}

