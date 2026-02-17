import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/disposable_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/cartListModal.dart';
import 'package:http/http.dart' as http;

import '../views/loginpage.dart';

class CartListProvider extends DisposableProvider {
  final List<DatumCartList> _data = [];

  // List<DatumCartList> data2 = [];
  List<DatumCartList> get data => _data;

  Future getCartItem(BuildContext context, String? partyId) async {
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);

    if (partyId == null) {
      _data.clear();
    } else {
      try {
        final http.Response response = await http.get(
          Uri.parse("${AppConfig.baseURL}cart?partyCd=$partyId"),
          headers: {
            "Authorization": "Bearer ${ub.token}",
            'x-app-type': 'oms',
          },
        );
        print("${AppConfig.baseURL}cart?partyCd=$partyId");
        print("Bearer ${ub.token}");
        if (response.statusCode == 200) {
          // data2.clear();
          // data2.addAll(cartListModalFromJson(response.body).data);
          _data.clear();
          _data.addAll(cartListModalFromJson(response.body).data);

          // data2.clear();
        } else {
          ub.userSignout(context).then((value) {
            Get.offAll(() => LoginPage());
          });
        }
      } catch (e) {
        //Fluttertoast.showToast(msg: "Something went wrong");
        AppSnackBar.showGetXCustomSnackBar(message: 'Something went wrong');
      }
    }
  }

  @override
  disposeValues() {
    _data.clear();
    notifyListeners();
  }
}
