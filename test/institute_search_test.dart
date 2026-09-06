import 'package:flutter_test/flutter_test.dart';
import 'package:nhnk/Pages/onboarding/institute_search.dart';

/// Hungarian institution names carry accents that people do not type when
/// searching, which made the old list look empty for a valid query.
void main() {
  const names = [
    'Óbudai Egyetem',
    'Szegedi Tudományegyetem',
    'A Tan Kapuja Buddhista Főiskola',
    'Budapesti Corvinus Egyetem',
  ];

  List<String> search(String query) =>
      names.where((n) => instituteMatches(n, query)).toList();

  test('an unaccented query finds an accented name', () {
    expect(search('obuda'), ['Óbudai Egyetem']);
    expect(search('tudomanyegyetem'), ['Szegedi Tudományegyetem']);
    expect(search('foiskola'), ['A Tan Kapuja Buddhista Főiskola']);
  });

  test('the accented spelling still works', () {
    expect(search('Óbudai'), ['Óbudai Egyetem']);
  });

  test('matching ignores case and surrounding space', () {
    expect(search('  CORVINUS '), ['Budapesti Corvinus Egyetem']);
  });

  test('an empty query is treated as matching everything', () {
    expect(search(''), names);
  });

  test('a query that matches nothing returns nothing', () {
    expect(search('cambridge'), isEmpty);
  });
}
