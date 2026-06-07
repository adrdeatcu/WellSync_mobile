// lib/measurement_sync_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/measurement_models.dart';

class MeasurementSyncService {
  final _supabase = Supabase.instance.client;

  Future<void> sendPerMinuteMeasurement(
      PerMinuteMeasurement measurement) async {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      if (kDebugMode) {
        print('No active session; skipping sync');
      }
      return;
    }

    final userId = session.user.id;

    // Include user_id to match your RLS policy: user_id = auth.uid()
    final payload = {
      ...measurement.toJson(),
      'user_id': userId,
    };

    final res =
        await _supabase.from('measurements_minute').insert(payload);

    if (kDebugMode) {
      print('Insert result: $res');
    }
  }
}