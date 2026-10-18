import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/exceptions.dart';
import '../core/formatters.dart';
import '../models/parking_session.dart';
import '../providers/parking_provider.dart';
import '../services/ocr_service.dart';
import '../services/parking_service.dart';
import '../services/plate_service.dart';
import 'receipt_screen.dart';

class ExitScreen extends StatefulWidget {
  const ExitScreen({super.key});

  @override
  State<ExitScreen> createState() => _ExitScreenState();
}

class _ExitScreenState extends State<ExitScreen> {
  final TextEditingController _plateController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final OcrService _ocrService = OcrService();

  ParkingExitPreview? _preview;
  List<ParkingSession> _matchingActiveVehicles = [];
  bool _isSearching = false;
  bool _isSaving = false;
  bool _isPaymentReceived = true;
  String _selectedPaymentMethod = AppConstants.paymentMethodCash;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _plateController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPrefilledPlate();
    });
  }

  void _checkPrefilledPlate() {
    final provider = context.read<ParkingProvider>();
    if (provider.prefilledExitPlate != null) {
      _plateController.text = provider.prefilledExitPlate!;
      provider.clearPrefilledExitPlate();
      _findActiveSession();
    }
  }

  @override
  void dispose() {
    _plateController.removeListener(_onSearchChanged);
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _onSearchChanged() async {
    final text = _plateController.text.trim();
    if (text.isEmpty) {
      setState(() => _matchingActiveVehicles = []);
      return;
    }

    final provider = context.read<ParkingProvider>();
    final matches = await provider.getActiveVehicles(query: text);
    if (!mounted) return;
    setState(() {
      _matchingActiveVehicles = matches;
    });
  }

  Future<void> _scanPlateWithCamera() async {
    try {
      final photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo == null) return;

      setState(() => _isSearching = true);
      final result = await _ocrService.recognizePlate(photo.path);
      if (!mounted) return;

      setState(() {
        _isSearching = false;
        if (result.suggestion.isNotEmpty) {
          _plateController.text = result.suggestion;
          _findActiveSession();
        } else if (result.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message!)),
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan error: ${e.toString()}')),
      );
    }
  }

  Future<void> _findActiveSession() async {
    final plate = PlateService.normalize(_plateController.text);
    if (plate.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a plate number.';
        _preview = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _preview = null;
    });

    final provider = context.read<ParkingProvider>();
    try {
      final preview = await provider.previewExit(rawPlate: plate);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _isSearching = false;
        _matchingActiveVehicles = [];
      });
    } on NoActiveSessionException {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No active session for $plate';
        _isSearching = false;
        _preview = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isSearching = false;
        _preview = null;
      });
    }
  }

  Future<void> _confirmExit() async {
    if (_preview == null || _isSaving) return;

    setState(() => _isSaving = true);
    final provider = context.read<ParkingProvider>();

    try {
      final completed = await provider.confirmExit(
        preview: _preview!,
        paymentMethod: _selectedPaymentMethod,
        isPaid: _isPaymentReceived,
      );

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _preview = null;
        _plateController.clear();
      });

      // Push Receipt screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReceiptScreen(sessionId: completed.id!),
        ),
      );
    } on AlreadyCompletedException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Exit'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search / Scan Bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _plateController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Plate Number',
                      hintText: 'Search active plate',
                      prefixIcon: const Icon(Icons.search_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.camera_alt_rounded),
                        tooltip: 'Scan Plate',
                        onPressed: _isSearching || _isSaving ? null : _scanPlateWithCamera,
                      ),
                    ),
                    onSubmitted: (_) => _findActiveSession(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(80, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSearching || _isSaving ? null : _findActiveSession,
                  child: _isSearching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Find'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Live list of matching active vehicles
            if (_matchingActiveVehicles.isNotEmpty && _preview == null) ...[
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _matchingActiveVehicles.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final s = _matchingActiveVehicles[idx];
                    return ListTile(
                      leading: Icon(
                        s.category == AppConstants.categoryBike
                            ? Icons.two_wheeler_rounded
                            : Icons.directions_car_rounded,
                        color: AppConstants.primarySeedColor,
                      ),
                      title: Text(s.plateNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Entry: ${AppFormatters.formatDateTime(s.entryTime)}'),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onTap: () {
                        _plateController.text = s.plateNumber;
                        _findActiveSession();
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Error Message Banner
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: Colors.red.shade700),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Bill Card (Shown when session found)
            if (_preview != null) ...[
              const SizedBox(height: 12),
              _buildBillCard(context, _preview!),
              const SizedBox(height: 20),

              // Payment toggle & method
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Payment Received', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(_isPaymentReceived ? 'Session marked as PAID' : 'Session marked as UNPAID'),
                        value: _isPaymentReceived,
                        onChanged: (val) {
                          setState(() => _isPaymentReceived = val);
                        },
                      ),
                      if (_isPaymentReceived) ...[
                        const Divider(),
                        Row(
                          children: [
                            const Text('Method:', style: TextStyle(fontWeight: FontWeight.w500)),
                            const SizedBox(width: 16),
                            Wrap(
                              spacing: 8,
                              children: [
                                ChoiceChip(
                                  label: const Text('Cash'),
                                  selected: _selectedPaymentMethod == AppConstants.paymentMethodCash,
                                  onSelected: (val) {
                                    if (val) setState(() => _selectedPaymentMethod = AppConstants.paymentMethodCash);
                                  },
                                ),
                                ChoiceChip(
                                  label: const Text('UPI'),
                                  selected: _selectedPaymentMethod == AppConstants.paymentMethodUpi,
                                  onSelected: (val) {
                                    if (val) setState(() => _selectedPaymentMethod = AppConstants.paymentMethodUpi);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Confirm Exit Button (disabled while saving to prevent double tap)
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
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text(
                  _isSaving ? 'Processing Exit...' : 'Confirm Exit & Issue Receipt',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: _isSaving ? null : _confirmExit,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBillCard(BuildContext context, ParkingExitPreview preview) {
    final theme = Theme.of(context);
    final session = preview.session;
    final breakdown = preview.breakdown;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  session.plateNumber,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                Chip(
                  label: Text(session.category),
                  backgroundColor: AppConstants.primarySeedColor.withValues(alpha: 0.1),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildDetailRow('Entry Time', AppFormatters.formatDateTime(session.entryTime)),
            const SizedBox(height: 6),
            _buildDetailRow('Exit Time', AppFormatters.formatDateTime(preview.exitTime)),
            const SizedBox(height: 6),
            _buildDetailRow('Duration', AppFormatters.formatDuration(preview.durationMinutes), isBold: true),
            const Divider(height: 24),

            // Breakdown
            Text('Tariff Calculation', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (breakdown.graceApplied) ...[
              _buildDetailRow('Grace Period (<= ${preview.tariff.graceMinutes}m)', '₹0', isMuted: true),
            ] else ...[
              _buildDetailRow('First Hour Rate', '₹${breakdown.firstHourCharge}'),
              if (breakdown.additionalHours > 0) ...[
                const SizedBox(height: 6),
                _buildDetailRow(
                  'Additional (${breakdown.additionalHours}h @ ₹${breakdown.additionalHourRate}/h)',
                  '₹${breakdown.additionalCharge}',
                ),
              ],
            ],
            const Divider(height: 24),

            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Due', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                Text(
                  AppFormatters.formatCurrency(breakdown.total),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppConstants.primarySeedColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, bool isMuted = false}) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isMuted ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isMuted ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
