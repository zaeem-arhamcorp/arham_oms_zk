import 'package:arham_corporation/providers/children_provider.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../helper/route_label_helper.dart';
import '../../../models/children_model.dart';
import '../../route_schedule_plan/controllers/beat_controller.dart';
import '../controllers/account_controller.dart';
import '../core/form_validation.dart';
import 'account_form_fields.dart';

class FormWidgets {
  // Generic Text Field
  static Widget textField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool isNumber = false,
    bool isRequired = false,
    bool isEnabled = true,
    String? Function(String?)? validator,
    int? maxLength,
    TextCapitalization textCapitalization = TextCapitalization.words,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          maxLength: maxLength,
          enabled: isEnabled,
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          validator: validator,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          decoration: InputDecoration(
            labelText: isRequired ? '$label *' : label,
            hintText: hint,
            counterText: '',
            // border: const OutlineInputBorder(),
            // filled: true,
            // fillColor: Colors.grey.shade50,
          ),
        ),
        _fieldSpacing,
      ],
    );
  }

  // Common spacing
  // static const _fieldSpacing = SizedBox(height: 12);
  static const _fieldSpacing = SizedBox(height: 2);
  // Section Header
  static Widget sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  // Basic Info Section
  static Widget basicInfo(AccountController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // sectionHeader('Basic Information'),
        textField(
          controller: AccountFormFields.accNameController,
          label: 'Account Name',
          isRequired: true,
          maxLength: 100,
          validator: (v) => FormValidation.validateRequired(v, 'Account Name'),
        ),
        textField(
          controller: AccountFormFields.personNmController,
          label: 'Person Name',
          isRequired: true,
          maxLength: 100,
          validator: (v) => FormValidation.validateRequired(v, 'Person Name'),
        ),
        Row(
          children: [
            Expanded(
              child: textField(
                controller: AccountFormFields.mobile1Controller,
                label: 'Mobile Number',
                isNumber: true,
                isRequired: true,
                maxLength: 10,
                validator: (v) =>
                    FormValidation.validatePhone(v) ??
                    FormValidation.validateRequired(v, 'Mobile Number'),
              ),
            ),
            SizedBox(
              width: 8,
            ),
            Expanded(
              child: textField(
                controller: AccountFormFields.whatsappNoController,
                label: 'Whatsapp Number',
                isNumber: true,
                isRequired: true,
                maxLength: 10,
                validator: (v) =>
                    FormValidation.validatePhone(v) ??
                    FormValidation.validateRequired(v, 'Whatsapp Number'),
              ),
            ),
          ],
        ),
        textField(
            controller: AccountFormFields.emailController,
            label: 'Email',
            isRequired: false,
            validator: (v) => FormValidation.validateEmail(v)
            // ?? FormValidation.validateRequired(v, 'Email'),
            ),

        Builder(
          builder: (context) {
            final childrenProvider = Provider.of<ChildrenProvider>(context);

            if (childrenProvider.isLoading && childrenProvider.users.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text('Loading users...'),
                  ],
                ),
              );
            }

            final items = childrenProvider.users;

            final rawUserCd = AccountFormFields.userController.text;

            final matchedUser = items.cast<Data?>().firstWhere(
                  (u) => u?.userCd == rawUserCd,
                  orElse: () => null,
                );

            final displayText = matchedUser?.userName ?? '';

            return GestureDetector(
              onTap: () async {
                final selected = await showModalBottomSheet<Data>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  builder: (sheetContext) {
                    final searchController = TextEditingController();

                    List<Data> filtered = List.from(items);

                    return StatefulBuilder(
                      builder: (context, setModalState) {
                        return SafeArea(
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height * .75,
                            child: Column(
                              children: [
                                const SizedBox(height: 12),
                                Container(
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.grey,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Select User',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: TextField(
                                    controller: searchController,
                                    decoration: const InputDecoration(
                                      prefixIcon: Icon(Icons.search),
                                      hintText: 'Search user',
                                      border: UnderlineInputBorder(),
                                      enabledBorder:
                                          const UnderlineInputBorder(),
                                      focusedBorder:
                                          const UnderlineInputBorder(),
                                      disabledBorder:
                                          const UnderlineInputBorder(),
                                      errorBorder: const UnderlineInputBorder(),
                                      focusedErrorBorder:
                                          const UnderlineInputBorder(),
                                    ),
                                    onChanged: (value) {
                                      final q = value.trim().toLowerCase();

                                      setModalState(() {
                                        if (q.isEmpty) {
                                          filtered = List.from(items);
                                        } else {
                                          filtered = items.where((u) {
                                            return u.userName
                                                    .toLowerCase()
                                                    .contains(q) ||
                                                u.userCd
                                                    .toLowerCase()
                                                    .contains(q);
                                          }).toList();
                                        }
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: filtered.length,
                                    itemBuilder: (_, index) {
                                      final user = filtered[index];

                                      return ListTile(
                                        title: Text(
                                          user.userName,
                                        ),
                                        subtitle: Text(
                                          user.userCd,
                                        ),
                                        onTap: () {
                                          Navigator.pop(
                                            sheetContext,
                                            user,
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                                if (childrenProvider.isLoadingMore)
                                  const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: CircularProgressIndicator(),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );

                if (selected != null) {
                  AccountFormFields.userController.text = selected.userCd;

                  (context as Element).markNeedsBuild();
                }
              },
              child: AbsorbPointer(
                child: TextFormField(
                  readOnly: true,
                  controller: TextEditingController(
                    text: displayText,
                  ),
                  decoration: InputDecoration(
                    labelText: 'User',
                    border: const UnderlineInputBorder(),
                    // filled: true,
                    // fillColor: Colors.grey.shade50,
                    suffixIcon: const Icon(
                      Icons.arrow_drop_down,
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        SizedBox(
          height: 15,
        ),
        sectionHeader("Address"),
        textField(
            controller: AccountFormFields.add1Controller,
            label: 'Address',
            maxLength: 255),
        Row(
          children: [
            Expanded(
              child: textField(
                  controller: AccountFormFields.areaController,
                  label: 'Area',
                  maxLength: 50),
            ),
            SizedBox(
              width: 8,
            ),
            Expanded(
              child: textField(
                  controller: AccountFormFields.cityController,
                  label: 'City',
                  maxLength: 50),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: textField(
                  controller: AccountFormFields.stateController,
                  label: 'State',
                  maxLength: 50),
            ),
            SizedBox(
              width: 8,
            ),
            Expanded(
              child: textField(
                controller: AccountFormFields.pincodeController,
                label: 'Pincode',
                maxLength: 10,
                isNumber: true,
              ),
            ),
          ],
        ),

        // Beat dropdown (loaded from API) - autofills with existing account beat
        Builder(builder: (context) {
          final profileProvider = Provider.of<ProfileProvider>(context);
          final hasBeatAccess = profileProvider.data != null &&
              profileProvider.data!.modulesList!.any((module) =>
                  module.mODULENO == "233" && module.rEADRIGHT == true);

          if (!hasBeatAccess) {
            return const SizedBox.shrink();
          }

          // Lazily register BeatController when form is used in a widget tree
          final beatCtrl = Get.isRegistered<BeatController>()
              ? Get.find<BeatController>()
              : Get.put(BeatController());

          return Obx(() {
            if (beatCtrl.isLoading) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: const [
                    SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 12),
                    Text('Loading beats...'),
                  ],
                ),
              );
            }

            final items = beatCtrl.beats;
            final rawBeatValue = AccountFormFields.beatCdController.text;
            final normalizedRaw = rawBeatValue.trim().toLowerCase();

            // Resolve prefill safely even when payload has whitespace/case differences
            // or sends beat name instead of beat code.
            final matchedBeat = items.cast<dynamic>().firstWhere(
                  (b) =>
                      b.beatCd.toString().trim().toLowerCase() ==
                          normalizedRaw ||
                      b.beatName.toString().trim().toLowerCase() ==
                          normalizedRaw,
                  orElse: () => null,
                );
            final selectedValue = matchedBeat?.beatCd as String?;

            if (matchedBeat != null &&
                AccountFormFields.beatCdController.text != selectedValue) {
              AccountFormFields.beatCdController.text = selectedValue ?? '';
            }

            // Searchable beat picker: tapping opens a dialog with search.
            final displayText = matchedBeat?.beatName.isNotEmpty == true
                ? matchedBeat!.beatName
                : (matchedBeat?.beatCd ?? '');

            final profile = context.watch<ProfileProvider>();
            final singularRouteLabel = RouteLabelHelper.singularMaster(profile);
            final pluralRouteLabel = RouteLabelHelper.singularMaster(profile);

            return GestureDetector(
              onTap: () async {
                if (beatCtrl.beats.isEmpty) {
                  await beatCtrl.fetchBeats();
                }
                if (!context.mounted) return;
                final selected = await showDialog<dynamic>(
                  context: context,
                  builder: (dialogCtx) {
                    final searchCtrl = TextEditingController();
                    var filtered = List.from(beatCtrl.beats);

                    return StatefulBuilder(builder: (c, setState) {
                      return AlertDialog(
                        title: Text('Select $singularRouteLabel'),
                        backgroundColor: Colors.white,
                        content: SizedBox(
                          width: double.maxFinite,
                          height: 320,
                          child: Column(
                            children: [
                              TextField(
                                controller: searchCtrl,
                                decoration: InputDecoration(
                                  prefixIcon: Icon(Icons.search),
                                  hintText: 'Search $pluralRouteLabel',
                                ),
                                onChanged: (s) {
                                  final q = s.trim().toLowerCase();
                                  setState(() {
                                    if (q.isEmpty) {
                                      filtered = List.from(beatCtrl.beats);
                                    } else {
                                      filtered = beatCtrl.beats
                                          .where((b) =>
                                              b.beatName
                                                  .toString()
                                                  .toLowerCase()
                                                  .contains(q) ||
                                              b.beatCd
                                                  .toString()
                                                  .toLowerCase()
                                                  .contains(q))
                                          .toList();
                                    }
                                  });
                                },
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: filtered.isEmpty
                                    ? Center(
                                        child:
                                            Text('No $pluralRouteLabel found'))
                                    : ListView.builder(
                                        itemCount: filtered.length,
                                        itemBuilder: (_, i) {
                                          final b = filtered[i];
                                          return ListTile(
                                            title: Text(b.beatName.isNotEmpty
                                                ? b.beatName
                                                : b.beatCd),
                                            subtitle: Text(b.beatCd),
                                            onTap: () => Navigator.of(c)
                                                .pop<dynamic>(filtered[i]),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: Text('Cancel'),
                          )
                        ],
                      );
                    });
                  },
                );

                if (selected != null) {
                  AccountFormFields.beatCdController.text = selected.beatCd;
                  try {
                    (context as Element).markNeedsBuild();
                  } catch (_) {}
                }
              },
              child: AbsorbPointer(
                child: TextFormField(
                  readOnly: true,
                  controller: TextEditingController(text: displayText),
                  decoration: InputDecoration(
                    labelText: singularRouteLabel,
                    border: const UnderlineInputBorder(),
                    // filled: true,
                    // fillColor: Colors.grey.shade50,
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                  ),
                ),
              ),
            );
          });
        }),
        const SizedBox(height: 8),
        _locationSection(controller),
      ],
    );
  }

  static Widget _locationSection(AccountController controller) {
    if (controller.locationLocked) {
      return Obx(() {
        final latText = controller.latitudeRx.value.isNotEmpty
            ? controller.latitudeRx.value
            : AccountFormFields.latitudeController.text;
        final longText = controller.longitudeRx.value.isNotEmpty
            ? controller.longitudeRx.value
            : AccountFormFields.longitudeController.text;
        final selected = controller.selectedLatLng.value;
        final target = selected ?? controller.defaultMapCenter;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionHeader('Current Location'),
            Card(
              color: Colors.blue.shade50,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.my_location,
                            size: 18, color: Colors.blue),
                        const SizedBox(width: 6),
                        Text(
                          'Latitude: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade900,
                          ),
                        ),
                        Text(
                          latText.isEmpty ? '--' : latText,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 18, color: Colors.redAccent),
                        const SizedBox(width: 6),
                        Text(
                          'Longitude: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade900,
                          ),
                        ),
                        Text(
                          longText.isEmpty ? '--' : longText,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Location is locked for this account.',
                      style: TextStyle(
                        color: Colors.blueGrey.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: IgnorePointer(
                child: SizedBox(
                  height: 220,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: target,
                      zoom: selected != null ? 16 : 14,
                    ),
                    onMapCreated: controller.onMapCreated,
                    markers: {
                      Marker(
                        markerId: const MarkerId('account_location_pin'),
                        position: target,
                        draggable: false,
                      ),
                    },
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    scrollGesturesEnabled: false,
                    zoomGesturesEnabled: false,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                  ),
                ),
              ),
            ),
          ],
        );
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('Current Location'),
        Obx(() {
          final latText = controller.latitudeRx.value.isNotEmpty
              ? controller.latitudeRx.value
              : AccountFormFields.latitudeController.text;
          final longText = controller.longitudeRx.value.isNotEmpty
              ? controller.longitudeRx.value
              : AccountFormFields.longitudeController.text;

          return Card(
            color: Colors.blue.shade50,
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: controller.isLocationLoading.value
                  ? Row(
                      children: [
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Fetching location...',
                          style:
                              TextStyle(fontSize: 15, color: Colors.blueGrey),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.my_location,
                                size: 18, color: Colors.blue),
                            const SizedBox(width: 6),
                            Text(
                              'Latitude: ',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade900),
                            ),
                            Text(
                              latText.isEmpty ? '--' : latText,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 18, color: Colors.redAccent),
                            const SizedBox(width: 6),
                            Text(
                              'Longitude: ',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade900),
                            ),
                            Text(
                              longText.isEmpty ? '--' : longText,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          );
        }),
        const SizedBox(height: 8),
        Obx(() {
          final busy = controller.isLocationLoading.value;
          final isCurrentMode =
              controller.locationMode.value == AccountLocationMode.current;

          return Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      busy ? null : () => controller.onCurrentButtonPressed(),
                  icon: const Icon(Icons.my_location),
                  label: const Text('Current'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCurrentMode
                        ? Colors.blue
                        : Colors.blue.withOpacity(0.15),
                    foregroundColor:
                        isCurrentMode ? Colors.white : Colors.blue.shade900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      busy ? null : () => controller.onAddressButtonPressed(),
                  icon: const Icon(Icons.search),
                  label: const Text('Address'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !isCurrentMode
                        ? Colors.blue
                        : Colors.blue.withOpacity(0.15),
                    foregroundColor:
                        !isCurrentMode ? Colors.white : Colors.blue.shade900,
                  ),
                ),
              ),
            ],
          );
        }),
        const SizedBox(height: 10),
        Obx(() {
          if (!controller.showAddressSearch.value) {
            return const SizedBox.shrink();
          }

          final suggestions = controller.placeSuggestions;
          final query = controller.placeSearchQuery.value.trim();
          final showNoResults = !controller.isPlaceSearchLoading.value &&
              query.length >= 2 &&
              suggestions.isEmpty;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller.placeSearchController,
                onChanged: controller.onPlaceSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Search Place',
                  hintText: 'Type area, city, landmark...',
                  prefixIcon: const Icon(Icons.place_outlined),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: controller.clearPlaceSearch,
                        ),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              if (controller.isPlaceSearchLoading.value)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              if (suggestions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 240),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: suggestions.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: Colors.grey.shade200,
                        ),
                        itemBuilder: (context, index) {
                          final item = suggestions[index];
                          return ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.location_on_outlined,
                              color: Colors.blue,
                            ),
                            title: Text(
                              item.mainText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: item.secondaryText.isEmpty
                                ? null
                                : Text(
                                    item.secondaryText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            onTap: () async {
                              FocusScope.of(context).unfocus();
                              await controller.onPlaceSuggestionSelected(item);
                            },
                          );
                        },
                      ),
                    ),
                  ),
                )
              else if (showNoResults)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'No places found',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
            ],
          );
        }),
        Obx(() {
          final selected = controller.selectedLatLng.value;
          final target = selected ?? controller.defaultMapCenter;
          final markers = <Marker>{
            Marker(
              markerId: const MarkerId('account_location_pin'),
              position: target,
              draggable: true,
              onDrag: controller.onMarkerDrag,
              onDragEnd: (position) {
                controller.onMarkerDragEnd(position);
              },
            ),
          };

          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 220,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: target,
                  zoom: selected != null ? 16 : 14,
                ),
                onMapCreated: controller.onMapCreated,
                onTap: controller.onMapTap,
                markers: markers,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                scrollGesturesEnabled: true,
                zoomGesturesEnabled: true,
                rotateGesturesEnabled: true,
                tiltGesturesEnabled: true,
                gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                  Factory<OneSequenceGestureRecognizer>(
                      () => EagerGestureRecognizer()),
                },
              ),
            ),
          );
        }),
      ],
    );
  }

  // License Section
  static Widget licenseInfo(AccountController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('License & Tax Information'),
        textField(
          controller: AccountFormFields.gstNoController,
          label: 'GST Number',
          maxLength: 15,
          textCapitalization: TextCapitalization.characters,
        ),
        textField(
          controller: AccountFormFields.drugLic1Controller,
          label: 'Drug License 1',
          maxLength: 50,
          textCapitalization: TextCapitalization.characters,
        ),
        textField(
          controller: AccountFormFields.drugLic2Controller,
          label: 'Drug License 2',
          maxLength: 50,
          textCapitalization: TextCapitalization.characters,
        ),
        textField(
          controller: AccountFormFields.fssaiNoController,
          isNumber: true,
          maxLength: 50,
          label: 'FSSAI Number',
          textCapitalization: TextCapitalization.characters,
        ),
      ],
    );
  }

  // Image Upload Section
  static Widget imageUpload(AccountController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionHeader('Upload Image'),
        Obx(() {
          final image = controller.selectedImage.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //  Image Preview
              if (image != null)
                Container(
                  height: 130,
                  width: 130,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      image,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

              //  Buttons Row
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: controller.showImageSourcePicker,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.upload),
                    label: Text(
                      image == null ? 'Upload Image' : 'Change',
                    ),
                  ),

                  const SizedBox(width: 10),

                  // 🔹 Remove Button
                  if (image != null)
                    OutlinedButton.icon(
                      onPressed: controller.removeImage,
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('Remove'),
                    ),
                ],
              ),

              const SizedBox(height: 12),
            ],
          );
        }),
      ],
    );
  }
}
