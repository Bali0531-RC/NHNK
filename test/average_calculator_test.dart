import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhnk/MarkbookElements/markbook_element_widget.dart';
import 'package:nhnk/Misc/average_calculator.dart';
import 'package:nhnk/colors.dart';
import 'package:nhnk/language.dart';

void main() {
  test('zero-credit ghost grades affect only the arithmetic average', () {
    final averages = calculateMarkbookAverages([
      (credit: 6, grade: 3, completed: true, ghostGrade: -1),
      (credit: 0, grade: 0, completed: false, ghostGrade: 5),
    ]);
    expect(averages.arithmetic, 4);
    expect(averages.weighted, 3);
    expect(averages.creditIndex, closeTo(0.6, 0.0001));
    expect(averages.gradedCredits, 6);
  });

  test('only zero-credit numeric grades still have an arithmetic average', () {
    final averages = calculateMarkbookAverages([
      (credit: 0, grade: 4, completed: true, ghostGrade: -1),
      (credit: 0, grade: 0, completed: false, ghostGrade: 2),
    ]);
    expect(averages.arithmetic, 3);
    expect(averages.weighted.isNaN, isTrue);
    expect(averages.creditIndex, 0);
    expect(averages.gradedCredits, 0);
  });

  test('removing a zero-credit ghost removes its contribution', () {
    final averages = calculateMarkbookAverages([
      (credit: 6, grade: 3, completed: true, ghostGrade: -1),
      (credit: 0, grade: 0, completed: false, ghostGrade: -1),
    ]);
    expect(averages.arithmetic, 3);
    expect(averages.weighted, 3);
  });

  test('completion without a numeric mark is not a grade', () {
    final averages = calculateMarkbookAverages([
      (credit: 0, grade: 0, completed: true, ghostGrade: -1),
      (credit: 6, grade: 4, completed: true, ghostGrade: -1),
    ]);
    expect(averages.arithmetic, 4);
    expect(averages.weighted, 4);
  });

  test('failed marks count in arithmetic and can be replaced by a ghost', () {
    final averages = calculateMarkbookAverages([
      (credit: 0, grade: 1, completed: false, ghostGrade: -1),
      (credit: 6, grade: 1, completed: false, ghostGrade: 5),
    ]);
    expect(averages.arithmetic, 3);
    expect(averages.weighted, 5);
    expect(averages.creditIndex, 1);
  });

  test('ghosts do not override actual passing grades', () {
    final averages = calculateMarkbookAverages([
      (credit: 6, grade: 4, completed: true, ghostGrade: 5),
    ]);
    expect(averages.arithmetic, 4);
    expect(averages.weighted, 4);
  });

  test('an empty markbook has no arithmetic or weighted average', () {
    final averages = calculateMarkbookAverages([]);
    expect(averages.arithmetic.isNaN, isTrue);
    expect(averages.weighted.isNaN, isTrue);
    expect(averages.creditIndex, 0);
  });

  testWidgets('zero-credit subjects allow and display ghost grades', (tester) async {
    AppStrings.initialize();
    AppColors.initialize();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MarkbookElementWidget(
      name: 'Zero-credit subject', credit: 0, completed: false, grade: 0,
      isFailed: false, onPopupResult: (_, __) {}, listIndex: 0, ghostGrade: 5,
    ))));
    final gesture = tester.widget<GestureDetector>(find.descendant(
      of: find.byType(MarkbookElementWidget), matching: find.byType(GestureDetector),
    ));
    expect(gesture.onTap, isNotNull);
    expect(find.text('5'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  testWidgets('a real zero-credit grade stays visible and cannot be overwritten', (tester) async {
    AppStrings.initialize();
    AppColors.initialize();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MarkbookElementWidget(
      name: 'Zero-credit subject', credit: 0, completed: true, grade: 4,
      isFailed: false, onPopupResult: (_, __) {}, listIndex: 0, ghostGrade: -1,
    ))));
    final gesture = tester.widget<GestureDetector>(find.descendant(
      of: find.byType(MarkbookElementWidget), matching: find.byType(GestureDetector),
    ));
    expect(gesture.onTap, isNull);
    expect(find.text('4'), findsOneWidget);
  });

  test('no grades yet means the target is simply the target', () {
    // NaN is what the markbook produces when nothing is graded (0/0).
    expect(
      requiredAverage(currentAverage: double.nan, currentCredits: 30, target: 4, remainingCredits: 30),
      closeTo(4, 0.001),
    );
    expect(
      requiredAverage(currentAverage: 0, currentCredits: 30, target: 4, remainingCredits: 30),
      closeTo(4, 0.001),
    );
  });

  test('existing grades pull the requirement up or down', () {
    // 30 credits at 3.0, wanting 4.0 overall across 60 credits -> 5.0 needed.
    expect(
      requiredAverage(currentAverage: 3, currentCredits: 30, target: 4, remainingCredits: 30),
      closeTo(5, 0.001),
    );
    // Already above target, so less is needed.
    expect(
      requiredAverage(currentAverage: 5, currentCredits: 30, target: 4, remainingCredits: 30),
      closeTo(3, 0.001),
    );
  });

  test('unequal credit weights', () {
    // 60 credits at 4.5, 10 left, target 4.0 -> only 1.0 needed on the remainder.
    expect(
      requiredAverage(currentAverage: 4.5, currentCredits: 60, target: 4, remainingCredits: 10),
      closeTo(1.0, 0.001),
    );
  });

  test('no remaining credits is not answerable', () {
    expect(requiredAverage(currentAverage: 4, currentCredits: 30, target: 5, remainingCredits: 0), isNull);
  });
}
