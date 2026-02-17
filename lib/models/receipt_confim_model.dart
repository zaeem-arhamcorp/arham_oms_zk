import 'dart:convert';

ReceiptConfirmModel ReceiptConfirmModelFromJson(String str) =>
    ReceiptConfirmModel.fromJson(json.decode(str));

String ReceiptConfirmModelModalToJson(ReceiptConfirmModel data) =>
    json.encode(data.toJson());

class ReceiptConfirmModel {
  String? message;
  List<Data>? data;

  ReceiptConfirmModel({this.message, this.data});

  ReceiptConfirmModel.fromJson(Map<String, dynamic> json) {
    message = json['message'];
    if (json['data'] != null) {
      data = <Data>[];
      json['data'].forEach((v) {
        data!.add(Data.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['message'] = message;
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

// class Data {
//   String? vOUCHDT;
//   num? vOUCHNO;
//   String? aUTOVNO;
//   String? tERMINAL;
//   String? rEFNO;
//   String? vOUCHTIME;
//   String? bOOKCD;
//   String? gSTFORM;
//   String? cSHBNKCD;
//   String? cBNAME;
//   String? pARTYCD;
//   String? pARTYNAME;
//   String? cHQNAME;
//   String? cHQDETL;
//   String? oTHPARTY;
//   num? aMOUNT;
//   bool? iSVALID;
//   String? rPTPAYDTL;
//   String? nARRATION;
//   String? nARRATION1;
//   String? nARRATION2;
//   String? cHQDT;
//   String? cHQNO;
//   String? rEALNARR;
//   String? cHQCLGDT;
//   String? kASARCD;
//   String? tOTKASAR;
//   String? dNCNCD;
//   String? tOTDNCN;
//   String? sMANCD;
//   String? pAIDTBP;
//   String? nONTAXABLE;
//   String? nETAMT;
//   String? uSERCD;
//   num? sYNCID;
//   String? lASTEDIT;
//   String? eNTRYCOMP;
//   String? aDDDT;
//   String? aDDTM;
//   String? mODIFYDT;
//   String? mODIFYTM;
//   String? dELETEDT;
//   String? dELETETM;
//   String? dATAUPDTD;
//   String? uPDATEDAT;
//   String? cREATEDAT;
//   List<BillwiseSettlements>? billwiseSettlements;
//   Party? party;
//   Party? cshbnkParty;
//
//   Data(
//       {this.vOUCHDT,
//       this.vOUCHNO,
//       this.aUTOVNO,
//       this.tERMINAL,
//       this.rEFNO,
//       this.vOUCHTIME,
//       this.bOOKCD,
//       this.gSTFORM,
//       this.cSHBNKCD,
//       this.cBNAME,
//       this.pARTYCD,
//       this.pARTYNAME,
//       this.cHQNAME,
//       this.cHQDETL,
//       this.oTHPARTY,
//       this.aMOUNT,
//       this.iSVALID,
//       this.rPTPAYDTL,
//       this.nARRATION,
//       this.nARRATION1,
//       this.nARRATION2,
//       this.cHQDT,
//       this.cHQNO,
//       this.rEALNARR,
//       this.cHQCLGDT,
//       this.kASARCD,
//       this.tOTKASAR,
//       this.dNCNCD,
//       this.tOTDNCN,
//       this.sMANCD,
//       this.pAIDTBP,
//       this.nONTAXABLE,
//       this.nETAMT,
//       this.uSERCD,
//       this.sYNCID,
//       this.lASTEDIT,
//       this.eNTRYCOMP,
//       this.aDDDT,
//       this.aDDTM,
//       this.mODIFYDT,
//       this.mODIFYTM,
//       this.dELETEDT,
//       this.dELETETM,
//       this.dATAUPDTD,
//       this.uPDATEDAT,
//       this.cREATEDAT,
//       this.billwiseSettlements,
//       this.party,
//       this.cshbnkParty});
//
//   Data.fromJson(Map<String, dynamic> json) {
//     vOUCHDT = json['VOUCH_DT'];
//     vOUCHNO = json['VOUCH_NO'];
//     aUTOVNO = json['AUTO_VNO'];
//     tERMINAL = json['TERMINAL'];
//     rEFNO = json['REF_NO'];
//     vOUCHTIME = json['VOUCH_TIME'];
//     bOOKCD = json['BOOK_CD'];
//     gSTFORM = json['GST_FORM'];
//     cSHBNKCD = json['CSHBNK_CD'];
//     cBNAME = json['CB_NAME'];
//     pARTYCD = json['PARTY_CD'];
//     pARTYNAME = json['PARTY_NAME'];
//     cHQNAME = json['CHQ_NAME'];
//     cHQDETL = json['CHQ_DETL'];
//     oTHPARTY = json['OTH_PARTY'];
//     aMOUNT = json['AMOUNT'];
//     iSVALID = json['IS_VALID'];
//     rPTPAYDTL = json['RPTPAY_DTL'];
//     nARRATION = json['NARRATION'];
//     nARRATION1 = json['NARRATION1'];
//     nARRATION2 = json['NARRATION2'];
//     cHQDT = json['CHQ_DT'];
//     cHQNO = json['CHQ_NO'];
//     rEALNARR = json['REAL_NARR'];
//     cHQCLGDT = json['CHQ_CLG_DT'];
//     kASARCD = json['KASAR_CD'];
//     tOTKASAR = json['TOT_KASAR'];
//     dNCNCD = json['DNCN_CD'];
//     tOTDNCN = json['TOT_DNCN'];
//     sMANCD = json['SMAN_CD'];
//     pAIDTBP = json['PAID_TBP'];
//     nONTAXABLE = json['NONTAXABLE'];
//     nETAMT = json['NET_AMT'];
//     uSERCD = json['USER_CD'];
//     sYNCID = json['SYNC_ID'];
//     lASTEDIT = json['LAST_EDIT'];
//     eNTRYCOMP = json['ENTRY_COMP'];
//     aDDDT = json['ADD_DT'];
//     aDDTM = json['ADD_TM'];
//     mODIFYDT = json['MODIFY_DT'];
//     mODIFYTM = json['MODIFY_TM'];
//     dELETEDT = json['DELETE_DT'];
//     dELETETM = json['DELETE_TM'];
//     dATAUPDTD = json['DATA_UPDTD'];
//     uPDATEDAT = json['UPDATED_AT'];
//     cREATEDAT = json['CREATED_AT'];
//     if (json['billwise_settlements'] != null) {
//       billwiseSettlements = <BillwiseSettlements>[];
//       json['billwise_settlements'].forEach((v) {
//         billwiseSettlements!.add(new BillwiseSettlements.fromJson(v));
//       });
//     }
//     party = json['party'] != null ? new Party.fromJson(json['party']) : null;
//     cshbnkParty = json['cshbnk_party'] != null
//         ? new Party.fromJson(json['cshbnk_party'])
//         : null;
//   }
//
//   Map<String, dynamic> toJson() {
//     final Map<String, dynamic> data = new Map<String, dynamic>();
//     data['VOUCH_DT'] = this.vOUCHDT;
//     data['VOUCH_NO'] = this.vOUCHNO;
//     data['AUTO_VNO'] = this.aUTOVNO;
//     data['TERMINAL'] = this.tERMINAL;
//     data['REF_NO'] = this.rEFNO;
//     data['VOUCH_TIME'] = this.vOUCHTIME;
//     data['BOOK_CD'] = this.bOOKCD;
//     data['GST_FORM'] = this.gSTFORM;
//     data['CSHBNK_CD'] = this.cSHBNKCD;
//     data['CB_NAME'] = this.cBNAME;
//     data['PARTY_CD'] = this.pARTYCD;
//     data['PARTY_NAME'] = this.pARTYNAME;
//     data['CHQ_NAME'] = this.cHQNAME;
//     data['CHQ_DETL'] = this.cHQDETL;
//     data['OTH_PARTY'] = this.oTHPARTY;
//     data['AMOUNT'] = this.aMOUNT;
//     data['IS_VALID'] = this.iSVALID;
//     data['RPTPAY_DTL'] = this.rPTPAYDTL;
//     data['NARRATION'] = this.nARRATION;
//     data['NARRATION1'] = this.nARRATION1;
//     data['NARRATION2'] = this.nARRATION2;
//     data['CHQ_DT'] = this.cHQDT;
//     data['CHQ_NO'] = this.cHQNO;
//     data['REAL_NARR'] = this.rEALNARR;
//     data['CHQ_CLG_DT'] = this.cHQCLGDT;
//     data['KASAR_CD'] = this.kASARCD;
//     data['TOT_KASAR'] = this.tOTKASAR;
//     data['DNCN_CD'] = this.dNCNCD;
//     data['TOT_DNCN'] = this.tOTDNCN;
//     data['SMAN_CD'] = this.sMANCD;
//     data['PAID_TBP'] = this.pAIDTBP;
//     data['NONTAXABLE'] = this.nONTAXABLE;
//     data['NET_AMT'] = this.nETAMT;
//     data['USER_CD'] = this.uSERCD;
//     data['SYNC_ID'] = this.sYNCID;
//     data['LAST_EDIT'] = this.lASTEDIT;
//     data['ENTRY_COMP'] = this.eNTRYCOMP;
//     data['ADD_DT'] = this.aDDDT;
//     data['ADD_TM'] = this.aDDTM;
//     data['MODIFY_DT'] = this.mODIFYDT;
//     data['MODIFY_TM'] = this.mODIFYTM;
//     data['DELETE_DT'] = this.dELETEDT;
//     data['DELETE_TM'] = this.dELETETM;
//     data['DATA_UPDTD'] = this.dATAUPDTD;
//     data['UPDATED_AT'] = this.uPDATEDAT;
//     data['CREATED_AT'] = this.cREATEDAT;
//     if (this.billwiseSettlements != null) {
//       data['billwise_settlements'] =
//           this.billwiseSettlements!.map((v) => v.toJson()).toList();
//     }
//     if (this.party != null) {
//       data['party'] = this.party!.toJson();
//     }
//     if (this.cshbnkParty != null) {
//       data['cshbnk_party'] = this.cshbnkParty!.toJson();
//     }
//     return data;
//   }
// }
//
// class BillwiseSettlements {
//   String? vOUCHDT;
//   num? vOUCHNO;
//   num? iTEMSR;
//   String? bWADV;
//   String? bOOKVNO;
//   String? bOOKCD;
//   String? vOUCHTYPE;
//   String? rEFNO;
//   String? cSHBNKCD;
//   String? pARTYCD;
//   String? dNCNCD;
//   String? kASARCD;
//   num? aMOUNT;
//   String? bLBOOKCD;
//   num? bLVNO;
//   String? bLBILLNO;
//   num? bLAMOUNT;
//   String? bLDRCRNT;
//   String? bLKASAR;
//   num? bLPAID;
//   String? eNTRYCOMP;
//   num? sYNCID;
//   String? lASTEDIT;
//   String? cONFIRMYN;
//   String? uPDATEDAT;
//   String? cREATEDAT;
//   String? bLVDT;
//
//   BillwiseSettlements(
//       {this.vOUCHDT,
//       this.vOUCHNO,
//       this.iTEMSR,
//       this.bWADV,
//       this.bOOKVNO,
//       this.bOOKCD,
//       this.vOUCHTYPE,
//       this.rEFNO,
//       this.cSHBNKCD,
//       this.pARTYCD,
//       this.dNCNCD,
//       this.kASARCD,
//       this.aMOUNT,
//       this.bLBOOKCD,
//       this.bLVNO,
//       this.bLBILLNO,
//       this.bLAMOUNT,
//       this.bLDRCRNT,
//       this.bLKASAR,
//       this.bLPAID,
//       this.eNTRYCOMP,
//       this.sYNCID,
//       this.lASTEDIT,
//       this.cONFIRMYN,
//       this.uPDATEDAT,
//       this.cREATEDAT,
//       this.bLVDT});
//
//   BillwiseSettlements.fromJson(Map<String, dynamic> json) {
//     vOUCHDT = json['VOUCH_DT'];
//     vOUCHNO = json['VOUCH_NO'];
//     iTEMSR = json['ITEM_SR'];
//     bWADV = json['BW_ADV'];
//     bOOKVNO = json['BOOK_VNO'];
//     bOOKCD = json['BOOK_CD'];
//     vOUCHTYPE = json['VOUCH_TYPE'];
//     rEFNO = json['REF_NO'];
//     cSHBNKCD = json['CSHBNK_CD'];
//     pARTYCD = json['PARTY_CD'];
//     dNCNCD = json['DNCN_CD'];
//     kASARCD = json['KASAR_CD'];
//     aMOUNT = json['AMOUNT'];
//     bLBOOKCD = json['BL_BOOK_CD'];
//     bLVNO = json['BL_V_NO'];
//     bLBILLNO = json['BL_BILL_NO'];
//     bLAMOUNT = json['BL_AMOUNT'];
//     bLDRCRNT = json['BL_DRCR_NT'];
//     bLKASAR = json['BL_KASAR'];
//     bLPAID = json['BL_PAID'];
//     eNTRYCOMP = json['ENTRY_COMP'];
//     sYNCID = json['SYNC_ID'];
//     lASTEDIT = json['LAST_EDIT'];
//     cONFIRMYN = json['CONFIRM_YN'];
//     uPDATEDAT = json['UPDATED_AT'];
//     cREATEDAT = json['CREATED_AT'];
//     bLVDT = json['BL_V_DT'];
//   }
//
//   Map<String, dynamic> toJson() {
//     final Map<String, dynamic> data = new Map<String, dynamic>();
//     data['VOUCH_DT'] = this.vOUCHDT;
//     data['VOUCH_NO'] = this.vOUCHNO;
//     data['ITEM_SR'] = this.iTEMSR;
//     data['BW_ADV'] = this.bWADV;
//     data['BOOK_VNO'] = this.bOOKVNO;
//     data['BOOK_CD'] = this.bOOKCD;
//     data['VOUCH_TYPE'] = this.vOUCHTYPE;
//     data['REF_NO'] = this.rEFNO;
//     data['CSHBNK_CD'] = this.cSHBNKCD;
//     data['PARTY_CD'] = this.pARTYCD;
//     data['DNCN_CD'] = this.dNCNCD;
//     data['KASAR_CD'] = this.kASARCD;
//     data['AMOUNT'] = this.aMOUNT;
//     data['BL_BOOK_CD'] = this.bLBOOKCD;
//     data['BL_V_NO'] = this.bLVNO;
//     data['BL_BILL_NO'] = this.bLBILLNO;
//     data['BL_AMOUNT'] = this.bLAMOUNT;
//     data['BL_DRCR_NT'] = this.bLDRCRNT;
//     data['BL_KASAR'] = this.bLKASAR;
//     data['BL_PAID'] = this.bLPAID;
//     data['ENTRY_COMP'] = this.eNTRYCOMP;
//     data['SYNC_ID'] = this.sYNCID;
//     data['LAST_EDIT'] = this.lASTEDIT;
//     data['CONFIRM_YN'] = this.cONFIRMYN;
//     data['UPDATED_AT'] = this.uPDATEDAT;
//     data['CREATED_AT'] = this.cREATEDAT;
//     data['BL_V_DT'] = this.bLVDT;
//     return data;
//   }
// }
//
// class Party {
//   String? aCCCD;
//   String? aCCNAME;
//
//   Party({this.aCCCD, this.aCCNAME});
//
//   Party.fromJson(Map<String, dynamic> json) {
//     aCCCD = json['ACC_CD'];
//     aCCNAME = json['ACC_NAME'];
//   }
//
//   Map<String, dynamic> toJson() {
//     final Map<String, dynamic> data = new Map<String, dynamic>();
//     data['ACC_CD'] = this.aCCCD;
//     data['ACC_NAME'] = this.aCCNAME;
//     return data;
//   }
// }

class Data {
  dynamic vOUCHNO;
  dynamic rEFNO;
  dynamic vOUCHDT;
  dynamic vOUCHTIME;
  dynamic bOOKCD;
  dynamic gSTFORM;
  dynamic cSHBNKCD;
  dynamic pARTYCD;
  dynamic cHQNAME;
  dynamic cHQDETL;
  dynamic oTHPARTY;
  dynamic aMOUNT;
  dynamic iSVALID;
  dynamic rPTPAYDTL;
  dynamic nARRATION;
  dynamic nARRATION1;
  dynamic nARRATION2;
  dynamic tRUCKID;
  dynamic cHQDT;
  dynamic cHQNO;
  dynamic rEALNARR;
  dynamic cHQCLGDT;
  dynamic kASARCD;
  dynamic tOTKASAR;
  dynamic dNCNCD;
  dynamic tOTDNCN;
  dynamic sMANCD;
  dynamic pAIDTBP;
  dynamic nONTAXABLE;
  dynamic nETAMT;
  dynamic uSERCD;
  dynamic sYNCID;
  dynamic cREATEDBY;
  dynamic cREATEDAPPTYPE;
  dynamic mODULENO;
  dynamic uPDATEDBY;
  dynamic uPDATEDAT;
  dynamic cREATEDAT;
  List<BillwiseSettlements>? billwiseSettlements;
  Party? party;
  Party? cshbnkParty;

  Data({
    this.vOUCHNO,
    this.rEFNO,
    this.vOUCHDT,
    this.vOUCHTIME,
    this.bOOKCD,
    this.gSTFORM,
    this.cSHBNKCD,
    this.pARTYCD,
    this.cHQNAME,
    this.cHQDETL,
    this.oTHPARTY,
    this.aMOUNT,
    this.iSVALID,
    this.rPTPAYDTL,
    this.nARRATION,
    this.nARRATION1,
    this.nARRATION2,
    this.tRUCKID,
    this.cHQDT,
    this.cHQNO,
    this.rEALNARR,
    this.cHQCLGDT,
    this.kASARCD,
    this.tOTKASAR,
    this.dNCNCD,
    this.tOTDNCN,
    this.sMANCD,
    this.pAIDTBP,
    this.nONTAXABLE,
    this.nETAMT,
    this.uSERCD,
    this.sYNCID,
    this.cREATEDBY,
    this.cREATEDAPPTYPE,
    this.mODULENO,
    this.uPDATEDBY,
    this.uPDATEDAT,
    this.cREATEDAT,
    this.billwiseSettlements,
    this.party,
    this.cshbnkParty,
  });

  Data.fromJson(Map<String, dynamic> json) {
    vOUCHNO = json['VOUCH_NO'];
    rEFNO = json['REF_NO'];
    vOUCHDT = json['VOUCH_DT'];
    vOUCHTIME = json['VOUCH_TIME'];
    bOOKCD = json['BOOK_CD'];
    gSTFORM = json['GST_FORM'];
    cSHBNKCD = json['CSHBNK_CD'];
    pARTYCD = json['PARTY_CD'];
    cHQNAME = json['CHQ_NAME'];
    cHQDETL = json['CHQ_DETL'];
    oTHPARTY = json['OTH_PARTY'];
    aMOUNT = json['AMOUNT'];
    iSVALID = json['IS_VALID'];
    rPTPAYDTL = json['RPTPAY_DTL'];
    nARRATION = json['NARRATION'];
    nARRATION1 = json['NARRATION1'];
    nARRATION2 = json['NARRATION2'];
    tRUCKID = json['TRUCK_ID'];
    cHQDT = json['CHQ_DT'];
    cHQNO = json['CHQ_NO'];
    rEALNARR = json['REAL_NARR'];
    cHQCLGDT = json['CHQ_CLG_DT'];
    kASARCD = json['KASAR_CD'];
    tOTKASAR = json['TOT_KASAR'];
    dNCNCD = json['DNCN_CD'];
    tOTDNCN = json['TOT_DNCN'];
    sMANCD = json['SMAN_CD'];
    pAIDTBP = json['PAID_TBP'];
    nONTAXABLE = json['NONTAXABLE'];
    nETAMT = json['NET_AMT'];
    uSERCD = json['USER_CD'];
    sYNCID = json['SYNC_ID'];
    cREATEDBY = json['CREATED_BY'];
    cREATEDAPPTYPE = json['CREATED_APP_TYPE'];
    mODULENO = json['MODULE_NO'];
    uPDATEDBY = json['UPDATED_BY'];
    uPDATEDAT = json['UPDATED_AT'];
    cREATEDAT = json['CREATED_AT'];
    if (json['billwise_settlements'] != null) {
      billwiseSettlements = <BillwiseSettlements>[];
      json['billwise_settlements'].forEach((v) {
        billwiseSettlements!.add(BillwiseSettlements.fromJson(v));
      });
    }
    party = json['party'] != null ? Party.fromJson(json['party']) : null;
    cshbnkParty = json['cshbnk_party'] != null
        ? Party.fromJson(json['cshbnk_party'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['VOUCH_NO'] = vOUCHNO;
    data['REF_NO'] = rEFNO;
    data['VOUCH_DT'] = vOUCHDT;
    data['VOUCH_TIME'] = vOUCHTIME;
    data['BOOK_CD'] = bOOKCD;
    data['GST_FORM'] = gSTFORM;
    data['CSHBNK_CD'] = cSHBNKCD;
    data['PARTY_CD'] = pARTYCD;
    data['CHQ_NAME'] = cHQNAME;
    data['CHQ_DETL'] = cHQDETL;
    data['OTH_PARTY'] = oTHPARTY;
    data['AMOUNT'] = aMOUNT;
    data['IS_VALID'] = iSVALID;
    data['RPTPAY_DTL'] = rPTPAYDTL;
    data['NARRATION'] = nARRATION;
    data['NARRATION1'] = nARRATION1;
    data['NARRATION2'] = nARRATION2;
    data['TRUCK_ID'] = tRUCKID;
    data['CHQ_DT'] = cHQDT;
    data['CHQ_NO'] = cHQNO;
    data['REAL_NARR'] = rEALNARR;
    data['CHQ_CLG_DT'] = cHQCLGDT;
    data['KASAR_CD'] = kASARCD;
    data['TOT_KASAR'] = tOTKASAR;
    data['DNCN_CD'] = dNCNCD;
    data['TOT_DNCN'] = tOTDNCN;
    data['SMAN_CD'] = sMANCD;
    data['PAID_TBP'] = pAIDTBP;
    data['NONTAXABLE'] = nONTAXABLE;
    data['NET_AMT'] = nETAMT;
    data['USER_CD'] = uSERCD;
    data['SYNC_ID'] = sYNCID;
    data['CREATED_BY'] = cREATEDBY;
    data['CREATED_APP_TYPE'] = cREATEDAPPTYPE;
    data['MODULE_NO'] = mODULENO;
    data['UPDATED_BY'] = uPDATEDBY;
    data['UPDATED_AT'] = uPDATEDAT;
    data['CREATED_AT'] = cREATEDAT;
    if (billwiseSettlements != null) {
      data['billwise_settlements'] =
          billwiseSettlements!.map((v) => v.toJson()).toList();
    }
    if (party != null) {
      data['party'] = party!.toJson();
    }
    if (cshbnkParty != null) {
      data['cshbnk_party'] = cshbnkParty!.toJson();
    }
    return data;
  }
}

class BillwiseSettlements {
  dynamic vOUCHDT;
  dynamic bLVDT;
  dynamic vOUCHNO;
  dynamic iTEMSR;
  dynamic bWADV;
  dynamic bOOKVNO;
  dynamic bOOKCD;
  dynamic vOUCHTYPE;
  dynamic rEFNO;
  dynamic vOUCHTIME;
  dynamic cSHBNKCD;
  dynamic pARTYCD;
  dynamic dNCNCD;
  dynamic kASARCD;
  dynamic aMOUNT;
  dynamic bLBOOKCD;
  dynamic bLVNO;
  dynamic bLBILLNO;
  dynamic bLAMOUNT;
  dynamic bLDRCRNT;
  dynamic bLKASAR;
  dynamic bLPAID;
  dynamic sYNCID;
  dynamic cONFIRMYN;
  dynamic cREATEDBY;
  dynamic cREATEDAPPTYPE;
  dynamic mODULENO;
  dynamic uPDATEDAT;
  dynamic uPDATEDBY;
  dynamic cREATEDAT;

  BillwiseSettlements(
      {this.vOUCHDT,
      this.bLVDT,
      this.vOUCHNO,
      this.iTEMSR,
      this.bWADV,
      this.bOOKVNO,
      this.bOOKCD,
      this.vOUCHTYPE,
      this.rEFNO,
      this.vOUCHTIME,
      this.cSHBNKCD,
      this.pARTYCD,
      this.dNCNCD,
      this.kASARCD,
      this.aMOUNT,
      this.bLBOOKCD,
      this.bLVNO,
      this.bLBILLNO,
      this.bLAMOUNT,
      this.bLDRCRNT,
      this.bLKASAR,
      this.bLPAID,
      this.sYNCID,
      this.cONFIRMYN,
      this.cREATEDBY,
      this.cREATEDAPPTYPE,
      this.mODULENO,
      this.uPDATEDAT,
      this.uPDATEDBY,
      this.cREATEDAT});

  BillwiseSettlements.fromJson(Map<String, dynamic> json) {
    vOUCHDT = json['VOUCH_DT'];
    bLVDT = json['BL_V_DT'];
    vOUCHNO = json['VOUCH_NO'];
    iTEMSR = json['ITEM_SR'];
    bWADV = json['BW_ADV'];
    bOOKVNO = json['BOOK_VNO'];
    bOOKCD = json['BOOK_CD'];
    vOUCHTYPE = json['VOUCH_TYPE'];
    rEFNO = json['REF_NO'];
    vOUCHTIME = json['VOUCH_TIME'];
    cSHBNKCD = json['CSHBNK_CD'];
    pARTYCD = json['PARTY_CD'];
    dNCNCD = json['DNCN_CD'];
    kASARCD = json['KASAR_CD'];
    aMOUNT = json['AMOUNT'];
    bLBOOKCD = json['BL_BOOK_CD'];
    bLVNO = json['BL_V_NO'];
    bLBILLNO = json['BL_BILL_NO'];
    bLAMOUNT = json['BL_AMOUNT'];
    bLDRCRNT = json['BL_DRCR_NT'];
    bLKASAR = json['BL_KASAR'];
    bLPAID = json['BL_PAID'];
    sYNCID = json['SYNC_ID'];
    cONFIRMYN = json['CONFIRM_YN'];
    cREATEDBY = json['CREATED_BY'];
    cREATEDAPPTYPE = json['CREATED_APP_TYPE'];
    mODULENO = json['MODULE_NO'];
    uPDATEDAT = json['UPDATED_AT'];
    uPDATEDBY = json['UPDATED_BY'];
    cREATEDAT = json['CREATED_AT'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['VOUCH_DT'] = vOUCHDT;
    data['BL_V_DT'] = bLVDT;
    data['VOUCH_NO'] = vOUCHNO;
    data['ITEM_SR'] = iTEMSR;
    data['BW_ADV'] = bWADV;
    data['BOOK_VNO'] = bOOKVNO;
    data['BOOK_CD'] = bOOKCD;
    data['VOUCH_TYPE'] = vOUCHTYPE;
    data['REF_NO'] = rEFNO;
    data['VOUCH_TIME'] = vOUCHTIME;
    data['CSHBNK_CD'] = cSHBNKCD;
    data['PARTY_CD'] = pARTYCD;
    data['DNCN_CD'] = dNCNCD;
    data['KASAR_CD'] = kASARCD;
    data['AMOUNT'] = aMOUNT;
    data['BL_BOOK_CD'] = bLBOOKCD;
    data['BL_V_NO'] = bLVNO;
    data['BL_BILL_NO'] = bLBILLNO;
    data['BL_AMOUNT'] = bLAMOUNT;
    data['BL_DRCR_NT'] = bLDRCRNT;
    data['BL_KASAR'] = bLKASAR;
    data['BL_PAID'] = bLPAID;
    data['SYNC_ID'] = sYNCID;
    data['CONFIRM_YN'] = cONFIRMYN;
    data['CREATED_BY'] = cREATEDBY;
    data['CREATED_APP_TYPE'] = cREATEDAPPTYPE;
    data['MODULE_NO'] = mODULENO;
    data['UPDATED_AT'] = uPDATEDAT;
    data['UPDATED_BY'] = uPDATEDBY;
    data['CREATED_AT'] = cREATEDAT;
    return data;
  }
}

class Party {
  dynamic aCCCD;
  dynamic aCCNAME;

  Party({this.aCCCD, this.aCCNAME});

  Party.fromJson(Map<String, dynamic> json) {
    aCCCD = json['ACC_CD'];
    aCCNAME = json['ACC_NAME'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['ACC_CD'] = aCCCD;
    data['ACC_NAME'] = aCCNAME;
    return data;
  }
}
