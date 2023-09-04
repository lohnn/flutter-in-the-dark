import 'package:flutter/material.dart';
import 'package:flutter_in_the_dark/challenges/canvas.dart';
import 'package:flutter_in_the_dark/challenges/flutter_chat.dart';
import 'package:flutter_in_the_dark/challenges/finals.dart';
import 'package:flutter_in_the_dark/challenges/flutter_friend_list.dart';
import 'package:flutter_in_the_dark/challenges/mirror.dart';

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
        Mirror.path: (_) => const Mirror(),
        FlutterChat.path: (_) => const FlutterChat(),
        CanvasHouse.path: (_) => const CanvasHouse(),
        Finals.path: (_) => const Finals(),
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
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pushNamed(context, FlutterFriendList.path),
              child: const Text("Flutter Friend List"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, CanvasHouse.path),
              child: const Text("Canvas House"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, Mirror.path),
              child: const Text("Mirror"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, FlutterChat.path),
              child: const Text("Flutter Chat"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, Finals.path),
              child: const Text("Finals"),
            ),
          ],
        ),
      ),
    );
  }
}
