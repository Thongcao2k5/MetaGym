import 'package:intl/intl.dart';

String formatProgressTime(String value) =>
    DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(value).toLocal());

DateTime? parseProgressTime(String value) {
  final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4}) (\d{2}):(\d{2})$')
      .firstMatch(value.trim());
  if (match == null) return null;
  final day = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final year = int.parse(match[3]!);
  final hour = int.parse(match[4]!);
  final minute = int.parse(match[5]!);
  final date = DateTime(year, month, day, hour, minute);
  return date.year == year &&
          date.month == month &&
          date.day == day &&
          date.hour == hour &&
          date.minute == minute
      ? date
      : null;
}
