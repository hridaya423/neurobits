import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { requireUser } from "./lib/auth";


export const recordQuizCompletion = mutation({
  args: {
    challengeId: v.id("challenges"),
    examTargetId: v.optional(v.id("userExamTargets")),
    completed: v.boolean(),
    attempts: v.number(),
    timeTakenSeconds: v.number(),
    accuracy: v.optional(v.number()),
    marksAwarded: v.optional(v.number()),
    marksAvailable: v.optional(v.number()),
    timezoneOffsetMinutes: v.optional(v.number()),
    answers: v.optional(
      v.array(
        v.object({
          questionIndex: v.number(),
          selectedOption: v.number(),
          selectedAnswerText: v.optional(v.string()),
          isCorrect: v.boolean(),
          timeSpentSeconds: v.number(),
          marksAwarded: v.optional(v.number()),
          marksAvailable: v.optional(v.number()),
          reasonCode: v.optional(v.string()),
          reasonDetail: v.optional(v.string()),
        })
      )
    ),
  },
  returns: v.object({
    newBadges: v.array(v.id("badges")),
    streakUpdated: v.boolean(),
    pathAdvanced: v.boolean(),
    newLevel: v.optional(v.number()),
  }),
  handler: async (ctx, args) => {
    const userId = await requireUser(ctx);
    const now = Date.now();

    let validatedExamTargetId = args.examTargetId;
    if (args.examTargetId !== undefined) {
      const target = await ctx.db.get(args.examTargetId);
      if (!target || target.userId !== userId) {
        validatedExamTargetId = undefined;
      }
    }

    await ctx.db.insert("challengeAttempts", {
      userId,
      challengeId: args.challengeId,
      examTargetId: validatedExamTargetId,
      completed: args.completed,
      attempts: args.attempts,
      timeTakenSeconds: args.timeTakenSeconds,
      accuracy: args.accuracy,
      marksAwarded: args.marksAwarded,
      marksAvailable: args.marksAvailable,
      answers: args.answers,
      createdAt: now,
    });

    const existingProgress = await ctx.db
      .query("userChallengeProgress")
      .withIndex("by_user_id_and_challenge_id", (q) =>
        q.eq("userId", userId).eq("challengeId", args.challengeId)
      )
      .unique();

    if (existingProgress !== null) {
      const updates: Record<string, unknown> = {
        attempts: existingProgress.attempts + 1,
        lastAttemptedAt: now,
        updatedAt: now,
      };
      if (args.completed && !existingProgress.completed) {
        updates.completed = true;
      }
      if (
        args.accuracy !== undefined &&
        (existingProgress.bestAccuracy === undefined ||
          args.accuracy > existingProgress.bestAccuracy)
      ) {
        updates.bestAccuracy = args.accuracy;
      }
      if (
        existingProgress.bestTimeSeconds === undefined ||
        args.timeTakenSeconds < existingProgress.bestTimeSeconds
      ) {
        updates.bestTimeSeconds = args.timeTakenSeconds;
      }
      await ctx.db.patch(existingProgress._id, updates);
    } else {
      await ctx.db.insert("userChallengeProgress", {
        userId,
        challengeId: args.challengeId,
        completed: args.completed,
        attempts: 1,
        bestAccuracy: args.accuracy,
        bestTimeSeconds: args.timeTakenSeconds,
        lastAttemptedAt: now,
        createdAt: now,
        updatedAt: now,
      });
    }

    const challenge = await ctx.db.get(args.challengeId);
    if (challenge !== null && challenge.topicId !== undefined) {
      const topicStats = await ctx.db
        .query("userTopicStats")
        .withIndex("by_user_id_and_topic_id", (q) =>
          q.eq("userId", userId).eq("topicId", challenge.topicId!)
        )
        .unique();

      const correctCount =
        args.answers?.filter((a) => a.isCorrect).length ?? 0;
      const totalCount = args.answers?.length ?? 0;

      if (topicStats !== null) {
        const newAttempts = topicStats.attempts + 1;
        const newCorrect = topicStats.correct + correctCount;
        const newTotal = topicStats.total + totalCount;
        const newAvg = newTotal > 0 ? newCorrect / newTotal : 0;

        await ctx.db.patch(topicStats._id, {
          attempts: newAttempts,
          correct: newCorrect,
          total: newTotal,
          avgAccuracy: newAvg,
          lastAttemptedAt: now,
          updatedAt: now,
        });
      } else {
        const avg = totalCount > 0 ? correctCount / totalCount : 0;
        await ctx.db.insert("userTopicStats", {
          userId,
          topicId: challenge.topicId!,
          attempts: 1,
          correct: correctCount,
          total: totalCount,
          avgAccuracy: avg,
          lastAttemptedAt: now,
          createdAt: now,
          updatedAt: now,
        });
      }

      const agg = await ctx.db
        .query("topicAggregates")
        .withIndex("by_topic_id", (q) => q.eq("topicId", challenge.topicId!))
        .unique();

      if (agg !== null) {
        const newAttempts = agg.attempts + 1;
        const newTotalAcc =
          agg.totalAccuracy + (args.accuracy ?? 0);
        await ctx.db.patch(agg._id, {
          attempts: newAttempts,
          totalAccuracy: newTotalAcc,
          avgAccuracy: newTotalAcc / newAttempts,
          updatedAt: now,
        });
      } else {
        const acc = args.accuracy ?? 0;
        await ctx.db.insert("topicAggregates", {
          topicId: challenge.topicId!,
          attempts: 1,
          totalAccuracy: acc,
          avgAccuracy: acc,
          updatedAt: now,
        });
      }
    }

    const user = await ctx.db.get(userId);
    if (user === null) throw new Error("User not found");

    const xpGained = args.completed ? 25 : 5;
    const pointsGained = args.completed
      ? Math.round(10 * (args.accuracy ?? 0.5))
      : 1;
    const newXp = user.xp + xpGained;
    const newPoints = user.points + pointsGained;

    const newLevel = Math.floor(newXp / 100) + 1;
    const leveledUp = newLevel > user.level;

    const offsetMs = (args.timezoneOffsetMinutes ?? 0) * 60 * 1000;
    const localNow = now - offsetMs;
    const localTodayStart = Math.floor(localNow / 86400000) * 86400000;
    const todayMs = localTodayStart + offsetMs;

    let streakUpdated = false;
    let newStreak = user.currentStreak;
    let newLongest = user.longestStreak;

    if (user.lastActivityAt === undefined || user.lastActivityAt < todayMs) {
      const yesterdayStart = todayMs - 86400000;
      if (
        user.lastActivityAt !== undefined &&
        user.lastActivityAt >= yesterdayStart
      ) {
        newStreak = user.currentStreak + 1;
      } else {
        newStreak = 1;
      }
      newLongest = Math.max(newLongest, newStreak);
      streakUpdated = true;
    }

    await ctx.db.patch(userId, {
      xp: newXp,
      points: newPoints,
      level: newLevel,
      currentStreak: newStreak,
      longestStreak: newLongest,
      lastActivityAt: now,
      updatedAt: now,
    });

    if (args.completed && challenge !== null) {
      await ctx.db.patch(args.challengeId, {
        solveCount: challenge.solveCount + 1,
      });
    }

    const newBadges: Array<typeof args.challengeId> = [];

    const completedProgress = await ctx.db
      .query("userChallengeProgress")
      .withIndex("by_user_id_and_completed_and_last_attempted_at", (q) =>
        q.eq("userId", userId).eq("completed", true)
      )
      .collect();

    const totalCompleted = completedProgress.length;

    const topicStats = await ctx.db
      .query("userTopicStats")
      .withIndex("by_user_id_and_last_attempted_at", (q) =>
        q.eq("userId", userId)
      )
      .collect();
    const uniqueTopicsAttempted = topicStats.length;

    const completedPaths = await ctx.db
      .query("userLearningPaths")
      .withIndex("by_user_id_and_is_complete_and_started_at", (q) =>
        q.eq("userId", userId).eq("isComplete", true)
      )
      .take(1);
    const hasCompletedPath = completedPaths.length > 0;

    const badgeChecks: Array<{ key: string; condition: boolean }> = [
      { key: "first-challenge", condition: totalCompleted >= 1 },
      { key: "challenge-10", condition: totalCompleted >= 10 },
      { key: "challenge-50", condition: totalCompleted >= 50 },
      { key: "challenge-100", condition: totalCompleted >= 100 },
      { key: "streak-7", condition: newStreak >= 7 },
      { key: "streak-30", condition: newStreak >= 30 },
      {
        key: "perfect-score",
        condition: args.accuracy !== undefined && args.accuracy >= 1.0,
      },
      {
        key: "speed-demon",
        condition: args.completed && args.timeTakenSeconds < 30,
      },
      {
        key: "explorer",
        condition: uniqueTopicsAttempted >= 5,
      },
      {
        key: "path-complete",
        condition: hasCompletedPath,
      },
    ];

    for (const check of badgeChecks) {
      if (!check.condition) continue;

      const badge = await ctx.db
        .query("badges")
        .withIndex("by_badge_key", (q) => q.eq("badgeKey", check.key))
        .unique();

      if (badge === null) continue;

      const existing = await ctx.db
        .query("userBadges")
        .withIndex("by_user_id_and_badge_id", (q) =>
          q.eq("userId", userId).eq("badgeId", badge._id)
        )
        .unique();

      if (existing === null) {
        await ctx.db.insert("userBadges", {
          userId,
          badgeId: badge._id,
          awardedAt: now,
        });
        newBadges.push(badge._id as any);
      }
    }

    return {
      newBadges: newBadges as any,
      streakUpdated,
      pathAdvanced: false,
      newLevel: leveledUp ? newLevel : undefined,
    };
  },
});


