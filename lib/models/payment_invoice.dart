class PaymentInvoice {
  const PaymentInvoice({
    required this.id,
    required this.payerId,
    required this.amount,
    required this.currency,
    required this.status,
    required this.createdAt,
    this.stripePaymentIntentId,
    this.refundId,
  });

  final String id;
  final String payerId;
  final double amount;
  final String currency;
  final String status;
  final DateTime createdAt;
  final String? stripePaymentIntentId;
  final String? refundId;

  Map<String, dynamic> toMap() => {
        'payerId': payerId,
        'amount': amount,
        'currency': currency,
        'status': status,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'stripePaymentIntentId': stripePaymentIntentId,
        'refundId': refundId,
      };
}
