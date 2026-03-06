import 'database_helper.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/helper/network_helper.dart';

import 'order_tracking_service.dart';

class SyncService {
  final DatabaseHelper db = DatabaseHelper();

  /// Main entry point: validate → repair → sync all pending orders.
  /// Returns a summary: {synced, failed, skipped}
  Future<Map<String, int>> syncOrders(String token) async {
    int synced = 0, failed = 0, skipped = 0;

    // Pre-check: make sure we actually have internet before attempting sync
    final hasNet = await NetworkHelper.hasInternet();
    if (!hasNet) {
      print('[SyncService] No internet — skipping sync');
      return {'synced': 0, 'failed': 0, 'skipped': 0};
    }

    // Step 0: try to auto-repair broken order items (missing item_cd)
    await _repairOrderItems();

    final pendingOrders = await db.getPendingOrders();
    print('[SyncService] Found ${pendingOrders.length} pending order(s)');

    for (var order in pendingOrders) {
      // Validate order items before attempting sync
      final items = await db.getOrderItems(order['id']);
      final hasValidItems =
          items.any((i) => (i['item_cd']?.toString() ?? '').isNotEmpty);

      if (items.isEmpty || !hasValidItems) {
        // Unrecoverable: no items or all items lack item_cd even after repair
        print(
            '[SyncService] Order ${order['id']} has no valid items — marking failed');
        await db.updateOrderStatus(order['id'], 'failed', null);
        skipped++;
        continue;
      }

      // Skip orders with empty partyCd — they can never sync successfully
      final partyCd = order['server_party_id']?.toString() ?? '';
      if (partyCd.isEmpty) {
        print(
            '[SyncService] ⚠️ Order ${order['id']} has empty partyCd — marking failed');
        await db.updateOrderStatus(order['id'], 'failed', null);
        skipped++;
        continue;
      }

      final ok = await _syncOrderWithRetry(order, token);
      if (ok) {
        synced++;
      } else {
        failed++;
      }
    }

    print(
        '[SyncService] Sync complete: synced=$synced, failed=$failed, skipped=$skipped');
    return {'synced': synced, 'failed': failed, 'skipped': skipped};
  }

  /// Try to fill in missing item_cd values from products_cache or cart_items.
  Future<void> _repairOrderItems() async {
    final dbInst = await db.database;
    final broken = await dbInst.query(
      'offline_order_items',
      where: "item_cd IS NULL OR item_cd = ''",
    );

    if (broken.isEmpty) return;
    print(
        '[SyncService] Repairing ${broken.length} order item(s) with empty item_cd');

    for (var row in broken) {
      final id = row['id'];
      final itemName = (row['item_name'] ?? '').toString().trim();
      String recoveredCd = '';

      // Strategy 1: match by item_name in products_cache
      if (itemName.isNotEmpty) {
        final candidates = await dbInst.query(
          'products_cache',
          where: 'item_name = ?',
          whereArgs: [itemName],
          limit: 2,
        );
        if (candidates.length == 1) {
          recoveredCd = candidates.first['item_cd']?.toString() ?? '';
        }

        // Strategy 2: match via product_json ITEM_NAME (case-insensitive)
        if (recoveredCd.isEmpty) {
          final all = await dbInst.query('products_cache');
          for (var p in all) {
            try {
              final json = jsonDecode(p['product_json'].toString())
                  as Map<String, dynamic>;
              final pName = (json['ITEM_NAME'] ?? json['itemName'] ?? '')
                  .toString()
                  .trim();
              if (pName.isNotEmpty &&
                  pName.toLowerCase() == itemName.toLowerCase()) {
                recoveredCd =
                    (json['ITEM_CD'] ?? json['itemCd'] ?? p['item_cd'])
                            ?.toString() ??
                        '';
                if (recoveredCd.isNotEmpty) break;
              }
            } catch (_) {}
          }
        }
      }

      // Strategy 3: look in cart_items for same order's party + matching fields
      if (recoveredCd.isEmpty) {
        final orderId = row['order_id'];
        final orders = await dbInst
            .query('offline_orders', where: 'id = ?', whereArgs: [orderId]);
        if (orders.isNotEmpty) {
          final partyCd = orders.first['server_party_id']?.toString() ?? '';
          if (partyCd.isNotEmpty) {
            final cartRows = await dbInst.query('cart_items',
                where: "party_cd = ? AND item_cd != '' AND item_cd IS NOT NULL",
                whereArgs: [partyCd]);
            // Try matching by quantity + rate
            for (var c in cartRows) {
              if (c['quantity'] == row['quantity'] &&
                  c['rate'] == row['rate']) {
                recoveredCd = c['item_cd']?.toString() ?? '';
                if (recoveredCd.isNotEmpty) break;
              }
            }
          }
        }
      }

      if (recoveredCd.isNotEmpty) {
        await dbInst.update(
          'offline_order_items',
          {'item_cd': recoveredCd},
          where: 'id = ?',
          whereArgs: [id],
        );
        print('[SyncService] Repaired item $id → item_cd=$recoveredCd');
      } else {
        print('[SyncService] Could not repair item $id (name="$itemName")');
      }
    }
  }

