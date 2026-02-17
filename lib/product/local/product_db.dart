// import 'package:get/get.dart';
// import 'package:get_storage/get_storage.dart';

// import '../model/product_model.dart';

// class LocalStorageService {
//   static final GetStorage _box = GetStorage();

//   /// Save products to local storage
//   static Future<void> saveProducts(List<ProductItem> products) async {
//     try {
//       final productsJson = products.map((product) => product.toJson()).toList();
//       await _box.write('products', productsJson);
//     } catch (e) {
//       throw Exception('Failed to save products to local storage: $e');
//     }
//   }

//   /// Load products from local storage
//   static Future<void> loadStoredProducts(
//       RxList<ProductItem> products, RxList<ProductItem> filteredProducts) async {
//     try {
//       final productsJson = _box.read<List<dynamic>>('products');

//       if (productsJson != null) {
//         final storedProducts = productsJson
//             .map((json) => ProductItem.fromJson(json as Map<String, dynamic>))
//             .toList();

//         products.assignAll(storedProducts);
//         filteredProducts.assignAll(storedProducts);
//       }
//     } catch (e) {
//       throw Exception('Failed to load products from local storage: $e');
//     }
//   }

//   /// Save departments to local storage
//   static Future<void> saveDepartments(List<Department> departments) async {
//     try {
//       final departmentsJson =
//           departments.map((department) => department.toJson()).toList();
//       await _box.write('departments', departmentsJson);
//     } catch (e) {
//       throw Exception('Failed to save departments to local storage: $e');
//     }
//   }

//   /// Load departments from local storage
//   static Future<void> loadStoredDepartments(RxList<Department> departments) async {
//     try {
//       final departmentsJson = _box.read<List<dynamic>>('departments');

//       if (departmentsJson != null) {
//         final storedDepartments = departmentsJson
//             .map((json) => Department.fromJson(json as Map<String, dynamic>))
//             .toList();

//         departments.assignAll(storedDepartments);
//       }
//     } catch (e) {
//       throw Exception('Failed to load departments from local storage: $e');
//     }
//   }
// }
