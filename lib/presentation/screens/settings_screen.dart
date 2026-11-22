import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/l10n/app_l10n.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/repositories.dart';
import '../blocs/history_cubit.dart';
import '../blocs/settings_cubit.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_background.dart';
import '../widgets/section_title.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsCubit>().state;
    final cubit = context.read<SettingsCubit>();
    void set(AppSettings Function(AppSettings) f) {
      HapticFeedback.selectionClick();
      cubit.update(f);
    }

    return GradientBackground(
      child: Scaffold(
        appBar: AppBar(title: Text(context.tr('settings'))),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
          SectionTitle(context.tr('alarms')),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              SwitchListTile(
                secondary: const Icon(Icons.alarm_rounded, color: Neon.green),
                title: Text(context.tr('charge_alarm')),
                subtitle: Text(context.tr('charge_alarm_sub').replaceAll('{n}', '${s.chargeAlarmLevel}')),
                value: s.chargeAlarmEnabled,
                onChanged: (v) => set((x) => x.copyWith(chargeAlarmEnabled: v)),
              ),
              if (s.chargeAlarmEnabled)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    Expanded(
                      child: Slider(
                        value: s.chargeAlarmLevel.toDouble(),
                        min: 50,
                        max: 95,
                        divisions: 9,
                        label: '${s.chargeAlarmLevel}%',
                        onChanged: (v) => cubit.update((x) => x.copyWith(chargeAlarmLevel: v.round())),
                      ),
                    ),
                    Text('${s.chargeAlarmLevel}%', style: AppTheme.digits(size: 14)),
                  ]),
                ),
              SwitchListTile(
                secondary: const Icon(Icons.battery_full_rounded, color: Neon.lime),
                title: Text(context.tr('full_alarm')),
                subtitle: Text(context.tr('full_alarm_sub')),
                value: s.fullAlarmEnabled,
                onChanged: (v) => set((x) => x.copyWith(fullAlarmEnabled: v)),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.local_fire_department_rounded, color: Neon.red),
                title: Text(context.tr('overheat_alarm')),
                subtitle: Text(context.tr('overheat_alarm_sub').replaceAll('{n}', s.overheatThresholdC.toStringAsFixed(0))),
                value: s.overheatEnabled,
                onChanged: (v) => set((x) => x.copyWith(overheatEnabled: v)),
              ),
              if (s.overheatEnabled)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    Expanded(
                      child: Slider(
                        value: s.overheatThresholdC,
                        min: 35,
                        max: 50,
                        divisions: 15,
                        activeColor: Neon.red,
                        label: '${s.overheatThresholdC.toStringAsFixed(0)}°C',
                        onChanged: (v) => cubit.update((x) => x.copyWith(overheatThresholdC: v.roundToDouble())),
                      ),
                    ),
                    Text('${s.overheatThresholdC.toStringAsFixed(0)}°C', style: AppTheme.digits(size: 14)),
                  ]),
                ),
              SwitchListTile(
                secondary: const Icon(Icons.notifications_active_rounded, color: Neon.cyan),
                title: Text(context.tr('live_notification')),
                subtitle: Text(context.tr('live_notification_sub')),
                value: s.liveNotification,
                onChanged: (v) async {
                  if (v) await sl<BatteryRepository>().requestNotificationPermission().catchError((_) => false);
                  set((x) => x.copyWith(liveNotification: v));
                },
              ),
            ]),
          ),
          SectionTitle(context.tr('charging_animation')),
          GlassCard(
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in AnimationTheme.values)
                ChoiceChip(
                  avatar: Icon(switch (t) {
                    AnimationTheme.lightning => Icons.bolt_rounded,
                    AnimationTheme.liquid => Icons.water_drop_rounded,
                    AnimationTheme.cyberRing => Icons.blur_circular_rounded,
                    AnimationTheme.minimal => Icons.crop_square_rounded,
                  }, size: 18),
                  label: Text(context.tr('anim_${t.name}')),
                  selected: s.animationTheme == t,
                  onSelected: (_) => set((x) => x.copyWith(animationTheme: t)),
                ),
            ]),
          ),
          const SizedBox(height: 8),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              SwitchListTile(
                secondary: const Icon(Icons.fullscreen_rounded),
                title: Text(context.tr('overlay_on_plug')),
                value: s.showOverlayOnPlug,
                onChanged: (v) => set((x) => x.copyWith(showOverlayOnPlug: v)),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.volume_up_rounded),
                title: Text(context.tr('sound')),
                value: s.soundEnabled,
                onChanged: (v) => set((x) => x.copyWith(soundEnabled: v)),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.vibration_rounded),
                title: Text(context.tr('haptics')),
                value: s.hapticsEnabled,
                onChanged: (v) => set((x) => x.copyWith(hapticsEnabled: v)),
              ),
            ]),
          ),
          SectionTitle(context.tr('appearance')),
          GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.tr('theme')),
              const SizedBox(height: 8),
              SegmentedButton<AppThemeMode>(
                segments: [
                  ButtonSegment(value: AppThemeMode.dark, label: Text(context.tr('theme_dark')), icon: const Icon(Icons.dark_mode_rounded)),
                  ButtonSegment(value: AppThemeMode.amoled, label: const Text('AMOLED'), icon: const Icon(Icons.contrast_rounded)),
                  ButtonSegment(value: AppThemeMode.light, label: Text(context.tr('theme_light')), icon: const Icon(Icons.light_mode_rounded)),
                ],
                selected: {s.themeMode},
                onSelectionChanged: (v) => set((x) => x.copyWith(themeMode: v.first)),
              ),
              const SizedBox(height: 16),
              Text(context.tr('language')),
              const SizedBox(height: 8),
              SegmentedButton<AppLanguage>(
                segments: const [
                  ButtonSegment(value: AppLanguage.en, label: Text('English')),
                  ButtonSegment(value: AppLanguage.hi, label: Text('हिन्दी')),
                  ButtonSegment(value: AppLanguage.mr, label: Text('मराठी')),
                ],
                selected: {s.language},
                onSelectionChanged: (v) => set((x) => x.copyWith(language: v.first)),
              ),
            ]),
          ),
          SectionTitle(context.tr('units')),
          GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SegmentedButton<TempUnit>(
                segments: const [
                  ButtonSegment(value: TempUnit.celsius, label: Text('°C')),
                  ButtonSegment(value: TempUnit.fahrenheit, label: Text('°F')),
                ],
                selected: {s.tempUnit},
                onSelectionChanged: (v) => set((x) => x.copyWith(tempUnit: v.first)),
              ),
              const SizedBox(height: 12),
              SegmentedButton<CurrentUnit>(
                segments: const [
                  ButtonSegment(value: CurrentUnit.milliamp, label: Text('mA')),
                  ButtonSegment(value: CurrentUnit.amp, label: Text('A')),
                ],
                selected: {s.currentUnit},
                onSelectionChanged: (v) => set((x) => x.copyWith(currentUnit: v.first)),
              ),
            ]),
          ),
          SectionTitle(context.tr('data')),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.file_download_outlined),
                title: Text(context.tr('export_csv')),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final saved = context.tr('csv_saved');
                  try {
                    final path = await context.read<HistoryCubit>().exportCsv();
                    messenger.showSnackBar(SnackBar(content: Text('$saved $path')));
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text('$e')));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Neon.red),
                title: Text(context.tr('clear_history')),
                onTap: () async {
                  final history = context.read<HistoryCubit>();
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(ctx.tr('clear_history')),
                      content: Text(ctx.tr('clear_history_confirm')),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('cancel'))),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.tr('delete'))),
                      ],
                    ),
                  );
                  if (ok ?? false) await history.clear();
                },
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
