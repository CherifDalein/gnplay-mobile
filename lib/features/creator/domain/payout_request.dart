import '../../../shared/utils/json_helpers.dart';

enum PayoutStatus {
  pending,
  processing,
  completed,
  failed,
  cancelled;

  static PayoutStatus fromRaw(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'processing':
        return PayoutStatus.processing;
      case 'completed':
        return PayoutStatus.completed;
      case 'failed':
        return PayoutStatus.failed;
      case 'cancelled':
        return PayoutStatus.cancelled;
      case 'pending':
      default:
        return PayoutStatus.pending;
    }
  }

  String get label {
    switch (this) {
      case PayoutStatus.pending:
        return 'En attente';
      case PayoutStatus.processing:
        return 'En cours';
      case PayoutStatus.completed:
        return 'Retrait terminé';
      case PayoutStatus.failed:
        return 'Retrait échoué';
      case PayoutStatus.cancelled:
        return 'Annulé';
    }
  }

  bool get isPending =>
      this == PayoutStatus.pending || this == PayoutStatus.processing;
}

class PayoutRequestRecord {
  const PayoutRequestRecord({
    required this.id,
    required this.amount,
    required this.status,
    required this.reference,
    required this.destinationPhone,
    required this.operator,
    required this.createdAt,
    this.fees,
    this.failureReason,
    this.processedAt,
  });

  final String id;
  final int amount;
  final int? fees;
  final PayoutStatus status;
  final String reference;
  final String destinationPhone;
  final String operator;
  final String? failureReason;
  final DateTime createdAt;
  final DateTime? processedAt;

  factory PayoutRequestRecord.fromJson(Map<String, dynamic> json) {
    return PayoutRequestRecord(
      id: jsonString(json['id'], fallback: ''),
      amount: jsonInt(json['amount']),
      fees: json['fees'] == null ? null : jsonInt(json['fees']),
      status: PayoutStatus.fromRaw(jsonNullableString(json['status'])),
      reference: jsonString(json['reference'], fallback: ''),
      destinationPhone: jsonString(json['destination_phone'], fallback: ''),
      operator: jsonString(json['operator'], fallback: ''),
      failureReason: jsonNullableString(json['failure_reason']),
      createdAt: jsonDate(json['created_at']) ?? DateTime.now(),
      processedAt: jsonDate(json['processed_at']),
    );
  }
}
