import 'dart:convert';
import 'dart:io'; // To handle file operations
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http; // Import http package
import 'package:path/path.dart'; // For handling file paths and names
import 'package:async/async.dart'; // For handling async streams
import 'package:app_1/screens/login_screen.dart';

class VideoPickerScreen extends StatefulWidget {
  const VideoPickerScreen({super.key});
  static String id = 'vid_pick';

  @override
  _VideoPickerScreenState createState() => _VideoPickerScreenState();
}

class _VideoPickerScreenState extends State<VideoPickerScreen> {
  String? _pickedVideo;
  VideoPlayerController? _videoController;
  Future<void>? _initializeVideoPlayerFuture;

  Future<String> _getUsername() async {
    final user = FirebaseAuth.instance.currentUser;
    return user != null ? user.displayName ?? 'User' : 'User';
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, LoginScreen.id);
  }

  Future<void> pickVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _pickedVideo = result.files.single.path!;
        _videoController = VideoPlayerController.file(
          File(_pickedVideo!), // Use the File class to handle file paths
        );
        _initializeVideoPlayerFuture = _videoController?.initialize();
      });
    } else {
      setState(() {
        _pickedVideo = 'No video selected';
      });
    }
  }

  Future<void> sendVideoToBackend(File videoFile) async {
    var uri = Uri.parse('http://192.168.0.121:5000/check_hash'); // Your updated backend endpoint

    var stream = http.ByteStream(DelegatingStream.typed(videoFile.openRead()));
    var length = await videoFile.length();

    var request = http.MultipartRequest('POST', uri);

    // Add the video file to the request
    var multipartFile = http.MultipartFile('video', stream, length,
        filename: basename(videoFile.path));
    request.files.add(multipartFile);

    var response = await request.send();

    if (response.statusCode == 200) {
      // Handle success
      var responseData = await http.Response.fromStream(response);
      final jsonResponse = json.decode(responseData.body);

      // Check the response and handle accordingly
      if (jsonResponse['exists']) {
        // Show dialog indicating the video is not deepfaked
        showDialog(
          context: this.context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Verification Result'),
              content: const Text('The video is not deepfaked.'),
              actions: [
                TextButton(
                  child: const Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop(); // Close the dialog
                  },
                ),
              ],
            );
          },
        );
      } else {
        // Show dialog indicating the video may be deepfaked
        showDialog(
          context: this.context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Verification Result'),
              content: const Text('The video may be deepfaked.'),
              actions: [
                TextButton(
                  child: const Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop(); // Close the dialog
                  },
                ),
              ],
            );
          },
        );
      }
    } else {
      // Handle error response
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('Failed to check video hash')),
      );
    }
  }



  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'assets/images/icons/camera.png', // Ensure the correct path to the image
            width: 24,
            height: 24,
          ),
        ),
        title: FutureBuilder<String>(
          future: _getUsername(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Text('Welcome...');
            } else if (snapshot.hasError) {
              return const Text('Welcome, User');
            } else {
              return Text('Welcome, ${snapshot.data}');
            }
          },
        ),
        actions: [
          FutureBuilder<String>(
            future: _getUsername(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(); // Show nothing while waiting
              } else if (snapshot.hasError) {
                return IconButton(
                  icon: Icon(Icons.error),
                  onPressed: () {}, // Handle error if needed
                );
              } else {
                return PopupMenuButton<String>(
                  icon: Padding(
                    padding: const EdgeInsets.all(8.0), // Adjust padding as needed
                    child: Image.asset(
                      'assets/images/icons/man.png', // Path to your asset image
                      width: 24, // Set the width of the asset icon
                      height: 24, // Set the height of the asset icon
                    ),
                  ),
                  onSelected: (value) {
                    if (value == 'logout') {
                      _logout(context); // Pass BuildContext correctly
                    } else if (value == 'credibility') {
                      // Navigate to credibility score page
                      // Navigator.pushNamed(context, CredibilityScoreScreen.id);
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    return [
                      const PopupMenuItem<String>(
                        value: 'credibility',
                        child: Text('View Credibility Score'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'logout',
                        child: Text('Logout'),
                      ),
                    ];
                  },
                );
              }
            },
          ),
        ],
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              ElevatedButton(
                onPressed: pickVideo,
                child: Text('Pick Video'),
              ),
              const SizedBox(height: 20),

              // Show the video player if a video is selected
              if (_pickedVideo != null && _pickedVideo != 'No video selected')
                Column(
                  children: [
                    FutureBuilder(
                      future: _initializeVideoPlayerFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done) {
                          return AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: VideoPlayer(_videoController!),
                          );
                        } else {
                          return const CircularProgressIndicator();
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        // Toggle video playback
                        setState(() {
                          if (_videoController!.value.isPlaying) {
                            _videoController!.pause();
                          } else {
                            _videoController!.play();
                          }
                        });
                      },
                      child: Text(
                        _videoController?.value.isPlaying ?? false
                            ? 'Pause Video'
                            : 'Play Video',
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        if (_pickedVideo != null) {
                          File videoFile = File(_pickedVideo!);
                          sendVideoToBackend(videoFile); // Send the video to the backend
                        }
                      },
                      child: const Text('Check the video'),
                    ),
                  ],
                )
              else
                const Text('No video selected'),
            ],
          ),
        ),
      ),
    );
  }
}
