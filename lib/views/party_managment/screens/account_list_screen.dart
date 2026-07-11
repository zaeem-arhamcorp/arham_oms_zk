import 'package:arham_corporation/helper/helper.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/party_provider.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/views/party_managment/bindings/account_bindings.dart';
import 'package:arham_corporation/views/party_managment/core/account_repository.dart';
import 'package:arham_corporation/views/party_managment/screens/add_account_screen.dart';
import 'package:arham_corporation/views/party_managment/screens/edit_account_screen.dart';
import 'package:arham_corporation/views/route_schedule_plan/controllers/beat_controller.dart';
import 'package:arham_corporation/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AccountListScreen extends StatefulWidget {
  const AccountListScreen({super.key});

  @override
  State<AccountListScreen> createState() => _AccountListScreenState();
}

class _AccountListScreenState extends State<AccountListScreen> {
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadParties());
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadParties() async {
    final partyProvider = context.read<PartyProvider>();
    final beatController = Get.find<BeatController>();
    // Load all parties across beats using report/party?groupCd=85

    if (beatController.beats.isEmpty) {
      print('Before fetch: ${beatController.beats.length}');
      await beatController.fetchBeats();
      print('After fetch: ${beatController.beats.length}');
    }

    await partyProvider.getPartyNameReportGroup85(context);

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
    });
  }

  List get _filteredData {
    final partyProvider = context.read<PartyProvider>();
    if (_searchQuery.isEmpty) {
      return partyProvider.data;
    }
    return partyProvider.data
        .where((party) =>
            party.accName.toLowerCase().contains(_searchQuery) ||
            party.accCd.toLowerCase().contains(_searchQuery) ||
            (party.person_nm?.toLowerCase().contains(_searchQuery) ?? false) ||
            party.mobile.toLowerCase().contains(_searchQuery))
        .toList();
  }

  final beatController = Get.find<BeatController>();

  @override
  Widget build(BuildContext context) {
    final partyProvider = context.watch<PartyProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    // final hasOmsWithoutErpSync = Helper.hasOmsWithoutErpSync(profileProvider);
    final bool isOmsWithoutErpSync = profileProvider.data?.profileSettings
            .any((e) => e.variable == 'omsWithoutErpSync' && e.value == 'Y') ??
        false;
    final canEditParty = Helper.canEditParty(profileProvider);
    final canDeleteParty = Helper.canDeleteParty(profileProvider);
    final canAddParty = Helper.canAddParty(profileProvider);
    final filteredData = _filteredData;

    bool showMoreOption = false;

    print("DEBUG: isOmsWithoutErpSync = $isOmsWithoutErpSync");
    print(
        "DEBUG: canEditParty = $canEditParty, canDeleteParty = $canDeleteParty");

    if (isOmsWithoutErpSync && (canEditParty || canDeleteParty)) {
      showMoreOption = true;
    }

    final beatCount = beatController.beats.length;

    return Scaffold(
      appBar: CustomAppBar(
        title: "Parties",
        actions: [
          if (canAddParty)
            IconButton(
              onPressed: () async {
                final result = await Get.to<bool>(
                    () => const AddAccountScreen(),
                    binding: AccountBindings());

                if (result == true) {
                  final currentContext = Get.context;
                  if (currentContext != null) {
                    await Provider.of<PartyProvider>(
                      currentContext,
                      listen: false,
                    ).getPartyNameProductPage(currentContext);
                  }
                }
                // Get.to(() => AddAccountScreen(), binding: AccountBindings());
              },
              icon: Icon(Icons.add),
            ),
        ],
      ),
      // backgroundColor: Colors.grey[100],
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Container(
                    // color: Colors.grey[100],
                    color: Colors.white,
                    padding: const EdgeInsets.all(12.0),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name, code, contact...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadParties,
                      child: filteredData.isEmpty
                          ? ListView(
                              children: [
                                SizedBox(height: 120),
                                Center(
                                  child: Text(_searchQuery.isEmpty
                                      ? 'No parties found'
                                      : 'No parties match your search'),
                                ),
                              ],
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(12),
                              itemCount: filteredData.length,
                              separatorBuilder: (_, __) =>
                                  // const Divider(height: 1),
                                  SizedBox(
                                height: 1,
                              ),
                              itemBuilder: (context, index) {
                                return showPartyListTilesWithSearch(
                                  index,
                                  filteredData,
                                  showMoreButton: showMoreOption,
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  static Widget showPartyListTilesWithSearch(int index, List listOfParty,
      {bool showMoreButton = false}) {
    // 🛡️ Bounds check: Prevent RangeError when index is out of bounds
    if (index < 0 || index >= listOfParty.length) {
      print(
          '[Helper] ⚠️ Index out of bounds: index=$index, listLength=${listOfParty.length}');
      return ListTile(
        leading: Text("${index + 1}"),
        title: const Text("Item not found"),
        dense: true,
      );
    }

    // Format last-order age into a readable and non-empty label.
    final int? daysAgo = listOfParty[index].lastOrderDays;

    late final String lastOrderText;
    late final Color lastOrderColor;

    if (daysAgo == null) {
      lastOrderText = 'No previous order';
      lastOrderColor = Colors.red;
    } else if (daysAgo == 0) {
      lastOrderText = 'Last order: Today';
      lastOrderColor = Colors.green;
    } else if (daysAgo == 1) {
      lastOrderText = 'Last order: Yesterday';
      lastOrderColor = Colors.green;
    } else if (daysAgo > 1) {
      lastOrderText = 'Last order: $daysAgo days ago';

      if (daysAgo > 60) {
        lastOrderColor = Colors.red;
      } else if (daysAgo > 15) {
        lastOrderColor = Colors.orange;
      } else {
        lastOrderColor = Colors.green; // 2-28 days
      }
    } else {
      lastOrderText = 'No previous order';
      lastOrderColor = Colors.red;
    }

    print('Party=${listOfParty[index].accName}, '
        'lastOrderDays=${listOfParty[index].lastOrderDays}');

    // Get beat information if party has beatCd
    String beatName = '';
    final beatCd = listOfParty[index].beatCd;
    if (beatCd != null && beatCd.toString().trim().isNotEmpty) {
      try {
        final beatController = Get.find<BeatController>();
        final beatList = beatController.beats;
        final beat = beatList.firstWhereOrNull(
          (b) => b.beatCd.toLowerCase() == beatCd.toString().toLowerCase(),
        );
        if (beat != null) {
          beatName = beat.beatName;
        }
      } catch (e) {
        // BeatController not found, skip beat display
        print('[Helper] Beat info not available: $e');
      }
    }

    final context = Get.context;
    final profileProvider =
        Provider.of<ProfileProvider>(context!, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    final canEditParty = Helper.canEditParty(profileProvider);
    final canDeleteParty = Helper.canDeleteParty(profileProvider);

    final isOmsWithoutERPSyncEnabled = profileProvider.data?.profileSettings
            .any((e) => e.variable == 'omsWithoutErpSync' && e.value == 'Y') ??
        false;

    // return ListTile(
    //   // leading: Text("${index + 1}"),
    //   // trailing: showEditButton
    //   //     ? IconButton(
    //   //         onPressed: () async {
    //   //           final accountData = _toAccountDataMap(listOfParty[index]);
    //   //           final result = await Get.to<bool>(
    //   //             () => EditAccountScreen(accountData: accountData),
    //   //             binding: AccountBindings(),
    //   //           );
    //   //
    //   //           if (result == true) {
    //   //             final context = Get.context;
    //   //             if (context != null) {
    //   //               try {
    //   //                 await Provider.of<PartyProvider>(context, listen: false)
    //   //                     .getPartyNameProductPage(context);
    //   //               } catch (e) {
    //   //                 print(
    //   //                     '[Helper] Failed to refresh party list after edit: $e');
    //   //               }
    //   //             }
    //   //           }
    //   //         },
    //   //         icon: Icon(Icons.edit),
    //   //       )
    //   //     : null,
    //   // trailing: ,
    //   title: Row(
    //     children: [
    //       RichText(
    //         text: TextSpan(
    //             //"(${listOfParty[index].accCd}) ${listOfParty[index].accName} ${listOfParty[index].person_nm != null ? " - " + listOfParty[index].person_nm : ""}",
    //             text: "${listOfParty[index].accName} ",
    //             style: TextStyle(
    //                 fontSize: 15.0,
    //                 fontWeight: FontWeight.bold,
    //                 color: Colors.black),
    //             children: [
    //               TextSpan(
    //                   style: TextStyle(fontWeight: FontWeight.normal),
    //                   text:
    //                       "${listOfParty[index].person_nm != null ? " - ${listOfParty[index].person_nm}" : ""} "),
    //             ]),
    //       ),
    //       Spacer(),
    //       if (showEditButton) ...[
    //         PopupMenuButton<String>(
    //           icon: const Icon(Icons.more_vert),
    //           onSelected: (value) async {
    //             if (value == 'edit') {
    //               final accountData = _toAccountDataMap(listOfParty[index]);
    //
    //               final result = await Get.to<bool>(
    //                 () => EditAccountScreen(accountData: accountData),
    //                 binding: AccountBindings(),
    //               );
    //
    //               if (result == true) {
    //                 final context = Get.context;
    //                 if (context != null) {
    //                   try {
    //                     await Provider.of<PartyProvider>(
    //                       context,
    //                       listen: false,
    //                     ).getPartyNameProductPage(context);
    //                   } catch (e) {
    //                     debugPrint(
    //                       '[Helper] Failed to refresh party list after edit: $e',
    //                     );
    //                   }
    //                 }
    //               }
    //             }
    //           },
    //           itemBuilder: (context) => const [
    //             PopupMenuItem(
    //               value: 'edit',
    //               child: Row(
    //                 children: [
    //                   Icon(Icons.edit, size: 20),
    //                   SizedBox(width: 8),
    //                   Text('Edit'),
    //                 ],
    //               ),
    //             ),
    //           ],
    //         )
    //       ]
    //     ],
    //   ),
    //   subtitle: RichText(
    //     text: TextSpan(
    //       text: "(${listOfParty[index].accCd})",
    //       style: TextStyle(color: Colors.black54),
    //       children: [
    //         TextSpan(
    //             text:
    //                 "${listOfParty[index].accAddress} || ${listOfParty[index].mobile}"),
    //         if (!isOmsWithoutERPSyncEnabled) ...[
    //           WidgetSpan(
    //               child: Container(
    //             padding: const EdgeInsets.symmetric(
    //               horizontal: 5,
    //               vertical: 1,
    //             ),
    //             decoration: BoxDecoration(
    //               color: Colors.grey.withValues(alpha: 0.1),
    //               borderRadius: BorderRadius.circular(5),
    //             ),
    //             child: Text(
    //               "${listOfParty[index].clBAL != null ? " CL BAL : ${formatAmount(double.parse(listOfParty[index].clBAL.toString()))}" : ""}",
    //               style: TextStyle(color: Colors.green),
    //             ),
    //           )),
    //         ],
    //         TextSpan(text: " (${listOfParty[index].accCd})"),
    //         if (listOfParty[index].accCartItem != null)
    //           TextSpan(
    //             text: " || ${listOfParty[index].accCartItem} ",
    //             style: TextStyle(color: Colors.amber),
    //           ),
    //         if (beatName.isNotEmpty)
    //           TextSpan(
    //             text: "Beat: $beatName\n",
    //             style: TextStyle(
    //               color: Colors.blue,
    //               fontWeight: FontWeight.w500,
    //             ),
    //           ),
    //         // TextSpan(
    //         //   text: "$lastOrderText",
    //         //   style: TextStyle(
    //         //     color: lastOrderColor,
    //         //     fontWeight: FontWeight.w500,
    //         //     backgroundColor: lastOrderColor.withValues(alpha: 0.2),
    //         //   ),
    //         // ),
    //         WidgetSpan(
    //           child: Container(
    //             padding: const EdgeInsets.symmetric(
    //               horizontal: 5,
    //               vertical: 1,
    //             ),
    //             decoration: BoxDecoration(
    //               color: lastOrderColor.withValues(alpha: 0.1),
    //               borderRadius: BorderRadius.circular(5),
    //             ),
    //             child: Text(
    //               lastOrderText,
    //               style: TextStyle(
    //                 color: lastOrderColor,
    //                 fontWeight: FontWeight.w600,
    //               ),
    //             ),
    //           ),
    //         ),
    //       ],
    //     ),
    //   ),
    //   dense: true,
    //   shape: RoundedRectangleBorder(
    //     borderRadius: BorderRadius.circular(12),
    //     side: BorderSide(color: Colors.grey.shade300),
    //   ),
    //   tileColor: Colors.white,
    // );
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      // color: Colors.grey[100],
      color: Colors.white,
      child: Container(
        // margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          // color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Row 1 : Account + Person + More
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: [
                      Text(
                        listOfParty[index].accName ?? "",
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if ((listOfParty[index].person_nm ?? "").isNotEmpty)
                        Text(
                          "- ${listOfParty[index].person_nm}",
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                    ],
                  ),
                ),
                if (showMoreButton)
                  SizedBox(
                    height: 25,
                    width: 25,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                      splashRadius: 18,
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) async {
                        if (value == "edit") {
                          final accountData =
                              _toAccountDataMap(listOfParty[index]);

                          final result = await Get.to<bool>(
                            () => EditAccountScreen(
                              accountData: accountData,
                            ),
                            binding: AccountBindings(),
                          );

                          if (result == true) {
                            final context = Get.context;
                            if (context != null) {
                              await Provider.of<PartyProvider>(
                                context,
                                listen: false,
                              ).getPartyNameProductPage(context);
                            }
                          }
                        }
                        if (value == "delete") {
                          final currentContext = Get.context;
                          if (currentContext == null) return;

                          // 1. Show Confirmation Dialog
                          bool confirmDelete = await showDialog<bool>(
                                context: currentContext,
                                builder: (BuildContext dialogContext) {
                                  return AlertDialog(
                                    title: const Text("Delete Party"),
                                    content: Text(
                                        "Are you sure you want to delete ${listOfParty[index].accName ?? 'this party'}?"),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(dialogContext)
                                                .pop(false),
                                        child: const Text("Cancel"),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(dialogContext)
                                                .pop(true),
                                        style: TextButton.styleFrom(
                                            foregroundColor: Colors.red),
                                        child: const Text("Delete"),
                                      ),
                                    ],
                                  );
                                },
                              ) ??
                              false;

                          if (confirmDelete) {
                            try {
                              final accCd = listOfParty[index].accCd;
                              if (accCd == null || accCd.isEmpty) {
                                AppSnackBar.showGetXCustomSnackBar(
                                  message: 'Account code missing',
                                  backgroundColor: Colors.red,
                                );
                                return;
                              }

                              // Show loading spinner dialog
                              Get.dialog(
                                const Center(
                                    child: CircularProgressIndicator()),
                                barrierDismissible: false,
                              );

                              // 2. Fetch or initialize the AccountRepository
                              final repository =
                                  Get.isRegistered<AccountRepository>()
                                      ? Get.find<AccountRepository>()
                                      : Get.put(AccountRepository());

                              // 3. Execute delete request via repository layer
                              final result = await repository.deleteAccount(
                                accCode: accCd,
                                token: userProvider.token ?? '',
                              );

                              // Dismiss the loading spinner dialog safely
                              if (Get.isDialogOpen ?? false) Get.back();

                              if (result['success'] == true) {
                                // Standard Success Snackbar used across Arham Corporation apps
                                AppSnackBar.showGetXCustomSnackBar(
                                  message: result['message'] ??
                                      'Account deleted successfully',
                                  backgroundColor: Colors.green,
                                );

                                // 4. Refresh provider list data
                                final refreshContext = Get.context;
                                if (refreshContext != null) {
                                  await Provider.of<PartyProvider>(
                                    refreshContext,
                                    listen: false,
                                  ).getPartyNameProductPage(refreshContext);
                                }
                              } else {
                                // Standard Error Snackbar
                                AppSnackBar.showGetXCustomSnackBar(
                                  message: result['message'] ??
                                      result['error'] ??
                                      'Deletion failed',
                                  backgroundColor: Colors.red,
                                );
                              }
                            } catch (e) {
                              if (Get.isDialogOpen ?? false) Get.back();
                              AppSnackBar.showGetXCustomSnackBar(
                                message: 'Something went wrong',
                                backgroundColor: Colors.red,
                              );
                            }
                          }
                        }
                      },
                      itemBuilder: (_) => [
                        if (canEditParty)
                          PopupMenuItem(
                            value: "edit",
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit,
                                  size: 18,
                                  color: Colors.blueGrey,
                                ),
                                SizedBox(width: 8),
                                Text("Edit"),
                              ],
                            ),
                          ),
                        if (canDeleteParty)
                          PopupMenuItem(
                            value: "delete",
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete,
                                  size: 18,
                                  color: Colors.red,
                                ),
                                SizedBox(width: 8),
                                Text("Delete"),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),

            /// Row 2 : Code + Balance
            Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (!isOmsWithoutERPSyncEnabled &&
                    listOfParty[index].clBAL != null)
                  Builder(
                    builder: (_) {
                      final balance = double.tryParse(
                              listOfParty[index].clBAL.toString()) ??
                          0;

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: balance < 0
                              ? Colors.red.withValues(alpha: 0.08)
                              : Colors.green.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "CL BAL: ${formatAmount(balance)}",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: balance < 0 ? Colors.red : Colors.green,
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "Code: ${listOfParty[index].accCd}",
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            /// Row 3 : Address + Phone
            Theme(
              data: Theme.of(context).copyWith(
                textSelectionTheme: TextSelectionThemeData(
                  // This changes the color of the selection handles
                  selectionHandleColor: Colors.blue,
                  // This changes the background color of the selected text (replaces selectionColor)
                  selectionColor: Colors.blue.shade100,
                ),
              ),
              child: SelectableText(
                "${listOfParty[index].accAddress}  |  ${listOfParty[index].mobile}",
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
            ),

            const SizedBox(height: 8),

            /// Row 4 : Beat + Last Order
            Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (beatName.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "Beat: $beatName",
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: lastOrderColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    lastOrderText,
                    style: TextStyle(
                      color: lastOrderColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String formatAmount(double amount) {
    final formatter =
        NumberFormat('#,##0.00', 'en_US'); // Format with commas and 2 decimals
    return formatter.format(amount);
  }

  static Map<String, dynamic> _toAccountDataMap(dynamic party) {
    if (party is Map<String, dynamic>) {
      return party;
    }

    String beatCd = '';
    try {
      beatCd = (party.beatCd ?? '').toString();
    } catch (_) {
      beatCd = '';
    }

    return {
      'ACC_CD': party.accCd ?? '',
      'ACC_NAME': party.accName ?? '',
      'BEAT_CD': beatCd,
      'PERSON_NM': party.person_nm ?? '',
      'MOBILE1': party.mobile ?? '',
      'ADD1': party.add1 ?? '',
      'WA_NO': party.whNo ?? '',
      'USER_CD': party.userCd ?? '',
      'ZONE': party.zone ?? '',
      'CITY': party.city ?? '',
      'STATE': party.state ?? '',
      'PINCODE': party.pincode ?? '',
      'LATITUDE': party.lat ?? 0,
      'LONGITUDE': party.long ?? 0,
      'GST_NO': party.gstNo ?? '',
      'GST_TYPE': party.gstType ?? '',
      'DRUG_LIC1': party.drugLic1 ?? '',
      'DRUG_LIC2': party.drugLic2 ?? '',
      'FSSAI_NO': party.fssaiNo ?? '',
      'EMAIL': party.email ?? '',
      'PAN_NO': party.panNo ?? '',
      'CREDIT_DAY': party.creditDay ?? 0,
      'CR_LIMIT': party.crLimit ?? 0,
      'CL_BAL': party.clBAL ?? 0,
      'ACC_ADD': party.accAddress ?? '',
      'ACC_CART_ITEM': party.accCartItem ?? '',
      'LAST_ORDER_DAYS_AGO': party.lastOrderDays ?? 0,
    };
  }
}
