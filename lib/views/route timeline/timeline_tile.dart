import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Mapping config matching the React META structure
class TimelineMeta {
  final IconData icon;
  final Color color;
  final String label;

  const TimelineMeta({
    required this.icon,
    required this.color,
    required this.label,
  });
}

class TimelineTile extends StatefulWidget {
  final Map<String, dynamic> event;
  final bool isLast;
  final Function(Map<String, dynamic>) onViewItems;
  final Function(Map<String, dynamic>) onViewHistory;

  const TimelineTile({
    super.key,
    required this.event,
    required this.isLast,
    required this.onViewItems,
    required this.onViewHistory,
  });

  @override
  State<TimelineTile> createState() => _TimelineTileState();
}

class _TimelineTileState extends State<TimelineTile> {
  bool _isHovered = false;

  /// String canonicalization helper mimicking React's normalize logic
  String _normalize(String raw) {
    final s = raw.toLowerCase().replaceAll(RegExp(r'[\s\-]+'), '_').trim();
    if (s.contains('order_start') || s.contains('check_in'))
      return 'order_start';
    if (s.contains('order_end') || s.contains('check_out')) return 'order_end';
    if (s.contains('order_place') || s.contains('order_placed'))
      return 'order_placed';
    if (s.contains('waiting') || s.contains('wait_stop')) return 'waiting';
    if (s.contains('offline_end') ||
        s.contains('offline_ended') ||
        s.contains('online_start') ||
        s.contains('online_started') ||
        s == 'offline_ended' ||
        s.contains('connectivity_restore') ||
        s.contains('network_online') ||
        s.contains('device_online') ||
        s.contains('online_restored')) return 'online';
    if (s.contains('offline') ||
        s.contains('connectivity_lost') ||
        s.contains('network_offline') ||
        s.contains('device_offline')) return 'offline';
    if (s.contains('trip_start') || s.contains('trip_started'))
      return 'trip_start';
    if (s.contains('trip_end') || s.contains('trip_complet')) return 'trip_end';
    return s;
  }

  /// Parses backend durations, discarding zero-hour roots and tracking seconds
  String _smartFormatDuration(String raw) {
    final s = raw.trim();
    if (s.isEmpty || s == '-') return '';
    final regex = RegExp(r'(?:(\d+)h\s*)?(\d+)m');
    final match = regex.firstMatch(s);
    if (match != null) {
      final hoursStr = match.group(1);
      final minutesStr = match.group(2);
      if (hoursStr != null) {
        final h = int.tryParse(hoursStr) ?? 0;
        final m = int.tryParse(minutesStr!) ?? 0;
        return h > 0 ? '${h}h ${m}m' : '${m}m';
      } else if (minutesStr != null) {
        return '${int.tryParse(minutesStr)}m';
      }
    }
    return s.replaceAll(RegExp(r'\s*\d+s\s*$'), '').trim();
  }

  /// React noise filters
  bool _isNoiseNote(String n) {
    final low = n.toLowerCase();
    final noiseNotes = [
      "trip session started",
      "trip session completed",
      "device/network went offline",
      "connectivity restored",
      "offline started",
      "offline ended",
      "online restored"
    ];
    if (noiseNotes.any((x) => low.contains(x))) return true;
    if (RegExp(r'^(in|out)\s*[•·]\s*.+$', caseSensitive: false).hasMatch(low))
      return true;
    if (RegExp(r'^order\s+placed\s*\(', caseSensitive: false).hasMatch(low))
      return true;
    return false;
  }

