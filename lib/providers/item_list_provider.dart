import 'package:arham_corporation/models/personModal.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:flutter/cupertino.dart';
//import 'package:fluttertoast/fluttertoast.dart';
import 'package:arham_corporation/models/cityListModal.dart';
import 'package:arham_corporation/providers/disposable_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import 'package:http/http.dart' as http;

import '../models/deptmentListModal.dart';
import '../models/itemListModal.dart';
import '../views/loginpage.dart';
import 'package:arham_corporation/services/crashlytics_service.dart';

class ItemListProvider extends DisposableProvider {
  List<DatumItemList> _data = [];

  List<DatumItemList> get data => _data;

  List<DatumDeptment> dataDeptmant = [];

  List<DatumCity> dataCity = [];

  List<DatumPerson> dataOpUsers = [];

  List<DatumItemList> itemListForSalesReport = [];
  List<DatumItemList> itemListForLeadgerReport = [];
  List<DatumItemList> itemListForpartyWiseSaleReport = [];

  bool noList = false;
  bool noListDeptment = false;
  bool noListCity = false;
  bool noOpUsers = false;

  Future getItems(BuildContext context) async {
    _data.clear();
    itemListForSalesReport.clear();
    itemListForLeadgerReport.clear();
    itemListForpartyWiseSaleReport.clear();
    noList = false;
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    try {
      final http.Response response = await http.get(
        Uri.parse(AppConfig.baseURL + "items"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print(AppConfig.baseURL + "items");
      print(response.body);
      print(response.statusCode);
      if (response.statusCode == 200) {
        _data.clear();
        _data.addAll(itemListModalFromJson(response.body).data);
        itemListForSalesReport
            .addAll(itemListModalFromJson(response.body).data);
        itemListForLeadgerReport
            .addAll(itemListModalFromJson(response.body).data);
        itemListForpartyWiseSaleReport
            .addAll(itemListModalFromJson(response.body).data);
        if (_data.isEmpty) {
          noList = true;
        }
      } else {
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: 'Something went wrong');
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in ItemListProvider getItems  ${e.toString()}");
    }
    notifyListeners();
  }

  Future getDeptment(BuildContext context) async {
    dataDeptmant.clear();
    noListDeptment = false;
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    print(AppConfig.baseURL + "deptment");
    try {
      final http.Response response = await http.get(
        Uri.parse(AppConfig.baseURL + "deptment"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );

      if (response.statusCode == 200) {
        dataDeptmant.addAll(deptmentListModalFromJson(response.body).data);
        if (dataDeptmant.isEmpty) {
          noListDeptment = true;
        }
      } else {
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      //Fluttertoast.showToast(msg: "Something went wrong");
      AppSnackBar.showGetXCustomSnackBar(message: 'Something went wrong');
      print("Error in ItemListProvider getDeptment  ${e.toString()}");
    }
    notifyListeners();
  }

  Future getCity(BuildContext context) async {
    dataCity.clear();
    noListCity = false;
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    try {
      final http.Response response = await http.get(
        Uri.parse(AppConfig.baseURL + "city"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );

      if (response.statusCode == 200) {
        dataCity.addAll(cityListModalFromJson(response.body).data);
        if (dataCity.isEmpty) {
          noListCity = true;
        }
      } else {
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      //Fluttertoast.showToast(msg: "Something went wrong");
      AppSnackBar.showGetXCustomSnackBar(message: 'Something went wrong');
      print("Error in ItemListProvider getCity  ${e.toString()}");
    }
    notifyListeners();
  }

  Future getOpUsers(BuildContext context) async {
    dataOpUsers.clear();
    noOpUsers = false;
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    try {
      final http.Response response = await http.get(
        Uri.parse(AppConfig.baseURL + "filter-user"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print(response.body);
      if (response.statusCode == 200) {
        dataOpUsers.addAll(opPersonModalFromJson(response.body).data);
        if (dataOpUsers.isEmpty) {
          noOpUsers = true;
        }else{
          noOpUsers = false;
        }
      } else {
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      //Fluttertoast.showToast(msg: "Something went wrong");
      AppSnackBar.showGetXCustomSnackBar(message: 'Something went wrong');
      print("Error in ItemListProvider getOpUsers  ${e.toString()}");
    }
    notifyListeners();
  }

  fillterListForSaleReport(val) {
    print(val);
    itemListForSalesReport.clear();
    _data.forEach((element) {
      if (element.deptCd == val) {
        print("hhhhhhh");
        itemListForSalesReport.add(element);
      }
    });
    if (itemListForSalesReport.isEmpty) {
      noList = true;
    }
    notifyListeners();
  }

  clearDepetmantforSalceReport() {
    itemListForSalesReport.clear();
    noList = false;
    noListDeptment = false;
    itemListForSalesReport.addAll(_data);
    notifyListeners();
  }

  fillterListForLeadgerReport(val) {
    itemListForLeadgerReport.clear();
    _data.forEach((element) {
      if (element.deptCd == val) {
        print("hhhhhhh");
        itemListForLeadgerReport.add(element);
      }
    });

    if (itemListForLeadgerReport.isEmpty) {
      noList = true;
    } else {
      noList = false;
    }
    notifyListeners();
  }

  clearDepetmantforLeadgerReport() {
    itemListForLeadgerReport.clear();
    noList = false;
    noListDeptment = false;
    itemListForLeadgerReport.addAll(_data);
    notifyListeners();
  }

  fillterListForPartyWiseSaleReport(val) {
    itemListForpartyWiseSaleReport.clear();
    _data.forEach((element) {
      if (element.deptCd == val) {
        print("hhhhhhh");
        itemListForpartyWiseSaleReport.add(element);
      }
    });
    if (itemListForpartyWiseSaleReport.isEmpty) {
      noList = true;
    } else {
      noList = false;
    }
    notifyListeners();
  }

  clearDepetmantforPartyWiseSalesReport() {
    itemListForpartyWiseSaleReport.clear();
    noList = false;
    noListDeptment = false;
    itemListForpartyWiseSaleReport.addAll(_data);
    notifyListeners();
  }

  @override
  disposeValues() {
    print("oooooooooooooooooo");
    _data.clear();
    dataDeptmant.clear();
    dataCity.clear();
    dataOpUsers.clear();
    itemListForpartyWiseSaleReport.clear();
    itemListForLeadgerReport.clear();
    itemListForSalesReport.clear();
    notifyListeners();
  }
}

