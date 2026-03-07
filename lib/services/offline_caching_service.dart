import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product_response.dart';
import '../providers/profile_provider.dart';
import '../providers/party_provider.dart';
import '../providers/item_list_provider.dart';
import '../providers/user_provider.dart';
import 'database_helper.dart';
import 'services.dart';

class CacheItemStatus {
  final String name;
  bool isInProgress; // Currently being cached
  bool isComplete; // Caching finished (success or failure)
  bool isSuccess; // True if completed successfully
  String? errorMessage;

  CacheItemStatus({
    required this.name,
    this.isInProgress = false,
    this.isComplete = false,
    this.isSuccess = false,
    this.errorMessage,
  });
}

/// Callback for progress updates
typedef ProgressCallback = void Function(CacheItemStatus status);

class OfflineCachingService {
  /// Manually trigger caching of all critical data for offline use with detailed progress tracking
  /// Stops on first failure and reports it via callback
  /// UI shows 5 items: Profile, Departments, Products, Party, Cart
  /// Background: Profile also caches license info + settings; Products also caches departments + items
  static Future<bool> cacheAllDataForOffline(
    BuildContext context, {
    void Function(CacheItemStatus status)? onProgress,
  }) async {
    try {
      print('[OFFLINE CACHE] Starting manual offline caching...');

      // Define cache items in order (shown in UI)
      final cacheItems = [
        CacheItemStatus(name: 'Profile'),
        CacheItemStatus(name: 'Departments'),
        CacheItemStatus(name: 'Products'),
        CacheItemStatus(name: 'Party'),
        CacheItemStatus(name: 'Cart'),
      ];

      // ========== PROFILE SECTION (includes License Info + Settings) ==========
      try {
        _reportProgress(cacheItems[0], onProgress, inProgress: true);
        print('[OFFLINE CACHE] Caching profile...');

        final profileProvider =
            Provider.of<ProfileProvider>(context, listen: false);
        await profileProvider.getProfile(context);
        print('[OFFLINE CACHE] ✓ Profile cached');

        // Cache License Info for Order Limits
        print('[OFFLINE CACHE] Caching license info...');
        try {
          final userProvider =
              Provider.of<UserProvider>(context, listen: false);

          // Get syncId from profile data (just loaded) or UserProvider
          int syncId = 0;

          // Try to get from ProfileProvider.data first (most reliable after getProfile)
          final profileSyncId = profileProvider.data?.syncId;
          if (profileSyncId is int) {
            syncId = profileSyncId;
          } else if (profileSyncId is String) {
            syncId = int.tryParse(profileSyncId) ?? 0;
          }

          // Fallback to UserProvider if profile didn't have it
          if (syncId == 0) {
            final userSyncId = userProvider.syncId;
            if (userSyncId is String) {
              final parsed = int.tryParse(userSyncId);
              syncId = parsed ?? 0;
            }
          }

          print(
              '[OFFLINE CACHE] Debug - profileSyncId=${profileProvider.data?.syncId}, userSyncId=${userProvider.syncId}, parsed syncId=$syncId');

          if (syncId > 0) {
            final db = DatabaseHelper();

            // Check cached license info
            print('[OFFLINE CACHE] Step 1.5: Checking cached license info...');
            final existingLicense = await db.getLicenseInfo(syncId);

            if (existingLicense != null) {
              print(
                  '[OFFLINE CACHE] ✓ License info cached from previous activity');
              print(
                  '[OFFLINE CACHE]   - Orders: ${existingLicense['orderCount']}/${existingLicense['maxOrders']}');
              print(
                  '[OFFLINE CACHE]   - Blacklisted: ${existingLicense['autoBlacklisted']}');
              print('[OFFLINE CACHE]   ℹ️ Cache updates when you:');
              print('[OFFLINE CACHE]      • Place an online order');
              print('[OFFLINE CACHE]      • Sync offline orders to server');
            } else {
              print('[OFFLINE CACHE] ℹ️ No license info cached yet');
              print(
                  '[OFFLINE CACHE]    (Will be cached when you place your first order)');
            }
          } else {
            print(
                '[OFFLINE CACHE] ⚠️ Could not retrieve SYNC_ID for license caching (syncId=$syncId)');
          }
        } catch (e) {
          print(
              '[OFFLINE CACHE] ⚠️ Warning: Could not verify license info: $e');
        }

        // Cache Settings (already done in getProfile, but explicit call ensures it)
        print('[OFFLINE CACHE] Caching settings...');
        try {
          await profileProvider.loadSettings(context);
          print('[OFFLINE CACHE] ✓ Settings cached');
        } catch (e) {
          print('[OFFLINE CACHE] ✗ Failed to cache settings: $e');
          throw e; // Propagate to catch block
        }

        _reportProgress(cacheItems[0], onProgress, success: true);
      } catch (e) {
        print('[OFFLINE CACHE] ✗ Failed to cache profile: $e');
        cacheItems[0].errorMessage = e.toString();
        _reportProgress(cacheItems[0], onProgress,
            success: false, error: e.toString());
        return false; // Stop here
      }

      // ========== DEPARTMENTS & PRODUCTS SECTION ==========
      try {
        _reportProgress(cacheItems[1], onProgress, inProgress: true);
        print('[OFFLINE CACHE] Caching departments and products...');

        // Use Services to fetch departments (handles caching internally)
        final deptList = await Services().getDeptment(context);
        if (deptList == null || deptList.isEmpty) {
          throw Exception('No departments received from API');
        }
        print(
            '[OFFLINE CACHE] ✓ Departments and products cached (${deptList.length} departments)');

        _reportProgress(cacheItems[1], onProgress, success: true);
      } catch (e) {
        print('[OFFLINE CACHE] ✗ Failed to cache departments: $e');
        cacheItems[1].errorMessage = e.toString();
        _reportProgress(cacheItems[1], onProgress,
            success: false, error: e.toString());
        return false; // Stop here
      }

      // Step 2: Cache Products with FULL data (prices, stock, rates, etc.)
      try {
        _reportProgress(cacheItems[2], onProgress, inProgress: true);
        print('[OFFLINE CACHE] Caching products with full details...');

        // Use export/products API (same as ProductController) - returns full product data
        final ProductResponse? productResponse =
            await Services().getProductNew(null, null, null, context, null);
        if (productResponse == null ||
            productResponse.data == null ||
            productResponse.data!.isEmpty) {
          throw Exception('No products received from API');
        }

        final productsData = productResponse.data!;
        print(
            '[OFFLINE CACHE] Fetched ${productsData.length} products from API');

        // Cache with full product JSON (prices, stock, rates, discounts, department info)
        final db = DatabaseHelper();
        List<Map<String, dynamic>> productsForCache = [];

        for (var product in productsData) {
          try {
            productsForCache.add({
              'item_cd': product.iTEMCD ?? '',
              'product_json': jsonEncode(product.toJson()),
              'cached_at': DateTime.now().millisecondsSinceEpoch,
              'department_code': product.dEPTCD ?? '',
              'item_name': product.iTEMNAME ?? '',
            });
          } catch (e) {
            print('[OFFLINE CACHE] Skipping product ${product.iTEMCD}: $e');
          }
        }

        if (productsForCache.isEmpty) {
          throw Exception('Failed to serialize any products for caching');
        }

        await db.cacheProductsJson(productsForCache);
        print(
            '[OFFLINE CACHE] ✓ Cached ${productsForCache.length} products with full details');

        // Verify cache was actually written
        final verifyCount = (await db.getCachedProducts()).length;
        if (verifyCount == 0) {
          throw Exception(
              'Products cache verification failed - 0 products in database');
        }
        print('[OFFLINE CACHE] ✓ Verified: $verifyCount products in cache');

        _reportProgress(cacheItems[2], onProgress, success: true);
      } catch (e) {
        print('[OFFLINE CACHE] ✗ Failed to cache products: $e');
        cacheItems[2].errorMessage = e.toString();
        _reportProgress(cacheItems[2], onProgress,
            success: false, error: e.toString());
        return false;
      }

      // ========== PARTIES SECTION ==========
      try {
        _reportProgress(cacheItems[3], onProgress, inProgress: true);
        print('[OFFLINE CACHE] Caching parties...');

        final partyProvider =
            Provider.of<PartyProvider>(context, listen: false);
        await partyProvider.getpartyname(context);
        print('[OFFLINE CACHE] ✓ Parties cached');

        _reportProgress(cacheItems[3], onProgress, success: true);
      } catch (e) {
        print('[OFFLINE CACHE] ✗ Failed to cache parties: $e');
        cacheItems[3].errorMessage = e.toString();
        _reportProgress(cacheItems[3], onProgress,
            success: false, error: e.toString());
        return false; // Stop here
      }

      // ========== CART & ITEMS SECTION ==========
      try {
        _reportProgress(cacheItems[4], onProgress, inProgress: true);
        print('[OFFLINE CACHE] Caching items list and cart...');

        // Cache item list (used for item search/selection in reports)
        final itemListProvider =
            Provider.of<ItemListProvider>(context, listen: false);
        await itemListProvider.getItems(context);
        print(
            '[OFFLINE CACHE] ✓ Items list cached (${itemListProvider.data.length} items)');

        // Cart items are cached locally in cart_items table
        print('[OFFLINE CACHE] ✓ Cart ready for offline');
        _reportProgress(cacheItems[4], onProgress, success: true);
      } catch (e) {
        print('[OFFLINE CACHE] ✗ Failed to cache cart/items: $e');
        cacheItems[4].errorMessage = e.toString();
        _reportProgress(cacheItems[4], onProgress,
            success: false, error: e.toString());
        return false;
      }

      print('[OFFLINE CACHE] ✓ All data cached successfully!');
      return true;
    } catch (e) {
      print('[OFFLINE CACHE] ✗ Error during offline caching: $e');
      return false;
    }
  }

  /// Helper to report progress
  static void _reportProgress(
    CacheItemStatus status,
    void Function(CacheItemStatus status)? onProgress, {
    bool inProgress = false,
    bool success = false,
    String? error,
  }) {
    if (inProgress) {
      status.isInProgress = true;
      status.isComplete = false;
    } else {
      status.isInProgress = false;
      status.isComplete = true;
      status.isSuccess = success;
    }
    if (error != null) {
      status.errorMessage = error;
    }
    onProgress?.call(status);
  }
}
