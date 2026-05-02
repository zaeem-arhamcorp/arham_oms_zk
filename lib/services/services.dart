import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:arham_corporation/helper/helper.dart';
import 'package:arham_corporation/models/ItemWiseReportModal.dart';
import 'package:arham_corporation/models/OutstandingReportModal.dart';
import 'package:arham_corporation/models/PartyWiseReportModal.dart';
import 'package:arham_corporation/models/narrationModal.dart';
import 'package:arham_corporation/models/partyWiseOutstandingReportModal.dart';
import 'package:arham_corporation/models/personModal.dart';
import 'package:arham_corporation/models/product_response.dart';
import 'package:arham_corporation/models/receipt_confim_model.dart';
import 'package:arham_corporation/models/salesRegisterReportModal.dart';
import 'package:arham_corporation/models/stockReportModal.dart';
import 'package:arham_corporation/models/userWiseOutStandingModal.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/party_provider.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/services/crashlytics_service.dart';
import 'package:arham_corporation/views/loginpage.dart';
import 'package:cancellation_token_http/http.dart' as httpc;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../constants/constants.dart';
import '../models/accountLeagerReportModal.dart';
import '../models/dailReportListModal.dart';
import '../models/dashboardmodal.dart';
import '../models/itemLedgerReportModal.dart';
import '../models/itemWisePartyWiseReportModal.dart';
import '../models/orderReportModal.dart';
import '../models/productModal.dart';
import '../models/settingmodal.dart';
import '../models/utlityModal.dart';
import '../product/controller/product_controller.dart';
import '../providers/user_provider.dart';
import '../views/monthly_target/services/api_services.dart';
import 'database_helper.dart';

