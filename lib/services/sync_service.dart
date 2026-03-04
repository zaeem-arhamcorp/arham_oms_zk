import 'database_helper.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:arham_corporation/config/app_config.dart';

class SyncService {
  final DatabaseHelper db = DatabaseHelper();

  Future<void> syncOrders(String token) async {
    final pendingOrders = await db.getPendingOrders();

    for (var order in pendingOrders) {
      await _syncOrderWithRetry(order, token);
    }
  }

  Future<void> _syncOrderWithRetry(Map<String, dynamic> order, String token,
      {int maxRetries = 3}) async {
    int attempt = 0;
    int delaySeconds = 1; // Start with 1 second delay

    while (attempt < maxRetries) {
      try {
        await _syncSingleOrder(order, token);
        return; // Success, exit retry loop
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) {
          // Max retries reached, update with final error
          await db.updateRetry(order['id'], "Max retries exceeded: $e");
          print(
              "Failed to sync order ${order['id']} after $maxRetries attempts: $e");
          return;
        }

        // Wait before retry with exponential backoff
        await Future.delayed(Duration(seconds: delaySeconds));
        delaySeconds *= 2; // Double the delay for next attempt
        print(
            "Retrying order ${order['id']} in ${delaySeconds}s (attempt $attempt/$maxRetries)");
      }
    }
  }

  Future<void> _syncSingleOrder(
      Map<String, dynamic> order, String token) async {
    final items = await db.getOrderItems(order['id']);

    // Step 1: Add each item to the server cart (mirrors online add-to-cart flow)
    for (var item in items) {
      // Ensure item code is present. If missing, try to recover from local product cache
      String itemCd = item["item_cd"]?.toString() ?? '';
      final itemName = item['item_name']?.toString() ?? '';

      if (itemCd.isEmpty && itemName.isNotEmpty) {
        try {
          final cached = await db.getCachedProducts();
          for (var p in cached) {
            final name = (p['item_name'] ?? '').toString();
            if (name.isNotEmpty && name == itemName) {
              try {
                final prodJson = p['product_json'] as String?;
                if (prodJson != null && prodJson.isNotEmpty) {
                  final parsed = jsonDecode(prodJson) as Map<String, dynamic>;
                  // Try common keys
                  itemCd = (parsed['ITEM_CD'] ??
                              parsed['itemCd'] ??
                              parsed['item_cd'])
                          ?.toString() ??
                      '';
                  if (itemCd.isNotEmpty) break;
                }
              } catch (_) {}
            }
          }
        } catch (e) {
          print('Error while trying to recover itemCd from cache: $e');
        }
      }

      var cartPayload = {
        "partyCd": order["server_party_id"],
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

      print(
          "Syncing cart item ${cartPayload['itemCd']} for order ${order['id']}: $cartPayload");

      var cartResponse = await http.post(
        Uri.parse("${AppConfig.baseURL}cart"),
        headers: {
          "Authorization": "Bearer $token",
          'x-app-type': 'oms',
        },
        body: cartPayload,
      );

      print(
          "Cart sync response for ${cartPayload['itemCd']}: ${cartResponse.statusCode}");

      if (cartResponse.statusCode == 401) {
        throw Exception("Authentication expired");
      }
      if (cartResponse.statusCode != 200) {
        throw Exception(
            "Failed to add item ${cartPayload['itemCd']} to cart: HTTP ${cartResponse.statusCode}");
      }
    }

    // Step 2: Place the order (server reads items from its own cart)
    var orderPayload = {
      "partyCd": order["server_party_id"],
      "lat": order["latitude"]?.toString() ?? '0',
      "longi": order["longitude"]?.toString() ?? '0',
      "narration": order["remarks"] ?? "",
      "moduleNo": "205",
    };

    print("Syncing order ${order['id']} with payload: $orderPayload");

    var response = await http.post(
      Uri.parse("${AppConfig.baseURL}orders"),
      headers: {
        "Authorization": "Bearer $token",
        'x-app-type': 'oms',
      },
      body: orderPayload,
    );

    print("Order sync response: ${response.statusCode} - ${response.body}");

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final serverOrderId = data["data"]["oId"];

      await db.updateOrderStatus(
        order['id'],
        'synced',
        serverOrderId,
      );
      print(
          "Order ${order['id']} synced successfully with server ID: $serverOrderId");
      // Clean up local offline order and any related cart items for the party
      try {
        await db.deleteOfflineOrder(order['id']);
        // Also clear any leftover cart items for this party
        if (order['server_party_id'] != null) {
          await db.clearCartForParty(order['server_party_id'].toString());
        }
        print('Local offline order ${order["id"]} deleted after sync');
      } catch (e) {
        print('Error cleaning up local order ${order["id"]}: $e');
      }
    } else {
      throw Exception("HTTP ${response.statusCode}: ${response.body}");
    }
  }

  // Method to check for data inconsistencies between local and server
  Future<List<String>> checkDataInconsistencies(String token) async {
    List<String> inconsistencies = [];

    try {
      // Check for orders that exist locally but not on server
      final localOrders = await db.getPendingOrders();
      // This would require fetching server orders and comparing
      // For now, just check sync status
      for (var order in localOrders) {
        if (order['sync_attempts'] > 5) {
          inconsistencies.add(
              "Order ${order['id']} has failed sync ${order['sync_attempts']} times");
        }
      }

      // Check for orders marked as synced but no server_order_id
      final allOrders =
          await db.database.then((db) => db.query('offline_orders'));
      for (var order in allOrders) {
        if (order['sync_status'] == 'synced' &&
            order['server_order_id'] == null) {
          inconsistencies.add(
              "Order ${order['id']} marked as synced but missing server ID");
        }
      }
    } catch (e) {
      inconsistencies.add("Error checking inconsistencies: $e");
    }

    return inconsistencies;
  }
}
