import 'package:flutter/cupertino.dart';

class BillProvider extends ChangeNotifier{
  TextEditingController searchItemCltt = TextEditingController();
  List selectedIndex = [];
  void addRemoveItem(val){
    if(selectedIndex.contains(val)){
      selectedIndex.remove(val);
    }else{
      selectedIndex.add(val);
    }
    notifyListeners();
  }

  void clearList(){
    selectedIndex.clear();
    notifyListeners();
  }
}