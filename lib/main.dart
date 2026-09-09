import 'package:chat_ikokas/globals.dart';
import 'package:chat_ikokas/models/user_model.dart';
import 'package:chat_ikokas/screen/home_screen.dart';
import 'package:chat_ikokas/screen/messageScreen.dart';
import 'package:chat_ikokas/screen/navigation_screen.dart';
import 'package:chat_ikokas/screen/app_lock_screen.dart';
import 'package:chat_ikokas/screen/signIn_screen.dart';
import 'package:chat_ikokas/screen/face_capture_screen.dart';
import 'package:chat_ikokas/services/local_notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:chat_ikokas/repositories/auth_repository.dart';
import 'package:chat_ikokas/bloc/auth/auth_bloc.dart';
import 'package:chat_ikokas/bloc/auth/auth_event.dart';
import 'package:chat_ikokas/bloc/auth/auth_state.dart';
import 'package:chat_ikokas/repositories/chat_repository.dart';
import 'package:chat_ikokas/bloc/chat/chat_bloc.dart';
import 'package:chat_ikokas/bloc/like/like_bloc.dart';
import 'package:chat_ikokas/bloc/post/post_bloc.dart';
import 'package:chat_ikokas/bloc/post/post_event.dart';
import 'package:chat_ikokas/bloc/profile/profile_bloc.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:chat_ikokas/repositories/call_repository.dart';
import 'package:chat_ikokas/bloc/call/call_bloc.dart';
import 'package:chat_ikokas/bloc/call/call_event.dart';
import 'package:chat_ikokas/services/push_notification_service.dart';
import 'package:chat_ikokas/services/call_page.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("[BG_HANDLER] Background message received: ${message.data}");
  if (message.data['type'] == 'voice_call') {
    print("[BG_HANDLER] Showing incoming call screen...");
    await PushNotificationService.handleIncomingCall(message.data);
  } else if (message.data['type'] == 'call_ended') {
    print("[BG_HANDLER] Call ended by caller, dismissing UI...");
    await FlutterCallkitIncoming.endAllCalls();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await LocalNotificationService.instance.initialize();

  // Create call notification channel so FCM HIGH priority messages work
  const AndroidNotificationChannel callChannel = AndroidNotificationChannel(
    'call_channel',
    'Incoming Calls',
    description: 'Notifications for incoming voice calls',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );
  final FlutterLocalNotificationsPlugin flnp =
      FlutterLocalNotificationsPlugin();
  await flnp
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(callChannel);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Request permission
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Android 14+ requires explicit full-screen intent permission for incoming call UI
  final canUseFullScreen =
      await FlutterCallkitIncoming.canUseFullScreenIntent();
  if (!canUseFullScreen) {
    await FlutterCallkitIncoming.requestFullIntentPermission();
  }

  // Handle app opened from terminated state via notification tap
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    if (initialMessage.data['type'] == 'voice_call') {
      await PushNotificationService.handleIncomingCall(initialMessage.data);
    } else if (initialMessage.data['type'] == 'call_ended') {
      await FlutterCallkitIncoming.endAllCalls();
    }
  }

  // Handle app opened from background via notification tap
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    if (message.data['type'] == 'voice_call') {
      PushNotificationService.handleIncomingCall(message.data);
    } else if (message.data['type'] == 'call_ended') {
      FlutterCallkitIncoming.endAllCalls();
    }
  });

  // Handle Foreground Messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    if (message.data['type'] == 'voice_call') {
      PushNotificationService.handleIncomingCall(message.data);
    } else if (message.data['type'] == 'call_ended') {
      FlutterCallkitIncoming.endAllCalls();
    }

    if (message.notification != null) {
      LocalNotificationService.instance.showNotification(
        title: message.notification!.title ?? 'New Notification',
        body: message.notification!.body ?? '',
      );
    }
  });

  // CallKit Listener
  FlutterCallkitIncoming.onEvent.listen((event) async {
    if (event == null) return;

    switch (event.event) {
      case Event.actionCallAccept:
        final callId = event.body['extra']?['callId'] ?? '';
        print("[CALLKIT] Call accepted: $callId");
        
        await FirebaseFirestore.instance.collection('calls').doc(callId).update(
          {'status': 'accepted'},
        );

        if (navigatorKey.currentState != null) {
          navigatorKey.currentState!.push(
            MaterialPageRoute(builder: (context) => CallPage(callID: callId)),
          );
        } else {
          print("[CALLKIT] Navigator is null, saving to pendingCallId");
          pendingCallId = callId;
        }
        break;
      case Event.actionCallDecline:
        final callId = event.body['extra']?['callId'] ?? '';
        print("[CALLKIT] Call declined: $callId");
        await FirebaseFirestore.instance.collection('calls').doc(callId).update(
          {'status': 'rejected'},
        );
        break;
      case Event.actionCallEnded:
        final callId = event.body['extra']?['callId'] ?? '';
        print("[CALLKIT] Call ended: $callId");
        await FirebaseFirestore.instance.collection('calls').doc(callId).update(
          {'status': 'ended'},
        );
        break;
      default:
        break;
    }
  });

  // Save Token when user logs in
  FirebaseAuth.instance.authStateChanges().listen((User? user) async {
    if (user != null) {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'fcmToken': token});
        }
      } catch (e) {
        print("Failed to save FCM token: $e");
      }
    }
  });

  // Refresh token if it changes
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'fcmToken': newToken},
      );
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (context) => AuthRepository()),
        RepositoryProvider(create: (context) => ChatRepository()),
        RepositoryProvider(create: (context) => CallRepository()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => AuthBloc(
              authRepository: RepositoryProvider.of<AuthRepository>(context),
            )..add(AuthCheckRequested()),
          ),
          BlocProvider(
            create: (context) => ChatBloc(
              chatRepository: RepositoryProvider.of<ChatRepository>(context),
            ),
          ),
          BlocProvider(create: (context) => PostBloc()..add(LoadPosts())),
          BlocProvider(create: (context) => LikeBloc()),
          BlocProvider(create: (context) => ProfileBloc()),
          BlocProvider(
            create: (context) => CallBloc(
              callRepository: RepositoryProvider.of<CallRepository>(context),
              notificationService: PushNotificationService(),
            ),
          ),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          ),
          home: 
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              if (state is Authenticated) {
                return const AppLockScreen();
              }
              if (state is FaceVerificationRequired) {
                return FaceCaptureScreen(user: state.user, isSignUp: state.isSignUp);
              }
              if (state is Unauthenticated) {
                return const SigninScreen();
              }

              return const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text("Wait a minute...", style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
