import 'package:flutter/material.dart';

class AccountFormFields {
  //  Basic Info
  static final personNmController = TextEditingController();
  static final accNameController = TextEditingController();
  static final mobile1Controller = TextEditingController();
  static final whatsappNoController = TextEditingController();
  static final emailController = TextEditingController();
  static final userController = TextEditingController();
  static final add1Controller = TextEditingController();
  static final cityController = TextEditingController();
  static final areaController = TextEditingController();
  static final stateController = TextEditingController();
  static final pincodeController = TextEditingController();
  static final latitudeController = TextEditingController();
  static final longitudeController = TextEditingController();
  static final beatCdController = TextEditingController();

  //  License Info
  static final gstNoController = TextEditingController();
  static final drugLic1Controller = TextEditingController();
  static final drugLic2Controller = TextEditingController();
  static final fssaiNoController = TextEditingController();

  static void clearAll() {
    // Basic Info
    accNameController.clear();
    personNmController.clear();
    mobile1Controller.clear();
    whatsappNoController.clear();
    emailController.clear();
    userController.clear();
    add1Controller.clear();
    cityController.clear();
    areaController.clear();
    stateController.clear();
    pincodeController.clear();
    latitudeController.clear();
    longitudeController.clear();
    beatCdController.clear();

    // License Info
    gstNoController.clear();
    drugLic1Controller.clear();
    drugLic2Controller.clear();
    fssaiNoController.clear();
  }
}
