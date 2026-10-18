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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OCR error: ${e.toString()}. You can type the plate manually.')),
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
      appBar: AppBar(
        title: const Text('Vehicle Entry'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Camera Capture / Photo Thumbnail Area
            if (_capturedImagePath != null) ...[
              Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      File(_capturedImagePath!),
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.black54,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retake'),
                      onPressed: _isOcrLoading || _isSaving ? null : _capturePhoto,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ] else ...[
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Capture Plate Image', style: TextStyle(fontSize: 16)),
                onPressed: _isOcrLoading || _isSaving ? null : _capturePhoto,
              ),
              const SizedBox(height: 16),
            ],

            if (_isOcrLoading) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text('Recognising license plate...'),
                    ],
                  ),
                ),
              ),
            ],

            // Alternative OCR Candidate Chips
            if (_ocrChips.isNotEmpty) ...[
              Text(
                'Other detected candidates:',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: _ocrChips.map((chip) {
                  return ActionChip(
                    label: Text(chip),
                    onPressed: () {
                      _plateController.text = chip;
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Plate Input Field
            TextField(
              controller: _plateController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Vehicle Registration Number *',
                hintText: 'e.g. DL01AB1234 or 22BH1234AA',
                prefixIcon: const Icon(Icons.pin_rounded),
                suffixIcon: _plateController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => _plateController.clear(),
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                errorText: _softWarning,
                errorStyle: TextStyle(color: Colors.amber.shade800),
              ),
            ),
            const SizedBox(height: 8),

            // Helper text (mandatory per Section 18)
            Text(
              'OCR can misread. Always verify the number.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),

            // Vehicle Category Segmented Control
            Text(
              'Vehicle Category',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: AppConstants.categoryCar,
                  label: Text('Car'),
                  icon: Icon(Icons.directions_car_rounded),
                ),
                ButtonSegment(
                  value: AppConstants.categoryBike,
                  label: Text('Bike'),
                  icon: Icon(Icons.two_wheeler_rounded),
                ),
                ButtonSegment(
                  value: AppConstants.categoryOther,
                  label: Text('Other'),
                  icon: Icon(Icons.category_rounded),
                ),
              ],
              selected: {_selectedCategory},
              onSelectionChanged: (set) {
                setState(() => _selectedCategory = set.first);
              },
            ),
            const SizedBox(height: 28),

            // Confirm Entry Button
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
                  : const Icon(Icons.check_circle_rounded),
              label: Text(
                _isSaving ? 'Saving Entry...' : 'Confirm Entry',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: isConfirmEnabled ? _confirmEntry : null,
            ),
          ],
        ),
      ),
    );
  }
}