export const getTopicAnalytics = query({
  args: { topic: v.string() },
  returns: v.object({
    totalAttempts: v.number(),
    avgTimeSeconds: v.number(),
    avgAccuracy: v.number(),
    avgMarksPct: v.number(),
    bestMarksPct: v.number(),
    bestAccuracy: v.number(),
    bestTimeSeconds: v.number(),
    lastAttemptedAt: v.number(),
  }),
  handler: async (ctx, args) => {
    const userId = await requireUser(ctx);
    const topicName = args.topic.trim().toLowerCase();
    if (!topicName) {
      return {
        totalAttempts: 0,
        avgTimeSeconds: 0,
        avgAccuracy: 0,
        avgMarksPct: 0,
        bestMarksPct: 0,
        bestAccuracy: 0,
        bestTimeSeconds: 0,
        lastAttemptedAt: 0,
      };
    }

    const topic = await ctx.db
      .query("topics")
      .withIndex("by_name_lower", (q) => q.eq("nameLower", topicName))
      .unique();

    if (topic === null) {
      return {
        totalAttempts: 0,
        avgTimeSeconds: 0,
        avgAccuracy: 0,
        avgMarksPct: 0,
        bestMarksPct: 0,
        bestAccuracy: 0,
        bestTimeSeconds: 0,
        lastAttemptedAt: 0,
      };
    }

    const topicStats = await ctx.db
      .query("userTopicStats")
      .withIndex("by_user_id_and_topic_id", (q) =>
        q.eq("userId", userId).eq("topicId", topic._id)
      )
      .unique();

    const challenges = await ctx.db
      .query("challenges")
      .withIndex("by_topic_id_and_created_at", (q) =>
        q.eq("topicId", topic._id)
      )
      .collect();

    let attemptCount = 0;
    let progressAttempts = 0;
    let totalTime = 0;
    let timedAttempts = 0;
    let accuracySum = 0;
    let accuracyCount = 0;
    let marksPctSum = 0;
    let marksPctCount = 0;
    let bestMarksPct = 0;
    let bestAccuracy = 0;
    let bestTimeSeconds = 0;
    let lastAttemptedAt = 0;

    const deriveAccuracy = (
      answers?: Array<{ isCorrect: boolean }>
    ): number | undefined => {
      if (!answers || answers.length === 0) return undefined;
      const correct = answers.filter((a) => a.isCorrect).length;
      return correct / answers.length;
    };

    for (const challenge of challenges) {
      const progress = await ctx.db
        .query("userChallengeProgress")
        .withIndex("by_user_id_and_challenge_id", (q) =>
          q.eq("userId", userId).eq("challengeId", challenge._id)
        )
        .unique();
      if (progress !== null) {
        progressAttempts += progress.attempts;
        if (
          progress.bestAccuracy !== undefined &&
          progress.bestAccuracy > bestAccuracy
        ) {
          bestAccuracy = progress.bestAccuracy;
        }
        if (
          progress.bestTimeSeconds !== undefined &&
          progress.bestTimeSeconds > 0 &&
          (bestTimeSeconds === 0 ||
            progress.bestTimeSeconds < bestTimeSeconds)
        ) {
          bestTimeSeconds = progress.bestTimeSeconds;
        }
        if (
          progress.lastAttemptedAt !== undefined &&
          progress.lastAttemptedAt > lastAttemptedAt
        ) {
          lastAttemptedAt = progress.lastAttemptedAt;
        }
      }

      const attempts = await ctx.db
        .query("challengeAttempts")
        .withIndex("by_user_id_and_challenge_id_and_created_at", (q) =>
          q.eq("userId", userId).eq("challengeId", challenge._id)
        )
        .collect();

      for (const attempt of attempts) {
        attemptCount += 1;
        const attemptTime = attempt.timeTakenSeconds;
        if (attemptTime !== undefined && attemptTime > 0) {
          totalTime += attemptTime;
          timedAttempts += 1;
          if (bestTimeSeconds === 0 || attemptTime < bestTimeSeconds) {
            bestTimeSeconds = attemptTime;
          }
        }

        const attemptAccuracy =
          attempt.accuracy ??
          deriveAccuracy(
            attempt.answers as Array<{ isCorrect: boolean }> | undefined
          );
        if (attemptAccuracy !== undefined) {
          accuracySum += attemptAccuracy;
          accuracyCount += 1;
          if (attemptAccuracy > bestAccuracy) {
            bestAccuracy = attemptAccuracy;
          }
        }

        if (
          attempt.marksAwarded !== undefined &&
          attempt.marksAvailable !== undefined &&
          attempt.marksAvailable > 0
        ) {
          const marksPct = attempt.marksAwarded / attempt.marksAvailable;
          marksPctSum += marksPct;
          marksPctCount += 1;
          if (marksPct > bestMarksPct) {
            bestMarksPct = marksPct;
          }
        }

        if (
          attempt.createdAt !== undefined &&
          attempt.createdAt > lastAttemptedAt
        ) {
          lastAttemptedAt = attempt.createdAt;
        }
      }
    }

    if (
      topicStats?.lastAttemptedAt !== undefined &&
      topicStats.lastAttemptedAt > lastAttemptedAt
    ) {
      lastAttemptedAt = topicStats.lastAttemptedAt;
    }

    const avgTimeSeconds =
      timedAttempts > 0 ? totalTime / timedAttempts : 0;
    const avgAccuracy =
      topicStats?.avgAccuracy ??
      (accuracyCount > 0 ? accuracySum / accuracyCount : 0);
    const avgMarksPct = marksPctCount > 0 ? marksPctSum / marksPctCount : 0;
    const totalAttempts =
      topicStats?.attempts ?? (attemptCount > 0 ? attemptCount : progressAttempts);

    return {
      totalAttempts,
      avgTimeSeconds,
      avgAccuracy,
      avgMarksPct,
      bestMarksPct,
      bestAccuracy,
      bestTimeSeconds,
      lastAttemptedAt,
    };
  },
});


