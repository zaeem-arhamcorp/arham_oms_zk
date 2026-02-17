class ProductResponse {
  dynamic message;
  List<Data>? data;

  ProductResponse({this.message, this.data});

  ProductResponse.fromJson(Map<String, dynamic> json) {
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

class Data {
  dynamic iTEMCD2;
  dynamic nRATE;
  dynamic aVLSTK;
  dynamic eXDT;
  dynamic rACKNO;
  dynamic iTEMCAT;
  dynamic sUBCAT;
  dynamic iTEMBRAND;
  dynamic iTEMCD;
  dynamic iTEMNAME;
  dynamic iTEMSNAME;
  dynamic iTEMLNAME;
  dynamic dEPTCD;
  dynamic sRATE1;
  dynamic sRATE3;
  dynamic sYNCID;
  dynamic iTEMGRADE;
  dynamic iTEMDESC;
  dynamic pRATE;
  dynamic pDISC;
  dynamic gSTPERC;
  dynamic fRMLSRT1;
  dynamic sDISC;
  dynamic sDISC1;
  dynamic cSTK;
  dynamic oRSTK;
  Deptment? deptment;
  dynamic itemImage;

  Data(
      {this.iTEMCD2,
        this.nRATE,
        this.aVLSTK,
        this.eXDT,
        this.rACKNO,
        this.iTEMCAT,
        this.sUBCAT,
        this.iTEMBRAND,
        this.iTEMCD,
        this.iTEMNAME,
        this.iTEMSNAME,
        this.iTEMLNAME,
        this.dEPTCD,
        this.sRATE1,
        this.sRATE3,
        this.sYNCID,
        this.iTEMGRADE,
        this.iTEMDESC,
        this.pRATE,
        this.pDISC,
        this.gSTPERC,
        this.fRMLSRT1,
        this.sDISC,
        this.sDISC1,
        this.cSTK,
        this.oRSTK,
        this.deptment,
        this.itemImage});

  Data.fromJson(Map<String, dynamic> json) {
    iTEMCD2 = json['ITEM_CD2'];
    nRATE = json['NRATE'];
    aVLSTK = json['AVL_STK'];
    eXDT = json['EX_DT'];
    rACKNO = json['RACK_NO'];
    iTEMCAT = json['ITEM_CAT'];
    sUBCAT = json['SUBCAT'];
    iTEMBRAND = json['ITEM_BRAND'];
    iTEMCD = json['ITEM_CD'];
    iTEMNAME = json['ITEM_NAME'];
    iTEMSNAME = json['ITEM_SNAME'];
    iTEMLNAME = json['ITEM_LNAME'];
    dEPTCD = json['DEPT_CD'];
    sRATE1 = json['SRATE1'];
    sRATE3 = json['SRATE3'];
    sYNCID = json['SYNC_ID'];
    iTEMGRADE = json['ITEM_GRADE'];
    iTEMDESC = json['ITEM_DESC'];
    pRATE = json['PRATE'];
    pDISC = json['PDISC'];
    gSTPERC = json['GST_PERC'];
    fRMLSRT1 = json['FRML_SRT1'];
    sDISC = json['SDISC'];
    sDISC1 = json['SDISC1'];
    cSTK = json['C_STK'];
    oRSTK = json['OR_STK'];
    deptment = json['deptment'] != null
        ? Deptment.fromJson(json['deptment'])
        : null;
    itemImage = json['item_image'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['ITEM_CD2'] = iTEMCD2;
    data['NRATE'] = nRATE;
    data['AVL_STK'] = aVLSTK;
    data['EX_DT'] = eXDT;
    data['RACK_NO'] = rACKNO;
    data['ITEM_CAT'] = iTEMCAT;
    data['SUBCAT'] = sUBCAT;
    data['ITEM_BRAND'] = iTEMBRAND;
    data['ITEM_CD'] = iTEMCD;
    data['ITEM_NAME'] = iTEMNAME;
    data['ITEM_SNAME'] = iTEMSNAME;
    data['ITEM_LNAME'] = iTEMLNAME;
    data['DEPT_CD'] = dEPTCD;
    data['SRATE1'] = sRATE1;
    data['SRATE3'] = sRATE3;
    data['SYNC_ID'] = sYNCID;
    data['ITEM_GRADE'] = iTEMGRADE;
    data['ITEM_DESC'] = iTEMDESC;
    data['PRATE'] = pRATE;
    data['PDISC'] = pDISC;
    data['GST_PERC'] = gSTPERC;
    data['FRML_SRT1'] = fRMLSRT1;
    data['SDISC'] = sDISC;
    data['SDISC1'] = sDISC1;
    data['C_STK'] = cSTK;
    data['OR_STK'] = oRSTK;
    if (deptment != null) {
      data['deptment'] = deptment!.toJson();
    }
    data['item_image'] = itemImage;
    return data;
  }
}

class Deptment {
  dynamic dEPTCD;
  dynamic dEPTNAME;
  dynamic gROUPING;
  dynamic sYNCID;
  dynamic cREATEDBY;
  dynamic cREATEDAPPTYPE;
  dynamic uPDATEDAT;
  dynamic cREATEDAT;

  Deptment(
      {this.dEPTCD,
        this.dEPTNAME,
        this.gROUPING,
        this.sYNCID,
        this.cREATEDBY,
        this.cREATEDAPPTYPE,
        this.uPDATEDAT,
        this.cREATEDAT});

  Deptment.fromJson(Map<String, dynamic> json) {
    dEPTCD = json['DEPT_CD'];
    dEPTNAME = json['DEPT_NAME'];
    gROUPING = json['GROUPING'];
    sYNCID = json['SYNC_ID'];
    cREATEDBY = json['CREATED_BY'];
    cREATEDAPPTYPE = json['CREATED_APP_TYPE'];
    uPDATEDAT = json['UPDATED_AT'];
    cREATEDAT = json['CREATED_AT'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['DEPT_CD'] = dEPTCD;
    data['DEPT_NAME'] = dEPTNAME;
    data['GROUPING'] = gROUPING;
    data['SYNC_ID'] = sYNCID;
    data['CREATED_BY'] = cREATEDBY;
    data['CREATED_APP_TYPE'] = cREATEDAPPTYPE;
    data['UPDATED_AT'] = uPDATEDAT;
    data['CREATED_AT'] = cREATEDAT;
    return data;
  }
}
