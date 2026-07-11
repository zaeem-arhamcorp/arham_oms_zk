import 'package:arham_corporation/helper/route_label_helper.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:arham_corporation/views/route_schedule_plan/services/beat_service.dart';
import 'package:arham_corporation/views/route_schedule_plan/widgets/beat_selection_sheet.dart';
import 'package:arham_corporation/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../../providers/profile_provider.dart';
import '../controllers/beat_controller.dart';
import '../models/beat_model.dart';

class BeatListView extends StatefulWidget {
  const BeatListView({super.key});

  @override
  State<BeatListView> createState() => _BeatListViewState();
}

class _BeatListViewState extends State<BeatListView> {
  DateTime currentMonth = DateTime.now();
  DateTime? selectedDate;
  bool isSaved = false;
  late BeatController beatController;
  Map<String, String> _userNameByCode = {};

  @override
  void initState() {
    super.initState();
    beatController = Get.isRegistered<BeatController>()
        ? Get.find<BeatController>()
        : Get.put(BeatController());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final routeLabel =
            RouteLabelHelper.singularPlanner(context.read<ProfileProvider>());
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text("Attention"),
            content: Text(
                "Remember to save your $routeLabel data before closing the page or else your selected $routeLabel data will be lost."),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text("OK"),
              ),
            ],
          ),
        );
      }
    });

    // Fetch user's beat schedule
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final profileProvider =
            Provider.of<ProfileProvider>(context, listen: false);
        final userCd = profileProvider.userCode;
        if (userCd != null && userCd.isNotEmpty) {
          await beatController.fetchUserBeatSchedule(userCd);
        }

        final token = Provider.of<UserProvider>(context, listen: false).token;
        final users = await BeatService().fetchChildren(token: token?.trim());
        if (!mounted) return;
        setState(() {
          _userNameByCode = {
            for (final user in users)
              (user['userCode'] ?? '').toString():
                  (user['userName'] ?? '').toString(),
          };
        });
      } catch (e) {
        print('[BeatListView] Error fetching beat schedule: $e');
      }
    });
  }

  @override
  void dispose() {
    // Clean up resources
    super.dispose();
  }

  bool _isCurrentMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  bool _isPastDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return normalizedDate.isBefore(today);
  }

  @override
  Widget build(BuildContext context) {
    final routeLabel =
        RouteLabelHelper.singularPlanner(context.read<ProfileProvider>());
    final weeks = _buildMonthMatrix(currentMonth);

    return Scaffold(
      appBar: CustomAppBar(
        title: "$routeLabel Schedule",
        actions: [
          Obx(() {
            // show Save only when there are pending (new) beats
            if (beatController.newBeatsByDate.isEmpty) return SizedBox.shrink();
            return TextButton(
              onPressed: isSaved ? null : _onSavePressed,
              child: Text(
                "Save",
                style: TextStyle(
                  color: isSaved ? Colors.grey.shade400 : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            );
          }),
        ],
      ),
      body: Column(
        children: [
          _buildCalendarHeader(),
          Divider(),
          _buildWeekHeader(),

          /// FULL SCREEN GRID
          Expanded(
            child: Column(
              children: weeks.map((week) {
                return Expanded(
                  child: Row(
                    children: week.map((date) {
                      return Expanded(
                        child: _buildCell(date),
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Weekday header
  Widget _buildWeekHeader() {
    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Row(
      children: days.map((d) {
        return Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                d,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Single cell with beat badges
  Widget _buildCell(DateTime? date) {
    if (date == null) return Container();

    final isToday = _isSameDate(date, DateTime.now());
    final isSelected = _isSameDate(date, selectedDate);

    return Obx(() {
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final List<BeatScheduler> savedBeats =
          beatController.beatsByDate[dateStr] ?? <BeatScheduler>[];
      final List<BeatScheduler> pendingBeats =
          beatController.newBeatsByDate[dateStr] ?? <BeatScheduler>[];
      final hasSaved = savedBeats.isNotEmpty;
      final hasPending = pendingBeats.isNotEmpty;
      final isPast = _isPastDate(date);
      final List<BeatScheduler> displayBeats = hasSaved
          ? savedBeats
          : (hasPending ? pendingBeats : <BeatScheduler>[]);

      return GestureDetector(
        onTap: () {
          if (isPast) {
            if (hasSaved) {
              _showBeatInfoDialog(date, savedBeats);
            } else {
              _showNoBeatDialog(date);
            }
            return;
          }

          if (hasSaved) {
            _showBeatInfoDialog(date, savedBeats);
            return;
          }

          if (isSaved) return;

          setState(() {
            selectedDate = date;
          });

          _openBeatDialog(
            date,
            initialBeat: _resolveInitialBeat(displayBeats),
            allowRemoveOption: hasPending && !hasSaved,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: hasSaved
                  ? Colors.green.shade300
                  : ((isSelected || hasPending) && !isSaved)
                      ? Colors.orange.shade700
                      : Colors.grey.shade300,
              width: hasSaved ? 1.0 : 0.5,
            ),
            gradient: hasSaved
                ? LinearGradient(
                    colors: [Colors.green.shade50, Colors.green.shade100],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : ((isSelected || hasPending) && !isSaved)
                    ? LinearGradient(
                        colors: [
                          Colors.orange.shade400,
                          Colors.orange.shade600
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : isToday
                        ? LinearGradient(
                            colors: [Colors.blue.shade50, Colors.blue.shade100],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
            color: !isSelected && !isToday && !hasSaved && !hasPending
                ? Colors.transparent
                : null,
            borderRadius: BorderRadius.circular(0),
            boxShadow: hasSaved
                ? [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.15),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    )
                  ]
                : [],
          ),
          padding: EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${date.day}",
                style: TextStyle(
                  fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                  color: Colors.black87,
                  fontSize: 14,
                ),
              ),
              Spacer(),
              if (displayBeats.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(
                    top: 4.0,
                    bottom: 4,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: EdgeInsets.only(right: 6, top: 2),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: hasSaved
                              ? Colors.green.shade700
                              : Colors.orange.shade200,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          displayBeats.map((b) => b.beatName).join(', '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            height: 1.1,
                            fontWeight: FontWeight.w500,
                            color: hasSaved
                                ? Colors.green.shade900
                                : Colors.brown.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  /// Build month grid (weeks)
  List<List<DateTime?>> _buildMonthMatrix(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    int startOffset = firstDay.weekday % 7; // Sunday = 0
    int totalDays = lastDay.day;

    List<DateTime?> allDays = [];

    // leading empty cells
    for (int i = 0; i < startOffset; i++) {
      allDays.add(null);
    }

    // actual days
    for (int i = 1; i <= totalDays; i++) {
      allDays.add(DateTime(month.year, month.month, i));
    }

    // trailing empty cells to complete weeks
    while (allDays.length % 7 != 0) {
      allDays.add(null);
    }

    // split into weeks
    List<List<DateTime?>> weeks = [];
    for (int i = 0; i < allDays.length; i += 7) {
      weeks.add(allDays.sublist(i, i + 7));
    }

    return weeks;
  }

  bool _isSameDate(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Beat? _resolveInitialBeat(List<BeatScheduler> dateBeats) {
    if (dateBeats.isEmpty) return null;

    final first = dateBeats.first;
    for (final beat in beatController.beats) {
      if (beat.beatCd == first.beatCd) {
        return beat;
      }
    }

    return Beat(
      id: first.id,
      beatCd: first.beatCd,
      beatName: first.beatName,
      userCd: first.userCd,
    );
  }

  Future<void> _openBeatDialog(
    DateTime date, {
    Beat? initialBeat,
    bool allowRemoveOption = false,
  }) async {
    // if (beatController.beats.isEmpty) {
    //   await beatController.fetchBeatsWithUserCd();
    // }

    final result = await showModalBottomSheet<BeatSelectionResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BeatSelectionSheet(
        selectedDate: date,
        // userNameByCode: _userNameByCode,
        initialSelectedBeat: initialBeat,
        allowRemoveOption: allowRemoveOption,
      ),
    );

    if (result == null) return;

    try {
      if (result.remove) {
        beatController.removePendingBeatForDate(date);
        return;
      }

      final selected = result.beat;
      if (selected == null) return;

      final profileProvider =
          Provider.of<ProfileProvider>(context, listen: false);
      final userCd = profileProvider.userCode ?? '';
      beatController.addBeatForDate(date, selected, userCd);
    } catch (e) {
      print('[BeatListView] Error adding beat for date: $e');
    }
  }

  Future<void> _showBeatInfoDialog(DateTime date, List beats) async {
    final routeLabelPlural =
        RouteLabelHelper.pluralPlanner(context.read<ProfileProvider>());

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text('Assigned ${routeLabelPlural.toLowerCase()}'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: beats.length,
              itemBuilder: (_, idx) {
                final b = beats[idx];
                return ListTile(
                  title: Text(b.beatName ?? b.beatCd ?? ''),
                  subtitle: Text(b.beatCd ?? ''),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            )
          ],
          backgroundColor: Colors.white,
        );
      },
    );
  }

  Future<void> _showNoBeatDialog(DateTime date) async {
    final routeLabel =
        RouteLabelHelper.singularPlanner(context.read<ProfileProvider>());

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text('No $routeLabel'),
          content: Text('No $routeLabel assigned on this date.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(foregroundColor: Color(0xFF1C4FBA)),
              child: Text('OK'),
            )
          ],
        );
      },
    );
  }

  Future<void> _onSavePressed() async {
    // confirm before saving
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Confirm Save'),
        content: Text(
            'Are you sure you want to save the selected ${RouteLabelHelper.pluralPlanner(context.read<ProfileProvider>()).toLowerCase()}? You cannot change them later. Save Changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Yes'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    try {
      // show loading using root navigator
      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (_) => Center(child: CircularProgressIndicator()),
      );

      final profileProvider =
          Provider.of<ProfileProvider>(context, listen: false);
      final userCd = profileProvider.userCode ?? '';

      final ok = await beatController.saveBeatSchedule(userCd);

      // close loading
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (!mounted) return;

      if (ok) {
        setState(() {
          isSaved = true;
        });
        AppSnackBar.showGetXCustomSnackBar(
          message:
              '${RouteLabelHelper.pluralPlanner(context.read<ProfileProvider>())} saved successfully',
          backgroundColor: Colors.green,
        );
      } else {
        AppSnackBar.showGetXCustomSnackBar(
          message:
              'Failed to save ${RouteLabelHelper.pluralPlanner(context.read<ProfileProvider>()).toLowerCase()}',
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      try {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      } catch (_) {}
      if (mounted) {
        AppSnackBar.showGetXCustomSnackBar(
          message:
              'Error saving ${RouteLabelHelper.pluralPlanner(context.read<ProfileProvider>()).toLowerCase()}: $e',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  String _monthName(int m) {
    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December"
    ];
    return months[m - 1];
  }

  Widget _buildCalendarHeader() {
    final isCurrent = _isCurrentMonth(currentMonth);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: Icon(Icons.chevron_left),
          onPressed: () {
            setState(() {
              currentMonth =
                  DateTime(currentMonth.year, currentMonth.month - 1);
            });
          },
        ),
        Text(
          "${_monthName(currentMonth.month)} ${currentMonth.year}",
          style: TextStyle(
            fontSize: 20,
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.chevron_right,
            color: _isCurrentMonth(currentMonth) ? Colors.grey : Colors.black,
          ),
          onPressed: () {
            if (_isCurrentMonth(currentMonth)) return;

            setState(() {
              currentMonth =
                  DateTime(currentMonth.year, currentMonth.month + 1);
            });
          },
        ),
      ],
    );
  }
}
