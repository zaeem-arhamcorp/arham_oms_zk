import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../config/app_config.dart';
import '../../../config/app_log.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/user_provider.dart';
import '../core/account_repository.dart';
import '../models/account_model.dart';
import '../widgets/account_form_fields.dart';

class PlaceSuggestion {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  const PlaceSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    final structured = json['structured_formatting'] as Map<String, dynamic>?;
    return PlaceSuggestion(
      placeId: (json['place_id'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      mainText:
          (structured?['main_text'] ?? json['description'] ?? '').toString(),
      secondaryText: (structured?['secondary_text'] ?? '').toString(),
    );
  }
}

enum AccountLocationMode { current, address }

class AccountController extends GetxController {
  static const String _googlePlacesApiKey = AppConfig.googlePlacesApiKey;

  bool locationLocked = false;

  final RxBool isLocationLoading = false.obs;
  final RxString latitudeRx = ''.obs;
  final RxString longitudeRx = ''.obs;
  final Rx<AccountLocationMode> locationMode = AccountLocationMode.current.obs;

  final RxBool showAddressSearch = false.obs;
  final RxBool isPlaceSearchLoading = false.obs;
  final RxList<PlaceSuggestion> placeSuggestions = <PlaceSuggestion>[].obs;
  final RxString placeSearchQuery = ''.obs;
  final TextEditingController placeSearchController = TextEditingController();

  final Rx<LatLng?> selectedLatLng = Rx<LatLng?>(null);
  static const LatLng _defaultMapCenter = LatLng(23.0225, 72.5714);

  LatLng get defaultMapCenter => _defaultMapCenter;

  GoogleMapController? _googleMapController;
  Timer? _markerDragDebounce;
  Timer? _placeSearchDebounce;
  Timer? _addressFieldDebounce;
  String _placesSessionToken = '';
  bool _ignorePlaceSearchChange = false;
  bool _ignoreAddressFieldUpdates = false;
  bool _didInitLocation = false;
  final AccountRepository _repository = Get.find<AccountRepository>();

  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString successMessage = ''.obs;
  final RxBool isLicensedVisible = false.obs;

  final Rx<File?> selectedImage = Rx<File?>(null);
  final ImagePicker _picker = ImagePicker();

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final locationProvider =
      Provider.of<LocationProvider>(Get.context!, listen: false);

  @override
  void onInit() {
    super.onInit();
    _attachAddressFieldListeners();
  }

  void _attachAddressFieldListeners() {
    AccountFormFields.add1Controller.addListener(_onAddressFieldChanged);
    AccountFormFields.areaController.addListener(_onAddressFieldChanged);
    AccountFormFields.cityController.addListener(_onAddressFieldChanged);
    AccountFormFields.stateController.addListener(_onAddressFieldChanged);
    AccountFormFields.pincodeController.addListener(_onAddressFieldChanged);
  }

  void _detachAddressFieldListeners() {
    AccountFormFields.add1Controller.removeListener(_onAddressFieldChanged);
    AccountFormFields.areaController.removeListener(_onAddressFieldChanged);
    AccountFormFields.cityController.removeListener(_onAddressFieldChanged);
    AccountFormFields.stateController.removeListener(_onAddressFieldChanged);
    AccountFormFields.pincodeController.removeListener(_onAddressFieldChanged);
  }

  void _onAddressFieldChanged() {
    if (_ignoreAddressFieldUpdates) {
      return;
    }

    _addressFieldDebounce?.cancel();
    _addressFieldDebounce = Timer(const Duration(milliseconds: 800), () {
      _forwardGeocodeAddressFields();
    });
  }

