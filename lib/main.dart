import 'package:flutter/material.dart';
import 'package:flutter_in_the_dark/challenges/flutter_friend_list.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      routes: {
        HomeScreen.path: (_) => const HomeScreen(),
        FlutterFriendList.path: (_) => const FlutterFriendList(),
      },
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  static const path = "/home";

  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 100),
        child: ListView(
          children: [
            const Center(
              child: Text(
                "Challenges:",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pushNamed(context, FlutterFriendList.path),
              child: const Text("Flutter Friend List"),
            )
          ],
        ),
      ),
    );
  }
}
