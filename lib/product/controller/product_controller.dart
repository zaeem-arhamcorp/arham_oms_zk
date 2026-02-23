import 'dart:async';
import 'dart:developer';

import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/services/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

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
      final response = await _getRequest(endpoint: 'export/products');
      if (response != null) {
        final apiResponse = ProductResponse.fromJson(response);
        final productsData = apiResponse.data;

        products.assignAll(productsData);
        filteredProducts.assignAll(productsData);
      }
    } catch (e) {
      log("Failed to fetch products from API: $e");
    } finally {
      isLoading.value = false;
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
                (word) =>
                searchableFields.any((field) => field.contains(word)));
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
      log("Filtered products for department '${selectedChip
          .value}': $filteredList");
    }
  }

  Future<void> fetchDepartments() async {
    isDpLoading.value = true;
    try {
      final response = await _getRequest(endpoint: 'export/deptment');
      if (response != null) {
        final departments = <Department>[
          Department(
            deptCd: '',
            deptName: 'All Item',
            grouping: '',
            syncId: '0',
            updatedAt: '',
            createdAt: '',
          ),
          ...List<Department>.from(
            (response['data'] as List<dynamic>)
                .map((dept) => Department.fromJson(dept)),
          ),
        ];

        deptment.value = departments;
      }
    } catch (e) {
      log("Failed to fetch departments: $e");
      _handleError('Failed to fetch departments: $e');
    } finally {
      isDpLoading.value = false;
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
        otherDescOptions.addAll(value.map((e) =>
            DatumNarration(
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
        fld5DescOptions.addAll(value.map((e) =>
            DatumNarration(
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

  Future<void> _fetchNarrationOptions(String narrationType,
      RxList<DatumNarration> targetList) async {
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
