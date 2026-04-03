import 'dart:convert';
import 'database_helper.dart';
import 'cart_service.dart';
import 'offline_order_service.dart' as db;

class OfflineOrderService {
  final DatabaseHelper db = DatabaseHelper();
  final CartService cartService = CartService();

  Future<int> saveOrderOffline({
    required String partyId,
    required double totalAmount,
    required double latitude,
    required double longitude,
    required int syncId,
    String? remarks,
  }) async {
    // ============================================================================
    // STEP 1: LOG LICENSE INFO FOR REFERENCE (NO OFFLINE ENFORCEMENT)
    // ============================================================================
    // NOTE: Multiple users share the same firm license, so we allow ALL offline
    // orders to be saved. Blacklisting happens only AFTER sync when we know
    // the total orders from all users in the firm exceed the limit.

    try {
      final licenseInfo = await db.getLicenseInfo(syncId);

      if (licenseInfo != null) {
        final serverOrderCount = licenseInfo['orderCount'] as int? ?? 0;
        final maxOrders = licenseInfo['maxOrders'] as int? ?? 0;

        print('[OfflineOrder] ╔════════════════════════════════════════════');
        print('[OfflineOrder] ║ LICENSE INFO (FOR REFERENCE)');
        print('[OfflineOrder] ║ Max Orders Limit: $maxOrders');
        print('[OfflineOrder] ║ Current Server Orders: $serverOrderCount');
        print('[OfflineOrder] ║ Remaining: ${maxOrders - serverOrderCount}');
        print(
            '[OfflineOrder] ║ NOTE: Allowing offline order (multi-user firm)');
        print('[OfflineOrder] ║ Blacklisting checked AFTER sync');
        print('[OfflineOrder] ╚════════════════════════════════════════════');
      } else {
        print(
            '[OfflineOrder] ℹ️ No cached license info - allowing order to proceed');
      }
    } catch (e) {
      print('[OfflineOrder] ℹ️ License check skipped: $e');
    }

    // GET CURRENT CART - rest of the method proceeds as before
    final cartItems = await cartService.getCartItems(partyId: partyId);

    if (cartItems.isEmpty) {
      throw Exception('Cart is empty');
    }

    // Validate & enrich: ensure every item has item_cd before saving
    final productsCache = await db.getCachedProducts();
    List<Map<String, dynamic>> validatedItems = [];

    for (var item in cartItems) {
      String itemCd = (item['item_cd'] ?? '').toString().trim();
      String itemName = (item['item_name'] ?? '').toString().trim();

      // If item_cd is missing, try to recover from products_cache
      if (itemCd.isEmpty && itemName.isNotEmpty) {
        for (var p in productsCache) {
          final cacheName = (p['item_name'] ?? '').toString().trim();
          if (cacheName.isNotEmpty &&
              cacheName.toLowerCase() == itemName.toLowerCase()) {
            itemCd = (p['item_cd'] ?? '').toString();
            break;
          }
          // Also try parsing product_json
          try {
            final json = jsonDecode(p['product_json'].toString())
                as Map<String, dynamic>;
            final jsonName = (json['ITEM_NAME'] ?? '').toString().trim();
            if (jsonName.isNotEmpty &&
                jsonName.toLowerCase() == itemName.toLowerCase()) {
              itemCd = (json['ITEM_CD'] ?? p['item_cd'] ?? '').toString();
              break;
            }
          } catch (_) {}
        }
      }

      // If still empty, try to get item_cd from products_cache by item_cd match
      if (itemCd.isEmpty) {
        print(
            '[OfflineOrderService] WARNING: item_cd empty for "${itemName}" — order item will be saved but may fail sync');
      }

      validatedItems.add({
        ...item,
        'item_cd': itemCd,
        'item_name': itemName,
      });
    }

    // Insert the offline order header
    // Log coordinates to confirm they're captured at offline-order time
    try {
      print(
          '[OfflineOrderService] Saving offline order — party:$partyId lat:$latitude long:$longitude total:$totalAmount');
    } catch (_) {}

    // CRITICAL: Capture order creation time PRECISELY
    final now = DateTime.now();
    final orderDateMs = now.millisecondsSinceEpoch;
    final orderDtStr = now.toString().split(' ')[0]; // YYYY-MM-DD
    final orderTimeStr =
        now.toString().split(' ')[1].split('.').first; // HH:MM:SS

    print('[OfflineOrderService] 📅 CAPTURING ORDER TIME:');
    print('[OfflineOrderService]   DateTime.now(): $now');
    print('[OfflineOrderService]   millisecondsSinceEpoch: $orderDateMs');
    print('[OfflineOrderService]   Formatted as: $orderDtStr $orderTimeStr');

    int orderId = await db.insertOfflineOrder({
      'server_party_id': partyId,
      'total_amount': totalAmount,
      'order_date':
          orderDateMs, // Always set with current time - DO NOT let this be NULL
      'latitude': latitude,
      'longitude': longitude,
      'sync_status': 'pending',
      'sync_attempts': 0,
      'last_sync_attempt': null,
      'error_message': null,
      'remarks': remarks,
      'SYNC_ID': syncId,
    });

    print('[OfflineOrderService] ✅ ORDER SAVED WITH TIMESTAMP:');
    print('[OfflineOrderService]   orderId=$orderId | order_date=$orderDateMs');

    // Insert order items matching server `ordritm` structure
    List<Map<String, dynamic>> orderItems = validatedItems.map((item) {
      return {
        'order_id': orderId,
        'item_cd': item['item_cd'] ?? '',
        'item_name': item['item_name'] ?? '',
        'quantity': item['quantity'],
        'rate': item['rate'],
        'nrate': item['nrate'],
        'lrate': item['lrate'],
        'amount': item['amount'],
        'other_desc': item['other_desc'] ?? '',
        'fld5': item['fld5'] ?? '',
        'stockist': item['stockist'] ?? '',
      };
    }).toList();

    await db.insertOrderItems(orderItems);

    // Clear the local cart after saving order
    await cartService.clearCart();

    // Increment offline_order_count for tracking (not for blocking)
    // This allows us to show accurate count of pending offline orders
    try {
      await db.incrementOfflineOrderCount(syncId);
      print(
          '[OfflineOrderService] Incremented offline_order_count for tracking');
    } catch (e) {
      print(
          '[OfflineOrderService] Warning: Could not increment offline_order_count: $e');
    }

    print(
        '[OfflineOrderService] Saved offline order $orderId with ${orderItems.length} item(s)');
    return orderId;
  }

