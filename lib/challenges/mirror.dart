import 'package:flutter/material.dart';

class Mirror extends StatelessWidget {
  static const String path = "/mirror";

  const Mirror({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hi, I'm chat"),
      ),
      body: ListView(
        children: [
          const ListTile(
            title: Text("Wanna grab a beer 🍻?"),
          ),
          Transform.scale(
            scaleX: -1,
            child: const ListTile(
              title: Text("Yes! When?"),
            ),
          ),
          const ListTile(
            title: Text("Tomorrow morning?"),
          ),
          Transform.scale(
            scaleX: -1,
            child: const ListTile(
              title: Text("Nah, I'm good."),
            ),
          ),
          const Divider(),
          const Center(
            child: Text(
              "End of chat",
              style: TextStyle(color: Colors.blueGrey),
            ),
          ),
        ],
      ),
    );
  }
}
