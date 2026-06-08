// lib/mobile_dashboard_page.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ble_measurement_service.dart';
import 'login_page.dart';
import 'per_minute_aggregator.dart';
import 'measurement_sync_service.dart';
import 'models/measurement_models.dart';

class MobileDashboardPage extends StatefulWidget {
  const MobileDashboardPage({super.key});

  @override
  State<MobileDashboardPage> createState() => _MobileDashboardPageState();
}

class _MobileDashboardPageState extends State<MobileDashboardPage> {
  final _bleService = BleMeasurementService();
  final _syncService = MeasurementSyncService();

  // We still subscribe so aggregation/sync continues, but we don't show live data.
  StreamSubscription<MeasurementSample>? _sampleSub;

  PerMinuteAggregator? _aggregator;
  StreamSubscription<PerMinuteMeasurement>? _perMinuteSub;

  // Profile / goal
  int _stepGoalPerDay = 10000;
  bool _loadingProfile = true;

  // Today stats from measurements_minute
  bool _loadingStats = true;
  String? _statsError;

  int _totalStepsToday = 0;
  double? _avgHr;
  double? _minHr;
  double? _maxHr;
  double? _avgAqi;
  double? _avgTemp;
  double? _avgHum;
  double? _avgPress;

  @override
  void initState() {
    super.initState();

    _loadStepGoalPerDay();
    _loadTodayStats();

    // 1) Subscribe to raw samples (not used in UI, but kept if needed later)
    _sampleSub = _bleService.samplesStream.listen((sample) {
      // no setState: we don't display live sample anymore
      if (kDebugMode) {
        // You can log if you want
        // print('Received live sample: ${sample.toJson()}');
      }
    });

    // 2) Set up per-minute aggregation and sync (unchanged)
    _aggregator = PerMinuteAggregator(_bleService.samplesStream);
    _aggregator!.start();

    _perMinuteSub = _aggregator!.perMinuteStream.listen((perMinute) async {
      try {
        if (kDebugMode) {
          print('Syncing per-minute measurement: ${perMinute.toJson()}');
        }
        await _syncService.sendPerMinuteMeasurement(perMinute);
      } catch (e) {
        if (kDebugMode) {
          print('Sync error: $e');
        }
      }
    });
  }

