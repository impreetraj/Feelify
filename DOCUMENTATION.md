# chat_ikokas

This is a Flutter social chat application utilizing the BLoC pattern for state management. It handles various features such as authentication, real-time messaging, post creation, and voice calling. 

Authentication is managed through Firebase Auth, supporting Email/Password, Google Sign-In, and a custom face recognition login using a TFLite model and Google ML Kit Face Detection. The app can also use the local_auth package to require device-level biometric authentication (like fingerprint or face unlock) before accessing the app content.

Once authenticated, users interact with a feed of posts and a chat interface. Posts can contain text, images, or videos (using the video_player and chewie packages). The visibility_detector package is used to determine when video posts are on screen. Users can upload new media using the image_picker package, with files being uploaded to a backend service using the http package.

Real-time chat is powered by Firebase Cloud Firestore. Users can send and receive messages instantly. The app also supports voice calling through the ZegoCloud UI kit (zego_uikit_prebuilt_call). Incoming calls are presented using the flutter_callkit_incoming package, providing a native call screen experience.

Push notifications are integrated using Firebase Cloud Messaging (FCM). The flutter_local_notifications package displays alerts when the app receives a notification payload while active or in the background.

The app uses Cloud Firestore to store core data (users, messages, posts, likes, comments). Additionally, it uses local SQLite databases (via the sqflite package) to cache certain data like posts and notifications for offline access. The uuid package generates unique identifiers, and the equatable package is used for value equality in BLoC states.

Technologies used: Flutter, flutter_bloc, Firebase Core, Firebase Auth, Cloud Firestore, Firebase Messaging, google_sign_in, zego_uikit_prebuilt_call, flutter_callkit_incoming, sqflite, shared_preferences, local_auth, camera, google_mlkit_face_detection, tflite_flutter, flutter_local_notifications, video_player, chewie, image_picker, http, equatable, intl, uuid, visibility_detector.

## Working Flow
1. Open the app -> The Auth BLoC checks if you are logged in.
2. Login -> Authenticate via Firebase (Google/Email) or the custom Face Recognition model.
3. View Feed -> The app fetches posts from Firestore (or local SQLite cache) and displays them. Videos play when visible on screen.
4. Open Chat -> Select a user to open a chat screen. The app connects to a Firestore stream to show real-time messages.
5. Send Message -> The BLoC writes the new message to the Firestore database.
6. Start Call -> The app initializes a ZegoCloud voice call and triggers a push notification to the recipient.
7. Create Post -> Select an image/video from the device gallery, upload it, and the BLoC saves the post record to Firestore.
