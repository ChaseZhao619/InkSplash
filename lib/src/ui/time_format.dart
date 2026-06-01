import 'package:intl/intl.dart';

String formatLocalTime(String? value) {
  if (value == null || value.trim().isEmpty) {
    return '';
  }
  try {
    final local = DateTime.parse(value).toLocal();
    final now = DateTime.now();
    final sameDay =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    return DateFormat(sameDay ? 'HH:mm' : 'yyyy-MM-dd HH:mm').format(local);
  } catch (_) {
    return value;
  }
}

String joinDetails(Iterable<String?> values, {String separator = ' · '}) {
  return values
      .whereType<String>()
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .join(separator);
}
