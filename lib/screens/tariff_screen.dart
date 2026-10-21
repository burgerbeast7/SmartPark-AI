import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../models/tariff.dart';
import '../providers/parking_provider.dart';
import '../widgets/ambient_background.dart';
import '../widgets/glass_container.dart';

class TariffScreen extends StatefulWidget {
  const TariffScreen({super.key});

  @override
  State<TariffScreen> createState() => _TariffScreenState();
}

class _TariffScreenState extends State<TariffScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstHourController = TextEditingController();
  final _additionalHourController = TextEditingController();
  final _graceMinutesController = TextEditingController();
  final _capacityController = TextEditingController();

  String _roundingRule = AppConstants.roundingStartedHour;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadTariff();
  }

  @override
  void dispose() {
    _firstHourController.dispose();
    _additionalHourController.dispose();
    _graceMinutesController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _loadTariff() async {
    final provider = context.read<ParkingProvider>();
    final tariff = await provider.getTariff();
    if (!mounted) return;
    setState(() {
      _firstHourController.text = tariff.firstHourRate.toString();
      _additionalHourController.text = tariff.additionalHourRate.toString();
      _graceMinutesController.text = tariff.graceMinutes.toString();
      _capacityController.text = tariff.capacity.toString();
      _roundingRule = tariff.roundingRule;
      _isLoading = false;
    });
  }

  Future<void> _saveTariff() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final provider = context.read<ParkingProvider>();

    final updated = TariffSettings(
      id: 1,
      firstHourRate: int.parse(_firstHourController.text.trim()),
      additionalHourRate: int.parse(_additionalHourController.text.trim()),
      graceMinutes: int.parse(_graceMinutesController.text.trim()),
      roundingRule: _roundingRule,
      capacity: int.parse(_capacityController.text.trim()),
      updatedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
    );

    await provider.updateTariff(updated);
    if (!mounted) return;

    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tariff settings saved successfully.'),
        backgroundColor: AppConstants.primarySeedColor,
      ),
    );
    Navigator.pop(context);
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
          'Tariff Settings',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.3),
        ),
      ),
      body: AmbientBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Information Frosted Banner
                      GlassContainer(
                        borderRadius: 16,
                        padding: const EdgeInsets.all(14),
                        tintColor: AppConstants.primarySeedColor,
                        opacity: isDark ? 0.25 : 0.12,
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppConstants.primarySeedColor.withValues(alpha: 0.2),
                              ),
                              child: Icon(
                                Icons.info_outline_rounded,
                                color: AppConstants.primarySeedColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Applies to future exits only. Completed session fees never change.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Main Form Container
                      GlassContainer(
                        borderRadius: 22,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Hourly Rates & Parking Rules',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 18),

                            // First-Hour Rate
                            TextFormField(
                              controller: _firstHourController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: _inputDecoration(
                                labelText: 'First Hour Rate (₹) *',
                                icon: Icons.currency_rupee_rounded,
                                isDark: isDark,
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'First hour rate is required.';
                                final num = int.tryParse(val.trim());
                                if (num == null || num < 0) return 'Must be an integer >= 0.';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Additional-Hour Rate
                            TextFormField(
                              controller: _additionalHourController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: _inputDecoration(
                                labelText: 'Additional Hour Rate (₹) *',
                                icon: Icons.more_time_rounded,
                                isDark: isDark,
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Additional hour rate is required.';
                                final num = int.tryParse(val.trim());
                                if (num == null || num < 0) return 'Must be an integer >= 0.';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Grace Period Minutes
                            TextFormField(
                              controller: _graceMinutesController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: _inputDecoration(
                                labelText: 'Grace Period (Minutes) *',
                                hintText: '0 to 120 minutes',
                                icon: Icons.timelapse_rounded,
                                isDark: isDark,
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Grace minutes is required.';
                                final num = int.tryParse(val.trim());
                                if (num == null || num < 0 || num > 120) return 'Grace period must be between 0 and 120.';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Parking Capacity
                            TextFormField(
                              controller: _capacityController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: _inputDecoration(
                                labelText: 'Total Facility Capacity (Spots) *',
                                hintText: 'At least 1',
                                icon: Icons.local_parking_rounded,
                                isDark: isDark,
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Facility capacity is required.';
                                final num = int.tryParse(val.trim());
                                if (num == null || num < 1) return 'Capacity must be at least 1.';
                                return null;
                              },
                            ),
                            const SizedBox(height: 22),

                            // Rounding Choice
                            Text(
                              'Billing Rounding Method',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                  value: AppConstants.roundingStartedHour,
                                  label: Text('Started Hour\n(Ceiling)', textAlign: TextAlign.center),
                                  icon: Icon(Icons.arrow_upward_rounded),
                                ),
                                ButtonSegment(
                                  value: AppConstants.roundingFullHour,
                                  label: Text('Full Hours\n(Floor)', textAlign: TextAlign.center),
                                  icon: Icon(Icons.arrow_downward_rounded),
                                ),
                              ],
                              selected: {_roundingRule},
                              onSelectionChanged: (set) {
                                setState(() => _roundingRule = set.first);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Save Button with glow
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppConstants.primarySeedColor.withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(54),
                            backgroundColor: AppConstants.primarySeedColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.save_rounded),
                          label: Text(
                            _isSaving ? 'Saving...' : 'Save Tariff Settings',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          onPressed: _isSaving ? null : _saveTariff,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Center(
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
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String labelText,
    String? hintText,
    required IconData icon,
    required bool isDark,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: Icon(icon, color: AppConstants.primarySeedColor),
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.03),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.1),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.1),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AppConstants.primarySeedColor,
          width: 1.5,
        ),
      ),
    );
  }
}

