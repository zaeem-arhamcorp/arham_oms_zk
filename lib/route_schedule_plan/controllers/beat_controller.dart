import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

import '../models/beat_model.dart';
import '../services/beat_service.dart';
import '../../providers/user_provider.dart';

class BeatController extends GetxController {
  final _beats = <Beat>[].obs;
  final _isLoading = false.obs;
  final _userBeats = <BeatScheduler>[].obs; // User-assigned beats by date
  final _beatsByDate = <String, List<BeatScheduler>>{}.obs; // Organized by date
  final _newBeatsByDate =
      <String, List<BeatScheduler>>{}.obs; // Newly added beats pending save

  List<Beat> get beats => _beats.toList();
  bool get isLoading => _isLoading.value;
  List<BeatScheduler> get userBeats => _userBeats.toList();
  Map<String, List<BeatScheduler>> get beatsByDate => _beatsByDate;
  Map<String, List<BeatScheduler>> get newBeatsByDate => _newBeatsByDate;

  final BeatService _service;

  BeatController({BeatService? service}) : _service = service ?? BeatService();

  @override
  void onInit() {
    super.onInit();
    fetchBeatsIfNeeded();
  }

  Future<void> fetchBeatsIfNeeded() async {
    if (_beats.isNotEmpty) return;
    await fetchBeats();
  }

  Future<void> fetchBeats() async {
    _isLoading.value = true;
    try {
      String? token;
      try {
        final up = Provider.of<UserProvider>(Get.context!, listen: false);
        token = up.token;
      } catch (_) {
        token = null;
      }

      final data = await _service.fetchBeats(token: token);
      final list = Beat.listFromJson(data);
      _beats.assignAll(list);
    } catch (e) {
      // ignore errors; leave list empty
      print('[BeatController] fetchBeats error: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  /// Fetch beats scheduled for a specific user and organize by date
  Future<void> fetchUserBeatSchedule(String userCd) async {
    _isLoading.value = true;
    try {
      String? token;
      try {
        final up = Provider.of<UserProvider>(Get.context!, listen: false);
        token = up.token;
      } catch (_) {
        token = null;
      }

      final data =
          await _service.fetchUserBeatSchedule(userCd: userCd, token: token);
      final list = BeatScheduler.listFromJson(data);
      _userBeats.assignAll(list);

      // Organize by date for quick lookup
      final organized = <String, List<BeatScheduler>>{};
      for (final beat in list) {
        if (!organized.containsKey(beat.assignDate)) {
          organized[beat.assignDate] = [];
        }
        organized[beat.assignDate]!.add(beat);
      }
      _beatsByDate.assignAll(organized);

      print(
          '[BeatController] Loaded ${list.length} user beats organized by date');
    } catch (e) {
      print('[BeatController] fetchUserBeatSchedule error: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  /// Get beats for a specific date (YYYY-MM-DD) - includes both existing and newly added
  List<BeatScheduler> getBeatsForDate(DateTime date) {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final existing = _beatsByDate[dateStr] ?? [];
    final newOnes = _newBeatsByDate[dateStr] ?? [];
    return [...existing, ...newOnes];
  }

  /// Add a newly selected beat for a specific date
  void addBeatForDate(DateTime date, Beat beat, String userCd) {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final beatScheduler = BeatScheduler(
      id: 0, // temporary id for new beats
      userCd: userCd,
      beatCd: beat.beatCd,
      beatName: beat.beatName,
      assignDate: dateStr,
    );

    if (!_newBeatsByDate.containsKey(dateStr)) {
      _newBeatsByDate[dateStr] = [];
    }

    _newBeatsByDate[dateStr]!.add(beatScheduler);
    _newBeatsByDate.refresh(); // trigger UI update
  }

  /// Save all newly added beats to the API
  Future<bool> saveBeatSchedule(String userCd) async {
    if (_newBeatsByDate.isEmpty) {
      print('[BeatController] No new beats to save');
      return true;
    }

    _isLoading.value = true;
    try {
      String? token;
      try {
        final up = Provider.of<UserProvider>(Get.context!, listen: false);
        token = up.token;
      } catch (_) {
        token = null;
      }

      // Flatten all new beats into a single list
      final beatsToSave = <BeatScheduler>[];
      _newBeatsByDate.forEach((date, beats) {
        beatsToSave.addAll(beats);
      });

      await _service.saveBeatScheduleBulk(
          beatsToSave: beatsToSave, token: token);

      // Move new beats to user beats after successful save
      _newBeatsByDate.forEach((date, beats) {
        if (!_beatsByDate.containsKey(date)) {
          _beatsByDate[date] = [];
        }
        _beatsByDate[date]!.addAll(beats);
      });

      _newBeatsByDate.clear();
      print('[BeatController] Successfully saved ${beatsToSave.length} beats');
      return true;
    } catch (e) {
      print('[BeatController] saveBeatSchedule error: $e');
      return false;
    } finally {
      _isLoading.value = false;
    }
  }
}
