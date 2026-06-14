// lib/activity_chat_page.dart
import 'package:flutter/material.dart';

import 'community_repository.dart';
import 'models/community_models.dart';

class ActivityChatPage extends StatefulWidget {
  final CommunityActivity activity;
  final CommunityRepository repo;

  const ActivityChatPage({
    super.key,
    required this.activity,
    required this.repo,
  });

  @override
  State<ActivityChatPage> createState() => _ActivityChatPageState();
}

class _ActivityChatPageState extends State<ActivityChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _loading = false;
  String? _error;
  bool _sending = false;

  List<ActivityMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged); // ensure button rebuilds
    _loadMessages();
  }

  void _onTextChanged() {
    // Rebuild so the Send button updates its enabled state
    setState(() {});
  }

  Future<void> _loadMessages() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final msgs =
          await widget.repo.listActivityMessages(widget.activity.id);
      if (!mounted) return;
      setState(() {
        _messages = msgs;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load messages: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _sending = true;
    });

    try {
      final msg = await widget.repo.sendActivityMessage(
        activityId: widget.activity.id,
        content: text,
      );
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, msg];
        _controller.clear();
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const brandBg = Color(0xFFEAF5F3);
    const brandBorder = Color(0xFFD8E9E6);
    const brandText = Color(0xFF1F3B3A);
    const brandMuted = Color(0xFF5D7B79);
    const brandDeep = Color(0xFF1F5F63);

    return Scaffold(
      backgroundColor: brandBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: brandText,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.activity.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Activity chat · ${widget.activity.city}',
              style: const TextStyle(
                fontSize: 12,
                color: brandMuted,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.red.shade50,
              child: Text(
                _error!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                ),
              ),
            ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: brandBorder),
                color: const Color(0xFFF5FAF8),
              ),
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _messages.isEmpty
                      ? const Center(
                          child: Text(
                            'No messages yet. Start the conversation!',
                            style: TextStyle(
                              fontSize: 13,
                              color: brandMuted,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final m = _messages[index];
                            final ts =
                                m.createdAt.toLocal().toString(); // simple format
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white,
                                border: Border.all(
                                  color: const Color(0x0F1F5F63),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          m.senderName,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: brandDeep,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        ts,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: brandMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    m.content,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: brandText,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Write a message...',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: const BorderSide(color: brandBorder),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _sending || _controller.text.trim().isEmpty
                      ? null
                      : _handleSend,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandDeep,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: Text(
                    _sending ? 'Sending…' : 'Send',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}