import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'like_event.dart';
import 'like_state.dart';
import '../../models/like_model.dart';
import '../../services/push_notification_service.dart';

class LikeBloc extends Bloc<LikeEvent, LikeState> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  Map<String, LikeModel?> _currentLikes = {};
  Map<String, int> _likeCounts = {};

  LikeBloc() : super(LikeInitial()) {
    on<LoadLikes>(_onLoadLikes);
    on<ToggleLike>(_onToggleLike);
    on<ClearLikes>(_onClearLikes);
  }

  void _onClearLikes(ClearLikes event, Emitter<LikeState> emit) {
    _currentLikes.clear();
    _likeCounts.clear();
    emit(LikeInitial());
  }

  Future<void> _onLoadLikes(LoadLikes event, Emitter<LikeState> emit) async {
    final currentUser = FirebaseAuth.instance.currentUser?.uid;
    if (currentUser == null) return;

    try {
      if (state is LikeInitial) {
        emit(LikeLoading());
      }

      for (String postId in event.postIds) {
        // Get current user's like
        final doc = await firestore
            .collection('likes')
            .doc(postId)
            .collection('userLikes')
            .doc(currentUser)
            .get();

        if (doc.exists) {
          _currentLikes[postId] = LikeModel.fromMap(doc.data()!, doc.id);
        } else {
          _currentLikes[postId] = null;
        }

        // total like count
        final allLikes = await firestore
            .collection('likes')
            .doc(postId)
            .collection('userLikes')
            .get();
        _likeCounts[postId] = allLikes.docs.length;
      }

      emit(LikesLoaded(Map.from(_currentLikes), Map.from(_likeCounts)));
    } catch (e) {
      emit(LikeError(e.toString()));
    }
  }

  Future<void> _onToggleLike(ToggleLike event, Emitter<LikeState> emit) async {
    final currentUser = FirebaseAuth.instance.currentUser?.uid;
    if (currentUser == null) return;

    try {
      final docRef = firestore
          .collection('likes')
          .doc(event.postId)
          .collection('userLikes')
          .doc(currentUser);

      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        final existingReaction = docSnapshot.data()?['reaction'];
        if (existingReaction == event.reaction || event.reaction.isEmpty) {
          // Unlike - remove the like
          await docRef.delete();
          _currentLikes[event.postId] = null;
          _likeCounts[event.postId] = (_likeCounts[event.postId] ?? 1) - 1;
          if ((_likeCounts[event.postId] ?? 0) < 0) {
            _likeCounts[event.postId] = 0;
          }
        } else {
          // Change reaction
          await docRef.update({'reaction': event.reaction});
          _currentLikes[event.postId] = LikeModel(
            id: currentUser,
            postId: event.postId,
            userId: currentUser,
            reaction: event.reaction,
            timestamp: docSnapshot.data()?['timestamp'] ?? '',
          );
        }
      } else {
        // New like
        final timestamp = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
        await docRef.set({
          'postId': event.postId,
          'userId': currentUser,
          'reaction': event.reaction,
          'timestamp': timestamp,
        });
        _currentLikes[event.postId] = LikeModel(
          id: currentUser,
          postId: event.postId,
          userId: currentUser,
          reaction: event.reaction,
          timestamp: timestamp,
        );
        _likeCounts[event.postId] = (_likeCounts[event.postId] ?? 0) + 1;

        // Send notification to post author
        if (currentUser != event.postUserId) {
          final senderDoc = await firestore.collection('users').doc(currentUser).get();
          final senderName = senderDoc.data()?['name'] ?? 'Someone';
          final message = '$senderName reacted ${event.reaction} to your post';

          // 1. Database me save (History ke liye)
          await firestore
              .collection('users')
              .doc(event.postUserId)
              .collection('notifications')
              .add({
            'message': message,
            'timestamp': DateTime.now().toIso8601String(),
          });

          // 2. Mobile par popup (Alert ke liye)
          final receiverDoc = await firestore.collection('users').doc(event.postUserId).get();
          final fcmToken = receiverDoc.data()?['fcmToken'];
          if (fcmToken != null) {
            PushNotificationService().sendNotification(
              receiverToken: fcmToken,
              title: "New Reaction",
              body: message,
            );
          }
        }
      }

      emit(LikesLoaded(Map.from(_currentLikes), Map.from(_likeCounts)));
    } catch (e) {
      emit(LikeError(e.toString()));
    }
  }
}
