import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';
import 'package:chat_ikokas/bloc/post/post_bloc.dart';
import 'package:chat_ikokas/bloc/post/post_event.dart';
import 'package:chat_ikokas/models/post_model.dart';
import 'package:chat_ikokas/services/cloudinary_service.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? selectedFile;
  String mediaType = 'image'; // 'image' or 'video'
  final TextEditingController captionController = TextEditingController();
  bool isLoading = false;
  VideoPlayerController? _videoController;

  @override
  void dispose() {
    captionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  /// Pick image from gallery
  Future<void> pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      _videoController?.dispose();
      _videoController = null;

      setState(() {
        selectedFile = File(pickedFile.path);
        mediaType = 'image';
      });
    }
  }

  Future<void> pickVideo() async {
    final pickedFile = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );

    if (pickedFile != null) {
      _videoController?.dispose();

      final file = File(pickedFile.path);
      
      setState(() {
        selectedFile = file;
        mediaType = 'video';
        _videoController = null;
      });

      final controller = VideoPlayerController.file(file);
      await controller.initialize();

      setState(() {
        _videoController = controller;
      });
    }
  }

  /// Upload the post (image or video)
  Future<void> uploadPost() async {
    if (selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an image or video")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
    
      String mediaUrl;
      if (mediaType == 'video') {
        mediaUrl = await CloudinaryService.uploadVideo(selectedFile!);
      } else {
        mediaUrl = await CloudinaryService.uploadImage(selectedFile!);
      }

      if (mediaUrl.isEmpty) {
        throw Exception('Upload failed. Please try again.');
      }

      // Fetch user details
      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get();
      final userName = userDoc.data()?["name"] ?? 'User';
      final photoUrl = userDoc.data()?["profilePic"] ?? '';

      final newPost = PostModel(
        userId: FirebaseAuth.instance.currentUser!.uid,
        imagePath: mediaUrl,
        caption: captionController.text,
        userName: userName,
        photourl: photoUrl,
        timestamp: DateTime.now().toString(),
        mediaType: mediaType,
      );

      context.read<PostBloc>().add(AddPost(newPost));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Post created successfully")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Widget _buildMediaPreview() {
    if (selectedFile == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.add_photo_alternate_outlined, size: 60, color: Colors.grey),
          SizedBox(height: 10),
          Text("Tap buttons below to select media"),
        ],
      );
    }

    if (mediaType == 'video') {
      if (_videoController == null || !_videoController!.value.isInitialized) {
        return const Center(child: CircularProgressIndicator());
      }
      
      return Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          ),
          
          GestureDetector(
            onTap: () {
              setState(() {
                if (_videoController!.value.isPlaying) {
                  _videoController!.pause();
                } else {
                  _videoController!.play();
                }
              });
            },
            child: CircleAvatar(
              radius: 30,
              backgroundColor: Colors.black54,
              child: Icon(
                _videoController!.value.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
          // Video badge
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text("Video", style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Image preview
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(selectedFile!, fit: BoxFit.cover),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Post")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Media preview container
              Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _buildMediaPreview(),
              ),

              const SizedBox(height: 16),

              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isLoading ? null : pickImage,
                      icon: const Icon(Icons.photo_library),
                      label: const Text("Photo"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: mediaType == 'image' && selectedFile != null
                              ? Colors.blue
                              : Colors.grey,
                          width: mediaType == 'image' && selectedFile != null ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isLoading ? null : pickVideo,
                      icon: const Icon(Icons.videocam),
                      label: const Text("Video"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: mediaType == 'video' && selectedFile != null
                              ? Colors.blue
                              : Colors.grey,
                          width: mediaType == 'video' && selectedFile != null ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Caption field
              TextField(
                controller: captionController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Write a caption...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Upload button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    await uploadPost();
                  },
                  child: isLoading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            mediaType == 'video'
                                ? "Uploading Video..."
                                : "Uploading...",
                          ),
                        ],
                      )
                    : const Text("Upload Post"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
