class PayoutBalances {
  const PayoutBalances({
    required this.walletBalance,
    required this.withdrawableBalance,
    required this.pendingEarnings,
  });

  final int walletBalance;
  final int withdrawableBalance;
  final int pendingEarnings;
}
