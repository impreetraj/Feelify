class PostModel {
  final String? id;
  final String userId;
  final String imagePath;
  final String caption;
  final String timestamp;
  final String userName;
  final String photourl;
  final String? reaction;
  final int likeCount;
  final String mediaType; // 'image' or 'video'

  PostModel({
    this.id,
    required this.userId,
    required this.imagePath,
    required this.caption,
    required this.userName,
    required this.photourl,
    required this.timestamp,
    this.reaction,
    this.likeCount = 0,
    this.mediaType = 'image',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'imagePath': imagePath,
      'caption': caption,
      'userName': userName,
      'photourl': photourl,
      'timestamp': timestamp,
      'reaction': reaction,
      'likeCount': likeCount,
      'mediaType': mediaType,
    };
  }

  factory PostModel.fromMap(Map<String, dynamic> map) {
    return PostModel(
      id: map['id'],
      userId: map['userId'] ?? '',
      imagePath: map['imagePath'],
      caption: map['caption'],
      userName: map['userName'],
      photourl: map['photourl'],
      timestamp: map['timestamp'],
      reaction: map['reaction'],
      likeCount: map['likeCount'] ?? 0,
      mediaType: map['mediaType'] ?? 'image',
    );
  }
}
