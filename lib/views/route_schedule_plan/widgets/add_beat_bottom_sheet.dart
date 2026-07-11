import 'package:arham_corporation/helper/route_label_helper.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/views/route_schedule_plan/services/beat_service.dart';
import 'package:arham_corporation/widgets/user_search_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AddBeatBottomSheet extends StatefulWidget {
  final VoidCallback onBeatCreated;

  const AddBeatBottomSheet({required this.onBeatCreated});

  @override
  State<AddBeatBottomSheet> createState() => _AddBeatBottomSheetState();
}

class _AddBeatBottomSheetState extends State<AddBeatBottomSheet> {
  late TextEditingController beatNameController;
  String? selectedUserCode = '';
  List<Map<String, dynamic>> users = [];
  bool loadingUsers = false;

  @override
  void initState() {
    super.initState();
    beatNameController = TextEditingController();
    _fetchChildren();
  }

  @override
  void dispose() {
    beatNameController.dispose();
    super.dispose();
  }

  Future<void> _fetchChildren() async {
    setState(() {
      loadingUsers = true;
    });
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final token = userProvider.token?.trim();

      final childrenList = await BeatService().fetchChildren(token: token);
      setState(() {
        users = childrenList;
      });
    } catch (e) {
      debugPrint('[AddBeatBottomSheet] fetchChildren error: $e');
      if (mounted) {
        AppSnackBar.showGetXCustomSnackBar(
            message: 'Failed to load users', backgroundColor: Colors.orange);
      }
    } finally {
      setState(() {
        loadingUsers = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final routeLabel = RouteLabelHelper.singularMaster(profile);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  RouteLabelHelper.addTitle(profile),
                  style: TextStyle(
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            SizedBox(
              height: 10,
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: beatNameController,
                      decoration: InputDecoration(
                        labelText: '$routeLabel name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    UserSearchDropdown(
                      users: users,
                      selectedUserCode: selectedUserCode,
                      loading: loadingUsers,
                      onChanged: (code) {
                        setState(() {
                          selectedUserCode = code;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final beatName = beatNameController.text.trim();
                      if (beatName.isEmpty) {
                        AppSnackBar.showGetXCustomSnackBar(
                            message: 'Please enter $routeLabel name',
                            backgroundColor: Colors.red);
                        return;
                      }
                      if (selectedUserCode == null ||
                          selectedUserCode!.isEmpty) {
                        AppSnackBar.showGetXCustomSnackBar(
                            message: 'Please select a user',
                            backgroundColor: Colors.red);
                        return;
                      }

                      try {
                        final token =
                            Provider.of<UserProvider>(context, listen: false)
                                .token;
                        final sanitizedToken = token?.trim();
                        if (sanitizedToken == null || sanitizedToken.isEmpty) {
                          AppSnackBar.showGetXCustomSnackBar(
                              message: 'User token not found',
                              backgroundColor: Colors.red);
                          return;
                        }

                        await BeatService().createBeat(
                          beatName: beatName,
                          moduleNo: '102',
                          assignUser: selectedUserCode!,
                          token: sanitizedToken,
                        );

                        if (!mounted) return;
                        Navigator.of(context).pop();
                        AppSnackBar.showGetXCustomSnackBar(
                            message: '$routeLabel created',
                            backgroundColor: Colors.green);
                        widget.onBeatCreated();
                      } catch (e) {
                        if (!mounted) return;
                        AppSnackBar.showGetXCustomSnackBar(
                            message: 'Create failed: $e',
                            backgroundColor: Colors.red);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Create'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
