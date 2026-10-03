import 'package:chat_ikokas/bloc/auth/auth_state.dart';
import 'package:chat_ikokas/bloc/chat/chat_bloc.dart';
import 'package:chat_ikokas/bloc/chat/chat_event.dart';
import 'package:chat_ikokas/models/message_model.dart';
import 'package:chat_ikokas/repositories/chat_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:chat_ikokas/bloc/auth/auth_bloc.dart';


class Messagescreen extends StatefulWidget {
  final String peerId;
  final String peerName;
  final String peerPhotoUrl;

  const Messagescreen({
    super.key,
    required this.peerId,
    required this.peerName,
    required this.peerPhotoUrl,
  });

  @override
  State<Messagescreen> createState() => _MessagescreenState();
}

class _MessagescreenState extends State<Messagescreen> {
  final TextEditingController messageController = TextEditingController();
  late String currentUserId;
  late String chatroomId;

  @override
  void initState() {
    super.initState();

    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      currentUserId = authState.user.uid;
    } else {
      currentUserId = '';
    }

    chatroomId = context.read<ChatRepository>().getChatroomId(
      currentUserId,
      widget.peerId,
    );
  }

  void _sendMessage() {
    final text = messageController.text.trim();
    if (text.isNotEmpty) {
      final message = MessageModel(
        senderId: currentUserId,
        receiverId: widget.peerId,
        message: text,
        timestamp: Timestamp.now(),
      );

      context.read<ChatBloc>().add(SendMessageEvent(chatroomId, message));
      messageController.clear();
    }
  }

  Widget buildMessageWithTags(String message, bool isMe) {
    List<TextSpan> spans = [];

    List<String> words = message.split(" ");

    for (String word in words) {
      if (word.startsWith("@")) {
        spans.add(
          TextSpan(
            text: "$word ",
            style: TextStyle(
              color: isMe ? Colors.yellowAccent : Colors.blue,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: "$word ",
            style: TextStyle(
              color: isMe ? Colors.white : Colors.black87,
              fontSize: 16,
            ),
          ),
        );
      }
    }

    return RichText(text: TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: widget.peerPhotoUrl.isNotEmpty
                  ? NetworkImage(widget.peerPhotoUrl)
                  : null,
              child: widget.peerPhotoUrl.isEmpty
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Text(widget.peerName),
          ],
        ),
        backgroundColor: Colors.white,
      ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: context.read<ChatRepository>().getMessages(
                    chatroomId,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text("Error loading messages"),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text("Say hi!"));
                    }

                    final messages = snapshot.data!.docs;

                    return ListView.builder(
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msgData =
                            messages[index].data() as Map<String, dynamic>;
                        final isMe = msgData['senderId'] == currentUserId;

                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              vertical: 5,
                              horizontal: 10,
                            ),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.blue[300] : Colors.white,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: buildMessageWithTags(
                              msgData['message'] ?? '',
                              isMe,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // The Message Input Area
              Container(
                padding: const EdgeInsets.all(10),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: messageController,
                        decoration: InputDecoration(
                          hintText: "Type a message...",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[200],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: IconButton(
                        onPressed: _sendMessage,
                        icon: const Icon(Icons.send, color: Colors.white),
                      ),
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
