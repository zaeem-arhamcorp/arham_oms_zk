import 'package:arham_corporation/widgets/custom_app_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:arham_corporation/services/services.dart';

import '../models/settingmodal.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  List<DatumSettings> data = [];
  bool noSetting = false;
  bool loading = false;
  int radiocheck = 0;

  getSettings() {
    setState(() {
      data.clear();
      noSetting = false;
    });
    Services().getSettings(context).then((value) {
      if (value != null) {
        setState(() {
          data.addAll(value.data);
          if (data.isEmpty) {
            noSetting = true;
          }
        });
      } else {
        setState(() {
          noSetting = true;
        });
      }
    });
  }

  updateSetting(sid, val,amt) {
    setState(() {
      loading = true;
    });
    Services().updateSetting(context, sid, val,amt).then((value) {
      setState(() {
        loading = false;
      });
      print("454545454545454");
      getSettings();
    });
  }

  syncSetting() {
    setState(() {
      data.clear();
      noSetting = false;
    });
    Services().syncSetting(context).then((value) {
      getSettings();
    });
  }

  @override
  void initState() {
    getSettings();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: "Settings",
        actions: [
          TextButton.icon(
              onPressed: () {
                syncSetting();
              },
              icon: Icon(Icons.settings_backup_restore, color: Colors.white),
              label: Text(
                "Update Settings",
                style: TextStyle(color: Colors.white),
              )),
        ],
      ),
      body: SafeArea(
        child: Container(
            height: size.height,
            width: size.width,
            child: Stack(
              children: [
                noSetting == true
                    ? Center(
                        child: ElevatedButton(
                          onPressed: () {
                            syncSetting();
                          },
                          child: Text("Sync Setting"),
                        ),
                      )
                    : data.isEmpty
                        ? Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            itemCount: data.length,
                            shrinkWrap: true,
                            padding: EdgeInsets.all(4),
                            itemBuilder: (context, index) {
                              // return Column(
                              //   children: [
                              //     Row(
                              //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              //       crossAxisAlignment: CrossAxisAlignment.center,
                              //       children: [
                              //         Flexible(
                              //             child: Text("${data[index].settingName}")),
                              //         // CupertinoSwitch(
                              //         //     value:
                              //         //         data[index].value == "Y" ? true : false,
                              //         //     onChanged: (val) {
                              //         //       setState(() {
                              //         //         updateSetting(
                              //         //             data[index].sId.toString(),
                              //         //             val.toString());
                              //         //       });
                              //         //     })
                              //
                              //         Transform.scale(
                              //           scale: 0.7,
                              //           child: CupertinoSwitch(
                              //             value: data[index].value == "Y" ? true : false,
                              //             onChanged: (val) {
                              //               setState(() {
                              //                 toggleSetting(
                              //                   variable: data[index].variable,
                              //                   //newValue: val.toString(),
                              //                   newValue: val ? "Y" : "N",   // <-- convert to String
                              //                   settings: data, // full list of settings
                              //                 );
                              //               });
                              //             },
                              //           ),
                              //         ),
                              //       ],
                              //     ),
                              //     Divider(),
                              //   ],
                              // );

                              return Column(
                                children: [
                                  ListTile(
                                    dense: true,
                                    visualDensity: VisualDensity(horizontal: -2.0,vertical: -3.0),
                                    title: Text(data[index].settingName),
                                    trailing: Transform.scale(
                                      scale: 0.7,
                                      child: CupertinoSwitch(
                                        value: data[index].value == "Y",
                                        onChanged: (val) {
                                          setState(() {
                                            toggleSetting(
                                              variable: data[index].variable,
                                              newValue: val ? "Y" : "N",
                                              settings: data,
                                            );
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                  Divider(height: 1),
                                ],
                              );
                            }),
                Visibility(
                  visible: loading,
                  child: Container(
                    alignment: Alignment.center,
                    decoration:
                        BoxDecoration(color: Colors.grey.withOpacity(0.4)),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ],
            )),
      ),
    );
  }

  void toggleSetting({
    required String variable,
    required String newValue,   // <-- "Y" or "N"
    required List<DatumSettings> settings,
  }) {
    print("Variable: $variable | New Value: $newValue");

    // Find both settings
    var itemCodeSetting =
    settings.firstWhere((e) => e.variable == "sortingOnItemCode");

    var itemNameSetting =
    settings.firstWhere((e) => e.variable == "sortingOnItemName");

    // CASE 1 → Turning ON sortingOnItemCode ("Y")
    if (variable == "sortingOnItemCode" && newValue == "Y") {
      if (itemNameSetting.value == "Y") {
        showDialog(
          context:
          context,
          builder:
              (BuildContext
          context) {
            return AlertDialog(
              title:
              Text('Setting Confirmation'),
              content:
              Text('Please turn OFF Sorting On Item Name first.'),
              actions: [
                TextButton(
                  onPressed: () {
                    // Cancel button: Close the dialog
                    Navigator.of(context).pop();
                  },
                  child: Text('Ok'),
                ),
                // TextButton(
                //   onPressed: () {
                //     // Confirm logout
                //     Navigator.of(context).pop();
                //   },
                //   child: Text('Yes'),
                // ),
              ],
            );
          },
        );

        // AppSnackBar.showGetXCustomSnackBar(
        //   message: "Please turn OFF Sorting On Item Name first.",
        // );
        return;
      } else if (itemNameSetting.value == "N") {
        radiocheck = 0;

        showDialog(
          context: context,
          builder: (BuildContext context) {
            return StatefulBuilder(
              builder: (context, setStateDialog) {
                return AlertDialog(
                  title: Text('Order Sorting Base Item Code'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Please select one of the following options to sort the order items.'),

                      Row(
                        children: [
                          Radio(
                            visualDensity: VisualDensity(
                              horizontal: VisualDensity.minimumDensity,
                              vertical: VisualDensity.minimumDensity,
                            ),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            value: 0,
                            groupValue: radiocheck,
                            onChanged: (val) {
                              setStateDialog(() {
                                radiocheck = val!;
                              });
                            },
                          ),
                          Text("A-Z", style: TextStyle(fontSize: 12)),
                        ],
                      ),

                      Row(
                        children: [
                          Radio(
                            visualDensity: VisualDensity(
                              horizontal: VisualDensity.minimumDensity,
                              vertical: VisualDensity.minimumDensity,
                            ),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            value: 1,
                            groupValue: radiocheck,
                            onChanged: (val) {
                              setStateDialog(() {
                                radiocheck = val!;
                              });
                            },
                          ),
                          Text("Z-A", style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();

                        final bool boolValue = newValue == "Y" ? true : false;

                        updateSetting(
                          settings.firstWhere((e) => e.variable == variable).sId.toString(),
                          boolValue.toString(),
                          radiocheck.toString(),
                        );
                      },
                      child: Text('Ok'),
                    ),
                  ],
                );
              },
            );
          },
        );

        return;
      }
    }
    if (variable == "sortingOnItemName" && newValue == "Y") {
      if (itemCodeSetting.value == "Y") {
        showDialog(
          context:
          context,
          builder:
              (BuildContext
          context) {
            return AlertDialog(
              title:
              Text('Setting Confirmation'),
              content:
              Text('Please turn OFF Sorting On Item Code first.'),
              actions: [
                TextButton(
                  onPressed: () {
                    // Cancel button: Close the dialog
                    Navigator.of(context).pop();
                  },
                  child: Text('Ok'),
                ),
                // TextButton(
                //   onPressed: () {
                //     // Confirm logout
                //     Navigator.of(context).pop();
                //   },
                //   child: Text('Yes'),
                // ),
              ],
            );
          },
        );

        // AppSnackBar.showGetXCustomSnackBar(
        //   message: "Please turn OFF Sorting On Item Code first.",
        // );
        return;
      }else if (itemCodeSetting.value == "N") {
        radiocheck = 0;

        showDialog(
          context: context,
          builder: (BuildContext context) {
            return StatefulBuilder(
              builder: (context, setStateDialog) {
                return AlertDialog(
                  title: Text('Order Sorting Base Item Name'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Please select one of the following options to sort the order items.'),

                      Row(
                        children: [
                          Radio(
                            visualDensity: VisualDensity(
                              horizontal: VisualDensity.minimumDensity,
                              vertical: VisualDensity.minimumDensity,
                            ),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            value: 0,
                            groupValue: radiocheck,
                            onChanged: (val) {
                              setStateDialog(() {
                                radiocheck = val!;
                              });
                            },
                          ),
                          Text("A-Z", style: TextStyle(fontSize: 12)),
                        ],
                      ),

                      Row(
                        children: [
                          Radio(
                            visualDensity: VisualDensity(
                              horizontal: VisualDensity.minimumDensity,
                              vertical: VisualDensity.minimumDensity,
                            ),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            value: 1,
                            groupValue: radiocheck,
                            onChanged: (val) {
                              setStateDialog(() {
                                radiocheck = val!;
                              });
                            },
                          ),
                          Text("Z-A", style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();

                        final bool boolValue = newValue == "Y" ? true : false;

                        updateSetting(
                          settings.firstWhere((e) => e.variable == variable).sId.toString(),
                          boolValue.toString(),
                          radiocheck.toString(),
                        );
                      },
                      child: Text('Ok'),
                    ),
                  ],
                );
              },
            );
          },
        );

        return;
      }
    }

    final bool boolValue = newValue == "Y" ? true : false;
    print("Bool Value $boolValue");

    // If allowed → update setting
    updateSetting(
      settings.firstWhere((e) => e.variable == variable).sId.toString(),
      boolValue.toString(),
      //settings.firstWhere((e) => e.variable == variable).valueAmt.toString(),
      radiocheck.toString(),
    );
  }
}
