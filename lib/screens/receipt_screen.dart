import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/constants.dart';
import '../core/formatters.dart';
import '../models/parking_session.dart';
import '../providers/parking_provider.dart';
import '../services/billing_service.dart';
import '../widgets/ambient_background.dart';
import '../widgets/glass_container.dart';

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Mark Payment as Paid', style: TextStyle(fontWeight: FontWeight.bold)),
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
              style: FilledButton.styleFrom(
                backgroundColor: AppConstants.primarySeedColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
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
    text.writeln('------------------------------------------');
    text.writeln('Designed & Developed by Kunal Chauhan');
    text.writeln('© 2026 Kunal Chauhan. All rights reserved.');
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
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Parking Receipt'),
        ),
        body: const AmbientBackground(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_session == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Parking Receipt'),
        ),
        body: const AmbientBackground(
          child: Center(child: Text('Receipt not found.')),
        ),
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          AppFormatters.formatReceiptNumber(s.id!),
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.3),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share Receipt',
            onPressed: _shareReceiptText,
          ),
        ],
      ),
      body: AmbientBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            children: [
              GlassContainer(
                borderRadius: 22,
                padding: const EdgeInsets.all(22.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Brand & Status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF0E8C7F),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'SMARTPARK AI',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    letterSpacing: 1.2,
                                    color: AppConstants.primarySeedColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppFormatters.formatReceiptNumber(s.id!),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isPaid
                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isPaid
                                  ? const Color(0xFF10B981).withValues(alpha: 0.6)
                                  : const Color(0xFFF59E0B).withValues(alpha: 0.6),
                              width: 1.2,
                            ),
                          ),
                          child: Text(
                            isPaid ? 'PAID' : 'UNPAID',
                            style: TextStyle(
                              color: isPaid ? const Color(0xFF059669) : const Color(0xFFD97706),
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Divider(
                      height: 1,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                    const SizedBox(height: 16),

                    // Plate & Category
                    _buildRow('Vehicle Number', s.plateNumber, isBold: true, isHighlight: true),
                    const SizedBox(height: 10),
                    _buildRow('Category', s.category),
                    const SizedBox(height: 10),
                    _buildRow('Entry Time', AppFormatters.formatDateTime(s.entryTime)),
                    const SizedBox(height: 10),
                    _buildRow('Exit Time', AppFormatters.formatDateTime(s.exitTime)),
                    const SizedBox(height: 10),
                    _buildRow('Duration', AppFormatters.formatDuration(s.durationMinutes ?? 0)),

                    const SizedBox(height: 16),
                    Divider(
                      height: 1,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                    const SizedBox(height: 16),

                    // Breakdown lines
                    Text(
                      'Tariff Breakdown',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (breakdown.graceApplied) ...[
                      _buildRow('Grace Period Applied', '₹0', isMuted: true),
                    ] else ...[
                      _buildRow('First Hour Charge', '₹${breakdown.firstHourCharge}'),
                      if (breakdown.additionalHours > 0) ...[
                        const SizedBox(height: 8),
                        _buildRow(
                          'Additional Hours (${breakdown.additionalHours}h @ ₹${breakdown.additionalHourRate}/h)',
                          '₹${breakdown.additionalCharge}',
                        ),
                      ],
                    ],

                    const SizedBox(height: 18),
                    // Total Emerald Highlight Glass Box
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppConstants.primarySeedColor.withValues(alpha: isDark ? 0.25 : 0.12),
                            const Color(0xFF0EA5E9).withValues(alpha: isDark ? 0.15 : 0.06),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppConstants.primarySeedColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Amount',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            AppFormatters.formatCurrency(s.amount ?? 0),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppConstants.primarySeedColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (isPaid && s.payment != null) ...[
                      const SizedBox(height: 18),
                      Divider(
                        height: 1,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.08),
                      ),
                      const SizedBox(height: 14),
                      _buildRow('Payment Method', s.payment!.paymentMethod),
                      const SizedBox(height: 8),
                      _buildRow('Paid At', AppFormatters.formatDateTime(s.payment!.paidAt)),
                    ],
                    const SizedBox(height: 18),
                    Divider(
                      height: 1,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        'SmartPark AI • ${AppConstants.developerCredit}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Actions Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.25)
                              : Colors.black.withValues(alpha: 0.15),
                        ),
                      ),
                      icon: const Icon(Icons.share_rounded, size: 20),
                      label: const Text(
                        'Share Receipt',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: _shareReceiptText,
                    ),
                  ),
                  if (!isPaid) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: const Color(0xFF059669),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.payment_rounded, size: 20),
                          label: const Text(
                            'Mark Paid',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: _markAsPaid,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 22),
              Center(
                child: Text(
                  AppConstants.copyrightNotice,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value, {
    bool isBold = false,
    bool isMuted = false,
    bool isHighlight = false,
  }) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isMuted ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            fontSize: isHighlight ? 16 : null,
            letterSpacing: isHighlight ? 0.5 : null,
            color: isHighlight
                ? AppConstants.primarySeedColor
                : (isMuted ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface),
          ),
        ),
      ],
    );
  }
}

