import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/views/EditUserScreen.dart';
import 'package:arham_corporation/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:arham_corporation/providers/person_provider.dart';

//import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../models/personModal.dart';
import 'package:pagination_flutter/pagination.dart' as pa;

import '../providers/profile_provider.dart';
import 'adduserScreen.dart';

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  PersonModal? person;
  List<DatumPerson> personData = [];
  bool nolist = false;
  int selectedPage = 1;
  bool loading = false;
  int maxUsers = 0;

  setSelectedPage(int index) {
    setState(() {
      selectedPage = index;
    });
  }

  getPersonList() {
    setState(() {
      personData.clear();
      nolist = false;
      loading = true;
    });
    final PersonProvider p =
        Provider.of<PersonProvider>(context, listen: false);
    p.getPersonList(context, selectedPage).then((_) {
      print('1');

      if (p.person != null) {
        print('4');

        setState(() {
          person = p.person;
          personData.addAll(p.personData);
          loading = false;
          if (personData.isEmpty) {
            print('3');
            nolist = false;
          }
        });
      } else {
        print('4');
        loading = false;
      }
    });
  }

  @override
  void setState(VoidCallback fn) {
    // TODO: implement setState
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  void initState() {
    getPersonList();
    // Call getProfile from ProfileProvider in initState(), but don't directly use context.watch()
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ProfileProvider p =
          Provider.of<ProfileProvider>(context, listen: false);
      p.getProfile().then((value) {
        // Load settings after profile is loaded
        p.loadSettings(context);

        setState(() {
          maxUsers = p.data?.license?.maxUsers ?? 0; // Safely access maxUsers
          print("Max Users : $maxUsers");
        });
      });
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final PersonProvider personProvider = context.watch<PersonProvider>();
    return Scaffold(
      // bottomSheet: person == null
      //     ? null
      //     : Visibility(
      //   visible: personData.length >= 10,
      //   child: Container(
      //     height: 50.h,
      //     width: size.width,
      //     child: SingleChildScrollView( // Wrapping Pagination in SingleChildScrollView
      //       scrollDirection: Axis.horizontal, // Ensure it scrolls horizontally
      //       child: pa.Pagination(
      //         numOfPages: person!.payload.pagination.lastPage,
      //         selectedPage: selectedPage,
      //         pagesVisible: 4,
      //         spacing: 20,
      //         onPageChanged: (page) {
      //           if (loading == true) {
      //           } else {
      //             setState(() {
      //               selectedPage = page;
      //               getPersonList();
      //             });
      //           }
      //         },
      //         nextIcon: const Icon(
      //           Icons.arrow_forward_ios,
      //           color: Color(0XFF1C22C3),
      //           size: 14,
      //         ),
      //         previousIcon: const Icon(
      //           Icons.arrow_back_ios,
      //           color: Color(0XFF1C22C3),
      //           size: 14,
      //         ),
      //         activeTextStyle: const TextStyle(
      //           color: Colors.white,
      //           fontSize: 14,
      //           fontWeight: FontWeight.w700,
      //         ),
      //         activeBtnStyle: ButtonStyle(
      //           backgroundColor:
      //           MaterialStateProperty.all(Color(0XFF1C22C3)),
      //           shape: MaterialStateProperty.all(
      //             RoundedRectangleBorder(
      //               borderRadius: BorderRadius.circular(38),
      //             ),
      //           ),
      //         ),
      //         inactiveBtnStyle: ButtonStyle(
      //           shape: MaterialStateProperty.all(RoundedRectangleBorder(
      //             borderRadius: BorderRadius.circular(38),
      //           )),
      //         ),
      //         inactiveTextStyle: const TextStyle(
      //           fontSize: 14,
      //           color: Color(0XFF1C22C3),
      //           fontWeight: FontWeight.w700,
      //         ),
      //       ),
      //     ),
      //   ),
      // ),
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: "Users",
        actions: [
          // IconButton(onPressed: () {}, icon: Icon(Icons.search)),
          IconButton(
              onPressed: () {
                if (personData.length >= maxUsers) {
                  // Fluttertoast.showToast(
                  //     msg:
                  //         'User limit reached! You cannot add more than $maxUsers users.');
                  AppSnackBar.showGetXCustomSnackBar(
                      message:
                          'User limit reached! You cannot add more than $maxUsers users.');
                } else {
                  Get.to(() => AddUserScreen(
                        screenId: 0,
                      ))?.then((value) {
                    if (value != null && value == 1) {
                      getPersonList();
                    }
                  });
                }
              },
              icon: Icon(Icons.add))
        ],
      ),
      // body : nolist == true
      //     ? Center(
      //   child: CircularProgressIndicator(),
      // )
      //     : person != null && personData.isNotEmpty
      //     ? Stack(
      //   children: [
      //     Padding(
      //       padding: const EdgeInsets.only(bottom: 55, top: 10),
      //       child: ListView.builder(
      //           itemCount: personData.length,
      //           shrinkWrap: true,
      //           itemBuilder: (context, index) {
      //             return Card(
      //               elevation: 5,
      //               child: ExpansionTile(
      //                 childrenPadding: EdgeInsets.all(8),
      //                 title: Text(
      //                   personData[index].userName,
      //                 ),
      //                 subtitle: Text(
      //                   personData[index].userCd,
      //                 ),
      //                 children: [
      //                   Row(
      //                     children: [
      //                       UserOtherDetailContainer(
      //                         title: "User Code",
      //                         data: person!.data[index].userCd,
      //                       ),
      //                       UserOtherDetailContainer(
      //                         title: "User Type",
      //                         data: person!.data[index].userType ==
      //                             "M"
      //                             ? "Master User"
      //                             : "Operator User",
      //                       ),
      //                       UserOtherDetailContainer(
      //                         title: "Password",
      //                         data: person!.data[index].userPwd,
      //                       ),
      //                     ],
      //                   ),
      //                   Row(
      //                     mainAxisAlignment: MainAxisAlignment.end,
      //                     children: [
      //                       IconButton(
      //                           onPressed: () {
      //                             Get.to(() => AddUserScreen(
      //                                 screenId: 1,
      //                                 data:
      //                                 person!.data[index]))
      //                                 ?.then((value) {
      //                               if (value != null &&
      //                                   value == 1) {
      //                                 getPersonList();
      //                               }
      //                             });
      //                           },
      //                           icon: Icon(Icons.edit)),
      //                       IconButton(
      //                         onPressed: () {
      //                           personProvider.changeLoading(true);
      //                           personProvider
      //                               .deletePerson(context,
      //                               person!.data[index].userCd)
      //                               .then((value) {
      //                             personProvider
      //                                 .changeLoading(false);
      //                             if (value == true) {
      //                               getPersonList();
      //                             }
      //                           });
      //                         },
      //                         icon: Icon(Icons.delete),
      //                         color: Colors.red,
      //                       ),
      //                     ],
      //                   ),
      //                 ],
      //               ),
      //             );
      //           }),
      //     ),
      //     Visibility(
      //         visible: personProvider.loading,
      //         child: Container(
      //             decoration: BoxDecoration(
      //                 color: Colors.grey.withOpacity(0.5)),
      //             child: Center(
      //               child: CircularProgressIndicator(
      //                 color: AppConfig.mainColor,
      //               ),
      //             )))
      //   ],
      // )
      //     : Center(
      //   child: CircularProgressIndicator(),
      // ));
      body: SafeArea(
        //bottom: true,
        child: loading
            ? Center(
                child: CircularProgressIndicator(),
              )
            : personData.isEmpty
                ? Center(
                    child:
                        Text('No Record Found', style: TextStyle(fontSize: 18)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(
                      bottom: 55, // ⭐ IMPORTANT: prevents last item cut
                      top: 10,
                    ),
                    itemCount: personData.length,
                    shrinkWrap: true,
                    itemBuilder: (context, index) {
                      return Card(
                        //margin: EdgeInsets.all(8),
                        elevation: 4,
                        color: Colors.white,
                        child: ExpansionTile(
                          shape: Border(),
                          collapsedShape: Border(),
                          childrenPadding: EdgeInsets.all(8),
                          title: Text(personData[index].userName),
                          subtitle: Text(personData[index].userCd),
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                UserOtherDetailContainer(
                                  title: "User Code",
                                  data: personData[index].userCd,
                                ),
                                UserOtherDetailContainer(
                                  title: "User Type",
                                  data: personData[index].userType == "M"
                                      ? "Master User"
                                      : "Operator User",
                                ),
                                // UserOtherDetailContainer(
                                //   title: "Password",
                                //   data: personData[index].userPwd,
                                // ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              //mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  onPressed: () {
                                    // Get.to(() => AddUserScreen(
                                    //         screenId: 1,
                                    //         data: personData[index]))
                                    //     ?.then((value) {
                                    //   if (value != null && value == 1) {
                                    //     getPersonList();
                                    //   }
                                    // });

                                    Get.to(() => EditUserScreen(
                                            screenId: 1,
                                            data: personData[index]))
                                        ?.then((value) {
                                      if (value != null && value == 1) {
                                        getPersonList();
                                      }
                                    });
                                  },
                                  icon: Icon(Icons.edit),
                                ),
                                IconButton(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          title: Text('Delete Confirmation'),
                                          content: Text(
                                              'Are you sure you want to delete user? - ${personData[index].userName}'),
                                          actions: [
                                            TextButton(
                                              onPressed: () {
                                                // Cancel button: Close the dialog
                                                Get.back();
                                              },
                                              child: Text('No'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                // Confirm logout
                                                personProvider
                                                    .changeLoading(true);
                                                personProvider
                                                    .deletePerson(
                                                        context,
                                                        personData[index]
                                                            .userCd,
                                                        personData[index]
                                                            .userName)
                                                    .then((value) {
                                                  personProvider
                                                      .changeLoading(false);
                                                  if (value == true) {
                                                    getPersonList();
                                                  }
                                                });
                                              },
                                              child: Text('Yes'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                  icon: Icon(Icons.delete),
                                  color: Colors.red,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
      bottomNavigationBar: person == null
          ? null
          : SafeArea(
              child: Visibility(
                visible: personData.length >= 10 || selectedPage > 1,
                child: Container(
                  height: 50.h,
                  width: size.width,
                  child: pa.Pagination(
                    numOfPages: person!.payload.pagination.lastPage,
                    selectedPage: selectedPage,
                    pagesVisible: 3,
                    spacing: 20,
                    onPageChanged: (page) {
                      if (loading == true) {
                      } else {
                        setState(() {
                          selectedPage = page;
                          getPersonList();
                        });
                      }
                    },
                    nextIcon: const Icon(
                      Icons.arrow_forward_ios,
                      color: Color(0XFF1C22C3),
                      size: 14,
                    ),
                    previousIcon: const Icon(
                      Icons.arrow_back_ios,
                      color: Color(0XFF1C22C3),
                      size: 14,
                    ),
                    activeTextStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    activeBtnStyle: ButtonStyle(
                      backgroundColor:
                          WidgetStateProperty.all(Color(0XFF1C22C3)),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(38),
                        ),
                      ),
                    ),
                    inactiveBtnStyle: ButtonStyle(
                      shape: WidgetStateProperty.all(RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(38),
                      )),
                    ),
                    inactiveTextStyle: const TextStyle(
                      fontSize: 14,
                      color: Color(0XFF1C22C3),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),

      // bottomNavigationBar: person == null
      //     ? null
      //     : Visibility(
      //   visible: personData.length >= 10 || selectedPage > 1,
      //   child: Container(
      //     height: 50.h,
      //     width: size.width,
      //     child: Row(
      //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
      //       children: [
      //         // Previous Button: Fixed on the left
      //         // GestureDetector(
      //         //   onTap: () {
      //         //     if (selectedPage > 1 && loading == false) {
      //         //       setState(() {
      //         //         selectedPage--;
      //         //         getPersonList();
      //         //       });
      //         //     }
      //         //   },
      //         //   child: const Padding(
      //         //     padding: EdgeInsets.symmetric(horizontal: 10),
      //         //     child: Icon(
      //         //       Icons.arrow_back_ios,
      //         //       color: Color(0XFF1C22C3),
      //         //       size: 14,
      //         //     ),
      //         //   ),
      //         // ),
      //
      //         // Page Numbers: Scrollable horizontally
      //         Expanded(
      //           child: SingleChildScrollView(
      //             scrollDirection: Axis.horizontal,
      //             child: pa.Pagination(
      //               numOfPages: person!.payload.pagination.lastPage,
      //               selectedPage: selectedPage,
      //               pagesVisible: person!.payload.pagination.lastPage,
      //               //pagesVisible: 4,
      //               spacing: 20,
      //               onPageChanged: (page) {
      //                 if (loading == false) {
      //                   setState(() {
      //                     selectedPage = page;
      //                     getPersonList();
      //                   });
      //                 }
      //               },
      //               activeTextStyle: const TextStyle(
      //                 color: Colors.white,
      //                 fontSize: 14,
      //                 fontWeight: FontWeight.w700,
      //               ),
      //               activeBtnStyle: ButtonStyle(
      //                 backgroundColor: MaterialStateProperty.all(Color(0XFF1C22C3)),
      //                 shape: MaterialStateProperty.all(
      //                   RoundedRectangleBorder(
      //                     borderRadius: BorderRadius.circular(38),
      //                   ),
      //                 ),
      //               ),
      //               inactiveBtnStyle: ButtonStyle(
      //                 shape: MaterialStateProperty.all(RoundedRectangleBorder(
      //                   borderRadius: BorderRadius.circular(38),
      //                 )),
      //               ),
      //               inactiveTextStyle: const TextStyle(
      //                 fontSize: 14,
      //                 color: Color(0XFF1C22C3),
      //                 fontWeight: FontWeight.w700,
      //               ),
      //             ),
      //           ),
      //         ),
      //
      //         // Next Button: Fixed on the right
      //         // GestureDetector(
      //         //   onTap: () {
      //         //     if (selectedPage < person!.payload.pagination.lastPage && loading == false) {
      //         //       setState(() {
      //         //         selectedPage++;
      //         //         getPersonList();
      //         //       });
      //         //     }
      //         //   },
      //         //   child: const Padding(
      //         //     padding: EdgeInsets.symmetric(horizontal: 10),
      //         //     child: Icon(
      //         //       Icons.arrow_forward_ios,
      //         //       color: Color(0XFF1C22C3),
      //         //       size: 14,
      //         //     ),
      //         //   ),
      //         // ),
      //       ],
      //     ),
      //   ),
      // ),
    );
  }
}

class UserOtherDetailContainer extends StatelessWidget {
  const UserOtherDetailContainer({
    super.key,
    required this.data,
    required this.title,
  });

  final String data;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("${title}"),
          SizedBox(
            height: 5.h,
          ),
          Text("${data}"),
        ],
      ),
    );
  }
}
