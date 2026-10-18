import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/constants.dart';
import '../core/formatters.dart';
import '../models/parking_session.dart';
import '../providers/parking_provider.dart';
import '../services/billing_service.dart';

class ReceiptScreen extends StatefulWidget {
  final int sessionId;

  const ReceiptScreen({super.key, required this.sessionId});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  ParkingSession? _session;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    setState(() => _isLoading = true);
    final provider = context.read<ParkingProvider>();
    final session = await provider.getSessionById(widget.sessionId);
    if (!mounted) return;
    setState(() {
      _session = session;
      _isLoading = false;
    });
  }

  Future<void> _markAsPaid() async {
    String selectedMethod = AppConstants.paymentMethodCash;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Mark Payment as Paid'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select payment method:'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Cash'),
                    selected: selectedMethod == AppConstants.paymentMethodCash,
                    onSelected: (val) {
                      if (val) setDialogState(() => selectedMethod = AppConstants.paymentMethodCash);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('UPI'),
                    selected: selectedMethod == AppConstants.paymentMethodUpi,
                    onSelected: (val) {
                      if (val) setDialogState(() => selectedMethod = AppConstants.paymentMethodUpi);
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm Paid'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<ParkingProvider>();
      await provider.markPaymentAsPaid(
        sessionId: widget.sessionId,
        paymentMethod: selectedMethod,
      );
      await _loadSession();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment marked as PAID.')),
      );
    }
  }

  void _shareReceiptText() {
    if (_session == null) return;
    final s = _session!;
    final receiptNo = AppFormatters.formatReceiptNumber(s.id!);
    final text = StringBuffer();
    text.writeln('========== SMARTPARK AI RECEIPT ==========');
    text.writeln('Receipt No: $receiptNo');
    text.writeln('Vehicle Plate: ${s.plateNumber}');
    text.writeln('Category: ${s.category}');
    text.writeln('Entry Time: ${AppFormatters.formatDateTime(s.entryTime)}');
    text.writeln('Exit Time: ${AppFormatters.formatDateTime(s.exitTime)}');
    text.writeln('Duration: ${AppFormatters.formatDuration(s.durationMinutes ?? 0)}');
    text.writeln('Total Amount: ${AppFormatters.formatCurrency(s.amount ?? 0)}');
    text.writeln('Payment Status: ${s.payment?.paymentStatus ?? "UNPAID"}');
    if (s.payment?.paymentStatus == AppConstants.paymentStatusPaid) {
      text.writeln('Payment Method: ${s.payment?.paymentMethod}');
      text.writeln('Paid At: ${AppFormatters.formatDateTime(s.payment?.paidAt)}');
    }
    text.writeln('==========================================');

    SharePlus.instance.share(
      ShareParams(
        text: text.toString(),
        subject: 'Parking Receipt $receiptNo',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Parking Receipt')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Parking Receipt')),
        body: const Center(child: Text('Receipt not found.')),
      );
    }

    final s = _session!;
    final breakdown = BillingService.rebuildBreakdown(
      s.durationMinutes ?? 0,
      s.tariffSnapshot,
      s.amount ?? 0,
    );
    final isPaid = s.payment?.paymentStatus == AppConstants.paymentStatusPaid;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppFormatters.formatReceiptNumber(s.id!)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share Receipt',
            onPressed: _shareReceiptText,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SMARTPARK AI',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppConstants.primarySeedColor,
                              ),
                            ),
                            Text(
                              AppFormatters.formatReceiptNumber(s.id!),
                              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isPaid ? Colors.green.shade50 : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isPaid ? Colors.green : Colors.orange),
                          ),
                          child: Text(
                            isPaid ? 'PAID' : 'UNPAID',
                            style: TextStyle(
                              color: isPaid ? Colors.green.shade800 : Colors.orange.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),

                    // Plate & Category
                    _buildRow('Vehicle Number', s.plateNumber, isBold: true),
                    const SizedBox(height: 8),
                    _buildRow('Category', s.category),
                    const SizedBox(height: 8),
                    _buildRow('Entry Time', AppFormatters.formatDateTime(s.entryTime)),
                    const SizedBox(height: 8),
                    _buildRow('Exit Time', AppFormatters.formatDateTime(s.exitTime)),
                    const SizedBox(height: 8),
                    _buildRow('Duration', AppFormatters.formatDuration(s.durationMinutes ?? 0)),

                    const Divider(height: 32),

                    // Breakdown lines
                    Text(
                      'Tariff Breakdown',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (breakdown.graceApplied) ...[
                      _buildRow('Grace Period Applied', '₹0', isMuted: true),
                    ] else ...[
                      _buildRow('First Hour Charge', '₹${breakdown.firstHourCharge}'),
                      if (breakdown.additionalHours > 0) ...[
                        const SizedBox(height: 6),
                        _buildRow(
                          'Additional Hours (${breakdown.additionalHours}h @ ₹${breakdown.additionalHourRate}/h)',
                          '₹${breakdown.additionalCharge}',
                        ),
                      ],
                    ],
                    const Divider(height: 24),

                    // Total
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Amount',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          AppFormatters.formatCurrency(s.amount ?? 0),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppConstants.primarySeedColor,
                          ),
                        ),
                      ],
                    ),

                    if (isPaid && s.payment != null) ...[
                      const Divider(height: 32),
                      _buildRow('Payment Method', s.payment!.paymentMethod),
                      const SizedBox(height: 6),
                      _buildRow('Paid At', AppFormatters.formatDateTime(s.payment!.paidAt)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Share Receipt'),
                    onPressed: _shareReceiptText,
                  ),
                ),
                if (!isPaid) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: Colors.green.shade700,
                      ),
                      icon: const Icon(Icons.payment_rounded),
                      label: const Text('Mark as Paid'),
                      onPressed: _markAsPaid,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false, bool isMuted = false}) {
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
