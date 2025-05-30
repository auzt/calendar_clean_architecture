// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_event_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CalendarEventModelAdapter extends TypeAdapter<CalendarEventModel> {
  @override
  final int typeId = 0;

  @override
  CalendarEventModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CalendarEventModel(
      id: fields[0] as String,
      title: fields[1] as String,
      startTime: fields[3] as DateTime,
      endTime: fields[4] as DateTime,
      description: fields[2] as String?,
      location: fields[5] as String?,
      isAllDay: fields[6] as bool,
      color: fields[7] as Color,
      googleEventId: fields[8] as String?,
      attendees: (fields[9] as List).cast<String>(),
      recurrence: fields[10] as String?,
      isFromGoogle: fields[11] as bool,
      lastModified: fields[12] as DateTime?,
      createdBy: fields[13] as String?,
      additionalData: (fields[14] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, CalendarEventModel obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.startTime)
      ..writeByte(4)
      ..write(obj.endTime)
      ..writeByte(5)
      ..write(obj.location)
      ..writeByte(6)
      ..write(obj.isAllDay)
      ..writeByte(7)
      ..write(obj.color)
      ..writeByte(8)
      ..write(obj.googleEventId)
      ..writeByte(9)
      ..write(obj.attendees)
      ..writeByte(10)
      ..write(obj.recurrence)
      ..writeByte(11)
      ..write(obj.isFromGoogle)
      ..writeByte(12)
      ..write(obj.lastModified)
      ..writeByte(13)
      ..write(obj.createdBy)
      ..writeByte(14)
      ..write(obj.additionalData);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarEventModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CalendarEventModel _$CalendarEventModelFromJson(Map<String, dynamic> json) =>
    CalendarEventModel(
      id: json['id'] as String,
      title: json['title'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      description: json['description'] as String?,
      location: json['location'] as String?,
      isAllDay: json['isAllDay'] as bool? ?? false,
      color: json['color'] == null
          ? Colors.blue
          : CalendarEventModel._colorFromJson((json['color'] as num).toInt()),
      googleEventId: json['googleEventId'] as String?,
      attendees: (json['attendees'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      recurrence: json['recurrence'] as String?,
      isFromGoogle: json['isFromGoogle'] as bool? ?? false,
      lastModified: json['lastModified'] == null
          ? null
          : DateTime.parse(json['lastModified'] as String),
      createdBy: json['createdBy'] as String?,
      additionalData: json['additionalData'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$CalendarEventModelToJson(CalendarEventModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'startTime': instance.startTime.toIso8601String(),
      'endTime': instance.endTime.toIso8601String(),
      'location': instance.location,
      'isAllDay': instance.isAllDay,
      'color': CalendarEventModel._colorToJson(instance.color),
      'googleEventId': instance.googleEventId,
      'attendees': instance.attendees,
      'recurrence': instance.recurrence,
      'isFromGoogle': instance.isFromGoogle,
      'lastModified': instance.lastModified?.toIso8601String(),
      'createdBy': instance.createdBy,
      'additionalData': instance.additionalData,
    };
