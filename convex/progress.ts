import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { requireUser } from "./lib/auth";


export const recordQuizCompletion = mutation({
  args: {
    challengeId: v.id("challenges"),
    completed: v.boolean(),
    attempts: v.number(),
    timeTakenSeconds: v.number(),
    accuracy: v.optional(v.number()),
    timezoneOffsetMinutes: v.optional(v.number()),
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

    await ctx.db.insert("challengeAttempts", {
      userId,
      challengeId: args.challengeId,
      completed: args.completed,
      attempts: args.attempts,
      timeTakenSeconds: args.timeTakenSeconds,
      accuracy: args.accuracy,
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
    const totalAttempts =
      topicStats?.attempts ?? (attemptCount > 0 ? attemptCount : progressAttempts);

    return {
      totalAttempts,
      avgTimeSeconds,
      avgAccuracy,
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

    return {
      totalAttempts: attempts.length,
      completionRate: completedCount / attempts.length,
      avgTimeSeconds: totalTime / attempts.length,
      avgAccuracy: avgAcc,
    };
  },
});
