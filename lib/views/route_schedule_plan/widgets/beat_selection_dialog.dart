import 'package:flutter/material.dart';

class BeatSelectionDialog extends StatefulWidget {
  @override
  State<BeatSelectionDialog> createState() => _BeatSelectionDialogState();
}

class _BeatSelectionDialogState extends State<BeatSelectionDialog> {
  final TextEditingController _controller = TextEditingController();

  final List<String> allBeats = [
    "Navrangpura",
    "Maninagar",
    "Satellite",
    "Bopal",
    "CG Road",
    "Vastrapur",
    "Paldi",
    "Gota",
  ];

  List<String> filteredBeats = [];
  String? selectedBeat;

  @override
  void initState() {
    super.initState();
    filteredBeats = List.from(allBeats);
  }

  void _filter(String value) {
    setState(() {
      filteredBeats = allBeats
          .where((beat) => beat.toLowerCase().contains(value.toLowerCase()))
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
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: filteredBeats.isEmpty
                  ? Center(child: Text("No results"))
                  : ListView.builder(
                      itemCount: filteredBeats.length,
                      itemBuilder: (context, index) {
                        final beat = filteredBeats[index];
                        return ListTile(
                          title: Text(beat),
                          onTap: () {
                            setState(() {
                              selectedBeat = beat;
                              _controller.text = beat;
                              filteredBeats = [beat];
                            });
                          },
                        );
                      },
                    ),
            ),

            SizedBox(height: 15),

            /// ➕ Add Button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text("Cancel"),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: selectedBeat == null
                      ? null
                      : () {
                          print("Selected Beat: $selectedBeat");
                          Navigator.pop(context);
                        },
                  child: Text("Add"),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
