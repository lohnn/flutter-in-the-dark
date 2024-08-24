import 'package:ff_card/ff_card.dart';
import 'package:fitd24/challenges/final/organiser_card.dart';
import 'package:flutter/material.dart';

class Final extends StatelessWidget {
  static const path = "/final";

  const Final({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Final 🎉"),
        centerTitle: true,
      ),
      body: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: const Card(
                    clipBehavior: Clip.antiAlias,
                    margin: EdgeInsets.zero,
                    elevation: 12,
                    child: OrganiserCard(
                      host: Host(
                        name: 'Johannes Pietilä Löhnn',
                        title: 'Not just a pretty face',
                        photo: 'johannes.jpg',
                        socialText: '@lohnn',
                        socialUrl: 'https://twitter.com/lohnn',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: const Card(
                    clipBehavior: Clip.antiAlias,
                    margin: EdgeInsets.zero,
                    elevation: 12,
                    child: OrganiserCard(
                      host: Host(
                        name: 'Alek Åström',
                        title: 'I get it Done 👷‍♂️',
                        photo: 'alek.png',
                        socialText: '@MisterAlek',
                        socialUrl: 'https://twitter.com/MisterAlek',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: const Card(
                    clipBehavior: Clip.antiAlias,
                    margin: EdgeInsets.zero,
                    elevation: 12,
                    child: OrganiserCard(
                      host: Host(
                        name: 'Lukas Klingsbo',
                        title: 'At least my name has no swedish characters',
                        photo: 'lukas.jpeg',
                        socialText: '@spydon',
                        socialUrl: 'https://twitter.com/spydon',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
