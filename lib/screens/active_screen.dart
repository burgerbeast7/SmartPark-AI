import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/formatters.dart';
import '../models/parking_session.dart';
import '../providers/parking_provider.dart';
import '../widgets/glass_container.dart';

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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Active Parking (${_activeSessions.length})',
          style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.3),
        ),
      ),
      body: Column(
        children: [
          // Glass Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 12.0),
            child: GlassContainer(
              borderRadius: 16,
              blur: 14,
              opacity: 0.75,
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 2.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search active plates...',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppConstants.primarySeedColor.withValues(alpha: 0.8),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ),

          // Vehicle List or Empty State
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _activeSessions.isEmpty
                    ? Center(
                        child: GlassContainer(
                          borderRadius: 24,
                          blur: 16,
                          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 36.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppConstants.primarySeedColor.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.local_parking_rounded,
                                  size: 48,
                                  color: AppConstants.primarySeedColor.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No vehicles parked',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'New vehicle entries will appear here live.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
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
                      )
                    : RefreshIndicator(
                        onRefresh: _loadActiveVehicles,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 110.0),
                          itemCount: _activeSessions.length + 1,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (ctx, idx) {
                            if (idx == _activeSessions.length) {
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

                            final session = _activeSessions[idx];
                            final elapsedMin = (nowMs - session.entryTime) ~/ 60000;
                            final isBike = session.category == AppConstants.categoryBike;

                            return GlassContainer(
                              borderRadius: 18,
                              blur: 14,
                              opacity: 0.72,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              onTap: () {
                                context.read<ParkingProvider>().openExitWithPlate(session.plateNumber);
                              },
                              child: Row(
                                children: [
                                  // Category Avatar Icon with Gradient
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: isBike
                                            ? [const Color(0xFF0284C7), const Color(0xFF0369A1)]
                                            : [AppConstants.primarySeedColor, const Color(0xFF0F766E)],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (isBike ? const Color(0xFF0284C7) : AppConstants.primarySeedColor)
                                              .withValues(alpha: 0.28),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      isBike ? Icons.two_wheeler_rounded : Icons.directions_car_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Plate & Duration
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          session.plateNumber,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Parked: ${AppFormatters.formatDateTime(session.entryTime)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppConstants.primarySeedColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.timer_outlined,
                                                size: 13,
                                                color: AppConstants.primarySeedColor,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                AppFormatters.formatDuration(elapsedMin),
                                                style: const TextStyle(
                                                  color: AppConstants.primarySeedColor,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Exit Button
                                  FilledButton.tonal(
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () {
                                      context.read<ParkingProvider>().openExitWithPlate(session.plateNumber);
                                    },
                                    child: const Text(
                                      'Exit',
                                      style: TextStyle(fontWeight: FontWeight.w700),
                                    ),
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
}
