import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/user_model.dart';
import '../services/face_auth_service.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_event.dart';
import '../bloc/auth/auth_state.dart';

class FaceCaptureScreen extends StatefulWidget {
  final UserModel user;
  final bool isSignUp;

  const FaceCaptureScreen({
    Key? key,
    required this.user,
    required this.isSignUp,
  }) : super(key: key);

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen> {
  CameraController? _cameraController;
  final FaceAuthService _faceAuthService = FaceAuthService();
  bool _isProcessing = false;
  String _statusMessage = "Align your face within the camera";

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _faceAuthService.initialize();
  }

  bool _cameraError = false;

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _cameraError = true;
          _statusMessage = "No cameras available.";
        });
        return;
      }
      
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
    } catch (e) {
      setState(() {
        _cameraError = true;
        _statusMessage = "Camera initialization failed: $e";
      });
    }
    if (mounted) setState(() {});
  }

  Future<void> _captureAndVerifyFace() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = "Processing your face...\nPlease wait for a minute.";
    });

    try {
      final XFile imageFile = await _cameraController!.takePicture();
      final embedding = await _faceAuthService.getFaceEmbedding(imageFile.path);

      if (embedding == null) {
        setState(() {
          _isProcessing = false;
          _statusMessage = "Face detection failed. Try again.";
        });
        return;
      }

      
      context.read<AuthBloc>().add(
        FaceVerificationCompleted(widget.user, embedding, widget.isSignUp),
      );

    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = "Error: $e";
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceAuthService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraError) {
      return Scaffold(
        appBar: AppBar(title: const Text("Camera Error")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 16),
            ),
          ),
        ),
      );
    }

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Face Verification"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is FaceVerificationFailed) {
            setState(() {
              _isProcessing = false;
              _statusMessage = state.message;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message, style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red),
            );
          } else if (state is Authenticated) {
            Navigator.popUntil(context, (route) => route.isFirst);
          } else if (state is AuthError) {
            setState(() {
              _isProcessing = false;
              _statusMessage = state.error;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error, style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red),
            );
          }
        },
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CameraPreview(_cameraController!),
                    if (_isProcessing)
                      Container(
                        color: Colors.black54,
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: Colors.white),
                              SizedBox(height: 16),
                              Text(
                                "Please wait for a minute...",
                                style: TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                color: Colors.black,
                child: Column(
                  children: [
                    Text(
                      _statusMessage,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isProcessing ? null : _captureAndVerifyFace,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text("Capture Face", style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
