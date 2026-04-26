// ============================================================================
// Trip-GUY — Travel Super-App
// Copyright (c) 2026 Gnanasekaran D. All Rights Reserved.
//
// PROPRIETARY AND CONFIDENTIAL
//
// This source code and all associated files are the exclusive intellectual
// property of Gnanasekaran D. Unauthorized copying, modification, distribution,
// or use of this file, via any medium, is strictly prohibited.
//
// Contact : sgnana238@gmail.com | +91 8248094569
// Country : India
// License : See LICENSE file at the project root for full terms.
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../../core/theme/colors.dart';

class _ChatMessage {
  final String text;
  final bool isBot;
  final DateTime time;
  const _ChatMessage({required this.text, required this.isBot, required this.time});
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-page wrapper with premium gradient AppBar
// ─────────────────────────────────────────────────────────────────────────────

class AiAssistantFullPage extends StatelessWidget {
  const AiAssistantFullPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2453E0), Color(0xFF4272FF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: [
                // Back
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                // Bot avatar
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withAlpha(60), width: 1.5),
                  ),
                  child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 10),
                Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('TripBot AI',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Row(children: [
                    Container(width: 7, height: 7,
                      decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    const Text('Powered by Gemini · Online',
                      style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ]),
                ]),
                const Spacer(),
                // Clear chat button
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withAlpha(50)),
                  ),
                  child: const Text('Gemini Pro', style: TextStyle(color: Colors.white70, fontSize: 11)),
                ),
              ]),
            ),
          ),
        ),
      ),
      body: const AiAssistantPage(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Core chat content
// ─────────────────────────────────────────────────────────────────────────────

class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({super.key});
  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  late final ChatSession _chatSession;
  bool _isTyping = false;
  bool _isInitialized = false;

  final List<_ChatMessage> _messages = [
    _ChatMessage(
      text: "Hi! I'm TripBot — your AI travel companion powered by Google Gemini. ✈️\n\nAsk me to plan an itinerary, estimate expenses, suggest destinations, or give you packing tips!",
      isBot: true,
      time: DateTime.now(),
    ),
  ];

  // 8 quick-prompt categories
  final List<Map<String, dynamic>> _quickPrompts = [
    {'icon': '🗺️', 'label': 'Plan itinerary'},
    {'icon': '💰', 'label': 'Budget tips'},
    {'icon': '🏖️', 'label': 'Beach destinations'},
    {'icon': '🎒', 'label': 'Packing list'},
    {'icon': '🏔️', 'label': 'Mountain trips'},
    {'icon': '🍜', 'label': 'Food guide'},
    {'icon': '🛂', 'label': 'Visa guide'},
    {'icon': '🚂', 'label': 'Train travel'},
  ];

  @override
  void initState() {
    super.initState();
    _initializeAI();
  }

  void _initializeAI() {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      setState(() {
        _messages.add(_ChatMessage(
          text: "⚠️ API key missing. Please check your .env file.",
          isBot: true, time: DateTime.now()));
      });
      return;
    }
    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      systemInstruction: Content.system(
        'You are TripBot, a friendly expert travel assistant inside a mobile app. '
        'Keep answers concise and mobile-friendly. Use bullet points. '
        'Max 120 words per response. Use emojis sparingly for friendliness.'),
    );
    _chatSession = model.startChat();
    _isInitialized = true;
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || !_isInitialized) return;
    final userText = text.trim();
    _controller.clear();
    setState(() {
      _messages.add(_ChatMessage(text: userText, isBot: false, time: DateTime.now()));
      _isTyping = true;
    });
    _scrollToBottom();
    try {
      final response = await _chatSession.sendMessage(Content.text(userText));
      if (mounted) {
        setState(() {
          _isTyping = false;
          final cleanText = response.text?.replaceAll('**', '') ?? "I couldn't process that.";
          _messages.add(_ChatMessage(text: cleanText, isBot: true, time: DateTime.now()));
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(_ChatMessage(
            text: "Network error. Please check your connection.",
            isBot: true, time: DateTime.now()));
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(120.ms, () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(children: [
      // ── Messages list ──────────────────────────────────────
      Expanded(
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(14, 90, 14, 14),
          itemCount: _messages.length + (_isTyping ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _messages.length && _isTyping) {
              return _buildTypingBubble(isDark);
            }
            final msg = _messages[index];
            return _buildMessageBubble(context, msg, isDark);
          },
        ),
      ),

      // ── Quick prompts (visible until 3rd message) ──────────
      if (_messages.length <= 2 && !_isTyping)
        Container(
          height: 42,
          color: Theme.of(context).colorScheme.surface,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: _quickPrompts.length,
            itemBuilder: (context, i) {
              final p = _quickPrompts[i];
              return GestureDetector(
                onTap: () => _sendMessage('${p['label']}'),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF2453E0), Color(0xFF4272FF)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(p['icon'] as String, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 4),
                    Text(p['label'] as String,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                  ]),
                ),
              );
            },
          ),
        ).animate().fade(duration: 300.ms),

      // ── Input bar ─────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 12, offset: const Offset(0, -3))],
        ),
        child: Row(children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.primary.withAlpha(40)),
              ),
              child: TextField(
                controller: _controller,
                enabled: !_isTyping,
                onSubmitted: _sendMessage,
                decoration: const InputDecoration(
                  hintText: 'Ask TripBot anything...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(fontSize: 13),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isTyping ? null : () => _sendMessage(_controller.text),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: _isTyping
                    ? null
                    : const LinearGradient(colors: [Color(0xFF2453E0), Color(0xFF4272FF)]),
                color: _isTyping ? Colors.grey[300] : null,
                shape: BoxShape.circle,
                boxShadow: _isTyping ? [] : [BoxShadow(
                  color: AppColors.primary.withAlpha(80), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Icon(Icons.send_rounded,
                color: _isTyping ? Colors.grey : Colors.white, size: 20),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _buildMessageBubble(BuildContext context, _ChatMessage msg, bool isDark) {
    final isBot = msg.isBot;
    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
        margin: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            if (isBot)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 3),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFF2453E0), Color(0xFF4272FF)]),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 12),
                  ),
                  const SizedBox(width: 5),
                  const Text('TripBot', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                ]),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isBot ? null : const LinearGradient(
                  colors: [Color(0xFF2453E0), Color(0xFF4272FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                color: isBot ? (isDark ? const Color(0xFF1C2A3A) : const Color(0xFFEBF4FF)) : null,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isBot ? 4 : 18),
                  bottomRight: Radius.circular(isBot ? 18 : 4),
                ),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Text(msg.text,
                style: TextStyle(
                  color: isBot
                      ? (isDark ? Colors.white : const Color(0xFF1A1A1A))
                      : Colors.white,
                  fontSize: 13.5,
                  height: 1.5,
                )),
            ),
          ],
        ),
      ).animate().fade(duration: 250.ms).scale(begin: const Offset(0.92, 0.92)),
    );
  }

  Widget _buildTypingBubble(bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C2A3A) : const Color(0xFFEBF4FF),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _Dot(delay: 0),
          const SizedBox(width: 4),
          _Dot(delay: 150),
          const SizedBox(width: 4),
          _Dot(delay: 300),
        ]),
      ).animate().fade(duration: 200.ms),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated typing dot
// ─────────────────────────────────────────────────────────────────────────────
class _Dot extends StatelessWidget {
  final int delay;
  const _Dot({required this.delay});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
    )
    .animate(onPlay: (c) => c.repeat())
    .moveY(begin: 0, end: -5, delay: Duration(milliseconds: delay), duration: 400.ms, curve: Curves.easeInOut)
    .then()
    .moveY(begin: -5, end: 0, duration: 400.ms, curve: Curves.easeInOut);
  }
}
