const Map<String, String> gcseCoreBoardBySubject = <String, String>{
  'Mathematics': 'Pearson Edexcel',
  'English Language': 'AQA',
  'English Literature': 'AQA',
  'Biology': 'AQA',
  'Chemistry': 'AQA',
  'Physics': 'AQA',
};

const List<String> gcseCoreSubjects = <String>[
  'Mathematics',
  'English Language',
  'English Literature',
  'Biology',
  'Chemistry',
  'Physics',
];

String? gcsePreferredBoardForSubject(String subject) {
  final normalized = subject.trim().toLowerCase();
  for (final entry in gcseCoreBoardBySubject.entries) {
    if (entry.key.toLowerCase() == normalized) {
      return entry.value;
    }
  }
  return null;
}

bool isGcseCoreSubject(String subject) {
  return gcsePreferredBoardForSubject(subject) != null;
}
