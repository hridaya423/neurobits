import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { getCurrentUserId } from "./lib/auth";


export const getMe = query({
  args: {},
  returns: v.union(
    v.null(),
    v.object({
      _id: v.id("users"),
      _creationTime: v.number(),
      authSubject: v.string(),
      email: v.string(),
      emailLower: v.string(),
      username: v.optional(v.string()),
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
  ),
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (identity === null) {
      return null;
    }

    const user = await ctx.db
      .query("users")
      .withIndex("by_auth_subject", (q) =>
        q.eq("authSubject", identity.subject)
      )
      .unique();

    return user ?? null;
  },
});


export const ensureCurrent = mutation({
  args: {},
  returns: v.id("users"),
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (identity === null) {
      throw new Error("Unauthenticated: must be logged in to call ensureCurrent");
    }

    const existing = await ctx.db
      .query("users")
      .withIndex("by_auth_subject", (q) =>
        q.eq("authSubject", identity.subject)
      )
      .unique();

    if (existing !== null) {
      return existing._id;
    }

    const email = identity.email ?? "";
    const emailLower = email.toLowerCase();
    if (emailLower.length > 0) {
      const existingByEmail = await ctx.db
        .query("users")
        .withIndex("by_email_lower", (q) => q.eq("emailLower", emailLower))
        .first();

      if (existingByEmail !== null) {
        await ctx.db.patch(existingByEmail._id, {
          authSubject: identity.subject,
          updatedAt: Date.now(),
        });
        return existingByEmail._id;
      }
    }

    const now = Date.now();
    const userId = await ctx.db.insert("users", {
      authSubject: identity.subject,
      email: email,
      emailLower: emailLower,
      username: identity.nickname ?? undefined,

      points: 0,
      xp: 0,
      level: 1,

      streakGoal: 7,
      currentStreak: 0,
      longestStreak: 0,

      adaptiveDifficultyEnabled: true,
      remindersEnabled: false,
      streakNotifications: false,

      onboardingComplete: false,

      createdAt: now,
      updatedAt: now,
    });

    return userId;
  },
});


export const updateProfile = mutation({
  args: {
    username: v.optional(v.string()),
    streakGoal: v.optional(v.number()),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    const userId = await getCurrentUserId(ctx);
    if (userId === null) {
      throw new Error("Unauthenticated");
    }

    const updates: Record<string, unknown> = {
      updatedAt: Date.now(),
    };

    if (args.username !== undefined) {
      updates.username = args.username;
    }
    if (args.streakGoal !== undefined) {
      updates.streakGoal = args.streakGoal;
    }

    await ctx.db.patch(userId, updates);
    return null;
  },
});


export const updateSettings = mutation({
  args: {
    adaptiveDifficultyEnabled: v.optional(v.boolean()),
    remindersEnabled: v.optional(v.boolean()),
    streakNotifications: v.optional(v.boolean()),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    const userId = await getCurrentUserId(ctx);
    if (userId === null) {
      throw new Error("Unauthenticated");
    }

    const updates: Record<string, unknown> = {
      updatedAt: Date.now(),
    };

    if (args.adaptiveDifficultyEnabled !== undefined) {
      updates.adaptiveDifficultyEnabled = args.adaptiveDifficultyEnabled;
    }
    if (args.remindersEnabled !== undefined) {
      updates.remindersEnabled = args.remindersEnabled;
    }
    if (args.streakNotifications !== undefined) {
      updates.streakNotifications = args.streakNotifications;
    }

    await ctx.db.patch(userId, updates);
    return null;
  },
});


export const completeOnboarding = mutation({
  args: {},
  returns: v.null(),
  handler: async (ctx) => {
    const userId = await getCurrentUserId(ctx);
    if (userId === null) {
      throw new Error("Unauthenticated");
    }

    await ctx.db.patch(userId, {
      onboardingComplete: true,
      updatedAt: Date.now(),
    });
    return null;
  },
});
