// lib/mobile_history_page.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  List<StepsHistoryItem> _stepsHistory = [];
  List<HeartRateHistoryItem> _hrHistory = [];

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

      // Compute date range in UTC: same logic as backend
      final now = DateTime.now().toUtc();
      final endDate = DateTime.utc(now.year, now.month, now.day);
      final startDate =
          endDate.subtract(Duration(days: days - 1)); // inclusive range

      final startStr = _formatDate(startDate);
      final endStr = _formatDate(endDate);

      // Fetch from daily_stats for this user and range
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
          .eq('user_id', user.id)
          .gte('date', startStr)
          .lte('date', endStr)
          .order('date', ascending: true);

      final rows = res as List<dynamic>;

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

      setState(() {
        _rangeDays = days;
        _stepsHistory = steps;
        _hrHistory = hr;
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

  String _formatDate(DateTime d) {
    // Format as YYYY-MM-DD
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
                    _HistoryCard(
                      title: 'Steps per day',
                      subtitle: 'Daily total over the selected range',
                      brandBorder: brandBorder,
                      brandMuted: brandMuted,
                      brandDeep: brandDeep,
                      children: _stepsHistory.isEmpty
                          ? const [
                              Text(
                                'No steps history for this range yet.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ]
                          : _stepsHistory
                              .map(
                                (item) => _DayRow(
                                  date: item.date,
                                  value:
                                      '${item.totalSteps.toString()} steps',
                                ),
                              )
                              .toList(),
                    ),
                    const SizedBox(height: 16),
                    _HistoryCard(
                      title: 'Heart rate per day',
                      subtitle: 'Average bpm with daily min and max',
                      brandBorder: brandBorder,
                      brandMuted: brandMuted,
                      brandDeep: brandDeep,
                      children: _hrHistory.isEmpty
                          ? const [
                              Text(
                                'No heart-rate history for this range yet.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ]
                          : _hrHistory
                              .map(
                                (item) => _DayRow(
                                  date: item.date,
                                  value: _formatHrRow(item),
                                ),
                              )
                              .toList(),
                    ),
                  ],
                ),
              ),
          ],
        ),
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

class _HistoryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color brandBorder;
  final Color brandMuted;
  final Color brandDeep;
  final List<Widget> children;

  const _HistoryCard({
    required this.title,
    required this.subtitle,
    required this.brandBorder,
    required this.brandMuted,
    required this.brandDeep,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
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
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: brandDeep,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: brandMuted,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

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
          Text(
            date,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F3B3A),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF2A4948),
            ),
          ),
        ],
      ),
    );
  }
}