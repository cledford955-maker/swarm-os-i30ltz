import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'lucille_voice_service.dart';

/// Service managing 3-times daily Food, Water & Medication intake with Lucille voice alarms
class VitalService extends ChangeNotifier {
  static final VitalService _instance = VitalService._internal();
  factory VitalService() => _instance;
  VitalService._internal() {
    _loadState();
    _startAlarmScheduleChecker();
  }

  // Daily target water in milliliters (e.g., 2500ml ~ 8-10 glasses)
  static const int kDailyWaterTargetMl = 2500;

  // State
  bool _breakfastTaken = false;
  bool _lunchTaken = false;
  bool _dinnerTaken = false;

  bool _medsMorningTaken = false;
  bool _medsMiddayTaken = false;
  bool _medsEveningTaken = false;

  int _waterConsumedMl = 0;
  bool _alarmsEnabled = true;

  Timer? _scheduleTimer;

  bool get breakfastTaken => _breakfastTaken;
  bool get lunchTaken => _lunchTaken;
  bool get dinnerTaken => _dinnerTaken;

  bool get medsMorningTaken => _medsMorningTaken;
  bool get medsMiddayTaken => _medsMiddayTaken;
  bool get medsEveningTaken => _medsEveningTaken;

  int get waterConsumedMl => _waterConsumedMl;
  double get waterProgress => (_waterConsumedMl / kDailyWaterTargetMl).clamp(0.0, 1.0);
  bool get alarmsEnabled => _alarmsEnabled;

  int get completedGoalsCount {
    int count = 0;
    if (_breakfastTaken) count++;
    if (_lunchTaken) count++;
    if (_dinnerTaken) count++;
    if (_medsMorningTaken) count++;
    if (_medsMiddayTaken) count++;
    if (_medsEveningTaken) count++;
    if (waterProgress >= 1.0) count++;
    return count;
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final lastRecordedDate = prefs.getString('vital_last_date') ?? '';

    if (lastRecordedDate != todayStr) {
      // New day: reset checkboxes
      _breakfastTaken = false;
      _lunchTaken = false;
      _dinnerTaken = false;
      _medsMorningTaken = false;
      _medsMiddayTaken = false;
      _medsEveningTaken = false;
      _waterConsumedMl = 0;
      await prefs.setString('vital_last_date', todayStr);
      await _saveState();
    } else {
      _breakfastTaken = prefs.getBool('vital_breakfast') ?? false;
      _lunchTaken = prefs.getBool('vital_lunch') ?? false;
      _dinnerTaken = prefs.getBool('vital_dinner') ?? false;
      _medsMorningTaken = prefs.getBool('vital_meds_morning') ?? false;
      _medsMiddayTaken = prefs.getBool('vital_meds_midday') ?? false;
      _medsEveningTaken = prefs.getBool('vital_meds_evening') ?? false;
      _waterConsumedMl = prefs.getInt('vital_water_ml') ?? 0;
      _alarmsEnabled = prefs.getBool('vital_alarms_enabled') ?? true;
    }
    notifyListeners();
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vital_breakfast', _breakfastTaken);
    await prefs.setBool('vital_lunch', _lunchTaken);
    await prefs.setBool('vital_dinner', _dinnerTaken);
    await prefs.setBool('vital_meds_morning', _medsMorningTaken);
    await prefs.setBool('vital_meds_midday', _medsMiddayTaken);
    await prefs.setBool('vital_meds_evening', _medsEveningTaken);
    await prefs.setInt('vital_water_ml', _waterConsumedMl);
    await prefs.setBool('vital_alarms_enabled', _alarmsEnabled);
    notifyListeners();
  }

  void toggleBreakfast(bool? val) {
    _breakfastTaken = val ?? !_breakfastTaken;
    _saveState();
  }

  void toggleLunch(bool? val) {
    _lunchTaken = val ?? !_lunchTaken;
    _saveState();
  }

  void toggleDinner(bool? val) {
    _dinnerTaken = val ?? !_dinnerTaken;
    _saveState();
  }

  void toggleMedsMorning(bool? val) {
    _medsMorningTaken = val ?? !_medsMorningTaken;
    _saveState();
  }

  void toggleMedsMidday(bool? val) {
    _medsMiddayTaken = val ?? !_medsMiddayTaken;
    _saveState();
  }

  void toggleMedsEvening(bool? val) {
    _medsEveningTaken = val ?? !_medsEveningTaken;
    _saveState();
  }

  void addWater(int ml) {
    _waterConsumedMl += ml;
    _saveState();
  }

  void resetWater() {
    _waterConsumedMl = 0;
    _saveState();
  }

  void setAlarmsEnabled(bool enabled) {
    _alarmsEnabled = enabled;
    _saveState();
  }

  /// Trigger Lucille vocal reminder alarm (ensuring she always says "hun")
  Future<void> triggerLucilleAlarm({required String slot}) async {
    String speech = '';
    switch (slot.toLowerCase()) {
      case 'morning':
        speech = "Good morning hun! It's Lucille reminding you: Dr. Vital has your morning schedule ready. Drink a tall glass of water, enjoy some breakfast, and take your morning meds for me.";
        break;
      case 'midday':
      case 'lunch':
        speech = "Hey hun, it's midday! Time for lunch, another glass of water, and your afternoon medication. Keep that momentum going!";
        break;
      case 'evening':
      case 'dinner':
        speech = 'Evening hun... Lucille here. Time for dinner, your evening meds, and some hydration. Take good care of yourself, okay?';
        break;
      default:
        speech = "Hey hun! Dr. Vital says it's time to check in: make sure you're drinking water, eating well, and keeping up with your medication.";
    }

    await LucilleVoiceService().speak(speech);
  }

  void _startAlarmScheduleChecker() {
    // Check every 15 minutes for 3-times daily scheduled alarms
    _scheduleTimer?.cancel();
    _scheduleTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      if (!_alarmsEnabled) return;
      final now = DateTime.now();

      // Morning slot: between 8:00 AM and 8:15 AM
      if (now.hour == 8 && now.minute < 15 && (!_medsMorningTaken || !_breakfastTaken)) {
        triggerLucilleAlarm(slot: 'morning');
      }
      // Midday slot: between 1:00 PM and 1:15 PM
      else if (now.hour == 13 && now.minute < 15 && (!_medsMiddayTaken || !_lunchTaken)) {
        triggerLucilleAlarm(slot: 'midday');
      }
      // Evening slot: between 7:00 PM and 7:15 PM
      else if (now.hour == 19 && now.minute < 15 && (!_medsEveningTaken || !_dinnerTaken)) {
        triggerLucilleAlarm(slot: 'evening');
      }
    });
  }

  @override
  void dispose() {
    _scheduleTimer?.cancel();
    super.dispose();
  }
}
