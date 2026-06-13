import 'dart:convert';

import 'package:arham_corporation/config/app_config.dart';
import 'package:arham_corporation/product/widget/app_snack_bar.dart';
import 'package:arham_corporation/providers/profile_provider.dart';
import 'package:arham_corporation/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

// Model to represent a single Trip
class Trip {
  final int tripId;
  final String status;
  final String startTime;
  final String endTime;
  final bool isActive;
  final int pointCount;

  Trip({
    required this.tripId,
    required this.status,
    required this.startTime,
    required this.endTime,
    required this.isActive,
    required this.pointCount,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      tripId: json['TRIP_ID'] ?? 0,
      status: json['STATUS'] ?? 'unknown',
      startTime: json['START_TIME'] ?? '',
      endTime: json['END_TIME'] ?? '',
      isActive: json['IS_ACTIVE'] ?? false,
      pointCount: json['POINT_COUNT'] ?? 0,
    );
  }
}

class TripSummaryScreen extends StatefulWidget {
  const TripSummaryScreen({super.key});

  @override
  State<TripSummaryScreen> createState() => _TripSummaryScreenState();
}

class _TripSummaryScreenState extends State<TripSummaryScreen> {
  List<Trip> trips = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchTrips();
  }

  Future<void> fetchTrips() async {
    // 1. Get providers
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    // 2. Debug: Print the URL to your console to verify it in Postman
    final url =
        '${AppConfig.baseURL}location/trip?user_cd=${profileProvider.userCode}';
    print('[DEBUG] Requesting URL: $url');
    print('[DEBUG] Token: ${userProvider.token}');

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer ${userProvider.token}',
          'x-app-type':
              'oms', // Ensure these headers match your working service
          'Content-Type': 'application/json',
        },
      );

      print('[DEBUG] Response Code: ${response.statusCode}');
      print('[DEBUG] Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final body = json.decode(response.body);

        // Ensure 'data' and 'trips' exist before accessing
        if (body['data'] != null && body['data']['trips'] is List) {
          final List<dynamic> tripList = body['data']['trips'];
          setState(() {
            trips = tripList.map((t) => Trip.fromJson(t)).toList();
            isLoading = false;
          });
        } else {
          print('[DEBUG] Unexpected JSON structure');
          setState(() => isLoading = false);
        }
      } else {
        print('[DEBUG] Server error: ${response.statusCode}');
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('[DEBUG] Exception: $e');
      setState(() => isLoading = false);
    }
  }

  // Add this method inside your _TripSummaryScreenState class
  // Future<void> _handlePunchOut(Trip trip) async {
  //   final userProvider = Provider.of<UserProvider>(context, listen: false);
  //
  //   // 1. Calculate the 11 PM logic using the same base logic as before
  //   DateTime start = DateTime.parse(trip.startTime.replaceAll(' ', 'T'));
  //   DateTime targetEnd;
  //
  //   if (start.hour >= 23) {
  //     targetEnd = DateTime(start.year, start.month, start.day + 1, 23, 0, 0);
  //   } else {
  //     targetEnd = DateTime(start.year, start.month, start.day, 23, 0, 0);
  //   }
  //
  //   // 2. Use your existing format function for the API body
  //   // Note: Assuming _formatDateTimeWithOffsetForApi takes a millisecond timestamp
  //   final formattedEndTime = _formatDateTimeWithOffsetForApi(
  //     targetEnd.millisecondsSinceEpoch,
  //   );
  //
  //   final uri = Uri.parse('${AppConfig.baseURL}location/trip/end');
  //
  //   final body = {
  //     "trip_id": trip.tripId,
  //     "sync_id": userProvider.syncId.toString(),
  //     "end_time": formattedEndTime, // Using your standard format
  //   };
  //
  //   try {
  //     print(uri);
  //     final response = await http.post(
  //       uri,
  //       headers: {
  //         'Authorization': 'Bearer ${userProvider.token}',
  //         'x-app-type': 'oms',
  //         'Content-Type': 'application/json',
  //       },
  //       body: json.encode(body),
  //     );
  //     print(body);
  //
  //     if (response.statusCode == 200) {
  //       AppSnackBar.showGetXCustomSnackBar(
  //         message: "Trip punched out successfully!",
  //         backgroundColor: Colors.green,
  //       );
  //       fetchTrips(); // Refresh the list
  //     } else {
  //       AppSnackBar.showGetXCustomSnackBar(
  //         message: "Error punching out the trip.",
  //         backgroundColor: Colors.red,
  //       );
  //       print("Error: ${response.statusCode} - ${response.body}");
  //     }
  //   } catch (e) {
  //     print("Exception: $e");
  //   }
  // }

  Future<void> _handlePunchOut(Trip trip) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    // 1. Calculate Time (Same as before)
    DateTime start = DateTime.parse(trip.startTime.replaceAll(' ', 'T'));
    DateTime targetEnd = (start.hour >= 23)
        ? DateTime(start.year, start.month, start.day + 1, 23, 0, 0)
        : DateTime(start.year, start.month, start.day, 23, 0, 0);

    final formattedEndTime =
        _formatDateTimeWithOffsetForApi(targetEnd.millisecondsSinceEpoch);

    final tripEndURL = Uri.parse('${AppConfig.baseURL}location/trip/end');

    final body = {
      "trip_id": trip.tripId,
      "sync_id": userProvider.syncId.toString(),
      "end_time": formattedEndTime,
    };

    try {
      // 2. CALL 1: Punch Out
      print(tripEndURL);
      final response = await http.post(
        tripEndURL,
        headers: {
          'Authorization': 'Bearer ${userProvider.token}',
          'x-app-type': 'oms',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );
      print(body);

      if (response.statusCode == 200) {
        // 3. CALL 2: Log Location (Only if first call succeeded)
        await _logPunchOutLocation(targetEnd);

        if (mounted) {
          AppSnackBar.showGetXCustomSnackBar(
            message: "Punch out and location logged successfully!",
            backgroundColor: Colors.green,
          );
          fetchTrips();
        }
      } else {
        print("Punch out failed: ${response.body}");
      }
    } catch (e) {
      print("Exception: $e");
    }
  }

  Future<void> _logPunchOutLocation(DateTime targetEnd) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    try {
      // Fetch Current Location
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);

      final body = {
        "lat": position.latitude,
        "long": position.longitude,
        "moduleNo": 301, // Or get this from the trip object if dynamic
        "remarks": "PUNCH OUT",
        "vouchDt":
            "${targetEnd.year}-${targetEnd.month.toString().padLeft(2, '0')}-${targetEnd.day.toString().padLeft(2, '0')}",
        "vouchTime":
            "${targetEnd.hour.toString().padLeft(2, '0')}:${targetEnd.minute.toString().padLeft(2, '0')}:${targetEnd.second.toString().padLeft(2, '0')}"
      };

      final locationURL = Uri.parse('${AppConfig.baseURL}locations');

      print(locationURL);
      print(body);

      final response = await http.post(
        locationURL,
        headers: {
          'Authorization': 'Bearer ${userProvider.token}',
          'x-app-type': 'oms',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      print("Location log response: ${response.statusCode}");
    } catch (e) {
      print("Error logging location: $e");
    }
  }

  static String _formatDateTimeWithOffsetForApi(int timestampMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs).toLocal();
    final offset = dt.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final absOffset = offset.abs();
    final offsetHours = absOffset.inHours.toString().padLeft(2, '0');
    final offsetMinutes = (absOffset.inMinutes % 60).toString().padLeft(2, '0');

    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}T${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}$sign$offsetHours:$offsetMinutes';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Trip Summary")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: trips.length,
              itemBuilder: (context, index) {
                final trip = trips[index];

                // Logic: Show button if status is NOT 'completed'
                final bool isNotCompleted =
                    trip.status.toLowerCase() != 'completed';

                bool startedToday = false;

                try {
                  final startDate =
                      DateTime.parse(trip.startTime.replaceAll(' ', 'T'));
                  final now = DateTime.now();

                  startedToday = startDate.year == now.year &&
                      startDate.month == now.month &&
                      startDate.day == now.day;
                } catch (_) {}

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Trip #${trip.tripId}",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text("Status: ${trip.status.toUpperCase()}"),
                          ],
                        ),
                        const Divider(),
                        Text("Start: ${trip.startTime}"),
                        Text("End: ${trip.endTime}"),
                        Text("Points: ${trip.pointCount}"),
                        const SizedBox(height: 10),

                        // Updated Condition and linked to _handlePunchOut
                        if (isNotCompleted && !startedToday)
                          SizedBox(
                            width:
                                double.infinity, // Makes the button full width
                            child: ElevatedButton(
                              onPressed: () => _handlePunchOut(trip),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent),
                              child: const Text("PUNCH OUT",
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
