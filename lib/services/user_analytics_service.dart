import 'package:neurobits/services/supabase.dart';
import 'package:neurobits/services/groq_service.dart';
import 'package:neurobits/services/recommendation_cache_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:math';

class UserAnalyticsService {
  static Future<Map<String, TopicPerformance>> getUserPerformanceVector(
      String userId) async {
    final stats = await SupabaseService.client
        .from('user_topic_stats')
        .select(
            'topic_id, attempts, correct, total, avg_accuracy, last_attempted')
        .eq('user_id', userId);

    final topicNames =
        await SupabaseService.client.from('topics').select('id, name');

    final topicIdToName = Map<String, String>.fromEntries(
      topicNames.map<MapEntry<String, String>>(
          (t) => MapEntry(t['id'] as String, t['name'] as String)),
    );

    final performanceMap = <String, TopicPerformance>{};

    for (final stat in stats) {
      final topicId = stat['topic_id'] as String;
      final topicName = topicIdToName[topicId] ?? 'Unknown';

      performanceMap[topicName] = TopicPerformance(
        topicId: topicId,
        topicName: topicName,
        attempts: stat['attempts'] as int? ?? 0,
        correct: stat['correct'] as int? ?? 0,
        total: stat['total'] as int? ?? 0,
        accuracy: (stat['avg_accuracy'] as num?)?.toDouble() ?? 0.0,
        lastAttempted: stat['last_attempted'] != null
            ? DateTime.parse(stat['last_attempted'] as String)
            : null,
      );
    }

    return performanceMap;
  }

  static Future<List<PersonalizedRecommendation>>
      getPersonalizedRecommendations({
    required String userId,
    int limit = 12,
    bool forceRefresh = false,
  }) async {
    try {
      if (!forceRefresh) {
        final cached =
            await RecommendationCacheService.getCachedRecommendations(userId);
        if (cached != null && cached.isNotEmpty) {
          debugPrint('✓ Using cached recommendations (${cached.length} items)');
          return cached.take(limit).toList();
        }
      }

      final performanceData = await getUserPerformanceVector(userId);
      final userPreferences = await _getUserPreferences(userId);
      final allTopics = await _getAllAvailableTopics();

      final aiRecommendations = await _generateAIRecommendations(
        userId: userId,
        performanceData: performanceData,
        userPreferences: userPreferences,
        availableTopics: allTopics,
        limit: limit,
      );

      await RecommendationCacheService.cacheRecommendations(
          userId, aiRecommendations);
      debugPrint('✓ Cached ${aiRecommendations.length} recommendations');

      return aiRecommendations;
    } catch (e) {
      debugPrint('Error getting personalized recommendations: $e');
      final cached =
          await RecommendationCacheService.getCachedRecommendations(userId);
      return cached ?? [];
    }
  }

  static double _calculateOverallAccuracy(
      Map<String, TopicPerformance> allPerformance) {
    if (allPerformance.isEmpty) return 0.6;

    double totalAccuracy = 0.0;
    int count = 0;

    for (final performance in allPerformance.values) {
      if (performance.attempts > 0) {
        totalAccuracy += performance.accuracy;
        count++;
      }
    }

    return count > 0 ? totalAccuracy / count : 0.6;
  }

  static double _calculateExplorationReadiness(
      Map<String, TopicPerformance> performanceData) {
    if (performanceData.isEmpty) return 0.3;

    final confidenceBoost = performanceData.values
            .where((p) => p.accuracy >= 0.8 && p.attempts >= 3)
            .length /
        max(performanceData.length, 1);

    return min(0.9, 0.3 + (confidenceBoost * 0.6));
  }