class Services {
  Future<DashboardModal?> getDashboarddata(BuildContext context) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    try {
      final http.Response response = await http.get(
        Uri.parse("${AppConfig.baseURL}dashboard"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print("${AppConfig.baseURL}dashboard");
      print(response.body);
      if (response.statusCode == 200) {
        return dashboardModalFromJson(response.body);
      } else if (response.statusCode == 401) {
        print('print 1');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      } else {
        print(
            '[Services:getDashboarddata] Non-auth failure: status=${response.statusCode}');
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);

      final isNetworkError =
          e is SocketException || e.toString().contains('SocketException');

      AppSnackBar.showGetXCustomSnackBar(
        message: isNetworkError ? Constants.networkMsg : "Something went wrong",
      );
      print("Error in Services getDashboard data Dashboard ${e.toString()}");
    }
    return null;
  }

  Future<ProductModal?> getProduct(
      page, search, deptCd, context, httpc.CancellationToken? tocken) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    var query = "page=$page";
    //var query = "";
    try {
      if (search != null && search != "") {
        query = "$query&search=${Uri.encodeComponent(search)}";
      }
      if (deptCd != null) {
        query = "$query&deptCd=$deptCd";
      }

      var response = await httpc.get(
        Uri.parse("${AppConfig.baseURL}products?$query"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
        cancellationToken: tocken,
      );
      print("${AppConfig.baseURL}products?$query");
      print(response.body);

      if (response.statusCode == 200) {
        return productModalFromJson(response.body);
      } else if (response.statusCode == 401) {
        print('print 2');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      } else {
        print(
            '[Services:getProduct] Non-auth failure: status=${response.statusCode}');
      }
    } on httpc.CancelledException {
      getProduct(page, search, deptCd, context, null);
      print("cancelled Expeption");
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      // Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getProduct data ${e.toString()}");
    }
    return null;
  }

  Future<ProductResponse?> getProductNew(
      page, search, deptCd, context, httpc.CancellationToken? tocken) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    try {
      var response = await httpc.get(
        Uri.parse("${AppConfig.baseURL}export/products"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
        cancellationToken: tocken,
      );

      print("API URL: ${AppConfig.baseURL}export/products");
      print("Response: ${response.body}");

      if (response.statusCode == 200) {
        final decodedJson = json.decode(response.body);

        if (decodedJson == null || decodedJson['data'] == null) {
          print("API returned null data");
          return null;
        }

        return ProductResponse.fromJson(decodedJson);
      } else if (response.statusCode == 401) {
        print("API error: ${response.statusCode}");
        print('print 3');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      } else {
        print(
            '[Services:getProductNew] Non-auth failure: status=${response.statusCode}');
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      print("Error in API Call: ${e.toString()}");
    }

    return null;
  }

  Future<List<DeptmentModal>?> getDeptment(context) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    // ⚡⚡⚡ OPTIMISTIC LOADING: Try API immediately without network check!
    // This saves ~2 seconds that was spent on connectivity check
    try {
      print('[DEPARTMENTS] Fetching from API (optimistic)...');
      final http.Response response = await http.get(
        Uri.parse("${AppConfig.baseURL}deptment"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      ).timeout(
        const Duration(seconds: 10),
      );
      print("[DEPARTMENTS] GET ${AppConfig.baseURL}deptment");
      print('[DEPARTMENTS] API Response: ${response.body}');

      if (response.statusCode == 200) {
        final deptList = deptmentModalFromJson(response.body).data;

        // Cache departments for offline use
        if (deptList.isNotEmpty) {
          try {
            final List<Map<String, dynamic>> deptMaps = deptList
                .map((d) => {
                      'DEPT_CD': d.DEPT_CD,
                      'DEPT_NAME': d.DEPT_NAME,
                      'SYNC_ID': d.SYNC_ID,
                    })
                .toList();
            await DatabaseHelper().cacheDepartments(deptMaps);
            print('[DEPARTMENTS] ✅ Cached ${deptMaps.length} departments');
          } catch (e) {
            print('[DEPARTMENTS] Failed to cache departments: $e');
          }
        }

        return deptList;
      } else if (response.statusCode == 401) {
        print('[DEPARTMENTS] API returned status ${response.statusCode}');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
        return null;
      } else {
        print(
            '[DEPARTMENTS] Non-auth failure status=${response.statusCode}, trying cache...');
        return await _getDepartmentsFromCache();
      }
    } catch (e, stack) {
      // ❌ API FAILED - fallback to cache
      print('[DEPARTMENTS] 🔴 API failed: $e, falling back to cache');
      try {
        return await _getDepartmentsFromCache();
      } catch (e2) {
        print('[DEPARTMENTS] Fallback cache load also failed: $e2');
        CrashlyticsService.recordNonFatal(e2, stack);
        return null;
      }
    }
  }

  /// Helper method to load departments from local cache
  Future<List<DeptmentModal>?> _getDepartmentsFromCache() async {
    try {
      final cachedDepts = await DatabaseHelper().getAllDepartments();
      if (cachedDepts.isNotEmpty) {
        final deptList = cachedDepts
            .map((d) => DeptmentModal(
                  DEPT_CD: d['DEPT_CD'],
                  DEPT_NAME: d['DEPT_NAME'],
                  SYNC_ID: d['SYNC_ID'],
                ))
            .toList();
        print(
            '[DEPARTMENTS] ✅ Loaded ${deptList.length} departments from cache');
        return deptList;
      } else {
        print('[DEPARTMENTS] No cached departments available');
        return null;
      }
    } catch (e) {
      print('[DEPARTMENTS] Error loading cached departments: $e');
      return null;
    }
  }

  Future<dynamic> addItemtoCartPartyWise(
      String partyid,
      String itemCd,
      String qty,
      String? otherDesc,
      context,
      String? rate,
      String? remarks) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    try {
      var requestBody = {
        "partyCd": partyid,
        "itemCd": itemCd,
        "qty": qty,
        "lrate": rate,
      };
      if (otherDesc != null && otherDesc != "") {
        requestBody["otherDesc"] = otherDesc;
      }
      if (remarks != null) {
        requestBody['fld5'] = remarks;
      }
      if (rate != null && rate != "") {
        requestBody['rate'] = rate;
      }
      print(requestBody);
      final http.Response response = await http.post(
        Uri.parse("${AppConfig.baseURL}cart"),
        body: requestBody,
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print('add into card no:162:' + AppConfig.baseURL + "cart");
      print(response.body);
      if (response.statusCode == 401) {
        print('print 5');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      } else {
        return {
          "message": json.decode(response.body)['message'],
          "statusCode": response.statusCode
        };
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);

      final isNetworkError =
          e is SocketException || e.toString().contains('SocketException');

      AppSnackBar.showGetXCustomSnackBar(
        message: isNetworkError ? Constants.networkMsg : "Something went wrong",
      );
      //Fluttertoast.showToast(msg: "Something went wrong");;
      print("Error in Services addItemtoCart data ${e.toString()}");
    }
  }

  Future<dynamic> addItemtoCart(String partyid, String itemCd, String qty,
      String? otherDesc, context, String? rate, String? remarks) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    try {
      var requestBody = {
        "partyCd": partyid,
        "itemCd": itemCd,
        "qty": qty,
        "lrate": rate, // Fazal Changes 14-02-2025
      };
      if (otherDesc != null && otherDesc != "") {
        requestBody["otherDesc"] = otherDesc;
      }
      if (remarks != null) {
        requestBody['fld5'] = remarks;
      }
      if (rate != null && rate != "") {
        requestBody['rate'] = rate;
      }
      print(requestBody);
      final http.Response response = await http.post(
        Uri.parse("${AppConfig.baseURL}cart"),
        body: requestBody,
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print("Add into cart api  lno:207 : ${AppConfig.baseURL}cart");
      print(response.body);
      if (response.statusCode == 401) {
        print('print 6');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      } else {
        return {
          "message": json.decode(response.body)['message'],
          "statusCode": response.statusCode
        };
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");;
      print("Error in Services addItemtoCart data ${e.toString()}");
    }
  }

  Future<String?> bulkUpdateCartItem(List<dynamic> items, context) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    try {
      final http.Response response = await http.post(
        Uri.parse("${AppConfig.baseURL}bulk-cart-item"),
        body: items,
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print(response.body);
      if (response.statusCode == 200) {
        return json.decode(response.body)["message"];
      } else {
        print('print 7');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");;
      print("Error in Services bulkUpdateCartItem data ${e.toString()}");
    }
    return null;
  }

  Future<String?> updateItemtoCart(
      String partyid,
      String itemCd,
      String qty,
      String? otherDesc,
      context,
      String? rate,
      String? lrate,
      String? remarks,
      String cId) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    try {
      var requestBody = {
        "partyCd": partyid,
        "itemCd": itemCd,
        "qty": qty,
        "cId": cId,
        //"lrate": rate,// Fazal Changes 14-02-2025
        "moduleNo": "205",
      };
      if (lrate != null) {
        requestBody["lrate"] = lrate;
      }
      if (otherDesc != null) {
        requestBody["otherDesc"] = otherDesc;
      }
      if (remarks != null) {
        requestBody['fld5'] = remarks;
      }
      if (rate != null) {
        requestBody['rate'] = rate;
      }
      final http.Response response = await http.put(
        Uri.parse("${AppConfig.baseURL}cart"),
        body: requestBody,
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print("here is add to cart : ${AppConfig.baseURL}cart");
      print(requestBody);
      print(response.body);
      if (response.statusCode == 200) {
        return json.decode(response.body)["message"];
      } else if (response.statusCode == 404) {
        return json.decode(response.body)["message"];
      } else {
        print('print 8');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");;
      print("Error in Services getDashboard data add to cart ${e.toString()}");
    }
    return null;
  }

  Future<String?> deleteItemtoCart(String cartid, context) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    try {
      final http.Response response = await http.delete(
        Uri.parse("${AppConfig.baseURL}cart/$cartid"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print("DELETE ${AppConfig.baseURL}cart/$cartid");
      print(response.body);
      if (response.statusCode == 200) {
        return json.decode(response.body)["message"];
      } else {
        print('print 9');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");;
      print("Error in Services getDashboard data delete cart ${e.toString()}");
    }
    return null;
  }

  Future<String?> addOrder(partyCd, lat, longi, context, orderRemarks) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    final PartyProvider pp = Provider.of<PartyProvider>(context, listen: false);
    final ProfileProvider pb =
        Provider.of<ProfileProvider>(context, listen: false);
    print("ORDER LOC:  $lat ++ $longi");
    try {
      var requestBody = {
        "partyCd": partyCd,
        "lat": lat ?? '0',
        "longi": longi ?? '0',
        "narration": orderRemarks,
        "moduleNo": "205"
      };
      print(requestBody);

      final http.Response response = await http.post(
        Uri.parse("${AppConfig.baseURL}orders"),
        body: requestBody,
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print("here is oder url ${AppConfig.baseURL}orders");
      print(requestBody);
      print(response.body);
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        print('[ORDER] 🔍 Full /orders response: ${decoded["data"]}');
        final extractedOId = decoded["data"]?["oId"];
        print(
            '[ORDER] 🔍 Extracted oId: $extractedOId (type: ${extractedOId.runtimeType})');

        // Check for an order-limit warning from the backend and persist it
        // so the homescreen can display it as a snackbar after navigation.
        String? warning;

        // Try to get warnings array (plural) first
        final warnings = decoded['warnings'];
        if (warnings is List && warnings.isNotEmpty) {
          // Combine multiple warnings into a single message
          warning = warnings.join('\n');
          print('[ORDER] Warnings received from API: $warnings');
        } else {
          // Fallback to single warning field
          warning = decoded['warning']?.toString();
        }

        if (warning != null && warning.isNotEmpty) {
          pb.setPendingWarning(warning);
          print('[ORDER] Warning to display: $warning');
        }

        // Cache license info from API response for offline license checking
        try {
          final licenseInfo = decoded['licenseInfo'];
          if (licenseInfo != null) {
            final currentOrderCount = licenseInfo['orderCount'] as int? ?? 0;

            // Persist a one-time milestone marker for HomePage.
            // Home will consume this flag and show congratulations after redirect.
            if (currentOrderCount == 5000) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('show_5000_orders_congrats', true);
              print('[ORDER] 🎉 Milestone reached: 5000 orders');
            }

            // Get syncId from profile or UserProvider (profile.data might be null)
            int syncId = 0;
            final profileSyncId = pb.data?.syncId;
            if (profileSyncId is int) {
              syncId = profileSyncId;
            } else if (profileSyncId is String) {
              syncId = int.tryParse(profileSyncId) ?? 0;
            }

            // Fallback to UserProvider if profile didn't have it
            if (syncId == 0 && ub.syncId != null) {
              syncId = int.tryParse(ub.syncId ?? '0') ?? 0;
            }

            print(
                '[ORDER] Debug - profileSyncId=$profileSyncId, userSyncId=${ub.syncId}, parsed syncId=$syncId');

            if (syncId > 0) {
              await DatabaseHelper().cacheLicenseInfo(
                syncId: syncId,
                orderCount: licenseInfo['orderCount'] as int? ?? 0,
                maxOrders: licenseInfo['maxOrders'] as int? ?? 0,
                autoBlacklisted: licenseInfo['autoBlacklisted'] == true,
                renewalTriggered: licenseInfo['renewalTriggered'] == true,
              );
              print(
                  '[ORDER] ✅ Cached license info from API: syncId=$syncId, orders=${licenseInfo['orderCount']}/${licenseInfo['maxOrders']}, blacklisted=${licenseInfo['autoBlacklisted']}');
            } else {
              print(
                  '[ORDER] ⚠️ Could not retrieve SYNC_ID for license caching (syncId=$syncId)');
            }
          }
        } catch (e) {
          print('[ORDER] ⚠️ Error caching license info: $e');
        }

        if (pb.YN == "Y") {
          final orderId = extractedOId != null ? extractedOId.toString() : '';
          print('[ORDER] ✅ Sending END order with oId=$orderId');
          pp
              .startEndOrder(
                  pb.YN == "Y" ? pp.punchInOutParty : "", partyCd, context, "2",
                  oID: orderId.isNotEmpty ? orderId : null)
              .then((value) {
            pb.getProfile().then((v) {
              // Load settings after profile is loaded
              // 🛡️ Guard: Only call if context is still mounted
              if (context.mounted) {
                pb.loadSettings(context);
              }
            });
          });
        }
        return decoded["message"];
      } else {
        print('print 10');
        // 🛡️ Guard: Only signout if context is still mounted
        if (context.mounted) {
          ub.userSignout(context).then((value) {
            Get.offAll(() => LoginPage());
          });
        }
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      print("Error in Services addOrder data ${e.toString()}");

      // Re-throw network errors so the caller can handle offline fallback
      // Don't show error snackbar here - let caller handle it
      rethrow;
    }
    return null;
  }

  Future<Map<String, dynamic>?> updateOrder(oId, context,
      {String? stockist}) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    print(ub.token);
    try {
      // Build URI with optional stockist parameter
      var uri = Uri.parse("${AppConfig.baseURL}orders/$oId");
      if (stockist != null && stockist.isNotEmpty) {
        uri = uri.replace(queryParameters: {'stockist': stockist});
      }

      final http.Response response = await http.put(
        uri,
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print("${AppConfig.baseURL}orders/$oId");
      print(response.body);
      print("Response Status Code: ${response.statusCode}");

      if (response.statusCode == 200 ||
          response.statusCode == 400 ||
          response.statusCode == 422) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        // Check if order can be edited - handle both boolean and string "false"
        final canEditValue = responseData['CAN_EDIT'];
        final isCanEditFalse = canEditValue == false || canEditValue == 'false';

        if (isCanEditFalse) {
          // Order cannot be edited - return error info
          print(
              '[Services] CAN_EDIT is false - cannot edit order: ${responseData['message']}');
          return {
            'success': false,
            'message': responseData['message'] ?? 'Order cannot be edited',
            'CAN_EDIT': false,
          };
        }

        // Order can be edited
        print('[Services] CAN_EDIT is true - order can be edited');
        return {
          'success': true,
          'message': responseData["message"],
          'CAN_EDIT': true,
        };
      } else {
        print('print 11 - Unexpected status code: ${response.statusCode}');

        // ub.userSignout(context).then((value) {
        //   Get.offAll(() => LoginPage());
        // });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");;
      print("Error in Services updateOrder  ${e.toString()}");
    }
    return null;
  }

  Future<String?> deleteOrder(oId, context, {String? stockist}) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    print(ub.token);
    try {
      final http.Response response = await http.delete(
        Uri.parse("${AppConfig.baseURL}orders/$oId"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      late final ProductController productcontroller =
          Get.isRegistered<ProductController>()
              ? Get.find<ProductController>()
              : Get.put(ProductController());

      final PartyProvider party =
          Provider.of<PartyProvider>(context, listen: false);
      final ProfileProvider profile =
          Provider.of<ProfileProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final resolvedStockist = (stockist != null && stockist.trim().isNotEmpty)
          ? stockist.trim()
          : (productcontroller.selectedStockistId.value.trim().isNotEmpty
              ? productcontroller.selectedStockistId.value.trim()
              : (profile.YN == "Y" ? party.punchInOutPartyId : party.partyid)
                  .toString()
                  .trim());

      final pobSynced = await (Get.isRegistered<MonthlyTargetApiService>()
              ? Get.find<MonthlyTargetApiService>()
              : Get.put(MonthlyTargetApiService()))
          .syncPobMonthlyTarget(
        stockistCd: resolvedStockist,
        token: userProvider.token,
      );
      print('[DELETE_CART] ✅ POB sync result: $pobSynced');
      print(response.body);
      if (response.statusCode == 200) {
        return json.decode(response.body)["message"];
      } else {
        print('print 12');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services deleteOrder  ${e.toString()}");
    }
    return null;
  }

  //Report Api Call Start

  Future<OrderReportModal?> getOrderReport(
      context, partyCd, fromdate, toDate, userCd, filterOrderType) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    print(ub.token);
    var queryString =
        "partyCd=$partyCd&fromDate=$fromdate&toDate=$toDate&filterOrderType=$filterOrderType";
    if (userCd != null) {
      queryString = "$queryString&userCd=$userCd";
    }

    try {
      final http.Response response = await http.get(
        Uri.parse("${AppConfig.baseURLReport}orders?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print("Order URL ${AppConfig.baseURLReport}orders?$queryString");
      print("Order Report ${response.body}");

      log(response.body);
      if (response.statusCode == 200) {
        return orderReportModalFromJson(response.body);
      } else {
        print('print 13');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getOrderReport data ${e.toString()}");
    }
    return null;
  }

  Future<String?> getOrderExportFile(
      context, partyCd, fromdate, toDate, userCd, type) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    print("fff");
    var queryString =
        "partyCd=$partyCd&fromDate=${Helper.toApi(fromdate)}&toDate=${Helper.toApi(toDate)}&export=true&exportType=$type";
    if (userCd != null) {
      queryString = "$queryString&userCd=$userCd";
    }
    try {
      final http.Response response = await http.get(
        Uri.parse("${AppConfig.baseURLReport}orders?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print("${AppConfig.baseURLReport}orders?$queryString");
      print(response.statusCode);
      log(response.body);
      if (response.statusCode == 200) {
        return json.decode(response.body)["data"];
      } else {
        print('print 14');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getOrderReport data ${e.toString()}");
      return null;
    }
    return null;
  }

  Future<String?> getOrderExportFileItem(
      context, partyCd, fromdate, toDate, userCd, type) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    print("fff");
    var queryString =
        "partyCd=$partyCd&fromDate=${Helper.toApi(fromdate)}&toDate=${Helper.toApi(toDate)}&export=true&exportType=$type&expand=true";
    if (userCd != null) {
      queryString = "$queryString&userCd=$userCd";
    }
    try {
      final http.Response response = await http.get(
        Uri.parse("${AppConfig.baseURLReport}orders?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print("${AppConfig.baseURLReport}orders?$queryString");
      print(response.statusCode);
      log(response.body);
      if (response.statusCode == 200) {
        final pdfUrl = json.decode(response.body)["data"];
        print("[Order Export] PDF URL for partyId=$partyCd: $pdfUrl");
        return pdfUrl;
      } else {
        print(
            '[Order Export] API returned status ${response.statusCode} for partyId=$partyCd');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getOrderReport data ${e.toString()}");
      return null;
    }
    return null;
  }

  Future<AccountLEadgerReportModal?> getAccountLeagerReport(
      context, fromdate, toDate, partycd) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    var queryString = "fromDate=$fromdate&toDate=$toDate";

    if (partycd != null) {
      queryString = "$queryString&partyCd=$partycd";
    }

    try {
      final http.Response response = await http.get(
        Uri.parse("${AppConfig.baseURLReport}account-ledger?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );

      print("${AppConfig.baseURLReport}account-ledger?$queryString");
      print("Bearer ${ub.token}");
      print(response.body);

      if (response.statusCode == 200) {
        return accountLEadgerReportModalFromJson(response.body);
      } else {
        print('print 15');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getAccountLeagerReport data ${e.toString()}");
    }
    return null;
  }

  Future<String?> getAccountLeagerExportFile(
      context, fromdate, toDate, partycd, type) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    var queryString =
        "fromDate=${Helper.toApi(fromdate)}&toDate=${Helper.toApi(toDate)}&export=true&exportType=$type";

    if (partycd != null) {
      queryString = "$queryString&partyCd=$partycd";
    }

    try {
      final http.Response response = await http.get(
        Uri.parse("${AppConfig.baseURLReport}account-ledger?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print("${AppConfig.baseURLReport}account-ledger?$queryString");
      print(response.body);
      if (response.statusCode == 200) {
        return json.decode(response.body)["data"];
      } else {
        print('print 16');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getAccountLeagerReport data ${e.toString()}");
    }
    return null;
  }

  Future<AccountLEadgerDetailReportModal?> getAccountLeagerDetailReport(
      context, fromdate, toDate, partycd, vouchDt, bookCd, vouchNo) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    // var queryString =
    //     "fromDate=$fromdate&toDate=$toDate&type=full&bookCd=$bookCd&vouchDt=${vouchDt.split("-")[2]}-${vouchDt.split("-")[1]}-${vouchDt.split("-")[0]}&vouchNo=$vouchNo";

    var queryString =
        "fromDate=$fromdate&toDate=$toDate&type=full&bookCd=$bookCd&vouchDt=$vouchDt&vouchNo=$vouchNo";

    if (partycd != null) {
      queryString = "$queryString&partyCd=$partycd";
    }

    try {
      final http.Response response = await http.get(
        Uri.parse("${AppConfig.baseURLReport}account-ledger?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print("${AppConfig.baseURLReport}account-ledger?$queryString");
      print(response.body);
      if (response.statusCode == 200) {
        return accountLEadgerDetailReportModalFromJson(response.body);
      } else {
        print('print 17');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print(
          "Error in Services getAccountLeagerDetailReport data ${e.toString()}");
    }
    return null;
  }

  Future<AccountLEadgerBillWiseDetailReportModal?>
      getAccountLeagerBillWiseDetailReport(
          context, partycd, vouchDt, bookCd, vouchNo) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    // var queryString =
    //     "type=full&bookCd=$bookCd&vouchDt=${vouchDt.split("-")[2]}-${vouchDt.split("-")[1]}-${vouchDt.split("-")[0]}&partyCd=$partycd&vouchNo=$vouchNo";

    var queryString =
        "type=full&bookCd=$bookCd&vouchDt=$vouchDt&partyCd=$partycd&vouchNo=$vouchNo";

    try {
      final http.Response response = await http.get(
        Uri.parse("${AppConfig.baseURLReport}account-ledger?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print("${AppConfig.baseURLReport}account-ledger?$queryString");
      print(response.body);
      if (response.statusCode == 200) {
        return accountLEadgerBillWiseDetailReportModalFromJson(response.body);
      } else {
        print('print 18');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print(
          "Error in Services getAccountLeagerDetailReport data ${e.toString()}");
    }
    return null;
  }

  Future<DailReportListModal?> getDailyReport(context, fromdate, toDate) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    print(ub.token);
    try {
      final http.Response response = await http.get(
        Uri.parse(
            "${AppConfig.baseURLReport}daily-report?fromDate=$fromdate&toDate=$toDate"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print(
          "${AppConfig.baseURLReport}daily-report?fromDate=$fromdate&toDate=$toDate");
      print("Bearer ${ub.token}");
      print(response.body);
      if (response.statusCode == 200) {
        return dailReportListModalFromJson(response.body);
      } else {
        print('print 19');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getDailyReport data ${e.toString()}");
    }
    return null;
  }

  Future<ItemLeadgerReportModal?> getItemLeagerReport(
      context, fromdate, toDate, itemCd) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    print(ub.token);
    try {
      final http.Response response = await http.get(
        Uri.parse(
            "${AppConfig.baseURLReport}item-ledger-report?itemCd=$itemCd&fromDate=$fromdate&toDate=$toDate"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print(
          "${AppConfig.baseURLReport}item-ledger-report?itemCd=$itemCd&fromDate=$fromdate&toDate=$toDate");
      print(response.body);
      if (response.statusCode == 200) {
        return itemLeadgerReportModalFromJson(response.body);
      } else {
        print('print 20');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getItemLeagerReport data ${e.toString()}");
    }
    return null;
  }

  Future<String?> getItemLeagerExportFile(
      context, fromdate, toDate, itemCd, type) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    var queryString =
        "itemCd=$itemCd&fromDate=${Helper.toApi(fromdate)}&toDate=${Helper.toApi(toDate)}&export=true&exportType=$type";

    try {
      final http.Response response = await http.get(
        Uri.parse("${AppConfig.baseURLReport}item-ledger-report?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body)["data"];
      } else {
        print('print 21');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getOrderReport data ${e.toString()}");
      return null;
    }
    return null;
  }

  Future<StockReportModal?> getStockReport(
      context, itemCd, deptCd, page, showZeroStk, radiocheck) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    var queryString =
        "page=$page&items_per_page=50&showZeroStk=$showZeroStk&rateType=$radiocheck";

    if (itemCd != null) {
      queryString = "$queryString&itemCd=$itemCd";
    }

    if (deptCd != null) {
      queryString = "$queryString&deptCd=$deptCd";
    }

    print(queryString);
    try {
      final http.Response response = await http.get(
        Uri.parse("${AppConfig.baseURLReport}stock-report?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          "Connection": "keep-alive",
          'x-app-type': 'oms',
        },
      );
      print("${AppConfig.baseURLReport}stock-report?$queryString");
      print("Bearer ${ub.token}");
      print((response.body));

      if (response.statusCode == 200) {
        return stockReportModalFromJson(response.body);
      } else {
        print('print 22');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getStockReport data ${e.toString()}");
    }
    return null;
  }

  Future<String?> getStockExportFile(
      context, itemCd, deptCd, page, showZeroStk, radiocheck, type) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    var queryString =
        "page=$page&items_per_page=50&showZeroStk=$showZeroStk&rateType=$radiocheck&export=true&exportType=$type";

    if (itemCd != null) {
      queryString = "$queryString&itemCd=$itemCd";
    }

    if (deptCd != null) {
      queryString = "$queryString&deptCd=$deptCd";
    }
    try {
      final http.Response response = await http.get(
        Uri.parse("${AppConfig.baseURLReport}stock-report?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );

      print("${AppConfig.baseURLReport}stock-report?$queryString");
      print("Bearer ${ub.token}");
      print(response.body);

      if (response.statusCode == 200) {
        return json.decode(response.body)["data"];
      } else {
        print('print 23');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getOrderReport data ${e.toString()}");
      return null;
    }
    return null;
  }

  Future<OutstandingReportModal?> getOutStandingReportPayble(
      context, toDate, partyCd, city) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    var queryString = "toDate=$toDate";

    if (partyCd != null) {
      queryString = "$queryString&partyCd=$partyCd";
    }

    if (city != null) {
      queryString = "$queryString&city=$city";
    }

    print(ub.token);
    try {
      final http.Response response = await http.get(
        Uri.parse(
            "${AppConfig.baseURLReport}outstanding-payable-report?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print(
          "${AppConfig.baseURLReport}outstanding-payable-report?$queryString");
      print(response.body);
      if (response.statusCode == 200) {
        return OutstandingReportModalFromJson(response.body);
      } else {
        print('print 24');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getOutStandingReport data ${e.toString()}");
    }
    return null;
  }

  Future<OutstandingReportModal?> getOutStandingReport(
      context, toDate, partyCd, city) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    var queryString = "toDate=$toDate";

    if (partyCd != null) {
      queryString = "$queryString&partyCd=$partyCd";
    }

    if (city != null) {
      queryString = "$queryString&city=$city";
    }

    print(ub.token);
    try {
      final http.Response response = await http.get(
        Uri.parse(
            "${AppConfig.baseURLReport}outstanding-receivable-report?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print(
          "${AppConfig.baseURLReport}outstanding-receivable-report?$queryString");
      print(response.body);
      if (response.statusCode == 200) {
        return OutstandingReportModalFromJson(response.body);
      } else {
        print('print 25');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getOutStandingReport data ${e.toString()}");
    }
    return null;
  }

  Future<String?> getOutStandingExportFileReceivable(
      context, toDate, partyCd, city, type) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    var queryString =
        "toDate=${Helper.toApi(toDate)}&export=true&exportType=$type";

    if (partyCd != null) {
      queryString = "$queryString&partyCd=$partyCd";
    }

    if (city != null) {
      queryString = "$queryString&city=$city";
    }

    try {
      final http.Response response = await http.get(
        Uri.parse(
            "${AppConfig.baseURLReport}outstanding-receivable-report?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body)["data"];
      } else {
        print('print 26');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getOrderReport data ${e.toString()}");
      return null;
    }
    return null;
  }

  Future<String?> getOutStandingExportFilePayable(
      context, toDate, partyCd, city, type) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    var queryString =
        "toDate=${Helper.toApi(toDate)}&export=true&exportType=$type";

    if (partyCd != null) {
      queryString = "$queryString&partyCd=$partyCd";
    }

    if (city != null) {
      queryString = "$queryString&city=$city";
    }

    try {
      final http.Response response = await http.get(
        Uri.parse(
            "${AppConfig.baseURLReport}outstanding-payable-report?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body)["data"];
      } else {
        print('print 27');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getOrderReport data ${e.toString()}");
      return null;
    }
    return null;
  }

  Future<String?> getOutStandingExportFile(
      context, toDate, partyCd, city, type) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    var queryString =
        "toDate=${Helper.toApi(toDate)}&export=true&exportType=$type";

    if (partyCd != null) {
      queryString = "$queryString&partyCd=$partyCd";
    }

    if (city != null) {
      queryString = "$queryString&city=$city";
    }

    try {
      final http.Response response = await http.get(
        Uri.parse("${AppConfig.baseURLReport}outstanding-report?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body)["data"];
      } else {
        print('print 28');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getOrderReport data ${e.toString()}");
      return null;
    }
    return null;
  }

  Future<UserWiseOutstandingReportModal?> getUserWiseOutStandingReport(
      context, toDate, partyCd, city, userCd) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    var queryString = "toDate=$toDate&userCd=$userCd";

    if (partyCd != null) {
      queryString = "$queryString&partyCd=$partyCd";
    }

    if (city != null) {
      queryString = "$queryString&city=$city";
    }

    print(ub.token);
    try {
      final http.Response response = await http.get(
        Uri.parse(
            "${AppConfig.baseURLReport}user-wise-outstanding-report?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print(response.body);
      if (response.statusCode == 200) {
        return userWiseOutstandingReportModalFromJson(response.body);
      } else {
        print('print 29');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getOutStandingReport data ${e.toString()}");
    }
    return null;
  }

  Future<SalesRegisterReportModal?> getSalesRegisterReport(
      context, fromDate, toDate, partyCd, city) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    var queryString = "fromDate=$fromDate&toDate=$toDate";

    if (partyCd != null) {
      queryString = "$queryString&partyCd=$partyCd";
    }

    if (city != null) {
      queryString = "$queryString&city=$city";
    }

    //try {
    final http.Response response = await http.get(
      Uri.parse("${AppConfig.baseURLReport}sales-register-report?$queryString"),
      headers: {
        "Authorization": "Bearer ${ub.token}",
        'x-app-type': 'oms',
      },
    );
    print("${AppConfig.baseURLReport}sales-register-report?$queryString");
    print(response.body);
    if (response.statusCode == 200) {
      return salesRegisterReportModalFromJson(response.body);
    } else {
      print('print 30');
      ub.userSignout(context).then((value) {
        Get.offAll(() => LoginPage());
      });
    }
    // } catch (e, stack) {
    //   AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
    //   //Fluttertoast.showToast(msg: "Something went wrong");
    //   print("Error in Services getSalesRegisterReport data ${e.toString()}");
    // }
    return null;
  }

  Future<AccountLEadgerDetailReportModal?> getSalesRegisterDetailReport(
      context, fromdate, toDate, partycd, vouchDt, bookCd) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    // var queryString =
    //     "fromDate=$fromdate&toDate=$toDate&type=full&bookCd=$bookCd&vouchDt=${vouchDt.split("-")[2]}-${vouchDt.split("-")[1]}-${vouchDt.split("-")[0]}";

    var queryString =
        "fromDate=$fromdate&toDate=$toDate&type=full&bookCd=$bookCd&vouchDt=$vouchDt";

    if (partycd != null) {
      queryString = "$queryString&partyCd=$partycd";
    }

    try {
      final http.Response response = await http.get(
        Uri.parse(
            "${AppConfig.baseURLReport}sales-register-report?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print("${AppConfig.baseURLReport}sales-register-report?$queryString");
      print("Bearer ${ub.token}");
      print(response.body);
      if (response.statusCode == 200) {
        return accountLEadgerDetailReportModalFromJson(response.body);
      } else {
        print('print 31');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print(
          "Error in Services getSalesRegisterDetailReport data ${e.toString()}");
    }
    return null;
  }

  Future<String?> getSalesRegisterReportExportFile(
      context, fromDate, toDate, partyCd, city, type) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    var queryString =
        "fromDate=${Helper.toApi(fromDate)}&toDate=${Helper.toApi(toDate)}&export=true&exportType=$type";

    if (partyCd != null) {
      queryString = "$queryString&partyCd=$partyCd";
    }

    if (city != null) {
      queryString = "$queryString&city=$city";
    }

    try {
      final http.Response response = await http.get(
        Uri.parse(
            "${AppConfig.baseURLReport}sales-register-report?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print(response.body);
      if (response.statusCode == 200) {
        return json.decode(response.body)["data"];
      } else {
        print('print 32');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print(
          "Error in Services getSalesRegisterReportExportFile data ${e.toString()}");
    }
    return null;
  }

  Future<String?> getUserWiseOutStandingExportFile(
      context, toDate, partyCd, city, userCd, type) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    var queryString =
        "toDate=${Helper.toApi(toDate)}&export=true&exportType=$type&userCd=$userCd";

    if (partyCd != null) {
      queryString = "$queryString&partyCd=$partyCd";
    }

    if (city != null) {
      queryString = "$queryString&city=$city";
    }

    try {
      final http.Response response = await http.get(
        Uri.parse(
            "${AppConfig.baseURLReport}user-wise-outstanding-report?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body)["data"];
      } else {
        print('print 33');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getOrderReport data ${e.toString()}");
      return null;
    }
    return null;
  }

  Future<AccountLEadgerDetailReportModal?>
      getPartyWiseOutStandingDetailReportPayable(
          context, toDate, vouchDt, bookCd, partyCd) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    // var queryString =
    //     "toDate=$toDate&type=full&bookCd=$bookCd&vouchDt=${vouchDt.split("-")[2]}-${vouchDt.split("-")[1]}-${vouchDt.split("-")[0]}&partyCd=$partyCd";
    var queryString =
        "toDate=$toDate&type=full&bookCd=$bookCd&vouchDt=$vouchDt&partyCd=$partyCd";

    try {
      final http.Response response = await http.get(
        Uri.parse(
            "${AppConfig.baseURLReport}party-outstanding-payable-report?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print(
          "${AppConfig.baseURLReport}party-outstanding-payable-report?$queryString");
      print(response.body);
      if (response.statusCode == 200) {
        return accountLEadgerDetailReportModalFromJson(response.body);
      } else {
        print('print 34');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print(
          "Error in Services getOutStandingDetailReport data ${e.toString()}");
    }
    return null;
  }

  Future<AccountLEadgerDetailReportModal?>
      getPartyWiseOutStandingReceivableDetailReport(
          context, toDate, vouchDt, bookCd, partyCd) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    // var queryString =
    //     "toDate=$toDate&type=full&bookCd=$bookCd&vouchDt=${vouchDt.split("-")[2]}-${vouchDt.split("-")[1]}-${vouchDt.split("-")[0]}&partyCd=$partyCd";

    try {
      var queryString =
          "toDate=$toDate&type=full&bookCd=$bookCd&vouchDt=$vouchDt&partyCd=$partyCd";
      final http.Response response = await http.get(
        Uri.parse(
            "${AppConfig.baseURLReport}party-outstanding-receivable-report?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print(
          "${AppConfig.baseURLReport}party-outstanding-receivable-report?$queryString");
      print(response.body);
      if (response.statusCode == 200) {
        return accountLEadgerDetailReportModalFromJson(response.body);
      } else {
        print('print 35');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print(
          "Error in Services getOutStandingDetailReport data ${e.toString()}");
    }
    return null;
  }

  Future<AccountLEadgerDetailReportModal?>
      getPartyWiseOutStandingPayableDetailReport(
          context, toDate, vouchDt, bookCd, partyCd) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    // var queryString =
    //     "toDate=$toDate&type=full&bookCd=$bookCd&vouchDt=${vouchDt.split("-")[2]}-${vouchDt.split("-")[1]}-${vouchDt.split("-")[0]}&partyCd=$partyCd";

    var queryString =
        "toDate=$toDate&type=full&bookCd=$bookCd&vouchDt=$vouchDt&partyCd=$partyCd";

    try {
      final http.Response response = await http.get(
        Uri.parse(
            "${AppConfig.baseURLReport}party-outstanding-payable-report?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print(
          "${AppConfig.baseURLReport}party-outstanding-payable-report?$queryString");
      print(response.body);
      if (response.statusCode == 200) {
        return accountLEadgerDetailReportModalFromJson(response.body);
      } else {
        print('print 36');

        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print(
          "Error in Services getOutStandingDetailReport data ${e.toString()}");
    }
    return null;
  }

  Future<AccountLEadgerBillWiseDetailReportModal?>
      getPartyWiseOutStandingBillWiseDetailReportPayable(
          context, toDate, partycd, vouchDt, bookCd, vouchNo) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    // var queryString =
    //     "toDate=$toDate&type=full&bookCd=$bookCd&vouchDt=${vouchDt.split("-")[2]}-${vouchDt.split("-")[1]}-${vouchDt.split("-")[0]}&partyCd=$partycd&vouchNo=$vouchNo";
    var queryString =
        "toDate=$toDate&type=full&bookCd=$bookCd&vouchDt=$vouchDt&partyCd=$partycd&vouchNo=$vouchNo";

    try {
      final http.Response response = await http.get(
        Uri.parse(
            "${AppConfig.baseURLReport}party-outstanding-payable-report?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print(
          "${AppConfig.baseURLReport}party-outstanding-payable-report?$queryString");
      print(response.body);
      if (response.statusCode == 200) {
        return accountLEadgerBillWiseDetailReportModalFromJson(response.body);
      } else {
        print('print 37');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print(
          "Error in Services getAccountLeagerDetailReport data ${e.toString()}");
    }
    return null;
  }

  Future<AccountLEadgerBillWiseDetailReportModal?>
      getPartyWiseOutStandingBillWiseReceivableDetailReport(
          context, toDate, partycd, vouchDt, bookCd, vouchNo) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    // var queryString =
    //     "toDate=$toDate&type=full&bookCd=$bookCd&vouchDt=${vouchDt.split("-")[2]}-${vouchDt.split("-")[1]}-${vouchDt.split("-")[0]}&partyCd=$partycd&vouchNo=$vouchNo";

    var queryString =
        "toDate=$toDate&type=full&bookCd=$bookCd&vouchDt=$vouchDt&partyCd=$partycd&vouchNo=$vouchNo";

    try {
      final http.Response response = await http.get(
        Uri.parse(
            "${AppConfig.baseURLReport}party-outstanding-receivable-report?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print(
          "${AppConfig.baseURLReport}party-outstanding-receivable-report?$queryString");
      print(response.body);
      if (response.statusCode == 200) {
        return accountLEadgerBillWiseDetailReportModalFromJson(response.body);
      } else {
        print('print 38');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print(
          "Error in Services getAccountLeagerDetailReport data ${e.toString()}");
    }
    return null;
  }

  Future<AccountLEadgerBillWiseDetailReportModal?>
      getPartyWiseOutStandingBillWisePayableDetailReport(
          context, toDate, partycd, vouchDt, bookCd, vouchNo) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    // var queryString =
    //     "toDate=$toDate&type=full&bookCd=$bookCd&vouchDt=${vouchDt.split("-")[2]}-${vouchDt.split("-")[1]}-${vouchDt.split("-")[0]}&partyCd=$partycd&vouchNo=$vouchNo";

    var queryString =
        "toDate=$toDate&type=full&bookCd=$bookCd&vouchDt=$vouchDt&partyCd=$partycd&vouchNo=$vouchNo";

    try {
      final http.Response response = await http.get(
        Uri.parse(
            "${AppConfig.baseURLReport}party-outstanding-payable-report?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print(
          "${AppConfig.baseURLReport}party-outstanding-payable-report?$queryString");
      print(response.body);
      if (response.statusCode == 200) {
        return accountLEadgerBillWiseDetailReportModalFromJson(response.body);
      } else {
        print('print 39');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print(
          "Error in Services getAccountLeagerDetailReport data ${e.toString()}");
    }
    return null;
  }

  Future<PartyWiseOutstandingReportModal?> getPartyWiseOutStandingReportPayable(
      context, toDate, partyCd) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    var queryString = "toDate=$toDate";

    if (partyCd != null) {
      queryString = "$queryString&partyCd=$partyCd";
    }

    try {
      final http.Response response = await http.get(
        Uri.parse(
            "${AppConfig.baseURLReport}party-outstanding-payable-report?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print(
          "${AppConfig.baseURLReport}party-outstanding-payable-report?$queryString");
      print("API Data ${response.body}");

      if (response.statusCode == 200) {
        return PartyWiseOutstandingReportModalFromJson(response.body);
      } else {
        print('print 40');
        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getOutStandingReport data ${e.toString()}");
    }
    return null;
  }

  Future<PartyWiseOutstandingReportModal?>
      getPartyWiseOutStandingReceivableReport(context, toDate, partyCd) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    var queryString = "toDate=$toDate";

    if (partyCd != null) {
      queryString = "$queryString&partyCd=$partyCd";
    }

    try {
      final http.Response response = await http.get(
        Uri.parse(
            "${AppConfig.baseURLReport}party-outstanding-receivable-report?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print(
          "${AppConfig.baseURLReport}party-outstanding-receivable-report?$queryString");
      print("API Data ${response.body}");

      if (response.statusCode == 200) {
        return PartyWiseOutstandingReportModalFromJson(response.body);
      } else {
        print('print 41');

        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getOutStandingReport data ${e.toString()}");
    }
    return null;
  }

  Future<ReceiptConfirmModel?> getReceiptReceivableConfirm1(context) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    try {
      final http.Response response = await http.get(
        Uri.parse("${AppConfig.baseURL}receipt-entry"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print(response.statusCode);
      print("${AppConfig.baseURL}receipt-entry");
      print(response.body);

      if (response.statusCode == 200) {
        return ReceiptConfirmModelFromJson(response.body);
      } else {
        print('unauthorized');
        print('print 42');

        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
    }
    return null;
  }

  Future<ReceiptConfirmModel?> getReceiptReceivableConfirm(
      BuildContext context, fromDt, toDt, isValid, partyCd, userCd) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    try {
      // Start with an empty query string
      String queryString = '';

      // Add parameters conditionally if they are not null
      if (fromDt != null) {
        queryString += '&fromDate=$fromDt';
      }
      if (toDt != null) {
        queryString += '&toDate=$toDt';
      }
      if (isValid != null) {
        queryString += '&isValid=$isValid';
      }
      if (partyCd != null) {
        queryString += '&partyCd=$partyCd';
      }
      if (userCd != null) {
        queryString += '&userCd=$userCd';
      }

      // Construct the full URL with query parameters
      final url = Uri.parse(
          "${AppConfig.baseURL}receipt-entry${queryString.isNotEmpty ? "?$queryString" : ""}");

      final http.Response response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print(response.statusCode);
      print(url.toString()); // Print the full URL
      print(response.body);

      if (response.statusCode == 200) {
        return ReceiptConfirmModelFromJson(response.body);
      } else {
        print('Unauthorized');
        print('print 43');

        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
    }
    return null;
  }

  Future<ReceiptConfirmModel?> getPaymentPayableConfirm1(context) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    try {
      final http.Response response = await http.get(
        Uri.parse("${AppConfig.baseURL}payment-entry"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print(response.statusCode);
      print(response.body);

      if (response.statusCode == 200) {
        return ReceiptConfirmModelFromJson(response.body);
      } else {
        print('unauthorized');
        print('print 44');

        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
    }
    return null;
  }

  Future<ReceiptConfirmModel?> getPaymentPayableConfirm(
      BuildContext context, fromDt, toDt, isValid, partyCd, userCd) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    try {
      // Start with an empty query string
      String queryString = '';

      // Add parameters conditionally if they are not null
      if (fromDt != null) {
        queryString += '&fromDate=$fromDt';
      }
      if (toDt != null) {
        queryString += '&toDate=$toDt';
      }
      if (isValid != null) {
        queryString += '&isValid=$isValid';
      }
      if (partyCd != null) {
        queryString += '&partyCd=$partyCd';
      }
      if (userCd != null) {
        queryString += '&userCd=$userCd';
      }

      // Construct the full URL with query parameters
      final url = Uri.parse(
          "${AppConfig.baseURL}payment-entry${queryString.isNotEmpty ? "?$queryString" : ""}");

      final http.Response response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print(response.statusCode);
      print(url.toString()); // Print the full URL
      print(response.body);

      if (response.statusCode == 200) {
        return ReceiptConfirmModelFromJson(response.body);
      } else {
        print('unauthorized');
        print('print 45');

        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
    }
    return null;
  }

  Future<PartyWiseOutstandingReportModal?> getPartyWiseOutStandingPayableReport(
      context, toDate, partyCd) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    var queryString = "toDate=$toDate";

    if (partyCd != null) {
      queryString = "$queryString&partyCd=$partyCd";
    }

    try {
      final http.Response response = await http.get(
        Uri.parse(
            "${AppConfig.baseURLReport}party-outstanding-payable-report?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print(
          "${AppConfig.baseURLReport}party-outstanding-payable-report?$queryString");
      print("API Data ${response.body}");

      if (response.statusCode == 200) {
        return PartyWiseOutstandingReportModalFromJson(response.body);
      } else {
        print('print 46');

        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getOutStandingReport data ${e.toString()}");
    }
    return null;
  }

  Future<String?> getPartyWiseOutStandingExportFileReceivable(
      context, toDate, partyCd, type) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    var queryString =
        "toDate=${Helper.toApi(toDate)}&export=true&exportType=$type";

    if (partyCd != null) {
      queryString = "$queryString&partyCd=$partyCd";
    }

    try {
      final http.Response response = await http.get(
        Uri.parse(
            "${AppConfig.baseURLReport}party-outstanding-receivable-report?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body)["data"];
      } else {
        print('print 47');

        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getOrderReport data ${e.toString()}");
      return null;
    }
    return null;
  }

  Future<String?> getPartyWiseOutStandingExportFilePayble(
      context, toDate, partyCd, type) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    var queryString =
        "toDate=${Helper.toApi(toDate)}&export=true&exportType=$type";

    if (partyCd != null) {
      queryString = "$queryString&partyCd=$partyCd";
    }

    try {
      final http.Response response = await http.get(
        Uri.parse(
            "${AppConfig.baseURLReport}party-outstanding-payable-report?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body)["data"];
      } else {
        print('print 48');

        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getOrderReport data ${e.toString()}");
      return null;
    }
    return null;
  }

  Future<String?> getPartyWiseOutStandingExportFile(
      context, toDate, partyCd, type) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    var queryString =
        "toDate=${Helper.toApi(toDate)}&export=true&exportType=$type";

    if (partyCd != null) {
      queryString = "$queryString&partyCd=$partyCd";
    }

    try {
      final http.Response response = await http.get(
        Uri.parse(
            "${AppConfig.baseURLReport}party-outstanding-report?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body)["data"];
      } else {
        print('print 49');

        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getOrderReport data ${e.toString()}");
      return null;
    }
    return null;
  }

  Future<ItemWiseReportModal?> getItemWiseSaleReport(
      context, fromDate, toDate, itemCd, deptCd) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    var queryString = "fromDate=$fromDate&toDate=$toDate";

    if (itemCd != null) {
      queryString = "$queryString&itemCd=$itemCd";
    }

    if (deptCd != null) {
      queryString = "$queryString&deptCd=$deptCd";
    }

    print(ub.token);
    try {
      final http.Response response = await http.get(
        Uri.parse("${AppConfig.baseURLReport}items-wise-report?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print(response.body);
      if (response.statusCode == 200) {
        return itemWiseReportModalFromJson(response.body);
      } else {
        print('print 50');

        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getItemWiseReport data ${e.toString()}");
    }
    return null;
  }

  Future<String?> getItemWiseSaleExportFile(
      context, fromDate, toDate, itemCd, deptCd, type) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    var queryString =
        "fromDate=${Helper.toApi(fromDate)}&toDate=${Helper.toApi(toDate)}&export=true&exportType=$type";

    if (itemCd != null) {
      queryString = "$queryString&itemCd=$itemCd";
    }

    if (deptCd != null) {
      queryString = "$queryString&deptCd=$deptCd";
    }

    try {
      final http.Response response = await http.get(
        Uri.parse("${AppConfig.baseURLReport}items-wise-report?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print(Uri.parse(
          "${AppConfig.baseURLReport}items-wise-report?$queryString"));

      if (response.statusCode == 200) {
        return json.decode(response.body)["data"];
      } else {
        print('print 51');

        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getOrderReport data ${e.toString()}");
      return null;
    }
    return null;
  }

  Future<ItemWiseDetailReportModal?> getItemWiseSaleDetailReport(
      context, fromDate, toDate, itemCd) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    var queryString = "fromDate=$fromDate&toDate=$toDate&type=full";

    if (itemCd != null) {
      queryString = "$queryString&itemCd=$itemCd";
    }

    print(ub.token);
    try {
      final http.Response response = await http.get(
        Uri.parse("${AppConfig.baseURLReport}items-wise-report?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print(response.body);
      if (response.statusCode == 200) {
        return itemWiseDetailReportModalFromJson(response.body);
      } else {
        print('print 52');

        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getItemWiseReport data ${e.toString()}");
    }
    return null;
  }

  Future<PartyWiseReportModal?> getPartyWiseReport(
      context, fromDate, toDate, partyCd) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    var queryString = "fromDate=$fromDate&toDate=$toDate";

    if (partyCd != null) {
      queryString = "$queryString&partyCd=$partyCd";
    }

    print(ub.token);
    try {
      final http.Response response = await http.get(
        Uri.parse("${AppConfig.baseURLReport}party-wise-report?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print("${AppConfig.baseURLReport}party-wise-report?$queryString");
      print(response.body);
      if (response.statusCode == 200) {
        return partyWiseReportModalFromJson(response.body);
      } else {
        print('print 53');

        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getPartyWiseReport data ${e.toString()}");
    }
    return null;
  }

  Future<String?> getPartyWiseExportFile(
      context, fromDate, toDate, partyCd, type) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    var queryString =
        "fromDate=${Helper.toApi(fromDate)}&toDate=${Helper.toApi(toDate)}&export=true&exportType=$type";

    if (partyCd != null) {
      queryString = "$queryString&partyCd=$partyCd";
    }
    try {
      final http.Response response = await http.get(
        Uri.parse("${AppConfig.baseURLReport}party-wise-report?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body)["data"];
      } else {
        print('print 54');

        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getOrderReport data ${e.toString()}");
      return null;
    }
    return null;
  }

  Future<PartyWiseDetailReportModal?> getPartyWiseDetailReport(
      context, fromDate, toDate, partyCd) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    var queryString = "fromDate=$fromDate&toDate=$toDate&type=full";

    if (partyCd != null) {
      queryString = "$queryString&partyCd=$partyCd";
    }
    print(ub.token);
    try {
      final http.Response response = await http.get(
        Uri.parse("${AppConfig.baseURLReport}party-wise-report?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print(response.body);
      if (response.statusCode == 200) {
        return partyWiseDetailReportModalFromJson(response.body);
      } else {
        print('print 55');

        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getPartyWiseDetailReport data ${e.toString()}");
    }
    return null;
  }

  Future<PartyWiseItemWiseSaleReportModal?> getPartyWiseItemSaleReport(
      context, fromdate, toDate, partyCd, deptCd) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    var queryString = "fromDate=$fromdate&toDate=$toDate&partyCd=$partyCd";

    if (deptCd != null) {
      queryString = "$queryString&deptCd=$deptCd";
    }

    try {
      final http.Response response = await http.get(
        Uri.parse(
            "${AppConfig.baseURLReport}party-wise-item-sale-report?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print(
          "${AppConfig.baseURLReport}party-wise-item-sale-report?$queryString");
      print("Bearer ${ub.token}");
      print(response.body);
      if (response.statusCode == 200) {
        return partyWiseItemWiseSaleReportModalFromJson(response.body);
      } else {
        print('print 56');

        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print(
          "Error in Services getPartyWiseItemSaleReport data ${e.toString()}");
    }
    return null;
  }

  Future<PartyWiseItemWiseSaleReportModal?> getPartyWiseItemPurchaseReport(
      context, fromdate, toDate, partyCd, deptCd) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    var queryString = "fromDate=$fromdate&toDate=$toDate&partyCd=$partyCd";

    if (deptCd != null) {
      queryString = "$queryString&deptCd=$deptCd";
    }

    try {
      final http.Response response = await http.get(
        Uri.parse(
            "${AppConfig.baseURLReport}party-wise-item-purchase-report?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print(
          "${AppConfig.baseURLReport}party-wise-item-purchase-report?$queryString");
      print("Bearer ${ub.token}");
      print(response.body);
      if (response.statusCode == 200) {
        return partyWiseItemWiseSaleReportModalFromJson(response.body);
      } else {
        print('print 56_1');

        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print(
          "Error in Services getPartyWiseItemPurchaseReport data ${e.toString()}");
    }
    return null;
  }

  Future<String?> getPartyWiseItemExportFile(
      context, fromdate, toDate, partyCd, deptCd, type) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    var queryString =
        "fromDate=${Helper.toApi(fromdate)}&toDate=${Helper.toApi(toDate)}&partyCd=$partyCd&export=true&exportType=$type";

    if (deptCd != null) {
      queryString = "$queryString&deptCd=$deptCd";
    }

    try {
      final http.Response response = await http.get(
        Uri.parse(
            "${AppConfig.baseURLReport}party-wise-item-sale-report?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print(Uri.parse(
          "${AppConfig.baseURLReport}party-wise-item-sale-report?$queryString"));

      if (response.statusCode == 200) {
        return json.decode(response.body)["data"];
      } else {
        print('print 57');

        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getOrderReport data ${e.toString()}");
      return null;
    }
    return null;
  }

  Future<String?> getPartyWiseItemExportPurchaseFile(
      context, fromdate, toDate, partyCd, deptCd, type) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    var queryString =
        "fromDate=$fromdate&toDate=$toDate&partyCd=$partyCd&export=true&exportType=$type";

    if (deptCd != null) {
      queryString = "$queryString&deptCd=$deptCd";
    }
    try {
      final http.Response response = await http.get(
        Uri.parse(
            "${AppConfig.baseURLReport}party-wise-item-purchase-report?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body)["data"];
      } else {
        print('print 57_1');

        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print(
          "Error in Services party wise iem wise purchase export report data ${e.toString()}");
      return null;
    }
    return null;
  }

  Future<PartyWiseItemWiseSaleDetailReportModal?>
      getPartyWiseItemSaleDetailReport(
          context, fromdate, toDate, partyCd, deptCd, itemCd) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    var queryString =
        "fromDate=$fromdate&toDate=$toDate&partyCd=$partyCd&itemCd=$itemCd&type=full";

    if (deptCd != null) {
      queryString = "$queryString&deptCd=$deptCd";
    }

    print(ub.token);
    try {
      final http.Response response = await http.get(
        Uri.parse(
            "${AppConfig.baseURLReport}party-wise-item-sale-report?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print(
          "${AppConfig.baseURLReport}party-wise-item-sale-report?$queryString");
      print(response.body);
      if (response.statusCode == 200) {
        return partyWiseItemWiseSaleDetailReportModalFromJson(response.body);
      } else {
        print('print 58');

        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print(
          "Error in Services getPartyWiseItemSaleDetailReport data ${e.toString()}");
    }
    return null;
  }

  Future<PartyWiseItemWiseSaleDetailReportModal?>
      getPartyWiseItemPurchaseDetailReport(
          context, fromdate, toDate, partyCd, deptCd, itemCd) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    var queryString =
        "fromDate=$fromdate&toDate=$toDate&partyCd=$partyCd&itemCd=$itemCd&type=full";

    if (deptCd != null) {
      queryString = "$queryString&deptCd=$deptCd";
    }

    print(ub.token);
    try {
      final http.Response response = await http.get(
        Uri.parse(
            "${AppConfig.baseURLReport}party-wise-item-purchase-report?$queryString"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print(response.body);
      if (response.statusCode == 200) {
        return partyWiseItemWiseSaleDetailReportModalFromJson(response.body);
      } else {
        print('print 58_1');

        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print(
          "Error in Services getPartyWiseItemSaleDetailReport data ${e.toString()}");
    }
    return null;
  }

  //Report Api Call End

  Future<SettingModal?> getSettings(context) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    // print(ub.token);
    // print("${AppConfig.baseURL}settings");
    try {
      final http.Response response = await http.get(
        Uri.parse("${AppConfig.baseURL}settings"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print(ub.token);
      print("[SERVICES] GET ${AppConfig.baseURL}settings");
      print("[SERVICES] ${response.body}");
      if (response.statusCode == 200) {
        return settingModalFromJson(response.body);
      } else {
        print('print 59');

        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getSettings data ${e.toString()}");
    }
    return null;
  }

  Future updateSetting(context, sid, val, amt) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    print(ub.token);
    try {
      Map<String, dynamic> payload = {
        "sId": sid,
        "value": val,
        "valueAmt": amt
      };

      final http.Response response =
          await http.post(Uri.parse("${AppConfig.baseURL}update-settings"),
              headers: {
                "Authorization": "Bearer ${ub.token}",
                'x-app-type': 'oms',
              },
              body: payload);

      print("Update Setting Body $payload");
      print(response.body);
      if (response.statusCode == 200) {
        //Fluttertoast.showToast(msg: "${json.decode(response.body)["message"]}");
        AppSnackBar.showGetXCustomSnackBar(
            message: "${json.decode(response.body)["message"]}",
            backgroundColor: Colors.green);
      } else {
        print('print 60');

        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services updateSetting data ${e.toString()}");
    }
  }

  Future deleteAccount(context) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    print(ub.token);
    try {
      final http.Response response = await http
          .post(Uri.parse("${AppConfig.baseURL}users/deactivate"), headers: {
        "Authorization": "Bearer ${ub.token}",
        'x-app-type': 'oms',
      }, body: {});
      print(response.body);
      if (response.statusCode == 200) {
        return true;
      } else {
        print('print 61');

        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services syncSetting  ${e.toString()}");
    }
  }

  Future syncSetting(context) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    print(ub.token);
    try {
      final http.Response response = await http.get(
        Uri.parse("${AppConfig.baseURL}settings/sync"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print(response.body);
      if (response.statusCode == 200) {
        return settingModalFromJson(response.body);
      } else {
        print('print 62');

        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services syncSetting  ${e.toString()}");
    }
  }

  Future<ModulesModal?> getModules(context) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    print(ub.token);
    try {
      final http.Response response = await http.get(
        Uri.parse("${AppConfig.baseURL}users/modules"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print("${AppConfig.baseURL}users/modules");
      print("Bearer ${ub.token}");
      print(response.body);
      if (response.statusCode == 200) {
        // Fluttertoast.showToast(msg: "${json.decode(response.body)["message"]}");
        return modulesModalFromJson(response.body);
      } else {
        print('print 63');
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getUtlity data ${e.toString()}");
    }
    return null;
  }

  Future<UtlityModal?> getUtlity(context) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    print('Token Temp : ${ub.token}');
    try {
      final http.Response response = await http.get(
        Uri.parse("${AppConfig.baseURL}utils"),
        headers: {
          'x-app-type': 'oms',
        },
      );
      print("${AppConfig.baseURL}utils");
      print(response.body);
      if (response.statusCode == 200) {
        // Fluttertoast.showToast(msg: "${json.decode(response.body)["message"]}");
        ub.changeShowSignUp(utlityModalFromJson(response.body).data.isSignUp);
        return utlityModalFromJson(response.body);
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getUtlity data ${e.toString()}");
    }
    return null;
  }

  Future<List<DatumNarration>?> getNarration(
      context, String narrationType) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    print(ub.token);
    try {
      final http.Response response = await http.get(
        Uri.parse(
            "${AppConfig.baseURL}master-entry/narration?narrType=$narrationType"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print(
          "Narration URL: ${AppConfig.baseURL}master-entry/narration?narrType=$narrationType");
      print("Narration API: ${response.body}");
      if (response.statusCode == 200) {
        return narrationModalFromJson(response.body).data;
      } else {
        //Fazal Add 23-03-2025
        // ub.userSignout(context).then((value) {
        //   Get.offAll(() => LoginPage());
        // });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getNarration data ${e.toString()}");
    }
    return null;
  }

  Future<String?> getProductExportFile(context, search, deptCd) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    var query = "export=true&exportType=pdf";
    if (search != null && search != "") {
      query = "$query&search=${Uri.encodeComponent(search)}";
    }
    if (deptCd != null) {
      query = "$query&deptCd=$deptCd";
    }

    try {
      final http.Response response = await http.get(
        Uri.parse("${AppConfig.baseURL}products?$query"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );

      print("${AppConfig.baseURL}products?$query");
      print("Bearer ${ub.token}");
      print(response.body);

      if (response.statusCode == 200) {
        return json.decode(response.body)["data"];
      } else {
        print('print 65');

        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getOrderReport data ${e.toString()}");
      return null;
    }
    return null;
  }

  Future<String?> getPartyExportFile(context) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    var query = "export=true&exportType=pdf";

    try {
      final http.Response response = await http.get(
        Uri.parse("${AppConfig.baseURL}products/party?$query"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );
      print("${AppConfig.baseURL}products/party?$query");
      print(response.body);
      print(response.statusCode == 200);

      if (response.statusCode == 200) {
        return json.decode(response.body)["data"];
      } else {
        print('print 66');

        ub.userSignout(context).then((value) {
          Get.offAll(() => LoginPage());
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: "Something went wrong");
      //Fluttertoast.showToast(msg: "Something went wrong");
      print("Error in Services getPartyExportFile data ${e.toString()}");
      return null;
    }
    return null;
  }

  void logout(context) async {
    try {
      // Since context may be deactivated during logout, we need to handle this carefully
      UserProvider? ub;
      try {
        ub = Provider.of<UserProvider>(context, listen: false);
      } catch (e) {
        print(
            '[Services] ⚠️ Could not access UserProvider from context during logout: $e');
        print(
            '[Services] Skipping server logout API call (context deactivated)');
        return;
      }

      final token = ub.token;
      if (token == null || token.isEmpty) {
        print('[Services] No token available for logout API call');
        return;
      }

      print('[Services] 📡 Calling logout API...');
      final http.Response response = await http.post(
        Uri.parse("${AppConfig.baseURL}logout"),
        headers: {
          "Authorization": "Bearer $token",
          'x-app-type': 'oms',
        },
      ).timeout(const Duration(seconds: 5));

      print("Response : ${response.body}");
      if (response.statusCode == 200) {
        print('[Services] ✅ Logout API successful');
        return json.decode(response.body);
      }
    } catch (e) {
      print('[Services] ⚠️ Error in logout API call: $e');
      // Don't record this error to Crashlytics since context is deactivated
      // and this is expected during logout
    }
  }

  Future<void> logoutWithToken(String? token) async {
    try {
      if (token == null || token.isEmpty) {
        print('[Services] No token available for logout API call');
        return;
      }

      print('[Services] 📡 Calling logout API (token mode)...');
      final http.Response response = await http.post(
        Uri.parse("${AppConfig.baseURL}logout"),
        headers: {
          "Authorization": "Bearer $token",
          'x-app-type': 'oms',
        },
      ).timeout(const Duration(seconds: 5));

      print(
          '[Services] Logout(token) status=${response.statusCode} body=${response.body}');
    } catch (e) {
      print('[Services] ⚠️ Error in logout(token) API call: $e');
    }
  }

  /// Fetch current punch state from server using /orders-tracking API
  /// Returns the outer 'remark' field which indicates "PUNCH IN" or "PUNCH OUT"
  Future<String?> getCurrentPunchState(String token) async {
    if (token.isEmpty) {
      print('[Services] 🔐 [PUNCH_STATE] Token is missing');
      return null;
    }

    try {
      print(
          '[Services] 📡 [PUNCH_STATE] Fetching current punch state from /orders-tracking');
      final http.Response response = await http.get(
        Uri.parse("${AppConfig.baseURL}orders-tracking"),
        headers: {
          "Authorization": "Bearer $token",
          'x-app-type': 'oms',
        },
      ).timeout(const Duration(seconds: 10));
      print("[SERVICES] GET ${AppConfig.baseURL}orders-tracking");
      print(
          '[Services] 📥 [PUNCH_STATE] Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final outerRemark = decoded['remark']?.toString() ?? '';

        print('[Services] 📋 [PUNCH_STATE] Full Response: ${response.body}');
        print('[Services] ✅ [PUNCH_STATE] Outer remark: "$outerRemark"');

        return outerRemark;
      } else {
        print(
            '[Services] ❌ [PUNCH_STATE] API returned status ${response.statusCode}');
        return null;
      }
    } catch (e, stack) {
      print('[Services] ❌ [PUNCH_STATE] Exception: $e');
      CrashlyticsService.recordNonFatal(e, stack);
      return null;
    }
  }

  /// Get active trip status for a user
  /// Returns trip details if active trip exists, null otherwise
  Future<Map<String, dynamic>?> getActiveTripStatus(
      String userCd, int syncId, String token) async {
    if (token.isEmpty || userCd.isEmpty) {
      print('[Services] [TRIP_STATUS] Invalid parameters: userCd=$userCd');
      return null;
    }

    Map<String, dynamic>? normalizeTrip(dynamic rawTrip) {
      if (rawTrip is! Map) {
        return null;
      }

      final rawTripId =
          rawTrip['trip_id'] ?? rawTrip['tripId'] ?? rawTrip['id'];
      int? tripId;
      if (rawTripId is int) {
        tripId = rawTripId;
      } else if (rawTripId is String) {
        tripId = int.tryParse(rawTripId);
      }

      if (tripId == null || tripId <= 0) {
        return null;
      }

      final rawStatus = (rawTrip['status'] ??
              rawTrip['trip_status'] ??
              rawTrip['tripStatus'] ??
              '')
          .toString()
          .toLowerCase();

      if (rawStatus.isNotEmpty &&
          rawStatus != 'active' &&
          rawStatus != 'paused' &&
          rawStatus != 'started' &&
          rawStatus != 'in_progress' &&
          rawStatus != 'ongoing') {
        return null;
      }

      final rawSyncId = rawTrip['sync_id'] ?? rawTrip['syncId'];
      int? parsedSyncId;
      if (rawSyncId is int) {
        parsedSyncId = rawSyncId;
      } else if (rawSyncId is String) {
        parsedSyncId = int.tryParse(rawSyncId);
      }

      return {
        'trip_id': tripId,
        'user_cd': rawTrip['user_cd'] ?? rawTrip['userCd'] ?? userCd,
        'sync_id': parsedSyncId ?? syncId,
        'start_time': rawTrip['start_time'] ?? rawTrip['startTime'],
        'trip_name': rawTrip['trip_name'] ?? rawTrip['tripName'],
        'status': rawTrip['status'] ?? 'active',
      };
    }

    Map<String, dynamic>? extractActiveTrip(dynamic decodedBody) {
      if (decodedBody is! Map) {
        return null;
      }

      final candidates = <dynamic>[
        decodedBody['trip'],
        decodedBody['data'],
        decodedBody['result'],
      ];

      final dataNode = decodedBody['data'];
      if (dataNode is Map) {
        candidates.add(dataNode['trip']);
        candidates.add(dataNode['active_trip']);
      }

      for (final candidate in candidates) {
        final normalized = normalizeTrip(candidate);
        if (normalized != null) {
          return normalized;
        }
      }

      return null;
    }

    Future<http.Response?> fetchTripStatus({required bool includeSync}) async {
      final uri = includeSync && syncId > 0
          ? Uri.parse(
              '${AppConfig.baseURL}location/trip/status?user_cd=$userCd&sync_id=$syncId')
          : Uri.parse(
              '${AppConfig.baseURL}location/trip/status?user_cd=$userCd');

      return http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'x-app-type': 'oms',
        },
      ).timeout(const Duration(seconds: 10));
    }

    try {
      print('[Services] [TRIP_STATUS] Fetching active trip status...');
      print('[Services] [TRIP_STATUS] UserCd=$userCd, SyncId=$syncId');

      final response = await fetchTripStatus(includeSync: true);
      if (response == null) {
        return null;
      }

      print('[Services] [TRIP_STATUS] Response: ${response.statusCode}');
      print('[Services] [TRIP_STATUS] Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final activeTrip = extractActiveTrip(decoded);

        if (activeTrip != null) {
          print('[Services] [TRIP_STATUS] ✅ Found active trip:');
          print('[Services] [TRIP_STATUS]   trip_id=${activeTrip['trip_id']}');
          return activeTrip;
        }

        print(
            '[Services] [TRIP_STATUS] No active trip in sync-filtered response');
      }

      if (syncId > 0) {
        print(
            '[Services] [TRIP_STATUS] Retrying without sync_id filter for resilience...');
        final fallbackResponse = await fetchTripStatus(includeSync: false);

        if (fallbackResponse != null) {
          print(
              '[Services] [TRIP_STATUS] Fallback response: ${fallbackResponse.statusCode}');
          print(
              '[Services] [TRIP_STATUS] Fallback body: ${fallbackResponse.body}');

          if (fallbackResponse.statusCode == 200) {
            final fallbackDecoded = json.decode(fallbackResponse.body);
            final fallbackTrip = extractActiveTrip(fallbackDecoded);

            if (fallbackTrip != null) {
              print('[Services] [TRIP_STATUS] ✅ Found active trip (fallback):');
              print(
                  '[Services] [TRIP_STATUS]   trip_id=${fallbackTrip['trip_id']}');
              return fallbackTrip;
            }
          }
        }
      }

      print('[Services] [TRIP_STATUS] No active trip found');
      return null;
    } catch (e, stack) {
      print('[Services] [TRIP_STATUS] Exception: $e');
      CrashlyticsService.recordNonFatal(e, stack);
      return null;
    }
  }

  Future finalReceivableReceiptPaymentQuickSave(
      BuildContext context,
      String date,
      String time,
      String cashBnkCd,
      String party,
      num amount,
      String checkNo,
      String remarks,
      String type,
      String bookCd,
      List<Map<String, dynamic>> billWise) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    // Prepare payload with the required fields
    Map<String, dynamic> payload = {
      "vouchDt": date,
      //"time": time,
      "cashBnkCd": cashBnkCd,
      "party": party,
      "amount": amount,
      "cheqNo": checkNo,
      "remarks": remarks,
      "type": type,
      //"bookCd": bookCd,
      "billWise": billWise,
      "moduleNo": "214"
    };

    print(payload);

    try {
      // Make HTTP POST request
      final http.Response response = await http.post(
        Uri.parse("${AppConfig.baseURL}receipt-entry"),
        body: json.encode(payload),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'Content-Type': 'application/json; charset=UTF-8',
          "x-app-type": "oms"
        },
      );

      // Handle response

      print("${AppConfig.baseURL}receipt-entry");
      print("Bearer ${ub.token}");
      print(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("success : ${response.statusCode}${response.body}");
        // Fluttertoast.showToast(
        //   msg: json.decode(response.body)["message"],
        // );
        AppSnackBar.showGetXCustomSnackBar(
            message: json.decode(response.body)["message"],
            backgroundColor: Colors.green);
        return true;
      } else {
        print("Fail : ${response.statusCode} ${response.body}");
        // Fluttertoast.showToast(
        //   msg: json.decode(response.body)["message"],
        // );
        AppSnackBar.showGetXCustomSnackBar(
            message: json.decode(response.body)["message"]);
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      //Fluttertoast.showToast(msg: "Something went wrong for firmId: $e");
      AppSnackBar.showGetXCustomSnackBar(
          message: "Something went wrong for firmId: $e");
    }
  }

  Future finalPayableReceiptPaymentQuickSave(
      BuildContext context,
      String date,
      String time,
      String cashBnkCd,
      String party,
      num amount,
      String checkNo,
      String remarks,
      String type,
      String bookCd,
      List<Map<String, dynamic>> billWise) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    // Prepare payload with the required fields
    Map<String, dynamic> payload = {
      "vouchDt": date,
      //"time": time,
      "cashBnkCd": cashBnkCd,
      "party": party,
      "amount": amount,
      "cheqNo": checkNo,
      "remarks": remarks,
      "type": type,
      //"bookCd": bookCd,
      "billWise": billWise,
      "moduleNo": "215"
    };

    print(payload);

    try {
      // Make HTTP POST request
      final http.Response response = await http.post(
        Uri.parse("${AppConfig.baseURL}payment-entry"),
        body: json.encode(payload),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'Content-Type': 'application/json; charset=UTF-8',
          "x-app-type": "oms"
        },
      );

      // Handle response
      print(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        print("success : ${response.statusCode}${response.body}");
        //Fluttertoast.showToast(msg: json.decode(response.body)["message"]);
        AppSnackBar.showGetXCustomSnackBar(
            message: json.decode(response.body)["message"],
            backgroundColor: Colors.green);
        return true;
      } else {
        print("Fail : ${response.statusCode} ${response.body}");
        //Fluttertoast.showToast(msg: json.decode(response.body)["message"]);
        AppSnackBar.showGetXCustomSnackBar(
          message: json.decode(response.body)["message"],
        );
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      //Fluttertoast.showToast(msg: "Something went wrong for firmId: $e");
      AppSnackBar.showGetXCustomSnackBar(
          message: "Something went wrong for firmId: $e");
    }
  }

  Future finalReceivableReceiptPaymentManuallySave(
      BuildContext context,
      String date,
      String time,
      String cashBnkCd,
      String party,
      num amount,
      String checkNo,
      String remarks,
      String type,
      String bookCd,
      List<Map<String, dynamic>> billWise) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    // Prepare payload with the required fields
    Map<String, dynamic> payload = {
      "vouchDt": date,
      //"time": time,
      "cashBnkCd": cashBnkCd,
      "party": party,
      "amount": amount,
      "cheqNo": checkNo,
      "remarks": remarks,
      "type": type,
      //"bookCd": bookCd,
      "billWise": billWise,
      "moduleNo": "214"
    };

    try {
      // Make HTTP POST request
      final http.Response response = await http.post(
        Uri.parse("${AppConfig.baseURL}receipt-entry"),
        body: json.encode(payload),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'Content-Type': 'application/json; charset=UTF-8',
          "x-app-type": "oms"
        },
      );

      print("${AppConfig.baseURL}receipt-entry");
      print(payload);

      // Handle response

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("success : ${response.statusCode}${response.body}");
        //Fluttertoast.showToast(msg: json.decode(response.body)["message"]);
        AppSnackBar.showGetXCustomSnackBar(
            message: json.decode(response.body)["message"],
            backgroundColor: Colors.green);
        return true;
      } else {
        print("Fail : ${response.statusCode} ${response.body}");
        //Fluttertoast.showToast(msg: json.decode(response.body)["message"]);
        AppSnackBar.showGetXCustomSnackBar(
            message: json.decode(response.body)["message"]);
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      //Fluttertoast.showToast(msg: "Something went wrong for firmId: $e");
      AppSnackBar.showGetXCustomSnackBar(
          message: "Something went wrong for firmId: $e");
    }
  }

  Future finalPayableReceiptPaymentManuallySave(
      BuildContext context,
      String date,
      String time,
      String cashBnkCd,
      String party,
      num amount,
      String checkNo,
      String remarks,
      String type,
      String bookCd,
      List<Map<String, dynamic>> billWise) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    // Prepare payload with the required fields
    Map<String, dynamic> payload = {
      "vouchDt": date,
      //"time": time,
      "cashBnkCd": cashBnkCd,
      "party": party,
      "amount": amount,
      "cheqNo": checkNo,
      "remarks": remarks,
      "type": type,
      //"bookCd": bookCd,
      "billWise": billWise,
      "moduleNo": "215"
    };

    print(payload);

    try {
      // Make HTTP POST request
      final http.Response response = await http.post(
        Uri.parse("${AppConfig.baseURL}payment-entry"),
        body: json.encode(payload),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'Content-Type': 'application/json; charset=UTF-8',
          "x-app-type": "oms"
        },
      );

      // Handle response

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("success : ${response.statusCode}${response.body}");
        //Fluttertoast.showToast(msg: json.decode(response.body)["message"]);
        AppSnackBar.showGetXCustomSnackBar(
            message: json.decode(response.body)["message"],
            backgroundColor: Colors.green);
        return true;
      } else {
        print("Fail : ${response.statusCode} ${response.body}");
        //Fluttertoast.showToast(msg: json.decode(response.body)["message"]);
        AppSnackBar.showGetXCustomSnackBar(
            message: json.decode(response.body)["message"]);
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      //Fluttertoast.showToast(msg: "Something went wrong for firmId: $e");
      AppSnackBar.showGetXCustomSnackBar(
          message: "Something went wrong for firmId: $e");
    }
  }

  Future receiptPaymentValidateAPI(
      BuildContext context, List<Map<String, dynamic>> receipt) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    // Prepare payload with the required fields
    Map<String, dynamic> payload = {
      "receipt": receipt,
    };

    print(payload);

    try {
      // Make HTTP POST request
      final http.Response response = await http.post(
        Uri.parse("${AppConfig.baseURL}validate-receipt"),
        body: json.encode(payload),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'Content-Type': 'application/json; charset=UTF-8',
          "x-app-type": "oms"
        },
      );

      // Handle response

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("success : ${response.statusCode}${response.body}");
        //Fluttertoast.showToast(msg: json.decode(response.body)["message"]);
        AppSnackBar.showGetXCustomSnackBar(
            message: json.decode(response.body)["message"],
            backgroundColor: Colors.green);
        return true;
      } else {
        print("Fail : ${response.statusCode} ${response.body}");
        //Fluttertoast.showToast(msg: json.decode(response.body)["message"]);
        AppSnackBar.showGetXCustomSnackBar(
            message: json.decode(response.body)["message"]);
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      //Fluttertoast.showToast(msg: "Something went wrong for firmId: $e");
      AppSnackBar.showGetXCustomSnackBar(
          message: "Something went wrong for firmId: $e");
    }
  }

  Future paymentValidateAPI(
      BuildContext context, List<Map<String, dynamic>> receipt) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    // Prepare payload with the required fields
    Map<String, dynamic> payload = {
      "receipt": receipt,
    };

    print(payload);

    try {
      // Make HTTP POST request
      final http.Response response = await http.post(
        Uri.parse("${AppConfig.baseURL}validate-payment"),
        body: json.encode(payload),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'Content-Type': 'application/json; charset=UTF-8',
          "x-app-type": "oms"
        },
      );

      // Handle response

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("success : ${response.statusCode}${response.body}");
        //Fluttertoast.showToast(msg: json.decode(response.body)["message"]);
        AppSnackBar.showGetXCustomSnackBar(
            message: json.decode(response.body)["message"],
            backgroundColor: Colors.green);
        return true;
      } else {
        print("Fail : ${response.statusCode} ${response.body}");
        //Fluttertoast.showToast(msg: json.decode(response.body)["message"]);
        AppSnackBar.showGetXCustomSnackBar(
            message: json.decode(response.body)["message"]);
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatal(e, stack);
      //Fluttertoast.showToast(msg: "Something went wrong for firmId: $e");
      AppSnackBar.showGetXCustomSnackBar(
          message: "Something went wrong for firmId: $e");
    }
  }
}
