// lib/mobile_dashboard_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ble_measurement_service.dart';
import 'models/measurement_models.dart';
import 'login_page.dart';

class MobileDashboardPage extends StatefulWidget {
  const MobileDashboardPage({super.key});

  @override
  State<MobileDashboardPage> createState() => _MobileDashboardPageState();
}

class _MobileDashboardPageState extends State<MobileDashboardPage> {
  final _bleService = BleMeasurementService();
  MeasurementSample? _latestSample;
  StreamSubscription<MeasurementSample>? _sampleSub;

  @override
  void initState() {
    super.initState();
    _sampleSub = _bleService.samplesStream.listen((sample) {
      setState(() {
        _latestSample = sample;
      });
    });
  }

  @override
  void dispose() {
    _sampleSub?.cancel();
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

  Widget _buildStatTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8E9E6)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(31, 95, 99, 0.12),
            blurRadius: 16,
            offset: Offset(0, 8),
            spreadRadius: -6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF5D7B79),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F3B3A),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sample = _latestSample;

    return Scaffold(
      appBar: AppBar(
        title: const Text('WellSync Mobile Dashboard'),
        actions: [
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
            // BLE status + connect button
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
                        onPressed: () {
                          if (!connected) {
                            _bleService.connectAndListen();
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

            if (sample == null)
              const Text(
                'No live data yet. Connect to your watch to start streaming.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              )
            else
              Expanded(
                child: ListView(
                  children: [
                    Text(
                      'Latest sample at ${sample.timestamp.toLocal()}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.8,
                      children: [
                        _buildStatTile(
                          'Steps today',
                          sample.stepsTotalToday.toString(),
                        ),
                        _buildStatTile(
                          'Heart rate',
                          '${sample.heartRateBpm.toStringAsFixed(1)} bpm',
                        ),
                        _buildStatTile(
                          'SpO₂',
                          '${sample.spo2.toStringAsFixed(1)} %',
                        ),
                        _buildStatTile(
                          'Air quality',
                          sample.airQualityIndex.toStringAsFixed(1),
                        ),
                        _buildStatTile(
                          'Temperature',
                          '${sample.temperatureC.toStringAsFixed(1)} °C',
                        ),
                        _buildStatTile(
                          'Humidity',
                          '${sample.humidityPercent.toStringAsFixed(1)} %',
                        ),
                        _buildStatTile(
                          'Pressure',
                          '${sample.pressureHpa.toStringAsFixed(1)} hPa',
                        ),
                      ],
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