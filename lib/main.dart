import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/constants.dart';
import 'data/app_database.dart';
import 'data/repositories/parking_repository.dart';
import 'data/repositories/tariff_repository.dart';
import 'providers/parking_provider.dart';
import 'services/parking_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock portrait only (Section 13)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const AppInitializer());
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  Future<ParkingProvider>? _initFuture;

  @override
  void initState() {
    super.initState();
    _startInitialization();
  }

  void _startInitialization() {
    setState(() {
      _initFuture = _initializeDependencies();
    });
  }

  Future<ParkingProvider> _initializeDependencies() async {
    final appDatabase = await AppDatabase.init();
    final tariffRepo = TariffRepository(appDatabase.database);
    final parkingRepo = ParkingRepository(appDatabase.database);
    final parkingService = ParkingService(
      parkingRepository: parkingRepo,
      tariffRepository: tariffRepo,
    );
    return ParkingProvider(parkingService: parkingService);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ParkingProvider>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            // Error screen with Retry button (Section 19)
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                useMaterial3: true,
                colorSchemeSeed: AppConstants.primarySeedColor,
              ),
              home: Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 60),
                        const SizedBox(height: 16),
                        const Text(
                          'Database Initialization Failed',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Unable to open local database: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _startInitialization,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          // Successfully initialized
          return ChangeNotifierProvider<ParkingProvider>.value(
            value: snapshot.data!,
            child: const SmartParkApp(),
          );
        }

        // Loading splash
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: AppConstants.primarySeedColor,
          ),
          home: const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading SmartPark AI...'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
