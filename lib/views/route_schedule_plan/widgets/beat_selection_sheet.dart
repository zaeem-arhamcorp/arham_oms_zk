import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../route_schedule_plan/controllers/beat_controller.dart';
import '../../../route_schedule_plan/models/beat_model.dart';

class BeatSelectionSheet extends StatefulWidget {
  final DateTime selectedDate;

  const BeatSelectionSheet({required this.selectedDate, super.key});

  @override
  State<BeatSelectionSheet> createState() => _BeatSelectionSheetState();
}

class _BeatSelectionSheetState extends State<BeatSelectionSheet> {
  final TextEditingController _controller = TextEditingController();
  late BeatController beatController;

  List<Beat> filteredBeats = [];
  Beat? selectedBeat;

  @override
  void initState() {
    super.initState();
    beatController = Get.isRegistered<BeatController>()
        ? Get.find<BeatController>()
        : Get.put(BeatController());

    // Initialize with all beats from controller
    filteredBeats = List.from(beatController.beats);
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
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

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
                  "Select a Beat",
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
                hintText: "Search Beat",
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
              child: filteredBeats.isEmpty
                  ? Center(child: Text("No results"))
                  : ListView.builder(
                      itemCount: filteredBeats.length,
                      itemBuilder: (context, index) {
                        final beat = filteredBeats[index];

                        return ListTile(
                          title: Text("${beat.beatCd} - ${beat.beatName}"),
                          onTap: () {
                            setState(() {
                              selectedBeat = beat;
                              _controller.text = beat.beatCd;
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
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: selectedBeat == null
                        ? null
                        : () {
                            print(
                                "Selected Beat: ${selectedBeat!.beatCd} - ${selectedBeat!.beatName}");
                            Navigator.pop(context, selectedBeat);
                          },
                    child: Text("Add"),
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
