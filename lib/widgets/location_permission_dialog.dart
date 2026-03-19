import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:arham_corporation/services/location_permission_service.dart';

class LocationPermissionDialog extends StatelessWidget {
  const LocationPermissionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button from dismissing
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Row(
          children: [
            Icon(Icons.location_on, color: Colors.blue, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Location Permission Required',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Background location tracking requires "Allow all the time" permission. This ensures location is captured even when the app is not actively used.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Instructions to enable:',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Tap "Allow All the Time" button below\n2 Select "Arham OMS"\n3. Select "Allow all the time" option\n\nLocation tracking will work in background',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.blue.shade900,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () async {
              final permission =
                  await LocationPermissionService.requestLocationPermission();

              // If still not "always", open settings
              if (permission != LocationPermission.always) {
                await LocationPermissionService.openLocationSettings();
              } else {
                // Only mark as shown if permission was actually granted
                await LocationPermissionService.markDialogShown();
              }

              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            icon: Icon(Icons.location_on),
            label: Text('Allow All the Time'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
