import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/formatters.dart';
import '../models/parking_session.dart';
import '../providers/parking_provider.dart';

class ActiveScreen extends StatefulWidget {
  const ActiveScreen({super.key});

  @override
  State<ActiveScreen> createState() => _ActiveScreenState();
}

class _ActiveScreenState extends State<ActiveScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<ParkingSession> _activeSessions = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  int _lastRevision = -1;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    // Refresh live elapsed time every minute (Section 18)
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.watch<ParkingProvider>();
    if (_lastRevision != provider.revision) {
      _lastRevision = provider.revision;
      _loadActiveVehicles();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel(); // Cancel timer in dispose (Section 22)
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _loadActiveVehicles();
  }

  Future<void> _loadActiveVehicles() async {
    final provider = context.read<ParkingProvider>();
    final list = await provider.getActiveVehicles(
      query: _searchController.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _activeSessions = list;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;

    return Scaffold(
      appBar: AppBar(
        title: Text('Active Parking (${_activeSessions.length})'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Parked Vehicles',
                hintText: 'Filter by plate number',
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
          ),

          // Vehicle List or Empty State
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _activeSessions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_parking_rounded, size: 64, color: theme.colorScheme.outlineVariant),
                            const SizedBox(height: 16),
                            Text(
                              'No vehicles parked',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadActiveVehicles,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          itemCount: _activeSessions.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (ctx, idx) {
                            final session = _activeSessions[idx];
                            final elapsedMin = (nowMs - session.entryTime) ~/ 60000;

                            return Card(
                              elevation: 0,
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(color: theme.colorScheme.outlineVariant),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor: AppConstants.primarySeedColor.withValues(alpha: 0.15),
                                  child: Icon(
                                    session.category == AppConstants.categoryBike
                                        ? Icons.two_wheeler_rounded
                                        : Icons.directions_car_rounded,
                                    color: AppConstants.primarySeedColor,
                                  ),
                                ),
                                title: Text(
                                  session.plateNumber,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text('Parked: ${AppFormatters.formatDateTime(session.entryTime)}'),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(Icons.timer_outlined, size: 14, color: theme.colorScheme.primary),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Elapsed: ${AppFormatters.formatDuration(elapsedMin)}',
                                          style: TextStyle(
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: FilledButton.tonal(
                                  onPressed: () {
                                    // Tap opens Exit screen with plate pre-filled (Section 18)
                                    context.read<ParkingProvider>().openExitWithPlate(session.plateNumber);
                                  },
                                  child: const Text('Exit'),
                                ),
                                onTap: () {
                                  context.read<ParkingProvider>().openExitWithPlate(session.plateNumber);
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
