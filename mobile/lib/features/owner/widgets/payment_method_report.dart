import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../data/models.dart';
import '../../../theme.dart';

/// How the money actually came in, over whatever window the Reports page is
/// showing.
///
/// Counted off `Bill.amountPaid` grouped by `Bill.paymentMethod`, which is
/// the same attribution `dailyStats.collected_*` uses: a settlement recorded
/// later is credited to the bill's original method
/// (see SalonFirestore.recordPayment), and `amountPaid` already folds those
/// settlements in (see billFromFS). So this agrees with the figures on Home
/// rather than offering a second opinion.
class PaymentMix {
  final double cash;
  final double card;
  final double upi;

  /// Money taken against pay-later bills. Not a channel of its own - it is
  /// cash or UPI in real life - but the bill records PENDING as its method,
  /// so attributing it to either would be inventing detail the data does not
  /// carry. Shown separately so the parts still add up to the total.
  final double payLater;

  final int cashBills;
  final int cardBills;
  final int upiBills;
  final int payLaterBills;

  /// Billed but not yet handed over, across the same window.
  final double outstanding;

  const PaymentMix({
    required this.cash,
    required this.card,
    required this.upi,
    required this.payLater,
    required this.cashBills,
    required this.cardBills,
    required this.upiBills,
    required this.payLaterBills,
    required this.outstanding,
  });

  double get collected => cash + card + upi + payLater;

  /// Share of everything collected. Zero rather than NaN on an empty window.
  double shareOf(double amount) => collected <= 0 ? 0 : amount / collected;
}

PaymentMix computePaymentMix(List<Bill> bills) {
  var cash = 0.0, card = 0.0, upi = 0.0, payLater = 0.0, outstanding = 0.0;
  var cashBills = 0, cardBills = 0, upiBills = 0, payLaterBills = 0;

  for (final b in bills) {
    outstanding += b.amountDue;
    // A bill that collected nothing is not a payment by any method - it
    // would otherwise pad the bill counts with rows worth zero.
    if (b.amountPaid <= 0) continue;

    switch (b.paymentMethod) {
      case 'CASH':
        cash += b.amountPaid;
        cashBills++;
      case 'CARD':
        card += b.amountPaid;
        cardBills++;
      case 'UPI':
        upi += b.amountPaid;
        upiBills++;
      default:
        // PENDING, and anything a future method might add - counted rather
        // than dropped, so `collected` stays the real total.
        payLater += b.amountPaid;
        payLaterBills++;
    }
  }

  return PaymentMix(
    cash: cash,
    card: card,
    upi: upi,
    payLater: payLater,
    cashBills: cashBills,
    cardBills: cardBills,
    upiBills: upiBills,
    payLaterBills: payLaterBills,
    outstanding: outstanding,
  );
}

/// Payment-method breakdown for the Reports page: a stacked share bar, then
/// a row per method with its amount, share and bill count.
class PaymentMethodReport extends StatelessWidget {
  final List<Bill> bills;

  /// Formats a rupee figure the way the rest of the page does.
  final String Function(double) formatCurrency;

  const PaymentMethodReport({
    super.key,
    required this.bills,
    required this.formatCurrency,
  });

  static const _cashColor = AppTheme.accentGreen;
  static const _upiColor = Color(0xFF8B5CF6);
  static const _cardColor = Color(0xFF3B82F6);
  static const _laterColor = AppTheme.accentAmber;

  @override
  Widget build(BuildContext context) {
    final mix = computePaymentMix(bills);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Methods',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'How the money came in',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCurrency(mix.collected),
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Text(
                    'collected',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _shareBar(mix),
          const SizedBox(height: 16),
          _row(
            icon: PhosphorIconsBold.money,
            color: _cashColor,
            label: 'Cash',
            amount: mix.cash,
            bills: mix.cashBills,
            mix: mix,
          ),
          const SizedBox(height: 12),
          _row(
            icon: PhosphorIconsBold.qrCode,
            color: _upiColor,
            label: 'UPI / QR',
            amount: mix.upi,
            bills: mix.upiBills,
            mix: mix,
          ),
          const SizedBox(height: 12),
          _row(
            icon: PhosphorIconsBold.creditCard,
            color: _cardColor,
            label: 'Card / POS',
            amount: mix.card,
            bills: mix.cardBills,
            mix: mix,
            // Card was retired from both POS screens, so this row can only
            // ever reflect bills taken before that. Saying so beats an
            // unexplained permanent zero.
            note: mix.card <= 0 ? 'No longer offered' : 'Retired - legacy bills',
          ),
          if (mix.payLater > 0) ...[
            const SizedBox(height: 12),
            _row(
              icon: PhosphorIconsBold.clockCountdown,
              color: _laterColor,
              label: 'On pay-later bills',
              amount: mix.payLater,
              bills: mix.payLaterBills,
              mix: mix,
              note: 'Method not recorded per payment',
            ),
          ],
          if (mix.outstanding > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.accentAmberBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    PhosphorIconsBold.handCoins,
                    size: 14,
                    color: AppTheme.accentAmber,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      // Outstanding is not a payment method, so it is kept
                      // out of the bar and the shares above - it is money
                      // that has not come in by any route yet.
                      '${formatCurrency(mix.outstanding)} still outstanding on these bills',
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF92400E),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _shareBar(PaymentMix mix) {
    final segments = <MapEntry<Color, double>>[
      MapEntry(_cashColor, mix.cash),
      MapEntry(_upiColor, mix.upi),
      MapEntry(_cardColor, mix.card),
      MapEntry(_laterColor, mix.payLater),
    ].where((e) => e.value > 0).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 10,
        child: segments.isEmpty
            // Nothing collected in this window - an empty bar still has to
            // draw something, or the card looks broken rather than quiet.
            ? const ColoredBox(color: Color(0xFFE2E8F0))
            : Row(
                children: [
                  for (final s in segments)
                    Expanded(
                      // Scaled so a rounding error cannot leave a gap: flex
                      // is an int, so tiny shares still claim one unit.
                      flex: (s.value * 1000 / mix.collected).round().clamp(1, 1000),
                      child: ColoredBox(color: s.key),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _row({
    required IconData icon,
    required Color color,
    required String label,
    required double amount,
    required int bills,
    required PaymentMix mix,
    String? note,
  }) {
    final pct = (mix.shareOf(amount) * 100).round();
    final muted = amount <= 0;

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: muted ? const Color(0xFFF1F5F9) : color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 16,
            color: muted ? const Color(0xFF94A3B8) : color,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: muted ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                note ??
                    '$bills bill${bills == 1 ? '' : 's'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatCurrency(amount),
              maxLines: 1,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: muted ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$pct%',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: muted ? const Color(0xFFCBD5E1) : color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
