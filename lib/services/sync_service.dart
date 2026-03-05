import 'database_helper.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/helper/network_helper.dart';

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

    // Step 1: Add each item to the server cart
    for (var item in validItems) {
      final itemCd = item['item_cd'].toString();

      var cartPayload = {
        "partyCd": partyCd,
        "itemCd": itemCd,
        "qty": item["quantity"]?.toString() ?? '0',
        "rate": item["rate"]?.toString() ?? '0',
        "lrate": item["lrate"]?.toString() ?? '0',
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
        serverOrderId = data["data"]?["oId"] ?? data["oId"];
      } catch (_) {}

      await db.updateOrderStatus(order['id'], 'synced', serverOrderId);
      print(
          '[SyncService] Order ${order['id']} synced → server ID: $serverOrderId');

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
      print('[SyncService] No internet — skipping location sync');
      return {'synced': 0, 'failed': 0};
    }

    final pendingLocations = await db.getPendingLocations();
    print('[SyncService] Found ${pendingLocations.length} pending location(s)');

    for (var location in pendingLocations) {
      try {
        final locId = location['locId'];
        
        // Prepare payload for server
        var payload = {
          'USER_CD': location['USER_CD']?.toString() ?? '',
          'VOUCH_DT': location['VOUCH_DT']?.toString() ?? '',
          'VOUCH_TIME': location['VOUCH_TIME']?.toString() ?? '00:00:00',
          'LAT': location['LAT']?.toString() ?? '0.0',
          'LONGI': location['LONGI']?.toString() ?? '0.0',
          'REMARK': location['REMARK']?.toString() ?? '',
          'SYNC_ID': location['SYNC_ID']?.toString() ?? '',
          'MODULE_NO': location['MODULE_NO']?.toString() ?? '205',
        };

        print('[SyncService] POST location: $payload');

        // Post to server
        var response = await http.post(
          Uri.parse("${AppConfig.baseURL}locations"),
          headers: {
            "Authorization": "Bearer $token",
            'x-app-type': 'oms',
          },
          body: payload,
        );

        print('[SyncService] Location response ${response.statusCode}: ${response.body}');

        if (response.statusCode == 200 || response.statusCode == 201) {
          // Success: mark as synced and delete from local DB
          await db.updateLocationSyncStatus(locId, 'synced', null);
          await db.deleteLocation(locId);
          synced++;
          print('[SyncService] Location $locId synced and deleted locally');
        } else if (response.statusCode == 401) {
          print('[SyncService] Auth expired during location sync');
          break;
        } else {
          failed++;
          print('[SyncService] Location sync failed: HTTP ${response.statusCode}');
          // Keep local copy for retry
        }
      } catch (e) {
        failed++;
        print('[SyncService] Error syncing location: $e');
        // Keep local copy on error
      }
    }

    print('[SyncService] Location sync complete: synced=$synced, failed=$failed');
    return {'synced': synced, 'failed': failed};
  }
}

