import 'package:flutter_test/flutter_test.dart';
import 'package:nhnk/API/api_coms.dart';

CalendarEntry _restore(String line) =>
    CalendarEntry('0', '0', 'NULL', 'NULL', false).fillWithExisting(line);

void main() {
  // The Upcoming cache is persisted with the same newline format the weekly calendar
  // cache already uses, so the round trip has to hold for the entries it stores.
  test('an exam survives the cache round trip', () {
    final entry = CalendarEntry.fromModern(
      startEpoch: 1735689600000,
      endEpoch: 1735693200000,
      location: 'B-201',
      title: 'Analizis 1',
      eventType: 1,
      subjectCode: 'IPM-ANAL1',
      teacher: 'Dr Teszt Elek',
      classInstanceId: 'abc-123',
      taskId: null,
    );

    final restored = _restore(entry.toString());

    expect(restored.startEpoch, entry.startEpoch);
    expect(restored.endEpoch, entry.endEpoch);
    expect(restored.location, entry.location);
    expect(restored.title, entry.title);
    expect(restored.eventType, entry.eventType);
    expect(restored.subjectCode, entry.subjectCode);
    expect(restored.teacher, entry.teacher);
    expect(restored.classInstanceId, 'abc-123');
    expect(restored.taskId, isNull);
    expect(restored.isExam, isTrue);
  });

  test('a task keeps its task id and stays a task', () {
    final entry = CalendarEntry.fromModern(
      startEpoch: 1735689600000,
      endEpoch: 1735689600000,
      location: '',
      title: 'Beadando',
      eventType: 2,
      subjectCode: 'IPM-PROG',
      teacher: '-',
      classInstanceId: null,
      taskId: 'task-9',
    );

    final restored = _restore(entry.toString());

    expect(restored.taskId, 'task-9');
    expect(restored.classInstanceId, isNull);
    expect(restored.isTask, isTrue);
    expect(restored.isExam, isFalse);
  });

  test('a truncated cache line is left alone instead of throwing', () {
    final restored = _restore('123\n456');
    expect(restored.title, 'NULL');
  });
}
