import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { requireUser } from "./lib/auth";

const practiceRec = v.object({
  topicName: v.string(),
  accuracy: v.optional(v.number()),
  attempts: v.optional(v.number()),
  lastAttemptedAt: v.optional(v.number()),
  reason: v.optional(v.string()),
  isSuggested: v.optional(v.boolean()),
});

const suggestedTopic = v.object({
  name: v.string(),
  reason: v.optional(v.string()),
  relatedTopics: v.array(v.string()),
});

const recommendationsDoc = v.object({
  _id: v.id("userRecommendations"),
  _creationTime: v.number(),
  userId: v.id("users"),
  practiceRecs: v.array(practiceRec),
  suggestedTopics: v.array(suggestedTopic),
  basedOnLastAttemptAt: v.optional(v.number()),
  basedOnPreferencesUpdatedAt: v.optional(v.number()),
  source: v.optional(v.string()),
  createdAt: v.number(),
  updatedAt: v.number(),
});

export const getCached = query({
  args: {},
  returns: v.union(v.null(), recommendationsDoc),
  handler: async (ctx) => {
    const userId = await requireUser(ctx);
    const cached = await ctx.db
      .query("userRecommendations")
      .withIndex("by_user_id", (q) => q.eq("userId", userId))
      .unique();
    return cached ?? null;
  },
});

export const upsert = mutation({
  args: {
    practiceRecs: v.optional(v.array(practiceRec)),
    suggestedTopics: v.optional(v.array(suggestedTopic)),
    basedOnLastAttemptAt: v.optional(v.number()),
    basedOnPreferencesUpdatedAt: v.optional(v.number()),
    source: v.optional(v.string()),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    const userId = await requireUser(ctx);
    const now = Date.now();

    const existing = await ctx.db
      .query("userRecommendations")
      .withIndex("by_user_id", (q) => q.eq("userId", userId))
      .unique();

    if (existing !== null) {
      const updates: Record<string, unknown> = { updatedAt: now };
      if (args.practiceRecs !== undefined) {
        updates.practiceRecs = args.practiceRecs;
      }
      if (args.suggestedTopics !== undefined) {
        updates.suggestedTopics = args.suggestedTopics;
      }
      if (args.basedOnLastAttemptAt !== undefined) {
        updates.basedOnLastAttemptAt = args.basedOnLastAttemptAt;
      }
      if (args.basedOnPreferencesUpdatedAt !== undefined) {
        updates.basedOnPreferencesUpdatedAt = args.basedOnPreferencesUpdatedAt;
      }
      if (args.source !== undefined) {
        updates.source = args.source;
      }
      await ctx.db.patch(existing._id, updates);
    } else {
      await ctx.db.insert("userRecommendations", {
        userId,
        practiceRecs: args.practiceRecs ?? [],
        suggestedTopics: args.suggestedTopics ?? [],
        basedOnLastAttemptAt: args.basedOnLastAttemptAt,
        basedOnPreferencesUpdatedAt: args.basedOnPreferencesUpdatedAt,
        source: args.source,
        createdAt: now,
        updatedAt: now,
      });
    }

    return null;
  },
});