  Future<void> _forwardGeocodeAddressFields() async {
    if (locationLocked) {
      return;
    }

    final addressQuery = _buildAddressQueryFromFields();
    if (addressQuery.isEmpty) {
      return;
    }

    try {
      final locations = await geocoding.locationFromAddress(addressQuery);
      if (locations.isEmpty) {
        return;
      }

      final location = locations.first;
      _updateLatLong(location.latitude, location.longitude, animateMap: true);
      appLog(
        '[_forwardGeocodeAddressFields] query="$addressQuery" lat=${location.latitude}, long=${location.longitude}',
        tag: 'AccountController',
      );
    } catch (e, stackTrace) {
      appLog(
        'Forward geocode from address fields error: $e',
        tag: 'AccountController',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  void onClose() {
    appLog('onClose called', tag: 'AccountController');
    _markerDragDebounce?.cancel();
    _markerDragDebounce = null;
    _placeSearchDebounce?.cancel();
    _placeSearchDebounce = null;
    _addressFieldDebounce?.cancel();
    _addressFieldDebounce = null;
    _detachAddressFieldListeners();
    _googleMapController?.dispose();
    _googleMapController = null;
    placeSearchController.dispose();
    AccountFormFields.clearAll();
    super.onClose();
  }

  Future<void> onCurrentButtonPressed() async {
    if (locationLocked) {
      return;
    }

    showAddressSearch.value = false;
    clearPlaceSuggestions();
    await useCurrentLocationAndFillAddress();
  }

  Future<void> onAddressButtonPressed() async {
    if (locationLocked) {
      return;
    }

    showAddressSearch.value = true;
    locationMode.value = AccountLocationMode.address;

    final hasAddressInput = _buildAddressQueryFromFields().isNotEmpty;
    if (hasAddressInput) {
      await useAddressAndResolveLocation(showFailureSnackbar: false);
    }
  }

  void clearPlaceSuggestions() {
    _placeSearchDebounce?.cancel();
    placeSuggestions.clear();
    isPlaceSearchLoading.value = false;
  }

  void clearPlaceSearch() {
    _ignorePlaceSearchChange = true;
    placeSearchController.clear();
    _ignorePlaceSearchChange = false;
    placeSearchQuery.value = '';
    clearPlaceSuggestions();
  }

  void onPlaceSearchChanged(String rawQuery) {
    if (_ignorePlaceSearchChange) {
      return;
    }

    placeSearchQuery.value = rawQuery;

    final query = rawQuery.trim();
    _placeSearchDebounce?.cancel();

    if (query.length < 2) {
      placeSuggestions.clear();
      isPlaceSearchLoading.value = false;
      if (query.isEmpty) {
        _placesSessionToken = '';
      }
      return;
    }

    if (_placesSessionToken.isEmpty) {
      _placesSessionToken = DateTime.now().millisecondsSinceEpoch.toString();
    }

    _placeSearchDebounce = Timer(const Duration(milliseconds: 350), () async {
      await _fetchPlaceSuggestions(query);
    });
  }

  Future<void> _fetchPlaceSuggestions(String query) async {
    if (_googlePlacesApiKey.trim().isEmpty) {
      appLog(
        'Google Places API key is missing',
        tag: 'AccountController',
      );
      placeSuggestions.clear();
      return;
    }

    isPlaceSearchLoading.value = true;
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        {
          'input': query,
          'key': _googlePlacesApiKey,
          'sessiontoken': _placesSessionToken,
          'types': 'geocode',
        },
      );

      final response = await http.get(uri);
      if (response.statusCode != 200) {
        placeSuggestions.clear();
        appLog(
          'Places autocomplete failed: HTTP ${response.statusCode}',
          tag: 'AccountController',
        );
        return;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final status = (json['status'] ?? '').toString();

      if (status == 'OK') {
        final predictions = (json['predictions'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(PlaceSuggestion.fromJson)
            .toList();
        placeSuggestions.assignAll(predictions);
      } else if (status == 'ZERO_RESULTS') {
        placeSuggestions.clear();
      } else {
        placeSuggestions.clear();
        appLog(
          'Places autocomplete error status: $status body=${response.body}',
          tag: 'AccountController',
        );
      }
    } catch (e, stackTrace) {
      placeSuggestions.clear();
      appLog(
        'Autocomplete exception: $e',
        tag: 'AccountController',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      isPlaceSearchLoading.value = false;
    }
  }

  Future<void> onPlaceSuggestionSelected(PlaceSuggestion suggestion) async {
    locationMode.value = AccountLocationMode.address;
    showAddressSearch.value = true;

    _ignorePlaceSearchChange = true;
    placeSearchController.text = suggestion.description;
    placeSearchController.selection = TextSelection.fromPosition(
      TextPosition(offset: placeSearchController.text.length),
    );
    _ignorePlaceSearchChange = false;
    placeSearchQuery.value = suggestion.description;

    clearPlaceSuggestions();

    if (_googlePlacesApiKey.trim().isEmpty || suggestion.placeId.isEmpty) {
      return;
    }

    isLocationLoading.value = true;
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/details/json',
        {
          'place_id': suggestion.placeId,
          'key': _googlePlacesApiKey,
          'sessiontoken': _placesSessionToken,
          'fields': 'address_component,geometry,formatted_address,name',
        },
      );

      final response = await http.get(uri);
      if (response.statusCode != 200) {
        appLog(
          'Place details failed: HTTP ${response.statusCode}',
          tag: 'AccountController',
        );
        return;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final status = (json['status'] ?? '').toString();
      if (status != 'OK') {
        appLog(
          'Place details error status: $status body=${response.body}',
          tag: 'AccountController',
        );
        return;
      }

      final result = json['result'] as Map<String, dynamic>?;
      if (result == null) {
        return;
      }

      final geometry = result['geometry'] as Map<String, dynamic>?;
      final location = geometry?['location'] as Map<String, dynamic>?;
      final lat = (location?['lat'] as num?)?.toDouble();
      final lng = (location?['lng'] as num?)?.toDouble();

      if (lat != null && lng != null) {
        _updateLatLong(lat, lng);
      }

      final addressComponents =
          (result['address_components'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .toList();
      _fillAddressFromPlaceDetails(
        components: addressComponents,
        formattedAddress: (result['formatted_address'] ?? '').toString(),
        placeName: (result['name'] ?? '').toString(),
      );
    } catch (e, stackTrace) {
      appLog(
        'Place details exception: $e',
        tag: 'AccountController',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _placesSessionToken = '';
      isLocationLoading.value = false;
    }
  }

  void _fillAddressFromPlaceDetails({
    required List<Map<String, dynamic>> components,
    required String formattedAddress,
    required String placeName,
  }) {
    _ignoreAddressFieldUpdates = true;
    try {
      String? valueByType(String type) {
        for (final component in components) {
          final types = (component['types'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList();
          if (types.contains(type)) {
            final value = (component['long_name'] ?? '').toString().trim();
            if (value.isNotEmpty) {
              return value;
            }
          }
        }
        return null;
      }

      final streetNumber = valueByType('street_number') ?? '';
      final route = valueByType('route') ?? '';
      final add1 = [streetNumber, route]
          .where((part) => part.trim().isNotEmpty)
          .join(' ')
          .trim();

      final firstLineFromFormatted = _firstAddressSegment(formattedAddress);

      AccountFormFields.add1Controller.text = _firstNonEmpty([
        add1,
        placeName,
        firstLineFromFormatted,
      ]);
      AccountFormFields.areaController.text = _firstNonEmpty([
        valueByType('sublocality_level_1'),
        valueByType('sublocality'),
        valueByType('neighborhood'),
        valueByType('locality'),
      ]);
      AccountFormFields.cityController.text = _firstNonEmpty([
        valueByType('locality'),
        valueByType('administrative_area_level_2'),
        valueByType('sublocality_level_1'),
      ]);
      AccountFormFields.stateController.text = _firstNonEmpty([
        valueByType('administrative_area_level_1'),
      ]);
      AccountFormFields.pincodeController.text = _firstNonEmpty([
        valueByType('postal_code'),
      ]);
    } finally {
      _ignoreAddressFieldUpdates = false;
    }
  }

  String _firstAddressSegment(String formattedAddress) {
    final normalized = formattedAddress.trim();
    if (normalized.isEmpty) {
      return '';
    }
    final parts = normalized.split(',');
    return parts.first.trim();
  }

  void toggleLicenseFields(bool value) {
    isLicensedVisible.value = value;
    appLog('toggleLicenseFields called with value: $value',
        tag: 'AccountController');
  }

  Future<void> pickImage({required ImageSource source}) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        selectedImage.value = File(pickedFile.path);
        appLog('Image selected: ${pickedFile.path}', tag: 'AccountController');
      } else {
        appLog('No image selected', tag: 'AccountController');
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to pick image');
      appLog('Image pick error: $e', tag: 'AccountController');
    }
  }

  // Remove image
  void removeImage() {
    selectedImage.value = null;
    appLog('Image removed', tag: 'AccountController');
  }

  Future<void> ensureInitialLocation() async {
    if (_didInitLocation) {
      return;
    }
    _didInitLocation = true;
    await useCurrentLocationAndFillAddress(showFailureSnackbar: false);
  }

  void onMapCreated(GoogleMapController controller) {
    _googleMapController = controller;
    final target = selectedLatLng.value;
    if (target != null) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
    }
  }

  Future<void> _animateMapTo(LatLng target) async {
    final controller = _googleMapController;
    if (controller == null) {
      return;
    }
    await controller.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
  }

  void _updateLatLong(
    double latitude,
    double longitude, {
    bool animateMap = true,
  }) {
    if (locationLocked) {
      return;
    }

    AccountFormFields.latitudeController.text = latitude.toString();
    AccountFormFields.longitudeController.text = longitude.toString();
    latitudeRx.value = latitude.toString();
    longitudeRx.value = longitude.toString();

    final target = LatLng(latitude, longitude);
    selectedLatLng.value = target;
    if (animateMap) {
      _animateMapTo(target);
    }
  }

  void _updateLatLongTextOnly(double latitude, double longitude) {
    if (locationLocked) {
      return;
    }

    AccountFormFields.latitudeController.text = latitude.toString();
    AccountFormFields.longitudeController.text = longitude.toString();
    latitudeRx.value = latitude.toString();
    longitudeRx.value = longitude.toString();
  }

  void _fillAddressControllers(geocoding.Placemark p) {
    _ignoreAddressFieldUpdates = true;
    try {
      final addressLine = [
        p.name,
        p.subThoroughfare,
        p.thoroughfare,
      ].where((element) => (element ?? '').trim().isNotEmpty).join(' ').trim();

      AccountFormFields.add1Controller.text =
          addressLine.isNotEmpty ? addressLine : _firstNonEmpty([p.street]);
      AccountFormFields.areaController.text =
          _firstNonEmpty([p.subLocality, p.locality]);
      AccountFormFields.cityController.text =
          _firstNonEmpty([p.locality, p.subAdministrativeArea]);
      AccountFormFields.stateController.text =
          _firstNonEmpty([p.administrativeArea]);
      AccountFormFields.pincodeController.text = _firstNonEmpty([p.postalCode]);
    } finally {
      _ignoreAddressFieldUpdates = false;
    }
  }

  Future<void> _reverseGeocodeAndFillAddress(
    double latitude,
    double longitude, {
    bool showFailureSnackbar = false,
  }) async {
    try {
      final placemarks =
          await geocoding.placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        _fillAddressControllers(placemarks.first);
      }
    } catch (e, stackTrace) {
      appLog(
        'reverseGeocode error: $e',
        tag: 'AccountController',
        error: e,
        stackTrace: stackTrace,
      );
      if (showFailureSnackbar) {
        Get.snackbar('Location', 'Unable to resolve address from map pin');
      }
    }
  }

  void onMarkerDrag(LatLng position) {
    if (locationLocked) {
      return;
    }

    locationMode.value = AccountLocationMode.address;
    // Keep the map smooth while dragging by updating only text fields in real-time.
    _updateLatLongTextOnly(position.latitude, position.longitude);

    _markerDragDebounce?.cancel();
    _markerDragDebounce = Timer(const Duration(milliseconds: 450), () {
      _reverseGeocodeAndFillAddress(
        position.latitude,
        position.longitude,
        showFailureSnackbar: false,
      );
    });
  }

  Future<void> onMarkerDragEnd(LatLng position) async {
    if (locationLocked) {
      return;
    }

    locationMode.value = AccountLocationMode.address;
    _updateLatLong(
      position.latitude,
      position.longitude,
      animateMap: false,
    );

    _markerDragDebounce?.cancel();
    await _reverseGeocodeAndFillAddress(
      position.latitude,
      position.longitude,
      showFailureSnackbar: true,
    );
  }

  Future<void> onMapTap(LatLng position) async {
    if (locationLocked) {
      return;
    }

    locationMode.value = AccountLocationMode.address;
    _updateLatLong(
      position.latitude,
      position.longitude,
      animateMap: false,
    );

    _markerDragDebounce?.cancel();
    await _reverseGeocodeAndFillAddress(
      position.latitude,
      position.longitude,
      showFailureSnackbar: false,
    );
  }

  String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final v = (value ?? '').trim();
      if (v.isNotEmpty) {
        return v;
      }
    }
    return '';
  }

  String _buildAddressQueryFromFields() {
    final parts = [
      AccountFormFields.add1Controller.text.trim(),
      AccountFormFields.areaController.text.trim(),
      AccountFormFields.cityController.text.trim(),
      AccountFormFields.stateController.text.trim(),
      AccountFormFields.pincodeController.text.trim(),
    ].where((element) => element.isNotEmpty).toList();

    return parts.join(', ');
  }

  Future<bool> useCurrentLocationAndFillAddress({
    bool showFailureSnackbar = true,
  }) async {
    if (locationLocked) {
      return false;
    }

    locationMode.value = AccountLocationMode.current;
    showAddressSearch.value = false;
    clearPlaceSuggestions();
    isLocationLoading.value = true;

    try {
      await locationProvider.getCurrentLocation();
      final latitude = locationProvider.lat;
      final longitude = locationProvider.lag;

      if (latitude == 0.0 && longitude == 0.0) {
        if (showFailureSnackbar) {
          Get.snackbar('Location', 'Unable to fetch current location');
        }
        return false;
      }

      _updateLatLong(latitude, longitude);
      await _reverseGeocodeAndFillAddress(
        latitude,
        longitude,
        showFailureSnackbar: showFailureSnackbar,
      );

      appLog(
        '[useCurrentLocationAndFillAddress] lat=$latitude, long=$longitude',
        tag: 'AccountController',
      );
      return true;
    } catch (e, stackTrace) {
      appLog(
        'useCurrentLocationAndFillAddress error: $e',
        tag: 'AccountController',
        error: e,
        stackTrace: stackTrace,
      );
      if (showFailureSnackbar) {
        Get.snackbar('Location', 'Unable to resolve current location');
      }
      return false;
    } finally {
      isLocationLoading.value = false;
    }
  }

  Future<bool> useAddressAndResolveLocation({
    bool showFailureSnackbar = true,
  }) async {
    if (locationLocked) {
      return false;
    }

    locationMode.value = AccountLocationMode.address;
    showAddressSearch.value = true;
    isLocationLoading.value = true;

    try {
      final addressQuery = _buildAddressQueryFromFields();
      if (addressQuery.isEmpty) {
        if (showFailureSnackbar) {
          Get.snackbar('Address', 'Please enter address details first');
        }
        return false;
      }

      final locations = await geocoding.locationFromAddress(addressQuery);
      if (locations.isEmpty) {
        if (showFailureSnackbar) {
          Get.snackbar('Address', 'Unable to fetch lat/long for this address');
        }
        return false;
      }

      final location = locations.first;
      _updateLatLong(location.latitude, location.longitude);
      appLog(
        '[useAddressAndResolveLocation] query="$addressQuery" lat=${location.latitude}, long=${location.longitude}',
        tag: 'AccountController',
      );
      return true;
    } catch (e, stackTrace) {
      appLog(
        'useAddressAndResolveLocation error: $e',
        tag: 'AccountController',
        error: e,
        stackTrace: stackTrace,
      );
      if (showFailureSnackbar) {
        Get.snackbar('Address', 'Unable to fetch lat/long for this address');
      }
      return false;
    } finally {
      isLocationLoading.value = false;
    }
  }

  Future<void> updateLocationFields() async {
    if (locationLocked) {
      return;
    }

    await useCurrentLocationAndFillAddress(showFailureSnackbar: false);
  }

  void seedLockedLocation(double latitude, double longitude) {
    AccountFormFields.latitudeController.text = latitude.toString();
    AccountFormFields.longitudeController.text = longitude.toString();
    latitudeRx.value = latitude.toString();
    longitudeRx.value = longitude.toString();
    selectedLatLng.value = LatLng(latitude, longitude);
  }

  Future<void> createAccountFromForm(BuildContext context) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      successMessage.value = '';

      final hasLatLong =
          AccountFormFields.latitudeController.text.trim().isNotEmpty &&
              AccountFormFields.longitudeController.text.trim().isNotEmpty;

      if (!hasLatLong) {
        if (locationMode.value == AccountLocationMode.address) {
          await useAddressAndResolveLocation(showFailureSnackbar: false);
        } else {
          await useCurrentLocationAndFillAddress(showFailureSnackbar: false);
        }
      }

      final account = AccountModel(
        accName: AccountFormFields.accNameController.text.trim(),
        personNm: AccountFormFields.personNmController.text.trim(),
        mobile1: AccountFormFields.mobile1Controller.text.trim(),
        add1: AccountFormFields.add1Controller.text.trim(),
        area: AccountFormFields.areaController.text.trim(),
        city: AccountFormFields.cityController.text.trim(),
        state: AccountFormFields.stateController.text.trim(),
        pincode: AccountFormFields.pincodeController.text.trim(),
        beatCd: AccountFormFields.beatCdController.text.trim(),
        latitude:
            double.tryParse(AccountFormFields.latitudeController.text) ?? 0.0,
        longitude:
            double.tryParse(AccountFormFields.longitudeController.text) ?? 0.0,
        // 🔹 License fields (only if visible)
        gstNo: isLicensedVisible.value
            ? AccountFormFields.gstNoController.text.trim()
            : '',
        gstType: AccountFormFields.gstNoController.text.trim().isNotEmpty
            ? 'R'
            : 'U',
        drugLic1: isLicensedVisible.value
            ? AccountFormFields.drugLic1Controller.text.trim()
            : '',
        drugLic2: isLicensedVisible.value
            ? AccountFormFields.drugLic2Controller.text.trim()
            : '',
        fssaiNo: isLicensedVisible.value
            ? AccountFormFields.fssaiNoController.text.trim()
            : '',
      );

      // appLog('data  ${account.toJson()}');

      // Get token from UserProvider
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final token = userProvider.token;

      final result = await _repository.createAccount(account, token: token);

      if (result['success']) {
        successMessage.value = result['message'];

        // Extract ACC_CD from response
        final responseData = result['data'] as Map<String, dynamic>?;
        final accCd = responseData?['data']?['ACC_CD'] as String?;

        appLog('[createAccountFromForm] Account created - ACC_CD: $accCd',
            tag: 'AccountController');

        // If image is selected, upload it after a delay
        if (selectedImage.value != null && accCd != null && accCd.isNotEmpty) {
          appLog(
              '[createAccountFromForm] Image selected, waiting 2 seconds before upload',
              tag: 'AccountController');

          // Wait for 2 seconds
          await Future.delayed(const Duration(seconds: 2));

          appLog('[createAccountFromForm] Uploading account image',
              tag: 'AccountController');

          // Upload the image
          final imageResult = await _repository.uploadAccountImage(
            accCd: accCd,
            imageFile: selectedImage.value!,
            token: token!,
          );

          if (imageResult['success']) {
            appLog('[createAccountFromForm] Image uploaded successfully',
                tag: 'AccountController');
            successMessage.value =
                '${result['message']}\n${imageResult['message']}';
          } else {
            appLog(
                '[createAccountFromForm] Image upload failed: ${imageResult['error']}',
                tag: 'AccountController');
            // Account is created but image upload failed
            // Still show success but with warning
            successMessage.value =
                '${result['message']}\nWarning: ${imageResult['message']}';
          }
        }

        final accName = AccountFormFields.accNameController.text.trim();
        AccountFormFields.clearAll();
        selectedImage.value = null;
        // Pop and pass account name back
        Get.back(result: accName);
      } else {
        errorMessage.value = result['error'];
      }
    } catch (e, stackTrace) {
      errorMessage.value = 'Error: $e';
      appLog(
        'Exception in createAccountFromForm: $e',
        tag: 'AccountController',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      isLoading.value = false;
      appLog('Loading state set to false', tag: 'AccountController');
      appLog('createAccountFromForm completed', tag: 'AccountController');
    }
  }

  void showImageSourcePicker() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Get.back();
                pickImage(source: ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Gallery'),
              onTap: () {
                Get.back();
                pickImage(source: ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}