  static Future<Map<String, dynamic>> _calculateExplorationBehavior(
      Map<String, TopicPerformance> performanceData,
      List<String> exploredDomains) async {
    final totalTopics = performanceData.length;
    final domainCount = exploredDomains.length;

    final chronologicalTopics = performanceData.values
        .where((p) => p.lastAttempted != null)
        .toList()
      ..sort((a, b) => a.lastAttempted!.compareTo(b.lastAttempted!));

    int explorationJumps = 0;
    String? lastDomain;

    final recentTopics = chronologicalTopics.take(20).toList();

    for (final topic in recentTopics) {
      final currentDomain = await _getTopicDomain(topic.topicName);
      if (lastDomain != null && currentDomain != lastDomain) {
        explorationJumps++;
      }
      lastDomain = currentDomain;
    }

    double boldnessLevel = 0.3;
    if (totalTopics > 10 && domainCount > 2) {
      boldnessLevel = min(
          0.9, 0.3 + (explorationJumps / max(recentTopics.length, 1)) * 1.2);
    }

    return {
      'exploration_history': explorationJumps,
      'domain_diversity': domainCount,
      'boldness_level': boldnessLevel,
    };
  }

  static Future<String> _getTopicDomain(String topicName) async {
    final cached =
        await RecommendationCacheService.getCachedTopicDomain(topicName);
    if (cached != null) {
      return cached;
    }

    try {
      final prompt = '''
Classify this learning topic into one of these broad domains. Return ONLY the domain name, nothing else.

Topic: "$topicName"

Domains:
- Programming (coding, software development, web development, mobile apps, etc.)
- Mathematics (math, statistics, calculus, algebra, geometry, etc.)
- Science (physics, chemistry, biology, research methods, etc.)
- Business (entrepreneurship, management, marketing, finance, economics, etc.)
- Design (UI/UX, graphic design, product design, etc.)
- Data (data science, analytics, machine learning, AI, etc.)
- General (everything else)

Return only the domain name:''';

      final response = await GroqService.getAIResponse(prompt);
      final domain = response.trim();

      const validDomains = [
        'Programming',
        'Mathematics',
        'Science',
        'Business',
        'Design',
        'Data',
        'General'
      ];

      final validDomain = validDomains.contains(domain) ? domain : 'General';
      await RecommendationCacheService.cacheTopicDomain(topicName, validDomain);

      return validDomain;
    } catch (e) {
      debugPrint('Error classifying topic domain: $e');
      return 'General';
    }
  }

  static Future<double> _calculateProgressionSafety(
      Map<String, TopicPerformance> performanceData) async {
    if (performanceData.isEmpty) return 0.9;

    final domainConsistency = <String, List<double>>{};

    final recentTopics = performanceData.entries.take(15).toList();

    for (final entry in recentTopics) {
      final domain = await _getTopicDomain(entry.key);
      domainConsistency.putIfAbsent(domain, () => []);
      domainConsistency[domain]!.add(entry.value.accuracy);
    }

    double avgConsistency = 0.0;
    int domainCount = 0;

    domainConsistency.forEach((domain, accuracies) {
      if (accuracies.length > 1) {
        final avgAccuracy =
            accuracies.reduce((a, b) => a + b) / accuracies.length;
        avgConsistency += avgAccuracy;
        domainCount++;
      }
    });

    if (domainCount == 0) return 0.8;

    avgConsistency /= domainCount;
    return min(0.9, max(0.3, avgConsistency));
  }

  static Future<List<PersonalizedRecommendation>> _generateAIRecommendations({
    required String userId,
    required Map<String, TopicPerformance> performanceData,
    Map<String, dynamic>? userPreferences,
    required List<Map<String, dynamic>> availableTopics,
    required int limit,
  }) async {
    try {
      final userProfile =
          await _buildUserLearningProfile(performanceData, userPreferences);

      final aiPrompt = _buildRecommendationPrompt(userProfile, availableTopics);

      final aiResponse =
          await GroqService.getAIResponse(aiPrompt, maxTokens: 12000);

      final recommendations = await _parseAIRecommendations(
          aiResponse, availableTopics, performanceData, userPreferences);

      debugPrint(
          '[_generateAIRecommendations] Successfully parsed ${recommendations.length} recommendations');
      return recommendations.take(limit).toList();
    } catch (e, stackTrace) {
      debugPrint('Error generating AI recommendations: $e');
      debugPrint('Stack trace: $stackTrace');
      return _generateFallbackRecommendations(
          performanceData, availableTopics, userPreferences, limit);
    }
  }

