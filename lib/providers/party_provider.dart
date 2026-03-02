import 'dart:convert';

import 'package:arham_corporation/product/widget/app_snack_bar.dart';

//import 'package:fluttertoast/fluttertoast.dart';
import 'package:arham_corporation/providers/disposable_provider.dart';
import 'package:arham_corporation/providers/cart_list_provider.dart';
import 'package:arham_corporation/providers/location_provider.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/services/apiServices.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/partynameModal.dart';
import '../views/loginpage.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class PartyProvider extends DisposableProvider {
  String _party = "";

  String get party => _party;
  String _partyId = "";

  String get partyid => _partyId;

  String _orderParty = "";

  String get orderParty => _orderParty;
  String _orderPartyId = "";

  String get orderPartyid => _orderPartyId;

  bool nolistParty = false;

  List<DatumPartyname> _data = [];

  List<DatumPartyname> get data => _data;

  String punchInOutParty = "";
  String punchInOutPartyId = "";

  changePunchInOutParty(partyname, partyID, context,
      {isProductPage, type, id}) {
    final ProfileProvider pp =
        Provider.of<ProfileProvider>(context, listen: false);
    punchInOutParty = partyname;
    punchInOutPartyId = partyID;
    if (isProductPage != null) {
      if (id == null) {
        if (pp.YN == "Y") {
          if (pp.ACC_NAME == "" && pp.ACC_CD == "") {
            startEndOrder(partyname, partyID, context, type).then((value) {});
          }
        }
      }
    }
    notifyListeners();
  }

  clearPunchInOutParty() {
    punchInOutParty = "";
    punchInOutPartyId = "";
    notifyListeners();
  }

  changeParty(partyname, partyID, context) {
    _party = partyname;
    _partyId = partyID;

    notifyListeners();
  }

  clearParty() {
    _party = "";
    _partyId = "";
    notifyListeners();
  }

  changeOrderParty(partyname, partyID, context) {
    _orderParty = partyname;
    _orderPartyId = partyID;
    final CartListProvider cart = Provider.of<CartListProvider>(context, listen: false);
    cart.getCartItem(context, partyID);
    notifyListeners();
  }

  Future<PartynameModal?> getPartyNameProductPage(context) async {
    _data.clear();
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    print(ub.token);
    try {
      final http.Response response = await http.get(
        Uri.parse(AppConfig.baseURL + "products/party"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print("Here the product page is calling :-  " +
          AppConfig.baseURL +
          "products/party");
      print("Bearer ${ub.token}");
      print(response.body);
      if (response.statusCode == 200) {
        data.addAll(partynameModalFromJson(response.body).data);
        if (data.isEmpty) {
          nolistParty = true;
        } else {
          nolistParty = false;
        }
      } else {
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack);
      //Fluttertoast.showToast(msg: "Something went wrong");
      AppSnackBar.showGetXCustomSnackBar(message: 'Something went wrong');
      print("Error in PartyProvider getpartyname data ${e.toString()}");
    }
    notifyListeners();
    return null;
  }

  Future<PartynameModal?> getpartyname1(context) async {
    _data.clear();
    nolistParty = false; // Reset before fetching
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    print(ub.token);
    try {
      final http.Response response = await http.get(
        Uri.parse(AppConfig.baseURL + "report/party"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );

      print(AppConfig.baseURL + "report/party");
      print("Bearer ${ub.token}");
      print(response.body);
      if (response.statusCode == 200) {
        data.addAll(partynameModalFromJson(response.body).data);
        if (_data.isEmpty) {
          nolistParty = true;
        }
      } else {
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack);
      //Fluttertoast.showToast(msg: "Something went wrong");
      AppSnackBar.showGetXCustomSnackBar(message: 'Something went wrong');
      print("Error in PartyProvider getpartyname data ${e.toString()}");
    }
    notifyListeners();
    return null;
  }

  Future<PartynameModal?> getpartyname(context) async {
    _data.clear();
    nolistParty = false; // Reset before fetching
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    print(ub.token);
    try {
      final http.Response response = await http.get(
        Uri.parse("${AppConfig.baseURL}report/party"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );

      print(AppConfig.baseURL + "report/party");
      print("Bearer ${ub.token}");
      print(response.body);
      if (response.statusCode == 200) {
        data.addAll(partynameModalFromJson(response.body).data);
        if (data.isEmpty) {
          nolistParty = true;
          print('call 1 1');
        } else {
          nolistParty = false;
          print('call 2 2');
        }
      } else {
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack);
      //Fluttertoast.showToast(msg: "Something went wrong");
      AppSnackBar.showGetXCustomSnackBar(message: 'Something went wrong');
      print("Error in PartyProvider getpartyname data ${e.toString()}");
    }
    notifyListeners();
    return null;
  }

  Future<PartynameModal?> getpartynameForReceivable(context) async {
    _data.clear();
    nolistParty = false; // Reset before fetching
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    print(ub.token);
    try {
      final http.Response response = await http.get(
        Uri.parse(AppConfig.baseURL + "report/party"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );

      print(AppConfig.baseURL + "report/party");
      print("Bearer ${ub.token}");
      print(response.body);

      if (response.statusCode == 200) {
        // Parse response and filter records based on GROUP_CD == 135
        var partynameModal = partynameModalFromJson(response.body);
        //var filteredData = partynameModal.data.where((party) => party.groupCD == 135).toList();

        var filteredData = partynameModal.data.where((party) {
          return (party.clBAL != null && party.clBAL! > 0) &&
              (party.groupCD == 135 || party.groupCD == 85);
        }).toList();

        if (filteredData.isEmpty) {
          nolistParty = true;
          print('call 1');
        } else {
          nolistParty = false;
          print('call 2');
        }

        // Clear current data and add filtered records
        _data.clear();
        _data.addAll(filteredData);
      } else {
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack);
      //Fluttertoast.showToast(msg: "Something went wrong");
      AppSnackBar.showGetXCustomSnackBar(message: 'Something went wrong');
      print("Error in PartyProvider getpartyname data ${e.toString()}");
    }
    notifyListeners();
    return null;
  }

  Future<PartynameModal?> getpartynameForReceivableWithoutFilter(context) async {
    _data.clear();
    nolistParty = false; // Reset before fetching
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    print(ub.token);
    try {
      final http.Response response = await http.get(
        Uri.parse(AppConfig.baseURL + "report/party"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );

      print(AppConfig.baseURL + "report/party");
      print("Bearer ${ub.token}");
      print(response.body);

      if (response.statusCode == 200) {
        // Parse response and filter records based on GROUP_CD == 135
        var partynameModal = partynameModalFromJson(response.body);
        //var filteredData = partynameModal.data.where((party) => party.groupCD == 135).toList();

        var filteredData = partynameModal.data.toList();

        if (filteredData.isEmpty) {
          nolistParty = true;
          print('call 1');
        } else {
          nolistParty = false;
          print('call 2');
        }

        // Clear current data and add filtered records
        _data.clear();
        _data.addAll(filteredData);
      } else {
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack);
      //Fluttertoast.showToast(msg: "Something went wrong");
      AppSnackBar.showGetXCustomSnackBar(message: 'Something went wrong');
      print("Error in PartyProvider getpartyname data ${e.toString()}");
    }
    notifyListeners();
    return null;
  }

  Future<PartynameModal?> getpartynameForPayment(context) async {
    _data.clear();
    nolistParty = false; // Reset before fetching
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    print(ub.token);
    try {
      final http.Response response = await http.get(
        Uri.parse(AppConfig.baseURL + "report/party"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );

      print(AppConfig.baseURL + "report/party");
      print("Bearer ${ub.token}");
      print(response.body);

      if (response.statusCode == 200) {
        // Parse response and filter records based on GROUP_CD == 135
        var partynameModal = partynameModalFromJson(response.body);
        //var filteredData = partynameModal.data.where((party) => party.groupCD == 135).toList();

        var filteredData = partynameModal.data.where((party) {
          return (party.groupCD == 135 || party.groupCD == 85) &&
              (party.clBAL != null && party.clBAL! < 0);
        }).toList();

        if (filteredData.isEmpty) {
          nolistParty = true;
        } else {
          nolistParty = false;
        }

        // Clear current data and add filtered records
        _data.clear();
        _data.addAll(filteredData);

        print(filteredData.length);
      } else {
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack);
      //Fluttertoast.showToast(msg: "Something went wrong");
      AppSnackBar.showGetXCustomSnackBar(message: 'Something went wrong');
      print("Error in PartyProvider getpartyname data ${e.toString()}");
    }
    notifyListeners();
    return null;
  }

  Future<PartynameModal?> getpartynameForPaymentWithoutFilter(context) async {
    _data.clear();
    nolistParty = false; // Reset before fetching
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    print(ub.token);
    try {
      final http.Response response = await http.get(
        Uri.parse(AppConfig.baseURL + "report/party"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );

      print(AppConfig.baseURL + "report/party");
      print("Bearer ${ub.token}");
      print(response.body);

      if (response.statusCode == 200) {
        // Parse response and filter records based on GROUP_CD == 135
        var partynameModal = partynameModalFromJson(response.body);
        //var filteredData = partynameModal.data.where((party) => party.groupCD == 135).toList();

        var filteredData = partynameModal.data.toList();

        if (filteredData.isEmpty) {
          nolistParty = true;
        } else {
          nolistParty = false;
        }

        // Clear current data and add filtered records
        _data.clear();
        _data.addAll(filteredData);

        print(filteredData.length);
      } else {
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack);
      //Fluttertoast.showToast(msg: "Something went wrong");
      AppSnackBar.showGetXCustomSnackBar(message: 'Something went wrong');
      print("Error in PartyProvider getpartyname data ${e.toString()}");
    }
    notifyListeners();
    return null;
  }

  clearOrderParty() {
    _orderParty = "";
    _orderPartyId = "";
    notifyListeners();
  }

  bool loading = false;

  Future startEndOrder(accName, acc_cd, BuildContext context, type,
      {oID, id}) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    final LocationProvider lp =
        Provider.of<LocationProvider>(context, listen: false);
    final ProfileProvider pp =
        Provider.of<ProfileProvider>(context, listen: false);
    loading = true;
    notifyListeners();
    try {
      await lp.determinePosition().then((location) async {
        ApiServices()
            .postData(
                "orders-tracking",
                {
                  "accCd": acc_cd,

                  // "lat": location.latitude.toString(),
                  // "longi": location.longitude.toString(),
                  "lat": ub.role == AppConfig.masteruser
                      ? location.latitude.toString().isNotEmpty
                          ? location.latitude.toString()
                          : '0'
                      : location.latitude.toString().isNotEmpty
                      ? location.latitude.toString()
                      : '0',
                  "longi": ub.role == AppConfig.masteruser
                      ? location.longitude.toString().isNotEmpty
                          ? location.longitude.toString()
                          : '0'
                      : location.longitude.toString().isNotEmpty
                      ? location.longitude.toString()
                      : '0',
                  "oId": oID ?? "",
                  "type": type,
                  "moduleNo": "205"
                },
                context: context,
                header: true,
                he: ub.token.toString())
            .then((value) {
          if (value != null) {
            print(
                "...........////////////...............////////////......./////");
            //Fluttertoast.showToast(msg: json.decode(value.body)["message"]);
            AppSnackBar.showGetXCustomSnackBar(
                message: json.decode(value.body)["message"],
                backgroundColor: Colors.green);
            if (id != null) {
              pp.change("", "");
              punchInOutParty = "";
              punchInOutPartyId = "";
              notifyListeners();
            } else {
              pp.change(accName, acc_cd);
            }
            loading = false;
            notifyListeners();
          } else {
            loading = false;
            notifyListeners();
          }
        });
      });
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack);
      // Fluttertoast.showToast(
      //     msg: "Please Enable Location Permission",
      //     toastLength: Toast.LENGTH_LONG);
      AppSnackBar.showGetXCustomSnackBar(
          message: 'Please Enable Location Permission');

      loading = false;
      notifyListeners();
    }
  }

  @override
  disposeValues() {
    _data.clear();
    _party = "";
    _partyId = "";
    _orderParty = "";
    _orderPartyId = "";
    notifyListeners();
  }
}
