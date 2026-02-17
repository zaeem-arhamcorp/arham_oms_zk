//import 'package:fluttertoast/fluttertoast.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/disposable_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../constants/constants.dart';
import '../models/orderlistModal.dart';
import 'package:http/http.dart' as http;

import '../views/loginpage.dart';

class OrderFetchProvider extends DisposableProvider {
  List<DatumOrderList> _data = [];
  List<DatumOrderList> get data => _data;
  bool nolist = false;

  final orderfetchHive = Hive.box<DatumOrderList>(Constants.orderFetch);

  Future getOrders(context) async {
    _data.clear();
    nolist = false;
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    //bool result = await InternetConnectionChecker().hasConnection;
    bool result = await InternetConnectionChecker.instance.hasConnection;
    try {
      if (result == true) {
        final http.Response response = await http.get(
          Uri.parse(AppConfig.baseURL + "orders"),
          headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
        );
        print(response.body);
        if (response.statusCode == 200) {
          await orderfetchHive.clear();
          _data.addAll(orderlistModalFromJson(response.body).data);
          await orderfetchHive.addAll(_data);

          if (_data.isEmpty) {
            nolist = true;
          }
        } else {
          ub.userSignout(context).then((value) {
            Get.offAll(() => LoginPage());
          });
        }
      } else {
        _data.addAll(orderfetchHive.values.cast());
      }
    } catch (e) {
      //Fluttertoast.showToast(msg: "Something went wrong");
      AppSnackBar.showGetXCustomSnackBar(message: 'Something went wrong');
      print("Error in orderfetchProvider getOrders data ${e.toString()}");
    }
    notifyListeners();
  }

  @override
  disposeValues() {
    _data.clear();
    notifyListeners();
  }
}
