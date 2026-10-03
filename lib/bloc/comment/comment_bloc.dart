import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'comment_event.dart';
import 'comment_state.dart';
import '../../services/comment_database_helper.dart';
import '../../models/comment_model.dart';
import '../../services/push_notification_service.dart';

class CommentBloc extends Bloc<CommentEvent, CommentState> {
  CommentBloc() : super(CommentInitial()) {
    on<LoadComments>(_onLoadComments);
    on<AddComment>(_onAddComment);
    on<UpdateCommentReaction>(_onUpdateCommentReaction);
  }

  Future<void> _onUpdateCommentReaction(UpdateCommentReaction event, Emitter<CommentState> emit) async {
    try {
      // await CommentDatabaseHelper.instance.updateReaction(event.commentId, event.reaction, event.likeCount);
      
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('comments').doc(event.commentId).update({
        'reaction': event.reaction,
        'likeCount': event.likeCount,
      });

      // final comments = await CommentDatabaseHelper.instance.readCommentsForPost(event.postId);
      // emit(CommentLoaded(comments));

      // Update the comment in-place without full reload
      if (state is CommentLoaded) {
        final currentComments = (state as CommentLoaded).comments;
        final updatedComments = currentComments.map((c) {
          if (c.id == event.commentId) {
            return CommentModel(
              id: c.id,
              postId: c.postId,
              authorName: c.authorName,
              authorPhotoUrl: c.authorPhotoUrl,
              content: c.content,
              timestamp: c.timestamp,
              reaction: event.reaction,
              likeCount: event.likeCount,
            );
          }
          return c;
        }).toList();
        emit(CommentLoaded(updatedComments));
      }
    } catch (e) {
      emit(CommentError(e.toString()));
    }
  }

  Future<void> _onLoadComments(LoadComments event, Emitter<CommentState> emit) async {
    emit(CommentLoading());
    try {
      // final comments = await CommentDatabaseHelper.instance.readCommentsForPost(event.postId);
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore
          .collection('comments')
          .where('postId', isEqualTo: event.postId)
          .get();

      final comments = snapshot.docs.map((doc) {
        final data = doc.data();
        return CommentModel(
          id: doc.id,
          postId: data['postId'],
          authorName: data['authorName'],
          authorPhotoUrl: data['authorPhotoUrl'] ?? '',
          content: data['content'],
          timestamp: data['timestamp'],
          reaction: data['reaction'],
          likeCount: data['likeCount'] ?? 0,
        );
      }).toList();

      comments.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      emit(CommentLoaded(comments));
    } catch (e) {
      emit(CommentError(e.toString()));
    }
  }

  Future<void> _onAddComment(AddComment event, Emitter<CommentState> emit) async {
    try {
      final timestamp = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
      
      final firestore = FirebaseFirestore.instance;
      
      // Fetch current user details
      final uid = FirebaseAuth.instance.currentUser?.uid;
      String authorName = event.authorName;
      String authorPhotoUrl = '';
      if (uid != null) {
        final doc = await firestore.collection('users').doc(uid).get();
        authorName = doc.data()?['name'] ?? authorName;
        authorPhotoUrl = doc.data()?['profilePic'] ?? '';
      }
      
      await firestore.collection('comments').add({
        'postId': event.postId,
        'authorName': authorName,
        'authorPhotoUrl': authorPhotoUrl,
        'content': event.content,
        'timestamp': timestamp,
        'reaction': null,
        'likeCount': 0,
      });

      if (uid != event.postUserId) {
        final message = '$authorName commented on your post: ${event.content}';

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
            title: "New Comment",
            body: message,
          );
        }
      }

      // final newComment = CommentModel(
      //   postId: event.postId,
      //   authorName: event.authorName,
      //   content: event.content,
      //   timestamp: timestamp,
      // );
      // await CommentDatabaseHelper.instance.create(newComment);
      
      // final comments = await CommentDatabaseHelper.instance.readCommentsForPost(event.postId);
      // emit(CommentLoaded(comments));
      
      add(LoadComments(event.postId)); // Reload comments after adding
    } catch (e) {
      emit(CommentError(e.toString()));
    }
  }
}
