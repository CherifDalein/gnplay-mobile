String formatGrouped(int value) {
  final sign = value < 0 ? '-' : '';
  final raw = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) {
      buffer.write(' ');
    }
    buffer.write(raw[i]);
  }
  return '$sign$buffer';
}

String formatMoney(int amount, {bool withCurrency = true}) {
  final value = formatGrouped(amount);
  return withCurrency ? '$value GNF' : value;
}

String formatCompact(int value) {
  if (value.abs() >= 1000000) {
    final millions = value / 1000000;
    return '${millions.toStringAsFixed(2).replaceAll('.', ',')} M';
  }
  if (value.abs() >= 1000) {
    final thousands = value / 1000;
    return '${thousands.toStringAsFixed(1).replaceAll('.', ',')} k';
  }
  return formatGrouped(value);
}

String formatDurationShort(int seconds) {
  if (seconds <= 0) {
    return '0 min';
  }

  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remainingSeconds = seconds % 60;

  if (hours > 0) {
    return '${hours}h ${minutes.toString().padLeft(2, '0')}';
  }

  return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
}