  /// Attempt sync with retries. Returns true on success, false on failure.
  Future<bool> _syncOrderWithRetry(Map<String, dynamic> order, String token,
      {int maxRetries = 3}) async {
    int attempt = 0;
    int delaySeconds = 1;

    while (attempt < maxRetries) {
      try {
        await _syncSingleOrder(order, token);
        return true;
      } catch (e) {
        attempt++;
        await db.updateRetry(order['id'], e.toString());

        if (attempt >= maxRetries) {
          print(
              '[SyncService] Order ${order['id']} failed after $maxRetries attempts: $e');
          return false;
        }

        print(
            '[SyncService] Retrying order ${order['id']} in ${delaySeconds}s (attempt $attempt/$maxRetries)');
        await Future.delayed(Duration(seconds: delaySeconds));
        delaySeconds *= 2;
      }
    }
    return false;
  }

  Future<void> _syncSingleOrder(
      Map<String, dynamic> order, String token) async {
    final items = await db.getOrderItems(order['id']);

    // Filter to only valid items (skip items with empty item_cd)
    final validItems = items
        .where((i) => (i['item_cd']?.toString() ?? '').isNotEmpty)
        .toList();

    if (validItems.isEmpty) {
      throw Exception('No valid items with item_cd for order ${order['id']}');
    }

    final partyCd = order["server_party_id"]?.toString() ?? '';

    // Step 0: CLEAR existing server cart for this party to avoid qty doubling
    // (Items may already exist from when user added them online)
    try {
      final cartResponse = await http.get(
        Uri.parse("${AppConfig.baseURL}cart?partyCd=$partyCd"),
        headers: {
          "Authorization": "Bearer $token",
          'x-app-type': 'oms',
        },
      );
      if (cartResponse.statusCode == 200) {
        final cartData = jsonDecode(cartResponse.body);
        final existingItems = cartData['data'] as List? ?? [];
        for (var existingItem in existingItems) {
          final cId = existingItem['cId'];
          if (cId != null) {
            await http.delete(
              Uri.parse("${AppConfig.baseURL}cart/$cId"),
              headers: {
                "Authorization": "Bearer $token",
                'x-app-type': 'oms',
              },
            );
            print('[SyncService] Deleted existing server cart item cId=$cId');
          }
        }
      }
    } catch (e) {
      print(
          '[SyncService] Warning: Could not clear server cart before sync: $e');
      // Continue anyway — better to have duplicates than skip the order
    }

    // // Step 1: Add each item to the server cart
    // for (var item in validItems) {
    //   final itemCd = item['item_cd'].toString();
    //
    //   var cartPayload = {
    //     "partyCd": partyCd,
    //     "itemCd": itemCd,
    //     "qty": item["quantity"]?.toString() ?? '0',
    //     "rate": item["rate"]?.toString() ?? '0',
    //     "lrate": item["lrate"]?.toString() ?? '0',
    //     "moduleNo": "205",
    //   };

    // Step 1: Add each item to the server cart
    // Get products cache to recover missing rates
    final productsCache = await db.getCachedProducts();

    for (var item in validItems) {
      final itemCd = item['item_cd'].toString();

      // Handle missing rates: if rate is 0, try to recover from products_cache
      var rate = item["rate"] ?? 0.0;
      var lrate = item["lrate"] ?? 0.0;
      var nrate = item["nrate"] ?? 0.0;

      if ((rate == 0.0 || rate.toString() == '0') && productsCache.isNotEmpty) {
        // Try to find this item in products_cache and get its rate
        try {
          final cachedProduct = productsCache.firstWhere(
                (p) => p['item_cd']?.toString() == itemCd,
            orElse: () => {},
          );

          if (cachedProduct.isNotEmpty) {
            final productJson = jsonDecode(cachedProduct['product_json'].toString())
            as Map<String, dynamic>;
            // Try different rate field names from product JSON
            final srate = productJson['SRATE1'] ??
                productJson['SRATE3'] ??
                productJson['PRATE'] ??
                0;
            if (srate != 0 && srate.toString() != '0') {
              rate = double.tryParse(srate.toString()) ?? rate;
              print(
                  '[SyncService] ✅ Recovered rate for item $itemCd: $rate (was 0.0)');
            }
          }
        } catch (e) {
          print('[SyncService] ⚠️ Could not recover rate for item $itemCd: $e');
        }
      }

      var cartPayload = {
        "partyCd": partyCd,
        "itemCd": itemCd,
        "qty": item["quantity"]?.toString() ?? '0',
        "rate": rate.toString(),
        "lrate": lrate.toString(),
        "moduleNo": "205",
      };

      if (item["other_desc"] != null &&
          item["other_desc"].toString().isNotEmpty) {
        cartPayload["otherDesc"] = item["other_desc"].toString();
      }
      if (item["fld5"] != null && item["fld5"].toString().isNotEmpty) {
        cartPayload["fld5"] = item["fld5"].toString();
      }

      print('[SyncService] POST cart: $cartPayload');

      var cartResponse = await http.post(
        Uri.parse("${AppConfig.baseURL}cart"),
        headers: {
          "Authorization": "Bearer $token",
          'x-app-type': 'oms',
        },
        body: cartPayload,
      );

      print(
          '[SyncService] Cart response ${cartResponse.statusCode}: ${cartResponse.body}');

      if (cartResponse.statusCode == 401) {
        throw Exception("Authentication expired");
      }
      if (cartResponse.statusCode != 200 && cartResponse.statusCode != 201) {
        throw Exception(
            "Failed to add item $itemCd to cart: HTTP ${cartResponse.statusCode} — ${cartResponse.body}");
      }
    }

    // Step 2: Place the order
    var orderPayload = {
      "partyCd": order["server_party_id"]?.toString() ?? '',
      "lat": order["latitude"]?.toString() ?? '0',
      "longi": order["longitude"]?.toString() ?? '0',
      "narration": order["remarks"]?.toString() ?? "",
      "moduleNo": "205",
    };

    print('[SyncService] POST orders: $orderPayload');

    var response = await http.post(
      Uri.parse("${AppConfig.baseURL}orders"),
      headers: {
        "Authorization": "Bearer $token",
        'x-app-type': 'oms',
      },
      body: orderPayload,
    );

    print(
        '[SyncService] Order response ${response.statusCode}: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      int? serverOrderId;
      try {
        final data = jsonDecode(response.body);
        print('[SyncService] 🔍 Full response data: ${data["data"]}');
        serverOrderId = data["data"]?["oId"] ?? data["oId"];
        print('[SyncService] 🔍 Extracted serverOrderId: $serverOrderId');
      } catch (e) {
        print('[SyncService] ⚠️ Failed to parse oId: $e');
      }

      await db.updateOrderStatus(order['id'], 'synced', serverOrderId);
      print(
          '[SyncService] Order ${order['id']} synced → server ID: $serverOrderId');

      // Step 3: Create order tracking record for "Order Placed" (type=2)
      // This reflects that an order was placed during the punch-in session
      try {
        if (serverOrderId != null) {
          final orderSvc = OrderTrackingService();
          final latitude = order["latitude"]?.toString() ?? '0';
          final longitude = order["longitude"]?.toString() ?? '0';

          print(
              '[SyncService] 📍 Creating order placement tracking for order $serverOrderId');

          await orderSvc.startEndOrder(
            accCd: order["server_party_id"]?.toString() ?? '',
            latitude: double.parse(latitude),
            longitude: double.parse(longitude),
            type: "2", // Type 2 = Order placed (matches online flow)
            oId: serverOrderId.toString(),
            token: token,
            moduleNo: "205",
            syncId: 0,
            userCd: "",
            isEndOrder: null, // Neutral for order placement
          );

          print(
              '[SyncService] ✅ Order placement tracking created for order $serverOrderId');
        }
      } catch (e) {
        print(
            '[SyncService] ⚠️ Warning: Could not create order placement tracking: $e');
        // Continue anyway - order was synced, tracking is optional
      }

      // Clean up local data
      try {
        await db.deleteOfflineOrder(order['id']);
        if (order['server_party_id'] != null) {
          await db.clearCartForParty(order['server_party_id'].toString());
        }
      } catch (e) {
        print('[SyncService] Cleanup error for order ${order['id']}: $e');
      }
    } else {
      throw Exception("HTTP ${response.statusCode}: ${response.body}");
    }
  }

