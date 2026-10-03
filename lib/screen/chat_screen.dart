

import 'package:chat_ikokas/bloc/auth/auth_bloc.dart';
import 'package:chat_ikokas/bloc/auth/auth_event.dart';
import 'package:chat_ikokas/bloc/auth/auth_state.dart';
import 'package:chat_ikokas/repositories/chat_repository.dart';
import 'package:chat_ikokas/screen/Search_screen.dart';
import 'package:chat_ikokas/screen/messageScreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  Widget build(BuildContext context) {
    String currentUserId = '';
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      currentUserId = authState.user.uid;
    }

    return Scaffold(
      appBar: AppBar(
      automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        title: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: const Text(
            "Messages",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              letterSpacing: 0.3,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: CupertinoButton(
              onPressed: () {
                context.read<AuthBloc>().add(SignOutRequested());
              },
              child: const Icon(Icons.logout),
            ),
          ),
        ],
      ),
      body: currentUserId.isEmpty
          ? const Center(child: Text("login fail"))
          : StreamBuilder<QuerySnapshot>(
              stream: context.read<ChatRepository>().getUserChatrooms(
                currentUserId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "No chats yet. Search for a friend to start chatting!",
                    ),
                  );
                }

                var chatrooms = snapshot.data!.docs.toList();

                // Sort locally by lastMessageTime to avoid needing a Firestore composite index
                chatrooms.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = aData['lastMessageTime'] as Timestamp?;
                  final bTime = bData['lastMessageTime'] as Timestamp?;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });

                return ListView.builder(
                  itemCount: chatrooms.length,
                  itemBuilder: (context, index) {
                    final chatData =
                        chatrooms[index].data() as Map<String, dynamic>;
                    final participants = List<String>.from(
                      chatData['participants'] ?? [],
                    );

                    String peerId = '';
                    if (participants.isNotEmpty) {
                      peerId = participants.firstWhere(
                        (id) => id != currentUserId,
                        orElse: () => '',
                      );
                    }

                    if (peerId.isEmpty) return const SizedBox.shrink();

                    // Fetch peer details from Firestore
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(peerId)
                          .get(),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData) {
                          return const ListTile(
                            leading: CircleAvatar(child: Icon(Icons.person)),
                            title: Text("Loading..."),
                          );
                        }

                        final userData =
                            userSnapshot.data!.data() as Map<String, dynamic>?;
                        final peerName =
                            userData?['name'] ?? userData?['username'] ?? 'Unknown User';
                        final peerPhotoUrl = 
                            userData?['profilePic'] ?? userData?['photoUrl'] ?? '';
                        final lastMessage = chatData['lastMessage'] ?? '';

                        return Card(
                          elevation: 1,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          child: ListTile(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => Messagescreen(
                                    peerId: peerId,
                                    peerName: peerName,
                                    peerPhotoUrl: peerPhotoUrl,
                                  ),
                                ),
                              );
                            },
                            leading: CircleAvatar(
                              backgroundColor: Colors.blueAccent,
                              backgroundImage: peerPhotoUrl.isNotEmpty 
                                  ? NetworkImage(peerPhotoUrl) 
                                  : null,
                              child: peerPhotoUrl.isEmpty 
                                  ? const Icon(Icons.person, color: Colors.white) 
                                  : null,
                            ),
                            title: Text(
                              peerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SearchScreen()),
          );
        },
        child: const Icon(Icons.search),
      ),
    );
  }
}