  static Future<Map<String, dynamic>> _buildUserLearningProfile(
    Map<String, TopicPerformance> performanceData,
    Map<String, dynamic>? userPreferences,
  ) async {
    final strongAreas = <String>[];
    final weakAreas = <String>[];
    final recentTopics = <String>[];
    final exploredDomains = <String>[];
    final potentialBridges = <String>[];

    performanceData.forEach((topic, performance) {
      if (performance.accuracy >= 0.8) {
        strongAreas.add(topic);
      } else if (performance.accuracy < 0.6) {
        weakAreas.add(topic);
      }

      if (performance.lastAttempted != null) {
        final daysSince =
            DateTime.now().difference(performance.lastAttempted!).inDays;
        if (daysSince < 14) {
          recentTopics.add(topic);
        }
      }

      final topicLower = topic.toLowerCase();
      if (topicLower.contains('python') ||
          topicLower.contains('programming') ||
          topicLower.contains('code') ||
          topicLower.contains('javascript')) {
        exploredDomains.add('Programming');
        if (performance.accuracy >= 0.75) {
          potentialBridges.add('Programming-to-Business');
          potentialBridges.add('Programming-to-DataScience');
          potentialBridges.add('Programming-to-Entrepreneurship');
        }
      }
      if (topicLower.contains('math') ||
          topicLower.contains('calculus') ||
          topicLower.contains('algebra') ||
          topicLower.contains('statistics')) {
        exploredDomains.add('Mathematics');
        if (performance.accuracy >= 0.75) {
          potentialBridges.add('Math-to-DataScience');
          potentialBridges.add('Math-to-Business');
          potentialBridges.add('Math-to-Finance');
        }
      }
      if (topicLower.contains('business') ||
          topicLower.contains('management') ||
          topicLower.contains('economics')) {
        exploredDomains.add('Business');
        if (performance.accuracy >= 0.75) {
          potentialBridges.add('Business-to-Tech');
          potentialBridges.add('Business-to-SaaS');
        }
      }
      if (topicLower.contains('science') ||
          topicLower.contains('physics') ||
          topicLower.contains('chemistry') ||
          topicLower.contains('biology')) {
        exploredDomains.add('Science');
        if (performance.accuracy >= 0.75) {
          potentialBridges.add('Science-to-DataScience');
          potentialBridges.add('Science-to-Research');
        }
      }
    });

    final explorationMetrics =
        await _calculateExplorationBehavior(performanceData, exploredDomains);

    return {
      'strong_areas': strongAreas,
      'weak_areas': weakAreas,
      'recent_topics': recentTopics,
      'explored_domains': exploredDomains.toSet().toList(),
      'potential_bridges': potentialBridges.toSet().toList(),
      'total_topics_attempted': performanceData.length,
      'average_accuracy': _calculateOverallAccuracy(performanceData),
      'exploration_readiness': _calculateExplorationReadiness(performanceData),
      'exploration_history': explorationMetrics['exploration_history'],
      'domain_diversity': explorationMetrics['domain_diversity'],
      'boldness_level': explorationMetrics['boldness_level'],
      'progression_safety': await _calculateProgressionSafety(performanceData),
      'learning_goal': userPreferences?['learning_goal'] ?? 'Skill Enhancement',
      'experience_level':
          userPreferences?['experience_level'] ?? 'Intermediate',
      'interested_topics': userPreferences?['interested_topics'] ?? [],
      'learning_style': userPreferences?['learning_style'] ?? 'Mixed',
      'time_commitment': userPreferences?['time_commitment'] ?? 15,
      'preferred_question_types':
          userPreferences?['preferred_question_types'] ?? ['quiz'],
    };
  }

