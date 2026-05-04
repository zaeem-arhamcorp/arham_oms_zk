import 'dart:async';

import 'package:arham_corporation/helper/network_helper.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/cart_list_provider.dart';
//import 'package:fluttertoast/fluttertoast.dart';
import 'package:arham_corporation/providers/disposable_provider.dart';
import 'package:arham_corporation/providers/location_provider.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/services/crashlytics_service.dart';
import 'package:arham_corporation/services/database_helper.dart';
import 'package:arham_corporation/services/order_tracking_service.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/partynameModal.dart';
import '../views/loginpage.dart';

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

  Future<void> changePunchInOutParty(partyname, partyID, context,
      {isProductPage, type, id}) async {
    final ProfileProvider pp =
        Provider.of<ProfileProvider>(context, listen: false);
    punchInOutParty = partyname;
    punchInOutPartyId = partyID;
    if (isProductPage != null) {
      if (id == null) {
        if (pp.YN == "Y") {
          if (pp.ACC_NAME == "" && pp.ACC_CD == "") {
            await startEndOrder(partyname, partyID, context, type);
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
    final CartListProvider cart =
        Provider.of<CartListProvider>(context, listen: false);
    cart.getCartItem(context, partyID);
    notifyListeners();
  }

  /// 📝 UPDATE A SINGLE PARTY IN THE CACHED LIST AFTER EDIT
  /// Called after successful account update to ensure next edit has fresh data
  void updatePartyData(String accCd, Map<String, dynamic> updatedData) {
    try {
      final index = _data.indexWhere((party) => party.accCd == accCd);
      if (index != -1) {
        final party = _data[index];
        // Update the party object with new data from API response
        party.accName = updatedData['ACC_NAME'] ?? party.accName;
        party.accAddress = updatedData['ADD1'] ?? party.accAddress;
        party.mobile = updatedData['MOBILE1'] ?? party.mobile;
        party.add1 = updatedData['ADD1'] ?? party.add1;
        party.add2 = updatedData['ADD2'] ?? party.add2;
        party.add3 = updatedData['ADD3'] ?? party.add3;
        party.city = updatedData['CITY'] ?? party.city;
        party.zone = updatedData['ZONE'] ?? party.zone;
        party.state = updatedData['STATE'] ?? party.state;
        party.pincode = updatedData['PINCODE'] ?? party.pincode;
        party.person_nm = updatedData['PERSON_NM'] ?? party.person_nm;
        party.email = updatedData['EMAIL'] ?? party.email;
        party.panNo = updatedData['PAN_NO'] ?? party.panNo;
        party.gstNo = updatedData['GST_NO'] ?? party.gstNo;
        party.gstType = updatedData['GST_TYPE'] ?? party.gstType;
        party.drugLic1 = updatedData['DRUG_LIC1'] ?? party.drugLic1;
        party.drugLic2 = updatedData['DRUG_LIC2'] ?? party.drugLic2;
        party.fssaiNo = updatedData['FSSAI_NO'] ?? party.fssaiNo;
        party.lat = (updatedData['LATITUDE'] as num?)?.toDouble() ?? party.lat;
        party.long =
            (updatedData['LONGITUDE'] as num?)?.toDouble() ?? party.long;
        party.clBAL = (updatedData['CL_BAL'] as num?) ?? party.clBAL;
        party.creditDay =
            (updatedData['CREDIT_DAY'] as num?) ?? party.creditDay;
        party.crLimit = (updatedData['CR_LIMIT'] as num?) ?? party.crLimit;
        notifyListeners();
        print('✅ Updated party $accCd in PartyProvider cache with all fields');
      }
    } catch (e) {
      print('❌ Error updating party data: $e');
    }
  }

  Future<PartynameModal?> getPartyNameProductPage(context) async {
    _data.clear();
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    print(ub.token);

    // ⚡⚡⚡ OPTIMISTIC LOADING: Try API immediately without internet check!
    // This saves ~2 seconds that was spent on connectivity check
    try {
      final http.Response response = await http.get(
        Uri.parse(AppConfig.baseURL + "products/party?groupCd=85"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      ).timeout(
        const Duration(seconds: 10),
      );
      print("Here the product page is calling :-  " +
          AppConfig.baseURL +
          "products/party?groupCd=85");
      print("Bearer ${ub.token}");
      print(response.body);
      if (response.statusCode == 200) {
        final parsed = partynameModalFromJson(response.body).data;
        // Filter to only include parties (groupCD 135 or 85), exclude stockists (groupCD 136)
        final filteredData = parsed
            .where((party) => (party.groupCD == 135 || party.groupCD == 85))
            .toList();
        data.addAll(filteredData);

        // ⚡ REFRESH CART COUNTS FROM LOCAL DB FOR EACH PARTY
        final cartCounts = await DatabaseHelper().getAllPartyCartCounts();
        for (var party in data) {
          int cartCount = cartCounts[party.accCd] ?? 0;
          if (cartCount > 0) {
            party.accCartItem =
                "$cartCount Cart Item${cartCount > 1 ? 's' : ''}";
          }
        }

        if (data.isEmpty) {
          nolistParty = true;
        } else {
          nolistParty = false;
        }

        // Cache to DB for offline use (ONLY filtered parties, not stockists)
        try {
          List<Map<String, dynamic>> toCache = filteredData.map((p) {
            int? sid;
            try {
              sid = int.tryParse(p.accCd);
            } catch (_) {
              sid = null;
            }
            return {
              'server_id': sid,
              'acc_cd': p.accCd,
              'name': p.accName,
              'address': p.accAddress,
              'phone': p.mobile,
              'last_updated': DateTime.now().millisecondsSinceEpoch,
            };
          }).toList();
          await DatabaseHelper().cachePartiesJson(toCache);
          print('Cached ${toCache.length} parties');
        } catch (cacheErr) {
          print('Failed to cache parties: $cacheErr');
        }
      } else if (response.statusCode == 401) {
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e) {
      // ❌ API FAILED or offline - fallback to cache
      print('🔴 API failed: $e, falling back to cache');
      try {
        final cached = await DatabaseHelper().getCachedParties();
        // ⚡ GET ACTUAL CART COUNTS FROM LOCAL DB FOR EACH PARTY
        final cartCounts = await DatabaseHelper().getAllPartyCartCounts();

        for (var row in cached) {
          String accCd = row['acc_cd']?.toString() ?? '';
          int cartCount = cartCounts[accCd] ?? 0;
          _data.add(DatumPartyname(
            accCd: accCd,
            accName: row['name'] ?? '',
            accAddress: row['address'] ?? '',
            mobile: row['phone'] ?? '',
            accCartItem: cartCount > 0
                ? "$cartCount Cart Item${cartCount > 1 ? 's' : ''}"
                : '',
          ));
        }
        nolistParty = _data.isEmpty;
        print('📦 Loaded ${_data.length} parties from cache');
      } catch (cacheErr) {
        print('Failed to load from cache: $cacheErr');
        nolistParty = true;
      }
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
      CrashlyticsService.recordNonFatal(e, stack);
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

    final bool online = await NetworkHelper.hasInternet();
    if (!online) {
      try {
        final cached = await DatabaseHelper().getCachedParties();
        for (var row in cached) {
          _data.add(DatumPartyname(
            accCd: row['acc_cd']?.toString() ?? '',
            accName: row['name'] ?? '',
            accAddress: row['address'] ?? '',
            mobile: row['phone'] ?? '',
            accCartItem: '',
          ));
        }
        nolistParty = _data.isEmpty;
        notifyListeners();
        return null;
      } catch (e) {
        print('Failed to load parties from cache: $e');
      }
    }

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
        final parsed = partynameModalFromJson(response.body).data;
        data.addAll(parsed);
        if (data.isEmpty) {
          nolistParty = true;
          print('call 1 1');
        } else {
          nolistParty = false;
          print('call 2 2');
        }

        // Cache parties
        try {
          List<Map<String, dynamic>> toCache = parsed.map((p) {
            int? sid;
            try {
              sid = int.tryParse(p.accCd);
            } catch (_) {
              sid = null;
            }
            return {
              'server_id': sid,
              'acc_cd': p.accCd,
              'name': p.accName,
              'address': p.accAddress,
              'phone': p.mobile,
              'last_updated': DateTime.now().millisecondsSinceEpoch,
            };
          }).toList();
          await DatabaseHelper().cachePartiesJson(toCache);
        } catch (cacheErr) {
          print('Failed to cache parties: $cacheErr');
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
      CrashlyticsService.recordNonFatal(e, stack);
      //Fluttertoast.showToast(msg: "Something went wrong");
      AppSnackBar.showGetXCustomSnackBar(message: 'Something went wrong');
      print("Error in PartyProvider getpartyname data ${e.toString()}");
    }
    notifyListeners();
    return null;
  }

  Future<PartynameModal?> getpartynameForReceivableWithoutFilter(
      context) async {
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
      CrashlyticsService.recordNonFatal(e, stack);
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
      CrashlyticsService.recordNonFatal(e, stack);
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
      CrashlyticsService.recordNonFatal(e, stack);
      //Fluttertoast.showToast(msg: "Something went wrong");
      AppSnackBar.showGetXCustomSnackBar(message: 'Something went wrong');
      print("Error in PartyProvider getpartyname data ${e.toString()}");
    }
    notifyListeners();
    return null;
  }

  /// Fetch all parties using report/party?groupCd=85 (used by AccountListScreen)
  Future<PartynameModal?> getPartyNameReportGroup85(context) async {
    _data.clear();
    nolistParty = false; // Reset before fetching
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    print(ub.token);
    try {
      final http.Response response = await http.get(
        Uri.parse(AppConfig.baseURL + "report/party?groupCd=85"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );

      print(AppConfig.baseURL + "report/party?groupCd=85");
      print("Bearer ${ub.token}");
      print(response.body);
      if (response.statusCode == 200) {
        final parsed = partynameModalFromJson(response.body).data;
        _data.addAll(parsed);
        if (_data.isEmpty) {
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
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: 'Something went wrong');
      print(
          "Error in PartyProvider getPartyNameReportGroup85 data ${e.toString()}");
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

  /// Sort parties by distance from user (nearest first)
  Future<void> sortPartiesByDistance() async {
    try {
      // Get user's current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      print(
          '[Party] User location: Lat=${position.latitude}, Long=${position.longitude}');

      // Calculate distance for each party and update the model
      for (final party in _data) {
        // Skip if lat/long is missing or invalid
        final lat = _parseDouble(party.lat);
        final long = _parseDouble(party.long);

        if (lat != null && long != null) {
          final distanceInMeters = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            lat,
            long,
          );
          party.distanceInMeters = distanceInMeters;
        } else {
          party.distanceInMeters = null;
        }
      }

      // Sort parties by distance (nearest first), with null values at the end
      _data.sort((a, b) {
        if (a.distanceInMeters == null && b.distanceInMeters == null) return 0;
        if (a.distanceInMeters == null) return 1; // Null goes to end
        if (b.distanceInMeters == null) return -1; // Null goes to end
        return a.distanceInMeters!.compareTo(b.distanceInMeters!);
      });

      print('[Party] Sorted ${_data.length} parties by distance');
      notifyListeners();
    } catch (e) {
      print('[Party] Error calculating distances: $e');
      // Continue with original order if distance calculation fails
    }
  }

  /// Helper method to safely parse double from dynamic value
  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

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
      // ⚡⚡⚡ GET LATEST LOCATION FROM DATABASE (40-second interval tracking)
      // This location is already being captured every 40 seconds during punch period
      final db = DatabaseHelper();
      final latestLocData = await db.getLatestLocation();

      double lat = 0.0;
      double lng = 0.0;

      if (latestLocData != null) {
        lat = latestLocData['latitude'] ?? 0.0;
        lng = latestLocData['longitude'] ?? 0.0;
        print(
            '[ORDER_START_END] 📍 Using latest location from 40-second tracking: ($lat, $lng)');
      } else {
        print(
            '[ORDER_START_END] ⚠️ No location in database, using fallback cached location');
        // Fallback to cached location if database is empty
        lat = lp.lat ?? 0.0;
        lng = lp.lag ?? 0.0;
      }

      print('[ORDER_START_END] 🚀 Using location immediately');
      print('[ORDER_START_END]   Lat: $lat, Lng: $lng');
      print('[ORDER_START_END]   Type: $type | Party: $acc_cd');

      // Use OrderTrackingService for offline-first start/end order
      final OrderTrackingService orderSvc = OrderTrackingService();
      final result = await orderSvc.startEndOrder(
        accCd: acc_cd,
        latitude: lat,
        longitude: lng,
        type: type,
        oId: oID,
        token: ub.token.toString(),
        moduleNo: "205",
        syncId: int.tryParse(ub.syncId ?? "0") ?? 0,
        userCd: ub.syncId ?? "",
        isEndOrder: id != null, // true if END order, false if START order
      );

      if (result['success'] == true) {
        // Choose contextual messages based on type and sync state
        String message = 'Order updated successfully';
        Color bg = Colors.green;

        if (result['synced'] == true) {
          print('[PartyProvider] 🟢 RESULT: SYNCED');
          if (type == "1") {
            message = 'Order session started';
          } else if (type == "3") {
            message = 'Order session ended';
          } else if (type == "2") {
            message = 'Order placed successfully';
          }
          bg = Colors.green;
        } else {
          print('[PartyProvider] 🟠 RESULT: OFFLINE');
          if (type == "1") {
            message = 'Order session started offline (will sync when online)';
          } else if (type == "3") {
            message = 'Order session ended offline (will sync when online)';
          } else if (type == "2") {
            message = 'Order saved offline (will sync when online)';
          }
          bg = Colors.orange;
        }

        AppSnackBar.showGetXCustomSnackBar(
            message: message, backgroundColor: bg);

        // Update local state based on START or END
        if (id != null) {
          // END ORDER
          pp.change("", "");
          punchInOutParty = "";
          punchInOutPartyId = "";
          notifyListeners();

          // ⚡ BACKGROUND: Pre-fetch fresh party list so it's ready for next START_ORDER
          print('[END_ORDER] 📡 Background: Pre-fetching fresh party list...');
          Future.microtask(() async {
            try {
              await getPartyNameProductPage(Get.context!);
              print('[END_ORDER] ✅ Background: Party list refreshed and ready');
            } catch (e) {
              print(
                  '[END_ORDER] ⚠️ Background: Could not pre-fetch parties: $e');
            }
          });
        } else {
          // START ORDER
          pp.change(accName, acc_cd);
        }
        loading = false;
        notifyListeners();

        // 📍 Background: Get fresh location for future API calls (non-blocking)
        Future.microtask(() async {
          try {
            print(
                '[ORDER_START_END] 📍 Background: Fetching fresh location...');
            final freshLocation = await lp.determinePosition();
            lp.lat = freshLocation.latitude;
            lp.lag = freshLocation.longitude;
            print(
                '[ORDER_START_END] ✅ Background: Location updated to (${freshLocation.latitude}, ${freshLocation.longitude})');
          } catch (e) {
            print(
                '[ORDER_START_END] ⚠️ Background: Could not refresh location: $e');
            // Silently fail - next API call will use database location
          }
        });
      } else {
        // Failed to process order
        print('[PartyProvider] 🔴 RESULT: FAILED | Error: ${result['error']}');
        AppSnackBar.showGetXCustomSnackBar(
            message: result['error'] ?? 'Failed to process order');
        loading = false;
        notifyListeners();
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      print('[ORDER_START_END] ❌ Error: $e');
      AppSnackBar.showGetXCustomSnackBar(message: 'Error: $e');

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