export const getMyStats = query({
  args: {},
  returns: v.object({
    points: v.number(),
    xp: v.number(),
    level: v.number(),
    currentStreak: v.number(),
    longestStreak: v.number(),
    totalAttempts: v.number(),
    totalCompleted: v.number(),
    avgAccuracy: v.number(),
  }),
  handler: async (ctx) => {
    const userId = await requireUser(ctx);
    const user = await ctx.db.get(userId);
    if (user === null) throw new Error("User not found");

    const allProgress = await ctx.db
      .query("userChallengeProgress")
      .withIndex("by_user_id_and_challenge_id", (q) =>
        q.eq("userId", userId)
      )
      .collect();
    
    const completed = allProgress.filter(p => p.completed === true);
    
    const allAccuracies = allProgress
      .map((p) => p.bestAccuracy)
      .filter((a): a is number => a !== undefined);
    const avgAccuracy =
      allAccuracies.length > 0
        ? allAccuracies.reduce((sum, a) => sum + a, 0) / allAccuracies.length
        : 0;

    return {
      points: user.points,
      xp: user.xp,
      level: user.level,
      currentStreak: user.currentStreak,
      longestStreak: user.longestStreak,
      totalAttempts: allProgress.length,
      totalCompleted: completed.length,
      avgAccuracy,
    };
  },
});


