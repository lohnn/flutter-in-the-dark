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
import 'package:timeago_flutter/timeago_flutter.dart'
    hide setLocaleMessages, setDefaultLocale;
import 'package:timeago_flutter/timeago_flutter.dart' as timeago
    show setLocaleMessages, setDefaultLocale;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  timeago.setLocaleMessages('en', OverrideEnTimeAgo());
  timeago.setDefaultLocale('en');
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
  DateTime? _startTime;
  DateTime? _endTime;
  Timer? _timer;

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
          case {
              'path': final String path,
              'startTime': final Timestamp startTime,
              'endTime': final Timestamp endTime,
            }:
            setState(() {
              _currentPath = path;
              _endTime = endTime.toDate();
              countDown(startTime.toDate());
            });
            break;
          default:
            debugPrint('The map does not contain the key "path"');
        }
      },
    );
    super.initState();
  }

  void countDown(DateTime startTime) {
    _timer?.cancel();
    _timer = null;

    if (DateTime.now().isAfter(startTime)) return;
    _startTime = startTime;

    _timer = Timer(
      startTime.difference(DateTime.now()),
      () {
        setState(() {
          _timer?.cancel();
          _timer = null;
          _startTime = null;
        });
      },
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_startTime case final startTime?) {
      return Scaffold(
        body: Timeago(
          refreshRate: const Duration(seconds: 1),
          date: startTime,
          allowFromNow: true,
          builder: (context, time) {
            return Text(
              'Starting $_currentPath challenge in $time',
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: switch (_endTime) {
          null => null,
          final endTime => Timeago(
              refreshRate: const Duration(seconds: 1),
              date: endTime,
              allowFromNow: true,
              builder: (context, time) {
                // TODO: Figure out a nice way to shake screen and throw confetti
                if (DateTime.now().isAfter(endTime)) {
                  return const Text('Time over!');
                }
                return Text(time);
              },
            ),
        },
      ),
      body: switch (_currentPath) {
        'first' => const First(),
        'second' => const Second(),
        'third' => const Third(),
        'fourth' => const Fourth(),
        'finals' => const Final(),
        _ => const HomeScreen(),
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  static const path = "/home";

  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('No challenge ongoing right now.'),
    );
  }
}

class OverrideEnTimeAgo extends EnMessages {
  @override
  String suffixFromNow() => '';

  @override
  String suffixAgo() => '';

  @override
  String lessThanOneMinute(int seconds) => '$seconds seconds';
}
