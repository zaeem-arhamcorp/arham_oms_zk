import 'database_helper.dart';
import 'package:arham_corporation/models/product.dart';

class ProductCacheService {
  final DatabaseHelper db = DatabaseHelper();

  Future<void> cacheProducts(List<Products> productsFromApi) async {
    List<Map<String, dynamic>> list = [];

    for (var p in productsFromApi) {
      list.add({
        "server_id": p.id,
        "name": p.title ?? '',
        "price": p.price?.toDouble() ?? 0.0,
        "category": p.category ?? '',
        "image_url": p.thumbnail ?? '',
        "last_updated": DateTime.now().millisecondsSinceEpoch,
        "sync_status": 'synced'
      });
    }

    await db.insertProducts(list);
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    return await db.getProducts();
  }

  Future<List<Map<String, dynamic>>> getProductsByCategory(
      String category) async {
    final db = await DatabaseHelper().database;
    return await db.query(
      'products',
      where: 'category = ?',
      whereArgs: [category],
    );
  }
}
