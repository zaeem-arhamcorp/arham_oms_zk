import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:arham_corporation/helper/network_helper.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/services/database_helper.dart';
import 'package:arham_corporation/services/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_config.dart';
import '../../models/narrationModal.dart';
import '../../models/partynameModal.dart';
import '../../views/loginpage.dart';
import '../model/product_model.dart';

class ProductController extends GetxController {
  var showSearch = false.obs;
  var showDeptSearch = false.obs;
  var isLoading = false.obs;
  var isKeyboardOpen = true.obs;
  var isDpLoading = false.obs;
  var isPartyLoading = false.obs;
  var errorMessage = ''.obs;

  var selectedPartyName = ''.obs;
  var selectedPartyId = ''.obs;

  // Stockist selection (for groupCd=136)
  var selectedStockistName = ''.obs;
  var selectedStockistId = ''.obs;
  var selectedStockistAddress = ''.obs;
  var selectedStockistCity = ''.obs;
  var selectedStockistMobile = ''.obs;
  var selectedStockistPersonName = ''.obs;
  var selectedStockistPincode = ''.obs;
  var hasStockistAccess = false.obs;
  var stockists = <DatumPartyname>[].obs;
  var isStockistLoading = false.obs;

  final products = RxList<ProductItem>();
  final filteredProducts = RxList<ProductItem>();
  var otherDescOptions = <DatumNarration>[].obs;
  var fld5DescOptions = <DatumNarration>[].obs;
  var filterParty = <DatumPartyname>[].obs;
  var party = <DatumPartyname>[].obs;
  var searchQuery = ''.obs;

  final deptment = RxList<Department>();
  final RxList<Department> filteredDepartments = <Department>[].obs;
  final RxString selectedChip = ''.obs;
  var isAddingToCart = false.obs;

  var isDownloadingExportPdf = false.obs;
  var isDownloadingPartyExportPdf = false.obs;

  // Controllers
  final searchController = TextEditingController();
  final focusNode = FocusNode();

  final departmentController = TextEditingController();
  final departmentFocusNode = FocusNode();

  // Dio instance
  final Dio dio = Dio();

  final ub = Provider.of<UserProvider>(Get.context!, listen: false);

  void toggleSearch1() {
    showSearch.value = !showSearch.value;
    showDeptSearch.value = false;
  }

