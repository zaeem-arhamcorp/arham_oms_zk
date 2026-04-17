# Cart Quantity Increase Analysis - Comprehensive Issue Report

## Summary
User reports cart item quantities are increasing unexpectedly (doubling, tripling, etc.) after various activities. Analysis reveals **multiple critical issues** in the cart management system that could cause this behavior.

---

## CRITICAL ISSUES IDENTIFIED

### 1. 🔴 **RACE CONDITION in `insertOrUpdateCartItem()` - HIGH PROBABILITY**

**Location:** `lib/services/database_helper.dart`, line 660

**Issue:**
```dart
Future<int> insertOrUpdateCartItem(Map<String, dynamic> item) async {
  final db = await database;
  final existing = await db.query(
    'cart_items',
    where: 'item_cd = ? AND party_cd = ?',
    whereArgs: [item['item_cd'], item['party_cd']],
  );
  if (existing.isNotEmpty) {
    // Update existing
    await db.update('cart_items', item, where: 'id = ?', whereArgs: [existing.first['id']]);
    return existing.first['id'] as int;
  } else {
    // Insert new - BUT WHAT IF ANOTHER THREAD INSERTS BETWEEN QUERY AND INSERT?
    return await db.insert('cart_items', item);
  }
}
```

**Problem:**
- Query checks if item exists (line 663-668)
- Between query result and insert, another thread/coroutine can insert the same item
- Result: **DUPLICATE items in database** with same `item_cd` and `party_cd`

**Trigger Scenarios:**
1. User clicks "Add to Cart" button rapidly (multi-tap)
2. Background sync happens while user is adding items
3. Two add operations initiated nearly simultaneously
4. Profile/Activity change triggers automatic refresh while user adds items

**Evidence:**
- No UNIQUE constraint on `(item_cd, party_cd)` in cart_items table (line 486-502)
- Only `id` is PRIMARY KEY
- The check-then-act pattern is NOT atomic

---

### 2. 🔴 **Inconsistent Deduplication: No Dedup in Fallback Path - HIGH PROBABILITY**

**Location:** `lib/providers/cart_list_provider.dart`, line 173-186

**Online Path (Good):**
```dart
if (response.statusCode == 200) {
  _data.clear();
  final serverItems = cartListModalFromJson(response.body).data;
  _data.addAll(serverItems);  // Server has no duplicates, all good
  
  // Background sync to local DB...
}
```

**Fallback Path (BROKEN - No Deduplication):**
```dart
} catch (e, stack) {
  // If server fails, try loading from local DB as fallback
  try {
    final localCart = await DatabaseHelper().getCartItems(partyId: partyId);
    if (localCart.isNotEmpty) {
      _data.clear();
      for (var item in localCart) {
        try {
          _data.add(DatumCartList.fromLocal(item));  // ❌ ADDS ALL ITEMS WITHOUT CHECKING
        } catch (_) {}
      }
```