  static String _buildRecommendationPrompt(Map<String, dynamic> userProfile,
      List<Map<String, dynamic>> availableTopics) {
    final topicList = availableTopics
        .map((t) => {
              'name': t['name'],
              'category': t['category'] ?? 'General',
              'difficulty': t['difficulty'] ?? 'Medium',
              'description': t['description'] ?? '',
            })
        .take(50)
        .toList();

    return '''
You are a behavioral learning psychologist who creates irresistible, personalized learning experiences. Use psychological triggers and behavioral analytics to recommend topics that maximize engagement and learning momentum.

User Psychology Profile:
- Mastery Areas: ${userProfile['strong_areas']} (confidence boosters)
- Struggle Points: ${userProfile['weak_areas']} (growth opportunities)
- Recent Engagement: ${userProfile['recent_topics']} (momentum indicators)
- Learning Streaks: ${userProfile['explored_domains']} (pattern recognition)
- Success Bridges: ${userProfile['potential_bridges']} (confidence transfer paths)
- Accuracy Rate: ${(userProfile['average_accuracy'] * 100).toStringAsFixed(1)}% (competence level)
- Adventure Readiness: ${(userProfile['exploration_readiness'] * 100).toStringAsFixed(1)}% (novelty tolerance)
- Exploration History: ${userProfile['exploration_history']} jumps across domains
- Domain Diversity: ${userProfile['domain_diversity']} different areas explored
- Boldness Level: ${(userProfile['boldness_level'] * 100).toStringAsFixed(1)}% (based on actual behavior)
- Progression Safety: ${(userProfile['progression_safety'] * 100).toStringAsFixed(1)}% (conservative vs aggressive)
- Motivation: ${userProfile['learning_goal']} (driving force)
- Self-Perception: ${userProfile['experience_level']} (identity alignment)
- Curiosity Areas: ${userProfile['interested_topics']} (intrinsic motivation)
- Preferences: ${userProfile['learning_style']}, ${userProfile['time_commitment']}min sessions

**CRITICAL: Balanced Progression Rules with Exploration**
- NEW USERS (0-3 topics): Start conservative but include 1-2 exploratory picks
- CAUTIOUS USERS (low boldness <40%): 70% related + 30% adjacent/exploratory
- ADVENTUROUS USERS (high boldness >70%): 50% related + 50% cross-domain jumps
- HIGH SAFETY (>80%): Focus on proven domains but suggest 1 "curiosity pick"
- LOW SAFETY (<50%): More experimental, user enjoys exploring

**Diversification Strategy:**
- Include at LEAST 2 cross-domain recommendations (e.g., Math → Science, Code → Design)
- Add 1 "wildcard" topic from a completely different field to spark curiosity
- Balance depth (mastery within domain) with breadth (exploration across domains)

**Examples of Good Diversity:**
- NEW: "Addition" + "Subtraction" (related) + "Basic Patterns" (exploratory)
- CAUTIOUS: "Python Lists" (related) + "Web Design Basics" (adjacent) + "Logic Puzzles" (exploratory)
- ADVENTUROUS: "Python Expert" + "JavaScript Fundamentals" + "System Design" + "UI/UX Principles"

Available Topics:
${jsonEncode(topicList)}

**MULTI-LAYERED RECOMMENDATION INTELLIGENCE:**

**LAYER 1: Semantic Topic Analysis**
- Analyze each available topic for semantic relationships to user's mastery areas
- Calculate conceptual distance (direct prerequisite vs tangentially related vs completely novel)
- Identify skill transfer opportunities (programming logic → math logic → business logic)
- Map knowledge dependency chains (prerequisite → current → next logical step)

**LAYER 2: Learning Psychology Optimization**
- Apply Zone of Proximal Development (optimal challenge level calculation)
- Use Spacing Effect principles for revisiting topics
- Implement Interleaving theory (mix different but related concepts)
- Apply Elaborative Interrogation (topics that answer "why" questions about their interests)

**LAYER 3: Behavioral Pattern Recognition**
- Analyze user's learning velocity (fast vs methodical learners)
- Detect preference patterns (theoretical vs practical, broad vs deep)
- Identify engagement triggers (what topics led to longest sessions)
- Recognize avoidance patterns (consistently skipped topic types)

**LAYER 4: Personalized Motivation Matching**
- Match topics to intrinsic motivators (mastery, autonomy, purpose)
- Apply Achievement Goal Theory (performance vs mastery orientation)
- Use Self-Determination Theory principles
- Create compelling "why learn this" narratives

**LAYER 5: Advanced Filtering & Ranking**
- Cross-reference multiple data points for hyper-personalization
- Apply diminishing returns logic (don't over-recommend similar topics)
- Balance exploration vs exploitation using multi-armed bandit principles
- Use collaborative filtering insights without compromising privacy

Create 2 psychologically optimized groups (6 topics each):

**GROUP 1: "We think you might love these..." (New Topic Discovery)**
- Criteria: Recommend NEW TOPICS (not existing quizzes) based on semantic progression
- Format: Topic name + description cards (quiz generated on-demand when clicked)
- Examples: Did "Addition" → suggest "Subtraction" topic, Did "Python Basics" → suggest "JavaScript Fundamentals" topic
- Psychology: Curiosity gap + competence building + natural progression

**GROUP 2: "Want to touch on these topics again?" (Past Performance Review)**
- Criteria: Recommend EXISTING TOPICS/QUIZZES they've attempted before or practice variations
- Format: Actual quiz cards or practice variations of past topics
- Examples: Did "Algebra" → suggest "Simplifying Equations" quiz, Did "Python Functions" → suggest "Advanced Python Functions" quiz
- Psychology: Spaced repetition + mastery motivation + confidence building

**CRITICAL OUTPUT FORMAT DIFFERENCE:**
- GROUP 1: Return topic_name + topic_description (no quiz_id needed)
- GROUP 2: Return existing quiz names or practice variations (can reference actual quiz content)

For each recommendation, provide ultra-detailed analysis:
- topic_name: (exactly as shown in available topics OR new topic name for might_love)
- topic_description: (brief description for might_love group, can be empty for touch_again)
- group: "might_love" or "touch_again"
- content_type: "new_topic" (for might_love) or "existing_quiz" (for touch_again)
- semantic_relevance: (0.1-1.0 how related to their mastery areas)
- challenge_optimality: (0.1-1.0 perfect difficulty balance)
- motivation_alignment: (0.1-1.0 matches their goals/interests)
- learning_psychology: (which learning science principle applied)
- behavioral_insight: (what pattern from their behavior led to this choice)
- skill_transfer_potential: (0.1-1.0 how much existing skills help)
- engagement_prediction: (0.1-1.0 likelihood of deep engagement)
- personalized_reason: (compelling explanation with "why this, why now")
- composite_score: (0.1-1.0 weighted combination of all factors)
- difficulty: Easy|Medium|Hard

**CRITICAL: Use all 5 layers of analysis for each recommendation.**

Response format (JSON array):
[{
  "topic_name": "Subtraction Fundamentals",
  "topic_description": "Master subtraction with borrowing and multi-digit problems",
  "group": "might_love",
  "content_type": "new_topic",
  "semantic_relevance": 0.92,
  "challenge_optimality": 0.95,
  "motivation_alignment": 0.78,
  "learning_psychology": "Zone of Proximal Development + Sequential Learning",
  "behavioral_insight": "User mastered addition with 95% accuracy, ready for next arithmetic operation",
  "skill_transfer_potential": 0.88,
  "engagement_prediction": 0.91,
  "personalized_reason": "Since you've mastered addition, subtraction is the perfect next step - it uses the same number sense but introduces the concept of 'taking away'.",
  "composite_score": 0.89,
  "difficulty": "Medium"
},
{
  "topic_name": "Algebra - Simplifying Equations",
  "topic_description": "",
  "group": "touch_again",
  "content_type": "existing_quiz",
  "semantic_relevance": 0.78,
  "challenge_optimality": 0.82,
  "motivation_alignment": 0.85,
  "learning_psychology": "Spaced Repetition + Mastery Learning",
  "behavioral_insight": "User attempted algebra with 65% accuracy, showing room for improvement",
  "skill_transfer_potential": 0.75,
  "engagement_prediction": 0.88,
  "personalized_reason": "You showed good progress in algebra before. Let's revisit with equation simplification to build that confidence up to mastery level.",
  "composite_score": 0.82,
  "difficulty": "Medium"
}]
''';
  }

