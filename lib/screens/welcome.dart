import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_1/components/components.dart'; // CustomButton component path
import 'package:app_1/screens/vid_pick.dart'; // Screen for video picker
import 'package:app_1/screens/capture_vid.dart'; // Screen for capturing video
import 'package:app_1/screens/login_screen.dart'; // Screen to redirect after logout
import 'package:flutter/services.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  static String id = 'welcome_screen';

  Future<String> _getUsername() async {
    final user = FirebaseAuth.instance.currentUser;
    return user != null ? user.displayName ?? 'User' : 'User';
  }
  Future<void> _showCredibilityScore(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Get user's credibility score from Firestore
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final credibilityScore = userDoc.data()?['credibilityScore'] ?? 0;

        // Show credibility score in a dialog
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Your Credibility Score'),
              content: Text(
                'Your current credibility score is: $credibilityScore',
                style: const TextStyle(fontSize: 18),
              ),
              actions: [
                TextButton(
                  child: const Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      } catch (e) {
        // Handle error (e.g., Firestore fetch failed)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch credibility score: $e')),
        );
      }
    } else {
      // If user is not logged in (edge case)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User is not logged in.')),
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut(); // Sign out from Firebase
    Navigator.pushReplacementNamed(context, LoginScreen.id); // Redirect to login screen
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
                    padding: const EdgeInsets.all(8.0),
                    child: Image.asset(
                      'assets/images/icons/man.png', // Path to your asset image
                      width: 24,
                      height: 24,
                    ),
                  ),
                  onSelected: (value) {
                    if (value == 'logout') {
                      _logout(context); // Call logout function
                    } else if (value == 'credibility') {
                      _showCredibilityScore(context); // Show credibility score
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
      backgroundColor: Colors.white,
      body: WillPopScope(
        onWillPop: () async {
          SystemNavigator.pop();
          return false;
        },
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center, // Center content
            children: [
              // Centered title
              const Text(
                'BLOCKFAKE',
                style: TextStyle(
                  fontSize: 32, // Adjust size as needed
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20), // Add spacing

              const SizedBox(height: 40),
              const Text(
                'Want to check your video is real or not?  '
                    '  Just upload your video to check it',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 10), // Spacing before button
              Hero(
                tag: 'login_btn',
                child: SizedBox(
                  width: 150, // Set a specific width
                  child: CustomButton(
                    buttonText: 'Upload',
                    onPressed: () {
                      Navigator.pushNamed(context, VideoPickerScreen.id);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'Want to stop deep-faking of your videos? '
                    'Protect it by taking videos through our app',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 10), // Spacing before button
              Hero(
                tag: 'capture_btn',
                child: SizedBox(
                  width: 150, // Set a specific width
                  child: CustomButton(
                    buttonText: 'Capture',
                    onPressed: () {
                      Navigator.pushNamed(context, VideoRecorderScreen.id);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
