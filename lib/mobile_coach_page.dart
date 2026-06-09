// lib/mobile_coach_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'coach_service.dart';
import 'config.dart'; // where AppConfig.backendBaseUrl lives

class CoachMessage {
  final String id;
  final String from; // 'user' or 'coach'
  final String text;

  CoachMessage({
    required this.id,
    required this.from,
    required this.text,
  });
}

class MobileCoachPage extends StatefulWidget {
  const MobileCoachPage({super.key});

  @override
  State<MobileCoachPage> createState() => _MobileCoachPageState();
}

class _MobileCoachPageState extends State<MobileCoachPage> {
  late final CoachService _coachService;

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<CoachMessage> _messages = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final supabase = Supabase.instance.client;
    _coachService = CoachService(
      supabase: supabase,
      backendBaseUrl: AppConfig.backendBaseUrl,
    );

    _messages.add(
      CoachMessage(
        id: 'greeting',
        from: 'coach',
        text: 'Hi, I’m your WellSync Coach. How can I help you today?',
      ),
    );

    // Keep button enabled/disabled in sync with text content
    _inputController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _loading) return;

    setState(() {
      _error = null;
      _loading = true;
      _messages.add(
        CoachMessage(
          id: 'user-${DateTime.now().millisecondsSinceEpoch}',
          from: 'user',
          text: text,
        ),
      );
      _inputController.clear();
    });

    _scrollToBottomDelayed();

    try {
      final advice = await _coachService.askCoach(question: text);

      final coachText = advice.actionSteps.isNotEmpty
          ? '${advice.summary}\n\n${advice.actionSteps.map((s) => '• $s').join('\n')}'
          : advice.summary;

      setState(() {
        _messages.add(
          CoachMessage(
            id: 'coach-${DateTime.now().millisecondsSinceEpoch}',
            from: 'coach',
            text: coachText,
          ),
        );
      });

      _scrollToBottomDelayed();
    } catch (e) {
      setState(() {
        _error =
            'The coach could not answer right now. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _scrollToBottomDelayed() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final brandDeep = const Color(0xFF1F5F63);
    final brandMuted = const Color(0xFF5D7B79);
    final brandBorder = const Color(0xFFD8E9E6);

    final canSend =
        !_loading && _inputController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('WellSync Coach'),
        backgroundColor: brandDeep,
      ),
      body: Container(
        width: double.infinity,
        color: const Color(0xFFEAF5F3),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: brandBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ask your coach',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F3B3A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ask about your progress, activity, or habits. Your recent data helps tailor the advice.',
                    style: TextStyle(
                      fontSize: 13,
                      color: brandMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
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

            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4FAF8),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: brandBorder),
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _messages.length + (_loading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_loading && index == _messages.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Coach is thinking…',
                          style: TextStyle(
                            fontSize: 12,
                            color: brandMuted,
                          ),
                        ),
                      );
                    }

                    final msg = _messages[index];
                    final isUser = msg.from == 'user';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: isUser
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isUser) ...[
                            Container(
                              width: 28,
                              height: 28,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE4F3F0),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: const Icon(
                                Icons.smart_toy,
                                size: 18,
                                color: Color(0xFF1F5F63),
                              ),
                            ),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(4),
                                    topRight: Radius.circular(14),
                                    bottomLeft: Radius.circular(14),
                                    bottomRight: Radius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  msg.text,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF1F3B3A),
                                  ),
                                ),
                              ),
                            ),
                          ] else ...[
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFF1F5F63),
                                      Color(0xFF7CC2B5),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(14),
                                    topRight: Radius.circular(4),
                                    bottomLeft: Radius.circular(14),
                                    bottomRight: Radius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  msg.text,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText:
                          'Ask something like “What should I focus on today?”',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: brandBorder),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: canSend ? _handleSend : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandDeep,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _loading ? 'Sending…' : 'Send',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}