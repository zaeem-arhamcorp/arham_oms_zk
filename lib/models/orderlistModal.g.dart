// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'orderlistModal.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DatumOrderListAdapter extends TypeAdapter<DatumOrderList> {
  @override
  final int typeId = 1;

  @override
  DatumOrderList read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DatumOrderList(
      oId: fields[0] as dynamic,
      vouchDt: fields[1] as dynamic,
      vouchTime: fields[2] as dynamic,
      partyCd: fields[3] as dynamic,
      lastEdit: fields[4] as dynamic,
      entryComp: fields[5] as dynamic,
      billNo: fields[6] as dynamic,
      syncId: fields[7] as dynamic,
      billDt: fields[8] as dynamic,
      netAmt: fields[9] as dynamic,
      orderNo: fields[10] as dynamic,
      ordritms: (fields[11] as List).cast<DataOrdritm>(),
    );
  }

  @override
  void write(BinaryWriter writer, DatumOrderList obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.oId)
      ..writeByte(1)
      ..write(obj.vouchDt)
      ..writeByte(2)
      ..write(obj.vouchTime)
      ..writeByte(3)
      ..write(obj.partyCd)
      ..writeByte(4)
      ..write(obj.lastEdit)
      ..writeByte(5)
      ..write(obj.entryComp)
      ..writeByte(6)
      ..write(obj.billNo)
      ..writeByte(7)
      ..write(obj.syncId)
      ..writeByte(8)
      ..write(obj.billDt)
      ..writeByte(9)
      ..write(obj.netAmt)
      ..writeByte(10)
      ..write(obj.orderNo)
      ..writeByte(11)
      ..write(obj.ordritms);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DatumOrderListAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DataOrdritmAdapter extends TypeAdapter<DataOrdritm> {
  @override
  final int typeId = 2;

  @override
  DataOrdritm read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DataOrdritm(
      odId: fields[0] as dynamic,
      oId: fields[1] as dynamic,
      itemSr: fields[2] as dynamic,
      vouchDt: fields[3] as dynamic,
      vouchTime: fields[4] as dynamic,
      pCd: fields[5] as dynamic,
      itemCd: fields[6] as dynamic,
      lastEdit: fields[7] as dynamic,
      quantity: fields[8] as dynamic,
      rate: fields[9] as dynamic,
      syncId: fields[10] as dynamic,
      amount: fields[11] as dynamic,
      otherDesc: fields[12] as dynamic,
    );
  }

  @override
  void write(BinaryWriter writer, DataOrdritm obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.odId)
      ..writeByte(1)
      ..write(obj.oId)
      ..writeByte(2)
      ..write(obj.itemSr)
      ..writeByte(3)
      ..write(obj.vouchDt)
      ..writeByte(4)
      ..write(obj.vouchTime)
      ..writeByte(5)
      ..write(obj.pCd)
      ..writeByte(6)
      ..write(obj.itemCd)
      ..writeByte(7)
      ..write(obj.lastEdit)
      ..writeByte(8)
      ..write(obj.quantity)
      ..writeByte(9)
      ..write(obj.rate)
      ..writeByte(10)
      ..write(obj.syncId)
      ..writeByte(11)
      ..write(obj.amount)
      ..writeByte(12)
      ..write(obj.otherDesc);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataOrdritmAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
