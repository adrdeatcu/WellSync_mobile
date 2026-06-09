// lib/coach_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class CoachAdvice {
  final String summary;
  final List<String> actionSteps;

  CoachAdvice({required this.summary, required this.actionSteps});
}

class CoachService {
  final SupabaseClient supabase;
  final String backendBaseUrl;

  CoachService({
    required this.supabase,
    required this.backendBaseUrl,
  });

  Future<CoachAdvice> askCoach({required String question}) async {
    final session = supabase.auth.currentSession;
    final user = session?.user;
    if (user == null) {
      throw Exception('You must be logged in to use the coach.');
    }

    final body = {
      'userId': user.id,
      'question': question,
    };

    final url = Uri.parse('$backendBaseUrl/api/coach/daily');

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) {
      throw Exception(
        'Coach backend error: ${res.statusCode} - ${res.body}',
      );
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;

    final summary = json['summary'] as String? ?? '';
    final actionStepsRaw = json['actionSteps'] as List<dynamic>? ?? [];

    final actionSteps = actionStepsRaw
        .whereType<String>()
        .toList();

    return CoachAdvice(summary: summary, actionSteps: actionSteps);
  }
}