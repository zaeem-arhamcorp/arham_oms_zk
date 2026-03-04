# Offline Mode Issues Analysis (March 4, 2026)

## ISSUE 1 & 2: Dashboard/Order Report डेटा Offline मेंनहीं दिख रहा

### Root Cause:
- `getDashboarddata()` में `if (value.data.labelData.transaction.isNotEmpty)` condition है
- अगर transaction empty हो तो cache नहीं होता
-Fallback parsing में error है (json.decode से null value आ रहा है)

### Symptom:
```
Error parsing cached dashboard JSON: type 'Null' is not a subtype of type 'Map<String, dynamic>'
```

### Fix Strategy:
1. **Always cache** dashboard/report data, even if partially empty
2. **Better fallback** parsing with null-safe operations
3. **Clear error handling** - don't force-cast potentially null values to Map

**Files to fix:**
- `lib/views/homepage.dart` - getDashboarddata()
- `lib/views/orderReportScreen.dart` - getDate()

---

## ISSUE 3: Quantity DOUBLE हो रही है (MAJOR BUG)

### Scenario:
```
Step 1: User ONLINE
- Adds 5 qty item to cart
- local_db: qty=5 (saved via cart_controller)
- server_cart: qty=5 (via POST /cart)

Step 2: User goes OFFLINE  
- Places order with same item (qty=5)
- offline_order saved with qty=5
- local_db cart CLEARED (via clearCart())

Step 3: User goes ONLINE
- ConnectivityService detects online
- syncOrders() called
- For offline order: POST /cart API called with qty=5 again
- server_cart NOW HAS: qty=10 (5 from step 1 + 5 from sync)

Result: User sees qty=10 instead of 5
```

### Root Cause:
1. **Server cart not cleared** after offline order is synced
2. **Items re-POSTed** to /cart endpoint (which is ADD, not REPLACE)
3. **Local cart cleared BEFORE syncing** - so no way to know which items belong to which order

### Problem in Code:
- `offline_order_service.dart` calls `clearCart()` IMMEDIATELY after saving order
- `sync_service.dart.` POSTs items to /cart AGAIN during sync
- Server cart already has items from online purchase

### Fix Strategy:
1. **Mark cart items** when they're part of an offline order (add `ordered_offline` sync_status)
2. **Don't POST** items to cart if they already have this status
3. **Delete marked items** AFTER successful order sync
4. **Skip those items** when syncing server cart to local

**Files to fix:**
- `lib/services/database_helper.dart` - add helper to mark/unmark cart items
- `lib/services/offline_order_service.dart` - mark items instead of clearing
- `lib/services/sync_service.dart` - check status before POSTing, delete after sync
- `lib/providers/cart_list_provider.dart` - skip ordered items when syncing

---

## Summary of Changes Needed:

| Issue | File | Change |
|-------|------|--------|
| 1, 2 | homepage.dart | Null-safe parsing, always cache |
| 1, 2 | orderReportScreen.dart | Null-safe parsing, always cache |
| 3 | database_helper.dart | Add mark/unmark methods for ordered items |
| 3 | offline_order_service.dart | Mark as 'ordered_offline' instead of clear |
| 3 | sync_service.dart | Check status before POST, delete after sync |
| 3 | cart_list_provider.dart | Skip 'ordered_offline' items |

---

## Implementation Order:
1. ✅ Fix dashboard/report caching (Issues 1 & 2) - SIMPLE
2. ✅ Add cart item marking system (Issue 3) - MEDIUM
3. ✅ Update offline order save/sync logic - MEDIUM
4. ✅ Test all scenarios