  /// Check current license status and return warning message if needed
  Future<String?> getOfflineLicenseWarning(int syncId) async {
    try {
      final licenseInfo = await db.getLicenseInfo(syncId);

      if (licenseInfo != null) {
        final serverOrderCount = licenseInfo['orderCount'] as int? ?? 0;
        final maxOrders = licenseInfo['maxOrders'] as int? ?? 0;
        final offlineOrderCount =
            licenseInfo['offline_order_count'] as int? ?? 0;
        final totalOrders = serverOrderCount + offlineOrderCount;

        print(
            '[OfflineOrderService] License check for warning: server=$serverOrderCount, offline=$offlineOrderCount, total=$totalOrders, max=$maxOrders');

        // EXACT LIMIT HIT - Show urgent popup message
        if (totalOrders == maxOrders) {
          final msg =
              'LIMIT_HIT:Sync your data now or your order data might be lost. Current: $totalOrders/${maxOrders} orders.';
          print('[OfflineOrderService] ⛔ LIMIT EXACTLY HIT: $msg');
          return msg;
        }

        // 1 remaining warning
        if (totalOrders == maxOrders - 1) {
          final msg =
              '⚠️ License Limit Warning\n\nYou have only 1 order remaining. Current: $totalOrders/${maxOrders} orders.\n\nPlease sync your orders or contact support.';
          print('[OfflineOrderService] Warning message: $msg');
          return msg;
        }
      }
    } catch (e) {
      print('[OfflineOrderService] Error getting license warning: $e');
    }

    return null;
  }

  Future<List<Map<String, dynamic>>> getPendingOrders() async {
    return await db.getPendingOrders();
  }

  Future<Map<String, dynamic>?> getOrderWithItems(int orderId) async {
    final orders = await db.getPendingOrders();

    Map<String, dynamic>? order;

    try {
      order = orders.firstWhere((o) => o['id'] == orderId);
    } catch (e) {
      return null;
    }

    final items = await db.getOrderItems(orderId);
    return {
      ...order,
      'items': items,
    };
  }
}
