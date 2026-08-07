import 'package:flutter_test/flutter_test.dart';
import 'package:nhnk/local_file_actions.dart';

class _E {
  final int startEpoch;
  final int endEpoch;
  final String title;
  final String location;
  final String teacher;
  _E(this.startEpoch, this.endEpoch, this.title, this.location, this.teacher);
}

void main() {
  test('ics export is well formed', () {
    final start = DateTime(2026, 9, 14, 8, 0).millisecondsSinceEpoch;
    final end = DateTime(2026, 9, 14, 9, 30).millisecondsSinceEpoch;
    final ics = IcsExportHelper.buildIcs([
      _E(start, end, 'Analízis I; gyakorlat, csoport A', 'B épület, 101', 'Dr. Teszt Elek'),
      _E(start, end, 'A' * 200, '', '-'),
    ]);

    final lines = ics.split('\r\n');
    expect(lines.first, 'BEGIN:VCALENDAR');
    expect(lines.where((l) => l == 'END:VCALENDAR').length, 1);
    expect(lines.where((l) => l == 'BEGIN:VEVENT').length, 2);
    expect(lines.where((l) => l == 'END:VEVENT').length, 2);

    // separators must be escaped, not raw
    expect(ics.contains('SUMMARY:Analízis I\\; gyakorlat\\, csoport A'), isTrue);
    expect(ics.contains('LOCATION:B épület\\, 101'), isTrue);

    // "-" teacher is a placeholder and should be dropped
    expect(ics.contains('DESCRIPTION:-'), isFalse);
    expect(ics.contains('DESCRIPTION:Dr. Teszt Elek'), isTrue);

    // UTC stamps, not local
    expect(RegExp(r'DTSTART:\d{8}T\d{6}Z').hasMatch(ics), isTrue);
    expect(RegExp(r'DTEND:\d{8}T\d{6}Z').hasMatch(ics), isTrue);
    expect(RegExp(r'DTSTAMP:\d{8}T\d{6}Z').hasMatch(ics), isTrue);

    // every content line within the RFC 5545 limit; continuations start with a space
    for (final line in lines) {
      expect(line.length <= 75, isTrue, reason: 'too long: $line');
    }
    expect(lines.any((l) => l.startsWith(' ')), isTrue);

    expect(IcsExportHelper.buildIcs([]).contains('BEGIN:VEVENT'), isFalse);
  });
}
