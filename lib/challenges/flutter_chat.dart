import 'package:flutter/material.dart';

class FlutterChat extends StatefulWidget {
  static const path = "/flutterChat";

  const FlutterChat({super.key});

  @override
  State<FlutterChat> createState() => _FlutterChatState();
}

class _FlutterChatState extends State<FlutterChat> {
  final chat = [];
  final time = DateTime.now();
  TextEditingController controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Flutter Chat"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView(
          children: [
            Text(chat.join("\n")),
            TextField(
              controller: controller,
              onSubmitted: (_) {
                setState(() {
                  chat.add("[${time.toString()}]: ${controller.text}");
                  controller.text = "";
                });
              },
              decoration: const InputDecoration(
                suffix: Text("insert here"),
              ),
            ),
            OutlinedButton(
                onPressed: () {
                  setState(() {
                    chat.add("[${time.toString()}]: ${controller.text}");
                    controller.text = "";
                  });
                },
                child: const Text("Submit"))
          ],
        ),
      ),
    );
  }
}
