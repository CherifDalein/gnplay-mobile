import '../../../shared/utils/json_helpers.dart';

class WalletLedgerEntry {
  const WalletLedgerEntry({
    required this.label,
    required this.dateLabel,
    required this.amount,
    required this.kind,
    this.payoutId,
  });

  final String label;
  final String dateLabel;
  final int amount;
  final WalletLedgerKind kind;

  /// `reference_id` quand `reference_type == "payout"` — permet le lien vers
  /// l'écran de suivi du retrait.
  final String? payoutId;

  /// Champs confirmés depuis app/models/wallets.py::LedgerEntry (l'endpoint
  /// renvoie l'ORM directement, sans schéma Pydantic) : amount, direction
  /// (credit/debit), transaction_type, reference_id, reference_type,
  /// description, created_at.
  factory WalletLedgerEntry.fromJson(Map<String, dynamic> json) {
    final type = jsonNullableString(json['transaction_type'])?.toLowerCase();
    final direction = jsonNullableString(json['direction'])?.toLowerCase();
    var amount = jsonInt(json['amount']);
    if (direction == 'debit' && amount > 0) {
      amount = -amount;
    }
    final referenceType = jsonNullableString(json['reference_type'])
        ?.toLowerCase();

    return WalletLedgerEntry(
      label: jsonString(json['description'], fallback: 'Mouvement'),
      dateLabel: _dateLabel(json['created_at']),
      amount: amount,
      kind: WalletLedgerKind.fromType(type),
      payoutId: referenceType == 'payout'
          ? jsonNullableString(json['reference_id'])
          : null,
    );
  }

  static String _dateLabel(Object? rawDate) {
    final parsed = jsonDate(rawDate);
    if (parsed == null) {
      return 'Aujourd’hui';
    }
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year}';
  }

  static List<WalletLedgerEntry> sample() {
    return const [
      WalletLedgerEntry(
        label: 'Vente vidéo',
        dateLabel: 'Aujourd’hui',
        amount: 1842000,
        kind: WalletLedgerKind.sale,
      ),
      WalletLedgerEntry(
        label: 'Retrait mobile money',
        dateLabel: 'Hier',
        amount: -750000,
        kind: WalletLedgerKind.payout,
      ),
      WalletLedgerEntry(
        label: 'Recharge portefeuille',
        dateLabel: '12/08/2026',
        amount: 250000,
        kind: WalletLedgerKind.topup,
      ),
    ];
  }
}

/// Miroir de WalletTransactionType (app/enums/wallets.py) : topup, purchase,
/// earning, commission, refund, withdrawal.
enum WalletLedgerKind {
  sale,
  payout,
  topup,
  purchase,
  refund,
  neutral;

  static WalletLedgerKind fromType(String? type) {
    return switch (type) {
      'earning' => WalletLedgerKind.sale,
      'withdrawal' => WalletLedgerKind.payout,
      'topup' => WalletLedgerKind.topup,
      'purchase' => WalletLedgerKind.purchase,
      'refund' => WalletLedgerKind.refund,
      _ => WalletLedgerKind.neutral,
    };
  }
}
