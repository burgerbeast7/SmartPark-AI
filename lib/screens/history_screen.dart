import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/formatters.dart';
import '../models/parking_session.dart';
import '../providers/parking_provider.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parking History'),
      ),
      body: Column(
        children: [
          // Filter Chips and Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    FilterChip(
                      label: const Text('Today'),
                      selected: _selectedFilter == HistoryFilter.today,
                      onSelected: (val) {
                        if (val) {
                          setState(() => _selectedFilter = HistoryFilter.today);
                          _loadHistory();
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('7 Days'),
                      selected: _selectedFilter == HistoryFilter.sevenDays,
                      onSelected: (val) {
                        if (val) {
                          setState(() => _selectedFilter = HistoryFilter.sevenDays);
                          _loadHistory();
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('All'),
                      selected: _selectedFilter == HistoryFilter.all,
                      onSelected: (val) {
                        if (val) {
                          setState(() => _selectedFilter = HistoryFilter.all);
                          _loadHistory();
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search History',
                    hintText: 'Search completed plate',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),

          // List or Empty State
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _completedSessions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_rounded, size: 64, color: theme.colorScheme.outlineVariant),
                            const SizedBox(height: 16),
                            Text(
                              'No completed sessions',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadHistory,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          itemCount: _completedSessions.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (ctx, idx) {
                            final session = _completedSessions[idx];
                            final isPaid = session.payment?.paymentStatus == AppConstants.paymentStatusPaid;

                            return Card(
                              elevation: 0,
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(color: theme.colorScheme.outlineVariant),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                leading: CircleAvatar(
                                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                  child: Icon(
                                    session.category == AppConstants.categoryBike
                                        ? Icons.two_wheeler_rounded
                                        : Icons.directions_car_rounded,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                title: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      session.plateNumber,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    Text(
                                      AppFormatters.formatCurrency(session.amount ?? 0),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: AppConstants.primarySeedColor,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Exit: ${AppFormatters.formatDateTime(session.exitTime)}'),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isPaid ? Colors.green.shade50 : Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        isPaid ? 'PAID' : 'UNPAID',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isPaid ? Colors.green.shade800 : Colors.orange.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                                onTap: () {
                                  // Tap opens Receipt screen (Section 18)
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ReceiptScreen(sessionId: session.id!),
                                    ),
                                  );
                                },
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
}