export const getChallengeAnalytics = query({
  args: { challengeId: v.id("challenges") },
  returns: v.object({
    totalAttempts: v.number(),
    completionRate: v.number(),
    avgTimeSeconds: v.number(),
    avgAccuracy: v.number(),
    avgMarksPct: v.number(),
    avgMarksAwarded: v.number(),
    avgMarksAvailable: v.number(),
  }),
  handler: async (ctx, args) => {
    const attempts = await ctx.db
      .query("challengeAttempts")
      .withIndex("by_challenge_id_and_created_at", (q) =>
        q.eq("challengeId", args.challengeId)
      )
      .collect();

    if (attempts.length === 0) {
      return {
        totalAttempts: 0,
        completionRate: 0,
        avgTimeSeconds: 0,
        avgAccuracy: 0,
        avgMarksPct: 0,
        avgMarksAwarded: 0,
        avgMarksAvailable: 0,
      };
    }

    const completedCount = attempts.filter((a) => a.completed).length;
    const totalTime = attempts.reduce((sum, a) => sum + a.timeTakenSeconds, 0);
    const accuracies = attempts
      .map((a) => a.accuracy)
      .filter((a): a is number => a !== undefined);
    const avgAcc =
      accuracies.length > 0
        ? accuracies.reduce((sum, a) => sum + a, 0) / accuracies.length
        : 0;
    const markAttempts = attempts.filter(
      (a) =>
        a.marksAwarded !== undefined &&
        a.marksAvailable !== undefined &&
        a.marksAvailable > 0
    );
    const avgMarksAwarded =
      markAttempts.length > 0
        ? markAttempts.reduce((sum, a) => sum + (a.marksAwarded ?? 0), 0) /
          markAttempts.length
        : 0;
    const avgMarksAvailable =
      markAttempts.length > 0
        ? markAttempts.reduce((sum, a) => sum + (a.marksAvailable ?? 0), 0) /
          markAttempts.length
        : 0;
    const avgMarksPct =
      avgMarksAvailable > 0 ? avgMarksAwarded / avgMarksAvailable : 0;

    return {
      totalAttempts: attempts.length,
      completionRate: completedCount / attempts.length,
      avgTimeSeconds: totalTime / attempts.length,
      avgAccuracy: avgAcc,
      avgMarksPct,
      avgMarksAwarded,
      avgMarksAvailable,
    };
  },
});

