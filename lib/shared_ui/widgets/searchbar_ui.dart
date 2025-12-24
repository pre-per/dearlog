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
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.12))
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(Icons.search, size: 25, color: Colors.grey[400]),
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
                  hintText: '제목, 내용, 날짜, 감정 등 검색',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[100],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