  Map<String, TimelineMeta> _getMetaMap() {
    return {
      'order_start': const TimelineMeta(
          icon: Icons.login, color: Color(0xFF10B981), label: 'Check-In'),
      'order_end': const TimelineMeta(
          icon: Icons.logout, color: Color(0xFFEF4444), label: 'Check-Out'),
      'order_placed': const TimelineMeta(
          icon: Icons.shopping_cart,
          color: Color(0xFF3B82F6),
          label: 'Order Placed'),
      'waiting': const TimelineMeta(
          icon: Icons.access_time, color: Color(0xFFF97316), label: 'Waiting'),
      'trip_start': const TimelineMeta(
          icon: Icons.play_arrow,
          color: Color(0xFF6366F1),
          label: 'Trip Started'),
      'trip_end': const TimelineMeta(
          icon: Icons.check_circle_outline,
          color: Color(0xFF6366F1),
          label: 'Trip Completed'),
      'offline': const TimelineMeta(
          icon: Icons.wifi_off,
          color: Color(0xFF64748B),
          label: 'Connection Lost'),
      'online': const TimelineMeta(
          icon: Icons.wifi,
          color: Color(0xFF22D3EE),
          label: 'Connection Restored'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    // Resolve Canonical types
    final canonicalA = _normalize(widget.event['event_type']?.toString() ?? '');
    final canonicalB = _normalize(widget.event['title']?.toString() ?? '');
    final metaMap = _getMetaMap();
    final canonical = metaMap.containsKey(canonicalA)
        ? canonicalA
        : (metaMap.containsKey(canonicalB) ? canonicalB : canonicalA);

    final isOrderStart = canonical == 'order_start';
    final isOrderEnd = canonical == 'order_end';
    final isOrderPlaced = canonical == 'order_placed';
    final isWaiting = canonical == 'waiting';

    // Durations
    final endDuration =
        _smartFormatDuration(widget.event['endDuration']?.toString() ?? '');
    final waitingDurationRaw =
        widget.event['waitingDuration']?.toString() ?? '';
    final waitingDuration = _smartFormatDuration(waitingDurationRaw).isNotEmpty
        ? _smartFormatDuration(waitingDurationRaw)
        : waitingDurationRaw;

    // Amount Calculations
    final orderAmountValue =
        double.tryParse(widget.event['order_amount']?.toString() ?? '') ?? 0.0;
    final isZeroAmount = isOrderPlaced && orderAmountValue <= 0;
    final isPositiveAmount = isOrderPlaced && orderAmountValue > 0;

    String orderAmountDisplay = '';
    if (isOrderPlaced) {
      orderAmountDisplay = NumberFormat.currency(locale: 'en_IN', symbol: '')
          .format(orderAmountValue);
    }

    // Color tokens matching React styles
    final textPrimary =
        isDarkTheme ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textAddress =
        isDarkTheme ? const Color(0xFFCED2D8) : const Color(0xFF1E293B);
    final textSecondary =
        isDarkTheme ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final textMuted =
        isDarkTheme ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    final borderColor = isDarkTheme
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.06);
    final dividerColor = isDarkTheme
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.04);
    final cardBg =
        isDarkTheme ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);

    final meta = metaMap[canonical] ??
        TimelineMeta(
            icon: Icons.fiber_manual_record,
            color:
                isDarkTheme ? const Color(0xFF475569) : const Color(0xFF94A3B8),
            label: '');

    final dotColor = meta.color;
    final dotBg =
        dotColor.withOpacity(0.09); // Corresponds to hex code opacity + "18"

    final inOutColor =
        isOrderStart ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    final partyName = widget.event['party_name']?.toString() ?? '';
    final mainLabel = partyName.isNotEmpty
        ? partyName
        : (meta.label.isNotEmpty
            ? meta.label
            : (widget.event['title'] ?? widget.event['event_type'] ?? '')
                .toString()
                .trim());

    final noteText = widget.event['note']?.toString() ?? '';
    final partyAddress = widget.event['party_address']?.toString() ?? '';
    final addressText =
        partyAddress.isNotEmpty ? partyAddress : (isWaiting ? noteText : '');
    final showNote = noteText.isNotEmpty &&
        !_isNoiseNote(noteText) &&
        (!isWaiting || partyAddress.isNotEmpty);

    final isOrderClickable = isOrderPlaced;
    final canOpenHistory = isOrderPlaced &&
        (partyName.isNotEmpty ||
            (widget.event['party_code']?.toString() ?? '').isNotEmpty);
    final hasFooter = (isOrderPlaced && orderAmountDisplay.isNotEmpty) ||
        isOrderClickable ||
        canOpenHistory;

    // Scale sizing metrics from React spine sizing tokens
    const double dotSize = 25.0;
    const double lineW = 1.7;

