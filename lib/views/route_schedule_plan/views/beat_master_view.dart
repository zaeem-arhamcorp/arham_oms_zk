import 'package:arham_corporation/helper/route_label_helper.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/views/route_schedule_plan/models/beat_master_model.dart';
import 'package:arham_corporation/views/route_schedule_plan/widgets/add_beat_bottom_sheet.dart';
import 'package:arham_corporation/views/route_schedule_plan/widgets/edit_beat_bottom_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/beat_service.dart';

class BeatMasterView extends StatefulWidget {
  const BeatMasterView({Key? key}) : super(key: key);

  @override
  State<BeatMasterView> createState() => _BeatMasterViewState();
}

class _BeatMasterViewState extends State<BeatMasterView> {
  late Future<List<dynamic>> _futureBeatData;

  @override
  void initState() {
    super.initState();
    _futureBeatData = _loadBeatData();
  }

  Future<List<BeatMasterModel>> _loadBeats() async {
    final token = Provider.of<UserProvider>(context, listen: false).token;
    final sanitizedToken = token?.trim();

    debugPrint('[BeatMasterView] token: ${sanitizedToken ?? 'null'}');

    if (sanitizedToken == null || sanitizedToken.isEmpty) {
      throw Exception('User token not found. Please login again.');
    }

    final arr = await BeatService().fetchBeats(token: sanitizedToken);
    return BeatMasterModel.listFromJson(arr);
  }

  Future<Map<String, String>> _loadUserNames() async {
    final token = Provider.of<UserProvider>(context, listen: false).token;
    final sanitizedToken = token?.trim();

    if (sanitizedToken == null || sanitizedToken.isEmpty) {
      return <String, String>{};
    }

    try {
      final users = await BeatService().fetchChildren(token: sanitizedToken);
      return {
        for (final user in users)
          (user['userCode'] ?? '').toString():
              (user['userName'] ?? '').toString(),
      };
    } catch (e) {
      debugPrint('[BeatMasterView] loadUserNames error: $e');
      return <String, String>{};
    }
  }

  Future<List<dynamic>> _loadBeatData() async {
    return Future.wait<dynamic>([
      _loadBeats(),
      _loadUserNames(),
    ]);
  }

  void _reloadData() {
    setState(() {
      _futureBeatData = _loadBeatData();
    });
  }

  void _onMenuSelected(String action, BeatMasterModel beat) {
    if (action == 'edit') {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        builder: (context) {
          return EditBeatBottomSheet(
            beatCd: beat.beatCd ?? '',
            initialBeatName: beat.beatName ?? '',
            initialAssignUser: beat.userCd ?? '',
            onBeatUpdated: () {
              _reloadData();
            },
          );
        },
      );
      return;
    }

    if (action == 'delete') {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Delete ${beat.beatName ?? ''}'),
          content: Text(
            "Are you sure you want to delete ${beat.beatName ?? ''} beat?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[700])),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();

                try {
                  final token =
                      Provider.of<UserProvider>(context, listen: false).token;
                  final sanitizedToken = token?.trim();

                  if (sanitizedToken == null || sanitizedToken.isEmpty) {
                    if (!mounted) return;
                    AppSnackBar.showGetXCustomSnackBar(
                        message: "User token not found",
                        backgroundColor: Colors.red);
                    return;
                  }

                  await BeatService().deleteBeat(
                    beatCd: beat.beatCd ?? '',
                    token: sanitizedToken,
                  );

                  if (!mounted) return;
                  AppSnackBar.showGetXCustomSnackBar(
                      message: "Deleted ${beat.beatName ?? ''} successfully",
                      backgroundColor: Colors.green);

                  // Refresh the list
                  _reloadData();
                } catch (e) {
                  if (!mounted) return;
                  AppSnackBar.showGetXCustomSnackBar(
                      message: "Delete failed: $e",
                      backgroundColor: Colors.green);
                }
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(180),
                ),
                child: Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  void _openAddBeatSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      builder: (context) {
        return AddBeatBottomSheet(onBeatCreated: () {
          _reloadData();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ProfileProvider p = context.watch<ProfileProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(RouteLabelHelper.masterTitle(p)),
        actions: [
          IconButton(
            onPressed: _openAddBeatSheet,
            icon: Icon(Icons.add),
          ),
        ],
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF3B82F6),
                Color(0xFF0057E7),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<List<dynamic>>(
          future: _futureBeatData,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final data = snapshot.data ?? [];
            final beats = data.isNotEmpty
                ? data[0] as List<BeatMasterModel>
                : <BeatMasterModel>[];
            final userNameByCode = data.length > 1
                ? data[1] as Map<String, String>
                : <String, String>{};

            if (beats.isEmpty) {
              return Center(child: Text(RouteLabelHelper.emptyState(p)));
            }

            return ListView.separated(
              itemCount: beats.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final beat = beats[index];
                final assignedUserLabel =
                    userNameByCode[beat.userCd ?? ''] ?? beat.userCd ?? '';
                return ListTile(
                  leading: CircleAvatar(
                    child: Text((beat.beatName ?? '').isNotEmpty
                        ? (beat.beatName!.substring(0, 1))
                        : '?'),
                  ),
                  title: Text(beat.beatName ?? ''),
                  subtitle: assignedUserLabel.isNotEmpty
                      ? Text('User Assigned: $assignedUserLabel')
                      : null,
                  trailing: p.data != null &&
                          p.data!.modulesList!.any((module) =>
                              module.mODULENO == "120" &&
                              (module.uPDATERIGHT == true ||
                                  module.dELETERIGHT == true))
                      ? PopupMenuButton<String>(
                          onSelected: (value) => _onMenuSelected(value, beat),
                          itemBuilder: (ctx) => [
                            if (p.data != null &&
                                p.data!.modulesList!.any((module) =>
                                    module.mODULENO == "120" &&
                                    module.uPDATERIGHT == true))
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.edit,
                                      color: Colors.grey,
                                      size: 18,
                                    ),
                                    SizedBox(
                                      width: 5,
                                    ),
                                    Text('Edit'),
                                  ],
                                ),
                              ),
                            if (p.data != null &&
                                p.data!.modulesList!.any((module) =>
                                    module.mODULENO == "120" &&
                                    module.dELETERIGHT == true))
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      CupertinoIcons.delete_solid,
                                      color: Colors.red,
                                      size: 18,
                                    ),
                                    SizedBox(
                                      width: 5,
                                    ),
                                    Text('Delete'),
                                  ],
                                ),
                              ),
                          ],
                        )
                      : SizedBox.shrink(),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