  static Future<List<PersonalizedRecommendation>> _parseAIRecommendations(
    String aiResponse,
    List<Map<String, dynamic>> availableTopics,
    Map<String, TopicPerformance> performanceData,
    Map<String, dynamic>? userPreferences,
  ) async {
    try {
      String cleaned = aiResponse.replaceAll(RegExp(r'```json\s*'), '');
      cleaned = cleaned.replaceAll(RegExp(r'```\s*'), '');

      cleaned = cleaned.replaceAll(
          RegExp(r'^.*?(Reasoning|Analysis|Here|Based on).*?(?=\[)',
              caseSensitive: false, dotAll: true, multiLine: true),
          '');

      final jsonStart = cleaned.indexOf('[');
      final jsonEnd = cleaned.lastIndexOf(']') + 1;

      if (jsonStart == -1 || jsonEnd <= jsonStart) {
        debugPrint(
            '[_parseAIRecommendations] No valid JSON array found in response');
        debugPrint(
            '[_parseAIRecommendations] First 500 chars: ${aiResponse.substring(0, min(500, aiResponse.length))}');
        throw Exception('No valid JSON found in AI response');
      }

      final jsonString = cleaned.substring(jsonStart, jsonEnd);
      final List<dynamic> aiRecommendations = jsonDecode(jsonString);

      final recommendations = <PersonalizedRecommendation>[];

      for (final rec in aiRecommendations) {
        final topicName = rec['topic_name'] as String;
        final topicDescription = rec['topic_description'] as String? ?? '';
        final group = rec['group'] as String;
        final contentType = rec['content_type'] as String? ?? 'new_topic';
        final reason = rec['personalized_reason'] as String;
        final score = (rec['composite_score'] as num).toDouble();
        final difficulty = rec['difficulty'] as String;

        final semanticRelevance =
            (rec['semantic_relevance'] as num?)?.toDouble() ?? 0.5;
        final challengeOptimality =
            (rec['challenge_optimality'] as num?)?.toDouble() ?? 0.5;
        final motivationAlignment =
            (rec['motivation_alignment'] as num?)?.toDouble() ?? 0.5;
        final learningPsychology =
            rec['learning_psychology'] as String? ?? 'Unknown';
        final behavioralInsight =
            rec['behavioral_insight'] as String? ?? 'No insight';
        final skillTransferPotential =
            (rec['skill_transfer_potential'] as num?)?.toDouble() ?? 0.5;
        final engagementPrediction =
            (rec['engagement_prediction'] as num?)?.toDouble() ?? 0.5;

        final matchingTopic = availableTopics.firstWhere(
          (topic) => topic['name'] == topicName,
          orElse: () => <String, dynamic>{},
        );

        if (matchingTopic.isNotEmpty || contentType == 'new_topic') {
          recommendations.add(PersonalizedRecommendation(
            topicId: matchingTopic.isNotEmpty
                ? matchingTopic['id'] as String
                : topicName,
            topicName: topicName,
            topicDescription: topicDescription,
            category: group,
            contentType: contentType,
            reason: reason,
            score: score,
            difficulty: difficulty,
            estimatedTime: matchingTopic.isNotEmpty
                ? matchingTopic['estimated_time_minutes'] as int? ?? 15
                : 15,
            semanticRelevance: semanticRelevance,
            challengeOptimality: challengeOptimality,
            motivationAlignment: motivationAlignment,
            learningPsychology: learningPsychology,
            behavioralInsight: behavioralInsight,
            skillTransferPotential: skillTransferPotential,
            engagementPrediction: engagementPrediction,
          ));
        }
      }

      return recommendations;
    } catch (e) {
      debugPrint('Error parsing AI recommendations: $e');
      return _generateFallbackRecommendations(
          performanceData, availableTopics, userPreferences, 12);
    }
  }