    // Date & Time extraction from string
    final timestamp = widget.event['timestamp']?.toString() ?? '';
    String datePart = '';
    String timePart = '';
    if (timestamp.isNotEmpty) {
      try {
        final dt = DateTime.parse(timestamp).toLocal();
        datePart = DateFormat('dd MMM yyyy').format(dt);
        timePart = DateFormat('hh:mm a').format(dt);
      } catch (_) {}
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Spine Column
            SizedBox(
              width: dotSize,
              child: Column(
                children: [
                  Container(
                    width: dotSize,
                    height: dotSize,
                    decoration: BoxDecoration(
                      color: dotBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: dotColor, width: 1.5),
                    ),
                    child: Center(
                      child: Icon(meta.icon, size: 14, color: dotColor),
                    ),
                  ),
                  if (!widget.isLast)
                    Expanded(
                      child: Container(
                        width: lineW,
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        decoration: BoxDecoration(
                          color: isDarkTheme
                              ? Colors.white.withOpacity(0.10)
                              : Colors.black.withOpacity(0.09),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Card Content Panel
            Expanded(
              child: Container(
                margin: EdgeInsets.only(bottom: widget.isLast ? 0 : 8),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _isHovered && isOrderClickable
                          ? dotColor.withOpacity(0.18)
                          : borderColor,
                      width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(
                          _isHovered && isOrderClickable ? 0.35 : 0.22),
                      blurRadius: _isHovered && isOrderClickable ? 12 : 5,
                      offset: Offset(0, _isHovered && isOrderClickable ? 4 : 2),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Header row
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                mainLabel,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                  letterSpacing: 0.15,
                                ),
                              ),
                              if (isWaiting && waitingDuration.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF97316)
                                        .withOpacity(0.07),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Duration : $waitingDuration',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFF97316)),
                                  ),
                                ),
                              if (isOrderEnd && endDuration.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444)
                                        .withOpacity(0.07),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Duration : $endDuration',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFEF4444)),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          // Address Details
                          if (addressText.isNotEmpty) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 1.0),
                                  child: Icon(Icons.location_on,
                                      size: 11, color: textSecondary),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    addressText,
                                    style: TextStyle(
                                        fontSize: 10.5,
                                        color: textAddress,
                                        height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                          ],
                          // Meta Timestamps Section
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                // IN/OUT Badge
                                if (isOrderStart || isOrderEnd)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.fiber_manual_record,
                                          size: 8, color: inOutColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        isOrderStart ? "IN" : "OUT",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: inOutColor,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ],
                                  ),

                                // Timestamp Data Details
                                if (timestamp.isNotEmpty) ...[
                                  // Calendar block
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.calendar_today,
                                          size: 11, color: textSecondary),
                                      const SizedBox(width: 4),
                                      Text(
                                        datePart,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Clock block
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.access_time,
                                          size: 13, color: textSecondary),
                                      const SizedBox(width: 4),
                                      Text(
                                        timePart,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.access_time,
                                          size: 11, color: textMuted),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Not recorded',
                                        style: TextStyle(
                                            fontSize: 12, color: textMuted),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          // Optional Notes
                          if (showNote) ...[
                            const SizedBox(height: 4),
                            Text(
                              '"$noteText"',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: textSecondary,
                                  fontStyle: FontStyle.italic,
                                  height: 1.45),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Action Footer Row
                    if (hasFooter) ...[
                      Container(
                        decoration: BoxDecoration(
                          border: Border(
                              top: BorderSide(color: dividerColor, width: 1)),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (isOrderPlaced &&
                                    orderAmountDisplay.isNotEmpty)
                                  RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: textSecondary),
                                      children: [
                                        const TextSpan(text: 'Amount: '),
                                        TextSpan(
                                          text: '₹',
                                          style: TextStyle(
                                            color: isPositiveAmount
                                                ? const Color(0xFF10B981)
                                                : const Color(0xFFEF4444),
                                          ),
                                        ),
                                        TextSpan(
                                          text: orderAmountDisplay,
                                          style: TextStyle(
                                            color: isPositiveAmount
                                                ? const Color(0xFF10B981)
                                                : const Color(0xFFEF4444),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  const SizedBox.shrink(),
                                // Row(
                                //   children: [
                                //     if (isOrderClickable)
                                //       TextButton.icon(
                                //         style: TextButton.styleFrom(
                                //           padding: const EdgeInsets.symmetric(
                                //               horizontal: 5),
                                //           minimumSize: Size.zero,
                                //           tapTargetSize:
                                //               MaterialTapTargetSize.shrinkWrap,
                                //         ),
                                //         onPressed: () =>
                                //             widget.onViewItems(widget.event),
                                //         icon: const Icon(Icons.inventory_2_outlined,
                                //             size: 12, color: Color(0xFF3B82F6)),
                                //         label: const Text(
                                //           'View items',
                                //           style: TextStyle(
                                //               fontSize: 12,
                                //               color: Color(0xFF3B82F6),
                                //               fontWeight: FontWeight.w600),
                                //         ),
                                //       ),
                                //     if (canOpenHistory) ...[
                                //       const SizedBox(width: 8),
                                //       TextButton.icon(
                                //         style: TextButton.styleFrom(
                                //           padding: EdgeInsets.zero,
                                //           minimumSize: Size.zero,
                                //           tapTargetSize:
                                //               MaterialTapTargetSize.shrinkWrap,
                                //         ),
                                //         onPressed: () =>
                                //             widget.onViewHistory(widget.event),
                                //         icon: const Icon(Icons.history,
                                //             size: 12, color: Color(0xFF8B5CF6)),
                                //         label: const Text(
                                //           'History',
                                //           style: TextStyle(
                                //               fontSize: 12,
                                //               color: Color(0xFF8B5CF6),
                                //               fontWeight: FontWeight.w600),
                                //         ),
                                //       ),
                                //     ],
                                //   ],
                                // ),
                              ],
                            ),
                            SizedBox(
                              height: 3,
                            ),
                            Row(
                              children: [
                                if (isOrderClickable)
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.only(right: 5),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () =>
                                        widget.onViewItems(widget.event),
                                    icon: const Icon(Icons.inventory_2_outlined,
                                        size: 12, color: Color(0xFF3B82F6)),
                                    label: const Text(
                                      'View items',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF3B82F6),
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                if (canOpenHistory) ...[
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () =>
                                        widget.onViewHistory(widget.event),
                                    icon: const Icon(Icons.history,
                                        size: 12, color: Color(0xFF8B5CF6)),
                                    label: const Text(
                                      'History',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF8B5CF6),
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
