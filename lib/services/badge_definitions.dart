final List<Map<String, dynamic>> badgeDefinitions = [
  {
    'id': 'first-challenge',
    'name': 'First Challenge',
    'criteria': {'type': 'challenges_solved', 'count': 1},
  },
  {
    'id': 'streak-7',
    'name': '7-Day Streak',
    'criteria': {'type': 'current_streak', 'count': 7},
  },
  {
    'id': 'streak-30',
    'name': '30-Day Streak',
    'criteria': {'type': 'current_streak', 'count': 30},
  },
  {
    'id': 'accuracy-90',
    'name': 'Accuracy Ace',
    'criteria': {'type': 'accuracy', 'min': 0.9},
  },
  {
    'id': 'speedster',
    'name': 'Speedster',
    'criteria': {'type': 'speed', 'max_seconds': 60},
  },
  {
    'id': 'solved-10',
    'name': '10 Challenges Solved',
    'criteria': {'type': 'challenges_solved', 'count': 10},
  },
  {
    'id': 'solved-50',
    'name': '50 Challenges Solved',
    'criteria': {'type': 'challenges_solved', 'count': 50},
  },
  {
    'id': 'solved-100',
    'name': '100 Challenges Solved',
    'criteria': {'type': 'challenges_solved', 'count': 100},
  },
  {
    'id': 'perfect-score',
    'name': 'Perfectionist',
    'criteria': {'type': 'accuracy', 'min': 1.0},
  },
  {
    'id': 'comeback',
    'name': 'Comeback Kid',
    'criteria': {'type': 'comeback'},
  },
];
