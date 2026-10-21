import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/formatters.dart';
import '../models/parking_session.dart';
import '../providers/parking_provider.dart';
import '../widgets/glass_container.dart';
import 'receipt_screen.dart';

enum HistoryFilter { today, sevenDays, all }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  HistoryFilter _selectedFilter = HistoryFilter.today;
  List<ParkingSession> _completedSessions = [];
  bool _isLoading = true;
  int _lastRevision = -1;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.watch<ParkingProvider>();
    if (_lastRevision != provider.revision) {
      _lastRevision = provider.revision;
      _loadHistory();
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final provider = context.read<ParkingProvider>();

    int? fromMs;
    if (_selectedFilter == HistoryFilter.today) {
      fromMs = AppFormatters.startOfTodayMs();
    } else if (_selectedFilter == HistoryFilter.sevenDays) {
      fromMs = AppFormatters.startOfDaysAgoMs(7);
    }

    final sessions = await provider.getHistory(
      plateQuery: _searchController.text.trim(),
      fromMs: fromMs,
      limit: 500,
    );

    if (!mounted) return;
    setState(() {
      _completedSessions = sessions;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Parking History',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.3),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips and Search inside GlassContainer
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: GlassContainer(
              borderRadius: 18,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Segmented Filter Bar
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.25)
                          : Colors.grey.shade100.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _buildFilterTab(
                          label: 'Today',
                          filter: HistoryFilter.today,
                          icon: Icons.today_rounded,
                        ),
                        const SizedBox(width: 4),
                        _buildFilterTab(
                          label: '7 Days',
                          filter: HistoryFilter.sevenDays,
                          icon: Icons.date_range_rounded,
                        ),
                        const SizedBox(width: 4),
                        _buildFilterTab(
                          label: 'All Time',
                          filter: HistoryFilter.all,
                          icon: Icons.all_inclusive_rounded,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Search Field
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Search completed vehicle plate...',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: AppConstants.primarySeedColor,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 20),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.03),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppConstants.primarySeedColor,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // List or Empty State
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _completedSessions.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: GlassContainer(
                            borderRadius: 24,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppConstants.primarySeedColor.withValues(alpha: 0.12),
                                  ),
                                  child: Icon(
                                    Icons.history_toggle_off_rounded,
                                    size: 36,
                                    color: AppConstants.primarySeedColor,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No Completed Sessions',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Completed vehicle exits and paid receipts will appear here.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'SmartPark AI • ${AppConstants.copyrightShort}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadHistory,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                          itemCount: _completedSessions.length + 1,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (ctx, idx) {
                            if (idx == _completedSessions.length) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 10.0, bottom: 6.0),
                                  child: Text(
                                    'SmartPark AI • ${AppConstants.copyrightShort}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
                                    ),
                                  ),
                                ),
                              );
                            }

                            final session = _completedSessions[idx];
                            final isPaid =
                                session.payment?.paymentStatus == AppConstants.paymentStatusPaid;
                            final isBike = session.category == AppConstants.categoryBike;

                            return GlassContainer(
                              borderRadius: 18,
                              padding: const EdgeInsets.all(14),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ReceiptScreen(sessionId: session.id!),
                                  ),
                                );
                              },
                              child: Row(
                                children: [
                                  // Category Avatar Jewel
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: isBike
                                            ? [
                                                const Color(0xFF6366F1),
                                                const Color(0xFF8B5CF6),
                                              ]
                                            : [
                                                const Color(0xFF0E8C7F),
                                                const Color(0xFF0EA5E9),
                                              ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (isBike
                                                  ? const Color(0xFF6366F1)
                                                  : const Color(0xFF0E8C7F))
                                              .withValues(alpha: 0.28),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      isBike
                                          ? Icons.two_wheeler_rounded
                                          : Icons.directions_car_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Details Column
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          session.plateNumber,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.access_time_rounded,
                                              size: 13,
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                'Exit: ${AppFormatters.formatDateTime(session.exitTime)}',
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: theme.colorScheme.onSurfaceVariant,
                                                  fontSize: 12,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Amount & Status Badge
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        AppFormatters.formatCurrency(session.amount ?? 0),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                          color: AppConstants.primarySeedColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isPaid
                                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                              : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isPaid
                                                ? const Color(0xFF10B981).withValues(alpha: 0.5)
                                                : const Color(0xFFF59E0B).withValues(alpha: 0.5),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          isPaid ? 'PAID' : 'UNPAID',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                            color: isPaid
                                                ? const Color(0xFF059669)
                                                : const Color(0xFFD97706),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab({
    required String label,
    required HistoryFilter filter,
    required IconData icon,
  }) {
    final isSelected = _selectedFilter == filter;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!isSelected) {
            setState(() => _selectedFilter = filter);
            _loadHistory();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppConstants.primarySeedColor
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

