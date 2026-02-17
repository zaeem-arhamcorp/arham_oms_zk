import 'dart:async';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/location_provider.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
//import 'package:fluttertoast/fluttertoast.dart';
import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/helper/helper.dart';
import 'package:arham_corporation/models/narrationModal.dart';
import 'package:arham_corporation/providers/cart_list_provider.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/services/services.dart';
import 'package:arham_corporation/views/productDetailPage.dart';
import 'package:arham_corporation/views/shoppingCartPage.dart';
import 'package:arham_corporation/widgets/pdfViewerScreen.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../models/cartListModal.dart';
import '../models/productModal.dart';
import '../providers/party_provider.dart';
import '../services/preventSearch.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({Key? key}) : super(key: key);

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  // PartynameModal? party;
  // bool nolistParty = false;

  String? deptCd;

  List<DeptmentModal> deptData = [];
  List<DeptmentModal> maindeptData = [];
  List<DatumNarration> otherDescOptions = [];
  List<DatumNarration> fld5DescOptions = [];

  TextEditingController searchClt = TextEditingController();

  bool showSearch = true;
  bool showDeptSearch = false;

  List<DatumProduct> dataProduct = [];

  List<TextEditingController> qty = [];
  List<TextEditingController> rate = [];
  List<TextEditingController> freeQty = [];
  List<TextEditingController> remarks = [];
  bool isLoading = true;
  int _page = 1;
  bool _hasNextPage = false;
  bool _isLoadMoreRunning = false;

  bool isDownloadingExportPdf = false;
  bool isDownloadingPartyExportPdf = false;

  List<String> isCardItemLoading = [];

  handleCartCheck(value) {
    if (value != null) {
      setState(() {
        final ProfileProvider profile =
            Provider.of<ProfileProvider>(context, listen: false);

        qty.clear();
        freeQty.clear();
        if (profile.data?.profileSettings
                    .firstWhere((element) =>
                        element.variable == 'editMasterRateSettings')
                    .value ==
                'Y' ||
            profile.data?.profileSettings
                    .firstWhere((element) =>
                        element.variable == 'editOperatorRateSettings')
                    .value ==
                'Y') {
          rate.clear();
        }
        if (profile.data?.profileSettings
                .firstWhere(
                    (element) => element.variable == 'showItemWiseRemarks')
                .value ==
            'Y') {
          remarks.clear();
        }

        if (value.payload.pagination.lastPage ==
            value.payload.pagination.page) {
          _hasNextPage = false;
        } else {
          _hasNextPage = true;
        }

        dataProduct.addAll(value.data);

        dataProduct.forEach((element) {
          qty.add(TextEditingController(text: ""));
          freeQty.add(TextEditingController(text: ""));
          if (profile.data?.profileSettings
                      .firstWhere((element) =>
                          element.variable == 'editMasterRateSettings')
                      .value ==
                  'Y' ||
              profile.data?.profileSettings
                      .firstWhere((element) =>
                          element.variable == 'editOperatorRateSettings')
                      .value ==
                  'Y') {
            rate.add(TextEditingController(
                text: element.srate1.toString() == '0.0'
                    ? ""
                    : element.srate1.toString()));
          }
          if (profile.data?.profileSettings
                  .firstWhere(
                      (element) => element.variable == 'showItemWiseRemarks')
                  .value ==
              'Y') {
            remarks.add(TextEditingController(text: ""));
          }
        });
        setState(() {
          isLoading = false;
          _isLoadMoreRunning = false;
        });
      });
    } else {
      setState(() {
        isLoading = false;
        _isLoadMoreRunning = false;
      });
    }

    if (timer != null && timer!.isActive) {
      timer!.cancel();
    }
  }

  getProduct({tocken}) {
    Services()
        .getProduct(_page.toString(), null,
            deptCd == "All Item" ? null : deptCd, context, tocken)
        .then((value) {
      // print(value!.data);
      final CartListProvider cart =
          Provider.of<CartListProvider>(context, listen: false);
      final PartyProvider party =
          Provider.of<PartyProvider>(context, listen: false);
      final ProfileProvider profile =
          Provider.of<ProfileProvider>(context, listen: false);
      if (profile.data?.profileSettings
                  .firstWhere((element) => element.variable == 'punchInOut')
                  .value ==
              'N' &&
          party.party != "") {
        cart.getCartItem(context, party.partyid).then((cart_value) {
          handleCartCheck(value);
        });
      } else if (profile.data?.profileSettings
                  .firstWhere((element) => element.variable == 'punchInOut')
                  .value ==
              'Y' &&
          party.punchInOutParty != "") {
        cart.getCartItem(context, party.punchInOutPartyId).then((cart_value) {
          handleCartCheck(value);
        });
      } else {
        cart.getCartItem(context, null).then((cart_value) {
          handleCartCheck(value);
        });
      }
    });
  }

  getDeptment() {
    Services().getDeptment(context).then((value) {
      setState(() {
        deptData.add(DeptmentModal(
            DEPT_CD: "All Item",
            DEPT_NAME: "All Item",
            SYNC_ID: value!.length != 0 ? value[0].SYNC_ID : ""));
        value.forEach((e) => deptData.add(DeptmentModal(
            DEPT_CD: e.DEPT_CD, DEPT_NAME: e.DEPT_NAME, SYNC_ID: e.SYNC_ID)));
        maindeptData.addAll(deptData);
      });
    });
  }

  filterDeptmentData(String userSearchTerm) {
    List<DeptmentModal> _searchList = [];

    for (int i = 0; i < maindeptData.length; i++) {
      String deptName = maindeptData[i].DEPT_NAME;
      if (deptName.toLowerCase().contains(userSearchTerm.toLowerCase())) {
        _searchList.add(maindeptData[i]);
      }
    }
    return _searchList;
  }

  getOptions() {
    Services().getNarration(context, "OTHER_DESC").then((value) {
      setState(() {
        value!.forEach((e) => otherDescOptions.add(DatumNarration(
            NARR_NAME: e.NARR_NAME,
            NARR_TYPE: e.NARR_TYPE,
            SYNC_ID: e.SYNC_ID)));
      });
    });
    Services().getNarration(context, "FLD5").then((value) {
      setState(() {
        value!.forEach((e) => fld5DescOptions.add(DatumNarration(
            NARR_NAME: e.NARR_NAME,
            NARR_TYPE: e.NARR_TYPE,
            SYNC_ID: e.SYNC_ID)));
      });
    });
  }

  getProductBySearch({search, tocken}) {
    final ProfileProvider profile =
        Provider.of<ProfileProvider>(context, listen: false);
    Services()
        .getProduct(_page.toString(), search, deptCd, context, tocken)
        .then((value) {
      final CartListProvider cart =
          Provider.of<CartListProvider>(context, listen: false);
      final PartyProvider party =
          Provider.of<PartyProvider>(context, listen: false);
      if (profile.data?.profileSettings
                  .firstWhere((element) => element.variable == 'punchInOut')
                  .value ==
              'N' &&
          party.party != "") {
        cart.getCartItem(context, party.partyid).then((cart_value) {
          handleCartCheck(value);
        });
      } else if (profile.data?.profileSettings
                  .firstWhere((element) => element.variable == 'punchInOut')
                  .value ==
              'Y' &&
          party.punchInOutParty != "") {
        cart.getCartItem(context, party.punchInOutPartyId).then((cart_value) {
          handleCartCheck(value);
        });
      } else {
        cart.getCartItem(context, null).then((cart_value) {
          handleCartCheck(value);
        });
      }
    });
  }

  void _loadMore() async {
    if (_hasNextPage == true && _isLoadMoreRunning == false) {
      setState(() {
        _isLoadMoreRunning = true; // Display a progress indicator at the bottom
      });
      _page += 1; // Increase _page by 1
      try {
        // Services().getProduct(_page.toString(), "", context).then((value) {
        //   final CartProvider cart =
        //       Provider.of<CartProvider>(context, listen: false);
        //   if (value != null) {
        //     setState(() {
        //       dataProduct.addAll(value.data);
        //
        //       dataProduct.forEach((element) {
        //         qty.add(TextEditingController(text: "0"));
        //         freeQty.add(TextEditingController(text: "0"));
        //       });
        //       _isFirstLoadRunning = false;
        //       _isLoadMoreRunning = false;
        //       if (dataProduct.isEmpty) {
        //         _hasNextPage = false;
        //         noProductList = true;
        //       }
        //     });
        //   }
        // });
        if (searchClt.text != "") {
          getProductBySearch(search: searchClt.text);
        } else {
          getProduct();
        }
      } catch (err) {
        if (kDebugMode) {
          print('Something went wrong!');
        }
      }
    }
  }

  additemtoCart(itemCd, qty, freeQty, rate, remarks) {
    final CartListProvider cart = Provider.of<CartListProvider>(context, listen: false);
    final PartyProvider party =
        Provider.of<PartyProvider>(context, listen: false);
    final ProfileProvider profile =
        Provider.of<ProfileProvider>(context, listen: false);
    if (profile.data?.profileSettings
                .firstWhere((element) => element.variable == 'punchInOut')
                .value ==
            'N' &&
        party.party == "") {
      FocusManager.instance.primaryFocus?.unfocus();
      //Fluttertoast.showToast(msg: "Please select party first");
      // showAnimatedToast(
      //     message: "Please select party first", color: Colors.red);
      AppSnackBar.showGetXCustomSnackBar(message:   "Please select party first");
    } else if (profile.data?.profileSettings
                .firstWhere((element) => element.variable == 'punchInOut')
                .value ==
            'Y' &&
        party.punchInOutParty == "") {
      FocusManager.instance.primaryFocus?.unfocus();
      // Fluttertoast.showToast(msg: "Please select party first");
      // showAnimatedToast(
      //     message: "Please select party first", color: Colors.red);
      AppSnackBar.showGetXCustomSnackBar(message:   "Please select party first");
    } else {
      setState(() {
        isCardItemLoading.add(itemCd);
      });
      Services()
          .addItemtoCart(
              profile.YN == "Y" ? party.punchInOutPartyId : party.partyid,
              itemCd,
              qty.toString(),
              freeQty.toString(),
              context,
              rate,
              remarks)
          .then((value) {
        if (value != null && value['statusCode'] == 200) {
          cart.data.add(DatumCartList(itemCd: itemCd));
          cart.getCartItem(context,
              profile.YN == "Y" ? party.punchInOutPartyId : party.partyid);
        }
        isCardItemLoading =
            isCardItemLoading.where((element) => element != itemCd).toList();
        setState(() {});
        //showAnimatedToast(message: value['message'], color: Colors.green);
        AppSnackBar.showGetXCustomSnackBar(message:   value['message'],backgroundColor: Colors.green);

        //Fluttertoast.showToast(msg: value['message']);
      });
    }
  }

  // void filterSearchResults(String query) {
  //   List<DatumProduct> dummySearchList = [];
  //   dummySearchList.clear();
  //   dummySearchList.addAll(dataProduct1);
  //   if (query.isNotEmpty) {
  //     List<DatumProduct> dummyListData = [];
  //     dummyListData.clear();
  //     for (var item in dummySearchList) {
  //       if (item.itemName.toLowerCase().contains(query.toLowerCase())) {
  //         print("/////////////////////////////////////");
  //         dummyListData.add(item);
  //         setState(() {
  //           dataProduct.clear();
  //           dataProduct.addAll(dummyListData);
  //         });
  //       }
  //     }
  //
  //     return;
  //   } else {
  //     setState(() {
  //       dataProduct.clear();
  //       dataProduct.addAll(dataProduct1);
  //     });
  //   }
  // }

  TextEditingController searchPartyClt = TextEditingController();
  List _tempParty = [];

  showMenu() {
    final PartyProvider pp = Provider.of<PartyProvider>(context, listen: false);
    final ProfileProvider p =
        Provider.of<ProfileProvider>(context, listen: false);
    pp.getPartyNameProductPage(context);
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        enableDrag: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(25.0),
          ),
        ),
        builder: (BuildContext context) {
          return SafeArea(
            top: false,
            child: Consumer<PartyProvider>(
              builder: (context, party, child) {
                return StatefulBuilder(builder: (context, StateSetter setStatee) {
                  return Padding(
                    padding: MediaQuery.of(context).viewInsets,
                    child: Container(
                      height: 450,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 20.0, bottom: 5.0, top: 20.0),
                                child: Text("Select Party:",
                                    style: TextStyle(
                                        fontSize: 20.0,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: CupertinoSearchTextField(
                                    controller: searchPartyClt,
                                    onChanged: (value) {
                                      //4
                                      setStatee(() {
                                        _tempParty =
                                            Helper.buildSearchList(value, party);
                                      });
                                    }),
                              ),
                            ],
                          ),
                          Expanded(
                            child: party.nolistParty == true
                                ? Center(
                                    child: Text("No List"),
                                  )
                                : party.data.isEmpty
                                    ? Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    : ListView.builder(
                                        itemCount: (_tempParty.length > 0)
                                            ? _tempParty.length
                                            : party.data.length,
                                        itemBuilder: (builder, index) {
                                          return InkWell(
                                            onTap: () async {
                                              if (p.data?.profileSettings
                                                      .firstWhere((element) =>
                                                          element.variable ==
                                                          'punchInOut')
                                                      .value ==
                                                  'Y') {
                                                final LocationProvider lp =
                                                    Provider.of<LocationProvider>(
                                                        context,
                                                        listen: false);
                                                print(
                                                    lp.enebleLocationPermission);
                                                if (lp.enebleLocationPermission ==
                                                    true) {
                                                  await party
                                                      .changePunchInOutParty(
                                                          (_tempParty.length > 0)
                                                              ? _tempParty[index]
                                                                  .accName
                                                              : party.data[index]
                                                                  .accName,
                                                          (_tempParty.length > 0)
                                                              ? _tempParty[index]
                                                                  .accCd
                                                              : party.data[index]
                                                                  .accCd,
                                                          isProductPage: true,
                                                          type: "1",
                                                          context);
                                                } else {
                                                  /*Fluttertoast.showToast(
                                                      msg:
                                                          "Please Enable Location Permission",
                                                      toastLength:
                                                          Toast.LENGTH_LONG);*/
                                                  // showAnimatedToast(
                                                  //     message:
                                                  //         "Please Enable Location Permission",
                                                  //     color: Colors.red);
                                                  AppSnackBar.showGetXCustomSnackBar(message:   "Please Enable Location Permission");
            
                                                }
                                              } else {
                                                await party.changeParty(
                                                    (_tempParty.length > 0)
                                                        ? _tempParty[index]
                                                            .accName
                                                        : party
                                                            .data[index].accName,
                                                    (_tempParty.length > 0)
                                                        ? _tempParty[index].accCd
                                                        : party.data[index].accCd,
                                                    context);
                                              }
            
                                              Get.back();
                                              setState(() {
                                                dataProduct.clear();
                                                isLoading = true;
                                                qty.clear();
                                                freeQty.clear();
                                                _page = 1;
                                                _hasNextPage = false;
                                              });
                                              getProduct();
                                            },
                                            child: (_tempParty.length > 0)
                                                ? Helper
                                                    .showPartyBottomSheetWithSearch(
                                                        index, _tempParty)
                                                : Helper
                                                    .showPartyBottomSheetWithSearch(
                                                        index, party.data),
                                          );
                                        }),
                          )
                        ],
                      ),
                    ),
                  );
                });
              },
            ),
          );
        });
  }

  FocusNode focusNode = FocusNode();

  //late FToast fToast;

  @override
  void initState() {
    // fToast = FToast();
    // fToast.init(context);

    setState(() {
      dataProduct.clear();
      isLoading = true;
      _hasNextPage = false;
      qty.clear();
      rate.clear();
      freeQty.clear();
    });
    getProduct();
    getDeptment();
    getOptions();
    super.initState();

    // Add a listener to the focus node to detect when the field gains focus
    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        // When focus is gained, set selection to the end (so the cursor is at the end of the text)
        //searchClt.selection =
        //    TextSelection.collapsed(offset: searchClt.text.length);

        searchClt.selection =
            TextSelection(baseOffset: 0, extentOffset: searchClt.text.length);
      }
    });
  }

  @override
  void dispose() {
    focusNode.dispose(); // Dispose of the FocusNode when no longer needed
    super.dispose();
  }

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  final _debouncer = Debouncer(milliseconds: 800);

  Timer? timer;

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    final PartyProvider party = context.watch<PartyProvider>();
    final CartListProvider cart = context.watch<CartListProvider>();
    final ProfileProvider profile = context.watch<ProfileProvider>();
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        // resizeToAvoidBottomInset: false,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: showSearch == true || showDeptSearch == true
              ? TextFormField(
                  controller: searchClt,
                  focusNode: focusNode,
                  // Attach the focus node
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                      focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white)),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white)),
                      hintText: showSearch == true
                          ? "Use * for multi Search."
                          : showDeptSearch == true
                              ? "Search Deptment"
                              : "",
                      hintStyle: TextStyle(color: Colors.white)),
                  onChanged: (val) {
                    if (showDeptSearch == true) {
                      if (val == "") {
                        setState(() {
                          deptData.clear();
                          deptData.addAll(maindeptData);
                        });
                      } else {
                        setState(() {
                          deptData.clear();
                          deptData.add(DeptmentModal(
                              DEPT_CD: "All Item",
                              DEPT_NAME: "All Item",
                              SYNC_ID: maindeptData[0].SYNC_ID));
                          deptData.addAll(filterDeptmentData(val));
                        });
                      }
                    } else if (showSearch == true) {
                      if (val.isNotEmpty && val.length.isGreaterThan(3)) {
                      }
                      isLoading = true;
                      _debouncer.run(() {
                        setState(() {
                          dataProduct.clear();

                          qty.clear();
                          rate.clear();
                          freeQty.clear();
                          _page = 1;
                          _hasNextPage = false;
                        });
                        if (val != '') {
                          dataProduct.clear();
                          getProductBySearch(search: val, tocken: null);
                        } else {
                          dataProduct.clear();
                          getProduct();
                        }
                      });
                    }

                    // if (timer != null && timer!.isActive) {
                    //   timer!.cancel();
                    //   timer =
                    //       Timer.periodic(Duration(milliseconds: 500), (Timer t) {
                    //
                    //   });
                    // } else {
                    //   timer =
                    //       Timer.periodic(Duration(milliseconds: 500), (Timer t) {
                    //     if (val != '') {
                    //       dataProduct.clear();
                    //       getProductBySearch(search: val);
                    //     } else {
                    //       dataProduct.clear();
                    //       getProduct();
                    //     }
                    //   });
                    // }
                  },
                )
              : InkWell(
                  onTap: () {
                    print(profile.ACC_CD);
                  },
                  child: Text("Products")),
          actions:
              // profile.data != null &&
              //         profile.data!.moduleNos.contains("205")
              profile.data != null &&
                      profile.data!.modulesList!
                          .any((module) => module.mODULENO == "205")
                  ? [
                      IconButton(
                          padding: EdgeInsets.symmetric(horizontal: 0.0),
                          constraints: BoxConstraints(),
                          tooltip: "Item Search",
                          onPressed: () {
                            setState(() {
                              searchClt.clear();
                              if (showSearch == true) {
                                setState(() {
                                  _page = 1;
                                  qty.clear();
                                  freeQty.clear();
                                  rate.clear();
                                  isLoading = true;
                                  dataProduct.clear();
                                  _hasNextPage = false;
                                });
                                getProduct();
                              }
                              showSearch = !showSearch;
                              showDeptSearch = false;
                            });
                          },
                          icon: Icon(showSearch == false
                              ? Icons.search
                              : Icons.close)),
                      TextButton.icon(
                          onPressed: () {
                            Get.to(() => ShoppingCartPage())!.then((value) {
                              setState(() {
                                isLoading = true;
                                dataProduct.clear();
                                qty.clear();
                                rate.clear();
                                freeQty.clear();
                                _page = 1;
                                _hasNextPage = false;
                              });
                              getProduct();
                              cart.data.clear();
                            });
                          },
                          icon: Icon(Icons.shopping_cart, color: Colors.white),
                          label: Text(
                            "Cart",
                            style: TextStyle(color: Colors.white),
                          )),
                      PopupMenuButton<dynamic>(
                        child: Container(
                          height: 36,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.more_vert,
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 2.0),
                        ),
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<dynamic>>[
                          PopupMenuItem(
                            value: 0,
                            child: isDownloadingExportPdf == true
                                ? Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Export PDF'),
                                      SizedBox(
                                          width: 15.0,
                                          height: 15.0,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.0,
                                          ))
                                    ],
                                  )
                                : Text('Export PDF'),
                            onTap: () {
                              setState(() {
                                isDownloadingExportPdf = true;
                              });
                              Services()
                                  .getProductExportFile(
                                      context, searchClt.text, deptCd)
                                  .then((value) {
                                if (value != null) {
                                  setState(() {
                                    isDownloadingExportPdf = false;
                                  });
                                  Get.to(() =>() =>PdfViewerScreen(
                                      pdfUrl: value,
                                      fileName: DateTime.now().toString()));
                                } else {
                                  setState(() {
                                    isDownloadingExportPdf = false;
                                  });
                                }
                              });
                            },
                          ),
                          PopupMenuItem(
                            value: 1,
                            child: Text('Deptment Search'),
                            onTap: () {
                              setState(() {
                                searchClt.clear();
                                if (showDeptSearch == true) {
                                  setState(() {
                                    deptData.clear();
                                    deptData.addAll(maindeptData);
                                  });
                                }
                                showDeptSearch = !showDeptSearch;
                                showSearch = false;
                              });
                            },
                          ),
                          PopupMenuItem(
                            value: 0,
                            child: isDownloadingPartyExportPdf == true
                                ? Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Export Party PDF'),
                                      SizedBox(
                                          width: 15.0,
                                          height: 15.0,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.0,
                                          ))
                                    ],
                                  )
                                : Text('Export Party PDF'),
                            onTap: () {
                              setState(() {
                                isDownloadingPartyExportPdf = true;
                              });
                              Services()
                                  .getPartyExportFile(context)
                                  .then((value) {
                                if (value != null) {
                                  setState(() {
                                    isDownloadingPartyExportPdf = false;
                                  });
                                  Get.to(() =>PdfViewerScreen(
                                      pdfUrl: value,
                                      fileName: DateTime.now().toString()));
                                } else {
                                  setState(() {
                                    isDownloadingPartyExportPdf = false;
                                  });
                                }
                              });
                            },
                          ),
                        ],
                      )
                    ]
                  : [],
        ),
        body: //profile.data != null && profile.data!.moduleNos.contains("205")
            SafeArea(
              child: profile.data != null &&
                      profile.data!.modulesList!
                          .any((module) => module.mODULENO == "205")
                  ? Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Card(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                  side: BorderSide(color: Colors.grey)),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: TextButton.icon(
                                      onPressed: showMenu,
                                      icon: Icon(
                                        Icons.search,
                                        color: Colors.black,
                                      ),
                                      label: Text(
                                        Provider.of<PartyProvider>(context)
                                                .party
                                                .isEmpty
                                            ? 'Search Party (Name, Phone Number, City, Area)' // Default text when no party is selected
                                            : ' ${Helper.trimValue(profile.YN == 'Y' ? party.punchInOutParty : party.party, 80)} ',
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: TextStyle(color: Colors.black),
                                      ),
                                    ),
                                  ),
              
                                  profile.YN == "Y"
                                      ? profile.ACC_NAME == "" &&
                                              profile.ACC_CD == ""
                                          ? TextButton(
                                              onPressed: profile
                                                          .data?.isPunchIn ==
                                                      true
                                                  ? showMenu
                                                  : () {
                                                      /*Fluttertoast.showToast(
                                                          msg: "Please Punch In");*/
                                                      // showAnimatedToast(
                                                          //     message:
                                                          //         "Please Punch In",
                                                          //     color: Colors.red);
              
                                                          AppSnackBar.showGetXCustomSnackBar(message:   "Please Punch In");
              
                                              },
                                              child: Text("Start Order"))
                                          : TextButton(
                                              onPressed: () async {
                                                await party.startEndOrder(
                                                    profile.ACC_NAME,
                                                    profile.ACC_CD,
                                                    context,
                                                    "3",
                                                    id: 1);
              
                                                setState(() {
                                                  dataProduct.clear();
                                                  isLoading = true;
                                                  qty.clear();
                                                  freeQty.clear();
                                                  _page = 1;
                                                  _hasNextPage = false;
                                                });
                                                getProduct();
                                              },
                                              child: Text("End Order"))
                                      : TextButton(
                                          onPressed: showMenu, child: Text("")),
                                  if (Provider.of<PartyProvider>(context)
                                      .party
                                      .isNotEmpty)
                                    Row(
                                      children: [
                                        GestureDetector(
                                            onTap: () {
                                              party.clearParty();
                                              party.clearPunchInOutParty();
                                            },
                                            child: Icon(
                                              Icons.cancel,
                                              size: 24,
                                            )),
                                      ],
                                    ), //Start Order  End Order
                                ],
                              ),
                            ),
                            Container(
                              height: 40,
                              child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: deptData.length,
                                  shrinkWrap: true,
                                  primary: false,
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 4.h),
                                      child: InkWell(
                                        onTap: () {
                                          if (deptCd == deptData[index].DEPT_CD ||
                                              deptData[index].DEPT_CD ==
                                                  "All Item") {
                                            setState(() {
                                              if (deptData[index].DEPT_CD ==
                                                  "All Item")
                                                deptCd = 'All Item';
                                              else
                                                deptCd = null;
                                              isLoading = true;
                                              dataProduct.clear();
                                              _page = 1;
                                              qty.clear();
                                              rate.clear();
                                              freeQty.clear();
                                              _hasNextPage = false;
                                            });
                                            getProduct();
                                          } else {
                                            setState(() {
                                              deptCd = deptData[index].DEPT_CD;
                                              isLoading = true;
                                              dataProduct.clear();
                                              _page = 1;
                                              qty.clear();
                                              freeQty.clear();
                                              rate.clear();
                                              _hasNextPage = false;
                                            });
                                            getProduct();
                                          }
                                        },
                                        child: Chip(
                                          label: Text(
                                              '${deptData[index].DEPT_NAME}'),
                                          backgroundColor:
                                              deptCd == deptData[index].DEPT_CD
                                                  ? Color(0XFF1C22C3)
                                                  : null,
                                          labelStyle:
                                              deptCd == deptData[index].DEPT_CD
                                                  ? TextStyle(color: Colors.white)
                                                  : null,
                                        ),
                                      ),
                                    );
                                  }),
                            ),
                            Expanded(
                              child: dataProduct.isEmpty == true && !isLoading
                                  ? Center(
                                      child: Text("No Product Available"),
                                    )
                                  : ListView(
                                      keyboardDismissBehavior:
                                          ScrollViewKeyboardDismissBehavior
                                              .onDrag,
                                      children: [
                                        ListView.builder(
                                            padding: EdgeInsets.zero,
                                            itemCount: dataProduct.length,
                                            shrinkWrap: true,
                                            physics:
                                                NeverScrollableScrollPhysics(),
                                            itemBuilder: (context, index) {
                                              var isadd = cart.data.any(
                                                  (element) =>
                                                      element.itemCd ==
                                                      dataProduct[index].itemCd);
                                              return Padding(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                child: GestureDetector(
                                                  onTap: () {
                                                    Get.to(
                                                      () => ProductDetailPage(
                                                        data: dataProduct[index],
                                                      ),
                                                    );
                                                  },
                                                  child: Container(
                                                    padding: EdgeInsets.only(
                                                        top: 10,
                                                        left: 10,
                                                        right: 10,
                                                        bottom: 10),
                                                    width: size.width,
                                                    decoration: BoxDecoration(
                                                        color: (double.parse(dataProduct[index].cStk !=
                                                                            null
                                                                        ? dataProduct[index]
                                                                            .cStk
                                                                            .toString()
                                                                        : "0.0") -
                                                                    double.parse(dataProduct[index]
                                                                                .orStk !=
                                                                            null
                                                                        ? dataProduct[index]
                                                                            .orStk
                                                                            .toString()
                                                                        : "0.0")) >
                                                                0.0
                                                            ? Colors.grey[300]
                                                            : Color(0XFFFF6263)
                                                                .withOpacity(0.2),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                10)),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          "${dataProduct[index].itemName}",
                                                          style: TextStyle(
                                                              fontSize: 13.sp,
                                                              color: Colors.black,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold),
                                                        ),
                                                        SizedBox(
                                                          height: 5.h,
                                                        ),
                                                        Wrap(
                                                          runSpacing: 3.0,
                                                          spacing: 9.0,
                                                          children: [
                                                            if (dataProduct[index]
                                                                    .srate3 !=
                                                                null)
                                                              Wrap(
                                                                children: [
                                                                  Text(
                                                                    "MRP: ",
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            13.sp,
                                                                        color: Colors
                                                                            .black,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold),
                                                                  ),
                                                                  SizedBox(
                                                                    width: 1.w,
                                                                  ),
                                                                  Text(
                                                                    "${dataProduct[index].srate3}",
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            13.sp,
                                                                        color: Colors
                                                                            .green,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold),
                                                                  ),
                                                                ],
                                                              ),
                                                            if (dataProduct[index]
                                                                    .srate1 !=
                                                                null)
                                                              Wrap(
                                                                children: [
                                                                  Text(
                                                                    "Rate: ",
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            13.sp,
                                                                        color: Colors
                                                                            .black,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold),
                                                                  ),
                                                                  SizedBox(
                                                                    width: 1.w,
                                                                  ),
                                                                  Text(
                                                                    "${dataProduct[index].srate1}",
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            13.sp,
                                                                        color: Colors
                                                                            .green,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold),
                                                                  ),
                                                                ],
                                                              ),
                                                            if (dataProduct[index]
                                                                    .cStk !=
                                                                null)
                                                              Wrap(
                                                                children: [
                                                                  Text(
                                                                    "Closing Stock: ",
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            13.sp,
                                                                        color: Colors
                                                                            .black,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold),
                                                                  ),
                                                                  SizedBox(
                                                                    width: 1.w,
                                                                  ),
                                                                  Text(
                                                                    "${dataProduct[index].cStk}",
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            13.sp,
                                                                        color: Colors
                                                                            .green,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold),
                                                                  ),
                                                                ],
                                                              ),
                                                            if (dataProduct[index]
                                                                    .nrate !=
                                                                null)
                                                              Wrap(
                                                                children: [
                                                                  Text(
                                                                    "Net RATE: ",
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            13.sp,
                                                                        color: Colors
                                                                            .black,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold),
                                                                  ),
                                                                  SizedBox(
                                                                    width: 1.w,
                                                                  ),
                                                                  Text(
                                                                    "${dataProduct[index].nrate}",
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            13.sp,
                                                                        color: Colors
                                                                            .green,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold),
                                                                  ),
                                                                ],
                                                              ),
                                                            if (dataProduct[index]
                                                                    .frmlSrt1 !=
                                                                null)
                                                              Wrap(
                                                                children: [
                                                                  Text(
                                                                    "Margin: ",
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            13.sp,
                                                                        color: Colors
                                                                            .black,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold),
                                                                  ),
                                                                  SizedBox(
                                                                    width: 1.w,
                                                                  ),
                                                                  Text(
                                                                    "${dataProduct[index].frmlSrt1}",
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            13.sp,
                                                                        color: Colors
                                                                            .green,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold),
                                                                  ),
                                                                ],
                                                              ),
                                                            if (dataProduct[index]
                                                                    .sdisc !=
                                                                null)
                                                              Wrap(
                                                                children: [
                                                                  Text(
                                                                    "Disc: ",
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            13.sp,
                                                                        color: Colors
                                                                            .black,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold),
                                                                  ),
                                                                  SizedBox(
                                                                    width: 1.w,
                                                                  ),
                                                                  Text(
                                                                    "${dataProduct[index].sdisc}",
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            13.sp,
                                                                        color: Colors
                                                                            .green,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold),
                                                                  ),
                                                                ],
                                                              ),
                                                            if (dataProduct[index]
                                                                    .sdisc1 !=
                                                                null)
                                                              Wrap(
                                                                children: [
                                                                  Text(
                                                                    "Cd%: ",
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            13.sp,
                                                                        color: Colors
                                                                            .black,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold),
                                                                  ),
                                                                  SizedBox(
                                                                    width: 1.w,
                                                                  ),
                                                                  Text(
                                                                    "${dataProduct[index].sdisc1}",
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            13.sp,
                                                                        color: Colors
                                                                            .green,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold),
                                                                  ),
                                                                ],
                                                              ),
                                                            if (dataProduct[index]
                                                                    .orStk !=
                                                                null)
                                                              Wrap(
                                                                children: [
                                                                  Text(
                                                                    "Pending Order: ",
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            13.sp,
                                                                        color: Colors
                                                                            .red,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold),
                                                                  ),
                                                                  SizedBox(
                                                                    width: 1.w,
                                                                  ),
                                                                  Text(
                                                                    "${dataProduct[index].orStk}",
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            13.sp,
                                                                        color: Colors
                                                                            .green,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold),
                                                                  ),
                                                                ],
                                                              ),
                                                            if (dataProduct[index]
                                                                    .cStk !=
                                                                null)
                                                              Wrap(
                                                                children: [
                                                                  Text(
                                                                    "Avl Stk: ",
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            13.sp,
                                                                        color: Colors
                                                                            .green,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold),
                                                                  ),
                                                                  SizedBox(
                                                                    width: 1.w,
                                                                  ),
                                                                  Text(
                                                                    "${dataProduct[index].avlStk}",
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            13.sp,
                                                                        color: Colors
                                                                            .green,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold),
                                                                  ),
                                                                ],
                                                              ),
                                                            if (dataProduct[index]
                                                                    .exDt !=
                                                                null)
                                                              Wrap(
                                                                children: [
                                                                  Text(
                                                                    "Exp Dt: ",
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            13.sp,
                                                                        color: Colors
                                                                            .black,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold),
                                                                  ),
                                                                  SizedBox(
                                                                    width: 1.w,
                                                                  ),
                                                                  Text(
                                                                    "${dataProduct[index].exDt}",
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            13.sp,
                                                                        color: Colors
                                                                            .green,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold),
                                                                  ),
                                                                ],
                                                              ),
                                                          ],
                                                        ),
                                                        SizedBox(
                                                          height: 3.h,
                                                        ),
                                                        Row(
                                                          children: [
                                                            Text(
                                                              "(${dataProduct[index].deptment?.DEPT_NAME})"
                                                                  " (${dataProduct[index].itemCd}) ${dataProduct[index].itemCd2 != null ? "(${dataProduct[index].itemCd2})" : ""} ",
                                                              style: TextStyle(
                                                                  fontSize: 10.sp,
                                                                  color:
                                                                      Colors.grey,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold),
                                                            ),
                                                            if (dataProduct[index]
                                                                    .itemGrade !=
                                                                null)
                                                              Text(
                                                                "   ${dataProduct[index].itemGrade}",
                                                                style: TextStyle(
                                                                    color: Colors
                                                                        .blue),
                                                              )
                                                          ],
                                                        ),
                                                        isCardItemLoading
                                                                .contains(
                                                                    dataProduct[
                                                                            index]
                                                                        .itemCd)
                                                            ? Row(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .end,
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Padding(
                                                                    padding: EdgeInsets
                                                                        .all(12.0
                                                                            .w),
                                                                    child:
                                                                        SizedBox(
                                                                      height:
                                                                          25.0,
                                                                      width: 25.0,
                                                                      child:
                                                                          CircularProgressIndicator(),
                                                                    ),
                                                                  ),
                                                                ],
                                                              )
                                                            : isadd
                                                                ? Padding(
                                                                    padding: const EdgeInsets
                                                                            .only(
                                                                        top:
                                                                            10.0),
                                                                    child:
                                                                        SizedBox(
                                                                      child: Text(
                                                                          "Item Already In Cart"),
                                                                    ),
                                                                  )
                                                                : Padding(
                                                                    padding: const EdgeInsets
                                                                            .only(
                                                                        top:
                                                                            10.0),
                                                                    child: Column(
                                                                      mainAxisAlignment:
                                                                          MainAxisAlignment
                                                                              .start,
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                        Row(
                                                                          children: [
                                                                            Expanded(
                                                                              child: Container(
                                                                                  child: TextFormField(
                                                                                keyboardType: TextInputType.number,
                                                                                decoration: InputDecoration(
                                                                                  hintText: "Enter Qty",
                                                                                  label: Text("Enter Qty"),
                                                                                  isDense: true,
                                                                                ),
                                                                                controller: qty[index],
                                                                              )),
                                                                            ),
                                                                            SizedBox(
                                                                              width:
                                                                                  10.w,
                                                                            ),
                                                                            Expanded(
                                                                              child:
                                                                                  Padding(
                                                                                padding: EdgeInsets.only(bottom: 4.h),
                                                                                child: DropdownMenu<dynamic>(
                                                                                  width: 90.w,
                                                                                  controller: freeQty[index],
                                                                                  requestFocusOnTap: true,
                                                                                  enableFilter: true,
                                                                                  label: const Text('Free'),
                                                                                  dropdownMenuEntries: otherDescOptions.map((e) => DropdownMenuEntry<dynamic>(value: e.NARR_NAME, label: e.NARR_NAME)).toList(),
                                                                                  inputDecorationTheme: const InputDecorationTheme(
                                                                                    isDense: true,
                                                                                  ),
                                                                                  enableSearch: true,
                                                                                ),
                                                                              ),
                                                                            ),
                                                                            if (profile.data?.profileSettings.firstWhere((element) => element.variable == 'editMasterRateSettings').value == 'Y' ||
                                                                                profile.data?.profileSettings.firstWhere((element) => element.variable == 'editOperatorRateSettings').value == 'Y')
                                                                              SizedBox(
                                                                                width: 40.w,
                                                                              ),
                                                                            if (profile.data?.profileSettings.firstWhere((element) => element.variable == 'editMasterRateSettings').value == 'Y' ||
                                                                                profile.data?.profileSettings.firstWhere((element) => element.variable == 'editOperatorRateSettings').value == 'Y')
                                                                              Expanded(
                                                                                child: Container(
                                                                                    child: TextFormField(
                                                                                  keyboardType: TextInputType.number,
                                                                                  decoration: InputDecoration(
                                                                                    hintText: "Rate",
                                                                                    label: Text("Rate"),
                                                                                    isDense: true,
                                                                                  ),
                                                                                  controller: rate[index],
                                                                                )),
                                                                              ),
                                                                            isadd
                                                                                ? Container()
                                                                                : GestureDetector(
                                                                                    onTap: () {
                                                                                      var tempRate;
                                                                                      var tempRemarks;
                                                                                      if (profile.data?.profileSettings.firstWhere((element) => element.variable == 'editMasterRateSettings').value == 'Y' || profile.data?.profileSettings.firstWhere((element) => element.variable == 'editOperatorRateSettings').value == 'Y') {
                                                                                        tempRate = rate[index].text;
                                                                                      }
              
                                                                                      if (profile.data?.profileSettings.firstWhere((element) => element.variable == 'showItemWiseRemarks').value == 'Y') {
                                                                                        tempRemarks = remarks[index].text;
                                                                                      }
              
                                                                                      if (qty[index].text == "0" || qty[index].text.isEmpty) {
                                                                                        additemtoCart(dataProduct[index].itemCd, "1", freeQty[index].text, tempRate, tempRemarks);
                                                                                      } else {
                                                                                        additemtoCart(dataProduct[index].itemCd, qty[index].text, freeQty[index].text, tempRate, tempRemarks);
                                                                                      }
                                                                                    },
                                                                                    child: Container(
                                                                                        decoration: BoxDecoration(color: Color(0xffFFAE37), borderRadius: BorderRadius.circular(8)),
                                                                                        child: Text(
                                                                                          "Add To Cart",
                                                                                          style: TextStyle(color: Colors.white, fontSize: 12),
                                                                                        ),
                                                                                        alignment: Alignment.center,
                                                                                        padding: EdgeInsets.only(left: 18, right: 18, top: 8, bottom: 8)),
                                                                                  ),
                                                                          ],
                                                                        ),
                                                                        if (profile
                                                                                .data
                                                                                ?.profileSettings
                                                                                .firstWhere((element) =>
                                                                                    element.variable ==
                                                                                    'showItemWiseRemarks')
                                                                                .value ==
                                                                            'Y')
                                                                          DropdownMenu<
                                                                              dynamic>(
                                                                            width:
                                                                                size.width - 50,
                                                                            controller:
                                                                                remarks[index],
                                                                            requestFocusOnTap:
                                                                                true,
                                                                            enableFilter:
                                                                                true,
                                                                            label:
                                                                                const Text('Remarks'),
                                                                            dropdownMenuEntries: fld5DescOptions
                                                                                .map((e) => DropdownMenuEntry<dynamic>(value: e.NARR_NAME, label: e.NARR_NAME))
                                                                                .toList(),
                                                                            inputDecorationTheme:
                                                                                const InputDecorationTheme(
                                                                              isDense:
                                                                                  true,
                                                                            ),
                                                                            enableSearch:
                                                                                true,
                                                                          )
                                                                      ],
                                                                    ),
                                                                  ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }),
                                        _hasNextPage == true
                                            ? Padding(
                                                padding: EdgeInsets.only(
                                                    top: 5, bottom: 10),
                                                child: Center(
                                                    child: Padding(
                                                  padding: const EdgeInsets.only(
                                                      left: 20, right: 20),
                                                  child: _isLoadMoreRunning ==
                                                          true
                                                      ? Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(5.0),
                                                          child:
                                                              CircularProgressIndicator(),
                                                        )
                                                      : GestureDetector(
                                                          onTap: () {
                                                            _loadMore();
                                                          },
                                                          child: Container(
                                                            alignment:
                                                                Alignment.center,
                                                            decoration: BoxDecoration(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            5),
                                                                color: AppConfig
                                                                    .mainColor),
                                                            height: 40,
                                                            width: 100,
                                                            child: Text(
                                                              "Load More",
                                                              style: TextStyle(
                                                                  fontSize: 15.sp,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Colors
                                                                      .white),
                                                            ),
                                                          ),
                                                        ),
                                                )),
                                              )
                                            : SizedBox(),
                                        // if (_hasNextPage == false)
                                        //   Container(
                                        //     padding: const EdgeInsets.only(
                                        //         top: 30, bottom: 40),
                                        //     color: Colors.amber,
                                        //     child: const Center(
                                        //       child: Text(
                                        //           'You have fetched all of the Product'),
                                        //     ),
                                        //   ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                        if (party.loading || isLoading)
                          Container(
                            decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.5)),
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          )
                      ],
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Center(
                            child: Text(
                                "You do not have permission to access the Order Entry. Please Upgrade your subscription",
                                textAlign: TextAlign.center),
                          )
                        ],
                      ),
                    ),
            ),
      ),
    );
  }
}
