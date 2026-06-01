import 'package:flutter_test/flutter_test.dart';
import 'package:ink_splash/src/ui/time_format.dart';
import 'package:intl/intl.dart';

void main() {
  test('formats utc iso time as local time', () {
    final source = DateTime.utc(2026, 6, 1, 8, 30);
    final expected = DateFormat(
      source.toLocal().day == DateTime.now().day &&
              source.toLocal().month == DateTime.now().month &&
              source.toLocal().year == DateTime.now().year
          ? 'HH:mm'
          : 'yyyy-MM-dd HH:mm',
    ).format(source.toLocal());

    expect(formatLocalTime(source.toIso8601String()), expected);
  });

  test('returns empty or original value for missing and invalid time', () {
    expect(formatLocalTime(null), '');
    expect(formatLocalTime(''), '');
    expect(formatLocalTime('not-a-date'), 'not-a-date');
  });

  test('joinDetails skips empty values', () {
    expect(joinDetails(['A', '', null, 'B']), 'A · B');
    expect(joinDetails(['A', 'B'], separator: ' | '), 'A | B');
  });
}