**Problem:**
- If local database has duplicate items (from race condition #1)
- They are ALL added to `_data` without any deduplication
- User sees quantity = (qty1 + qty2 + ... for each duplicate copy)

**Trigger Scenarios:**
1. Network error while loading cart + duplicates in local DB
2. API timeout + offline fallback path triggered
3. Server returns error after items already duplicated in local DB

---

### 3. 🟠 **Offline Path Deduplication ADDS Quantities - MEDIUM PROBABILITY**

**Location:** `lib/providers/cart_list_provider.dart`, line 78-100

**Code:**
```dart
// Map to track unique items by item_cd to prevent duplicates
final Map<String, DatumCartList> uniqueItems = {};

for (var item in localCart) {
  try {
    final cartItem = DatumCartList.fromLocal(item);
    final itemCd = item['item_cd'] ?? 'UNKNOWN';

    if (uniqueItems.containsKey(itemCd)) {
      final existing = uniqueItems[itemCd]!;
      // ❌ THIS ADDS THE QUANTITIES!
      existing.quantity = (existing.quantity ?? 0) + (cartItem.quantity ?? 0);
      existing.amount = ((existing.amount ?? 0) + (cartItem.amount ?? 0)).toDouble();
      print("Merged duplicate item: $itemCd");
    } else {
      uniqueItems[itemCd] = cartItem;
    }
  }
}
```

**Problem:**
- If local DB has 2 copies of Item A with qty 5 each
- Deduplication "merges" them by adding: qty 5 + qty 5 = **qty 10** (DOUBLED!)
- If 3 copies: qty 5 + 5 + 5 = **qty 15** (TRIPLED!)

**Trigger Scenario:**
- User is offline, goes to Products page
- Gets cart items from local database
- Items were already duplicated in DB (from race condition)
- Quantities appear doubled/tripled

---

### 4. 🟠 **Background Sync Race Condition - MEDIUM PROBABILITY**

**Location:** `lib/providers/cart_list_provider.dart`, line 140-165

**Code:**
```dart
Future.microtask(() async {
  try {
    final dbHelper = DatabaseHelper();
    await dbHelper.clearCartForParty(partyId);  // Good - clears old
    for (var item in serverItems) {  // Syncs server items
      await CartService().addToCart(...);  // Uses insertOrUpdateCartItem (race condition!)
    }
  }
});
```

**Problem:**
- Background sync running while user might be adding new items
- If user adds Item A while sync is adding Item A, race condition #1 occurs
- Server side cleared correctly, but local DB gets duplicates anyway
- Next getCartItem sees duplicates and either:
  - Falls back with duplicates (issue #2)
  - Deduplicates by adding (issue #3)

**Trigger Scenarios:**
1. User refreshes cart while items still syncing
2. Activity recognition event triggers refresh during sync
3. Rapid screen navigation causes multiple getCartItem calls

---

### 5. 🟡 **Multiple getCartItem Calls Without State Isolation - MEDIUM PROBABILITY**

**Locations:**
- `lib/product/ui/product_page.dart` - line 124 (initState)
- `lib/product/ui/product_page.dart` - line 1236 (END order)
- `lib/product/ui/product_page.dart` - line 1434 (START order)
- `lib/views/shoppingCartPage.dart` - line 269 (init)
- `lib/views/shoppingCartPage.dart` - line 740 (delete item)
- `lib/providers/party_provider.dart` - line 90 (party change)

**Problem:**
- Multiple calls to `cart.getCartItem()` for same party
- Each call fetches from server/DB independently
- If called while sync is in progress, items could be loaded before/after partial sync
- Could result in mixed state

---

### 6. 🟡 **No Unique Constraint on Cart Items - DESIGN FLAW**

**Location:** `lib/services/database_helper.dart`, line 486-502

**Current Schema:**
```sql
CREATE TABLE cart_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  party_cd TEXT,
  item_cd TEXT NOT NULL,
  quantity REAL DEFAULT 0,
  -- ... other fields ...
)
```

**Missing:**
```sql
UNIQUE (item_cd, party_cd)  -- ❌ THIS IS MISSING!
```

**Impact:**
- Database allows duplicates at the schema level
- No constraint to prevent race condition outcomes
- insertOrUpdateCartItem logic is only defense, but it's flawed

---

## SCENARIO WALKTHROUGHS

### Scenario A: Quantity Doubled (Most Common)
```
1. User opens Products page
2. Adds Item A (qty 5)
   → insertOrUpdateCartItem called
3. RACE CONDITION:
   - Thread 1: Query returns empty
   - Thread 2: Query returns empty  
   - Thread 1: Insert Item A (qty 5)
   - Thread 2: Insert Item A (qty 5)
4. Database now has 2 rows for Item A, both qty 5
5. User navigates away/back to Products page
6. getCartItem called
   → Online: Server has 1 item (qty 5), syncs correctly
7. But if network error or offline:
   → Fallback loads from DB
   → Finds 2 items without dedup: qty 5 + qty 5 = TOTAL QTY 10 (DOUBLED!)
```

### Scenario B: Quantity Tripled (During Activity Change)
```
1. User adds Item A (qty 5) - duplicates created in DB (2 copies)
2. Activity recognition event triggers refresh
3. getCartItem called with offline mode
   → Offline path: Loads 2 duplicate items
   → Dedup logic adds: 5 + 5 = 10
4. Activity changes again, another refresh
5. getCartItem called again
   → Server now has Item A (qty 5) synced
   → But local DB still corrupted with duplicates
   → If sync races, might load duplicates again
6. User sees quantity: 10 + 5 = 15 (TRIPLED!)
```

### Scenario C: Profile/Settings Change
```
1. Items added, duplicates in DB (qty 5 + qty 5)
2. Profile loads new settings
3. Stock
ist setting changes, triggers cart refresh
4. getCartItem called multiple times during setting load
5. Fallback path on error: Sees 2 items without dedup
6. Quantity = 10 (DOUBLED!)
```

---

## ROOT CAUSE RANKING

| Issue | Likelihood | Impact | Frequency |
|-------|-----------|--------|-----------|
| Race condition in insertOrUpdateCartItem | 🔴 HIGH | Creates duplicates | When user multi-taps or rapid operations |
| Fallback dedup-missing path | 🔴 HIGH | Shows duplicates to UI | When network error + offline |
| Offline dedup adds quantities | 🟠 MEDIUM | Visible quantity increase | When offline or after network error |
| Background sync race | 🟠 MEDIUM | Can create duplicates | During cart refresh while syncing |
| Multiple getCartItem calls | 🟡 LOW | State confusion | During screen navigation |
| No unique constraint | 🟡 LOW | Enables issues 1-4 | Systemic issue |

---

## CRITICAL FINDINGS

1. **Duplicates CAN be created in database** through race condition
2. **UI can show duplicates without dedup** in fallback path
3. **Quantities WILL be added** when duplicates are deduplicated offline
4. **Each of the top 3 issues can independently cause the complaint**
5. **Combined issues create cascading failures**

---

## FILES INVOLVED

- `lib/services/database_helper.dart` - insertOrUpdateCartItem, _createCartItemsTable, getCartItems, clearCartForParty
- `lib/providers/cart_list_provider.dart` - getCartItem (main culprit)
- `lib/services/cart_service.dart` - addToCart (calls insertOrUpdateCartItem)
- `lib/services/sync_service.dart` - syncOfflineOrder (background sync)
- `lib/product/ui/product_page.dart` - Multiple getCartItem calls
- `lib/views/shoppingCartPage.dart` - Multiple getCartItem calls

---

## NEXT STEPS FOR FIXES

### Priority 1: Fix Race Condition (Critical)
- Add UNIQUE constraint to cart_items table
- Use transaction-based insertOrReplace
- Atomic operation for check-then-act

### Priority 2: Add Deduplication to Fallback Path (Critical)
- Apply same dedup logic as offline path
- OR: Use UNIQUE constraint to prevent duplicates

### Priority 3: Fix Offline Dedup Logic (Important)
- Don't ADD quantities when deduplicating
- This is a merging bug - should REPLACE not ADD

### Priority 4: Add State Guards (Important)
- Prevent concurrent getCartItem calls
- Queue requests or use mutex
- Ensure only one active getCartItem per party

### Priority 5: Database Schema Fix (Systemic)
- Add UNIQUE (item_cd, party_cd) constraint
- Prevents issues at schema level

---

## Testing Recommendations

```
Test 1: Multi-tap add
- Add same item 10 times rapidly
- Check quantity is not 50x
- Expected: qty 5 (or ask user)

Test 2: Network error during load
- Add items
- Go offline
- Trigger getCartItem
- Quantity should not double

Test 3: Login/logout cycle
- Add items
- Logout
- Login
- Check quantities unchanged

Test 4: Activity recognition
- Add items
- Trigger activity recognition events
- Quantities should not change

Test 5: Background sync collision
- Add items
- Refresh cart while sync happening
- Quantities should remain consistent

Test 6: Rapid party switching
- Switch parties rapidly
- Add items to each
- Each party should have correct qty
```

---

## Summary

The user's complaint of **increasing quantities** is most likely caused by a combination of:

1. **Race condition creating duplicates** in the local database (via insertOrUpdateCartItem)
2. **Missing deduplication in error fallback path** (allowing duplicates to reach UI)
3. **Dedup logic adding quantities** (turning duplicates into visible quantity increases)

The fix requires addressing all three issues, with priority on the race condition (issue #1).
