// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ordermodal.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OrdermodalAdapter extends TypeAdapter<Ordermodal> {
  @override
  final int typeId = 3;

  @override
  Ordermodal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Ordermodal(
      partyCd: fields[0] as String,
      netAmt: fields[1] as String,
      orderItm: (fields[2] as List).cast<OrderItm>(),
    );
  }

  @override
  void write(BinaryWriter writer, Ordermodal obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.partyCd)
      ..writeByte(1)
      ..write(obj.netAmt)
      ..writeByte(2)
      ..write(obj.orderItm);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrdermodalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OrderItmAdapter extends TypeAdapter<OrderItm> {
  @override
  final int typeId = 4;

  @override
  OrderItm read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OrderItm(
      itemCd: fields[0] as String,
      qty: fields[1] as int,
      rate: fields[2] as double,
      amt: fields[3] as double,
      otherDesc: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, OrderItm obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.itemCd)
      ..writeByte(1)
      ..write(obj.qty)
      ..writeByte(2)
      ..write(obj.rate)
      ..writeByte(3)
      ..write(obj.amt)
      ..writeByte(4)
      ..write(obj.otherDesc);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderItmAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
