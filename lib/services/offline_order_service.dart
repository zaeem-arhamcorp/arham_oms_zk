import 'dart:convert';
import 'database_helper.dart';
import 'cart_service.dart';

class OfflineOrderService {
  final DatabaseHelper db = DatabaseHelper();
  final CartService cartService = CartService();

  Future<int> saveOrderOffline({
    required String partyId,
    required double totalAmount,
    required double latitude,
    required double longitude,
    String? remarks,
  }) async {
    // Get current cart items for this party only
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

    print(
        '[OfflineOrderService] Saved offline order $orderId with ${orderItems.length} item(s)');
    return orderId;
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