const DAY_MS = 86400000;

type PeriodKey = "daily" | "weekly" | "monthly";

function getPeriodDays(period: PeriodKey) {
  if (period === "daily") return 1;
  return period === "monthly" ? 30 : 7;
}

function getPeriodRanges(period: PeriodKey) {
  const days = getPeriodDays(period);
  const now = Date.now();
  const currentStart = now - days * DAY_MS;
  const previousStart = currentStart - days * DAY_MS;
  return { now, currentStart, previousStart };
}

function getDayKey(ts: number) {
  return Math.floor(ts / DAY_MS);
}

function percentDelta(current: number, previous: number) {
  if (previous === 0) return current > 0 ? 1 : 0;
  return (current - previous) / Math.abs(previous);
}

async function resolveTopicName(
  ctx: any,
  cache: Map<string, string>,
  challenge: any
) {
  const topicId = challenge?.topicId?.toString();
  if (topicId && cache.has(topicId)) return cache.get(topicId) as string;
  if (challenge?.topic) return challenge.topic as string;
  if (topicId) {
    const topic = await ctx.db.get(challenge.topicId);
    if (topic !== null) {
      cache.set(topicId, topic.name);
      return topic.name as string;
    }
  }
  return "";
}

function aggregateAttempts(
  attempts: any[],
  challengeTopicMap: Map<string, string>
) {
  const totals = {
    quizzesCompleted: 0,
    totalTimeSeconds: 0,
    accuracySum: 0,
    accuracyCount: 0,
  };
  const dayBuckets = new Map<number, { count: number; accuracySum: number; accuracyCount: number }>();
  const topicAttempts = new Map<string, number>();
  const topicAccuracy = new Map<string, { sum: number; count: number }>();
  const topicSet = new Set<string>();

  for (const attempt of attempts) {
    totals.quizzesCompleted += 1;
    totals.totalTimeSeconds += attempt.timeTakenSeconds ?? 0;
    if (attempt.accuracy !== undefined) {
      totals.accuracySum += attempt.accuracy;
      totals.accuracyCount += 1;
    }

    const dayKey = getDayKey(attempt.createdAt ?? 0);
    const day = dayBuckets.get(dayKey) ?? { count: 0, accuracySum: 0, accuracyCount: 0 };
    day.count += 1;
    if (attempt.accuracy !== undefined) {
      day.accuracySum += attempt.accuracy;
      day.accuracyCount += 1;
    }
    dayBuckets.set(dayKey, day);

    const challengeId = attempt.challengeId?.toString();
    if (challengeId && challengeTopicMap.has(challengeId)) {
      const topicName = challengeTopicMap.get(challengeId) as string;
      if (topicName) {
        topicSet.add(topicName);
        topicAttempts.set(topicName, (topicAttempts.get(topicName) ?? 0) + 1);
        const acc = topicAccuracy.get(topicName) ?? { sum: 0, count: 0 };
        if (attempt.accuracy !== undefined) {
          acc.sum += attempt.accuracy;
          acc.count += 1;
        }
        topicAccuracy.set(topicName, acc);
      }
    }
  }

  return {
    totals,
    dayBuckets,
    topicAttempts,
    topicAccuracy,
    topicSet,
  };
}

function buildTopicLists(
  topicAttempts: Map<string, number>,
  topicAccuracy: Map<string, { sum: number; count: number }>
) {
  const consistentTopics = Array.from(topicAttempts.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([topic, attempts]) => ({ topic, attempts }));

  const needsWork = Array.from(topicAccuracy.entries())
    .map(([topic, acc]) => ({
      topic,
      accuracy: acc.count > 0 ? acc.sum / acc.count : 0,
      attempts: topicAttempts.get(topic) ?? 0,
    }))
    .sort((a, b) => a.accuracy - b.accuracy)
    .slice(0, 5);

  return { consistentTopics, needsWork };
}

