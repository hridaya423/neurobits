import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { requireUser } from "./lib/auth";


export const save = mutation({
  args: {
    topic: v.optional(v.string()),
    quizName: v.optional(v.string()),
    analysis: v.string(),
    accuracy: v.optional(v.number()),
    totalTime: v.optional(v.number()),
  },
  returns: v.id("sessionAnalyses"),
  handler: async (ctx, args) => {
    const userId = await requireUser(ctx);
    const now = Date.now();

    return await ctx.db.insert("sessionAnalyses", {
      userId,
      topic: args.topic,
      quizName: args.quizName,
      analysis: args.analysis,
      accuracy: args.accuracy,
      totalTime: args.totalTime,
      createdAt: now,
    });
  },
});


export const listMine = query({
  args: { limit: v.optional(v.number()) },
  returns: v.array(
    v.object({
      _id: v.id("sessionAnalyses"),
      _creationTime: v.number(),
      userId: v.id("users"),
      topic: v.optional(v.string()),
      quizName: v.optional(v.string()),
      analysis: v.string(),
      accuracy: v.optional(v.number()),
      totalTime: v.optional(v.number()),
      createdAt: v.number(),
    })
  ),
  handler: async (ctx, args) => {
    const userId = await requireUser(ctx);
    const max = args.limit ?? 20;

    return await ctx.db
      .query("sessionAnalyses")
      .withIndex("by_user_id_and_created_at", (q) => q.eq("userId", userId))
      .order("desc")
      .take(max);
  },
});
