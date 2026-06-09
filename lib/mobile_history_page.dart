// lib/mobile_history_page.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

class StepsHistoryItem {
  final String date;
  final int totalSteps;

  StepsHistoryItem({required this.date, required this.totalSteps});
}

class HeartRateHistoryItem {
  final String date;
  final double? avgHeartRateBpm;
  final double? minHeartRateBpm;
  final double? maxHeartRateBpm;

  HeartRateHistoryItem({
    required this.date,
    required this.avgHeartRateBpm,
    required this.minHeartRateBpm,
    required this.maxHeartRateBpm,
  });
}

class MobileHistoryPage extends StatefulWidget {
  const MobileHistoryPage({super.key});

  @override
  State<MobileHistoryPage> createState() => _MobileHistoryPageState();
}

class _MobileHistoryPageState extends State<MobileHistoryPage> {
  final _supabase = Supabase.instance.client;

  int _rangeDays = 7;
  bool _loading = false;
  String? _error;

  // Daily-level history for ranges > 1 day
  List<StepsHistoryItem> _stepsHistory = [];
  List<HeartRateHistoryItem> _hrHistory = [];

  // Today-only, minute-level series for 1d charts
  List<FlSpot> _todayStepsSpots = [];
  List<FlSpot> _todayHrAvgSpots = [];
  List<FlSpot> _todayHrMinSpots = [];
  List<FlSpot> _todayHrMaxSpots = [];

  final List<int> _ranges = const [1, 3, 7, 14, 30];

  @override
  void initState() {
    super.initState();
    _loadData(_rangeDays);
  }

