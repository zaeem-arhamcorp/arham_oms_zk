import 'package:arham_corporation/services/battery_optimization_service.dart';
import 'package:flutter/material.dart';

class BatteryOptimizationDialog extends StatelessWidget {
  const BatteryOptimizationDialog({super.key});

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
            Icon(Icons.battery_charging_full, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Battery Optimization Enabled',
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
              'We detected that battery optimization is enabled for this app. This may prevent location tracking and background services from working properly.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Instructions to disable:',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                        ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Tap "Open Settings" button below\n2. Select "Allow" or "Don\'t optimize"\n3. Your location tracking will work better',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.orange.shade900,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          //TODO: REMOVE 'CANCEL' BUTTON BEFORE PRODUCTION BUILD
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text("Cancel"),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await BatteryOptimizationService
                  .openBatteryOptimizationSettings();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            icon: Icon(Icons.settings),
            label: Text('Open Settings'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
