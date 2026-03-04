import 'database_helper.dart';

class CartService {
  final DatabaseHelper db = DatabaseHelper();

  /// Add item to local cart, matching server `cart` table structure.
  Future<int> addToCart({
    required String partyCd,
    required String itemCd,
    required double quantity,
    required double rate,
    required double nrate,
    required double lrate,
    required double amount,
    String otherDesc = '',
    String fld5 = '',
    String itemName = '',
  }) async {
    return await db.insertOrUpdateCartItem({
      'party_cd': partyCd,
      'item_cd': itemCd,
      'quantity': quantity,
      'rate': rate,
      'nrate': nrate,
      'lrate': lrate,
      'amount': amount,
      'other_desc': otherDesc,
      'fld5': fld5,
      'item_name': itemName,
      'last_updated': DateTime.now().millisecondsSinceEpoch,
      'sync_status': 'pending',
    });
  }

  Future<List<Map<String, dynamic>>> getCartItems({String? partyId}) async {
    if (partyId != null && partyId.isNotEmpty) {
      return await db.getCartItems(partyId: partyId);
    }
    // Return all items if no party filter specified
    return await db.getCartItems();
  }

  Future<void> updateCartItemQuantity(int cartItemId, int newQuantity) async {
    final database = await DatabaseHelper().database;
    await database.update(
      'cart_items',
      {
        'quantity': newQuantity,
        'last_updated': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [cartItemId],
    );
  }

  Future<void> removeCartItem(int cartItemId) async {
    final database = await DatabaseHelper().database;
    await database.delete(
      'cart_items',
      where: 'id = ?',
      whereArgs: [cartItemId],
    );
  }

  Future<void> clearCart() async {
    await db.clearCart();
  }

  Future<double> getCartTotal() async {
    final cartItems = await getCartItems();
    double total = 0.0;
    for (var item in cartItems) {
      total += (item['amount'] as num? ?? 0.0);
    }
    return total;
  }
}
