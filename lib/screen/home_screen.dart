import 'dart:io';
import 'package:chat_ikokas/models/post_model.dart';
import 'package:chat_ikokas/bloc/like/like_bloc.dart';
import 'package:chat_ikokas/bloc/like/like_event.dart';
import 'package:chat_ikokas/bloc/like/like_state.dart';
import 'package:chat_ikokas/screen/upload_screen.dart';
import 'package:chat_ikokas/screen/user_profile_screen.dart';
import 'package:chat_ikokas/widgets/video_post_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:chat_ikokas/bloc/comment/comment_bloc.dart';
import 'package:chat_ikokas/bloc/comment/comment_event.dart';
import 'dart:async';
import 'package:chat_ikokas/bloc/comment/comment_state.dart';
import 'package:chat_ikokas/models/comment_model.dart';
import 'package:chat_ikokas/services/local_notification_service.dart';
import 'package:flutter/rendering.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

String? name = FirebaseAuth.instance.currentUser!.displayName;

class _HomeScreenState extends State<HomeScreen> {
  late final String _startupTime;
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  final Set<String> _loadedLikePostIds = {};
  bool _isUploadVisible = true;
  late Stream<QuerySnapshot> _postsStream;

  @override
  void initState() {
    super.initState();
    _startupTime = DateTime.now().toIso8601String();
    _listenForNotifications();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _postsStream = FirebaseFirestore.instance
          .collection('feeds')
          .doc(user.uid)
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .snapshots();
    } else {
      _postsStream = const Stream<QuerySnapshot>.empty();
    }
  }

  void _listenForNotifications() {
    final currentUser = FirebaseAuth.instance.currentUser?.uid;
    if (currentUser != null) {
      _notificationSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser)
          .collection('notifications')
          .where('timestamp', isGreaterThan: _startupTime)
          .snapshots()
          .listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data != null && data.containsKey('message')) {
              LocalNotificationService.instance.showNotification(
                title: 'New Notification',
                body: data['message'],
              );
            }
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _showFloatingAnimation(
    BuildContext context,
    String reaction,
    Offset position,
  ) {
    OverlayState? overlayState = Overlay.of(context);
    OverlayEntry? overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) {
        return TweenAnimationBuilder(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(seconds: 1),
          onEnd: () {
            overlayEntry?.remove();
          },
          builder: (context, double value, child) {
            return Positioned(
              left: position.dx - 20,
              top: position.dy - (value * 200),
              child: Opacity(
                opacity: 1 - value,
                child: Text(
                  reaction,
                  style: TextStyle(
                    fontSize: 40 + (value * 20),
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    overlayState.insert(overlayEntry);
  }

  void _showCommentReactionMenu(
    BuildContext context,
    Offset position,
    CommentModel comment,
    CommentBloc commentBloc,
  ) {
    if (comment.id == null) return;

    final reactions = ['👍', '❤️', '😂', '😮', '😢', '😡'];
    final bool hasExistingReaction =
        comment.reaction != null && comment.reaction!.isNotEmpty;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy - 80,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: reactions.map((r) {
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  final newLikeCount = hasExistingReaction
                      ? comment.likeCount
                      : comment.likeCount + 1;
                  context.read<CommentBloc>().add(
                    UpdateCommentReaction(
                      comment.id!,
                      comment.postId,
                      r,
                      newLikeCount,
                    ),
                  );
                  _showFloatingAnimation(context, r, position);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(r, style: const TextStyle(fontSize: 24)),
                ),
              );
            }).toList(),
          ),
        ),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    );
  }

  void _showCommentBox(BuildContext context, PostModel post) {
    if (post.id == null) return;
    TextEditingController commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: BlocProvider(
            create: (context) => CommentBloc()..add(LoadComments(post.id!)),
            child: SafeArea(
              child: DraggableScrollableSheet(
                initialChildSize: 0.7,
                minChildSize: 0.4,
                maxChildSize: 0.9,
                expand: false,
                builder: (context, scrollController) {
                  return Padding(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 16,
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Comments",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(),
                        Expanded(
                          child: BlocBuilder<CommentBloc, CommentState>(
                            builder: (context, state) {
                              if (state is CommentLoading) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              } else if (state is CommentLoaded) {
                                if (state.comments.isEmpty) {
                                  return ListView(
                                    controller: scrollController,
                                    children: const [
                                      Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Center(
                                          child: Text(
                                            "No comments yet. Be the first to comment!",
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }
                                return ListView.builder(
                                  controller: scrollController,
                                  itemCount: state.comments.length,
                                  itemBuilder: (context, index) {
                                    final comment = state.comments[index];
                                    final commentBloc = context
                                        .read<CommentBloc>();
                                    return GestureDetector(
                                      onLongPressStart: (details) {
                                        _showCommentReactionMenu(
                                          context,
                                          details.globalPosition,
                                          comment,
                                          commentBloc,
                                        );
                                      },
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundImage: comment.authorPhotoUrl.isNotEmpty 
                                              ? NetworkImage(comment.authorPhotoUrl) 
                                              : null,
                                          child: comment.authorPhotoUrl.isEmpty 
                                              ? const Icon(Icons.person) 
                                              : null,
                                        ),
                                        title: Text(comment.authorName),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(comment.content),
                                            if (comment.reaction != null &&
                                                comment.reaction!.isNotEmpty)
                                              Container(
                                                margin: const EdgeInsets.only(
                                                  top: 4,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade200,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      comment.reaction!,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                    if (comment.likeCount > 0)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              left: 4,
                                                            ),
                                                        child: Text(
                                                          '${comment.likeCount}',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 12,
                                                              ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                        trailing: Text(
                                          comment.timestamp,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              } else if (state is CommentError) {
                                return Center(child: Text(state.message));
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        const Divider(),
                        BlocBuilder<CommentBloc, CommentState>(
                          builder: (context, state) {
                            return Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: commentController,
                                    decoration: InputDecoration(
                                      hintText: "Add a comment...",
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                CircleAvatar(
                                  backgroundColor: Colors.blue,
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.send,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      if (commentController.text
                                          .trim()
                                          .isNotEmpty) {
                                        context.read<CommentBloc>().add(
                                          AddComment(
                                            post.id!,
                                            post.userId,
                                            name ?? "User",
                                            commentController.text.trim(),
                                          ),
                                        );
                                        commentController.clear();
                                      }
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showReactionMenu(
    BuildContext context,
    Offset position,
    PostModel post,
    bool isLikedByCurrentUser,
  ) {
    if (post.id == null) return;

    final reactions = ['👍', '❤️', '😂', '😮', '😢', '😡'];

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy - 80,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: reactions.map((r) {
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  context.read<LikeBloc>().add(
                    ToggleLike(post.id!, post.userId, r),
                  );
                  _showFloatingAnimation(context, r, position);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(r, style: const TextStyle(fontSize: 24)),
                ),
              );
            }).toList(),
          ),
        ),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Feelify",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: SafeArea(
        child: NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            if (notification.direction == ScrollDirection.forward) {
              if (!_isUploadVisible) setState(() => _isUploadVisible = true);
            } else if (notification.direction == ScrollDirection.reverse) {
              if (_isUploadVisible) setState(() => _isUploadVisible = false);
            }
            return false;
          },
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _isUploadVisible
                      ? Column(
                          children: [
                            Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(30),
                                      color: const Color.fromARGB(26, 243, 98, 98),
                                    ),
                                    child: Icon(Icons.person),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => UploadScreen(),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      alignment: Alignment.centerLeft,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.black, width: 1.5),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 10),
                                        child: Text("What's on your mind?"),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: Icon(Icons.photo),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(thickness: 1),
                          ],
                        )
                      : const SizedBox(height: 0, width: double.infinity),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _postsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text("Error: ${snapshot.error}"));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Text(
                            "No posts in your feed yet. Start following people!",
                          ),
                        );
                      }

                      final posts = snapshot.data!.docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return PostModel(
                          id: doc.id,
                          userId: data['userId'] ?? '',
                          imagePath: data['imageUrl'] ?? '',
                          caption: data['content'] ?? '',
                          userName: data['userName'] ?? '',
                          photourl: data['photourl'] ?? '',
                          timestamp: data['createdAt'] != null
                              ? (data['createdAt'] as Timestamp)
                                    .toDate()
                                    .toString()
                                    .substring(0, 16)
                              : DateTime.now().toString().substring(0, 16),
                          reaction: data['reaction'],
                          likeCount: data['likeCount'] ?? 0,
                          mediaType: data['mediaType'] ?? 'image',
                        );
                      }).toList();

                  
                      final postIds = posts
                          .where((p) => p.id != null)
                          .map((p) => p.id!)
                          .toList();
                      final newPostIds = postIds.where((id) => !_loadedLikePostIds.contains(id)).toList();
                      if (newPostIds.isNotEmpty) {
                        _loadedLikePostIds.addAll(newPostIds);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          context.read<LikeBloc>().add(LoadLikes(postIds));
                        });
                      }

                      return ListView.builder(
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          final post = posts[index];
                          return Card(
                            elevation: 1.5,
                            shadowColor: Colors.black12,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 1. Post Header: Avatar, Name, Timestamp (tap opens profile)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14.0,
                                    vertical: 10.0,
                                  ),
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      if (post.userId.isNotEmpty) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => UserProfileScreen(
                                              userId: post.userId,
                                              username: post.userName,
                                              name: post.userName,
                                              profile: post.photourl,
                                              bio: '',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: Colors.grey.shade200,
                                          backgroundImage: post.photourl.isNotEmpty
                                              ? NetworkImage(post.photourl)
                                              : null,
                                          child: post.photourl.isEmpty
                                              ? const Icon(Icons.person, size: 22, color: Colors.grey)
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                post.userName.isNotEmpty ? post.userName : 'User',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                  letterSpacing: 0.1,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                post.timestamp,
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 11.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // 2. Caption (if present)
                                if (post.caption.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 14.0,
                                      right: 14.0,
                                      bottom: 12.0,
                                    ),
                                    child: Text(
                                      post.caption,
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        height: 1.4,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),

                                // 3. Media (Video or Image)
                                if (post.mediaType == 'video' && post.imagePath.startsWith('http'))
                                  Container(
                                    constraints: const BoxConstraints(maxHeight: 460, minHeight: 220),
                                    width: double.infinity,
                                    color: Colors.black,
                                    child: VideoPostPlayer(
                                      key: ValueKey(post.imagePath),
                                      videoUrl: post.imagePath,
                                    ),
                                  )
                                else if (post.imagePath.startsWith('http'))
                                  Container(
                                    constraints: const BoxConstraints(maxHeight: 480, minHeight: 200),
                                    width: double.infinity,
                                    color: Colors.grey.shade100,
                                    child: Image.network(
                                      post.imagePath,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, progress) {
                                        if (progress == null) return child;
                                        return Container(
                                          height: 250,
                                          color: Colors.grey.shade100,
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              value: progress.expectedTotalBytes != null
                                                  ? progress.cumulativeBytesLoaded /
                                                      progress.expectedTotalBytes!
                                                  : null,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        height: 200,
                                        color: Colors.grey.shade200,
                                        child: const Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                              SizedBox(height: 6),
                                              Text(
                                                "Could not load image",
                                                style: TextStyle(color: Colors.grey, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                else if (post.imagePath.isNotEmpty)
                                  Container(
                                    constraints: const BoxConstraints(maxHeight: 480, minHeight: 200),
                                    width: double.infinity,
                                    color: Colors.grey.shade100,
                                    child: Image.file(
                                      File(post.imagePath),
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),

                                // Subtle divider
                                Divider(height: 1, thickness: 0.5, color: Colors.grey.shade200),

                                // 4. Action Buttons (Like & Comment) - Below Media, balanced full width
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                                  child: Row(
                                    children: [
                                      // Like / Reaction Button (Expanded)
                                      Expanded(
                                        child: BlocBuilder<LikeBloc, LikeState>(
                                          builder: (context, likeState) {
                                            String currentUserReaction = '';
                                            bool isLikedByCurrentUser = false;
                                            int realLikeCount = 0;

                                            if (likeState is LikesLoaded) {
                                              final userLike = likeState.userLikes[post.id];
                                              if (userLike != null && userLike.reaction.isNotEmpty) {
                                                isLikedByCurrentUser = true;
                                                currentUserReaction = userLike.reaction;
                                              }
                                              realLikeCount = likeState.likeCounts[post.id] ?? 0;
                                            }

                                            return GestureDetector(
                                              onLongPressStart: (details) {
                                                _showReactionMenu(
                                                  context,
                                                  details.globalPosition,
                                                  post,
                                                  isLikedByCurrentUser,
                                                );
                                              },
                                              onTapUp: (details) {
                                                if (post.id != null) {
                                                  final newReaction = isLikedByCurrentUser ? '' : '👍';
                                                  context.read<LikeBloc>().add(
                                                    ToggleLike(
                                                      post.id!,
                                                      post.userId,
                                                      newReaction,
                                                    ),
                                                  );
                                                  if (newReaction.isNotEmpty) {
                                                    _showFloatingAnimation(
                                                      context,
                                                      newReaction,
                                                      details.globalPosition,
                                                    );
                                                  }
                                                }
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: isLikedByCurrentUser
                                                      ? Colors.blue.withValues(alpha: 0.1)
                                                      : Colors.transparent,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    if (isLikedByCurrentUser)
                                                      Text(
                                                        currentUserReaction,
                                                        style: const TextStyle(fontSize: 18),
                                                      )
                                                    else
                                                      Icon(
                                                        Icons.thumb_up_alt_outlined,
                                                        size: 19,
                                                        color: Colors.grey.shade700,
                                                      ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      realLikeCount > 0
                                                          ? "$realLikeCount Like${realLikeCount > 1 ? 's' : ''}"
                                                          : "Like",
                                                      style: TextStyle(
                                                        fontSize: 13.5,
                                                        fontWeight: FontWeight.w600,
                                                        color: isLikedByCurrentUser
                                                            ? Colors.blue
                                                            : Colors.grey.shade800,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),

                                      // Vertical divider between Like & Comment
                                      Container(
                                        height: 20,
                                        width: 1,
                                        color: Colors.grey.shade300,
                                      ),

                                      // Comment Button (Expanded)
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            _showCommentBox(context, post);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.transparent,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.chat_bubble_outline_rounded,
                                                  size: 19,
                                                  color: Colors.grey.shade700,
                                                ),
                                                const SizedBox(width: 8),
                                                if (post.id != null)
                                                  StreamBuilder<QuerySnapshot>(
                                                    stream: FirebaseFirestore.instance
                                                        .collection('comments')
                                                        .where('postId', isEqualTo: post.id)
                                                        .snapshots(),
                                                    builder: (context, commentSnap) {
                                                      final count = commentSnap.hasData
                                                          ? commentSnap.data!.docs.length
                                                          : 0;
                                                      return Text(
                                                        count > 0
                                                            ? "$count Comment${count > 1 ? 's' : ''}"
                                                            : "Comment",
                                                        style: TextStyle(
                                                          fontSize: 13.5,
                                                          fontWeight: FontWeight.w600,
                                                          color: Colors.grey.shade800,
                                                        ),
                                                      );
                                                    },
                                                  )
                                                else
                                                  Text(
                                                    "Comment",
                                                    style: TextStyle(
                                                      fontSize: 13.5,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.grey.shade800,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
