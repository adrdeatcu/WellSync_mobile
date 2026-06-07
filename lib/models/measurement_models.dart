// lib/models/measurement_models.dart
class MeasurementSample {
  final DateTime timestamp;
  final int stepsTotalToday;
  final double heartRateBpm;
  final double spo2;
  final double airQualityIndex;
  final double temperatureC;
  final double humidityPercent;
  final double pressureHpa;

  MeasurementSample({
    required this.timestamp,
    required this.stepsTotalToday,
    required this.heartRateBpm,
    required this.spo2,
    required this.airQualityIndex,
    required this.temperatureC,
    required this.humidityPercent,
    required this.pressureHpa,
  });

  factory MeasurementSample.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now().toUtc();

    return MeasurementSample(
      timestamp: now, // we timestamp on phone; ignore timestamp_ms for now
      stepsTotalToday: (json['steps_total_today'] as num).toInt(),
      heartRateBpm: (json['heart_rate_bpm'] as num).toDouble(),
      spo2: (json['spo2'] as num).toDouble(),
      airQualityIndex: (json['air_quality_index'] as num).toDouble(),
      temperatureC: (json['temperature_c'] as num).toDouble(),
      humidityPercent: (json['humidity_percent'] as num).toDouble(),
      pressureHpa: (json['pressure_hpa'] as num).toDouble(),
    );
  }
}

class PerMinuteMeasurement {
  final DateTime timestampMinuteUtc;
  final int stepsTotalToday;
  final double? avgHeartRateBpm;
  final double? minHeartRateBpm;
  final double? maxHeartRateBpm;
  final double? avgSpo2;
  final double? avgAirQualityIndex;
  final double? avgTemperatureC;
  final double? avgHumidityPercent;
  final double? avgPressureHpa;

  PerMinuteMeasurement({
    required this.timestampMinuteUtc,
    required this.stepsTotalToday,
    this.avgHeartRateBpm,
    this.minHeartRateBpm,
    this.maxHeartRateBpm,
    this.avgSpo2,
    this.avgAirQualityIndex,
    this.avgTemperatureC,
    this.avgHumidityPercent,
    this.avgPressureHpa,
  });

  Map<String, dynamic> toJson() => {
        'timestamp_minute_utc': timestampMinuteUtc.toUtc().toIso8601String(),
        'steps_total_today': stepsTotalToday,
        'avg_heart_rate_bpm': avgHeartRateBpm,
        'min_heart_rate_bpm': minHeartRateBpm,
        'max_heart_rate_bpm': maxHeartRateBpm,
        'avg_spo2': avgSpo2,
        'avg_air_quality_index': avgAirQualityIndex,
        'avg_temperature_c': avgTemperatureC,
        'avg_humidity_percent': avgHumidityPercent,
        'avg_pressure_hpa': avgPressureHpa,
      };
}