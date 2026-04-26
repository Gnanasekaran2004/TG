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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../../injection_container.dart' as di;
import '../../data/datasources/firebase_chat_datasource.dart';

// ─────────────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────────────

enum MessageType { text, image, tripCard, audio }

enum MessageStatus { sending, sent, delivered, read }

class ChatMessage {
  final String id;
  final String text;
  final bool isMe;
  final DateTime timestamp;
  final MessageType type;
  MessageStatus status;
  String? reaction;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isMe,
    required this.timestamp,
    this.type = MessageType.text,
    this.status = MessageStatus.read,
    this.reaction,
  });
}

class ChatContact {
  final String id;
  final String name;
  final Color avatarColor;
  final bool isOnline;
  final String lastSeen;
  final String mutualTrip;
  final String? photoBase64;

  const ChatContact({
    required this.id,
    required this.name,
    required this.avatarColor,
    required this.isOnline,
    required this.lastSeen,
    required this.mutualTrip,
    this.photoBase64,
  });
}

// ─────────────────────────────────────────────────────
// Chat Screen (Live from Firestore)
// ─────────────────────────────────────────────────────

class ChatScreen extends StatefulWidget {
  final ChatContact contact;

  const ChatScreen({super.key, required this.contact});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _isTyping = false;

  late final Stream<QuerySnapshot> _messagesStream;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    // 1. Open the live pipe to the unique chat room for these two users
    _messagesStream = di.sl<FirebaseChatDataSource>().streamMessages(
      widget.contact.id,
    );
    // 2. Mark all unread messages from this contact as read
    di.sl<FirebaseChatDataSource>().markMessagesAsRead(widget.contact.id);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    setState(() => _isTyping = false);

    try {
      await di.sl<FirebaseChatDataSource>().sendMessage(
        widget.contact.id,
        text,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send message'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  bool _showDateSeparator(DateTime current, DateTime? previous) {
    if (previous == null) return true;
    return current.day != previous.day || current.month != previous.month;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Stack(
              children: [
              ProfileAvatar(
                photoBase64: widget.contact.photoBase64,
                initial: widget.contact.name.isNotEmpty ? widget.contact.name[0].toUpperCase() : 'T',
                radius: 20,
                backgroundColor: widget.contact.avatarColor,
              ),
                if (widget.contact.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.surface,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.contact.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Text(
                  'Online via Trip-GUY Cloud',
                  style: TextStyle(fontSize: 12, color: Colors.green),
                ),
              ],
            ),
          ],
        ),
      ),

      body: Column(
        children: [
          // Trip context banner
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withAlpha(20),
                  AppColors.primary.withAlpha(5),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withAlpha(60)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_outline, size: 16, color: AppColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Messages are secured and end-to-end encrypted.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Live Messages Stream
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Say hi! Start your adventure together.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                // Map Firestore documents to our local ChatMessage objects
                final List<ChatMessage> liveMessages = docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final isMe = data['senderId'] == _currentUserId;
                  final ts = data['timestamp'] as Timestamp?;

                  return ChatMessage(
                    id: doc.id,
                    text: data['message']?.toString() ?? '',
                    isMe: isMe,
                    timestamp: ts?.toDate() ?? DateTime.now(),
                    status: MessageStatus.read, // Hardcoded for simplicity
                  );
                }).toList();

                // Ensure the list scrolls down when new messages arrive!
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _scrollToBottom(),
                );

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  itemCount: liveMessages.length,
                  itemBuilder: (context, index) {
                    final msg = liveMessages[index];
                    final previousMsg = index > 0
                        ? liveMessages[index - 1]
                        : null;

                    return Column(
                      children: [
                        if (_showDateSeparator(
                          msg.timestamp,
                          previousMsg?.timestamp,
                        ))
                          _DateSeparator(date: msg.timestamp),
                        _MessageBubble(
                          message: msg,
                          formatTime: _formatTime,
                          contactColor: widget.contact.avatarColor,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Input bar
          _MessageInputBar(
            controller: _controller,
            isTyping: _isTyping,
            onChanged: (v) => setState(() => _isTyping = v.isNotEmpty),
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Message Bubble
// ─────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final String Function(DateTime) formatTime;
  final Color contactColor;

  const _MessageBubble({
    required this.message,
    required this.formatTime,
    required this.contactColor,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child:
          Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72,
                ),
                margin: EdgeInsets.only(
                  top: 2,
                  bottom: 4,
                  left: isMe ? 40 : 0,
                  right: isMe ? 0 : 40,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isMe
                      ? AppColors.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isMe ? 20 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      message.text,
                      style: TextStyle(
                        color: isMe
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatTime(message.timestamp),
                          style: TextStyle(
                            fontSize: 10,
                            color: isMe ? Colors.white60 : Colors.grey,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.done_all,
                            size: 13,
                            color: Colors.lightBlueAccent,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              )
              .animate()
              .fade(duration: 250.ms)
              .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),
    );
  }
}

// ─────────────────────────────────────────────────────
// Date Separator
// ─────────────────────────────────────────────────────

class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  String get label {
    final now = DateTime.now();
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return 'Today';
    }
    if (date.day == now.day - 1 &&
        date.month == now.month &&
        date.year == now.year) {
      return 'Yesterday';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Message Input Bar
// ─────────────────────────────────────────────────────

class _MessageInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isTyping;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  const _MessageInputBar({
    required this.controller,
    required this.isTyping,
    required this.onChanged,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline,
              color: AppColors.primary,
              size: 26,
            ),
            onPressed: () {},
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(28),
              ),
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                onSubmitted: (_) => onSend(),
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Message...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isTyping ? onSend : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isTyping
                    ? AppColors.primary
                    : Colors.grey.withAlpha(100),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
