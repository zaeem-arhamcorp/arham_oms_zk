import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../providers/party_provider.dart';
import '../providers/item_list_provider.dart';
import '../providers/user_provider.dart';
import '../product/controller/product_controller.dart';
import 'package:get/get.dart';
import 'database_helper.dart';

class OfflineCachingService {
  /// Manually trigger caching of all critical data for offline use
  /// This includes: Profile, Settings, Products, Departments, Parties, and Items
  static Future<bool> cacheAllDataForOffline(BuildContext context) async {
    try {
      print('[OFFLINE CACHE] Starting manual offline caching...');

      // Step 1: Cache Profile & Account
      print('[OFFLINE CACHE] Caching profile...');
      try {
        final profileProvider =
            Provider.of<ProfileProvider>(context, listen: false);
        await profileProvider.getProfile(context);
        print('[OFFLINE CACHE] ✓ Profile cached');
      } catch (e) {
        print('[OFFLINE CACHE] ✗ Failed to cache profile: $e');
      }

      // Step 1.5: Cache License Info for Order Limits
      print('[OFFLINE CACHE] Caching license info...');
      try {
        final profileProvider =
            Provider.of<ProfileProvider>(context, listen: false);
        final userProvider = Provider.of<UserProvider>(context, listen: false);

        // Get syncId from profile data (just loaded in Step 1) or UserProvider
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
        print('[OFFLINE CACHE] ⚠️ Warning: Could not verify license info: $e');
      }

      // Step 2: Cache Settings (already done in getProfile, but explicit call ensures it)
      print('[OFFLINE CACHE] Caching settings...');
      try {
        final profileProvider =
            Provider.of<ProfileProvider>(context, listen: false);
        await profileProvider.loadSettings(context);
        print('[OFFLINE CACHE] ✓ Settings cached');
      } catch (e) {
        print('[OFFLINE CACHE] ✗ Failed to cache settings: $e');
      }

      // Step 3: Cache Products & Departments
      print('[OFFLINE CACHE] Caching products and departments...');
      try {
        final productController = Get.find<ProductController>();
        await productController.fetchProductsFromAPI();
        print('[OFFLINE CACHE] ✓ Products and departments cached');
      } catch (e) {
        print('[OFFLINE CACHE] ✗ Failed to cache products: $e');
      }

      // Step 4: Cache Parties
      print('[OFFLINE CACHE] Caching parties...');
      try {
        final partyProvider =
            Provider.of<PartyProvider>(context, listen: false);
        await partyProvider.getpartyname(context);
        print('[OFFLINE CACHE] ✓ Parties cached');
      } catch (e) {
        print('[OFFLINE CACHE] ✗ Failed to cache parties: $e');
      }

      // Step 5: Cache Items
      print('[OFFLINE CACHE] Caching items...');
      try {
        final itemListProvider =
            Provider.of<ItemListProvider>(context, listen: false);
        await itemListProvider.getItems(context);
        print('[OFFLINE CACHE] ✓ Items cached');
      } catch (e) {
        print('[OFFLINE CACHE] ✗ Failed to cache items: $e');
      }

      print('[OFFLINE CACHE] ✓ All data cached successfully!');
      return true;
    } catch (e) {
      print('[OFFLINE CACHE] ✗ Error during offline caching: $e');
      return false;
    }
  }
}
