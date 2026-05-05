import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/services/offline_caching_service.dart'
    show OfflineCachingService, CacheItemStatus;
import 'package:arham_corporation/views/About%20me.dart';
import 'package:arham_corporation/views/change_password/change_password_view.dart';
import 'package:arham_corporation/views/monthly_target/screens/secondary_target_view.dart';
import 'package:arham_corporation/views/narration/narration_view.dart';
import 'package:arham_corporation/views/party_managment/screens/account_list_screen.dart';
import 'package:arham_corporation/views/referral/views/referral_view.dart';
import 'package:arham_corporation/views/reimbursement/get_expense_view.dart';
import 'package:arham_corporation/views/route_schedule_plan/views/beat_list_view.dart';
import 'package:arham_corporation/views/settingsScreen.dart';
import 'package:arham_corporation/views/userScreen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../views/company_management/firm_list.dart';
import '../views/loginpage.dart';
import '../views/tasks/assign_task_view.dart';
import '../views/tasks/task_list_view.dart';

class CommonAppDrawer extends StatefulWidget {
  final String? narrationModuleNo;
  final bool? narrationReadRight;
  final bool? narrationWriteRights;
  final bool? narrationUpdateRights;
  final bool? narrationDeleteRight;
  final bool? narrationPrintRights;

  const CommonAppDrawer({
    Key? key,
    this.narrationModuleNo,
    this.narrationReadRight,
    this.narrationWriteRights,
    this.narrationUpdateRights,
    this.narrationDeleteRight,
    this.narrationPrintRights,
  }) : super(key: key);

  @override
  State<CommonAppDrawer> createState() => _CommonAppDrawerState();
}

class _CommonAppDrawerState extends State<CommonAppDrawer> {
  late ProfileProvider _profileProvider;

  @override
  void initState() {
    super.initState();
    _profileProvider = Provider.of<ProfileProvider>(context, listen: false);
  }

