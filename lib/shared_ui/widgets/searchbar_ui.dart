import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../diary/providers/diary_providers.dart'; // searchQueryProvider 경로에 맞게

class SearchBarUI extends ConsumerWidget {
  const SearchBarUI({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(Icons.search, size: 25, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: TextEditingController(text: query)
                  ..selection = TextSelection.fromPosition(
                    TextPosition(offset: query.length),
                  ),
                onChanged: (v) =>
                ref.read(searchQueryProvider.notifier).state = v,
                decoration: InputDecoration(
                  hintText: '검색어를 입력하세요',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

