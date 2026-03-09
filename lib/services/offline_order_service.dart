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
    // STEP 1: CHECK LICENSE LIMITS BEFORE ALLOWING OFFLINE ORDER
    // ============================================================================
    // Enforce limit immediately while offline to prevent exceeding order quota
    String? licenseWarning;

    try {
      final licenseInfo = await db.getLicenseInfo(syncId);

      if (licenseInfo != null) {
        final serverOrderCount = licenseInfo['orderCount'] as int? ?? 0;
        final maxOrders = licenseInfo['maxOrders'] as int? ?? 0;
        final currentOfflineOrderCount =
            licenseInfo['offline_order_count'] as int? ?? 0;

        // Calculate total after this order
        final totalOrdersAfterThisOrder =
            serverOrderCount + currentOfflineOrderCount + 1;

        print('[OfflineOrder] ╔════════════════════════════════════════════');
        print('[OfflineOrder] ║ LICENSE CHECK (OFFLINE ENFORCEMENT)');
        print('[OfflineOrder] ║ Max Orders Limit: $maxOrders');
        print('[OfflineOrder] ║ Server Order Count: $serverOrderCount');
        print(
            '[OfflineOrder] ║ Current Offline Count: $currentOfflineOrderCount');
        print(
            '[OfflineOrder] ║ Will BE After This Order: $totalOrdersAfterThisOrder');
        print('[OfflineOrder] ╚════════════════════════════════════════════');

        if (totalOrdersAfterThisOrder > maxOrders) {
          // EXCEEDED LIMIT - BLOCK THIS ORDER
          final msg =
              'You have been blacklisted! You have exceeded your order limit ($maxOrders orders). Current: $serverOrderCount (server) + $currentOfflineOrderCount (offline) = ${serverOrderCount + currentOfflineOrderCount}. Please contact support.';
          print('[OfflineOrder] ❌ LIMIT EXCEEDED - LOGOUT NOW!');
          print(
              '[OfflineOrder] Total After This Order ($totalOrdersAfterThisOrder) > Max Limit ($maxOrders)');
          throw Exception(msg);
        }

        if (totalOrdersAfterThisOrder == maxOrders) {
          // FINAL ORDER: Allow this order but will need logout after save
          licenseWarning =
              '⚠️ License Limit: This order brings you to your maximum limit. You will be logged out after this order.';
          print('[OfflineOrder] ⚠️ WARNING - FINAL ORDER (WILL LOGOUT AFTER SAVE)!');
          print('[OfflineOrder] $licenseWarning');
        } else if (totalOrdersAfterThisOrder == maxOrders - 1) {
          // WARNING: next order will hit the limit
          licenseWarning =
              '⚠️ License Limit Warning: Only 1 order remaining after this.';
          print('[OfflineOrder] ⚠️ WARNING - LIMIT APPROACHING!');
          print('[OfflineOrder] $licenseWarning');
        }

        print(
            '[OfflineOrder] ✅ Order allowed to proceed. Will be: $totalOrdersAfterThisOrder/${maxOrders}');

        // Increment offline count BEFORE saving the order
        try {
          await db.incrementOfflineOrderCount(syncId);
          print(
              '[OfflineOrder] ✅ PRE-INCREMENTED offline order count for SYNC_ID=$syncId');
        } catch (e) {
          print(
              '[OfflineOrder] ❌ CRITICAL: Could not increment offline order count: $e');
          rethrow;
        }
      } else {
        print(
            '[OfflineOrder] ⚠️ No cached license info found for SYNC_ID=$syncId');
        print(
            '[OfflineOrder] ℹ️ Allowing order to proceed without offline license validation');
        print(
            '[OfflineOrder] ⚠️ (You must download data via Go Offline button first)');
      }
    } catch (e) {
      if (e.toString().contains('exceeded your order limit')) {
        rethrow; // Re-throw only exceeded exceptions
      }
      print('[OfflineOrder] ⚠️ License check error: $e');
      print('[OfflineOrder] ℹ️ Allowing order (graceful fallback)');
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

    int orderId = await db.insertOfflineOrder({
      'server_party_id': partyId,
      'total_amount': totalAmount,
      'order_date': DateTime.now().millisecondsSinceEpoch,
      'latitude': latitude,
      'longitude': longitude,
      'sync_status': 'pending',
      'sync_attempts': 0,
      'last_sync_attempt': null,
      'error_message': null,
      'remarks': remarks,
    });

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
      };
    }).toList();

    await db.insertOrderItems(orderItems);

    // Clear the local cart after saving order
    await cartService.clearCart();

    // Note: offline order count was ALREADY incremented BEFORE saving the order
    // to ensure the next check includes this order in the total count

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
