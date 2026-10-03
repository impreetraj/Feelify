import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'fcm_credentials.dart';

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  
  final List<String> _scopes = [
    "https://www.googleapis.com/auth/firebase.messaging"
  ];

  Future<String?> _getAccessToken() async {
    try {
      if (FCMCredentials.serviceAccountJson['project_id'] == null || FCMCredentials.serviceAccountJson['project_id']!.isEmpty) {
        print('FCM Credentials not provided.');
        return null;
      }
      
      final serviceAccountCredentials = auth.ServiceAccountCredentials.fromJson(
        FCMCredentials.serviceAccountJson,
      );

      final client = await auth.clientViaServiceAccount(
        serviceAccountCredentials,
        _scopes,
      );

      final accessToken = client.credentials.accessToken.data;
      client.close();
      return accessToken;
    } catch (e) {
      print("Error generating FCM access token: $e");
      return null;
    }
  }

  Future<void> sendNotification({
    required String receiverToken,
    required String title,
    required String body,
  }) async {
    try {
      final projectId = FCMCredentials.serviceAccountJson['project_id'];
      if (projectId == null || projectId.isEmpty) {
        print("Project ID not found. Notification aborted.");
        return;
      }

      final token = await _getAccessToken();
      if (token == null) {
        print("Failed to get FCM access token. Notification aborted.");
        return;
      }

      final String endpoint = "https://fcm.googleapis.com/v1/projects/$projectId/messages:send";

      final Map<String, dynamic> message = {
        'message': {
          'token': receiverToken,
          'notification': {
            'title': title,
            'body': body,
          },
          'data': {
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          }
        }
      };

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(message),
      );

      if (response.statusCode == 200) {
        print("Notification sent successfully to $receiverToken");
      } else {
        print("Failed to send notification: ${response.body}");
      }
    } catch (e) {
      print("Exception sending notification: $e");
    }
  }


}


