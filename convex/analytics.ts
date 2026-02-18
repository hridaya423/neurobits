import { query } from "./_generated/server";
import { v } from "convex/values";
import { requireUser } from "./lib/auth";


export const getUserPerformanceVector = query({
  args: {},
  returns: v.object({
    totalAttempts: v.number(),
    completedChallenges: v.number(),
    averageAccuracy: v.number(),
    averageTimeSeconds: v.number(),
    topicBreakdown: v.array(
      v.object({
        topicId: v.optional(v.id("topics")),
        topicName: v.string(),
        attempts: v.number(),
        accuracy: v.number(),
        lastAttemptedAt: v.optional(v.number()),
      })
    ),
    learningPatterns: v.object({
      consistencyScore: v.number(),
      difficultyProgression: v.string(),
      explorationDiversity: v.number(),
    }),
  }),
  handler: async (ctx) => {
    const userId = await requireUser(ctx);

    const allAttempts = await ctx.db
      .query("challengeAttempts")
      .withIndex("by_user_id_and_created_at", (q) => q.eq("userId", userId))
      .order("desc")
      .collect();

    const completedAttempts = allAttempts.filter((a) => a.completed);

    const accuracies = allAttempts
      .map((a) => a.accuracy)
      .filter((a): a is number => a !== undefined);
    const averageAccuracy =
      accuracies.length > 0
        ? accuracies.reduce((sum, a) => sum + a, 0) / accuracies.length
        : 0;

    const averageTimeSeconds =
      allAttempts.length > 0
        ? allAttempts.reduce((sum, a) => sum + a.timeTakenSeconds, 0) /
          allAttempts.length
        : 0;

    const topicStats = await ctx.db
      .query("userTopicStats")
      .withIndex("by_user_id_and_last_attempted_at", (q) =>
        q.eq("userId", userId)
      )
      .order("desc")
      .collect();

    const topicBreakdown: Array<{
      topicId?: (typeof topicStats)[0]["topicId"];
      topicName: string;
      attempts: number;
      accuracy: number;
      lastAttemptedAt?: number;
    }> = [];

    for (const ts of topicStats) {
      const topic = await ctx.db.get(ts.topicId);
      if (topic !== null) {
        topicBreakdown.push({
          topicId: ts.topicId,
          topicName: topic.name,
          attempts: ts.attempts,
          accuracy: ts.avgAccuracy,
          lastAttemptedAt: ts.lastAttemptedAt,
        });
      }
    }

    if (topicBreakdown.length === 0 && allAttempts.length > 0) {
      const topicNameCache = new Map<string, string>();
      const breakdownMap = new Map<
        string,
        {
          topicId?: (typeof topicStats)[0]["topicId"];
          topicName: string;
          attempts: number;
          accuracySum: number;
          accuracyCount: number;
          lastAttemptedAt?: number;
        }
      >();

      for (const attempt of allAttempts) {
        const challenge = await ctx.db.get(attempt.challengeId);
        if (challenge === null) continue;

        let topicName = challenge.topic;
        if (!topicName && challenge.topicId !== undefined) {
          const cached = topicNameCache.get(challenge.topicId.toString());
          if (cached) {
            topicName = cached;
          } else {
            const topic = await ctx.db.get(challenge.topicId);
            if (topic !== null) {
              topicName = topic.name;
              topicNameCache.set(challenge.topicId.toString(), topic.name);
            }
          }
        }

        if (!topicName) continue;

        const key = challenge.topicId
          ? challenge.topicId.toString()
          : `name:${topicName.toLowerCase()}`;

        const existing = breakdownMap.get(key) ?? {
          topicId: challenge.topicId,
          topicName,
          attempts: 0,
          accuracySum: 0,
          accuracyCount: 0,
          lastAttemptedAt: undefined,
        };

        existing.attempts += 1;
        if (attempt.accuracy !== undefined) {
          existing.accuracySum += attempt.accuracy;
          existing.accuracyCount += 1;
        }
        const attemptedAt = attempt.createdAt;
        if (attemptedAt !== undefined) {
          existing.lastAttemptedAt =
            existing.lastAttemptedAt === undefined
              ? attemptedAt
              : Math.max(existing.lastAttemptedAt, attemptedAt);
        }

        breakdownMap.set(key, existing);
      }

      for (const entry of breakdownMap.values()) {
        const accuracy =
          entry.accuracyCount > 0
            ? entry.accuracySum / entry.accuracyCount
            : 0;
        topicBreakdown.push({
          topicId: entry.topicId,
          topicName: entry.topicName,
          attempts: entry.attempts,
          accuracy,
          lastAttemptedAt: entry.lastAttemptedAt,
        });
      }
    }

    const user = await ctx.db.get(userId);
    const consistencyScore = user
      ? Math.min(1, user.currentStreak / Math.max(1, user.streakGoal))
      : 0;

    let difficultyProgression = "stable";
    if (allAttempts.length >= 10) {
      const recentAccuracies = allAttempts
        .slice(0, 5)
        .map((a) => a.accuracy ?? 0);
      const olderAccuracies = allAttempts
        .slice(5, 10)
        .map((a) => a.accuracy ?? 0);
      const recentAvg =
        recentAccuracies.reduce((s, a) => s + a, 0) / recentAccuracies.length;
      const olderAvg =
        olderAccuracies.reduce((s, a) => s + a, 0) / olderAccuracies.length;

      if (recentAvg > olderAvg + 0.1) difficultyProgression = "improving";
      else if (recentAvg < olderAvg - 0.1) difficultyProgression = "declining";
    }

    const explorationDiversity = topicStats.length;

    return {
      totalAttempts: allAttempts.length,
      completedChallenges: completedAttempts.length,
      averageAccuracy,
      averageTimeSeconds,
      topicBreakdown,
      learningPatterns: {
        consistencyScore,
        difficultyProgression,
        explorationDiversity,
      },
    };
  },
});
