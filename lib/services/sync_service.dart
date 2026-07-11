import 'dart:convert';

import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/helper/network_helper.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'database_helper.dart';
import 'order_tracking_service.dart';
import 'trip_prefs_helper.dart';

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
    print(
        '[SyncService] Found ${pendingOrders.length} pending order(s) for SYNC_ID=$syncId');

    // 🔥 DEBUG: Log detailed info if no orders found
    if (pendingOrders.isEmpty && syncId != null && syncId > 0) {
      print('[SyncService] 🔍 DEBUG: No pending orders found!');
      print('[SyncService]   Query: sync_status=pending AND SYNC_ID=$syncId');

      // Try querying ALL orders to see what's in the database
      final allOrders = await db.getPendingOrders();
      print(
          '[SyncService]   Total orders with sync_status=pending (any SYNC_ID): ${allOrders.length}');
      for (var o in allOrders) {
        print(
            '[SyncService]     - id=${o['id']}, SYNC_ID=${o['SYNC_ID']}, status=${o['sync_status']}');
      }
    }

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

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  bool _isEmptyOrderId(dynamic value) {
    if (value == null) return true;
    final text = value.toString().trim().toLowerCase();
    if (text.isEmpty || text == 'null') return true;
    final parsed = int.tryParse(text);
    return parsed == null || parsed <= 0;
  }

  Future<void> _linkServerOrderIdToPendingTrackings({
    required int localOrderId,
    required String accCd,
    required int serverOrderId,
    int? orderDateMs,
  }) async {
    if (accCd.trim().isEmpty || serverOrderId <= 0) {
      print(
          '[SyncService] ⚠️ Skipping oId linkage: invalid accCd/serverOrderId');
      return;
    }

    final dbInst = await db.database;
    final anchorMs = orderDateMs ?? DateTime.now().millisecondsSinceEpoch;

    final pendingRows = await dbInst.query(
      'order_tracking',
      where: "sync_status = 'pending' AND ACC_CD = ? AND tracking_type = '2'",
      whereArgs: [accCd],
      orderBy: 'CAST(CREATED_AT as INTEGER) ASC',
    );

    if (pendingRows.isEmpty) {
      print(
          '[SyncService] ℹ️ No pending type=2 tracking found for party=$accCd to attach oId=$serverOrderId');
      return;
    }

    final emptyOidRows =
        pendingRows.where((r) => _isEmptyOrderId(r['oId'])).toList();
    if (emptyOidRows.isEmpty) {
      print(
          '[SyncService] ℹ️ Pending trackings already have oId for party=$accCd');
      return;
    }

    Map<String, dynamic>? selectedPlaceTracking;
    final placeCandidates = emptyOidRows;

    if (placeCandidates.isNotEmpty) {
      placeCandidates.sort((a, b) {
        final aTs = _toInt(a['CREATED_AT']) ?? anchorMs;
        final bTs = _toInt(b['CREATED_AT']) ?? anchorMs;
        return (aTs - anchorMs).abs().compareTo((bTs - anchorMs).abs());
      });

      selectedPlaceTracking = placeCandidates.first;

      await dbInst.update(
        'order_tracking',
        {'oId': serverOrderId},
        where: 'locId = ?',
        whereArgs: [selectedPlaceTracking['locId']],
      );

      print(
          '[SyncService] 🔗 Linked server oId=$serverOrderId to PLACE ORDER tracking #${selectedPlaceTracking['locId']} (localOrderId=$localOrderId)');
    } else {
      print(
          '[SyncService] ℹ️ No pending PLACE ORDER tracking found for party=$accCd (localOrderId=$localOrderId)');
      return;
    }

    print(
        '[SyncService] ℹ️ By design, oId is linked only to ORDER PLACED (type=2); IN/OUT trackings keep oId=NULL');
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
      if (item["stockist"] != null && item["stockist"].toString().isNotEmpty) {
        cartPayload["stockist"] = item["stockist"].toString();
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

    print(
        '[SyncService] 🚀 Syncing local offline order id=${order['id']} via /orders');
    print('[SyncService]   POST URL: ${AppConfig.baseURL}orders');
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

      final localOrderId = _toInt(order['id']) ?? 0;
      final orderDateMs = _toInt(order['order_date']);
      if (serverOrderId != null && serverOrderId > 0) {
        await _linkServerOrderIdToPendingTrackings(
          localOrderId: localOrderId,
          accCd: partyCd,
          serverOrderId: serverOrderId,
          orderDateMs: orderDateMs,
        );
      } else {
        print(
            '[SyncService] ⚠️ No valid serverOrderId for localOrderId=$localOrderId; cannot attach oId to pending tracking rows');
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

      // 🔥 CRITICAL: Also clear server-side cart for this party!
      // After syncing offline order, delete cart items from server to prevent re-loading
      try {
        final partyCd = order['server_party_id']?.toString() ?? '';
        if (partyCd.isNotEmpty) {
          print('[SyncService] 🌐 Clearing server cart for party: $partyCd');

          // Fetch current server cart for this party to get cart IDs
          try {
            final response = await http.get(
              Uri.parse("${AppConfig.baseURL}cart?partyCd=$partyCd"),
              headers: {
                "Authorization": "Bearer $token",
                'x-app-type': 'oms',
              },
            ).timeout(Duration(seconds: 10));

            if (response.statusCode == 200) {
              try {
                final cartData = jsonDecode(response.body);
                final cartItems = cartData['data'] as List? ?? [];

                print(
                    '[SyncService]   Found ${cartItems.length} cart items to delete');

                // Delete each cart item
                for (var item in cartItems) {
                  try {
                    final cartId = item['cId'];
                    if (cartId != null) {
                      final deleteResponse = await http.delete(
                        Uri.parse("${AppConfig.baseURL}cart/$cartId"),
                        headers: {
                          "Authorization": "Bearer $token",
                          'x-app-type': 'oms',
                        },
                      ).timeout(Duration(seconds: 5));

                      if (deleteResponse.statusCode == 200) {
                        print(
                            '[SyncService]   ✅ Deleted server cart item cId=$cartId');
                      } else {
                        print(
                            '[SyncService]   ⚠️ Failed to delete cart item cId=$cartId (HTTP ${deleteResponse.statusCode})');
                      }
                    }
                  } catch (itemErr) {
                    print(
                        '[SyncService]   ⚠️ Error deleting cart item: $itemErr');
                    // Continue with next item
                  }
                }
              } catch (parseErr) {
                print(
                    '[SyncService]   ⚠️ Error parsing server cart response: $parseErr');
              }
            } else {
              print(
                  '[SyncService]   ⚠️ Failed to fetch server cart (HTTP ${response.statusCode})');
            }
          } catch (fetchErr) {
            print('[SyncService]   ⚠️ Error fetching server cart: $fetchErr');
          }
        }
      } catch (e) {
        print('[SyncService] ℹ️ Server cart clear skipped (not critical): $e');
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
    final Map<String, List<dynamic>> serverCartByParty = {};
    print(
        '[SyncService] Syncing ${pendingItems.length} pending cart item(s) to server');

    for (var item in pendingItems) {
      try {
        final partyCd = item['party_cd']?.toString() ?? '';
        final itemCd = item['item_cd']?.toString() ?? '';
        if (itemCd.isEmpty || partyCd.isEmpty) continue;

        // Safety guard for legacy data: if server already has same item with same qty,
        // mark local row as synced and skip re-post to avoid quantity doubling.
        if (!serverCartByParty.containsKey(partyCd)) {
          try {
            final response = await http.get(
              Uri.parse("${AppConfig.baseURL}cart?partyCd=$partyCd"),
              headers: {
                "Authorization": "Bearer $token",
                'x-app-type': 'oms',
              },
            );

            if (response.statusCode == 200) {
              final decoded = jsonDecode(response.body) as Map<String, dynamic>;
              serverCartByParty[partyCd] = (decoded['data'] as List?) ?? [];
            } else {
              serverCartByParty[partyCd] = [];
            }
          } catch (_) {
            serverCartByParty[partyCd] = [];
          }
        }

        final localQty =
            double.tryParse(item['quantity']?.toString() ?? '0') ?? 0.0;
        final serverItems = serverCartByParty[partyCd] ?? const [];
        Map<String, dynamic>? matchingServerItem;
        for (final serverItem in serverItems) {
          if (serverItem is Map) {
            final map = Map<String, dynamic>.from(serverItem);
            final serverItemCd =
                map['itemCd']?.toString() ?? map['ITEM_CD']?.toString() ?? '';
            if (serverItemCd == itemCd) {
              matchingServerItem = map;
              break;
            }
          }
        }

        if (matchingServerItem != null) {
          final serverQty = double.tryParse(
                  matchingServerItem['quantity']?.toString() ??
                      matchingServerItem['qty']?.toString() ??
                      '0') ??
              0.0;

          if ((serverQty - localQty).abs() < 0.0001) {
            await dbInst.update(
              'cart_items',
              {'sync_status': 'synced'},
              where: 'id = ?',
              whereArgs: [item['id']],
            );
            synced++;
            print(
                '[SyncService] Skipped cart sync for $itemCd ($partyCd): already present on server with same quantity');
            continue;
          }
        }

        var cartPayload = {
          "partyCd": partyCd,
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
          // Lowercase versions (expected by API)
          'lat': latStr,
          'long': longiStr,
          'remarks': remarkStr,
          'moduleNo': moduleNoStr,
          'vouchDt': location['VOUCH_DT']?.toString() ?? '',
          'vouchTime': cleanTime,

          // Uppercase versions (kept for backward compatibility)
          'USER_CD': location['USER_CD']?.toString() ?? '',
          'VOUCH_DT': location['VOUCH_DT']?.toString() ?? '',
          'VOUCH_TIME': cleanTime,
          'LAT': latStr,
          'LONGI': longiStr,
          'REMARK': remarkStr,
          'SYNC_ID': location['SYNC_ID']?.toString() ?? '',
          'MODULE_NO': moduleNoStr,
        };

        print('[SyncService] 📤 Syncing location #${locId ?? 'unknown'}');
        print(
            '[SyncService]   User: ${payload['USER_CD']} | Punch: ${payload['REMARK']}');
        print(
            '[SyncService]   Date: ${payload['VOUCH_DT']} | Time: ${payload['VOUCH_TIME']}');
        print('[SyncService]   GPS: (${payload['LAT']}, ${payload['LONGI']})');

        print("[SyncService] ${AppConfig.baseURL}locations");
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

          if (remarkStr.toUpperCase() == 'PUNCH OUT') {
            print(
                '[SyncService] 🛑 Punch-out detected. Triggering trip-end and stopping background service...');
            await _triggerTripEnd(token); // Trip-End API hit + stops service
          }
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

  Future<void> _triggerTripEnd(String token) async {
    // 1. Retrieve the necessary data from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    // Resolve active firm via global pointer; fall back to legacy global key
    final trackingSyncId = prefs.getInt(TripPrefsHelper.currentTrackingSyncId) ??
        prefs.getInt(TripPrefsHelper.legacySyncId);
    final int? tripId = trackingSyncId != null
        ? (prefs.getInt(TripPrefsHelper.tripId(trackingSyncId)) ??
            prefs.getInt(TripPrefsHelper.legacyTripId))
        : prefs.getInt(TripPrefsHelper.legacyTripId);
    final int? syncId = trackingSyncId;

    if (tripId == null || syncId == null) {
      print(
          '[SyncService] ⚠️ No active trip found in SharedPreferences; skipping trip-end.');
      // Even if there is no trip to end, make sure the background service is
      // fully stopped so it does not keep sending location points.
      await _stopBackgroundServiceAfterTripEnd(prefs);
      return;
    }

    // 2. Prepare the payload — sync_id must be int, use timezone-aware end_time
    //    to match the format used by stopTracking() / endActiveTripOnServer().
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final absOffset = offset.abs();
    final offsetHours = absOffset.inHours.toString().padLeft(2, '0');
    final offsetMinutes = (absOffset.inMinutes % 60).toString().padLeft(2, '0');
    final String endTime =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}'
        'T${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}'
        '$sign$offsetHours:$offsetMinutes';

    final body = {
      'trip_id': tripId, // int — must match server expectation
      'sync_id': syncId, // int — NOT toString()
      'end_time': endTime, // timezone-aware local time
    };

    // 3. Hit the /location/trip/end API
    try {
      print('[SyncService] 📤 Triggering trip-end API for trip: $tripId');
      final uri = Uri.parse('${AppConfig.baseURL}location/trip/end');
      print('[SyncService] API HIT: $uri');
      print('[SyncService] Payload: $body');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'x-app-type': 'oms',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );
      print('[SyncService] Trip-end response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('[SyncService] ✅ Trip ended successfully on server.');
      } else {
        print(
            '[SyncService] ❌ Trip end API failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('[SyncService] ❌ Exception in _triggerTripEnd: $e');
    } finally {
      // 4. ALWAYS stop the background service and clear ALL SharedPreferences
      //    keys regardless of whether the API call succeeded. The punch-out was
      //    already synced to the server (the /locations call succeeded), so the
      //    service MUST NOT keep running and collecting / sending location points.
      await _stopBackgroundServiceAfterTripEnd(prefs);
    }
  }

  /// Stop the background location service and clear all active-trip
  /// SharedPreferences keys after a punch-out has been successfully synced.
  Future<void> _stopBackgroundServiceAfterTripEnd(
      SharedPreferences prefs) async {
    try {
      // Resolve the firm we're stopping so we clear firm-specific keys
      final trackingSyncId = prefs.getInt(TripPrefsHelper.currentTrackingSyncId) ??
          prefs.getInt(TripPrefsHelper.legacySyncId);

      // Mark as explicitly stopped FIRST so the background guard in _onStart
      // will immediately self-terminate if the plugin tries to restart.
      if (trackingSyncId != null) {
        await prefs.setBool(
            TripPrefsHelper.explicitlyStopped(trackingSyncId), true);
        await TripPrefsHelper.clearFirmKeys(prefs, trackingSyncId);
      }
      // Always clear legacy keys to cover migration path
      await TripPrefsHelper.clearLegacyKeys(prefs);
      await prefs.remove(TripPrefsHelper.currentTrackingSyncId);

      print('[SyncService] ✅ SharedPreferences cleared after trip-end.');
    } catch (e) {
      print('[SyncService] ⚠️ Could not clear SharedPreferences: $e');
    }
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

        // Business rule: IN/OUT (type 1/3) must never carry oId.
        if (trackingType != '2' && !_isEmptyOrderId(tracking['oId'])) {
          final dbInst = await db.database;
          await dbInst.update(
            'order_tracking',
            {'oId': null},
            where: 'locId = ?',
            whereArgs: [trackingId],
          );
          print(
              '[SyncService] 🧹 Cleared unexpected oId from non-PLACE tracking #$trackingId (type=$trackingType)');
        }

        // Match EXACT same structure as online payload (order_tracking_service.dart)
        final payload = {
          'accCd': accCd,
          'lat': tracking['LAT']?.toString() ?? '0.0',
          'longi': tracking['LONGI']?.toString() ?? '0.0',
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
        print('[SyncService]   Party: ${payload['accCd']}');
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
            '[SyncService]   Party: ${payload['accCd']} | oId: ${payload['oId']} | VOUCH_DT=$vouchDt, VOUCH_TIME=$cleanTime');
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

        try {
          final respData = jsonDecode(response.body);
          final serverRemark = respData['data']?['REMARK']?.toString() ?? 'N/A';
          final serverOId = respData['data']?['oId']?.toString() ?? 'null';
          final serverLocId = respData['data']?['locId']?.toString() ?? 'N/A';
          print(
              '[SyncService] ✅ PLACE ORDER server stored: locId=$serverLocId, REMARK=$serverRemark, oId=$serverOId');
        } catch (e) {
          print('[SyncService] Could not parse PLACE ORDER response: $e');
        }

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
