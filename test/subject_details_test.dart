import 'package:flutter_test/flutter_test.dart';
import 'package:nhnk/API/api_coms.dart' as api;
import 'package:nhnk/storage.dart' as storage;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a subject keeps its ids and assessment type through the cache', () {
    final original = api.Subject(false, 6, 'A programozás alapjai\t', 0, 0, 0,
        subjectId: 'sub-1', termId: 'term-1', requirementType: 'Vizsga', code: 'VEMISAB146AP');
    final restored = api.Subject(false, 0, 'NULL', 0, 0, 0).fillWithExisting(original.toString());
    expect(restored.subjectId, 'sub-1');
    expect(restored.termId, 'term-1');
    expect(restored.requirementType, 'Vizsga');
    expect(restored.code, 'VEMISAB146AP');
    expect(restored.name, original.name);
  });

  test('subjects cached before the ids were stored still load', () {
    final restored = api.Subject(false, 0, 'NULL', 0, 0, 0)
        .fillWithExisting('true\n3\n0\nAnalízis I.\n4\n0');
    expect(restored.name, 'Analízis I.');
    expect(restored.subjectId, isNull);
    expect(restored.requirementType, '');
  });

  test('details are read from the server shape and the HTML description is flattened', () {
    final details = api.SubjectDetails.fromJson({
      'requirementType': 'Vizsga',
      'ownerPrintName': 'Dr. Teszt Elek',
      'interiorOrganization': 'Tanszék',
      'description': '<p>Első&nbsp;sor</p><p>Második &amp; harmadik</p>',
      'downloadSubjectThematicsEnabled': true,
      'classesPerWeek': [
        {'courseType': 'Elmélet', 'classesPerWeek': 2}
      ],
      'classesPerTerm': [
        {'courseType': 'Elmélet', 'classesPerTerm': 24}
      ],
      'subjectResult': {'typeName': 'Vizsgajegy'},
    });
    expect(details.thematicsAvailable, isTrue);
    expect(details.hoursPerWeek, {'Elmélet': 2});
    expect(details.hoursPerTerm, {'Elmélet': 24});
    expect(details.resultType, 'Vizsgajegy');
    expect(details.description, 'Első sor\nMásodik & harmadik');
  });

  test('missing fields do not break the details', () {
    final details = api.SubjectDetails.fromJson({});
    expect(details.thematicsAvailable, isFalse);
    expect(details.hoursPerWeek, isEmpty);
    expect(details.description, '');
  });

  group('state funding', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('only a full state scholarship hides the payments tab', () async {
      await storage.DataCache.setFinancialStatus('Állami ösztöndíjas');
      expect(storage.DataCache.isStateFunded(), isTrue);
      await storage.DataCache.setFinancialStatus('Állami részösztöndíjas');
      expect(storage.DataCache.isStateFunded(), isFalse);
      await storage.DataCache.setFinancialStatus('Önköltséges');
      expect(storage.DataCache.isStateFunded(), isFalse);
      await storage.DataCache.setFinancialStatus('');
      expect(storage.DataCache.isStateFunded(), isFalse);
    });
  });
}
