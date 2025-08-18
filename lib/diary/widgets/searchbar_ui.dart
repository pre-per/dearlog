import 'package:flutter/material.dart';

class SearchBarUI extends StatelessWidget {
  const SearchBarUI({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(Icons.search, size: 25, color: Colors.grey[600],),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: '검색어를 입력하세요',
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600
                    )
                  ),
                ),
              ),
            ]
          )
        ),
      ),
    );
  }
}
