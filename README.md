# Feelify - Social Media & Real-Time Chat App

Feelify is a modern, feature-rich social media and real-time chat application built with **Flutter** and **Firebase**, utilizing the **BLoC pattern** for scalable and predictable state management.

---

## 🌟 Key Features

* **Authentication & Onboarding**:
  * Secure Email/Password registration and login via Firebase Authentication.
  * One-tap Google Sign-In (`google_sign_in`).
* **Biometric Security & App Lock**:
  * Device-level biometric authentication (Fingerprint / Face Unlock) using `local_auth` to protect user chat privacy.
* **Social Feed & Media**:
  * Real-time post feed streaming directly from Cloud Firestore.
  * Multi-format media support: high-resolution image rendering and in-feed auto-playing video feeds using `video_player`, `chewie`, and `visibility_detector`.
* **Interactive Reactions & Live Comments**:
  * Multi-emoji reaction system (Like, Love, Haha, Wow, Sad, Angry) with floating micro-animations powered by `LikeBloc`.
  * Real-time live comments modal bottom sheet managed through `CommentBloc`.
* **Real-Time 1-on-1 Chat**:
  * Instant direct messaging powered by Firebase Cloud Firestore reactive streams.
  * Real-time message status, timestamping, and chatroom management via `ChatBloc` and `ChatRepository`.
* **Push Notifications (FCM HTTP v1)**:
  * Integrated Firebase Cloud Messaging using the latest **FCM HTTP v1 API** with OAuth 2.0 Google Service Account credentials (`googleapis_auth`).
  * Heads-up foreground alerts and background notification handling via `flutter_local_notifications`.
* **Media Uploads & Cloud Storage**:
  * Post creation supporting image and video picking via `image_picker`.
  * Cloudinary integration for scalable cloud asset hosting and URL delivery.
* **User Profiles**:
  * Follow/unfollow mechanism, bio customization, and profile post galleries.

---

## 🛠️ Architecture & Tech Stack

* **Frontend**: Flutter (Dart SDK ^3.11.0)
* **State Management**: `flutter_bloc` (v9.1.1), `equatable` (Clean Layered Architecture: UI ↔ BLoC ↔ Repository ↔ Data Source)
* **Backend Services**:
  * Firebase Core
  * Firebase Authentication
  * Cloud Firestore (NoSQL Real-Time Database)
  * Firebase Cloud Messaging (FCM HTTP v1)
* **Security & Auth**: `local_auth`, `google_sign_in`
* **Media & Playback**: `video_player`, `chewie`, `visibility_detector`, `image_picker`
* **Networking & Utilities**: `http`, `googleapis_auth`, `flutter_local_notifications`, `intl`, `shared_preferences`, `sqflite`, `path_provider`

---

## 🚀 Application Workflow

1. **App Launch**: `AuthBloc` verifies existing authentication state.
2. **Security Barrier**: If authenticated, `AppLockScreen` prompts for biometric verification (`local_auth`) to unlock the application.
3. **Feed Exploration**: Browse posts in the home feed. Videos automatically play when scrolled into the visible viewport.
4. **Engagement**: Long-press to choose emoji reactions on posts or tap to open live comments.
5. **Post Creation**: Select photos or videos from the gallery, add a caption, and upload directly to Cloudinary and Firestore.
6. **Real-Time Messaging**: Navigate to the chat tab, pick a contact, and exchange messages instantly with automated push notifications delivered to the recipient.
