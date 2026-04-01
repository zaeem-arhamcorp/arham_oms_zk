import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

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
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
        ),
        _fieldSpacing,
      ],
    );
  }

  // Common spacing
  static const _fieldSpacing = SizedBox(height: 12);

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
        sectionHeader('Basic Information'),
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
        textField(
          controller: AccountFormFields.mobile1Controller,
          label: 'Mobile Number',
          isNumber: true,
          isRequired: true,
          maxLength: 10,
          validator: (v) =>
              FormValidation.validatePhone(v) ??
              FormValidation.validateRequired(v, 'Mobile Number'),
        ),
        textField(
            controller: AccountFormFields.add1Controller,
            label: 'Address',
            maxLength: 255),
        textField(
            controller: AccountFormFields.cityController,
            label: 'City',
            maxLength: 50),
        // textField(
        //   controller: AccountFormFields.stateController,
        //   label: 'State',
        //   maxLength: 50
        // ),
        // textField(
        //   controller: AccountFormFields.pincodeController,
        //   label: 'Pincode',
        //   maxLength: 10
        //   isNumber: true,
        // ),
        const SizedBox(height: 8),
        sectionHeader('Current Location'),
        Obx(() {
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
                              AccountFormFields.latitudeController.text.isEmpty
                                  ? '--'
                                  : AccountFormFields.latitudeController.text,
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
                              AccountFormFields.longitudeController.text.isEmpty
                                  ? '--'
                                  : AccountFormFields.longitudeController.text,
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
