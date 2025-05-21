class CallDay {
  final DateTime date;
  final bool called;

  CallDay({required this.date, required this.called});

  factory CallDay.fromJson(Map<String, dynamic> json) {
    return CallDay(
      date: DateTime.parse(json['date']),
      called: json['called'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'called': called,
    };
  }

  String get formattedDate => '${date.month}/${date.day}';
}
