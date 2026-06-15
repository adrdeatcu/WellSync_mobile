// lib/mobile_emergency_alert_page.dart
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class MobileEmergencyAlertPage extends StatefulWidget {
  final String emergencyContactName;
  final String emergencyContactPhone;
  final String address; // initial / fallback address

  const MobileEmergencyAlertPage({
    super.key,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    required this.address,
  });

  @override
  State<MobileEmergencyAlertPage> createState() =>
      _MobileEmergencyAlertPageState();
}

class _MobileEmergencyAlertPageState extends State<MobileEmergencyAlertPage> {
  static const int _initialSeconds = 60;
  int _secondsLeft = _initialSeconds;
  Timer? _timer;

  late final AudioPlayer _audioPlayer;
  bool _alertActive = false;
  bool _finished = false; // to avoid double actions

  bool _resolvingLocation = false;
  String? _resolvedAddress;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _startCountdown();
    _startAlertFeedback();
    _startResolveLocation();
  }

  @override
  void dispose() {
    _stopAlertFeedback();
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _secondsLeft = _initialSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      setState(() {
        _secondsLeft--;
      });

      if (_secondsLeft <= 0) {
        timer.cancel();
        _handleTimeout();
      }
    });
  }

  Future<void> _startAlertFeedback() async {
    _alertActive = true;

    // Loop a short alert tone quietly in background
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(
      AssetSource('sounds/alert_tone.mp3'),
      volume: 0.6,
    );
  }

  Future<void> _stopAlertFeedback() async {
    if (!_alertActive) return;
    _alertActive = false;
    await _audioPlayer.stop();
  }

  Future<void> _startResolveLocation() async {
    setState(() {
      _resolvingLocation = true;
      _locationError = null;
    });

    try {
      // 1) Check & request permission
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        setState(() {
          _locationError = 'Location permission denied';
          _resolvingLocation = false;
        });
        return;
      }

      // 2) Ensure location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError =
              'Location services are disabled. Please enable GPS/location on your phone.';
          _resolvingLocation = false;
        });
        return;
      }

      // 3) Get current position with new LocationSettings API
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // 4) Reverse geocode
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isEmpty) {
        setState(() {
          _locationError = 'Could not resolve location';
          _resolvingLocation = false;
        });
        return;
      }

      final p = placemarks.first;

      // Build a friendly single-line address
      final parts = <String>[];
      if ((p.street ?? '').isNotEmpty) parts.add(p.street!);
      if ((p.subLocality ?? '').isNotEmpty) parts.add(p.subLocality!);
      if ((p.locality ?? '').isNotEmpty) parts.add(p.locality!);
      if ((p.administrativeArea ?? '').isNotEmpty) {
        parts.add(p.administrativeArea!);
      }
      if ((p.country ?? '').isNotEmpty) parts.add(p.country!);

      final addressLine = parts.isNotEmpty
          ? parts.join(', ')
          : widget.address; // fallback to passed address

      if (!mounted) return;
      setState(() {
        _resolvedAddress = addressLine;
        _resolvingLocation = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationError = 'Error getting location: $e';
        _resolvingLocation = false;
      });
    }
  }

  Future<void> _handleImOk() async {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    await _stopAlertFeedback();
    if (!mounted) return;
    Navigator.of(context).pop(); // simply close alert
  }

  Future<void> _handleCallEmergencyContact() async {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    await _stopAlertFeedback();

    final telUri = Uri(scheme: 'tel', path: widget.emergencyContactPhone);

    if (await canLaunchUrl(telUri)) {
      await launchUrl(telUri);
    }

    if (!mounted) return;
    Navigator.of(context).pop(); // pop the alert after launching dialer
  }

  Future<void> _handleTimeout() async {
    if (_finished) return;
    _finished = true;
    await _stopAlertFeedback();

    if (!mounted) return;

    // For now: show a demo dialog instead of real backend call.
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Demo: automatic call'),
          content: Text(
            'In a real scenario, an automatic call to '
            '${widget.emergencyContactName} would be placed now.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    if (mounted) {
      Navigator.of(context).pop(); // Close the emergency page
    }
  }

  @override
  Widget build(BuildContext context) {
    final brandDeep = const Color(0xFF1F5F63);
    final brandMuted = const Color(0xFF5D7B79);
    final brandBorder = const Color(0xFFD8E9E6);

    final addressToShow = _resolvedAddress ??
        (_resolvingLocation
            ? 'Resolving location…'
            : _locationError ?? widget.address); // fallback to original

    // Prevent back button: must choose or wait for timeout
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        // Do nothing; we block back.
      },
      child: Scaffold(
        backgroundColor:
            const Color(0xFF111827).withValues(alpha: 0.94),
        body: SafeArea(
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: brandBorder),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.25),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEE2E2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.health_and_safety,
                          color: Color(0xFFB91C1C),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Possible fall detected',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'If you do not respond in the next '
                    '$_secondsLeft seconds, a demo automatic call to '
                    '${widget.emergencyContactName} will be triggered.',
                    style: TextStyle(
                      fontSize: 13,
                      color: brandMuted,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Countdown pill
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFFB91C1C).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color:
                              const Color(0xFFB91C1C).withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.timer,
                            size: 18,
                            color: Color(0xFFB91C1C),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$_secondsLeft s remaining',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFB91C1C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Location section
                  const Text(
                    'Approximate location',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F3B3A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4FAF8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: brandBorder),
                    ),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: Color(0xFF4B5563),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            addressToShow,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _handleImOk,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: brandBorder),
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'I\'m OK',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _handleCallEmergencyContact,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandDeep,
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Call ${widget.emergencyContactName}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This is a demo. No real emergency services are contacted automatically.',
                    style: TextStyle(
                      fontSize: 11,
                      color: brandMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}