  /// Remove orders that are permanently unrecoverable (no items or all items lack item_cd).
  Future<int> cleanupBrokenOrders() async {
    final pendingOrders = await db.getPendingOrders();
    int cleaned = 0;

    for (var order in pendingOrders) {
      final items = await db.getOrderItems(order['id']);
      final hasValid =
          items.any((i) => (i['item_cd']?.toString() ?? '').isNotEmpty);

      if (items.isEmpty || !hasValid) {
        await db.deleteOfflineOrder(order['id']);
        print('[SyncService] Deleted broken order ${order['id']}');
        cleaned++;
      }
    }
    return cleaned;
  }

  /// Sync local cart items to server.
  /// Called on reconnection to push any items added while offline.
  Future<int> syncCartToServer(String token) async {
    final hasNet = await NetworkHelper.hasInternet();
    if (!hasNet) return 0;

    final dbInst = await db.database;
    // Get all local cart items that were added while offline (sync_status = 'pending')
    final pendingItems = await dbInst.query(
      'cart_items',
      where: "sync_status = 'pending'",
    );

    if (pendingItems.isEmpty) {
      print('[SyncService] No pending cart items to sync');
      return 0;
    }

    int synced = 0;
    print(
        '[SyncService] Syncing ${pendingItems.length} pending cart item(s) to server');

    for (var item in pendingItems) {
      try {
        final itemCd = item['item_cd']?.toString() ?? '';
        if (itemCd.isEmpty) continue;

        var cartPayload = {
          "partyCd": item['party_cd']?.toString() ?? '',
          "itemCd": itemCd,
          "qty": item['quantity']?.toString() ?? '0',
          "rate": item['rate']?.toString() ?? '0',
          "lrate": item['lrate']?.toString() ?? '0',
          "moduleNo": "205",
        };

        final otherDesc = item['other_desc']?.toString() ?? '';
        if (otherDesc.isNotEmpty) cartPayload["otherDesc"] = otherDesc;

        final fld5 = item['fld5']?.toString() ?? '';
        if (fld5.isNotEmpty) cartPayload["fld5"] = fld5;

        final response = await http.post(
          Uri.parse("${AppConfig.baseURL}cart"),
          headers: {
            "Authorization": "Bearer $token",
            'x-app-type': 'oms',
          },
          body: cartPayload,
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          // Mark as synced
          await dbInst.update(
            'cart_items',
            {'sync_status': 'synced'},
            where: 'id = ?',
            whereArgs: [item['id']],
          );
          synced++;
          print('[SyncService] Cart item $itemCd synced to server');
        } else if (response.statusCode == 401) {
          print('[SyncService] Auth expired during cart sync');
          break;
        }
      } catch (e) {
        print('[SyncService] Error syncing cart item: $e');
      }
    }

    print(
        '[SyncService] Cart sync complete: $synced/${pendingItems.length} items');
    return synced;
  }

