// lib/per_minute_aggregator.dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models/measurement_models.dart';

DateTime _bucketFor(DateTime ts) {
  final utc = ts.toUtc();
  return DateTime.utc(utc.year, utc.month, utc.day, utc.hour, utc.minute);
}

class PerMinuteAggregator {
  final Stream<MeasurementSample> samplesStream;

  final StreamController<PerMinuteMeasurement> _perMinuteController =
      StreamController<PerMinuteMeasurement>.broadcast();

  StreamSubscription<MeasurementSample>? _samplesSub;

  // Current bucket state
  DateTime? _currentBucket;
  final List<MeasurementSample> _currentSamples = [];

  PerMinuteAggregator(this.samplesStream);

  Stream<PerMinuteMeasurement> get perMinuteStream =>
      _perMinuteController.stream;

  void start() {
    if (_samplesSub != null) return;
    _samplesSub = samplesStream.listen(_handleSample);
  }

  void _handleSample(MeasurementSample sample) {
    final bucket = _bucketFor(sample.timestamp);

    _currentBucket ??= bucket;

    // If sample belongs to a new minute, flush previous bucket
    if (bucket != _currentBucket) {
      if (_currentSamples.isNotEmpty) {
        final agg = _buildPerMinute(_currentBucket!, _currentSamples);
        _perMinuteController.add(agg);

        if (kDebugMode) {
          print(
            'Per-minute agg emitted for bucket $_currentBucket '
            'with ${_currentSamples.length} samples',
          );
        }
      }
      _currentBucket = bucket;
      _currentSamples.clear();
    }

    _currentSamples.add(sample);
  }

  PerMinuteMeasurement _buildPerMinute(
      DateTime bucket, List<MeasurementSample> samples) {
    // Steps: take the last sample's steps_total_today for that minute
    final stepsTotalToday = samples.last.stepsTotalToday;

    double sumHr = 0;
    double minHr = double.infinity;
    double maxHr = -double.infinity;
    int hrCount = 0;

    double sumSpo2 = 0;
    int spo2Count = 0;

    double sumAqi = 0;
    int aqiCount = 0;

    double sumTemp = 0;
    int tempCount = 0;

    double sumHum = 0;
    int humCount = 0;

    double sumPress = 0;
    int pressCount = 0;

    for (final s in samples) {
      final hr = s.heartRateBpm;
      if (!hr.isNaN) {
        sumHr += hr;
        minHr = hr < minHr ? hr : minHr;
        maxHr = hr > maxHr ? hr : maxHr;
        hrCount++;
      }

      final spo2 = s.spo2;
      if (!spo2.isNaN) {
        sumSpo2 += spo2;
        spo2Count++;
      }

      final aqi = s.airQualityIndex;
      if (!aqi.isNaN) {
        sumAqi += aqi;
        aqiCount++;
      }

      final temp = s.temperatureC;
      if (!temp.isNaN) {
        sumTemp += temp;
        tempCount++;
      }

      final hum = s.humidityPercent;
      if (!hum.isNaN) {
        sumHum += hum;
        humCount++;
      }

      final press = s.pressureHpa;
      if (!press.isNaN) {
        sumPress += press;
        pressCount++;
      }
    }

    double? avgHr;
    double? minHrOut;
    double? maxHrOut;
    if (hrCount > 0) {
      avgHr = sumHr / hrCount;
      minHrOut = minHr;
      maxHrOut = maxHr;
    }

    double? avgSpo2;
    if (spo2Count > 0) {
      avgSpo2 = sumSpo2 / spo2Count;
    }

    double? avgAqi;
    if (aqiCount > 0) {
      avgAqi = sumAqi / aqiCount;
    }

    double? avgTemp;
    if (tempCount > 0) {
      avgTemp = sumTemp / tempCount;
    }

    double? avgHum;
    if (humCount > 0) {
      avgHum = sumHum / humCount;
    }

    double? avgPress;
    if (pressCount > 0) {
      avgPress = sumPress / pressCount;
    }

    return PerMinuteMeasurement(
      timestampMinuteUtc: bucket,
      stepsTotalToday: stepsTotalToday,
      avgHeartRateBpm: avgHr,
      minHeartRateBpm: minHrOut,
      maxHeartRateBpm: maxHrOut,
      avgSpo2: avgSpo2,
      avgAirQualityIndex: avgAqi,
      avgTemperatureC: avgTemp,
      avgHumidityPercent: avgHum,
      avgPressureHpa: avgPress,
    );
  }

  Future<void> flushAndStop() async {
    // Flush current bucket when stopping
    if (_currentBucket != null && _currentSamples.isNotEmpty) {
      final agg = _buildPerMinute(_currentBucket!, _currentSamples);
      _perMinuteController.add(agg);

      if (kDebugMode) {
        print(
          'Per-minute agg emitted on flush for bucket $_currentBucket '
          'with ${_currentSamples.length} samples',
        );
      }
    }
    _currentBucket = null;
    _currentSamples.clear();

    await _samplesSub?.cancel();
    _samplesSub = null;
  }

  Future<void> dispose() async {
    await flushAndStop();
    await _perMinuteController.close();
  }
}