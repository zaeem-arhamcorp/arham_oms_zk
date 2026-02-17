import 'package:flutter/cupertino.dart';

class Global extends ChangeNotifier {
  bool loadingLogin = false;
  bool loadingfetchLogin = false;
  bool loadingSignup = false;

//  String partyName = "Select Party";

  loadinglogin(bool value) {
    loadingLogin = value;
    notifyListeners();
  }

  loadingfetchlogin(bool value) {
    loadingfetchLogin = value;
    notifyListeners();
  }

  loadingsignup(bool value) {
    loadingSignup = value;
    notifyListeners();
  }

  changePartyname(val) {
    //partyName = val;
    notifyListeners();
  }
}
