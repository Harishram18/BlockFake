import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VideoRecorderScreen extends StatefulWidget {
  const VideoRecorderScreen({super.key});
  static String id = 'capture_vid';

  @override
  _VideoRecorderScreenState createState() => _VideoRecorderScreenState();
}



class _VideoRecorderScreenState extends State<VideoRecorderScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _isRecordingVideo = false;
  String? _videoPath; // Variable to store the video path
  bool _showUploadButton = false; // Control visibility of upload button
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> initializeUserScore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = _firestore.collection('users').doc(user.uid);

      // Check if user already has a score, initialize it if not
      final docSnapshot = await userDoc.get();
      if (!docSnapshot.exists) {
        await userDoc.set({'credibilityScore': 0});
      }
    }
  }

  Future<void> incrementScore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = _firestore.collection('users').doc(user.uid);

      // Increment the score by 5
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(userDoc);

        if (snapshot.exists) {
          final currentScore = snapshot['credibilityScore'] ?? 0;
          transaction.update(userDoc, {'credibilityScore': currentScore + 5});
        }
      });
    }
  }

  Future<int> getUserScore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = _firestore.collection('users').doc(user.uid);
      final snapshot = await userDoc.get();

      if (snapshot.exists) {
        return snapshot['credibilityScore'] ?? 0;
      }
    }
    return 0;
  }

  @override
  void initState() {
    super.initState();
    initializeCamera();
    initializeUserScore();
  }

  Future<void> initializeCamera() async {
    try {
      final cameras = await availableCameras();
      _controller = CameraController(
        cameras[0], // Use the first available camera
        ResolutionPreset.high,
      );

      _initializeControllerFuture = _controller.initialize();
      await _initializeControllerFuture; // Await initialization
      setState(() {}); // Rebuild the widget once the controller is initialized
    } catch (e) {
      print("Error initializing camera: $e");
      ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Error initializing camera: $e')));
    }
  }

  Future<void> saveVideoToCustomLocation(String videoPath, String customDirectoryPath) async {
    try {
      final savedDirectory = Directory(customDirectoryPath);

      if (!savedDirectory.existsSync()) {
        await savedDirectory.create(recursive: true); // Create the directory if it doesn't exist
      }

      final fileName = basename(videoPath);
      final newFilePath = '$customDirectoryPath/$fileName';

      // Copy the video file to the custom location
      final videoFile = File(videoPath);
      await videoFile.copy(newFilePath);

      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text('Video saved to $newFilePath')),
      );
    } catch (e) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text('Error saving video: $e')),
      );
    }
  }

  Future<void> saveVideoToDownloads(String videoPath) async {
    try {
      final downloadsDirectory = Directory('/storage/emulated/0/Download'); // Path to Downloads folder
      await saveVideoToCustomLocation(videoPath, downloadsDirectory.path);
    } catch (e) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text('Error saving video to Downloads: $e')),
      );
    }
  }
  Future<void> recordVideo() async {
    if (_isRecordingVideo) {
      // Stop recording video
      final video = await _controller.stopVideoRecording();
      _videoPath = video.path; // Store the video path
      setState(() {
        _isRecordingVideo = false;
        _showUploadButton = true; // Show the upload button
      });
      ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Video recorded successfully.')));
    } else {
      // Start recording video
      try {
        await _initializeControllerFuture; // Ensure the controller is initialized

        // Get a temporary directory to store the video
        final directory = await getTemporaryDirectory();
        _videoPath = '${directory.path}/video_${DateTime.now().millisecondsSinceEpoch}.mp4';

        await _controller.startVideoRecording();
        setState(() {
          _isRecordingVideo = true;
          _showUploadButton = false; // Hide the upload button during recording
        });
      } catch (e) {
        print(e);
        ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Error starting video recording: $e')));
      }
    }
  }

  Future<void> uploadVideo(String videoPath) async {
    // Save video to phone storage
    await saveVideoToDownloads(videoPath);

    // Upload video to backend
    var uri = Uri.parse('http://192.168.0.121:5000/upload_video'); // Update this with your backend URL

    var request = http.MultipartRequest('POST', uri);
    var videoFile = File(videoPath);
    var length = await videoFile.length();

    // Add video file to request
    var stream = http.ByteStream(videoFile.openRead().cast());
    var multipartFile = http.MultipartFile('video', stream, length, filename: basename(videoFile.path));
    request.files.add(multipartFile);

    try {
      var response = await request.send();

      if (response.statusCode == 200) {
        // Handle success response
        await incrementScore();
        var responseData = await http.Response.fromStream(response);
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(content: Text('Video uploaded successfully: ${responseData.body}')),
        );
      } else {
        // Handle error response
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(content: Text('Failed to upload video: ${response.reasonPhrase}')),
        );
      }
    } catch (e) {
      // Handle any exceptions
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> saveVideoToPhone(String videoPath) async {
    try {
      final directory = await getExternalStorageDirectory(); // Get phone's external storage directory
      if (directory != null) {
        final savedPath = '${directory.path}/SavedVideos';
        final savedDirectory = Directory(savedPath);

        if (!savedDirectory.existsSync()) {
          await savedDirectory.create(recursive: true); // Create the directory if it doesn't exist
        }

        final fileName = basename(videoPath);
        final newFilePath = '$savedPath/$fileName';

        // Copy the video file to the new location
        final videoFile = File(videoPath);
        await videoFile.copy(newFilePath);

        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(content: Text('Video saved to $newFilePath')),
        );
      } else {
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(content: Text('Failed to get storage directory.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text('Error saving video: $e')),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Video Recorder'),
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                CameraPreview(_controller),
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          await recordVideo();
                        },
                        child: Text(_isRecordingVideo ? 'Stop Recording' : 'Start Recording'),
                      ),
                      if (_showUploadButton && _videoPath != null)
                        ElevatedButton(
                          onPressed: () async {
                            await uploadVideo(_videoPath!);
                          },
                          child: Text('Upload & Save Video'),
                        ),
                    ],
                  ),
                ),
              ],
            );
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}


