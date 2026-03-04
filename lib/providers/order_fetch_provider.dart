//import 'package:fluttertoast/fluttertoast.dart';
import 'dart:convert';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/disposable_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../constants/constants.dart';
import '../models/orderlistModal.dart';
import 'package:http/http.dart' as http;

import '../services/database_helper.dart';
import '../views/loginpage.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class OrderFetchProvider extends DisposableProvider {
  List<DatumOrderList> _data = [];
  List<DatumOrderList> get data => _data;
  bool nolist = false;

  final orderfetchHive = Hive.box<DatumOrderList>(Constants.orderFetch);

  Future getOrders(context) async {
    _data.clear();
    nolist = false;
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    bool result = await InternetConnectionChecker.instance.hasConnection;
    try {
      if (result == true) {
        final http.Response response = await http.get(
          Uri.parse(AppConfig.baseURL + "orders"),
          headers: {
            "Authorization": "Bearer ${ub.token}",
            'x-app-type': 'oms',
          },
        );
        print(response.body);
        if (response.statusCode == 200) {
          await orderfetchHive.clear();
          final serverOrders = orderlistModalFromJson(response.body).data;
          _data.addAll(serverOrders);
          await orderfetchHive.addAll(serverOrders);

          // Cache server orders in SQLite for offline viewing
          try {
            final cacheList = serverOrders
                .map((o) => {
                      'server_order_id': o.oId?.toString() ?? '',
                      'order_json': jsonEncode(o.toJson()),
                    })
                .toList();
            await DatabaseHelper().cacheOrders(cacheList);
          } catch (e) {
            print("Error caching orders to SQLite: $e");
          }

          // Also append local pending offline orders so user sees them
          await _appendLocalPendingOrders();

          if (_data.isEmpty) {
            nolist = true;
          }
        } else {
          ub.userSignout(context).then((value) {
            Get.offAll(() => LoginPage());
          });
        }
      } else {
        // Offline: load from Hive cache + local pending orders
        _data.addAll(orderfetchHive.values.cast());

        // If Hive is empty, try SQLite orders_cache
        if (_data.isEmpty) {
          try {
            final cached = await DatabaseHelper().getCachedOrders();
            for (var row in cached) {
              try {
                final jsonStr = row['order_json']?.toString() ?? '';
                if (jsonStr.isNotEmpty) {
                  final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
                  _data.add(DatumOrderList.fromJson(parsed));
                }
              } catch (_) {}
            }
          } catch (e) {
            print("Error loading cached orders from SQLite: $e");
          }
        }

        // Append local pending offline orders
        await _appendLocalPendingOrders();
      }
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack);
      AppSnackBar.showGetXCustomSnackBar(message: 'Something went wrong');
      print("Error in orderfetchProvider getOrders data ${e.toString()}");
    }
    notifyListeners();
  }

  /// Append pending/failed offline orders to the display list
  Future<void> _appendLocalPendingOrders() async {
    try {
      final localOrders = await DatabaseHelper().getPendingOrFailedOrders();
      for (var order in localOrders) {
        final items = await DatabaseHelper().getOrderItems(order['id']);
        final orderDate = order['order_date'] != null
            ? DateTime.fromMillisecondsSinceEpoch(order['order_date'])
            : DateTime.now();

        // Convert offline order items to DataOrdritm
        List<DataOrdritm> ordritms = items.map((item) {
          return DataOrdritm(
            odId: item['id'],
            oId: order['id'],
            itemCd: item['item_cd'] ?? '',
            quantity: item['quantity'] ?? 0,
            rate: item['rate'] ?? 0,
            amount: item['amount'] ?? 0,
            otherDesc: item['other_desc'] ?? '',
            vouchDt: orderDate,
            vouchTime:
                '${orderDate.hour}:${orderDate.minute}:${orderDate.second}',
            pCd: order['server_party_id'] ?? '',
          );
        }).toList();

        final status = order['sync_status'] ?? 'pending';
        final statusLabel = status == 'failed' ? '(FAILED)' : '(PENDING SYNC)';

        _data.insert(
            0,
            DatumOrderList(
              oId: 'offline_${order['id']}',
              vouchDt: orderDate,
              vouchTime:
                  '${orderDate.hour}:${orderDate.minute}:${orderDate.second}',
              partyCd: order['server_party_id'] ?? '',
              netAmt: order['total_amount'] ?? 0,
              orderNo: 'OFFLINE-${order['id']} $statusLabel',
              ordritms: ordritms,
            ));
      }
    } catch (e) {
      print("Error appending local pending orders: $e");
    }
  }

  @override
  disposeValues() {
    _data.clear();
    notifyListeners();
  }
}
