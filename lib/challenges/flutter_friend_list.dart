import 'package:flutter/material.dart';

class FlutterFriendList extends StatefulWidget {
  static const path = "/crazyList";

  const FlutterFriendList({super.key});

  @override
  State<StatefulWidget> createState() => _FlutterFriendListState();
}

class _FlutterFriendListState extends State<FlutterFriendList> {
  bool isRevered = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Flutter Friend List"), centerTitle: true),
      body: ListView.builder(
        itemBuilder: (context, index) => ListTile(
          title: Text("Friend $index"),
        ),
        reverse: isRevered,
      ),
      floatingActionButton: FloatingActionButton(
        // Bonus point for icon
        child: const Icon(Icons.compare_arrows),
        onPressed: () => setState(() {
          isRevered = !isRevered;
        }),
      ),
    );
  }
}