  /// Sync pending location (punch-in/punch-out) records to server.
  /// Only deletes local records AFTER successful sync to server.
  Future<Map<String, int>> syncLocations(String token) async {
    int synced = 0, failed = 0;

    // Pre-check: make sure we have internet
    final hasNet = await NetworkHelper.hasInternet();
    if (!hasNet) {
      print('[SyncService] 📵 No internet — skipping location sync');
      return {'synced': 0, 'failed': 0};
    }

    final pendingLocations = await db.getPendingLocations();
    print('[SyncService] 📍 LOCATION SYNC STARTED');
    print(
        '[SyncService] Found ${pendingLocations.length} pending punch(es) to sync');

    for (var location in pendingLocations) {
      var locId;
      try {
        locId = location['locId'];

        // Prepare payload for server
        final rawTime = location['VOUCH_TIME']?.toString() ?? '00:00:00';
        final cleanTime = rawTime.split('.').first; // strip microseconds
        final latStr = location['LAT']?.toString() ?? '0.0';
        final longiStr = location['LONGI']?.toString() ?? '0.0';
        final remarkStr = location['REMARK']?.toString() ?? '';
        final moduleNoStr = location['MODULE_NO']?.toString() ?? '205';

        var payload = {
          'USER_CD': location['USER_CD']?.toString() ?? '',
          'VOUCH_DT': location['VOUCH_DT']?.toString() ?? '',
          'VOUCH_TIME': cleanTime,
          'LAT': latStr,
          'LONGI': longiStr,
          'REMARK': remarkStr,
          'SYNC_ID': location['SYNC_ID']?.toString() ?? '',
          'MODULE_NO': moduleNoStr,
          'lat': latStr,
          'long': longiStr,
          'moduleNo': moduleNoStr,
          'remarks': remarkStr,
        };

        print('[SyncService] 📤 Syncing location #${locId ?? 'unknown'}');
        print(
            '[SyncService]   User: ${payload['USER_CD']} | Punch: ${payload['REMARK']}');
        print(
            '[SyncService]   Date: ${payload['VOUCH_DT']} | Time: ${payload['VOUCH_TIME']}');
        print('[SyncService]   GPS: (${payload['LAT']}, ${payload['LONGI']})');

        // Post to server
        var response = await http.post(
          Uri.parse("${AppConfig.baseURL}locations"),
          headers: {
            "Authorization": "Bearer $token",
            'x-app-type': 'oms',
          },
          body: payload,
        );

        print(
            '[SyncService] 📥 Response ${response.statusCode}: ${response.body}');

        if (response.statusCode == 200 || response.statusCode == 201) {
          // Success: mark as synced and delete from local DB
          await db.updateLocationSyncStatus(locId, 'synced', null);
          await db.deleteLocation(locId);
          synced++;
          print(
              '[SyncService] ✅ Success! Location #${locId ?? 'unknown'} synced & deleted from local DB');
          print(
              '[SyncService]    (Synced: $synced/${pendingLocations.length})');
        } else if (response.statusCode == 401) {
          print('[SyncService] ⚠️ Auth expired during location sync');
          break;
        } else {
          failed++;
          print(
              '[SyncService] ❌ Failed: HTTP ${response.statusCode} for location #${locId ?? 'unknown'}');
          print('[SyncService]    Local copy kept for retry (Failed: $failed)');
          // Keep local copy for retry
        }
      } catch (e) {
        failed++;
        print(
            '[SyncService] ❌ Error syncing location #${locId ?? 'unknown'}: $e');
        print('[SyncService]    Local copy kept for retry');
        // Keep local copy on error
      }
    }

    print(
        '[SyncService] 📍 Location sync complete: $synced synced, $failed failed');
    return {'synced': synced, 'failed': failed};
  }

