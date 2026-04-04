import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/models/profileModal.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/services/services.dart';
import 'package:arham_corporation/views/company_management/firm_list.dart';
import 'package:arham_corporation/views/loginpage.dart';
import 'package:arham_corporation/views/narration/narration_view.dart';
import 'package:arham_corporation/views/referral/referral_view.dart';
import 'package:arham_corporation/views/reimbursement/get_expense_view.dart';
import 'package:arham_corporation/views/settingsScreen.dart';
import 'package:arham_corporation/views/userScreen.dart';
import 'package:arham_corporation/widgets/common_app_drawer.dart';
import 'package:arham_corporation/widgets/custom_app_bar.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../services/offline_caching_service.dart';
import 'About me.dart';
import 'change_password/change_password_view.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // It's good practice to initialize controllers in initState or late final
  // and dispose them in dispose().
  late TextEditingController _nameClt;
  late TextEditingController _codeClt; // Renamed for clarity
  late TextEditingController _addressClt;
  late TextEditingController _phoneNoClt; // Renamed for clarity

  // Removed: get ub => null; // This was unused and likely a placeholder

  bool receiptDeleteRight = false;
  bool receiptReadRight = false;
  bool receiptPrintRight = false;
  bool paymentDeleteRight = false;
  bool paymentReadRight = false;
  bool orderDeleteRight = false;
  bool orderPrintRight = false;

  String narrationModuleNo = '';
  bool narrationReadRight = false;
  bool narrationWriteRights = false;
  bool narrationUpdateRights = false;
  bool narrationDeleteRight = false;
  bool narrationPrintRights = false;

  @override
  void initState() {
    super.initState();
    _nameClt = TextEditingController();
    _codeClt = TextEditingController();
    _addressClt = TextEditingController();
    _phoneNoClt = TextEditingController();
    _setData(); // Renamed for convention (private method)

    final ProfileProvider p =
        Provider.of<ProfileProvider>(context, listen: false);

    // var receiptEntryModule =
    // p.data!.modulesList!.firstWhere((module) => module.mODULENO == "214");
    // receiptDeleteRight = receiptEntryModule.dELETERIGHT!;
    //
    // print("Receipt Delete :" + receiptDeleteRight.toString());

    // var paymentEntryModule =
    // p.data!.modulesList!.firstWhere((module) => module.mODULENO == "215");
    // paymentDeleteRight = paymentEntryModule.dELETERIGHT!;
    //
    // print("Payment Delete :" + paymentDeleteRight.toString());

    var narrationEntryModule = p.data?.modulesList?.firstWhere(
          (module) => module.mODULENO == "109",
          orElse: () => Modules(), // Default value in case not found
        ) ??
        Modules(); // Ensure that we get a default value if any part is null

    if (narrationEntryModule.mODULENO == "109") {
      narrationModuleNo = narrationEntryModule.mODULENO!;
      narrationReadRight = narrationEntryModule.rEADRIGHT!;
      narrationWriteRights = narrationEntryModule.wRITERIGHT!;
      narrationUpdateRights = narrationEntryModule.uPDATERIGHT!;
      narrationDeleteRight = narrationEntryModule.dELETERIGHT!;
      narrationPrintRights = narrationEntryModule.pRINTRIGHT!;
    } else {
      print("Module with mODULENO '109' not found.");
    }

    var receiptEntryModule = p.data?.modulesList?.firstWhere(
          (module) => module.mODULENO == "214",
          orElse: () => Modules(), // Default value in case not found
        ) ??
        Modules(); // Ensure that we get a default value if any part is null

    if (receiptEntryModule.mODULENO == "214") {
      receiptDeleteRight = receiptEntryModule.dELETERIGHT!;
      receiptReadRight = receiptEntryModule.rEADRIGHT!;
      receiptPrintRight = receiptEntryModule.pRINTRIGHT!;
      print("Receipt Delete: " + receiptDeleteRight.toString());
      print("Receipt Red: " + receiptReadRight.toString());
      print("Receipt Print: " + receiptPrintRight.toString());
    } else {
      print("Module with mODULENO '214' not found.");
    }

    var orderReportModule = p.data?.modulesList?.firstWhere(
            (module) => module.mODULENO == "304",
            orElse: () => Modules()) ??
        Modules();
    if (orderReportModule.mODULENO == "304") {
      orderPrintRight = orderReportModule.pRINTRIGHT!;
      print("Order Print :" + orderPrintRight.toString());
    } else {
      print("Module with mODULENO '304' not found.");
    }

    var paymentEntryModule = p.data?.modulesList?.firstWhere(
            (module) => module.mODULENO == "215",
            orElse: () =>
                Modules() // Provide a default instance of the `Module` class
            ) ??
        Modules();

    if (paymentEntryModule.mODULENO == "215") {
      paymentDeleteRight = paymentEntryModule.dELETERIGHT!;
      paymentReadRight = paymentEntryModule.rEADRIGHT!;
      print("Payment Delete: " + paymentDeleteRight.toString());
    } else {
      print("Module with mODULENO '215' not found.");
    }
  }

  // It's good practice to dispose controllers
  @override
  void dispose() {
    _nameClt.dispose();
    _codeClt.dispose();
    _addressClt.dispose();
    _phoneNoClt.dispose();
    super.dispose();
  }

  void _setData() {
    // No need for setState here if this is called before the first build,
    // as the controllers are being initialized with the correct values.
    // If this method could be called again later to refresh data *after* build,
    // then setState would be necessary.
    final ProfileProvider p =
        Provider.of<ProfileProvider>(context, listen: false);
    final UserProvider userProvider =
        Provider.of<UserProvider>(context, listen: false);

    _nameClt.text = p.data?.userName ?? 'No User Name';
    _codeClt.text = p.data?.userType ?? 'No User Type';
    _phoneNoClt.text = p.data?.mobileno ?? 'No User Mobile No';
    _addressClt.text =
        userProvider.syncName ?? "No Company Name"; // Simplified null check
  }

  // Helper function to check connectivity
  Future<bool> _isConnected() async {
    final List<ConnectivityResult> connectivityResult =
        await Connectivity().checkConnectivity();
    // Check if the list contains any of the connected types
    // and does not exclusively contain 'none'.
    if (connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi) ||
        connectivityResult.contains(ConnectivityResult.ethernet) ||
        connectivityResult.contains(ConnectivityResult.vpn)) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // You can access UserProvider here or directly in the onTap callback if preferred.
    // If only used in onTap, accessing it there might be slightly cleaner.
    final ProfileProvider p = context.watch<ProfileProvider>();
    final UserProvider ub = Provider.of<UserProvider>(context, listen: false);
    final UserProvider userProvider = context.watch<UserProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: 'Profile',
        actions: [
          // Consider if this Visibility widget is always true. If so, it can be removed.
          Visibility(
            visible: false,
            child: Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: GestureDetector(
                onTap: () async {
                  if (!mounted)
                    return; // Check if the widget is still in the tree

                  if (await _isConnected()) {
                    // Show confirmation dialog
                    final bool? confirmLogout = await showDialog<bool>(
                      // Explicit type
                      context: context,
                      builder: (BuildContext dialogContext) {
                        // Use a different context name
                        return AlertDialog(
                          title: const Text('Confirm Logout'),
                          content:
                              const Text('Are you sure you want to log out?'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(dialogContext)
                                    .pop(false); // Cancel
                              },
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(dialogContext)
                                    .pop(true); // Confirm
                              },
                              child: const Text('Logout'),
                            ),
                          ],
                        );
                      },
                    );

                    // Proceed with logout if confirmed (and not null)
                    if (confirmLogout == true) {
                      // Explicitly check for true
                      // No need for .then if you're not doing anything after the future completes here
                      await userProvider.userSignout(context);
                      if (!mounted) return;
                      Get.offAll(() => LoginPage());
                    }
                  } else {
                    if (!mounted) return;
                    AppSnackBar.showGetXCustomSnackBar(
                        message: 'Please check your internet connection.');
                  }
                },
                child: const Icon(
                  Icons.logout,
                  color: Colors.red,
                  size: 30,
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: CommonAppDrawer(
        narrationModuleNo: narrationModuleNo,
        narrationReadRight: narrationReadRight,
        narrationWriteRights: narrationWriteRights,
        narrationUpdateRights: narrationUpdateRights,
        narrationDeleteRight: narrationDeleteRight,
        narrationPrintRights: narrationPrintRights,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          // Added SingleChildScrollView for longer content
          padding: const EdgeInsets.only(
              top: 15, left: 8, right: 8, bottom: 15), // Added bottom padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileTextField(
                controller: _nameClt,
                label: "Name",
              ),
              const SizedBox(height: 20),
              _buildProfileTextField(
                controller: _codeClt,
                label: "User Type",
              ),
              const SizedBox(height: 20),
              _buildProfileTextField(
                controller: _addressClt,
                label: "Company Name",
              ),
              const SizedBox(height: 20),
              _buildProfileTextField(
                controller: _phoneNoClt,
                label: "Phone No",
              ),
              Padding(
                padding:
                    const EdgeInsets.only(top: 30.0), // Increased top padding
                child: Center(
                  child: Card(
                    shadowColor: Colors
                        .lightBlueAccent, // Slightly different color for variety
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(
                            color: Colors
                                .black54)), // Slightly less prominent border
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12), // Added padding
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              8), // Match card's border radius
                        ),
                      ),
                      child: const Text(
                        "Delete Account",
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        _showDeleteConfirmationDialog(context,
                            userProvider); // Pass userProvider if needed for deletion
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget to reduce repetition for TextFormFields
  Widget _buildProfileTextField({
    required TextEditingController controller,
    required String label,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          vertical: 8.0, horizontal: 8.0), // Consistent padding
      child: Card(
        shadowColor: Colors.lightBlue,
        elevation: 5,
        child: TextFormField(
          readOnly: true,
          controller: controller,
          decoration: InputDecoration(
            label: Text(label),
            focusedBorder: const OutlineInputBorder(), // Use const
            enabledBorder: const OutlineInputBorder(), // Use const
            isDense: true,
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog(
      BuildContext context, UserProvider userProvider) {
    showDialog<void>(
      // Explicit type
      context: context,
      builder: (BuildContext dialogContext) {
        // Use a different context name
        return AlertDialog(
          title: const Text("Confirm Deletion"),
          content: const Text(
              "Are you sure you want to delete your account? This action cannot be undone."),
          actions: <Widget>[
            TextButton(
              child: const Text("No"),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close the dialog
              },
            ),
            TextButton(
              child: const Text("Yes", style: TextStyle(color: Colors.red)),
              onPressed: () async {
                // Make async if service call is async
                if (!mounted) return;
                // Call the delete account service
                // Assuming Services().deleteAccount might also need context or user info
                await Services().deleteAccount(
                    context /*, other params if needed, e.g., userProvider.user.id */);
                if (!mounted) return;
                Navigator.of(dialogContext).pop(); // Close the dialog FIRST
                Get.offAll(() => LoginPage()); // Then navigate
              },
            ),
          ],
        );
      },
    );
  }

  // This function seems unused now. If you re-introduce it,
  // ensure to update the connectivity check and use 'userProvider'
  // which you'd need to pass or access via Provider.of.
  // ignore: unused_element
  void _showLogoutConfirmationDialog_Unused(
      BuildContext context, UserProvider userProvider) async {
    if (!mounted) return;

    if (await _isConnected()) {
      final bool? confirmLogout = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text("Confirm Logout"),
            content: const Text("Are you sure you want to log out?"),
            actions: <Widget>[
              TextButton(
                child: const Text("No"),
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
              ),
              TextButton(
                child: const Text("Yes", style: TextStyle(color: Colors.red)),
                onPressed: () async {
                  Navigator.of(dialogContext).pop(true);
                },
              ),
            ],
          );
        },
      );

      if (confirmLogout == true) {
        await userProvider.userSignout(context);
        if (!mounted) return;
        Get.offAll(() => LoginPage());
      }
    } else {
      if (!mounted) return;
      AppSnackBar.showGetXCustomSnackBar(
          message: 'Please check your internet connection.');
    }
  }
}
