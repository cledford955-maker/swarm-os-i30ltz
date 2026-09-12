import 'package:flutter/material.dart';
import '../services/vital_service.dart';
import '../theme/swarm_colors.dart';
import '../theme/swarm_text_styles.dart';

class VitalTrackerDialog extends StatefulWidget {
  const VitalTrackerDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: SwarmColors.scrim,
      builder: (_) => const VitalTrackerDialog(),
    );
  }

  @override
  State<VitalTrackerDialog> createState() => _VitalTrackerDialogState();
}

class _VitalTrackerDialogState extends State<VitalTrackerDialog> {
  final _vital = VitalService();

  @override
  void initState() {
    super.initState();
    _vital.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _vital.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    const accentGreen = Color(0xFF00E676);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 580,
        constraints: const BoxConstraints(maxHeight: 740),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0F1D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentGreen.withValues(alpha: 0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accentGreen.withValues(alpha: 0.15),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            // ─── Header ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: accentGreen.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                border: Border(bottom: BorderSide(color: accentGreen.withValues(alpha: 0.2))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentGreen.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.medical_services_rounded, color: accentGreen, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DR. VITAL · INTAKE GUARDIAN',
                          style: SwarmTextStyles.label.copyWith(
                            color: accentGreen,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Food, Water & Medication Adherence (3x Daily Schedule)',
                          style: SwarmTextStyles.codeSmall.copyWith(
                            color: SwarmColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: SwarmColors.textMuted, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // ─── Content ─────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Goals Progress
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: SwarmColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TODAY\'S INTAKE PROGRESS',
                                  style: SwarmTextStyles.codeSmall.copyWith(
                                    color: accentGreen,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_vital.completedGoalsCount} of 7 Daily Targets Completed',
                                  style: SwarmTextStyles.body.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _vital.alarmsEnabled,
                            activeThumbColor: accentGreen,
                            onChanged: (val) => _vital.setAlarmsEnabled(val),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _vital.alarmsEnabled ? 'Lucille Voice\nAlarms ON' : 'Alarms\nOFF',
                            style: SwarmTextStyles.codeSmall.copyWith(fontSize: 10),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 1. Three Times Daily Schedule (Breakfast, Lunch, Dinner & Meds)
                    Text(
                      '3X DAILY MEAL & MEDICATION SLOTS',
                      style: SwarmTextStyles.label.copyWith(
                        color: SwarmColors.textMuted,
                        fontSize: 11,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 10),

                    _buildSlotCard(
                      title: '🌅 MORNING (BREAKFAST & AM MEDS)',
                      timeTag: '~8:00 AM',
                      foodLabel: 'Breakfast Meal Logged',
                      foodTaken: _vital.breakfastTaken,
                      onFoodToggle: _vital.toggleBreakfast,
                      medsLabel: 'Morning Medication Taken',
                      medsTaken: _vital.medsMorningTaken,
                      onMedsToggle: _vital.toggleMedsMorning,
                      onVoiceAlarm: () => _vital.triggerLucilleAlarm(slot: 'morning'),
                    ),

                    const SizedBox(height: 12),

                    _buildSlotCard(
                      title: '☀️ MIDDAY (LUNCH & MIDDAY MEDS)',
                      timeTag: '~1:00 PM',
                      foodLabel: 'Lunch Meal Logged',
                      foodTaken: _vital.lunchTaken,
                      onFoodToggle: _vital.toggleLunch,
                      medsLabel: 'Midday Medication Taken',
                      medsTaken: _vital.medsMiddayTaken,
                      onMedsToggle: _vital.toggleMedsMidday,
                      onVoiceAlarm: () => _vital.triggerLucilleAlarm(slot: 'midday'),
                    ),

                    const SizedBox(height: 12),

                    _buildSlotCard(
                      title: '🌙 EVENING (DINNER & PM MEDS)',
                      timeTag: '~7:00 PM',
                      foodLabel: 'Dinner Meal Logged',
                      foodTaken: _vital.dinnerTaken,
                      onFoodToggle: _vital.toggleDinner,
                      medsLabel: 'Evening Medication Taken',
                      medsTaken: _vital.medsEveningTaken,
                      onMedsToggle: _vital.toggleMedsEvening,
                      onVoiceAlarm: () => _vital.triggerLucilleAlarm(slot: 'evening'),
                    ),

                    const SizedBox(height: 20),

                    // 2. Hydration Tracker
                    Text(
                      'DAILY HYDRATION TRACKER',
                      style: SwarmTextStyles.label.copyWith(
                        color: SwarmColors.textMuted,
                        fontSize: 11,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: SwarmColors.agentCyan.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.water_drop_rounded, color: SwarmColors.agentCyan, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_vital.waterConsumedMl} / ${VitalService.kDailyWaterTargetMl} ml',
                                    style: SwarmTextStyles.body.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${(_vital.waterProgress * 100).toInt()}% Target',
                                style: SwarmTextStyles.codeSmall.copyWith(
                                  color: SwarmColors.agentCyan,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _vital.waterProgress,
                              minHeight: 8,
                              backgroundColor: Colors.black26,
                              valueColor: const AlwaysStoppedAnimation<Color>(SwarmColors.agentCyan),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _vital.addWater(250),
                                icon: const Icon(Icons.add, size: 14, color: SwarmColors.agentCyan),
                                label: const Text('+250 ml (Cup)', style: TextStyle(fontSize: 11, color: SwarmColors.agentCyan)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: SwarmColors.agentCyan),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () => _vital.addWater(500),
                                icon: const Icon(Icons.add, size: 14, color: SwarmColors.agentCyan),
                                label: const Text('+500 ml (Bottle)', style: TextStyle(fontSize: 11, color: SwarmColors.agentCyan)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: SwarmColors.agentCyan),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () => _vital.resetWater(),
                                child: const Text('Reset', style: TextStyle(fontSize: 10, color: SwarmColors.textMuted)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotCard({
    required String title,
    required String timeTag,
    required String foodLabel,
    required bool foodTaken,
    required ValueChanged<bool?> onFoodToggle,
    required String medsLabel,
    required bool medsTaken,
    required ValueChanged<bool?> onMedsToggle,
    required VoidCallback onVoiceAlarm,
  }) {
    const accentGreen = Color(0xFF00E676);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (foodTaken && medsTaken) ? accentGreen.withValues(alpha: 0.4) : SwarmColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: SwarmTextStyles.codeSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(timeTag, style: SwarmTextStyles.codeSmall.copyWith(fontSize: 9)),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Play Lucille spoken alarm ("hun")',
                    child: InkWell(
                      onTap: onVoiceAlarm,
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: SwarmColors.lucille.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: SwarmColors.lucille.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.volume_up_rounded, color: SwarmColors.lucille, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              'LUCILLE ALARM',
                              style: SwarmTextStyles.codeSmall.copyWith(
                                color: SwarmColors.lucille,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: foodTaken,
            onChanged: onFoodToggle,
            activeColor: accentGreen,
            title: Text(foodLabel, style: SwarmTextStyles.body.copyWith(fontSize: 12)),
            secondary: const Icon(Icons.restaurant_rounded, size: 16, color: SwarmColors.textMuted),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
          CheckboxListTile(
            value: medsTaken,
            onChanged: onMedsToggle,
            activeColor: accentGreen,
            title: Text(medsLabel, style: SwarmTextStyles.body.copyWith(fontSize: 12)),
            secondary: const Icon(Icons.medication_rounded, size: 16, color: SwarmColors.textMuted),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