  /// Sync order tracking events (start/end order)
  Future<Map<String, int>> syncOrderTrackings(String token) async {
    int synced = 0, failed = 0;

    // Pre-check: make sure we have internet
    final hasNet = await NetworkHelper.hasInternet();
    if (!hasNet) {
      print('[SyncService] 📵 No internet — skipping order tracking sync');
      return {'synced': 0, 'failed': 0};
    }

    final pendingTrackings = await db.getPendingOrderTrackings();
    print('[SyncService] 🎯 ORDER TRACKING SYNC STARTED');
    print(
        '[SyncService] Found ${pendingTrackings.length} pending tracking(s) to sync');
    
    // Debug: show local DB state before sync
    for (var t in pendingTrackings) {
      print('[SyncService] 📋 LOCAL DB: trackingId=${t['locId']} | REMARK=${t['REMARK']} | oId=${t['oId']} | ACC_CD=${t['ACC_CD']}');
    }

    for (var tracking in pendingTrackings) {
      var trackingId;
      try {
        trackingId = tracking['locId'];

        final remarkVal = tracking['REMARK']?.toString() ?? '';
        final vouchDt = tracking['VOUCH_DT']?.toString() ?? '';
        final rawTime = tracking['VOUCH_TIME']?.toString() ?? '00:00:00';
        final cleanTime = rawTime.split('.').first;
        
        // Determine if this is START (IN) or END (OUT) order
        final isOut = remarkVal.toUpperCase() == 'OUT';

        final trackingType = isOut ? '3' : '1';
        
        final payload = {
          'accCd': tracking['ACC_CD']?.toString() ?? '',
          'lat': tracking['LAT']?.toString() ?? '0.0',
          'longi': tracking['LONGI']?.toString() ?? '0.0',
          'oId': tracking['oId']?.toString() ?? '',
          'type': trackingType,  // Keep original type value
          'moduleNo': tracking['MODULE_NO']?.toString() ?? '205',
          'remark': remarkVal,
          'REMARK': remarkVal,
          'remarks': remarkVal,
          'VOUCH_DT': vouchDt,
          'VOUCH_TIME': cleanTime,
          'USER_CD': tracking['USER_CD']?.toString() ?? '',
          'SYNC_ID': tracking['SYNC_ID']?.toString() ?? '',
        };

        print('[SyncService] 📤 Syncing order tracking #$trackingId');
        print(
            '[SyncService]   Party: ${payload['accCd']} | oId: ${payload['oId']}');
        print('[SyncService]   GPS: (${payload['lat']}, ${payload['longi']})');
        print('[SyncService]   REMARK: $remarkVal | type: ${payload['type']}');
        print('[SyncService]   Full payload: $payload');

        var response = await http.post(
          Uri.parse("${AppConfig.baseURL}orders-tracking"),
          headers: {
            "Authorization": "Bearer $token",
            'x-app-type': 'oms',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload),
        );

        print('[SyncService] 📥 Server response: ${response.statusCode}');
        print('[SyncService]   Body: ${response.body}');
        
        // Parse response to show what server stored
        try {
          final respData = jsonDecode(response.body);
          final serverRemark = respData['data']?['REMARK']?.toString() ?? 'N/A';
          final serverOId = respData['data']?['oId']?.toString() ?? 'null';
          final serverLocId = respData['data']?['locId']?.toString() ?? 'N/A';
          print('[SyncService] ✅ Server stored: locId=$serverLocId, REMARK=$serverRemark, oId=$serverOId');
        } catch (e) {
          print('[SyncService] Could not parse response: $e');
        }

        if (response.statusCode == 200 || response.statusCode == 201) {
          // Success: mark as synced and delete local copy
          await db.updateOrderTrackingStatus(trackingId, 'synced', null);
          await db.deleteOrderTracking(trackingId);
          synced++;
          print('[SyncService] ✅ Synced order tracking #$trackingId');
        } else {
          // Server error: keep local copy for retry
          failed++;
          print(
              '[SyncService] ❌ Failed: HTTP ${response.statusCode} for tracking #$trackingId');
          print('[SyncService]    Local copy kept for retry');
        }
      } catch (e) {
        failed++;
        print('[SyncService] ❌ Error syncing order tracking #$trackingId: $e');
        print('[SyncService]    Local copy kept for retry');
      }
    }

    print(
        '[SyncService] 🎯 Order tracking sync complete: $synced synced, $failed failed');
    return {'synced': synced, 'failed': failed};
  }
}