  Future<void> _loadStepGoalPerDay() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        setState(() {
          _stepGoalPerDay = 10000;
          _loadingProfile = false;
        });
        return;
      }

      final res = await client
          .from('profiles')
          .select('step_goal_per_day')
          .eq('id', user.id)
          .maybeSingle();

      final val = res?['step_goal_per_day'] as int?;
      setState(() {
        _stepGoalPerDay = val ?? 10000;
        _loadingProfile = false;
      });

      if (kDebugMode) {
        print('Loaded step_goal_per_day: $_stepGoalPerDay');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading step_goal_per_day: $e');
      }
      setState(() {
        _stepGoalPerDay = 10000;
        _loadingProfile = false;
      });
    }
  }

  Future<void> _loadTodayStats() async {
    setState(() {
      _loadingStats = true;
      _statsError = null;
    });

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        setState(() {
          _statsError = 'You are not logged in.';
          _loadingStats = false;
        });
        return;
      }

      final nowUtc = DateTime.now().toUtc();
      final startOfDay =
          DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final data = await client
          .from('measurements_minute')
          .select(
            'steps_total_today, avg_heart_rate_bpm, min_heart_rate_bpm, max_heart_rate_bpm, avg_air_quality_index, avg_temperature_c, avg_humidity_percent, avg_pressure_hpa, timestamp_minute_utc',
          )
          .eq('user_id', user.id)
          .gte('timestamp_minute_utc', startOfDay.toIso8601String())
          .lt('timestamp_minute_utc', endOfDay.toIso8601String());

      if (data.isEmpty) {
        setState(() {
          _totalStepsToday = 0;
          _avgHr = null;
          _minHr = null;
          _maxHr = null;
          _avgAqi = null;
          _avgTemp = null;
          _avgHum = null;
          _avgPress = null;
          _loadingStats = false;
        });
        return;
      }

      int maxSteps = 0;

      double sumHr = 0;
      int countHr = 0;
      double? minHr;
      double? maxHr;

      double sumAqi = 0;
      int countAqi = 0;

      double sumTemp = 0;
      int countTemp = 0;

      double sumHum = 0;
      int countHum = 0;

      double sumPress = 0;
      int countPress = 0;

      for (final row in data as List<dynamic>) {
        final m = row as Map<String, dynamic>;

        final steps = m['steps_total_today'];
        if (steps is int && steps > maxSteps) {
          maxSteps = steps;
        }

        final avgHr = m['avg_heart_rate_bpm'];
        if (avgHr is num) {
          sumHr += avgHr.toDouble();
          countHr++;
        }

        final minHrRow = m['min_heart_rate_bpm'];
        if (minHrRow is num) {
          final v = minHrRow.toDouble();
          if (minHr == null || v < minHr) minHr = v;
        }

        final maxHrRow = m['max_heart_rate_bpm'];
        if (maxHrRow is num) {
          final v = maxHrRow.toDouble();
          if (maxHr == null || v > maxHr) maxHr = v;
        }

        final aqi = m['avg_air_quality_index'];
        if (aqi is num) {
          sumAqi += aqi.toDouble();
          countAqi++;
        }

        final temp = m['avg_temperature_c'];
        if (temp is num) {
          sumTemp += temp.toDouble();
          countTemp++;
        }

        final hum = m['avg_humidity_percent'];
        if (hum is num) {
          sumHum += hum.toDouble();
          countHum++;
        }

        final press = m['avg_pressure_hpa'];
        if (press is num) {
          sumPress += press.toDouble();
          countPress++;
        }
      }

      setState(() {
        _totalStepsToday = maxSteps;
        _avgHr = countHr > 0 ? (sumHr / countHr) : null;
        _minHr = minHr;
        _maxHr = maxHr;
        _avgAqi = countAqi > 0 ? (sumAqi / countAqi) : null;
        _avgTemp = countTemp > 0 ? (sumTemp / countTemp) : null;
        _avgHum = countHum > 0 ? (sumHum / countHum) : null;
        _avgPress = countPress > 0 ? (sumPress / countPress) : null;
        _loadingStats = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading today stats: $e');
      }
      setState(() {
        _statsError = 'Error loading today\'s stats';
        _loadingStats = false;
      });
    }
  }

  double get _stepsProgress {
    if (_stepGoalPerDay <= 0) return 0.0;
    final p = _totalStepsToday / _stepGoalPerDay;
    if (p < 0) return 0.0;
    if (p > 1) return 1.0;
    return p;
  }

  @override
  void dispose() {
    _sampleSub?.cancel();
    _perMinuteSub?.cancel();
    _aggregator?.dispose();
    _bleService.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MobileLoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brandDeep = const Color(0xFF1F5F63);
    final brandBorder = const Color(0xFFD8E9E6);
    final brandMuted = const Color(0xFF5D7B79);

    if (_loadingStats && _loadingProfile) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('WellSync Dashboard'),
        backgroundColor: brandDeep,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _loadStepGoalPerDay();
              await _loadTodayStats();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        color: const Color(0xFFEAF5F3),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // BLE status + connect button (unchanged)
            ValueListenableBuilder<bool>(
              valueListenable: _bleService.isConnected,
              builder: (context, connected, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connected ? 'Watch connected' : 'Watch not connected',
                      style: TextStyle(
                        fontSize: 14,
                        color: connected
                            ? const Color(0xFF1F5F63)
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final session =
                              Supabase.instance.client.auth.currentSession;
                          if (session == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please log in again before connecting.',
                                ),
                              ),
                            );
                            return;
                          }

                          if (!connected) {
                            await _bleService.connectAndListen();

                            if (_bleService.isConnected.value) {
                              await _bleService.sendConfigToWatch(
                                stepTarget: _stepGoalPerDay,
                              );
                            }
                          } else {
                            _bleService.disconnect();
                          }
                        },
                        child: Text(
                          connected ? 'Disconnect watch' : 'Connect to watch',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_loadingProfile)
                      const Text(
                        'Loading profile...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ValueListenableBuilder<String?>(
                      valueListenable: _bleService.statusMessage,
                      builder: (context, msg, _) {
                        if (msg == null || msg.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return Text(
                          msg,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            if (_statsError != null)
              Text(
                _statsError!,
                style: const TextStyle(color: Colors.red),
              ),

            if (_loadingStats)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: CircularProgressIndicator(),
              )
            else
              Expanded(
                child: ListView(
                  children: [
                    _StepsCard(
                      stepsToday: _totalStepsToday,
                      stepGoal: _stepGoalPerDay,
                      progress: _stepsProgress,
                      borderColor: brandBorder,
                      deepColor: brandDeep,
                      mutedColor: brandMuted,
                    ),
                    const SizedBox(height: 16),
                    _HeartRateCard(
                      avgHr: _avgHr,
                      minHr: _minHr,
                      maxHr: _maxHr,
                      borderColor: brandBorder,
                      deepColor: brandDeep,
                      mutedColor: brandMuted,
                    ),
                    const SizedBox(height: 16),
                    _EnvironmentCard(
                      avgAqi: _avgAqi,
                      avgTemp: _avgTemp,
                      avgHum: _avgHum,
                      avgPress: _avgPress,
                      borderColor: brandBorder,
                      deepColor: brandDeep,
                      mutedColor: brandMuted,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Steps progress card
class _StepsCard extends StatelessWidget {
  final int stepsToday;
  final int stepGoal;
  final double progress;
  final Color borderColor;
  final Color deepColor;
  final Color mutedColor;

  const _StepsCard({
    required this.stepsToday,
    required this.stepGoal,
    required this.progress,
    required this.borderColor,
    required this.deepColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = borderColor.withValues(alpha: 0.4);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(31, 95, 99, 0.12),
            blurRadius: 20,
            offset: Offset(0, 10),
            spreadRadius: -8,
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            height: 90,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: bg,
                  valueColor: AlwaysStoppedAnimation<Color>(deepColor),
                ),
                Center(
                  child: Text(
                    '${(progress * 100).round()}%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: deepColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Steps today',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: deepColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$stepsToday / $stepGoal steps',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F3B3A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Keep moving to hit your daily goal.',
                  style: TextStyle(
                    fontSize: 12,
                    color: mutedColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Heart rate card
class _HeartRateCard extends StatelessWidget {
  final double? avgHr;
  final double? minHr;
  final double? maxHr;
  final Color borderColor;
  final Color deepColor;
  final Color mutedColor;

  const _HeartRateCard({
    required this.avgHr,
    required this.minHr,
    required this.maxHr,
    required this.borderColor,
    required this.deepColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = avgHr != null || minHr != null || maxHr != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(31, 95, 99, 0.12),
            blurRadius: 20,
            offset: Offset(0, 10),
            spreadRadius: -8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Heart rate',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: deepColor,
            ),
          ),
          const SizedBox(height: 4),
          if (!hasData)
            Text(
              'No heart rate data for today yet.',
              style: TextStyle(fontSize: 13, color: mutedColor),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Avg',
                    value: avgHr != null ? '${avgHr!.round()} bpm' : '–',
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Min',
                    value: minHr != null ? '${minHr!.round()} bpm' : '–',
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Max',
                    value: maxHr != null ? '${maxHr!.round()} bpm' : '–',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// Environment card
class _EnvironmentCard extends StatelessWidget {
  final double? avgAqi;
  final double? avgTemp;
  final double? avgHum;
  final double? avgPress;
  final Color borderColor;
  final Color deepColor;
  final Color mutedColor;

  const _EnvironmentCard({
    required this.avgAqi,
    required this.avgTemp,
    required this.avgHum,
    required this.avgPress,
    required this.borderColor,
    required this.deepColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasAny =
        avgAqi != null || avgTemp != null || avgHum != null || avgPress != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(31, 95, 99, 0.12),
            blurRadius: 20,
            offset: Offset(0, 10),
            spreadRadius: -8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Environment',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: deepColor,
            ),
          ),
          const SizedBox(height: 4),
          if (!hasAny)
            Text(
              'No environment data for today yet.',
              style: TextStyle(fontSize: 13, color: mutedColor),
            )
          else
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              childAspectRatio: 3.2,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _MiniStat(
                  label: 'Air quality',
                  value: avgAqi != null ? avgAqi!.round().toString() : '–',
                ),
                _MiniStat(
                  label: 'Temperature',
                  value: avgTemp != null
                      ? '${avgTemp!.toStringAsFixed(1)} °C'
                      : '–',
                ),
                _MiniStat(
                  label: 'Humidity',
                  value: avgHum != null
                      ? '${avgHum!.toStringAsFixed(1)} %'
                      : '–',
                ),
                _MiniStat(
                  label: 'Pressure',
                  value: avgPress != null
                      ? '${avgPress!.toStringAsFixed(1)} hPa'
                      : '–',
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// Reusable mini stat
class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF5D7B79),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F3B3A),
          ),
        ),
      ],
    );
  }
}