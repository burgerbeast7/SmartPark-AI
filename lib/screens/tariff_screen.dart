import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../models/tariff.dart';
import '../providers/parking_provider.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tariff Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Information Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Applies to future exits only. Completed session fees never change.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // First-Hour Rate
                    TextFormField(
                      controller: _firstHourController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'First Hour Rate (₹) *',
                        prefixIcon: const Icon(Icons.currency_rupee_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                      decoration: InputDecoration(
                        labelText: 'Additional Hour Rate (₹) *',
                        prefixIcon: const Icon(Icons.more_time_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                      decoration: InputDecoration(
                        labelText: 'Grace Period (Minutes) *',
                        hintText: '0 to 120 minutes',
                        prefixIcon: const Icon(Icons.timelapse_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                      decoration: InputDecoration(
                        labelText: 'Total Facility Capacity (Spots) *',
                        hintText: 'At least 1',
                        prefixIcon: const Icon(Icons.local_parking_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Facility capacity is required.';
                        final num = int.tryParse(val.trim());
                        if (num == null || num < 1) return 'Capacity must be at least 1.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Rounding Choice
                    Text(
                      'Rounding Choice',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: AppConstants.roundingStartedHour,
                          label: Text('Started Hour (Ceiling)'),
                          icon: Icon(Icons.arrow_upward_rounded),
                        ),
                        ButtonSegment(
                          value: AppConstants.roundingFullHour,
                          label: Text('Full Hours Only (Floor)'),
                          icon: Icon(Icons.arrow_downward_rounded),
                        ),
                      ],
                      selected: {_roundingRule},
                      onSelectionChanged: (set) {
                        setState(() => _roundingRule = set.first);
                      },
                    ),
                    const SizedBox(height: 28),

                    // Save Button
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        backgroundColor: AppConstants.primarySeedColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                  ],
                ),
              ),
            ),
    );
  }
}