export const getReportSummary = query({
  args: {
    period: v.union(
      v.literal("daily"),
      v.literal("weekly"),
      v.literal("monthly")
    ),
    scope: v.optional(v.union(v.literal("all"), v.literal("path"))),
  },
  returns: v.object({
    period: v.string(),
    scope: v.string(),
    current: v.object({
      quizzesCompleted: v.number(),
      avgAccuracy: v.number(),
      totalTimeSeconds: v.number(),
      activeDays: v.number(),
      newTopicsCount: v.number(),
    }),
    previous: v.object({
      quizzesCompleted: v.number(),
      avgAccuracy: v.number(),
      totalTimeSeconds: v.number(),
      activeDays: v.number(),
      newTopicsCount: v.number(),
    }),
    deltas: v.object({
      quizzesCompleted: v.number(),
      avgAccuracy: v.number(),
      totalTimeSeconds: v.number(),
      activeDays: v.number(),
      newTopicsCount: v.number(),
      quizzesCompletedPct: v.number(),
      avgAccuracyPct: v.number(),
    }),
    consistentTopics: v.array(
      v.object({ topic: v.string(), attempts: v.number() })
    ),
    needsWork: v.array(
      v.object({ topic: v.string(), accuracy: v.number(), attempts: v.number() })
    ),
    mostImproved: v.optional(
      v.object({ topic: v.string(), accuracyDelta: v.number() })
    ),
  }),
  handler: async (ctx, args) => {
    const userId = await requireUser(ctx);
    const { currentStart, previousStart } = getPeriodRanges(args.period);
    const scope = args.scope ?? "all";

    let pathTopicIds: Set<string> | null = null;
    if (scope === "path") {
      const activePath = await ctx.db
        .query("userLearningPaths")
        .withIndex("by_user_id_and_is_active_and_started_at", (q) =>
          q.eq("userId", userId).eq("isActive", true)
        )
        .order("desc")
        .first();
      if (activePath?.pathId) {
        const pathTopics = await ctx.db
          .query("learningPathTopics")
          .withIndex("by_path_id_and_step_number", (q) =>
            q.eq("pathId", activePath.pathId as any)
          )
          .collect();
        pathTopicIds = new Set(
          pathTopics
            .map((t) => t.topicId?.toString())
            .filter((id): id is string => Boolean(id))
        );
      }
    }

    const attempts = await ctx.db
      .query("challengeAttempts")
      .withIndex("by_user_id_and_created_at", (q) =>
        q.eq("userId", userId).gte("createdAt", previousStart)
      )
      .collect();

    const challengeIds = Array.from(new Set(attempts.map((a) => a.challengeId?.toString()).filter(Boolean))) as string[];
    const challengeTopicMap = new Map<string, string>();
    const challengeTopicIdMap = new Map<string, string>();
    for (const id of challengeIds) {
      const challenge = (await ctx.db.get(id as any)) as any;
      if (!challenge) continue;
      if (challenge.topicId) {
        challengeTopicIdMap.set(id, challenge.topicId.toString());
      }
      const topicName = await resolveTopicName(ctx, new Map(), challenge);
      if (topicName) {
        challengeTopicMap.set(id, topicName);
      }
    }

    const scopedAttempts = pathTopicIds
      ? attempts.filter((a) => {
          const challengeId = a.challengeId?.toString();
          if (!challengeId) return false;
          const topicId = challengeTopicIdMap.get(challengeId);
          return topicId ? pathTopicIds.has(topicId) : false;
        })
      : attempts;

    const currentAttempts = scopedAttempts.filter((a) => a.createdAt >= currentStart);
    const previousAttempts = scopedAttempts.filter(
      (a) => a.createdAt >= previousStart && a.createdAt < currentStart
    );

    const currentAgg = aggregateAttempts(currentAttempts, challengeTopicMap);
    const previousAgg = aggregateAttempts(previousAttempts, challengeTopicMap);

    const currentAvgAccuracy =
      currentAgg.totals.accuracyCount > 0
        ? currentAgg.totals.accuracySum / currentAgg.totals.accuracyCount
        : 0;
    const previousAvgAccuracy =
      previousAgg.totals.accuracyCount > 0
        ? previousAgg.totals.accuracySum / previousAgg.totals.accuracyCount
        : 0;

    const currentDays = new Set(Array.from(currentAgg.dayBuckets.keys()));
    const previousDays = new Set(Array.from(previousAgg.dayBuckets.keys()));

    const newTopics = new Set<string>();
    for (const topic of currentAgg.topicSet) {
      if (!previousAgg.topicSet.has(topic)) newTopics.add(topic);
    }

    const { consistentTopics, needsWork } = buildTopicLists(
      currentAgg.topicAttempts,
      currentAgg.topicAccuracy
    );

    let mostImproved: { topic: string; accuracyDelta: number } | undefined = undefined;
    for (const [topic, acc] of currentAgg.topicAccuracy.entries()) {
      const prev = previousAgg.topicAccuracy.get(topic);
      const currentAcc = acc.count > 0 ? acc.sum / acc.count : 0;
      const prevAcc = prev && prev.count > 0 ? prev.sum / prev.count : 0;
      const delta = currentAcc - prevAcc;
      if (!mostImproved || delta > mostImproved.accuracyDelta) {
        mostImproved = { topic, accuracyDelta: delta };
      }
    }

    return {
      period: args.period,
      scope,
      current: {
        quizzesCompleted: currentAgg.totals.quizzesCompleted,
        avgAccuracy: currentAvgAccuracy,
        totalTimeSeconds: currentAgg.totals.totalTimeSeconds,
        activeDays: currentDays.size,
        newTopicsCount: newTopics.size,
      },
      previous: {
        quizzesCompleted: previousAgg.totals.quizzesCompleted,
        avgAccuracy: previousAvgAccuracy,
        totalTimeSeconds: previousAgg.totals.totalTimeSeconds,
        activeDays: previousDays.size,
        newTopicsCount: 0,
      },
      deltas: {
        quizzesCompleted: currentAgg.totals.quizzesCompleted - previousAgg.totals.quizzesCompleted,
        avgAccuracy: currentAvgAccuracy - previousAvgAccuracy,
        totalTimeSeconds: currentAgg.totals.totalTimeSeconds - previousAgg.totals.totalTimeSeconds,
        activeDays: currentDays.size - previousDays.size,
        newTopicsCount: newTopics.size,
        quizzesCompletedPct: percentDelta(
          currentAgg.totals.quizzesCompleted,
          previousAgg.totals.quizzesCompleted
        ),
        avgAccuracyPct: percentDelta(currentAvgAccuracy, previousAvgAccuracy),
      },
      consistentTopics,
      needsWork,
      mostImproved,
    };
  },
});

