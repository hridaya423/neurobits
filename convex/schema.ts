import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  users: defineTable({
    authSubject: v.string(),
    email: v.string(),
    emailLower: v.string(),
    username: v.optional(v.string()),
    avatarUrl: v.optional(v.string()),
    avatarSeed: v.optional(v.string()),

    points: v.number(),
    xp: v.number(),
    level: v.number(),

    streakGoal: v.number(),
    currentStreak: v.number(),
    longestStreak: v.number(),
    lastActivityAt: v.optional(v.number()),

    adaptiveDifficultyEnabled: v.boolean(),
    remindersEnabled: v.boolean(),
    streakNotifications: v.boolean(),

    onboardingComplete: v.boolean(),

    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_auth_subject", ["authSubject"])
    .index("by_email_lower", ["emailLower"]),

  categories: defineTable({
    name: v.string(),
    nameLower: v.string(),
    description: v.optional(v.string()),
    createdAt: v.number(),
  }).index("by_name_lower", ["nameLower"]),

  topics: defineTable({
    name: v.string(),
    nameLower: v.string(),
    difficulty: v.string(),
    description: v.optional(v.string()),
    estimatedTimeMinutes: v.number(),
    category: v.optional(v.string()),
    createdAt: v.number(),
  })
    .index("by_name_lower", ["nameLower"])
    .index("by_created_at", ["createdAt"]),

  learningPaths: defineTable({
    name: v.string(),
    title: v.optional(v.string()),
    description: v.optional(v.string()),
    isActive: v.boolean(),
    createdByUserId: v.optional(v.id("users")),
    createdAt: v.number(),
  })
    .index("by_is_active_and_created_at", ["isActive", "createdAt"])
    .index("by_created_by_user_id_and_created_at", [
      "createdByUserId",
      "createdAt",
    ]),

  learningPathTopics: defineTable({
    pathId: v.id("learningPaths"),
    topicId: v.id("topics"),
    stepNumber: v.number(),
    description: v.optional(v.string()),
    createdAt: v.number(),
  })
    .index("by_path_id_and_step_number", ["pathId", "stepNumber"])
    .index("by_topic_id_and_path_id", ["topicId", "pathId"]),

  challenges: defineTable({
    title: v.optional(v.string()),
    quizName: v.optional(v.string()),
    type: v.optional(v.string()),
    difficulty: v.optional(v.string()),
    question: v.optional(v.string()),
    solution: v.optional(v.string()),
    options: v.optional(
      v.array(
        v.object({
          text: v.string(),
          isCorrect: v.boolean(),
        })
      )
    ),
    questions: v.optional(
      v.array(
        v.object({
          question: v.string(),
          options: v.array(v.string()),
          correctAnswer: v.number(),
          explanation: v.optional(v.string()),
        })
      )
    ),
    questionCount: v.optional(v.number()),
    estimatedTimeSeconds: v.optional(v.number()),
    solveCount: v.number(),
    topic: v.optional(v.string()),
    topicId: v.optional(v.id("topics")),
    categoryId: v.optional(v.id("categories")),
    createdByUserId: v.optional(v.id("users")),
    createdAt: v.number(),
  })
    .index("by_created_at", ["createdAt"])
    .index("by_solve_count", ["solveCount"])
    .index("by_topic_id_and_created_at", ["topicId", "createdAt"])
    .index("by_category_id_and_difficulty", ["categoryId", "difficulty"]),

  challengeAttempts: defineTable({
    userId: v.id("users"),
    challengeId: v.id("challenges"),
    completed: v.boolean(),
    attempts: v.number(),
    timeTakenSeconds: v.number(),
    accuracy: v.optional(v.number()),
    answers: v.optional(
      v.array(
        v.object({
          questionIndex: v.number(),
          selectedOption: v.number(),
          isCorrect: v.boolean(),
          timeSpentSeconds: v.number(),
        })
      )
    ),
    createdAt: v.number(),
  })
    .index("by_user_id_and_challenge_id_and_created_at", [
      "userId",
      "challengeId",
      "createdAt",
    ])
    .index("by_user_id_and_created_at", ["userId", "createdAt"])
    .index("by_challenge_id_and_created_at", ["challengeId", "createdAt"]),

  userChallengeProgress: defineTable({
    userId: v.id("users"),
    challengeId: v.id("challenges"),
    completed: v.boolean(),
    attempts: v.number(),
    bestAccuracy: v.optional(v.number()),
    bestTimeSeconds: v.optional(v.number()),
    lastAttemptedAt: v.optional(v.number()),
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_user_id_and_challenge_id", ["userId", "challengeId"])
    .index("by_user_id_and_completed_and_last_attempted_at", [
      "userId",
      "completed",
      "lastAttemptedAt",
    ]),

  userTopicStats: defineTable({
    userId: v.id("users"),
    topicId: v.id("topics"),
    attempts: v.number(),
    correct: v.number(),
    total: v.number(),
    avgAccuracy: v.number(),
    lastAttemptedAt: v.optional(v.number()),
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_user_id_and_topic_id", ["userId", "topicId"])
    .index("by_user_id_and_last_attempted_at", ["userId", "lastAttemptedAt"]),

  userQuizPreferences: defineTable({
    userId: v.id("users"),
    defaultNumQuestions: v.number(),
    defaultDifficulty: v.string(),
    defaultTimePerQuestionSec: v.number(),
    timedModeEnabled: v.boolean(),
    quickStartEnabled: v.optional(v.boolean()),
    hintsEnabled: v.optional(v.boolean()),
    imageQuestionsEnabled: v.optional(v.boolean()),
    allowedChallengeTypes: v.array(v.string()),
    learningGoal: v.optional(v.string()),
    experienceLevel: v.optional(v.string()),
    learningStyle: v.optional(v.string()),
    timeCommitmentMinutes: v.optional(v.number()),
    interestedTopics: v.array(v.string()),
    preferredQuestionTypes: v.array(v.string()),
    updatedAt: v.number(),
  }).index("by_user_id", ["userId"]),

  userRecommendations: defineTable({
    userId: v.id("users"),
    practiceRecs: v.array(
      v.object({
        topicName: v.string(),
        accuracy: v.optional(v.number()),
        attempts: v.optional(v.number()),
        lastAttemptedAt: v.optional(v.number()),
        reason: v.optional(v.string()),
        isSuggested: v.optional(v.boolean()),
      })
    ),
    suggestedTopics: v.array(
      v.object({
        name: v.string(),
        reason: v.optional(v.string()),
        relatedTopics: v.array(v.string()),
      })
    ),
    basedOnLastAttemptAt: v.optional(v.number()),
    basedOnPreferencesUpdatedAt: v.optional(v.number()),
    source: v.optional(v.string()),
    createdAt: v.number(),
    updatedAt: v.number(),
  }).index("by_user_id", ["userId"]),

  userLearningPaths: defineTable({
    userId: v.id("users"),
    pathId: v.optional(v.id("learningPaths")),
    currentStep: v.number(),
    startedAt: v.number(),
    completedAt: v.optional(v.number()),
    isComplete: v.boolean(),
    isActive: v.optional(v.boolean()),
    durationDays: v.number(),
    dailyMinutes: v.number(),
    level: v.optional(v.string()),
    isCustom: v.boolean(),
    aiPathJson: v.optional(v.string()),
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_user_id_and_is_complete_and_started_at", [
      "userId",
      "isComplete",
      "startedAt",
    ])
    .index("by_user_id_and_is_active_and_started_at", [
      "userId",
      "isActive",
      "startedAt",
    ])
    .index("by_user_id_and_completed_at", ["userId", "completedAt"])
    .index("by_path_id_and_user_id", ["pathId", "userId"]),

  userPathChallenges: defineTable({
    userPathId: v.id("userLearningPaths"),
    userId: v.id("users"),
    day: v.number(),
    topic: v.string(),
    challengeType: v.string(),
    title: v.string(),
    description: v.string(),
    completed: v.boolean(),
    bestAccuracy: v.optional(v.number()),
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_user_path_id_and_day", ["userPathId", "day"])
    .index("by_user_path_id_and_completed_and_day", [
      "userPathId",
      "completed",
      "day",
    ])
    .index("by_user_id_and_completed_and_updated_at", [
      "userId",
      "completed",
      "updatedAt",
    ]),

  sessionAnalyses: defineTable({
    userId: v.id("users"),
    topic: v.optional(v.string()),
    quizName: v.optional(v.string()),
    analysis: v.string(),
    accuracy: v.optional(v.number()),
    totalTime: v.optional(v.number()),
    createdAt: v.number(),
  })
    .index("by_user_id_and_created_at", ["userId", "createdAt"])
    .index("by_user_id_and_topic_and_created_at", [
      "userId",
      "topic",
      "createdAt",
    ]),

  badges: defineTable({
    badgeKey: v.string(),
    name: v.string(),
    description: v.optional(v.string()),
    icon: v.optional(v.string()),
    createdAt: v.number(),
  }).index("by_badge_key", ["badgeKey"]),

  userBadges: defineTable({
    userId: v.id("users"),
    badgeId: v.id("badges"),
    awardedAt: v.number(),
  })
    .index("by_user_id_and_badge_id", ["userId", "badgeId"])
    .index("by_user_id_and_awarded_at", ["userId", "awardedAt"]),

  topicAggregates: defineTable({
    topicId: v.id("topics"),
    attempts: v.number(),
    totalAccuracy: v.number(),
    avgAccuracy: v.number(),
    updatedAt: v.number(),
  })
    .index("by_attempts_and_updated_at", ["attempts", "updatedAt"])
    .index("by_topic_id", ["topicId"]),
});
