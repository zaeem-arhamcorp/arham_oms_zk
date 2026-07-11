import 'package:arham_corporation/helper/route_label_helper.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../controllers/beat_controller.dart';
import '../models/beat_model.dart';

class BeatSelectionResult {
  final Beat? beat;
  final bool remove;

  const BeatSelectionResult.select(this.beat) : remove = false;
  const BeatSelectionResult.remove()
      : beat = null,
        remove = true;
}

class BeatSelectionSheet extends StatefulWidget {
  final DateTime selectedDate;
  final Map<String, String>? userNameByCode;
  final Beat? initialSelectedBeat;
  final bool allowRemoveOption;

  const BeatSelectionSheet({
    required this.selectedDate,
    this.userNameByCode,
    this.initialSelectedBeat,
    this.allowRemoveOption = false,
    super.key,
  });

  @override
  State<BeatSelectionSheet> createState() => _BeatSelectionSheetState();
}

class _BeatSelectionSheetState extends State<BeatSelectionSheet> {
  final TextEditingController _controller = TextEditingController();
  late BeatController beatController;
  bool isLoading = true;

  List<Beat> filteredBeats = [];
  Beat? selectedBeat;

  @override
  void initState() {
    super.initState();
    beatController = Get.isRegistered<BeatController>()
        ? Get.find<BeatController>()
        : Get.put(BeatController());

    _loadBeats();
  }

  Future<void> _loadBeats() async {
    print('Before API: ${beatController.beats.length}');
    await beatController.fetchBeatsWithUserCd();
    print('After API: ${beatController.beats.length}');

    if (!mounted) return;

    setState(() {
      // Initialize with all beats from controller
      filteredBeats = List.from(beatController.beats);
      print('Beat count on sheet open: ${beatController.beats.length}');

      if (widget.initialSelectedBeat != null) {
        selectedBeat = widget.initialSelectedBeat;
        _controller.text = widget.initialSelectedBeat!.beatName;
        filteredBeats = [widget.initialSelectedBeat!];
      }

      isLoading = false;
    });

    print('Beat count after API: ${beatController.beats.length}');
  }

  void _filter(String value) {
    setState(() {
      filteredBeats = beatController.beats
          .where((b) =>
              b.beatCd.toLowerCase().contains(value.toLowerCase()) ||
              b.beatName.toLowerCase().contains(value.toLowerCase()))
          .toList();
    });
  }

  void _clear() {
    _controller.clear();
    _filter('');
    setState(() {
      selectedBeat = null;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final routeLabel =
        RouteLabelHelper.singularPlanner(context.read<ProfileProvider>());
    final routeLabelPlural =
        RouteLabelHelper.pluralPlanner(context.read<ProfileProvider>());

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// 🔘 Drag Handle
            Container(
              height: 4,
              width: 40,
              margin: EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  "Select a $routeLabel",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            SizedBox(
              height: 10,
            ),

            /// 🔍 Search Field
            TextField(
              controller: _controller,
              onChanged: _filter,
              decoration: InputDecoration(
                hintText: "Search $routeLabel",
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () {
                          _clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(),
              ),
            ),

            SizedBox(height: 10),

            /// 📋 Dropdown List
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: isLoading == true
                  ? Center(
                      child: CircularProgressIndicator(),
                    )
                  : filteredBeats.isEmpty
                      ? Center(
                          child: Text(
                              "No ${routeLabelPlural.toLowerCase()} found"))
                      : ListView.builder(
                          itemCount: filteredBeats.length,
                          itemBuilder: (context, index) {
                            final beat = filteredBeats[index];
                            final userName =
                                widget.userNameByCode?[beat.userCd] ?? '';
                            final displayTitle = userName.isNotEmpty
                                ? "${beat.beatName} - $userName"
                                : beat.beatName;

                            return ListTile(
                              title: Text(displayTitle),
                              // subtitle:
                              //     beat.userCd.isNotEmpty && userName.isEmpty
                              //         ? Text('Assigned user: ${beat.userCd}')
                              //         : null,
                              onTap: () {
                                setState(() {
                                  selectedBeat = beat;
                                  _controller.text = beat.beatName;
                                  filteredBeats = [beat];
                                });
                              },
                            );
                          },
                        ),
            ),

            SizedBox(height: 16),

            /// 🔘 Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text("Cancel"),
                  ),
                ),
                if (widget.allowRemoveOption) ...[
                  SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(
                            context, const BeatSelectionResult.remove());
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: Text("Remove"),
                    ),
                  ),
                ],
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: selectedBeat == null
                        ? null
                        : () {
                            print(
                                "Selected Beat: ${selectedBeat!.beatCd} - ${selectedBeat!.beatName}");
                            Navigator.pop(context,
                                BeatSelectionResult.select(selectedBeat));
                          },
                    child: Text(
                        widget.initialSelectedBeat == null ? "Add" : "Update"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