  void _showOfflineCachingDialog() {
    bool isCaching = false;
    bool cachingComplete = false;
    List<CacheItemStatus> cacheItems = [];
    String? failureMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.cloud_download, color: Color(0xFF2c9ed9)),
                  SizedBox(width: 8),
                  Text('Go Offline'),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isCaching && !cachingComplete)
                      Text(
                        'Download all masters for offline use?',
                        style: TextStyle(fontSize: 14),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isCaching
                                ? 'Caching data...'
                                : (failureMessage != null
                                    ? 'Caching failed!'
                                    : 'Caching complete!'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: (!isCaching && failureMessage != null)
                                  ? Colors.red
                                  : null,
                            ),
                          ),
                          SizedBox(height: 16),
                          ...cacheItems.map((item) => _buildCacheItemRow(item)),
                          if (failureMessage != null) ...[
                            SizedBox(height: 16),
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                border: Border.all(color: Colors.red.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline,
                                      color: Colors.red, size: 20),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      failureMessage!,
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: 12,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
              actions: [
                if (!isCaching && !cachingComplete)
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text('CANCEL'),
                  ),
                if (!isCaching && !cachingComplete)
                  ElevatedButton(
                    onPressed: () async {
                      // Initialize cache items
                      cacheItems = [
                        CacheItemStatus(name: 'Profile'),
                        CacheItemStatus(name: 'Departments'),
                        CacheItemStatus(name: 'Products'),
                        CacheItemStatus(name: 'Party'),
                        CacheItemStatus(name: 'Cart'),
                      ];
                      failureMessage = null;
                      cachingComplete = false;

                      setDialogState(() {
                        isCaching = true;
                      });

                      try {
                        await OfflineCachingService.cacheAllDataForOffline(
                          context,
                          onProgress: (status) {
                            if (mounted) {
                              setDialogState(() {
                                // Find and update the matching item
                                final index = cacheItems.indexWhere(
                                    (item) => item.name == status.name);
                                if (index != -1) {
                                  cacheItems[index] = status;
                                }

                                // Check for failure
                                if (!status.isSuccess && status.isComplete) {
                                  failureMessage =
                                      '${status.name} failed: ${status.errorMessage}';
                                }
                              });
                            }
                          },
                        );
                        // Caching finished (success or stopped on failure)
                        if (mounted) {
                          setDialogState(() {
                            isCaching = false;
                            cachingComplete = true;
                          });
                        }
                      } catch (e) {
                        print('Error during offline caching: $e');
                        if (mounted) {
                          setDialogState(() {
                            isCaching = false;
                            cachingComplete = true;
                            failureMessage = 'Error: ${e.toString()}';
                          });
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2c9ed9),
                    ),
                    child: Text(
                      'START',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                if (cachingComplete)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      final bool allSuccess =
                          cacheItems.every((item) => item.isSuccess);
                      AppSnackBar.showGetXCustomSnackBar(
                        message: allSuccess
                            ? 'All data cached successfully! You can now work offline.'
                            : failureMessage ??
                                'Caching failed. Please check your internet connection and try again.',
                        backgroundColor: allSuccess ? Colors.green : Colors.red,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2c9ed9),
                    ),
                    child: Text(
                      'DONE',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCacheItemRow(CacheItemStatus item) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Status icon - three states: waiting, in-progress, complete
              SizedBox(
                width: 24,
                height: 24,
                child: item.isComplete
                    ? (item.isSuccess
                        ? Icon(Icons.check_circle,
                            color: Colors.green, size: 24)
                        : Icon(Icons.cancel, color: Colors.red, size: 24))
                    : (item.isInProgress
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF2c9ed9)),
                            ),
                          )
                        : Icon(Icons.schedule,
                            color: Colors.grey, size: 24)), // Waiting icon
              ),
              SizedBox(width: 12),
              // Item name
              Expanded(
                child: Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Percentage/Status text
              Text(
                item.isComplete
                    ? (item.isSuccess ? '100%' : 'Failed')
                    : (item.isInProgress ? 'Loading...' : 'Waiting'),
                style: TextStyle(
                  fontSize: 12,
                  color: item.isComplete
                      ? (item.isSuccess ? Colors.green : Colors.red)
                      : (item.isInProgress ? Color(0xFF2c9ed9) : Colors.grey),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: item.isComplete ? 1.0 : (item.isInProgress ? 0.5 : 0.0),
              minHeight: 4,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                item.isComplete
                    ? (item.isSuccess ? Colors.green : Colors.red)
                    : (item.isInProgress ? Color(0xFF2c9ed9) : Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String narrationModuleNo = '';
  bool narrationReadRight = false;
  bool narrationWriteRights = false;
  bool narrationUpdateRights = false;
  bool narrationDeleteRight = false;
  bool narrationPrintRights = false;

  @override
  Widget build(BuildContext context) {
    final UserProvider ub = context.watch<UserProvider>();
    final ProfileProvider p = context.watch<ProfileProvider>();

    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.white,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Image.asset(
                    'assets/arhamOMS_icon.png',
                    fit: BoxFit.contain,
                    width: MediaQuery.of(context).size.width * 0.55,
                    // Don't use full screen height here
                    height: MediaQuery.of(context).size.height *
                        0.14, // Reduce height
                  ),
                ),
              ],
            ),
          ),

          // FAZAL Changes 15-12-2025
          // ListTile(
          //   leading: Icon(
          //     Icons.home,
          //     size: 30,
          //   ),
          //   title: Text(
          //     'Home',
          //     style: TextStyle(
          //       fontSize: 20,
          //     ),
          //   ),
          //   onTap: () {
          //     //Get.to(() => HomePage());
          //     Get.offAll(() =>
          //         BottomnavigationBarScreen()); // FAZAL Changes 14-02-2025
          //   },
          // ),
          // ADD : FAZAL Changes 15-12-2025
          // ListTile(
          //   leading: Icon(
          //     Icons.widgets_outlined,
          //     size: 30,
          //   ),
          //   title: Text(
          //     'Menus',
          //     style: TextStyle(
          //       fontSize: 20,
          //     ),
          //   ),
          //   onTap: () {
          //     Get.to(() => NewMenu());
          //   },
          // ),
          // if (p.data?.modulesList != null &&
          //     p.data!.modulesList!.any((module) =>
          //         module.mODULENO == "301" &&
          //         module.rEADRIGHT == true))
          //   ListTile(
          //     leading: Icon(
          //       Icons.dashboard,
          //       size: 30,
          //     ),
          //     title: Text(
          //       'DashBoard',
          //       style: TextStyle(fontSize: 20),
          //     ),
          //     onTap: () {
          //       Get.to(() => DailyReportScreen());
          //     },
          //   ),
          if (p.data != null &&
              p.data!.modulesList!.any((module) =>
                  module.mODULENO == "109" && module.rEADRIGHT == true))
            ListTile(
              leading: Icon(
                Icons.nat_rounded,
                size: 30,
              ),
              title: Text(
                'Narration',
                style: TextStyle(fontSize: 20),
              ),
              onTap: () {
                Get.to(NarrationView(), arguments: {
                  "ModuleNo": narrationModuleNo,
                  "ReadRight": narrationReadRight,
                  "WriteRight": narrationWriteRights,
                  "UpdateRight": narrationUpdateRights,
                  "DeleteRight": narrationDeleteRight,
                  "PrintRight": narrationPrintRights,
                });
              },
            ),
          if (ub.role == AppConfig.masteruser)
            ListTile(
              leading: Icon(
                Icons.business_sharp,
                size: 30,
              ),
              title: Text(
                'Firm Management',
                style: TextStyle(fontSize: 20),
              ),
              onTap: () {
                Get.to(() => FirmListPage());
              },
            ),
          if (p.data != null &&
              p.data!.modulesList!.any((module) =>
                  module.mODULENO == "110" && module.rEADRIGHT == true))
            ListTile(
              leading: Icon(
                Icons.group,
                size: 30,
              ),
              title: Text(
                'User Management',
                style: TextStyle(
                  fontSize: 20,
                ),
              ),
              onTap: () {
                Get.to(() => UserScreen());
              },
            ),
          // ListTile(
          //   leading: Icon(
          //     Icons.account_circle,
          //     size: 30,
          //   ),
          //   title: Text(
          //     'Profile',
          //     style: TextStyle(fontSize: 20),
          //   ),
          //   onTap: () {
          //     Get.to(() => ProfilePage());
          //   },
          // ),
          ListTile(
            leading: Icon(
              Icons.store,
              size: 30,
            ),
            title: Text(
              'Party Management',
              style: TextStyle(
                fontSize: 20,
              ),
            ),
            onTap: () {
              Get.to(() => AccountListScreen());
            },
          ),
          if (ub.role == AppConfig.masteruser)
            ListTile(
              leading: Icon(
                Icons.settings,
                size: 30,
              ),
              title: Text(
                'Settings',
                style: TextStyle(
                  fontSize: 20,
                ),
              ),
              onTap: () {
                Get.to(() => SettingScreen());
              },
            ),
          if (p.data != null &&
              p.data!.modulesList!.any((module) =>
                  module.mODULENO == "235" && module.wRITERIGHT == true))
            ListTile(
              leading: Icon(
                CupertinoIcons.scope,
                size: 30,
              ),
              title: Text(
                'Secondary Sales',
                style: TextStyle(
                  fontSize: 20,
                ),
              ),
              onTap: () {
                Get.to(() => SecondaryTargetView());
              },
            ),
          if (p.data != null &&
              p.data!.modulesList!.any((module) =>
                  module.mODULENO == "233" && module.rEADRIGHT == true))
            ListTile(
              leading: Icon(
                Icons.route_outlined,
                size: 30,
              ),
              title: Text(
                'Beat Schedule',
                style: TextStyle(
                  fontSize: 20,
                ),
              ),
              onTap: () {
                Get.to(() => BeatListView());
              },
            ),
          // ✅ Show Go Offline button only if offline mode is enabled
          Selector<ProfileProvider, bool>(
            selector: (context, profileProvider) =>
                profileProvider.isOfflineModeEnabled(),
            builder: (context, isOfflineModeEnabled, child) {
              if (!isOfflineModeEnabled) {
                print(
                    '[HomePage] Offline mode disabled - hiding Go Offline button');
                return SizedBox.shrink(); // Hide if offline mode disabled
              }
              print(
                  '[HomePage] Offline mode enabled - showing Go Offline button');
              return ListTile(
                leading: Icon(
                  Icons.cloud_download,
                  size: 30,
                ),
                title: Text(
                  'Go Offline',
                  style: TextStyle(
                    fontSize: 20,
                  ),
                ),
                onTap: () {
                  _showOfflineCachingDialog();
                },
              );
            },
          ),
          ListTile(
            leading: Icon(
              Icons.key,
              size: 30,
            ),
            title: Text(
              'Change Password',
              style: TextStyle(
                fontSize: 20,
              ),
            ),
            onTap: () {
              Get.to(() => ChangePasswordView());
            },
          ),
          if (p.data != null &&
              p.data!.modulesList!.any((module) =>
                  module.mODULENO == "232" && module.wRITERIGHT == true))
            ListTile(
              leading: Icon(
                Icons.add_task,
                size: 30,
              ),
              title: Text(
                'Assign Tasks',
                style: TextStyle(
                  fontSize: 20,
                ),
              ),
              onTap: () {
                Get.to(() => AssignTaskView());
              },
            ),
          if (p.data != null &&
              p.data!.modulesList!.any((module) =>
                  module.mODULENO == "232" && module.rEADRIGHT == true))
            ListTile(
              leading: Icon(
                Icons.task,
                size: 30,
              ),
              title: Text(
                'View Tasks',
                style: TextStyle(
                  fontSize: 20,
                ),
              ),
              onTap: () {
                Get.to(() => TaskListView());
              },
            ),
          ListTile(
            leading: Icon(
              Icons.group_add,
              size: 30,
            ),
            title: Text(
              'Generate Referral',
              style: TextStyle(
                fontSize: 20,
              ),
            ),
            onTap: () {
              Get.to(() => ReferralView());
            },
          ),
          // Reimbursement (Module 231)
          if (_profileProvider.data?.modulesList != null &&
              _profileProvider.data!.modulesList!.any((module) =>
                  module.mODULENO == "231" &&
                  (module.rEADRIGHT == true || module.wRITERIGHT == true)))
            ListTile(
              leading: Icon(
                Icons.attach_money,
                size: 30,
              ),
              title: Text(
                'Reimbursement',
                style: TextStyle(
                  fontSize: 20,
                ),
              ),
              onTap: () {
                Get.to(() => GetExpenseView());
              },
            ),
          ListTile(
            leading: Icon(
              Icons.info_outline,
              size: 30,
            ),
            title: Text(
              'About Us',
              style: TextStyle(
                fontSize: 20,
              ),
            ),
            onTap: () {
              Get.to(() => AboutPage());
            },
          ),
          ListTile(
            leading: Icon(
              Icons.logout,
              color: Colors.red,
              size: 30,
            ),
            title: Text(
              'Logout',
              style: TextStyle(
                fontSize: 20,
              ),
            ),
            onTap: () {
              // Show confirmation dialog
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text('Logout Confirmation'),
                    content: Text('Are you sure you want to log out?'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          // Cancel button: Close the dialog
                          Navigator.of(context).pop();
                        },
                        child: Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          // Confirm logout
                          Navigator.of(context).pop(); // Close the dialog
                          ub.userSignout(context).then((value) {
                            Get.offAll(() => LoginPage());
                          });
                        },
                        child: Text('Logout'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
