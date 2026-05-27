// import 'package:arham_corporation/services/location_permission_service.dart';
// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
//
// class LocationPermissionDialog extends StatelessWidget {
//   const LocationPermissionDialog({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return WillPopScope(
//       onWillPop: () async => false, // Prevent back button from dismissing
//       child: AlertDialog(
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(12),
//         ),
//         title: Row(
//           children: [
//             Icon(Icons.location_on, color: Colors.blue, size: 28),
//             SizedBox(width: 12),
//             Expanded(
//               child: Text(
//                 'Location Permission Required',
//                 style: Theme.of(context).textTheme.titleLarge?.copyWith(
//                       fontWeight: FontWeight.bold,
//                     ),
//               ),
//             ),
//           ],
//         ),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'ArhamOMS collects location data to enable live tracking of field employees, even when the app is closed or not in use. This helps businesses monitor field activity, verify visits, and optimize routes during working hours.',
//               style: Theme.of(context).textTheme.bodyMedium,
//             ),
//             SizedBox(height: 5),
//             Text(
//               'Background location tracking requires "Allow all the time" permission. This ensures location is captured in an active trip even when the app is not actively used.',
//               style: Theme.of(context).textTheme.bodyMedium,
//             ),
//             SizedBox(height: 5),
//             Text(
//                 'Disclosure: Tracking runs only during working hours and can be controlled by the user.'),
//             SizedBox(height: 16),
//             Container(
//               padding: EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: Colors.blue.shade50,
//                 borderRadius: BorderRadius.circular(8),
//                 border: Border.all(color: Colors.blue.shade200),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'Instructions to enable:',
//                     style: Theme.of(context).textTheme.labelLarge?.copyWith(
//                           fontWeight: FontWeight.bold,
//                           color: Colors.blue.shade900,
//                         ),
//                   ),
//                   SizedBox(height: 8),
//                   Text(
//                     '1. Tap "Allow All the Time" button below\n2 Select "Arham OMS"\n3. Select "Allow all the time" option\n\nLocation tracking will work in background',
//                     style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                           color: Colors.blue.shade900,
//                         ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//         actions: [
//           ElevatedButton.icon(
//             onPressed: () async {
//               final permission =
//                   await LocationPermissionService.requestLocationPermission();
//
//               // If still not "always", open settings
//               if (permission != LocationPermission.always) {
//                 await LocationPermissionService.openLocationSettings();
//               } else {
//                 // Only mark as shown if permission was actually granted
//                 await LocationPermissionService.markDialogShown();
//               }
//
//               if (context.mounted) {
//                 Navigator.pop(context);
//               }
//             },
//             icon: Icon(Icons.location_on),
//             label: Text('Allow All the Time'),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.blue,
//               foregroundColor: Colors.white,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

import 'package:arham_corporation/services/location_permission_service.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationPermissionDialog extends StatelessWidget {
  const LocationPermissionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Dialog(
        insetPadding: const EdgeInsets.all(0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ListView(
            children: [
              // Header with gradient
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Location Permission Required',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main description
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.blue.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'ArhamOMS needs location access to track field employees during work hours.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue.shade900,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Purpose section
                    _buildSectionTitle(Icons.work_outline, 'Why we need this'),
                    const SizedBox(height: 4),
                    Text(
                      '• Track live location of field employees\n'
                      '• Verify customer visits and check-ins\n'
                      '• Optimize delivery routes\n'
                      '• Monitor field activity during working hours',
                      style: const TextStyle(fontSize: 13, height: 1.5),
                    ),
                    const SizedBox(height: 16),

                    // Background location explanation
                    _buildSectionTitle(
                        Icons.settings_backup_restore, 'Background Location'),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.timer_outlined,
                              color: Colors.orange.shade700, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '"Allow all the time" permission ensures location is captured even when the app is closed - required for trip tracking.',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Privacy disclosure - CRITICAL for Play Store
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.privacy_tip,
                                  color: Colors.green.shade700, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'Privacy Disclosure',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '✓ Location tracking runs only during working hours\n'
                            '✓ You can disable tracking anytime in app settings\n'
                            '✓ Location data is used only for business operations\n'
                            '✓ No tracking outside working hours',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Instructions
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.help_outline,
                                  color: Colors.blue.shade700, size: 18),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'How to enable (one-time setup)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildInstructionStep(
                              '1', 'Tap "Allow All the Time" below'),
                          _buildInstructionStep(
                              '2', 'Select "Arham OMS" from the list'),
                          _buildInstructionStep(
                              '3', 'Choose "Allow all the time"'),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle,
                                    size: 12, color: Colors.blue.shade800),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'After setup, location will work in background',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.blue.shade800),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Actions
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text(
                        'Not Now',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                        ),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final permission = await LocationPermissionService
                              .requestLocationPermission();

                          if (permission != LocationPermission.always) {
                            await LocationPermissionService
                                .openLocationSettings();
                          } else {
                            await LocationPermissionService.markDialogShown();
                          }

                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                        icon: const Icon(Icons.location_on, size: 18),
                        label: const Text(
                          'Allow All the Time',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E88E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }
}
