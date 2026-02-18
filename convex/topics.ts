import { query } from "./_generated/server";
import { v } from "convex/values";
import { requireUser } from "./lib/auth";


export const listAll = query({
  args: {},
  returns: v.array(
    v.object({
      _id: v.id("topics"),
      _creationTime: v.number(),
      name: v.string(),
      nameLower: v.string(),
      difficulty: v.string(),
      description: v.optional(v.string()),
      estimatedTimeMinutes: v.number(),
      category: v.optional(v.string()),
      createdAt: v.number(),
    })
  ),
  handler: async (ctx) => {
    return await ctx.db
      .query("topics")
      .withIndex("by_created_at")
      .order("asc")
      .collect();
  },
});

export const searchRelated = query({
  args: {
    topic: v.string(),
    limit: v.optional(v.number()),
  },
  returns: v.array(
    v.object({
      _id: v.id("topics"),
      _creationTime: v.number(),
      name: v.string(),
      nameLower: v.string(),
      difficulty: v.string(),
      description: v.optional(v.string()),
      estimatedTimeMinutes: v.number(),
      category: v.optional(v.string()),
      createdAt: v.number(),
    })
  ),
  handler: async (ctx, args) => {
    const maxResults = args.limit ?? 10;
    const searchLower = args.topic.toLowerCase();

    const allTopics = await ctx.db
      .query("topics")
      .withIndex("by_name_lower")
      .order("asc")
      .collect();

    const matching = allTopics.filter((t) =>
      t.nameLower.includes(searchLower)
    );

    return matching.slice(0, maxResults);
  },
});


export const getTrending = query({
  args: {
    limit: v.optional(v.number()),
  },
  returns: v.array(
    v.object({
      topicId: v.id("topics"),
      name: v.string(),
      attempts: v.number(),
      avgAccuracy: v.number(),
      category: v.optional(v.string()),
      description: v.optional(v.string()),
    })
  ),
  handler: async (ctx, args) => {
    const maxResults = args.limit ?? 10;

    const aggregates = await ctx.db
      .query("topicAggregates")
      .withIndex("by_attempts_and_updated_at")
      .order("desc")
      .take(maxResults * 2);

    const results: Array<{
      topicId: typeof aggregates[0]["topicId"];
      name: string;
      attempts: number;
      avgAccuracy: number;
      category: string | undefined;
      description: string | undefined;
    }> = [];

    for (const agg of aggregates) {
      if (results.length >= maxResults) break;

      const topic = await ctx.db.get(agg.topicId);
      if (topic === null) continue;

      results.push({
        topicId: agg.topicId,
        name: topic.name,
        attempts: agg.attempts,
        avgAccuracy: agg.avgAccuracy,
        category: topic.category,
        description: topic.description,
      });
    }

    return results;
  },
});


export const getAdaptiveDifficultyForTopic = query({
  args: {
    topicId: v.id("topics"),
  },
  returns: v.object({
    difficulty: v.string(),
    reason: v.optional(v.string()),
  }),
  handler: async (ctx, args) => {
    const userId = await requireUser(ctx);

    const stats = await ctx.db
      .query("userTopicStats")
      .withIndex("by_user_id_and_topic_id", (q) =>
        q.eq("userId", userId).eq("topicId", args.topicId)
      )
      .unique();

    if (stats === null || stats.attempts < 3) {
      return {
        difficulty: "Medium",
        reason: "Not enough data to determine difficulty — starting at Medium",
      };
    }

    if (stats.avgAccuracy >= 0.85) {
      return {
        difficulty: "Hard",
        reason: `High accuracy (${Math.round(stats.avgAccuracy * 100)}%) — moving to Hard`,
      };
    }

    if (stats.avgAccuracy >= 0.6) {
      return {
        difficulty: "Medium",
        reason: `Moderate accuracy (${Math.round(stats.avgAccuracy * 100)}%) — staying at Medium`,
      };
    }

    return {
      difficulty: "Easy",
      reason: `Low accuracy (${Math.round(stats.avgAccuracy * 100)}%) — dropping to Easy`,
    };
  },
});