export const getReportDetail = query({
  args: {
    period: v.union(
      v.literal("daily"),
      v.literal("weekly"),
      v.literal("monthly")
    ),
    scope: v.optional(v.union(v.literal("all"), v.literal("path"))),
  },
  returns: v.object({
    period: v.string(),
    scope: v.string(),
    periodStart: v.number(),
    periodEnd: v.number(),
    daily: v.array(
      v.object({ date: v.number(), quizzesCompleted: v.number(), avgAccuracy: v.number() })
    ),
    topicsTried: v.array(v.string()),
    newTopics: v.array(v.string()),
    consistentTopics: v.array(
      v.object({ topic: v.string(), attempts: v.number() })
    ),
    needsWork: v.array(
      v.object({ topic: v.string(), accuracy: v.number(), attempts: v.number() })
    ),
    streak: v.object({ current: v.number(), longest: v.number(), goal: v.number() }),
    mostImproved: v.optional(
      v.object({ topic: v.string(), accuracyDelta: v.number() })
    ),
    path: v.optional(
      v.object({
        pathName: v.string(),
        completionPercent: v.number(),
        completedChallenges: v.number(),
        totalChallenges: v.number(),
        completedThisPeriod: v.number(),
        backlog: v.number(),
      })
    ),
  }),
  handler: async (ctx, args) => {
    const userId = await requireUser(ctx);
    const { now, currentStart, previousStart } = getPeriodRanges(args.period);
    const scope = args.scope ?? "all";

    let pathTopicIds: Set<string> | null = null;
    const activePath = await ctx.db
      .query("userLearningPaths")
      .withIndex("by_user_id_and_is_active_and_started_at", (q) =>
        q.eq("userId", userId).eq("isActive", true)
      )
      .order("desc")
      .first();
    if (scope === "path" && activePath?.pathId) {
      const pathTopics = await ctx.db
        .query("learningPathTopics")
        .withIndex("by_path_id_and_step_number", (q) =>
          q.eq("pathId", activePath.pathId as any)
        )
        .collect();
      pathTopicIds = new Set(
        pathTopics
          .map((t) => t.topicId?.toString())
          .filter((id): id is string => Boolean(id))
      );
    }

    const attempts = await ctx.db
      .query("challengeAttempts")
      .withIndex("by_user_id_and_created_at", (q) =>
        q.eq("userId", userId).gte("createdAt", currentStart)
      )
      .collect();

    const challengeIds = Array.from(new Set(attempts.map((a) => a.challengeId?.toString()).filter(Boolean))) as string[];
    const topicNameCache = new Map<string, string>();
    const challengeTopicMap = new Map<string, string>();
    const challengeTopicIdMap = new Map<string, string>();
    for (const id of challengeIds) {
      const challenge = (await ctx.db.get(id as any)) as any;
      if (!challenge) continue;
      if (challenge.topicId) {
        challengeTopicIdMap.set(id, challenge.topicId.toString());
      }
      const topicName = await resolveTopicName(ctx, topicNameCache, challenge);
      if (topicName) {
        challengeTopicMap.set(id, topicName);
      }
    }

    const scopedAttempts = pathTopicIds
      ? attempts.filter((a) => {
          const challengeId = a.challengeId?.toString();
          if (!challengeId) return false;
          const topicId = challengeTopicIdMap.get(challengeId);
          return topicId ? pathTopicIds.has(topicId) : false;
        })
      : attempts;

    const currentAgg = aggregateAttempts(scopedAttempts, challengeTopicMap);
    const { consistentTopics, needsWork } = buildTopicLists(
      currentAgg.topicAttempts,
      currentAgg.topicAccuracy
    );

    const topicsTried = Array.from(currentAgg.topicSet.values());

    const previousAttempts = await ctx.db
      .query("challengeAttempts")
      .withIndex("by_user_id_and_created_at", (q) =>
        q.eq("userId", userId)
          .gte("createdAt", previousStart)
          .lt("createdAt", currentStart)
      )
      .collect();
    const scopedPreviousAttempts = pathTopicIds
      ? previousAttempts.filter((a) => {
          const challengeId = a.challengeId?.toString();
          if (!challengeId) return false;
          const topicId = challengeTopicIdMap.get(challengeId);
          return topicId ? pathTopicIds.has(topicId) : false;
        })
      : previousAttempts;
    const previousAgg = aggregateAttempts(scopedPreviousAttempts, challengeTopicMap);

    const newTopics = topicsTried.filter((t) => !previousAgg.topicSet.has(t));

    const daily = Array.from(currentAgg.dayBuckets.entries())
      .sort((a, b) => a[0] - b[0])
      .map(([dayKey, bucket]) => ({
        date: dayKey * DAY_MS,
        quizzesCompleted: bucket.count,
        avgAccuracy: bucket.accuracyCount > 0 ? bucket.accuracySum / bucket.accuracyCount : 0,
      }));

    let path: any = undefined;
    if (activePath) {
      const pathChallenges = await ctx.db
        .query("userPathChallenges")
        .withIndex("by_user_path_id_and_day", (q) =>
          q.eq("userPathId", activePath._id)
        )
        .collect();
      const totalChallenges = pathChallenges.length;
      const completedChallenges = pathChallenges.filter((c) => c.completed).length;
      const backlog = pathChallenges.filter((c) => !c.completed).length;
      const completedThisPeriod = pathChallenges.filter((c) =>
        c.updatedAt !== undefined && c.updatedAt >= currentStart
      ).length;
      const pathDoc = activePath.pathId
        ? ((await ctx.db.get(activePath.pathId as any)) as any)
        : null;
      path = {
        pathName: pathDoc?.name ?? "Learning Path",
        completionPercent:
          totalChallenges > 0 ? completedChallenges / totalChallenges : 0,
        completedChallenges,
        totalChallenges,
        completedThisPeriod,
        backlog,
      };
    }

    let mostImproved: { topic: string; accuracyDelta: number } | undefined = undefined;
    for (const [topic, acc] of currentAgg.topicAccuracy.entries()) {
      const prev = previousAgg.topicAccuracy.get(topic);
      const currentAcc = acc.count > 0 ? acc.sum / acc.count : 0;
      const prevAcc = prev && prev.count > 0 ? prev.sum / prev.count : 0;
      const delta = currentAcc - prevAcc;
      if (!mostImproved || delta > mostImproved.accuracyDelta) {
        mostImproved = { topic, accuracyDelta: delta };
      }
    }

    const user = await ctx.db.get(userId);
    const streak = {
      current: user?.currentStreak ?? 0,
      longest: user?.longestStreak ?? 0,
      goal: user?.streakGoal ?? 0,
    };

    return {
      period: args.period,
      scope,
      periodStart: currentStart,
      periodEnd: now,
      daily,
      topicsTried,
      newTopics,
      consistentTopics,
      needsWork,
      streak,
      mostImproved,
      path,
    };
  },
});