  static Future<List<PersonalizedRecommendation>>
      _generateFallbackRecommendations(
    Map<String, TopicPerformance> performanceData,
    List<Map<String, dynamic>> availableTopics,
    Map<String, dynamic>? userPreferences,
    int limit,
  ) async {
    final recommendations = <PersonalizedRecommendation>[];
    final mightLove = <PersonalizedRecommendation>[];
    final touchAgain = <PersonalizedRecommendation>[];

    final now = DateTime.now();

    final spacedRepetitionCandidates = performanceData.entries.where((entry) {
      if (entry.value.lastAttempted == null) return false;
      final daysSince = now.difference(entry.value.lastAttempted!).inDays;
      return daysSince >= 7;
    }).toList();

    debugPrint(
        '[Fallback] Found ${spacedRepetitionCandidates.length} spaced repetition candidates');

    for (final entry in spacedRepetitionCandidates) {
      final topicName = entry.key;
      final performance = entry.value;
      final daysSince = now.difference(performance.lastAttempted!).inDays;

      final matchingTopic = availableTopics.firstWhere(
        (t) => t['name'] == topicName,
        orElse: () => <String, dynamic>{},
      );

      if (matchingTopic.isNotEmpty) {
        touchAgain.add(PersonalizedRecommendation(
          topicId: matchingTopic['id'] as String,
          topicName: topicName,
          category: 'touch_again',
          reason:
              'Last practiced $daysSince days ago - perfect time to review and retain your knowledge',
          score: 0.75 + (min(daysSince, 30) / 100),
          difficulty: matchingTopic['difficulty'] as String? ?? 'Medium',
          estimatedTime: matchingTopic['estimated_time_minutes'] as int? ?? 15,
        ));
      }

      if (touchAgain.length >= 6) break;
    }

    final improvementCandidates = performanceData.entries.where((entry) {
      final accuracy = entry.value.accuracy;
      return accuracy >= 0.6 && accuracy < 0.8;
    }).toList()
      ..sort((a, b) => b.value.attempts.compareTo(a.value.attempts));

    debugPrint(
        '[Fallback] Found ${improvementCandidates.length} improvement opportunity candidates');

    for (final entry in improvementCandidates) {
      if (touchAgain.length >= 6) break;

      final topicName = entry.key;
      final performance = entry.value;

      final matchingTopic = availableTopics.firstWhere(
        (t) => t['name'] == topicName,
        orElse: () => <String, dynamic>{},
      );

      if (matchingTopic.isNotEmpty &&
          !touchAgain.any((r) => r.topicName == topicName)) {
        touchAgain.add(PersonalizedRecommendation(
          topicId: matchingTopic['id'] as String,
          topicName: topicName,
          category: 'touch_again',
          reason:
              'You\'re ${(performance.accuracy * 100).toStringAsFixed(0)}% there - let\'s push to mastery level',
          score: 0.7 + (performance.attempts / 20),
          difficulty: matchingTopic['difficulty'] as String? ?? 'Medium',
          estimatedTime: matchingTopic['estimated_time_minutes'] as int? ?? 15,
        ));
      }
    }

    if (touchAgain.length < 6) {
      final lowAttemptCandidates = performanceData.entries.where((entry) {
        return entry.value.attempts < 3 && entry.value.attempts > 0;
      }).toList()
        ..sort((a, b) => b.value.accuracy.compareTo(a.value.accuracy));

      debugPrint(
          '[Fallback] Found ${lowAttemptCandidates.length} low-attempt candidates');

      for (final entry in lowAttemptCandidates) {
        if (touchAgain.length >= 6) break;

        final topicName = entry.key;
        final performance = entry.value;

        final matchingTopic = availableTopics.firstWhere(
          (t) => t['name'] == topicName,
          orElse: () => <String, dynamic>{},
        );

        if (matchingTopic.isNotEmpty &&
            !touchAgain.any((r) => r.topicName == topicName)) {
          touchAgain.add(PersonalizedRecommendation(
            topicId: matchingTopic['id'] as String,
            topicName: topicName,
            category: 'touch_again',
            reason:
                'Build consistency with more practice - strengthen your foundation',
            score: 0.65,
            difficulty: matchingTopic['difficulty'] as String? ?? 'Medium',
            estimatedTime:
                matchingTopic['estimated_time_minutes'] as int? ?? 15,
          ));
        }
      }
    }

    final attemptedTopicNames = performanceData.keys.toSet();

    for (final topic in availableTopics) {
      if (mightLove.length >= 6) break;

      final topicName = topic['name'] as String;

      if (!attemptedTopicNames.contains(topicName)) {
        final relatedToStrong = performanceData.entries.any((entry) {
          if (entry.value.accuracy < 0.75) return false;
          final category1 = topic['category'] as String?;
          final matchingTopics =
              availableTopics.where((t) => t['name'] == entry.key);
          if (matchingTopics.isEmpty) return false;
          final category2 = matchingTopics.first['category'] as String?;
          return category1 != null &&
              category2 != null &&
              category1 == category2;
        });

        final reason = relatedToStrong
            ? 'Related to topics you\'re already strong in - build on your success'
            : 'Expand your knowledge with this fresh topic';

        mightLove.add(PersonalizedRecommendation(
          topicId: topic['id'] as String,
          topicName: topicName,
          category: 'might_love',
          reason: reason,
          score: relatedToStrong ? 0.7 : 0.6,
          difficulty: topic['difficulty'] as String? ?? 'Medium',
          estimatedTime: topic['estimated_time_minutes'] as int? ?? 15,
          topicDescription: (topic['description'] as String?)?.substring(
              0, min((topic['description'] as String?)?.length ?? 0, 100)),
        ));
      }
    }

    debugPrint(
        '[Fallback] Generated ${mightLove.length} might_love and ${touchAgain.length} touch_again recommendations');

    recommendations.addAll(mightLove.take(6));
    recommendations.addAll(touchAgain.take(6));

    return recommendations;
  }

