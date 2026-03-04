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

    // Insert the offline order header
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
    List<Map<String, dynamic>> orderItems = cartItems.map((item) {
      return {
        'order_id': orderId,
        'item_cd': item['item_cd'],
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
