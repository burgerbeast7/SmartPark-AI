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
import '../widgets/glass_container.dart';
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
      final raw = e.toString();
      final displayMessage = raw.contains('PlatformException') || raw.contains('Exception:')
          ? 'Could not extract plate from photo. You can type the plate manually.'
          : raw;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(displayMessage)),
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
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Vehicle Exit',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.3),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 110.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Glass Search / Scan Bar
            GlassContainer(
              borderRadius: 18,
              blur: 14,
              opacity: 0.75,
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _plateController,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Search or enter plate number',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: AppConstants.primarySeedColor.withValues(alpha: 0.85),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                      onSubmitted: (_) => _findActiveSession(),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.camera_alt_rounded,
                      color: AppConstants.primarySeedColor,
                    ),
                    tooltip: 'Scan Plate with Camera',
                    onPressed: _isSearching || _isSaving ? null : _scanPlateWithCamera,
                  ),
                  const SizedBox(width: 4),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppConstants.primarySeedColor, Color(0xFF0F766E)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        minimumSize: const Size(68, 42),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSearching || _isSaving ? null : _findActiveSession,
                      child: _isSearching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Find',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Live list of matching active vehicles
            if (_matchingActiveVehicles.isNotEmpty && _preview == null) ...[
              GlassContainer(
                borderRadius: 18,
                blur: 14,
                opacity: 0.72,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _matchingActiveVehicles.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                  itemBuilder: (ctx, idx) {
                    final s = _matchingActiveVehicles[idx];
                    final isBike = s.category == AppConstants.categoryBike;

                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isBike ? const Color(0xFF0284C7) : AppConstants.primarySeedColor)
                              .withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isBike ? Icons.two_wheeler_rounded : Icons.directions_car_rounded,
                          color: isBike ? const Color(0xFF0284C7) : AppConstants.primarySeedColor,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        s.plateNumber,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      subtitle: Text(
                        'Entry: ${AppFormatters.formatDateTime(s.entryTime)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {
                        _plateController.text = s.plateNumber;
                        _findActiveSession();
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Error Message Banner
            if (_errorMessage != null) ...[
              GlassContainer(
                borderRadius: 16,
                blur: 12,
                tintColor: Colors.red.shade900,
                opacity: 0.1,
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Bill Card (Shown when session found)
            if (_preview != null) ...[
              _buildBillCard(context, _preview!),
              const SizedBox(height: 16),

              // Payment toggle & method Glass Card
              GlassContainer(
                borderRadius: 20,
                blur: 14,
                opacity: 0.72,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Payment Received',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      subtitle: Text(
                        _isPaymentReceived ? 'Session marked as PAID' : 'Session marked as UNPAID',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _isPaymentReceived ? Colors.green.shade700 : Colors.orange.shade800,
                        ),
                      ),
                      value: _isPaymentReceived,
                      onChanged: (val) {
                        setState(() => _isPaymentReceived = val);
                      },
                    ),
                    if (_isPaymentReceived) ...[
                      Divider(
                        height: 20,
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                      Row(
                        children: [
                          const Text(
                            'Method:',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          const SizedBox(width: 14),
                          Wrap(
                            spacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('Cash', style: TextStyle(fontWeight: FontWeight.bold)),
                                selected: _selectedPaymentMethod == AppConstants.paymentMethodCash,
                                onSelected: (val) {
                                  if (val) setState(() => _selectedPaymentMethod = AppConstants.paymentMethodCash);
                                },
                              ),
                              ChoiceChip(
                                label: const Text('UPI', style: TextStyle(fontWeight: FontWeight.bold)),
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
              const SizedBox(height: 24),

              // Confirm Exit Button
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [AppConstants.primarySeedColor, Color(0xFF0F766E)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppConstants.primarySeedColor.withValues(alpha: 0.38),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_rounded, color: Colors.white),
                  label: Text(
                    _isSaving ? 'Processing Exit...' : 'Confirm Exit & Issue Receipt',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  onPressed: _isSaving ? null : _confirmExit,
                ),
              ),
              const SizedBox(height: 18),
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
          ],
        ),
      ),
    );
  }

  Widget _buildBillCard(BuildContext context, ParkingExitPreview preview) {
    final theme = Theme.of(context);
    final session = preview.session;
    final breakdown = preview.breakdown;
    final isBike = session.category == AppConstants.categoryBike;

    return GlassContainer(
      borderRadius: 22,
      blur: 16,
      opacity: 0.75,
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isBike
                            ? [const Color(0xFF0284C7), const Color(0xFF0369A1)]
                            : [AppConstants.primarySeedColor, const Color(0xFF0F766E)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isBike ? Icons.two_wheeler_rounded : Icons.directions_car_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    session.plateNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppConstants.primarySeedColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  session.category,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: AppConstants.primarySeedColor,
                  ),
                ),
              ),
            ],
          ),
          Divider(
            height: 24,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          _buildDetailRow('Entry Time', AppFormatters.formatDateTime(session.entryTime)),
          const SizedBox(height: 6),
          _buildDetailRow('Exit Time', AppFormatters.formatDateTime(preview.exitTime)),
          const SizedBox(height: 6),
          _buildDetailRow('Duration', AppFormatters.formatDuration(preview.durationMinutes), isBold: true),
          Divider(
            height: 24,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),

          // Breakdown
          Text(
            'Tariff Calculation',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
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
          Divider(
            height: 24,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),

          // Total Due Glass Container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppConstants.primarySeedColor.withValues(alpha: 0.14),
                  AppConstants.primarySeedColor.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppConstants.primarySeedColor.withValues(alpha: 0.3),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Due',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                Text(
                  AppFormatters.formatCurrency(breakdown.total),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                    color: AppConstants.primarySeedColor,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
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
            color: isMuted
                ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)
                : theme.colorScheme.onSurface,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isMuted
                ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)
                : theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

