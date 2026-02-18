import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { requireUser } from "./lib/auth";

const challengeDoc = v.object({
  _id: v.id("challenges"),
  _creationTime: v.number(),
  title: v.optional(v.string()),
  quizName: v.optional(v.string()),
  type: v.optional(v.string()),
  difficulty: v.optional(v.string()),
  question: v.optional(v.string()),
  solution: v.optional(v.string()),
  options: v.optional(
    v.array(v.object({ text: v.string(), isCorrect: v.boolean() }))
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
});


export const getById = query({
  args: { challengeId: v.id("challenges") },
  returns: v.union(v.null(), challengeDoc),
  handler: async (ctx, args) => {
    const doc = await ctx.db.get(args.challengeId);
    return doc ?? null;
  },
});


export const listRecent = query({
  args: { limit: v.optional(v.number()) },
  returns: v.array(challengeDoc),
  handler: async (ctx, args) => {
    const max = args.limit ?? 20;
    return await ctx.db
      .query("challenges")
      .withIndex("by_created_at")
      .order("desc")
      .take(max);
  },
});


export const listMostSolved = query({
  args: { limit: v.optional(v.number()) },
  returns: v.array(challengeDoc),
  handler: async (ctx, args) => {
    const max = args.limit ?? 20;
    return await ctx.db
      .query("challenges")
      .withIndex("by_solve_count")
      .order("desc")
      .take(max);
  },
});


export const listByCategory = query({
  args: {
    categoryId: v.id("categories"),
    difficulty: v.optional(v.string()),
    limit: v.optional(v.number()),
  },
  returns: v.array(challengeDoc),
  handler: async (ctx, args) => {
    const max = args.limit ?? 20;

    if (args.difficulty !== undefined) {
      return await ctx.db
        .query("challenges")
        .withIndex("by_category_id_and_difficulty", (q) =>
          q.eq("categoryId", args.categoryId).eq("difficulty", args.difficulty!)
        )
        .order("desc")
        .take(max);
    }

    return await ctx.db
      .query("challenges")
      .withIndex("by_category_id_and_difficulty", (q) =>
        q.eq("categoryId", args.categoryId)
      )
      .order("desc")
      .take(max);
  },
});


export const listByTopic = query({
  args: {
    topicId: v.id("topics"),
    limit: v.optional(v.number()),
  },
  returns: v.array(challengeDoc),
  handler: async (ctx, args) => {
    const max = args.limit ?? 20;
    return await ctx.db
      .query("challenges")
      .withIndex("by_topic_id_and_created_at", (q) =>
        q.eq("topicId", args.topicId)
      )
      .order("desc")
      .take(max);
  },
});


export const createAdHoc = mutation({
  args: {
    topic: v.string(),
    difficulty: v.optional(v.string()),
    questionCount: v.optional(v.number()),
    quizName: v.optional(v.string()),
  },
  returns: v.id("challenges"),
  handler: async (ctx, args) => {
    const userId = await requireUser(ctx);
    const now = Date.now();

    const topicLower = args.topic.toLowerCase();
    let matchedTopic = await ctx.db
      .query("topics")
      .withIndex("by_name_lower", (q) => q.eq("nameLower", topicLower))
      .unique();

    if (matchedTopic === null) {
      const newTopicId = await ctx.db.insert("topics", {
        name: args.topic,
        nameLower: topicLower,
        difficulty: args.difficulty ?? "Medium",
        estimatedTimeMinutes: 15,
        createdAt: now,
      });
      matchedTopic = await ctx.db.get(newTopicId);
    }

    const challengeId = await ctx.db.insert("challenges", {
      title: args.quizName ?? `${args.topic} Quiz`,
      quizName: args.quizName ?? `${args.topic} Quiz`,
      type: "quiz",
      difficulty: args.difficulty ?? "Medium",
      questionCount: args.questionCount ?? 5,
      solveCount: 0,
      topic: args.topic,
      topicId: matchedTopic!._id,
      createdByUserId: userId,
      createdAt: now,
    });

    return challengeId;
  },
});