  Future<void> _loadData(int days) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _error = 'You are not logged in.';
          _loading = false;
        });
        return;
      }

      if (days == 1) {
        await _loadTodayFromMeasurementsMinute(user.id);
      } else {
        await _loadDailyStats(user.id, days);
      }

      setState(() {
        _rangeDays = days;
        _loading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading history: $e');
      }
      setState(() {
        _error = 'Error loading history';
        _loading = false;
      });
    }
  }

  // NEW: last N rows by date, not date window
  Future<void> _loadDailyStats(String userId, int days) async {
    final res = await _supabase
        .from('daily_stats')
        .select(
          '''
          date,
          total_steps,
          avg_heart_rate_bpm,
          min_heart_rate_bpm,
          max_heart_rate_bpm
          ''',
        )
        .eq('user_id', userId)
        .order('date', ascending: false) // newest first
        .limit(days);

    final rows = res as List<dynamic>;

    // Sort ascending in Dart so charts go left->right
    rows.sort((a, b) {
      final ma = a as Map<String, dynamic>;
      final mb = b as Map<String, dynamic>;
      final da = ma['date'] as String;
      final db = mb['date'] as String;
      return da.compareTo(db);
    });

    final steps = <StepsHistoryItem>[];
    final hr = <HeartRateHistoryItem>[];

    for (final row in rows) {
      final m = row as Map<String, dynamic>;
      final date = m['date'] as String;

      final totalStepsRaw = m['total_steps'];
      final totalSteps =
          (totalStepsRaw is int ? totalStepsRaw : (totalStepsRaw ?? 0)) as int;

      steps.add(
        StepsHistoryItem(
          date: date,
          totalSteps: totalSteps,
        ),
      );

      double? avgHr;
      if (m['avg_heart_rate_bpm'] is num) {
        avgHr = (m['avg_heart_rate_bpm'] as num).toDouble();
      }

      double? minHr;
      if (m['min_heart_rate_bpm'] is num) {
        minHr = (m['min_heart_rate_bpm'] as num).toDouble();
      }

      double? maxHr;
      if (m['max_heart_rate_bpm'] is num) {
        maxHr = (m['max_heart_rate_bpm'] as num).toDouble();
      }

      hr.add(
        HeartRateHistoryItem(
          date: date,
          avgHeartRateBpm: avgHr,
          minHeartRateBpm: minHr,
          maxHeartRateBpm: maxHr,
        ),
      );
    }

    // Clear today series when we're not in 1d mode
    _todayStepsSpots = [];
    _todayHrAvgSpots = [];
    _todayHrMinSpots = [];
    _todayHrMaxSpots = [];

    _stepsHistory = steps;
    _hrHistory = hr;
  }

  Future<void> _loadTodayFromMeasurementsMinute(String userId) async {
    final nowUtc = DateTime.now().toUtc();
    final startOfDay =
        DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day); // inclusive
    final endOfDay = startOfDay.add(const Duration(days: 1)); // exclusive

    final res = await _supabase
        .from('measurements_minute')
        .select(
          '''
          timestamp_minute_utc,
          steps_total_today,
          avg_heart_rate_bpm,
          min_heart_rate_bpm,
          max_heart_rate_bpm
          ''',
        )
        .eq('user_id', userId)
        .gte('timestamp_minute_utc', startOfDay.toIso8601String())
        .lt('timestamp_minute_utc', endOfDay.toIso8601String())
        .order('timestamp_minute_utc', ascending: true);

    final rows = res as List<dynamic>;

    if (rows.isEmpty) {
      _stepsHistory = [];
      _hrHistory = [];
      _todayStepsSpots = [];
      _todayHrAvgSpots = [];
      _todayHrMinSpots = [];
      _todayHrMaxSpots = [];
      return;
    }

    int maxSteps = 0;

    final stepsSpots = <FlSpot>[];
    final avgSpots = <FlSpot>[];
    final minSpots = <FlSpot>[];
    final maxSpots = <FlSpot>[];

    for (var i = 0; i < rows.length; i++) {
      final m = rows[i] as Map<String, dynamic>;

      final stepsRaw = m['steps_total_today'];
      int steps = 0;
      if (stepsRaw is int) {
        steps = stepsRaw;
      } else if (stepsRaw is num) {
        steps = stepsRaw.toInt();
      }
      if (steps > maxSteps) {
        maxSteps = steps;
      }

      stepsSpots.add(FlSpot(i.toDouble(), steps.toDouble()));

      final avgHr = m['avg_heart_rate_bpm'];
      if (avgHr is num) {
        avgSpots.add(FlSpot(i.toDouble(), avgHr.toDouble()));
      }

      final minHr = m['min_heart_rate_bpm'];
      if (minHr is num) {
        minSpots.add(FlSpot(i.toDouble(), minHr.toDouble()));
      }

      final maxHr = m['max_heart_rate_bpm'];
      if (maxHr is num) {
        maxSpots.add(FlSpot(i.toDouble(), maxHr.toDouble()));
      }
    }

    final dayLabel = _formatDate(startOfDay);

    _stepsHistory = [
      StepsHistoryItem(
        date: dayLabel,
        totalSteps: maxSteps,
      ),
    ];

    double? avgHrDay;
    double? minHrDay;
    double? maxHrDay;
    if (avgSpots.isNotEmpty) {
      final sum = avgSpots.fold<double>(0, (acc, s) => acc + s.y);
      avgHrDay = sum / avgSpots.length;
      minHrDay = minSpots.isNotEmpty
          ? minSpots.map((s) => s.y).reduce((a, b) => a < b ? a : b)
          : null;
      maxHrDay = maxSpots.isNotEmpty
          ? maxSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b)
          : null;
    }

    _hrHistory = [
      HeartRateHistoryItem(
        date: dayLabel,
        avgHeartRateBpm: avgHrDay,
        minHeartRateBpm: minHrDay,
        maxHeartRateBpm: maxHrDay,
      ),
    ];

    _todayStepsSpots = stepsSpots;
    _todayHrAvgSpots = avgSpots;
    _todayHrMinSpots = minSpots;
    _todayHrMaxSpots = maxSpots;
  }

  String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  @override
  Widget build(BuildContext context) {
    final brandDeep = const Color(0xFF1F5F63);
    final brandBorder = const Color(0xFFD8E9E6);
    final brandMuted = const Color(0xFF5D7B79);

    final isTodayMode = _rangeDays == 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        backgroundColor: brandDeep,
      ),
      body: Container(
        width: double.infinity,
        color: const Color(0xFFEAF5F3),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Range selector pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _ranges.map((r) {
                  final active = r == _rangeDays;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(r == 30 ? '1M' : '${r}d'),
                      selected: active,
                      onSelected: (sel) {
                        if (sel) {
                          _loadData(r);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFF5C2C0),
                  ),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFB3261E),
                  ),
                ),
              ),

            if (_loading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Expanded(
                child: ListView(
                  children: [
                    _StepsHistoryCard(
                      stepsHistory: _stepsHistory,
                      brandBorder: brandBorder,
                      brandDeep: brandDeep,
                      brandMuted: brandMuted,
                      isTodayMode: isTodayMode,
                      todayStepsSpots: _todayStepsSpots,
                    ),
                    const SizedBox(height: 16),
                    _HeartRateHistoryCard(
                      hrHistory: _hrHistory,
                      brandBorder: brandBorder,
                      brandDeep: brandDeep,
                      brandMuted: brandMuted,
                      isTodayMode: isTodayMode,
                      todayAvgSpots: _todayHrAvgSpots,
                      todayMinSpots: _todayHrMinSpots,
                      todayMaxSpots: _todayHrMaxSpots,
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

// -------------------- Steps card with chart --------------------

class _StepsHistoryCard extends StatelessWidget {
  final List<StepsHistoryItem> stepsHistory;
  final Color brandBorder;
  final Color brandMuted;
  final Color brandDeep;
  final bool isTodayMode;
  final List<FlSpot> todayStepsSpots;

  const _StepsHistoryCard({
    required this.stepsHistory,
    required this.brandBorder,
    required this.brandMuted,
    required this.brandDeep,
    required this.isTodayMode,
    required this.todayStepsSpots,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = isTodayMode
        ? todayStepsSpots.isNotEmpty
        : stepsHistory.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: brandBorder),
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
            isTodayMode ? 'Steps today' : 'Steps per day',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: brandDeep,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isTodayMode
                ? 'Per-minute steps over the current day'
                : 'Daily total over the selected range',
            style: TextStyle(
              fontSize: 13,
              color: brandMuted,
            ),
          ),
          const SizedBox(height: 12),
          if (!hasData)
            const Text(
              'No steps history for this range yet.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
            )
          else ...[
            SizedBox(
              height: 200,
              child: isTodayMode
                  ? _StepsLineChart(
                      spotsOverride: todayStepsSpots,
                      stepsHistory: const [],
                      brandDeep: brandDeep,
                      brandMuted: brandMuted,
                      isTodayMode: true,
                    )
                  : _StepsLineChart(
                      spotsOverride: null,
                      stepsHistory: stepsHistory,
                      brandDeep: brandDeep,
                      brandMuted: brandMuted,
                      isTodayMode: false,
                    ),
            ),
            const SizedBox(height: 12),
            Column(
              children: stepsHistory
                  .map(
                    (item) => _DayRow(
                      date: item.date,
                      value: '${item.totalSteps.toString()} steps',
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepsLineChart extends StatelessWidget {
  final List<StepsHistoryItem> stepsHistory;
  final Color brandDeep;
  final Color brandMuted;
  final bool isTodayMode;
  final List<FlSpot>? spotsOverride;

  const _StepsLineChart({
    required this.stepsHistory,
    required this.brandDeep,
    required this.brandMuted,
    required this.isTodayMode,
    required this.spotsOverride,
  });

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];

    if (isTodayMode && spotsOverride != null) {
      spots.addAll(spotsOverride!);
    } else {
      if (stepsHistory.isEmpty) {
        return const SizedBox.shrink();
      }
      for (var i = 0; i < stepsHistory.length; i++) {
        spots.add(
          FlSpot(
            i.toDouble(),
            stepsHistory[i].totalSteps.toDouble(),
          ),
        );
      }
    }

    if (spots.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxY = spots
        .map((e) => e.y)
        .fold<double>(0, (prev, v) => v > prev ? v : prev);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: spots.last.x,
        minY: 0,
        maxY: maxY == 0 ? 1 : maxY * 1.1,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 0 ? maxY / 4 : 1,
          getDrawingHorizontalLine: (value) => FlLine(
            color: const Color(0xFFE2EFEC),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: !isTodayMode, // hide x titles for today (many minutes)
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= stepsHistory.length) {
                  return const SizedBox.shrink();
                }
                final date = stepsHistory[idx].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    date.substring(5), // MM-DD
                    style: TextStyle(
                      fontSize: 10,
                      color: brandMuted,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    fontSize: 10,
                    color: brandMuted,
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(
          show: false,
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: brandDeep,
            barWidth: 3,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: brandDeep.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------- Heart rate card with chart --------------------

class _HeartRateHistoryCard extends StatelessWidget {
  final List<HeartRateHistoryItem> hrHistory;
  final Color brandBorder;
  final Color brandMuted;
  final Color brandDeep;
  final bool isTodayMode;
  final List<FlSpot> todayAvgSpots;
  final List<FlSpot> todayMinSpots;
  final List<FlSpot> todayMaxSpots;

  const _HeartRateHistoryCard({
    required this.hrHistory,
    required this.brandBorder,
    required this.brandMuted,
    required this.brandDeep,
    required this.isTodayMode,
    required this.todayAvgSpots,
    required this.todayMinSpots,
    required this.todayMaxSpots,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = isTodayMode
        ? todayAvgSpots.isNotEmpty ||
            todayMinSpots.isNotEmpty ||
            todayMaxSpots.isNotEmpty
        : hrHistory.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: brandBorder),
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
            isTodayMode ? 'Heart rate today' : 'Heart rate per day',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: brandDeep,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isTodayMode
                ? 'Per-minute heart rate over today'
                : 'Average bpm with daily min and max',
            style: TextStyle(
              fontSize: 13,
              color: brandMuted,
            ),
          ),
          const SizedBox(height: 12),
          if (!hasData)
            const Text(
              'No heart-rate history for this range yet.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
            )
          else ...[
            SizedBox(
              height: 200,
              child: _HeartRateLineChart(
                hrHistory: hrHistory,
                brandDeep: brandDeep,
                brandMuted: brandMuted,
                isTodayMode: isTodayMode,
                todayAvgSpots: todayAvgSpots,
                todayMinSpots: todayMinSpots,
                todayMaxSpots: todayMaxSpots,
              ),
            ),
            const SizedBox(height: 12),
            Column(
              children: hrHistory
                  .map(
                    (item) => _DayRow(
                      date: item.date,
                      value: _formatHrRow(item),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _formatHrRow(HeartRateHistoryItem item) {
    final avg =
        item.avgHeartRateBpm != null ? item.avgHeartRateBpm!.round().toString() : '—';
    final min = item.minHeartRateBpm?.round().toString();
    final max = item.maxHeartRateBpm?.round().toString();

    if (min != null && max != null) {
      return 'avg $avg bpm (min $min, max $max)';
    }
    return 'avg $avg bpm';
  }
}

class _HeartRateLineChart extends StatelessWidget {
  final List<HeartRateHistoryItem> hrHistory;
  final Color brandDeep;
  final Color brandMuted;
  final bool isTodayMode;
  final List<FlSpot> todayAvgSpots;
  final List<FlSpot> todayMinSpots;
  final List<FlSpot> todayMaxSpots;

  const _HeartRateLineChart({
    required this.hrHistory,
    required this.brandDeep,
    required this.brandMuted,
    required this.isTodayMode,
    required this.todayAvgSpots,
    required this.todayMinSpots,
    required this.todayMaxSpots,
  });

  @override
  Widget build(BuildContext context) {
    final avgSpots = <FlSpot>[];
    final minSpots = <FlSpot>[];
    final maxSpots = <FlSpot>[];

    if (isTodayMode) {
      avgSpots.addAll(todayAvgSpots);
      minSpots.addAll(todayMinSpots);
      maxSpots.addAll(todayMaxSpots);
    } else {
      if (hrHistory.isEmpty) {
        return const SizedBox.shrink();
      }
      for (var i = 0; i < hrHistory.length; i++) {
        final item = hrHistory[i];
        final x = i.toDouble();

        if (item.avgHeartRateBpm != null) {
          avgSpots.add(FlSpot(x, item.avgHeartRateBpm!));
        }
        if (item.minHeartRateBpm != null) {
          minSpots.add(FlSpot(x, item.minHeartRateBpm!));
        }
        if (item.maxHeartRateBpm != null) {
          maxSpots.add(FlSpot(x, item.maxHeartRateBpm!));
        }
      }
    }

    if (avgSpots.isEmpty && minSpots.isEmpty && maxSpots.isEmpty) {
      return const SizedBox.shrink();
    }

    final allY = <double>[];
    allY.addAll(avgSpots.map((e) => e.y));
    allY.addAll(minSpots.map((e) => e.y));
    allY.addAll(maxSpots.map((e) => e.y));

    double minY = allY.isEmpty ? 0 : allY.reduce((a, b) => a < b ? a : b);
    double maxY = allY.isEmpty ? 1 : allY.reduce((a, b) => a > b ? a : b);

    if (minY == maxY) {
      minY = minY - 5;
      maxY = maxY + 5;
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (avgSpots.isNotEmpty
                ? avgSpots.last.x
                : (minSpots.isNotEmpty ? minSpots.last.x : maxSpots.last.x))
            .toDouble(),
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: const Color(0xFFE2EFEC),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: !isTodayMode,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= hrHistory.length) {
                  return const SizedBox.shrink();
                }
                final date = hrHistory[idx].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    date.substring(5),
                    style: TextStyle(
                      fontSize: 10,
                      color: brandMuted,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    fontSize: 10,
                    color: brandMuted,
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          if (minSpots.isNotEmpty)
            LineChartBarData(
              spots: minSpots,
              isCurved: true,
              color: brandMuted.withValues(alpha: 0.7),
              barWidth: 2,
              dashArray: [4, 4],
              dotData: FlDotData(show: false),
            ),
          if (maxSpots.isNotEmpty)
            LineChartBarData(
              spots: maxSpots,
              isCurved: true,
              color: brandMuted.withValues(alpha: 0.7),
              barWidth: 2,
              dashArray: [4, 4],
              dotData: FlDotData(show: false),
            ),
          if (avgSpots.isNotEmpty)
            LineChartBarData(
              spots: avgSpots,
              isCurved: true,
              color: brandDeep,
              barWidth: 3,
              dotData: FlDotData(show: false),
            ),
        ],
      ),
    );
  }
}

// -------------------- Shared row widget --------------------

class _DayRow extends StatelessWidget {
  final String date;
  final String value;

  const _DayRow({required this.date, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFEFE),
        borderRadius: BorderRadius.circular(10),
        border: const Border(
          top: BorderSide(
            color: Color.fromRGBO(31, 95, 99, 0.08),
          ),
          bottom: BorderSide(
            color: Color.fromRGBO(31, 95, 99, 0.08),
          ),
          left: BorderSide(
            color: Color.fromRGBO(31, 95, 99, 0.08),
          ),
          right: BorderSide(
            color: Color.fromRGBO(31, 95, 99, 0.08),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            flex: 3,
            child: Text(
              date,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F3B3A),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 4,
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF2A4948),
              ),
            ),
          ),
        ],
      ),
    );
  }
}