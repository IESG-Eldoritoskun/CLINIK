import 'package:flutter_test/flutter_test.dart';

import 'package:clinik/main.dart';
import 'package:clinik/screens/home_screen.dart';
import 'package:clinik/screens/patient_activity_screen.dart';

void main() {
  test('ClinikApp se puede instanciar', () {
    const app = ClinikApp();
    expect(app, isNotNull);
  });

  test('calcula calorías estimadas según tipo de ejercicio y duración', () {
    expect(PatientActivityScreen.estimateCaloriesForExercise('Caminata', 30), equals(94));
    expect(PatientActivityScreen.estimateCaloriesForExercise('Correr', 20), greaterThan(200));
    expect(PatientActivityScreen.estimateCaloriesForExercise('Gimnasio', 45), greaterThan(0));
  });

  test('HomeScreen formatea las lecturas reales de Supabase', () {
    expect(HomeScreen.formatMetricDisplay(
      type: 'glucosa',
      data: {'valor': 105, 'unidad': 'mg/dL'},
    ), equals('105'));

    expect(HomeScreen.formatMetricDisplay(
      type: 'presion',
      data: {'sistolica': 120, 'diastolica': 80},
    ), equals('120/80'));
  });
}
