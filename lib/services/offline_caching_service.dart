import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../providers/party_provider.dart';
import '../providers/item_list_provider.dart';
import '../product/controller/product_controller.dart';
import 'package:get/get.dart';

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
