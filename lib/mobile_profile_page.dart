// lib/mobile_profile_page.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MobileProfilePage extends StatefulWidget {
  const MobileProfilePage({super.key});

  @override
  State<MobileProfilePage> createState() => _MobileProfilePageState();
}

class _MobileProfilePageState extends State<MobileProfilePage> {
  final _supabase = Supabase.instance.client;

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _success;

  // Form fields
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _stepGoalController = TextEditingController();

  String? _activityLevel; // sedentary, lightly_active, etc.

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
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

      final res = await _supabase
          .from('profiles')
          .select(
            'username, full_name, age, height_cm, weight_kg, activity_level, step_goal_per_day, high_hr_threshold, low_spo2_threshold, poor_air_quality_threshold',
          )
          .eq('id', user.id)
          .maybeSingle();

      if (res == null) {
        // No row; initialize defaults
        _usernameController.text = '';
        _fullNameController.text = '';
        _ageController.text = '';
        _heightController.text = '';
        _weightController.text = '';
        _activityLevel = null;
        _stepGoalController.text = '10000';
      } else {
        _usernameController.text = (res['username'] as String?) ?? '';
        _fullNameController.text = (res['full_name'] as String?) ?? '';
        _ageController.text = (res['age'] as int?)?.toString() ?? '';
        _heightController.text =
            (res['height_cm'] as num?)?.toString() ?? '';
        _weightController.text =
            (res['weight_kg'] as num?)?.toString() ?? '';
        _activityLevel = (res['activity_level'] as String?);
        _stepGoalController.text =
            (res['step_goal_per_day'] as int?)?.toString() ?? '10000';
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading profile: $e');
      }
      setState(() {
        _error = 'Error loading profile';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _error = 'You are not logged in.';
        });
        return;
      }

      int? parseIntOrNull(String text) {
        final t = text.trim();
        if (t.isEmpty) return null;
        return int.tryParse(t);
      }

      double? parseDoubleOrNull(String text) {
        final t = text.trim();
        if (t.isEmpty) return null;
        return double.tryParse(t);
      }

      final age = parseIntOrNull(_ageController.text);
      final heightCm = parseDoubleOrNull(_heightController.text);
      final weightKg = parseDoubleOrNull(_weightController.text);
      final stepGoal = parseIntOrNull(_stepGoalController.text) ?? 10000;

      final update = <String, dynamic>{
        'username': _usernameController.text.trim().isEmpty
            ? null
            : _usernameController.text.trim(),
        'full_name': _fullNameController.text.trim().isEmpty
            ? null
            : _fullNameController.text.trim(),
        'age': age,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'activity_level': _activityLevel,
        'step_goal_per_day': stepGoal,
      };

      final res = await _supabase
          .from('profiles')
          .update(update)
          .eq('id', user.id)
          .select(
            'username, full_name, age, height_cm, weight_kg, activity_level, step_goal_per_day, high_hr_threshold, low_spo2_threshold, poor_air_quality_threshold',
          )
          .maybeSingle();

      if (res == null) {
        setState(() {
          _error = 'Failed to save profile';
        });
      } else {
        setState(() {
          _success = 'Profile updated';
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving profile: $e');
      }
      setState(() {
        _error = 'Error saving profile';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _stepGoalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brandDeep = const Color(0xFF1F5F63);
    final brandBorder = const Color(0xFFD8E9E6);
    final brandMuted = const Color(0xFF5D7B79);

    InputDecoration fieldDecoration(String label, {String? hint}) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF6FBFA),
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFF2C4F4D),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: brandBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: brandBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: brandDeep),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      );
    }

    Widget buildErrorBanner(String message) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFDECEC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFFF5C2C0),
          ),
        ),
        child: Text(
          message,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFFB3261E),
          ),
        ),
      );
    }

    Widget buildSuccessBanner(String message) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE6F4EA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF9AD0A3),
          ),
        ),
        child: Text(
          message,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF166534),
          ),
        ),
      );
    }

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: brandDeep,
      ),
      body: Container(
        width: double.infinity,
        color: const Color(0xFFEAF5F3),
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              if (_error != null) buildErrorBanner(_error!),
              if (_success != null) buildSuccessBanner(_success!),
              Container(
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
                    const Text(
                      'Personal details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F3B3A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Update your info so WellSync can stay in tune with you.',
                      style: TextStyle(
                        fontSize: 13,
                        color: brandMuted,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Username
                    TextField(
                      controller: _usernameController,
                      decoration: fieldDecoration(
                        'Username',
                        hint: 'Choose a unique username',
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Full name
                    TextField(
                      controller: _fullNameController,
                      decoration: fieldDecoration(
                        'Full name',
                        hint: 'Your full name',
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Age / Height / Weight
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ageController,
                            keyboardType: TextInputType.number,
                            decoration: fieldDecoration(
                              'Age',
                              hint: 'Years',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _heightController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: fieldDecoration(
                              'Height (cm)',
                              hint: 'e.g. 170',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _weightController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: fieldDecoration(
                              'Weight (kg)',
                              hint: 'e.g. 65.5',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Activity level
                    InputDecorator(
                      decoration: fieldDecoration('Activity level'),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _activityLevel,
                          isDense: true,
                          isExpanded: true,
                          hint: const Text('Select activity level'),
                          items: const [
                            DropdownMenuItem(
                              value: 'sedentary',
                              child: Text('Sedentary'),
                            ),
                            DropdownMenuItem(
                              value: 'lightly_active',
                              child: Text('Lightly active'),
                            ),
                            DropdownMenuItem(
                              value: 'moderately_active',
                              child: Text('Moderately active'),
                            ),
                            DropdownMenuItem(
                              value: 'very_active',
                              child: Text('Very active'),
                            ),
                            DropdownMenuItem(
                              value: 'athlete',
                              child: Text('Athlete'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _activityLevel = value;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Step goal
                    TextField(
                      controller: _stepGoalController,
                      keyboardType: TextInputType.number,
                      decoration: fieldDecoration(
                        'Daily step goal',
                        hint: 'e.g. 10000',
                      ),
                    ),
                    const SizedBox(height: 24),

                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandDeep,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          _saving ? 'Saving…' : 'Save changes',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}