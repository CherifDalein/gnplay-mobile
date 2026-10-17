class TopupCheckout {
  const TopupCheckout({required this.paymentUrl, required this.reference});

  final String paymentUrl;
  final String reference;
}

/// États d'une recharge côté backend (`TopupStatus`) : le crédit n'est
/// appliqué qu'à `completed`, via le webhook DexPay.
enum TopupStatus {
  pending,
  completed,
  failed,
  cancelled;

  static TopupStatus parse(String? value) {
    return switch (value?.toLowerCase()) {
      'completed' => TopupStatus.completed,
      'failed' => TopupStatus.failed,
      'cancelled' => TopupStatus.cancelled,
      _ => TopupStatus.pending,
    };
  }

  bool get isFinal => this != TopupStatus.pending;
}
