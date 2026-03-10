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
  Future<Map<String, int>> syncOrders(String token, {int? syncId}) async {
    int synced = 0, failed = 0, skipped = 0;

    // Pre-check: make sure we actually have internet before attempting sync
    final hasNet = await NetworkHelper.hasInternet();
    if (!hasNet) {
      print('[SyncService] No internet — skipping sync');
      return {'synced': 0, 'failed': 0, 'skipped': 0};
    }

    // Step 0: try to auto-repair broken order items (missing item_cd)
    await _repairOrderItems();

    // Only sync orders belonging to the current firm
    final List<Map<String, dynamic>> pendingOrders;
    if (syncId != null && syncId > 0) {
      pendingOrders = await db.getPendingOrdersBySyncId(syncId);
    } else {
      pendingOrders = await db.getPendingOrders();
    }
    print('[SyncService] Found ${pendingOrders.length} pending order(s) for SYNC_ID=$syncId');

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

      final ok = await _syncOrderWithRetry(order, token, syncId: syncId);
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
      {int? syncId, int maxRetries = 3}) async {
    int attempt = 0;
    int delaySeconds = 1;

    while (attempt < maxRetries) {
      try {
        await _syncSingleOrder(order, token, syncId: syncId);
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

  Future<void> _syncSingleOrder(Map<String, dynamic> order, String token,
      {int? syncId}) async {
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
            final productJson =
            jsonDecode(cachedProduct['product_json'].toString())
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

        // Extract and cache updated licenseInfo from sync response (if available)
        try {
          final licenseInfoFromResponse = data["licenseInfo"];
          if (licenseInfoFromResponse != null && syncId != null && syncId > 0) {
            print(
                '[SyncService] 📋 Found licenseInfo in sync response: $licenseInfoFromResponse');
            await db.cacheLicenseInfo(
              syncId: syncId,
              orderCount: licenseInfoFromResponse['orderCount'] as int? ?? 0,
              maxOrders: licenseInfoFromResponse['maxOrders'] as int? ?? 0,
              autoBlacklisted:
              licenseInfoFromResponse['autoBlacklisted'] == true,
              renewalTriggered:
              licenseInfoFromResponse['renewalTriggered'] == true,
            );
            print(
                '[SyncService] ✅ Updated license info cache after order sync');
          }
        } catch (e) {
          print(
              '[SyncService] ℹ️ No licenseInfo in sync response or error updating: $e');
        }
      } catch (e) {
        print('[SyncService] ⚠️ Failed to parse oId: $e');
      }

      await db.updateOrderStatus(order['id'], 'synced', serverOrderId);
      print(
          '[SyncService] Order ${order['id']} synced → server ID: $serverOrderId');

      // Reset offline license order count after successful order sync
      if (syncId != null && syncId > 0) {
        try {
          final licenseInfoBefore = await db.getLicenseInfo(syncId);
          await db.resetOfflineOrderCount(syncId);
          final licenseInfoAfter = await db.getLicenseInfo(syncId);

          final offlineBefore =
          (licenseInfoBefore?['offline_order_count'] ?? 0) as int;
          final offlineAfter =
          (licenseInfoAfter?['offline_order_count'] ?? 0) as int;

          print('[SyncService] ╔════════════════════════════════════════════');
          print('[SyncService] ║ LICENSE INFO RESET AFTER SYNC');
          print('[SyncService] ║ SYNC_ID: $syncId');
          print('[SyncService] ║ Before Reset - Offline Count: $offlineBefore');
          print('[SyncService] ║ After Reset - Offline Count: $offlineAfter');
          print(
              '[SyncService] ║ Server Order Count: ${licenseInfoAfter?['orderCount'] ?? 0}');
          print(
              '[SyncService] ║ Max Orders Limit: ${licenseInfoAfter?['maxOrders'] ?? 0}');
          print('[SyncService] ╚════════════════════════════════════════════');
        } catch (e) {
          print(
              '[SyncService] ⚠️ Warning: Could not reset offline order count: $e');
        }
      }

      // Step 3: Create order tracking record for "Order Placed" (type=2)
      // NOTE: This is now created immediately when the order is placed in shoppingCartPage
      // Only create here if it doesn't already exist (as a fallback for older versions/edge cases)
      try {
        if (serverOrderId != null) {
          final orderSvc = OrderTrackingService();
          final latitude = order["latitude"]?.toString() ?? '0';
          final longitude = order["longitude"]?.toString() ?? '0';

          // Check if PLACE ORDER tracking already exists for this order
          final dbInst = await db.database;
          final existingTracking = await dbInst.query(
            'order_tracking',
            where:
            "tracking_type = '2' AND ACC_CD = ? AND ABS(CAST(CREATED_AT as INTEGER) - ?) < 5000",
            whereArgs: [
              order["server_party_id"]?.toString() ?? '',
              order["order_date"] ?? DateTime.now().millisecondsSinceEpoch
            ],
            limit: 1,
          );

          if (existingTracking.isNotEmpty) {
            print(
                '[SyncService] ✅ PLACE ORDER tracking already exists - skipping duplicate creation');
            print(
                '[SyncService]   Existing trackingId: ${existingTracking.first['locId']}');
          } else {
            // Convert order_date (milliseconds since epoch) back to DateTime
            final orderDateMs = order["order_date"] as int?;

            // DEFENSIVE: Log the order_date value for debugging
            print('[SyncService] 🔍 ORDER_DATE DEBUG INFO:');
            print('[SyncService]   Raw order_date from DB: $orderDateMs');
            print(
                '[SyncService]   Order keys available: ${order.keys.toList()}');

            final orderDateTime = orderDateMs != null
                ? DateTime.fromMillisecondsSinceEpoch(orderDateMs)
                : null;

            if (orderDateMs == null) {
              print(
                  '[SyncService] ⚠️ WARNING: order_date is NULL! FALLBACK to current time');
              print(
                  '[SyncService]    This PLACE ORDER will use sync time instead of order creation time');
              print(
                  '[SyncService]    This indicates a database issue or data integrity problem');
            }

            print(
                '[SyncService] 📍 Creating order placement tracking for order $serverOrderId (fallback)');
            print(
                '[SyncService]   Using order time: ${orderDateTime?.toString() ?? "(current time - FALLBACK)"}');

            // CRITICAL: ALWAYS pass the orderDateTime, never fall back to current sync time
            // If order_date is null, we have a data integrity problem that must be investigated
            final finalDateTime = orderDateTime ?? DateTime.now();
            print('[SyncService] 📤 PLACE ORDER TRACKING PARAMS:');
            print(
                '[SyncService]   orderDateTime param: ${orderDateTime?.toString() ?? "NULL (FALLBACK)"}');
            print('[SyncService]   finalDateTime used: $finalDateTime');
            print('[SyncService]   IS FALLBACK: ${orderDateTime == null}');

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
              orderDateTime:
              orderDateTime, // Pass order's actual creation time IF available
            );

            print(
                '[SyncService] ✅ Order placement tracking created for order $serverOrderId');
          }
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
    } else if (response.statusCode == 400 || response.statusCode == 429) {
      // Backend rejected order due to limit exceeded or too many requests
      final errorMsg = response.statusCode == 400
          ? 'License limit exceeded'
          : 'Too many requests';
      print(
          '[SyncService] ❌ Order ${order['id']} REJECTED by backend: $errorMsg (HTTP ${response.statusCode})');

      // Mark as 'rejected' - do NOT throw exception, do NOT retry
      // This order will be retried when the license limit is renewed
      final dbInst = await db.database;
      await dbInst.update(
        'offline_orders',
        {
          'sync_status': 'rejected',
          'error_message':
          '$errorMsg - Waiting for license renewal to retry (HTTP ${response.statusCode})',
        },
        where: 'id = ?',
        whereArgs: [order['id']],
      );

      // Do NOT delete the order from offline cache - keep it for later retry
      print(
          '[SyncService] 💾 Order ${order['id']} kept in offline cache for retry when limit is renewed');
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

  /// Retry all orders that were rejected due to license limit exceeded.
  /// Call this method when the license limit is renewed or increased.
  ///
  /// Real-world scenario:
  /// - User A/B/C each have 10 pending orders (offline)
  /// - Firm limit = 10 orders: A's orders sync successfully, B/C orders rejected (sync_status='rejected')
  /// - When firmware limit renewed to 50: call retryRejectedOrders() to retry B/C orders
  Future<Map<String, int>> retryRejectedOrders(String token,
      {int? syncId}) async {
    int synced = 0, failed = 0;

    // Pre-check: internet connectivity
    final hasNet = await NetworkHelper.hasInternet();
    if (!hasNet) {
      print('[SyncService] 📵 No internet — skipping retry of rejected orders');
      return {'synced': 0, 'failed': 0};
    }

    // Get all orders with status='rejected' (limit exceeded)
    final dbInst = await db.database;
    final rejectedOrders = await dbInst.query(
      'offline_orders',
      where: 'sync_status = ?',
      whereArgs: ['rejected'],
    );

    if (rejectedOrders.isEmpty) {
      print('[SyncService] ✅ No rejected orders to retry');
      return {'synced': 0, 'failed': 0};
    }

    print(
        '[SyncService] 🔄 RETRYING ${rejectedOrders.length} REJECTED ORDERS (limit was renewed)');

    for (var order in rejectedOrders) {
      try {
        // Update status back to pending so it gets synced again
        final orderId = order['id'] as int? ?? 0;
        await db.updateOrderStatus(orderId, 'pending', null);
        print('[SyncService] ✏️ Marked order ${orderId} as pending for retry');
      } catch (e) {
        print('[SyncService] Error marking order ${order['id']} for retry: $e');
        failed++;
      }
    }

    // Now sync all the re-marked pending orders (includes previously rejected ones)
    final syncResult = await syncOrders(token, syncId: syncId);
    return syncResult;
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
      print(
          '[SyncService] 📋 LOCAL DB: trackingId=${t['locId']} | REMARK=${t['REMARK']} | oId=${t['oId']} | ACC_CD=${t['ACC_CD']}');
    }

    for (var tracking in pendingTrackings) {
      var trackingId;
      try {
        trackingId = tracking['locId'];

        // ✅ VALIDATION: Skip if ACC_CD is empty (invalid party)
        final accCd = tracking['ACC_CD']?.toString().trim() ?? '';
        if (accCd.isEmpty) {
          print(
              '[SyncService] ⚠️ Skipping tracking #$trackingId - empty/invalid ACC_CD');
          print(
              '[SyncService]    This tracking has no party reference and cannot be synced');
          await db.deleteOrderTracking(trackingId);
          print('[SyncService]    ✅ Deleted invalid tracking record');
          continue;
        }

        final remarkVal = tracking['REMARK']?.toString() ?? '';
        final vouchDt = tracking['VOUCH_DT']?.toString() ?? '';
        final rawTime = tracking['VOUCH_TIME']?.toString() ?? '00:00:00';
        final cleanTime = rawTime.split('.').first;

        // Use stored tracking_type if available, otherwise derive from REMARK (for backward compatibility)
        var trackingType = tracking['tracking_type']?.toString() ?? '';
        if (trackingType.isEmpty) {
          // Fallback: Determine if this is START (IN) or END (OUT) order from REMARK
          final isOut = remarkVal.toUpperCase() == 'OUT';
          trackingType = isOut ? '3' : '1';
        }

        // Match EXACT same structure as online payload (order_tracking_service.dart)
        final payload = {
          'accCd': accCd,
          'lat': tracking['LAT']?.toString() ?? '0.0',
          'longi': tracking['LONGI']?.toString() ?? '0.0',
          'oId': tracking['oId']?.toString() ?? '',
          'type': trackingType,
          'moduleNo': tracking['MODULE_NO']?.toString() ?? '205',
          'remark': remarkVal,
          'REMARK': remarkVal,
          'remarks': remarkVal,
          'vouchDt': vouchDt,
          'vouchTime': cleanTime,
          'USER_CD': tracking['USER_CD']?.toString() ?? '',
          'SYNC_ID': tracking['SYNC_ID']?.toString() ?? '',
        };

        print('[SyncService] 📤 Syncing order tracking #$trackingId');
        print(
            '[SyncService]   Party: ${payload['accCd']} | oId: ${payload['oId']}');
        print('[SyncService]   GPS: (${payload['lat']}, ${payload['longi']})');
        print('[SyncService]   REMARK: $remarkVal | type: ${payload['type']}');
        print('[SyncService]   📅 SYNC TIME:');
        print('[SyncService]      LOCAL DB VOUCH_DT: $vouchDt');
        print(
            '[SyncService]      LOCAL DB VOUCH_TIME: $rawTime (cleaned: $cleanTime)');
        print(
            '[SyncService]      SENDING TO SERVER: VOUCH_DT=$vouchDt, VOUCH_TIME=$cleanTime');
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
          final serverVouchDt =
              respData['data']?['VOUCH_DT']?.toString() ?? 'N/A';
          final serverVouchTime =
              respData['data']?['VOUCH_TIME']?.toString() ?? 'N/A';
          print(
              '[SyncService] ✅ Server stored: locId=$serverLocId, REMARK=$serverRemark, oId=$serverOId');
          print(
              '[SyncService]   📅 SERVER TIME: VOUCH_DT=$serverVouchDt, VOUCH_TIME=$serverVouchTime');
        } catch (e) {
          print('[SyncService] Could not parse response: $e');
        }

        if (response.statusCode == 200 || response.statusCode == 201) {
          // Success: mark as synced and delete local copy
          await db.updateOrderTrackingStatus(trackingId, 'synced', null);
          await db.deleteOrderTracking(trackingId);
          synced++;
          print('[SyncService] ✅ Synced order tracking #$trackingId');
        } else if (response.statusCode == 400) {
          // ✅ 400 = Invalid party for this firm (FK constraint failed)
          // This tracking cannot be synced - delete it to prevent retry loops
          print(
              '[SyncService] ⚠️ HTTP 400: Party ${payload['accCd']} does not exist for this firm');
          print(
              '[SyncService]    Deleting tracking #$trackingId (unrecoverable)');
          await db.deleteOrderTracking(trackingId);
          synced++; // Count as processed (cleaned up)
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

    // ALSO sync pending PLACE ORDER (type=2) trackings that were created offline
    print('[SyncService] 🎯 PLACE ORDER TRACKING SYNC (type=2)');
    final pendingPlaceOrderTrackings =
    await db.getPendingOrderPlacementTrackings();
    print(
        '[SyncService] Found ${pendingPlaceOrderTrackings.length} pending PLACE ORDER tracking(s)');

    for (var tracking in pendingPlaceOrderTrackings) {
      var trackingId;
      try {
        trackingId = tracking['locId'];

        // ✅ VALIDATION: Skip if ACC_CD is empty (invalid party)
        final accCd = tracking['ACC_CD']?.toString().trim() ?? '';
        if (accCd.isEmpty) {
          print(
              '[SyncService] ⚠️ Skipping PLACE ORDER tracking #$trackingId - empty/invalid ACC_CD');
          await db.deleteOrderTracking(trackingId);
          print('[SyncService]    ✅ Deleted invalid PLACE ORDER tracking');
          continue;
        }

        final remarkVal = tracking['REMARK']?.toString() ?? '';
        final vouchDt = tracking['VOUCH_DT']?.toString() ?? '';
        final rawTime = tracking['VOUCH_TIME']?.toString() ?? '00:00:00';
        final cleanTime = rawTime.split('.').first;
        final trackingType = '2'; // PLACE ORDER

        final payload = {
          'accCd': accCd,
          'lat': tracking['LAT']?.toString() ?? '0.0',
          'longi': tracking['LONGI']?.toString() ?? '0.0',
          'oId': tracking['oId']?.toString() ?? '',
          'type': trackingType,
          'moduleNo': tracking['MODULE_NO']?.toString() ?? '205',
          'remark': remarkVal,
          'REMARK': remarkVal,
          'remarks': remarkVal,
          'vouchDt': vouchDt,
          'vouchTime': cleanTime,
          'USER_CD': tracking['USER_CD']?.toString() ?? '',
          'SYNC_ID': tracking['SYNC_ID']?.toString() ?? '',
        };

        print('[SyncService] 📤 Syncing PLACE ORDER tracking #$trackingId');
        print(
            '[SyncService]   Party: ${payload['accCd']} | VOUCH_DT=$vouchDt, VOUCH_TIME=$cleanTime');

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

        if (response.statusCode == 200 || response.statusCode == 201) {
          await db.updateOrderTrackingStatus(trackingId, 'synced', null);
          await db.deleteOrderTracking(trackingId);
          synced++;
          print('[SyncService] ✅ Synced PLACE ORDER tracking #$trackingId');
        } else if (response.statusCode == 400) {
          // ✅ 400 = Invalid party for this firm (FK constraint failed)
          print(
              '[SyncService] ⚠️ HTTP 400: Party ${payload['accCd']} does not exist for this firm');
          print(
              '[SyncService]    Deleting PLACE ORDER tracking #$trackingId (unrecoverable)');
          await db.deleteOrderTracking(trackingId);
          synced++; // Count as processed (cleaned up)
        } else {
          failed++;
          print(
              '[SyncService] ❌ Failed: HTTP ${response.statusCode} for PLACE ORDER tracking #$trackingId');
        }
      } catch (e) {
        failed++;
        print(
            '[SyncService] ❌ Error syncing PLACE ORDER tracking #$trackingId: $e');
      }
    }

    print(
        '[SyncService] 🎯 Order tracking sync complete: $synced synced, $failed failed');
    return {'synced': synced, 'failed': failed};
  }
}
