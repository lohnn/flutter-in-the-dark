import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fitd25/challenges/final.dart';
import 'package:fitd25/challenges/first.dart';
import 'package:fitd25/challenges/fourth.dart';
import 'package:fitd25/challenges/second.dart';
import 'package:fitd25/challenges/third.dart';
import 'package:fitd25/firebase_options.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark(),
      home: const AutoToggle(child: HomeScreen()),
    );
  }
}

class AutoToggle extends StatefulWidget {
  final Widget child;

  const AutoToggle({super.key, required this.child});

  @override
  State<AutoToggle> createState() => _AutoToggleState();
}

class _AutoToggleState extends State<AutoToggle> {
  late final StreamSubscription _subscription;
  String? _currentPath;

  @override
  void initState() {
    _subscription = FirebaseFirestore.instance
        .collection('fitd25')
        .doc('state')
        .snapshots()
        .listen(
      (value) {
        final data = value.data();

        switch (data) {
          case {'path': final path}:
            setState(() {
              _currentPath = path;
            });
            break;
          default:
            debugPrint('The map does not contain the key "path"');
        }
      },
    );
    super.initState();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (_currentPath) {
      'first' => const First(),
      'second' => const Second(),
      'third' => const Third(),
      'fourth' => const Fourth(),
      'finals' => const Final(),
      _ => const HomeScreen(),
    };
  }
}

class HomeScreen extends StatelessWidget {
  static const path = "/home";

  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text("Hi! I'm just waiting for better times."),
      ),
    );
  }
}
