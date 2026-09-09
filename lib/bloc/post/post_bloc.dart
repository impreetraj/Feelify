import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/post_database_helper.dart';
import '../../services/notification_database_helper.dart';
import '../../services/local_notification_service.dart';
import '../../models/notification_model.dart';
import 'post_event.dart';
import 'post_state.dart';

class PostBloc extends Bloc<PostEvent, PostState> {
  PostBloc() : super(PostInitial()) {
    on<LoadPosts>((event, emit) async {
      emit(PostLoading());
      try {
        final posts = await PostDatabaseHelper.instance.readAllPosts();
        emit(PostLoaded(posts));
      } catch (e) {
        emit(PostError(e.toString()));
      }
    });

    on<AddPost>((event, emit) async {
      try {
      
        // await PostDatabaseHelper.instance.create(event.post);
        // final posts = await PostDatabaseHelper.instance.readAllPosts();
        // emit(PostLoaded(posts));
        

        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId != null) {
          final firestore = FirebaseFirestore.instance;
          final postId = firestore.collection('posts').doc().id;

          final postData = {
            'postId': postId,
            'userId': userId,
            'content': event.post.caption,
            'imageUrl': event.post.imagePath,
            'userName': event.post.userName,
            'photourl': event.post.photourl,
            'mediaType': event.post.mediaType,
            'createdAt': FieldValue.serverTimestamp(),
          };

          // 1. Save in your own posts
          await firestore
              .collection('userPosts')
              .doc(userId)
              .collection('posts')
              .doc(postId)
              .set(postData);

          // 2. Save in your own feed
          await firestore
              .collection('feeds')
              .doc(userId)
              .collection('posts')
              .doc(postId)
              .set(postData);

          // 3. Find all followers
          final followersSnapshot = await firestore
              .collection('users')
              .doc(userId)
              .collection('followers')
              .get();

          
          for (var follower in followersSnapshot.docs) {
            final followerId = follower.id;

            await firestore
                .collection('feeds')
                .doc(followerId)
                .collection('posts')
                .doc(postId)
                .set(postData);
          }
        }
      } catch (e) {
        emit(PostError(e.toString()));
      }
    });

    on<DeletePost>((event, emit) async {
      try {
        // await PostDatabaseHelper.instance.delete(event.postId);
        // final posts = await PostDatabaseHelper.instance.readAllPosts();
        // emit(PostLoaded(posts));
        
        final firestore = FirebaseFirestore.instance;
        final snapshot = await firestore.collectionGroup('posts').where('postId', isEqualTo: event.postId).get();
        final batch = firestore.batch();
        for (var doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        
        final commentsSnapshot = await firestore.collection('comments').where('postId', isEqualTo: event.postId).get();
        final commentsBatch = firestore.batch();
        for (var doc in commentsSnapshot.docs) {
          commentsBatch.delete(doc.reference);
        }
        await commentsBatch.commit();

      } catch (e) {
        emit(PostError(e.toString()));
      }
    });

    on<UpdatePostReaction>((event, emit) async {
      try {
        // await PostDatabaseHelper.instance.updateReaction(event.postId, event.reaction, event.likeCount);
        
        final firestore = FirebaseFirestore.instance;
        final currentUser = FirebaseAuth.instance.currentUser?.uid;
        
        if (currentUser != null) {
          await firestore
              .collection('feeds')
              .doc(currentUser)
              .collection('posts')
              .doc(event.postId)
              .update({
            'reaction': event.reaction,
            'likeCount': event.likeCount,
          });
        }

        if (event.reaction.isNotEmpty) {
          if (currentUser != event.postUserId) {
            final userNameDoc = await firestore.collection('users').doc(currentUser).get();
            final currentUserName = userNameDoc.data()?['name'] ?? 'Someone';
            
            await firestore
                .collection('users')
                .doc(event.postUserId)
                .collection('notifications')
                .add({
              'message': '$currentUserName reacted ${event.reaction} to your post',
              'timestamp': DateTime.now().toIso8601String(),
            });
          }
        }
        // final posts = await PostDatabaseHelper.instance.readAllPosts();
        // emit(PostLoaded(posts));
      } catch (e) {
        emit(PostError(e.toString()));
      }
    });
  }
}
