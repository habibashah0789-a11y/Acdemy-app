
import 'package:hive/hive.dart';

part 'course_model.g.dart';

@HiveType(typeId: 2)
class CourseModel extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String name;
  @HiveField(2)
  String description;
  @HiveField(3)
  String teacherId;
  @HiveField(4)
  double fee;
  @HiveField(5)
  String duration;

  CourseModel({
    required this.id,
    required this.name,
    required this.description,
    required this.teacherId,
    required this.fee,
    required this.duration,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'teacherId': teacherId,
      'fee': fee,
      'duration': duration,
    };
  }

  factory CourseModel.fromMap(Map<String, dynamic> map, String docId) {
    return CourseModel(
      id: docId,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      teacherId: map['teacherId'] ?? '',
      fee: (map['fee'] ?? 0).toDouble(),
      duration: map['duration'] ?? '',
    );
  }
}