  void searchDepartments(String query) {
    if (query.isEmpty) {
      filteredDepartments.value = deptment; // Reset to full list when cleared
    } else {
      filteredDepartments.value = deptment
          .where((dept) =>
              dept.deptName.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
  }

  void toggleSearch() {
    if (showDeptSearch.value) {
      print('1');
      showDeptSearch.value = false; // Close department search
      showSearch.value = true; // Switch to normal search
      departmentController.clear();
      filteredDepartments.value = deptment; // Reset to full list when cleared
    } else if (showSearch.value) {
      print('2');
      showSearch.value = false; // Close normal search
    } else {
      print('3');
      showSearch.value = true; // Open normal search
    }
  }

  Future<void> fetchProductsFromAPI() async {
    isLoading.value = true;
    try {
      final bool online = await NetworkHelper.hasInternet();
      print("Network check: online=$online");

      if (online) {
        // ONLINE MODE: Fetch from API and cache for offline use
        final response = await _getRequest(endpoint: 'export/products');
        if (response != null) {
          final apiResponse = ProductResponse.fromJson(response);
          final productsData = apiResponse.data;
          print("Fetched ${productsData.length} products from API");

          // Cache products to local database for offline access
          await _cacheProductsForOffline(productsData);

          products.assignAll(productsData);
          filteredProducts.assignAll(productsData);
          print("Displayed ${productsData.length} products");
        } else {
          print("API response was null, attempting to load from cache");
          await _loadProductsFromCache();
        }
      } else {
        // OFFLINE MODE: Load from local cache
        print("Offline mode: loading products from cache");
        await _loadProductsFromCache();
      }
    } catch (e, stack) {
      print("Critical error in fetchProductsFromAPI: $e");
      print("Stack: $stack");
      log("Failed to fetch products from API: $e");
      // On error, still try to load from cache
      try {
        await _loadProductsFromCache();
      } catch (cacheError) {
        print("Also failed to load from cache: $cacheError");
      }
    } finally {
      isLoading.value = false;
    }
  }

  /// Cache products to local database with full JSON
  /// Stores item_cd, product JSON, department code, and item_name for indexing
  Future<void> _cacheProductsForOffline(List<ProductItem> productsData) async {
    try {
      List<Map<String, dynamic>> productsToCache = [];

      for (var product in productsData) {
        try {
          // Store product JSON using API-style keys so ProductItem.fromJson
          // can reconstruct objects correctly when loading from cache.
          // IMPORTANT: Include ALL fields that ProductItem.fromJson() expects!
          final productJsonMap = {
            'ITEM_CD': product.itemCd,
            'ITEM_CD2': product.itemCd2,
            'ITEM_NAME': product.itemName,
            'ITEM_SNAME': product.itemSname,
            'ITEM_LNAME': product.itemLname,
            'DEPT_CD': product.deptCd,
            'NRATE': product.nrate,
            'SRATE1': product.srate1,
            'SRATE3': product.srate3,
            'PRATE': product.prate,
            'PDISC': product.pdisc,
            'ITEM_BRAND': product.itemBrand,
            'ITEM_CAT': product.itemCat,
            'item_images': product
                .itemImages, // ✓ CRITICAL: Must be lowercase, not ITEM_IMAGES
            'C_STK': product.cStk,
            'OR_STK': product.orStk,
            'AVL_STK': product.avlStk,
            'SDISC': product.sdisc,
            'SDISC1': product.sdisc1,
            // MISSING FIELDS NOW ADDED:
            'EX_DT': product.exDt, // EXPIRY DATE - critical for display!
            'RACK_NO': product.rackNo,
            'ITEM_GRADE': product.itemGrade,
            'ITEM_DESC': product.itemDesc,
            'GST_PERC': product.gstPerc, // GST percentage
            'T_LAND': product.tLAND,
            'FRML_SRT1': product.frmlSrt1,
            'SYNC_ID': product.syncId,
            'HSN_NO': product.hsnNo, // HSN Code - required for offline display
            'deptment': product.deptment.toJson(),
          };

          productsToCache.add({
            'item_cd': product.itemCd,
            'product_json': jsonEncode(productJsonMap),
            'cached_at': DateTime.now().millisecondsSinceEpoch,
            'department_code': product.deptCd,
            'item_name': product.itemName,
          });
        } catch (itemError) {
          print(
              "Error serializing product ${product.itemCd}: $itemError. Skipping...");
          // Skip this product and continue
        }
      }

      if (productsToCache.isNotEmpty) {
        // Cache to database
        await DatabaseHelper().cacheProductsJson(productsToCache);
        print("Cached ${productsToCache.length} products for offline use");
      } else {
        print("Warning: No products were successfully serialized for caching");
      }
    } catch (e, stack) {
      print("Error caching products: $e");
      print("Stack: $stack");
      // Don't fail the entire fetch if caching fails
    }
  }

  /// Load products from local cache (offline mode)
  Future<void> _loadProductsFromCache() async {
    try {
      final cachedProducts = await DatabaseHelper().getCachedProducts();
      print("Retrieved ${cachedProducts.length} cached products from DB");

      if (cachedProducts.isEmpty) {
        log("No cached products available for offline mode");
        return;
      }

      // Reconstruct ProductItem list from cached JSON
      List<ProductItem> reconstructedProducts = [];
      int successCount = 0;
      int failCount = 0;

      for (var cachedProduct in cachedProducts) {
        try {
          final productJsonStr = cachedProduct['product_json'] as String?;
          if (productJsonStr == null || productJsonStr.isEmpty) {
            print(
                "Warning: Empty product JSON for item ${cachedProduct['item_cd']}");
            failCount++;
            continue;
          }

          var productJson = jsonDecode(productJsonStr);
          ProductItem productItem;

          try {
            productItem = ProductItem.fromJson(productJson);
            // If itemCd is empty, attempt fallback mapping from camelCase keys
            if (productItem.itemCd.isEmpty) {
              final fallback = <String, dynamic>{};
              for (var entry in productJson.entries) {
                final k = entry.key.toString();
                final v = entry.value;
                // convert camelCase to upper snake-like keys used by fromJson
                if (k == 'itemCd') fallback['ITEM_CD'] = v;
                if (k == 'itemName') fallback['ITEM_NAME'] = v;
                if (k == 'nrate') fallback['NRATE'] = v;
                if (k == 'deptCd') fallback['DEPT_CD'] = v;
                if (k == 'itemSname') fallback['ITEM_SNAME'] = v;
                if (k == 'itemLname') fallback['ITEM_LNAME'] = v;
                if (k == 'itemBrand') fallback['ITEM_BRAND'] = v;
                if (k == 'itemCat') fallback['ITEM_CAT'] = v;
                if (k == 'hsnNo') fallback['HSN_NO'] = v;
                if (k == 'item_images') fallback['item_images'] = v;
                if (k == 'deptment') fallback['deptment'] = v;
              }
              // merge remaining keys
              for (var entry in productJson.entries) {
                if (!fallback.containsKey(entry.key))
                  fallback[entry.key] = entry.value;
              }
              productItem = ProductItem.fromJson(fallback);
            }
            reconstructedProducts.add(productItem);
          } catch (e) {
            failCount++;
            print(
                "Error parsing cached product ${cachedProduct['item_cd']}: $e");
            continue;
          }
          successCount++;
        } catch (parseError) {
          failCount++;
          print(
              "Error parsing cached product ${cachedProduct['item_cd']}: $parseError");
          print(
              "Problem JSON: ${cachedProduct['product_json']?.substring(0, 100)}...");
          // Skip this product and continue
        }
      }

      products.assignAll(reconstructedProducts);
      filteredProducts.assignAll(reconstructedProducts);
      print(
          "Loaded $successCount products from offline cache (failed: $failCount)");
    } catch (e, stack) {
      log("Error loading products from cache: $e");
      log("Stack: $stack");
      print("Cache loading failed: $e");
    }
  }

  //TODO : Bir
  void searchProducts2(String query) {
    final queryNormalized = query.trim().toLowerCase();

    List<ProductItem> filteredList;

    if (queryNormalized.isEmpty) {
      // If query is empty, show all products
      filteredList = products;
    } else if (queryNormalized.contains('*')) {
      // 1️⃣ Wildcard search: Convert '*' to regex pattern '.*'
      final searchPattern = queryNormalized.replaceAll('*', '.*');
      final regex = RegExp(searchPattern, caseSensitive: false);

      filteredList = products.where((product) {
        return regex.hasMatch(product.itemName.toLowerCase()) ||
            regex.hasMatch(product.itemLname?.toLowerCase() ?? "") ||
            regex.hasMatch(product.itemCd.toLowerCase()) ||
            regex.hasMatch(product.itemBrand?.toLowerCase() ?? "") ||
            regex.hasMatch(product.itemCat?.toLowerCase() ?? "");
      }).toList();
    } else if (queryNormalized.contains(' ')) {
      // 2️⃣ Multi-word search (space-separated words)
      final searchWords = queryNormalized.split(' ');

      filteredList = products.where((product) {
        final searchableFields = [
          product.itemName.toLowerCase(),
          product.itemLname?.toLowerCase() ?? "",
          product.itemCd.toLowerCase(),
          product.itemBrand?.toLowerCase() ?? "",
          product.itemCat?.toLowerCase() ?? ""
        ];

        // Ensure all words from the search query are found
        return searchWords.every(
            (word) => searchableFields.any((field) => field.contains(word)));
      }).toList();
    } else {
      // 3️⃣ Normal single-word search
      filteredList = products.where((product) {
        return product.itemName.toLowerCase().contains(queryNormalized) ||
            product.itemCd.toLowerCase().contains(queryNormalized) ||
            (product.itemLname?.toLowerCase() ?? "")
                .contains(queryNormalized) ||
            (product.itemBrand?.toLowerCase() ?? "")
                .contains(queryNormalized) ||
            (product.itemCat?.toLowerCase() ?? "").contains(queryNormalized);
      }).toList();
    }

    filteredProducts.assignAll(filteredList);
    log("Filtered products: ${filteredList.length}");
  }

  //TODO : OLD Fazal
  void searchProducts123(String query) {
    final queryNormalized = query.trim().toLowerCase();

    List<ProductItem> filteredList;

    if (queryNormalized.isEmpty) {
      // If query is empty, show all products
      filteredList = products;
    } else if (queryNormalized.contains('*')) {
      // 1️⃣ Wildcard search: Convert '*' to regex pattern '.*'
      final searchPattern = queryNormalized.replaceAll('*', '.*');
      final regex = RegExp(searchPattern, caseSensitive: false);

      filteredList = products.where((product) {
        return regex.hasMatch(product.itemName.toLowerCase()) ||
            regex.hasMatch(product.itemLname?.toLowerCase() ?? "") ||
            regex.hasMatch(product.itemCd.toLowerCase()) ||
            regex.hasMatch(product.itemBrand?.toLowerCase() ?? "") ||
            regex.hasMatch(product.itemCat?.toLowerCase() ?? "");
      }).toList();
    } else if (queryNormalized.contains(' ')) {
      // 2️⃣ Multi-word search (space-separated words)
      final searchWords = queryNormalized.split(' ');

      filteredList = products.where((product) {
        final searchableFields = [
          product.itemName.toLowerCase(),
          product.itemLname?.toLowerCase() ?? "",
          product.itemCd.toLowerCase(),
          product.itemBrand?.toLowerCase() ?? "",
          product.itemCat?.toLowerCase() ?? ""
        ];

        // Ensure all words from the search query are found
        return searchWords.every(
          (word) => searchableFields.any((field) => field.contains(word)),
        );
      }).toList();
    } else {
      // 3️⃣ Normal single-word search with prioritization for words starting with the query
      final startsWithMatch = products.where((product) {
        final fields = [
          product.itemName.toLowerCase(),
          product.itemLname?.toLowerCase() ?? "",
          product.itemCd.toLowerCase(),
          product.itemBrand?.toLowerCase() ?? "",
          product.itemCat?.toLowerCase() ?? ""
        ];

        // Prioritize products that start with the query
        return fields.any((field) => field.startsWith(queryNormalized));
      }).toList();

      // Then, find products that contain the query anywhere
      final containsMatch = products.where((product) {
        final fields = [
          product.itemName.toLowerCase(),
          product.itemLname?.toLowerCase() ?? "",
          product.itemCd.toLowerCase(),
          product.itemBrand?.toLowerCase() ?? "",
          product.itemCat?.toLowerCase() ?? ""
        ];

        // Allow the query to match anywhere in the field
        return fields.any((field) => field.contains(queryNormalized));
      }).toList();

      // Combine the lists: start-with matches first, then contains matches
      filteredList = startsWithMatch + containsMatch;
    }

    // Removing duplicates by using a Set (in case a product matches both conditions)
    filteredList = filteredList.toSet().toList();

    filteredProducts.assignAll(filteredList);
    log("Filtered products: ${filteredList}");
  }

  void searchProducts(String query) {
    final queryNormalized = query.trim().toLowerCase();

    // 🔍 Filter products by selected department first
    List<ProductItem> baseList = selectedChip.value.isEmpty
        ? products
        : products
            .where((product) =>
                product.deptCd.toLowerCase() ==
                selectedChip.value.toLowerCase())
            .toList();

    List<ProductItem> filteredList;

    if (queryNormalized.isEmpty) {
      // If query is empty, show all from the current department
      filteredList = baseList;
    } else if (queryNormalized.contains('*')) {
      // Wildcard search
      final searchPattern = queryNormalized.replaceAll('*', '.*');
      final regex = RegExp(searchPattern, caseSensitive: false);

      filteredList = baseList.where((product) {
        return regex.hasMatch(product.itemName.toLowerCase()) ||
            regex.hasMatch(product.itemLname?.toLowerCase() ?? "") ||
            regex.hasMatch(product.itemCd.toLowerCase()) ||
            regex.hasMatch(product.itemBrand?.toLowerCase() ?? "") ||
            regex.hasMatch(product.itemCat?.toLowerCase() ?? "");
      }).toList();
    } else if (queryNormalized.contains(' ')) {
      // Multi-word search
      final searchWords = queryNormalized.split(' ');

      filteredList = baseList.where((product) {
        final searchableFields = [
          product.itemName.toLowerCase(),
          product.itemLname?.toLowerCase() ?? "",
          product.itemCd.toLowerCase(),
          product.itemBrand?.toLowerCase() ?? "",
          product.itemCat?.toLowerCase() ?? ""
        ];

        return searchWords.every(
          (word) => searchableFields.any((field) => field.contains(word)),
        );
      }).toList();
    } else {
      // Normal single-word search
      final startsWithMatch = baseList.where((product) {
        final fields = [
          product.itemName.toLowerCase(),
          product.itemLname?.toLowerCase() ?? "",
          product.itemCd.toLowerCase(),
          product.itemBrand?.toLowerCase() ?? "",
          product.itemCat?.toLowerCase() ?? ""
        ];

        return fields.any((field) => field.startsWith(queryNormalized));
      }).toList();

      final containsMatch = baseList.where((product) {
        final fields = [
          product.itemName.toLowerCase(),
          product.itemLname?.toLowerCase() ?? "",
          product.itemCd.toLowerCase(),
          product.itemBrand?.toLowerCase() ?? "",
          product.itemCat?.toLowerCase() ?? ""
        ];

        return fields.any((field) => field.contains(queryNormalized));
      }).toList();

      // Merge and deduplicate
      filteredList = [
        ...{...startsWithMatch, ...containsMatch}
      ];
    }

    filteredProducts.assignAll(filteredList);
    log("Filtered products: $filteredList");
  }

  void toggleChipSelection1(String deptCd) {
    selectedChip.value = (selectedChip.value == deptCd) ? '' : deptCd;
    // log("selecte dcip >>>> ${selectedChip.value}");
    if (selectedChip.value.isEmpty) {
      filteredProducts.assignAll(products);
    } else {
      final filteredList = products
          .where(
              (product) => product.deptCd.toLowerCase() == deptCd.toLowerCase())
          .toList();
      filteredProducts.assignAll(filteredList);
      log("Filtered products for department '$deptCd': $filteredList");
    }
  }

  void toggleChipSelection(String deptCd) {
    selectedChip.value = (selectedChip.value == deptCd) ? '' : deptCd;

    if (selectedChip.value.isEmpty) {
      filteredProducts.assignAll(products);
    } else {
      final filteredList = products
          .where((product) =>
              product.deptCd.toLowerCase() == selectedChip.value.toLowerCase())
          .toList();
      filteredProducts.assignAll(filteredList);
      log("Filtered products for department '${selectedChip.value}': $filteredList");
    }
  }

  Future<void> fetchDepartments() async {
    isDpLoading.value = true;
    try {
      print('[Departments] Delegating to Services().getDeptment()');

      final serviceResult = await Services().getDeptment(Get.context);
      print('[Departments] Service returned count: ${serviceResult?.length}');
      print(
          '[Departments] Service sample: ${serviceResult != null && serviceResult.isNotEmpty ? serviceResult.take(3).toList() : serviceResult}');

      // Quick double-check: read DB directly if service returned null/empty
      if (serviceResult == null || serviceResult.isEmpty) {
        try {
          final cached = await DatabaseHelper().getAllDepartments();
          print('[Departments] Direct DB read count: ${cached.length}');
          if (cached.isNotEmpty)
            print('[Departments] Direct DB sample: ${cached.take(3).toList()}');
        } catch (dbErr) {
          print('[Departments] Direct DB read failed: $dbErr');
        }
      }

      if (serviceResult != null && serviceResult.isNotEmpty) {
        final mapped = serviceResult
            .map((d) => Department.fromJson({
                  'DEPT_CD': d.DEPT_CD?.toString() ?? '',
                  'DEPT_NAME': d.DEPT_NAME?.toString() ?? '',
                  'GROUPING': '',
                  'SYNC_ID': d.SYNC_ID?.toString() ?? '',
                  'UPDATED_AT': '',
                  'CREATED_AT': ''
                }))
            .toList();

        print('[Departments] Mapped departments count: ${mapped.length}');
        print(
            '[Departments] Mapped sample names: ${mapped.take(5).map((e) => e.deptName).toList()}');

        final departments = <Department>[
          Department(
            deptCd: '',
            deptName: 'All Item',
            grouping: '',
            syncId: '0',
            updatedAt: '',
            createdAt: '',
          ),
          ...mapped
        ];

        print(
            '[Departments] Final departments count (with All Item): ${departments.length}');

        deptment.assignAll(departments);
        filteredDepartments.assignAll(departments);

        // Verify assignment
        print(
            '[Departments] After assignment - deptment.length: ${deptment.length}, filteredDepartments.length: ${filteredDepartments.length}');
      } else {
        print(
            '[Departments] Services returned no departments, loading default');
        _loadDefaultDepartments();
      }
    } catch (e) {
      print('[Departments] Error in fetchDepartments: $e');
      log("Failed to fetch departments: $e");
      // On error, still load default
      _loadDefaultDepartments();
    } finally {
      isDpLoading.value = false;
    }
  }

  /// Load default departments (at minimum "All Item")
  void _loadDefaultDepartments() {
    try {
      final departments = <Department>[
        Department(
          deptCd: '',
          deptName: 'All Item',
          grouping: '',
          syncId: '0',
          updatedAt: '',
          createdAt: '',
        ),
      ];
      deptment.value = departments;
      filteredDepartments.assignAll(departments);
      print('[Departments] Loaded default departments');
    } catch (e) {
      print('[Departments] Error loading default: $e');
    }
  }

  Future<void> fetchPartyNames() async {
    isPartyLoading.value = true;
    try {
      //final response = await _getRequest(endpoint: '/products/party');
      final response = await _getRequest(endpoint: 'products/party');

      if (response != null) {
        final partyData = PartynameModal.fromJson(response);
        party.assignAll(partyData.data);
        filterParty.assignAll(partyData.data);
      }
    } catch (e) {
      _handleError('Failed to fetch party names: $e');
    } finally {
      isPartyLoading.value = false;
    }
  }

  /// Fetch stockists by groupCd parameter
  /// Used to get parties with specific groupCd (e.g., groupCd=136 for stockists)
  /// and stockist=1 to fetch user-specific stockists.
  Future<void> fetchStockists({required String groupCd}) async {
    isStockistLoading.value = true;
    try {
      final uri = Uri.parse('${AppConfig.baseURL}products/party')
          .replace(queryParameters: {'groupCd': groupCd, 'stockist': '1'});

      final response = await dio.get(
        uri.toString(),
        options: Options(
          headers: {
            "Authorization": "Bearer ${ub.token}",
            'x-app-type': 'oms',
          },
        ),
      );

      print('[Stockist] GET $uri');
      print('[Stockist] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final partyData = PartynameModal.fromJson(response.data);
        stockists.assignAll(partyData.data);
        hasStockistAccess.value = stockists.isNotEmpty;
        print(
            '[Stockist] Fetched ${stockists.length} stockists for groupCd=$groupCd with stockist=1');

        // Calculate distances and sort stockists by proximity
        await _sortStockistsByDistance();
      } else {
        print('[Stockist] Failed with status: ${response.statusCode}');
        hasStockistAccess.value = false;
      }
    } catch (e) {
      print('[Stockist] Error fetching stockists: $e');
      hasStockistAccess.value = false;
    } finally {
      isStockistLoading.value = false;
    }
  }

  /// Calculate distance between user and each stockist, then sort by proximity
  Future<void> _sortStockistsByDistance() async {
    try {
      // Get user's current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      print(
          '[Stockist] User location: Lat=${position.latitude}, Long=${position.longitude}');

      // Calculate distance for each stockist and update the model
      for (final stockist in stockists) {
        // Skip if lat/long is missing or invalid
        final lat = _parseDouble(stockist.lat);
        final long = _parseDouble(stockist.long);

        if (lat != null && long != null) {
          final distanceInMeters = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            lat,
            long,
          );
          stockist.distanceInMeters = distanceInMeters;
          print(
              '[Stockist] ${stockist.accName}: ${(distanceInMeters / 1000).toStringAsFixed(2)} km');
        } else {
          print(
              '[Stockist] ${stockist.accName}: Missing coordinates (Lat=$lat, Long=$long)');
          stockist.distanceInMeters = null;
        }
      }

      // Sort stockists by distance (nearest first), with null values at the end
      stockists.sort((a, b) {
        if (a.distanceInMeters == null && b.distanceInMeters == null) return 0;
        if (a.distanceInMeters == null) return 1; // Null goes to end
        if (b.distanceInMeters == null) return -1; // Null goes to end
        return a.distanceInMeters!.compareTo(b.distanceInMeters!);
      });

      print('[Stockist] Sorted ${stockists.length} stockists by distance');
      stockists.refresh(); // Notify listeners of the change
    } catch (e) {
      print('[Stockist] Error calculating distances: $e');
      // Continue with original order if distance calculation fails
    }
  }

