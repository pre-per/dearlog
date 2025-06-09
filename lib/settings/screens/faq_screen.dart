import 'package:dearlog/settings/providers/faq_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/tile/faq_tile.dart';

class FAQScreen extends ConsumerWidget {
  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faqList = ref.watch(faqProvider);

    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: ListView(
          children: [
            const SizedBox(height: 30),
            const Text(
              '자주 묻는 질문',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 30),
            Column(
              children:
                  faqList
                      .map(
                        (item) => FaqTile(
                          question: item['question']!,
                          answer: item['answer']!,
                        ),
                      )
                      .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
