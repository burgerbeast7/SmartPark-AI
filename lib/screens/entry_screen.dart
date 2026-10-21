import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/exceptions.dart';
import '../core/formatters.dart';
import '../providers/parking_provider.dart';
import '../services/ocr_service.dart';
import '../services/plate_service.dart';
import '../widgets/glass_container.dart';

class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  final TextEditingController _plateController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final OcrService _ocrService = OcrService();

  String _selectedCategory = AppConstants.categoryCar;
  String? _capturedImagePath;
  bool _isOcrLoading = false;
  bool _isSaving = false;
  List<String> _ocrChips = [];
  String? _softWarning;

  @override
  void initState() {
    super.initState();
    _plateController.addListener(_onPlateChanged);
  }

  @override
  void dispose() {
    _plateController.removeListener(_onPlateChanged);
    _plateController.dispose();
    super.dispose();
  }

  void _onPlateChanged() {
    final text = _plateController.text;
    final normalized = PlateService.normalize(text);

    if (text != normalized) {
      _plateController.value = TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
      return;
    }

    final validation = PlateService.validate(normalized);
    setState(() {
      _softWarning = validation.warningMessage;
    });
  }

  Future<void> _capturePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (photo == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera capture cancelled. Manual entry available.')),
        );
        return;
      }

      setState(() {
        _capturedImagePath = photo.path;
        _isOcrLoading = true;
        _ocrChips = [];
      });

      final result = await _ocrService.recognizePlate(photo.path);
      if (!mounted) return;

      setState(() {
        _isOcrLoading = false;
        if (result.suggestion.isNotEmpty) {
          _plateController.text = result.suggestion;
          _ocrChips = result.alternativeChips;
        } else if (result.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message!)),
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isOcrLoading = false);
      final raw = e.toString();
      final displayMessage = raw.contains('PlatformException') || raw.contains('Exception:')
          ? 'Could not extract plate from photo. You can type the plate manually.'
          : raw;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(displayMessage)),
      );
    }
  }

  Future<void> _confirmEntry() async {
    final plate = PlateService.normalize(_plateController.text);
    final validation = PlateService.validate(plate);

    if (!validation.isValidLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plate number must be between 4 and 12 characters.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final provider = context.read<ParkingProvider>();

    try {
      final session = await provider.recordEntry(
        rawPlate: plate,
        category: _selectedCategory,
      );

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _plateController.clear();
        _capturedImagePath = null;
        _ocrChips = [];
        _softWarning = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vehicle ${session.plateNumber} parked successfully.'),
          backgroundColor: AppConstants.primarySeedColor,
        ),
      );
    } on DuplicateActiveSessionException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 40),
          title: const Text('Already Parked'),
          content: Text(
            'Vehicle ${e.plate} is already inside the facility.\n\n'
            'Active session entry time: ${AppFormatters.formatDateTime(e.entryTime)}',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
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
    final plateLength = _plateController.text.trim().length;
    final isConfirmEnabled = plateLength >= 4 && plateLength <= 12 && !_isSaving && !_isOcrLoading;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Vehicle Entry',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.3),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 110.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Camera Capture / Photo Thumbnail Area
            if (_capturedImagePath != null) ...[
              GlassContainer(
                borderRadius: 22,
                blur: 16,
                padding: const EdgeInsets.all(8.0),
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(_capturedImagePath!),
                        height: 190,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: GlassContainer(
                        borderRadius: 20,
                        blur: 12,
                        opacity: 0.8,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        onTap: _isOcrLoading || _isSaving ? null : _capturePhoto,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            const Text(
                              'Retake',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ] else ...[
              GlassContainer(
                borderRadius: 22,
                blur: 16,
                opacity: 0.72,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                onTap: _isOcrLoading || _isSaving ? null : _capturePhoto,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppConstants.primarySeedColor, Color(0xFF0284C7)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppConstants.primarySeedColor.withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.camera_alt_rounded, size: 30, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Scan License Plate',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Point camera at plate for automated offline recognition',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_isOcrLoading) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: GlassContainer(
                  borderRadius: 16,
                  blur: 14,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Extracting plate with ML Kit...',
                        style: TextStyle(
                          color: AppConstants.primarySeedColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Alternative OCR Candidate Chips
            if (_ocrChips.isNotEmpty) ...[
              Text(
                'Alternative detections:',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: _ocrChips.map((chip) {
                  return ActionChip(
                    label: Text(chip, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    side: BorderSide(color: AppConstants.primarySeedColor.withValues(alpha: 0.3)),
                    onPressed: () {
                      _plateController.text = chip;
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
            ],

            // Plate Input Field Glass Card
            GlassContainer(
              borderRadius: 18,
              blur: 14,
              opacity: 0.72,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: TextField(
                controller: _plateController,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: 1.0,
                ),
                decoration: InputDecoration(
                  labelText: 'Vehicle Plate Number *',
                  hintText: 'e.g. DL01AB1234 or 22BH1234AA',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    letterSpacing: 0,
                  ),
                  prefixIcon: Icon(
                    Icons.pin_rounded,
                    color: AppConstants.primarySeedColor.withValues(alpha: 0.85),
                  ),
                  suffixIcon: _plateController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 20),
                          onPressed: () => _plateController.clear(),
                        )
                      : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorText: _softWarning,
                  errorStyle: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Helper text (mandatory per Section 18)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: Text(
                'OCR can misread. Always verify the number.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Vehicle Category Glass Card
            GlassContainer(
              borderRadius: 18,
              blur: 14,
              opacity: 0.72,
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vehicle Category',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildCategoryOption(
                        context,
                        label: 'Car',
                        icon: Icons.directions_car_rounded,
                        value: AppConstants.categoryCar,
                      ),
                      const SizedBox(width: 8),
                      _buildCategoryOption(
                        context,
                        label: 'Bike',
                        icon: Icons.two_wheeler_rounded,
                        value: AppConstants.categoryBike,
                      ),
                      const SizedBox(width: 8),
                      _buildCategoryOption(
                        context,
                        label: 'Other',
                        icon: Icons.category_rounded,
                        value: AppConstants.categoryOther,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Confirm Entry Button
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: isConfirmEnabled
                    ? const LinearGradient(
                        colors: [AppConstants.primarySeedColor, Color(0xFF0F766E)],
                      )
                    : null,
                color: isConfirmEnabled ? null : theme.colorScheme.surfaceContainerHighest,
                boxShadow: isConfirmEnabled
                    ? [
                        BoxShadow(
                          color: AppConstants.primarySeedColor.withValues(alpha: 0.38),
                          blurRadius: 18,
                          offset: const Offset(0, 7),
                        ),
                      ]
                    : null,
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
                  _isSaving ? 'Recording Entry...' : 'Confirm Vehicle Entry',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isConfirmEnabled ? Colors.white : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
                onPressed: isConfirmEnabled ? _confirmEntry : null,
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
        ),
      ),
    );
  }

  Widget _buildCategoryOption(
    BuildContext context, {
    required String label,
    required IconData icon,
    required String value,
  }) {
    final isSelected = _selectedCategory == value;
    final theme = Theme.of(context);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedCategory = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppConstants.primarySeedColor.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppConstants.primarySeedColor
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: isSelected ? AppConstants.primarySeedColor : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected ? AppConstants.primarySeedColor : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

