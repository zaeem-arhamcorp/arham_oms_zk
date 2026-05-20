import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/helper/route_label_helper.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/views/route_schedule_plan/services/beat_service.dart';
import 'package:arham_corporation/widgets/user_search_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EditBeatBottomSheet extends StatefulWidget {
  final String beatCd;
  final String initialBeatName;
  final String initialAssignUser;
  final VoidCallback onBeatUpdated;

  const EditBeatBottomSheet({
    required this.beatCd,
    required this.initialBeatName,
    required this.initialAssignUser,
    required this.onBeatUpdated,
  });

  @override
  State<EditBeatBottomSheet> createState() => _EditBeatBottomSheetState();
}

class _EditBeatBottomSheetState extends State<EditBeatBottomSheet> {
  late TextEditingController beatNameController;
  String? selectedUserCode = '';
  List<Map<String, dynamic>> users = [];
  bool loadingUsers = false;
  String? initialSearchText;
  String? _beatUserCdFromApi;
  bool submitting = false;

  @override
  void initState() {
    super.initState();
    beatNameController = TextEditingController();
    // Load beat details and children, then prefill
    _loadBeatDetails();
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
      if (!mounted) return;
      setState(() {
        users = childrenList;
      });
    } catch (e) {
      debugPrint('[EditBeatBottomSheet] fetchChildren error: $e');
      if (mounted) {
        AppSnackBar.showGetXCustomSnackBar(
            message: 'Failed to load users', backgroundColor: Colors.orange);
      }
    } finally {
      if (mounted) {
        setState(() {
          loadingUsers = false;
        });
      }
    }
  }

  Future<void> _loadBeatDetails() async {
    setState(() {
      loadingUsers = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final token = userProvider.token?.trim();

      // Fetch beat details
      final data = await BeatService()
          .fetchBeatByCode(beatCd: widget.beatCd, token: token);
      final beatName = (data['BEAT_NAME'] ?? '').toString();
      final userCd =
          (data['USER_CD'] ?? data['USER_CD'] ?? '').toString().trim();
      _beatUserCdFromApi = userCd;

      // Fetch children
      final childrenList = await BeatService().fetchChildren(token: token);
      if (!mounted) return;

      setState(() {
        users = childrenList;
        beatNameController.text = beatName;
      });

      // Match userCd with fetched users and set selected and initial search text
      if (_beatUserCdFromApi != null && _beatUserCdFromApi!.isNotEmpty) {
        final idx = users.indexWhere(
            (u) => (u['userCode'] ?? '').toString() == _beatUserCdFromApi);
        if (idx != -1) {
          final match = users[idx];
          setState(() {
            selectedUserCode = (match['userCode'] ?? '').toString();
            initialSearchText = (match['userName'] ?? '').toString();
          });
        }
      }
    } catch (e) {
      debugPrint('[EditBeatBottomSheet] loadBeatDetails error: $e');
      if (mounted) {
        AppSnackBar.showGetXCustomSnackBar(
            message: 'Failed to load beat details',
            backgroundColor: Colors.orange);
      }
    } finally {
      if (mounted) {
        setState(() {
          loadingUsers = false;
        });
      }
    }
  }

  Future<void> _submitUpdate() async {
    final beatName = beatNameController.text.trim();
    if (beatName.isEmpty) {
      AppSnackBar.showGetXCustomSnackBar(
          message: 'Please enter beat name', backgroundColor: Colors.red);
      return;
    }
    if (selectedUserCode == null || selectedUserCode!.isEmpty) {
      AppSnackBar.showGetXCustomSnackBar(
          message: 'Please select a user', backgroundColor: Colors.red);
      return;
    }

    setState(() {
      submitting = true;
    });

    try {
      final token = Provider.of<UserProvider>(context, listen: false).token;
      final sanitizedToken = token?.trim();
      if (sanitizedToken == null || sanitizedToken.isEmpty) {
        AppSnackBar.showGetXCustomSnackBar(
            message: 'User token not found', backgroundColor: Colors.red);
        return;
      }

      await BeatService().updateBeat(
        beatCd: widget.beatCd,
        beatName: beatName,
        moduleNo: '120',
        assignUser: selectedUserCode!,
        token: sanitizedToken,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      AppSnackBar.showGetXCustomSnackBar(
          message: 'Beat updated', backgroundColor: Colors.green);
      widget.onBeatUpdated();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showGetXCustomSnackBar(
          message: 'Update failed: $e', backgroundColor: Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final routeLabel = RouteLabelHelper.singular(profile);

    return Padding(
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
                RouteLabelHelper.editTitle(profile),
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
                    initialSearchText: initialSearchText,
                    loading: loadingUsers,
                    onChanged: (code) {
                      setState(() {
                        selectedUserCode = code;
                        // clear initialSearchText after manual change
                        initialSearchText = null;
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
                  onPressed: submitting ? null : _submitUpdate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: submitting
                      ? CircularProgressIndicator()
                      : const Text('Update'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
