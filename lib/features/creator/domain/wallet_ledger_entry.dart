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

  factory WalletLedgerEntry.fromJson(Map<String, dynamic> json) {
    final type = (json['transaction_type'] ?? json['type'] ?? json['kind'])
        ?.toString()
        .toLowerCase();
    final direction = json['direction']?.toString().toLowerCase();
    final rawAmount = json['amount'] ?? json['value'] ?? json['total'];
    var amount = rawAmount is num
        ? rawAmount.round()
        : int.tryParse(rawAmount?.toString() ?? '') ?? 0;
    if (direction == 'debit' && amount > 0) {
      amount = -amount;
    }
    final referenceType = json['reference_type']?.toString().toLowerCase();

    return WalletLedgerEntry(
      label:
          (json['label'] ?? json['description'] ?? json['title'] ?? 'Mouvement')
              .toString(),
      dateLabel: _dateLabel(json['created_at'] ?? json['date']),
      amount: amount,
      kind: WalletLedgerKind.fromType(type),
      payoutId: referenceType == 'payout'
          ? json['reference_id']?.toString()
          : null,
    );
  }

  static String _dateLabel(Object? rawDate) {
    if (rawDate == null) {
      return 'Aujourd’hui';
    }
    final parsed = DateTime.tryParse(rawDate.toString());
    if (parsed == null) {
      return rawDate.toString();
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

enum WalletLedgerKind {
  sale,
  payout,
  topup,
  purchase,
  neutral;

  static WalletLedgerKind fromType(String? type) {
    if (type == null) {
      return WalletLedgerKind.neutral;
    }
    if (type.contains('sale') || type.contains('earning')) {
      return WalletLedgerKind.sale;
    }
    if (type.contains('payout') || type.contains('withdraw')) {
      return WalletLedgerKind.payout;
    }
    if (type.contains('topup') || type.contains('recharge')) {
      return WalletLedgerKind.topup;
    }
    if (type.contains('purchase') || type.contains('buy')) {
      return WalletLedgerKind.purchase;
    }
    return WalletLedgerKind.neutral;
  }
}
