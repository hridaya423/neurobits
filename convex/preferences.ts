import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { requireUser } from "./lib/auth";


export const getMine = query({
  args: {},
  returns: v.union(
    v.null(),
    v.object({
      _id: v.id("userQuizPreferences"),
      _creationTime: v.number(),
      userId: v.id("users"),
      defaultNumQuestions: v.number(),
      defaultDifficulty: v.string(),
      defaultTimePerQuestionSec: v.number(),
      timedModeEnabled: v.boolean(),
      quickStartEnabled: v.optional(v.boolean()),
      allowedChallengeTypes: v.array(v.string()),
      learningGoal: v.optional(v.string()),
      experienceLevel: v.optional(v.string()),
      learningStyle: v.optional(v.string()),
      timeCommitmentMinutes: v.optional(v.number()),
      interestedTopics: v.array(v.string()),
      preferredQuestionTypes: v.array(v.string()),
      updatedAt: v.number(),
    })
  ),
  handler: async (ctx) => {
    const userId = await requireUser(ctx);

    const prefs = await ctx.db
      .query("userQuizPreferences")
      .withIndex("by_user_id", (q) => q.eq("userId", userId))
      .unique();

    return prefs ?? null;
  },
});


export const upsertMine = mutation({
  args: {
    defaultNumQuestions: v.optional(v.number()),
    defaultDifficulty: v.optional(v.string()),
    defaultTimePerQuestionSec: v.optional(v.number()),
    timedModeEnabled: v.optional(v.boolean()),
    quickStartEnabled: v.optional(v.boolean()),
    allowedChallengeTypes: v.optional(v.array(v.string())),
    learningGoal: v.optional(v.string()),
    experienceLevel: v.optional(v.string()),
    learningStyle: v.optional(v.string()),
    timeCommitmentMinutes: v.optional(v.number()),
    interestedTopics: v.optional(v.array(v.string())),
    preferredQuestionTypes: v.optional(v.array(v.string())),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    const userId = await requireUser(ctx);
    const now = Date.now();

    const existing = await ctx.db
      .query("userQuizPreferences")
      .withIndex("by_user_id", (q) => q.eq("userId", userId))
      .unique();

    if (existing !== null) {
      const updates: Record<string, unknown> = { updatedAt: now };
      if (args.defaultNumQuestions !== undefined)
        updates.defaultNumQuestions = args.defaultNumQuestions;
      if (args.defaultDifficulty !== undefined)
        updates.defaultDifficulty = args.defaultDifficulty;
      if (args.defaultTimePerQuestionSec !== undefined)
        updates.defaultTimePerQuestionSec = args.defaultTimePerQuestionSec;
      if (args.timedModeEnabled !== undefined)
        updates.timedModeEnabled = args.timedModeEnabled;
      if (args.quickStartEnabled !== undefined)
        updates.quickStartEnabled = args.quickStartEnabled;
      if (args.allowedChallengeTypes !== undefined)
        updates.allowedChallengeTypes = args.allowedChallengeTypes;
      if (args.learningGoal !== undefined)
        updates.learningGoal = args.learningGoal;
      if (args.experienceLevel !== undefined)
        updates.experienceLevel = args.experienceLevel;
      if (args.learningStyle !== undefined)
        updates.learningStyle = args.learningStyle;
      if (args.timeCommitmentMinutes !== undefined)
        updates.timeCommitmentMinutes = args.timeCommitmentMinutes;
      if (args.interestedTopics !== undefined)
        updates.interestedTopics = args.interestedTopics;
      if (args.preferredQuestionTypes !== undefined)
        updates.preferredQuestionTypes = args.preferredQuestionTypes;

      await ctx.db.patch(existing._id, updates);
    } else {
      await ctx.db.insert("userQuizPreferences", {
        userId,
        defaultNumQuestions: args.defaultNumQuestions ?? 5,
        defaultDifficulty: args.defaultDifficulty ?? "Medium",
        defaultTimePerQuestionSec: args.defaultTimePerQuestionSec ?? 60,
        timedModeEnabled: args.timedModeEnabled ?? false,
        quickStartEnabled: args.quickStartEnabled ?? true,
        allowedChallengeTypes: args.allowedChallengeTypes ?? ["quiz"],
        learningGoal: args.learningGoal,
        experienceLevel: args.experienceLevel,
        learningStyle: args.learningStyle,
        timeCommitmentMinutes: args.timeCommitmentMinutes,
        interestedTopics: args.interestedTopics ?? [],
        preferredQuestionTypes: args.preferredQuestionTypes ?? [],
        updatedAt: now,
      });
    }

    return null;
  },
});
