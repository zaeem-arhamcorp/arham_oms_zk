# Comprehensive Field Mapping Audit

## API Response Fields (Actual from user's JSON)
Based on the API response provided, these are ALL fields at top level:
1. NRATE
2. AVL_STK
3. ITEM_CD
4. ADOPTED_ITEM_CD (not mapped anywhere)
5. ITEM_CD2
6. ITEM_NAME
7. ITEM_SNAME
8. ITEM_LNAME
9. SCHEDULE_TYPE
10. TO_ORDER_STATUS (not mapped anywhere)
11. ISDRAFT (not mapped anywhere)
12. DRUG_CD (not mapped anywhere)
13. DEPT_CD
14. DNAME (not mapped anywhere)
15. GST_PERC
16. CESS (not mapped anywhere)
17. TAX_INCLUDED_YN (not mapped anywhere)
18. IS_SERVICES (not mapped anywhere)
19. IS_FROM_SERVER (not mapped anywhere)
20. HSN_NO
21. UNIT
22. ITEM_TYPE
23. PRATE
24. SRATE1
25. SRATE2 ⚠️ **NOT in ProductItem model**
26. SRATE3
27. SRATE4 ⚠️ **NOT in ProductItem model**
28. SRATE5 ⚠️ **NOT in ProductItem model**
29. O_RATE (not mapped anywhere)
30. MRP ⚠️ **Cached but NOT in ProductItem.fromJson()**
31. NEW_MRP (not mapped anywhere)
32. T_LAND
33. FRML_SRT1
34. PDISC
35. SDISC
36. SDISC1
37. C_STK
38. OR_STK
39. O_STK (not mapped anywhere)
40. DR_STOCK (not mapped anywhere)
41. CR_STOCK (not mapped anywhere)
42. MIN_STK (not mapped anywhere)
43. RE_ORDER_QTY (not mapped anywhere)
44. STOCK_EFFECT (not mapped anywhere)
45. GST_STAXCD (not mapped anywhere)
46. LAST_SIZE (not mapped anywhere)
47. EX_DT
48. BLACKLIST
49. SYNC_ID
50. ITEM_GRADE
51. RACK_NO
52. ITEM_CAT
53. SUBCAT
54. ITEM_BRAND
55. ITEM_DESC
+ Nested: deptment, itemdtls, item_image, item_barcodes, tax

---

## ProductItem Model (lib/product/model/product_model.dart)
### Fields Defined:
- itemCd2 ✓
- nrate ✓
- avlStk ✓
- exDt ✓
- rackNo ✓
- itemCat ✓
- subCat ✓
- itemBrand ✓
- itemCd ✓
- itemName ✓
- itemSname ✓
- itemLname ✓
- deptCd ✓
- srate1 ✓
- srate3 ✓
- ⚠️ **srate2 - NOT DEFINED** (API has SRATE2)
- ⚠️ **srate4 - NOT DEFINED** (API has SRATE4)
- ⚠️ **srate5 - NOT DEFINED** (API has SRATE5)
- syncId ✓
- itemGrade ✓
- itemDesc ✓
- prate ✓
- pdisc ✓
- tLAND ✓ (note: mixed case!)
- gstPerc ✓
- frmlSrt1 ✓
- sdisc ✓
- sdisc1 ✓
- cStk ✓
- orStk ✓
- ⚠️ **mrp - NOT DEFINED** (but cached in database_helper)
- deptment ✓
- itemImages ✓

### ProductItem.fromJson() Key Mappings:
```dart
itemCd2: json['ITEM_CD2']
nrate: json['NRATE']
avlStk: json['AVL_STK']
exDt: json['EX_DT']
rackNo: json['RACK_NO']
itemCat: json['ITEM_CAT']
subCat: json['SUBCAT']
itemBrand: json['ITEM_BRAND']
itemCd: json['ITEM_CD']
itemName: json['ITEM_NAME']
itemSname: json['ITEM_SNAME']
itemLname: json['ITEM_LNAME']
deptCd: json['DEPT_CD']
srate1: json['SRATE1']
srate3: json['SRATE3']
syncId: json['SYNC_ID']
itemGrade: json['ITEM_GRADE']
itemDesc: json['ITEM_DESC']
prate: json['PRATE']
pdisc: json['PDISC']
tLAND: json['T_LAND']
gstPerc: json['GST_PERC']
frmlSrt1: json['FRML_SRT1']
sdisc: json['SDISC']
sdisc1: json['SDISC1']
cStk: json['C_STK']
orStk: json['OR_STK']
deptment: json['deptment']
itemImages: json['item_images'] ⚠️ **LOWERCASE, not ITEM_IMAGES**
```

---