  static Future<List<Map<String, dynamic>>> _getAllAvailableTopics() async {
    final topics = await SupabaseService.client.from('topics').select(
        'id, name, difficulty, estimated_time_minutes, category, description');
    return List<Map<String, dynamic>>.from(topics);
  }

  static Future<Map<String, dynamic>?> _getUserPreferences(
      String userId) async {
    try {
      final preferences = await SupabaseService.client
          .from('user_quiz_preferences')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();
      return preferences as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('Error getting user preferences: $e');
      return null;
    }
  }
}

class TopicPerformance {
  final String topicId;
  final String topicName;
  final int attempts;
  final int correct;
  final int total;
  final double accuracy;
  final DateTime? lastAttempted;

  TopicPerformance({
    required this.topicId,
    required this.topicName,
    required this.attempts,
    required this.correct,
    required this.total,
    required this.accuracy,
    this.lastAttempted,
  });
}

class PersonalizedRecommendation {
  final String topicId;
  final String topicName;
  final String? topicDescription;
  final String category;
  final String? contentType;
  final String reason;
  final double score;
  final String difficulty;
  final int estimatedTime;

  final double? semanticRelevance;
  final double? challengeOptimality;
  final double? motivationAlignment;
  final String? learningPsychology;
  final String? behavioralInsight;
  final double? skillTransferPotential;
  final double? engagementPrediction;

  PersonalizedRecommendation({
    required this.topicId,
    required this.topicName,
    this.topicDescription,
    required this.category,
    this.contentType,
    required this.reason,
    required this.score,
    required this.difficulty,
    required this.estimatedTime,
    this.semanticRelevance,
    this.challengeOptimality,
    this.motivationAlignment,
    this.learningPsychology,
    this.behavioralInsight,
    this.skillTransferPotential,
    this.engagementPrediction,
  });

  bool get isNewTopic => contentType == 'new_topic';
  bool get isExistingQuiz => contentType == 'existing_quiz';

  String get categoryDisplayName {
    switch (category) {
      case 'might_love':
        return 'We think you might love these...';
      case 'touch_again':
        return 'Want to touch on these topics again?';
      default:
        return 'Recommended for You';
    }
  }
}
