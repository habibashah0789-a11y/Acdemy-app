// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recycled_student.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecycledStudentAdapter extends TypeAdapter<RecycledStudent> {
  @override
  final int typeId = 1;

  @override
  RecycledStudent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecycledStudent(
      id: fields[0] as String,
      firstName: fields[1] as String,
      lastName: fields[2] as String,
      fatherName: fields[3] as String,
      phone: fields[4] as String,
      email: fields[5] as String,
      schedule: fields[6] as String,
      feeSubmitted: fields[7] as double,
      feeRemaining: fields[8] as double,
      biologyFee: fields[9] as double,
      physicsFee: fields[10] as double,
      chemistryFee: fields[11] as double,
      englishFee: fields[12] as double,
      profilePicUrl: fields[13] as String,
      enrollmentStatus: fields[14] as String,
      classType: fields[15] as String,
      grade: fields[16] as String,
      subject: fields[17] as String,
      mathFee: fields[18] as double,
      createdAt: fields[19] as DateTime?,
      updatedAt: fields[20] as DateTime?,
      isActive: fields[21] as bool,
      deletedAt: fields[22] as DateTime,
      paymentHistoryJson: fields[23] as String?,
      subjectSchedulesJson: fields[24] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, RecycledStudent obj) {
    writer
      ..writeByte(25)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.firstName)
      ..writeByte(2)
      ..write(obj.lastName)
      ..writeByte(3)
      ..write(obj.fatherName)
      ..writeByte(4)
      ..write(obj.phone)
      ..writeByte(5)
      ..write(obj.email)
      ..writeByte(6)
      ..write(obj.schedule)
      ..writeByte(7)
      ..write(obj.feeSubmitted)
      ..writeByte(8)
      ..write(obj.feeRemaining)
      ..writeByte(9)
      ..write(obj.biologyFee)
      ..writeByte(10)
      ..write(obj.physicsFee)
      ..writeByte(11)
      ..write(obj.chemistryFee)
      ..writeByte(12)
      ..write(obj.englishFee)
      ..writeByte(13)
      ..write(obj.profilePicUrl)
      ..writeByte(14)
      ..write(obj.enrollmentStatus)
      ..writeByte(15)
      ..write(obj.classType)
      ..writeByte(16)
      ..write(obj.grade)
      ..writeByte(17)
      ..write(obj.subject)
      ..writeByte(18)
      ..write(obj.mathFee)
      ..writeByte(19)
      ..write(obj.createdAt)
      ..writeByte(20)
      ..write(obj.updatedAt)
      ..writeByte(21)
      ..write(obj.isActive)
      ..writeByte(22)
      ..write(obj.deletedAt)
      ..writeByte(23)
      ..write(obj.paymentHistoryJson)
      ..writeByte(24)
      ..write(obj.subjectSchedulesJson);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecycledStudentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
