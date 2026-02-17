import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/party_provider.dart';
import 'package:flutter/cupertino.dart';

//import 'package:fluttertoast/fluttertoast.dart';
import 'package:arham_corporation/providers/disposable_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/profileModal.dart';
import '../views/loginpage.dart';

class ProfileProvider extends DisposableProvider {
  DataProfile? _data;

  DataProfile? get data => _data;

  String YN = "";
  String ACC_NAME = "";
  String ACC_CD = "";

  String? _userCode;

  String? get userCode => _userCode;

  String? _userName;

  String? get userName => _userName;

  Future saveUserCode(userCode) async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    await sp.setString("UserCode", userCode);
    _userCode = userCode;
    notifyListeners();
  }

  Future getUserCode() async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    _userCode = sp.getString("UserCode");
    print("User Code " + _userCode.toString());
    notifyListeners();
  }

  Future saveUserName(userName) async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    await sp.setString("UserName", userName);
    _userName = userName;
    notifyListeners();
  }

  Future getUserName() async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    _userName = sp.getString("UserName");
    print("User Name " + _userName.toString());
    notifyListeners();
  }

  change(accname, accid) {
    print(";;;;;;;;;;;;;;");
    ACC_NAME = accname;
    ACC_CD = accid;
    notifyListeners();
  }

  Future getProfile(BuildContext context, {id}) async {
    YN = "";
    ACC_NAME = "";
    ACC_CD = "";
    if (_data != null) {
      _data = null;
    }
    notifyListeners();
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    final PartyProvider pp = Provider.of<PartyProvider>(context, listen: false);

    //try {
      final http.Response response = await http.get(
        Uri.parse(AppConfig.baseURL + "profile"),
        headers: {
          "Authorization": "Bearer ${ub.token}",
          'x-app-type': 'oms',
        },
      );

      print(AppConfig.baseURL + "profile");
      print("Bearer ${ub.token}");
      print(response.body);

      if (response.statusCode == 200) {
        _data = profileModalFromJson(response.body).data;
        saveUserCode(_data!.userCd.toString());
        saveUserName(_data!.userName.toString());
        print('Profile Data :' + response.body);

        getUserCode();
        getUserName();

        // YN = data?.profileSettings
        //     .firstWhere((element) => element.variable == 'punchInOut')
        //     .value;
        YN = (data?.profileSettings.any(
                (e) => e.variable == 'punchInOut' && e.value == 'Y') ??
            false)
            ? 'Y'
            : 'N';

        ACC_NAME = data!.orderStartParty == null
            ? ""
            : data!.orderStartParty!.accName.toString();
        ACC_CD = data!.orderStartParty == null
            ? ""
            : data!.orderStartParty!.accCd.toString();
        if (id == null) {
          if (YN == "Y") {
            pp.changePunchInOutParty(ACC_NAME, ACC_CD, context, id: 5);
          }
        }
        notifyListeners();
      } else {
        ub.userSignout(context).then((value) {
          print("Profile Page Call Before Logout");
          Get.offAll(() => LoginPage());
          print("Profile Page Call After Logout");
        });
      }
    // } catch (e) {
    //   //Fluttertoast.showToast(msg: "Something went wrong");
    //   AppSnackBar.showGetXCustomSnackBar(message: 'Something went wrong');
    //   print("Error in PerofileProvider getProfile  ${e.toString()}");
    // }
    notifyListeners();
  }

  @override
  disposeValues() {
    _data = null;
    notifyListeners();
  }
}
