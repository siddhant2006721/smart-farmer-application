import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Farm Mitra Real-Time Awareness Tests', () {
    test('Dynamic DateTime.now() correctly computes current date, month, day, and year', () {
      final now = DateTime.now();
      final currentMonth = DateFormat('MMMM').format(now);
      final currentDate = DateFormat('d MMMM yyyy').format(now);
      final currentDay = DateFormat('EEEE').format(now);
      final currentYear = now.year.toString();

      expect(currentMonth, isNotEmpty);
      expect(currentDate, isNotEmpty);
      expect(currentDay, isNotEmpty);
      expect(currentYear, now.year.toString());

      final yesterday = DateFormat('d MMMM yyyy').format(now.subtract(const Duration(days: 1)));
      final tomorrow = DateFormat('d MMMM yyyy').format(now.add(const Duration(days: 1)));

      expect(yesterday, isNot(currentDate));
      expect(tomorrow, isNot(currentDate));
    });

    test('Month names and formatting match standard calendar months', () {
      final testDateAugust = DateTime(2026, 8, 28);
      expect(DateFormat('MMMM').format(testDateAugust), 'August');
      expect(DateFormat('d MMMM yyyy').format(testDateAugust), '28 August 2026');
      expect(DateFormat('EEEE').format(testDateAugust), 'Friday');
    });
  });
}
