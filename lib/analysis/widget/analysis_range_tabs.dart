import 'package:dearlog/app.dart';

class AnalysisRangeTabs extends ConsumerWidget {
  const AnalysisRangeTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(analysisRangeProvider);

    Widget tab(String label, AnalysisRange v) {
      final selected = range == v;
      return GestureDetector(
        onTap: () => ref.read(analysisRangeProvider.notifier).state = v,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white54,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 2,
                width: 26,
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        tab('일간', AnalysisRange.daily),
        tab('주간', AnalysisRange.weekly),
        tab('월간', AnalysisRange.monthly),
      ],
    );
  }
}
