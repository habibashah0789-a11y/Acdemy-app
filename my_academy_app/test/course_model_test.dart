import 'package:flutter_test/flutter_test.dart';
import 'package:my_academy_app/models/course_model.dart';

void main() {
  test('Course serialization roundtrip', () {
    final c = CourseModel(
      id: 'id123',
      name: 'T1',
      description: 'Desc',
      teacherId: 'teacher1',
      fee: 1000,
      duration: '3 months',
    );
    final map = c.toMap();
    final c2 = CourseModel.fromMap(map, 'id123');
    expect(c2.id, 'id123');
    expect(c2.name, 'T1');
    expect(c2.description, 'Desc');
  });
}