## Product Controller Caching (product_controller.dart line 145-177)
### Fields Being Cached:
```dart
'ITEM_CD': product.itemCd ✓
'ITEM_CD2': product.itemCd2 ✓
'ITEM_NAME': product.itemName ✓
'ITEM_SNAME': product.itemSname ✓
'ITEM_LNAME': product.itemLname ✓
'DEPT_CD': product.deptCd ✓
'NRATE': product.nrate ✓
'SRATE1': product.srate1 ✓
'SRATE3': product.srate3 ✓
'PRATE': product.prate ✓
'PDISC': product.pdisc ✓
'ITEM_BRAND': product.itemBrand ✓
'ITEM_CAT': product.itemCat ✓
'ITEM_IMAGES': product.itemImages ⚠️ **BUG: Should be 'item_images'**
'C_STK': product.cStk ✓
'OR_STK': product.orStk ✓
'AVL_STK': product.avlStk ✓
'SDISC': product.sdisc ✓
'SDISC1': product.sdisc1 ✓
'EX_DT': product.exDt ✓
'RACK_NO': product.rackNo ✓
'ITEM_GRADE': product.itemGrade ✓
'ITEM_DESC': product.itemDesc ✓
'GST_PERC': product.gstPerc ✓
'T_LAND': product.tLAND ✓
'FRML_SRT1': product.frmlSrt1 ✓
'SYNC_ID': product.syncId ✓
'deptment': product.deptment.toJson() ✓
```

### Missing from Caching:
- SRATE2 (Product doesn't have it)
- SRATE4 (Product doesn't have it)
- SRATE5 (Product doesn't have it)
- MRP (Not being cached but database tries to cache it)

---

## Database Helper Normalization (database_helper.dart)
### Issues Found:

1. **Mapping 'item_images' (CORRECT):**
```dart
if (productData.containsKey('ITEM_IMAGES')) {
  normalized['item_images'] = productData['ITEM_IMAGES'];
}
```
✓ Correctly handles ITEM_IMAGES → item_images

2. **Missing field in keyMappings:**
- MRP is in the individual column insert but NOT in the _normalizeProductJson keyMappings

3. **Database columns trying to cache:**
```dart
'mrp': _toDouble(productData['MRP'] ?? productData['mrp']),
'srate2': _toDouble(productData['SRATE2'] ?? productData['srate2']),
'srate4': _toDouble(productData['SRATE4'] ?? productData['srate4']),
'srate5': _toDouble(productData['SRATE5'] ?? productData['srate5']),
```
These fields come from the API but productData might not have them (since they're not in ProductItem).

---

## CRITICAL ISSUES FOUND

### 1. **ITEM_IMAGES vs item_images ⚠️**
**Location:** product_controller.dart line 161
**Issue:** Caching uses `'ITEM_IMAGES'` but ProductItem expects `'item_images'` (lowercase)
**Impact:** itemImages list will be empty after loading from cache
**Fix:** Change line 161 from:
```dart
'ITEM_IMAGES': product.itemImages,
```
To:
```dart
'item_images': product.itemImages,
```

### 2. **Missing SRATE2, SRATE4, SRATE5 fields ⚠️**
**Location:** ProductItem model
**Issue:** API returns SRATE2, SRATE4, SRATE5, MRP but ProductItem model only has srate1 and srate3
**Impact:** These fields are lost when converting API response to ProductItem
**Fix:** Add missing fields to ProductItem (optional - depends on if UI needs them)

### 3. **MRP field mismatch ⚠️**
**Location:** database_helper.dart line 829
**Issue:** Trying to cache 'mrp' but it's not in ProductItem or being sent from product_controller
**Impact:** MRP column will always be NULL in database
**Fix:** Either:
   - Add MRP to ProductItem model, OR
   - Remove MRP from database caching

### 4. **Missing MRP in keyMappings ⚠️**
**Location:** database_helper.dart _normalizeProductJson()
**Issue:** MRP is not in the keyMappings dictionary
**Impact:** Won't be normalized properly
**Fix:** Add to keyMappings

---

## Verification Checklist

- [x] **FIXED** - Changed ITEM_IMAGES → item_images in product_controller.dart (line 160)
- [ ] Consider: Add srate2, srate4, srate5, mrp to ProductItem model if UI needs them
- [x] Confirmed - MRP is in _normalizeProductJson keyMappings
- [ ] Clear database and re-cache
- [ ] Test offline product display

---

## FIXES APPLIED

### ✅ Fix #1: ITEM_IMAGES Case Bug
**File:** `lib/product/controller/product_controller.dart` line 160
**Changed:**
```dart
'ITEM_IMAGES': product.itemImages,  ❌ WRONG
```
**To:**
```dart
'item_images': product.itemImages,  ✅ CORRECT
```
**Reason:** ProductItem.fromJson() expects `json['item_images']` (lowercase), not `ITEM_IMAGES`

---

## REMAINING ISSUES

### Optional: Missing Fields in ProductItem Model
**Fields that API returns but ProductItem doesn't support:**
- SRATE2, SRATE4, SRATE5 - Only srate1 and srate3 are in ProductItem
- MRP - Not in ProductItem, but being cached by database

**Impact:** These fields are lost or ignored
**Decision Required:** Do you need these fields displayed in the UI?

- If **NO**: Leave as is
- If **YES**: Add these properties to ProductItem model

---

## NEXT ACTIONS

1. ✅ DONE: Fix ITEM_IMAGES → item_images
2. **TODO:** Clear database cache (Settings > Storage > Clear Data)
3. **TODO:** Re-login to re-cache products with corrected field names
4. **TODO:** Verify offline product display includes images, expiry dates, etc.
5. **Optional:** Add SRATE2/4/5 and MRP to ProductItem if needed for UI