  /// Helper method to safely parse double from dynamic value
  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Save stockist selection to SharedPreferences
  Future<void> saveStockistSelection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedStockistName', selectedStockistName.value);
      await prefs.setString('selectedStockistId', selectedStockistId.value);
      await prefs.setString(
          'selectedStockistAddress', selectedStockistAddress.value);
      await prefs.setString('selectedStockistCity', selectedStockistCity.value);
      await prefs.setString(
          'selectedStockistMobile', selectedStockistMobile.value);
      await prefs.setString(
          'selectedStockistPersonName', selectedStockistPersonName.value);
      await prefs.setString(
          'selectedStockistPincode', selectedStockistPincode.value);
      print(
          '[Stockist] Saved selection: ${selectedStockistName.value} (${selectedStockistId.value})');
    } catch (e) {
      print('[Stockist] Error saving selection: $e');
    }
  }

  /// Restore stockist selection from SharedPreferences
  Future<void> restoreStockistSelection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('selectedStockistName') ?? '';
      final id = prefs.getString('selectedStockistId') ?? '';

      if (name.isNotEmpty && id.isNotEmpty) {
        selectedStockistName.value = name;
        selectedStockistId.value = id;
        selectedStockistAddress.value =
            prefs.getString('selectedStockistAddress') ?? '';
        selectedStockistCity.value =
            prefs.getString('selectedStockistCity') ?? '';
        selectedStockistMobile.value =
            prefs.getString('selectedStockistMobile') ?? '';
        selectedStockistPersonName.value =
            prefs.getString('selectedStockistPersonName') ?? '';
        selectedStockistPincode.value =
            prefs.getString('selectedStockistPincode') ?? '';
        // Keep stockist header visible immediately after page reopen,
        // even before stockist API call completes.
        hasStockistAccess.value = true;
        print('[Stockist] Restored selection: $name ($id)');
      }
    } catch (e) {
      print('[Stockist] Error restoring selection: $e');
    }
  }

  /// Clear stockist selection from SharedPreferences
  Future<void> clearStockistSelection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('selectedStockistName');
      await prefs.remove('selectedStockistId');
      await prefs.remove('selectedStockistAddress');
      await prefs.remove('selectedStockistCity');
      await prefs.remove('selectedStockistMobile');
      await prefs.remove('selectedStockistPersonName');
      await prefs.remove('selectedStockistPincode');
      selectedStockistName.value = '';
      selectedStockistId.value = '';
      selectedStockistAddress.value = '';
      selectedStockistCity.value = '';
      selectedStockistMobile.value = '';
      selectedStockistPersonName.value = '';
      selectedStockistPincode.value = '';
      print('[Stockist] Cleared selection');
    } catch (e) {
      print('[Stockist] Error clearing selection: $e');
    }
  }

  Future<void> fetchOptions() async {
    try {
      _fetchNarrationOptions('OTHER_DESC', otherDescOptions);
      _fetchNarrationOptions('FLD5', fld5DescOptions);
      ;
    } catch (e) {
      log('Error in fetchOptions: $e');
    }
  }

  getOptions() {
    Services().getNarration(Get.context, "OTHER_DESC").then((value) {
      if (value != null) {
        otherDescOptions.addAll(value.map((e) => DatumNarration(
            NARR_NAME: e.NARR_NAME,
            NARR_TYPE: e.NARR_TYPE,
            SYNC_ID: e.SYNC_ID)));
      } else {
        print("Error: OTHER_DESC returned null or invalid data.");
      }
    }).catchError((error) {
      print("Error fetching OTHER_DESC: $error");
    });

    Services().getNarration(Get.context, "FLD5").then((value) {
      if (value != null) {
        fld5DescOptions.addAll(value.map((e) => DatumNarration(
            NARR_NAME: e.NARR_NAME,
            NARR_TYPE: e.NARR_TYPE,
            SYNC_ID: e.SYNC_ID)));
      } else {
        print("Error: FLD5 returned null or invalid data.");
      }
    }).catchError((error) {
      print("Error fetching FLD5: $error");
    });
  }

  Future<void> _fetchNarrationOptions(
      String narrationType, RxList<DatumNarration> targetList) async {
    final String url =
        ('${AppConfig.baseURL}master-entry/narration?narrType=$narrationType');

    try {
      // ignore: unused_local_variable
      final response = await dio.get(
        url,
        options: Options(headers: {
          'Authorization': 'Bearer ${ub.token}',
          'x-app-type': 'oms',
        }),
      );
      // Process the response as needed
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        // Handle 403 Forbidden error specifically
        print('Access forbidden: ${e.response?.data}');
      } else {
        // Handle other errors
        print('Request error: $e');
      }
    }
  }

  Future<dynamic> _getRequest({required String endpoint}) async {
    try {
      final response = await dio.get(
        '${AppConfig.baseURL}$endpoint',
        options: Options(
          headers: {
            "Authorization": "Bearer ${ub.token}",
            'x-app-type': 'oms',
          },
        ),
      );

      print('${AppConfig.baseURL}$endpoint');
      print('Bearer ${ub.token}');
      if (response.statusCode == 200) {
        return response.data;
      } else if (response.statusCode == 401) {
        Get.offAll(() => LoginPage());
      } else {
        _handleError('Failed with status code: ${response.statusCode}');
      }
    } catch (e) {
      _handleError('Error occurred while fetching data: $e');
    }
    return null;
  }

  void _handleError(String message) {
    errorMessage.value = message;

    //showToast(message);

    log("Error: $message");
  }

  @override
  void onInit() {
    super.onInit();
    fetchProductsFromAPI();
    fetchPartyNames();
    //fetchOptions();
    getOptions();
    fetchDepartments();
    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        // When focus is gained, set selection to the end (so the cursor is at the end of the text)
        //searchClt.selection =
        //    TextSelection.collapsed(offset: searchClt.text.length);

        searchController.selection = TextSelection(
            baseOffset: 0, extentOffset: searchController.text.length);
      }
    });
  }

  @override
  void onClose() {
    searchController.dispose();
    //focusNode.dispose();
    super.onClose();
  }
}
