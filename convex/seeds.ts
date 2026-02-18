import { internalMutation } from "./_generated/server";
import { v } from "convex/values";


export const seedCategoriesAndBadges = internalMutation({
  args: {},
  returns: v.null(),
  handler: async (ctx) => {
    const now = Date.now();

    const categories = [
      { name: "Programming", description: "Software development and coding" },
      { name: "Mathematics", description: "Math concepts and problem solving" },
      { name: "Science", description: "Scientific knowledge and discovery" },
      { name: "History", description: "Historical events and figures" },
      { name: "Geography", description: "World geography and cultures" },
      { name: "Language", description: "Language learning and linguistics" },
      { name: "Technology", description: "Modern technology and computing" },
      { name: "General Knowledge", description: "Miscellaneous trivia and facts" },
    ];

    for (const cat of categories) {
      const existing = await ctx.db
        .query("categories")
        .withIndex("by_name_lower", (q) =>
          q.eq("nameLower", cat.name.toLowerCase())
        )
        .unique();

      if (existing === null) {
        await ctx.db.insert("categories", {
          name: cat.name,
          nameLower: cat.name.toLowerCase(),
          description: cat.description,
          createdAt: now,
        });
      }
    }

    const badges = [
      {
        badgeKey: "first-challenge",
        name: "First Steps",
        description: "Complete your first challenge",
        icon: "star",
      },
      {
        badgeKey: "challenge-10",
        name: "Getting Serious",
        description: "Complete 10 challenges",
        icon: "trophy",
      },
      {
        badgeKey: "challenge-50",
        name: "Dedicated Learner",
        description: "Complete 50 challenges",
        icon: "medal",
      },
      {
        badgeKey: "challenge-100",
        name: "Century Club",
        description: "Complete 100 challenges",
        icon: "crown",
      },
      {
        badgeKey: "streak-7",
        name: "Week Warrior",
        description: "Maintain a 7-day streak",
        icon: "fire",
      },
      {
        badgeKey: "streak-30",
        name: "Monthly Master",
        description: "Maintain a 30-day streak",
        icon: "flame",
      },
      {
        badgeKey: "perfect-score",
        name: "Perfectionist",
        description: "Achieve 100% accuracy on a challenge",
        icon: "check-circle",
      },
      {
        badgeKey: "speed-demon",
        name: "Speed Demon",
        description: "Complete a challenge in under 30 seconds",
        icon: "zap",
      },
      {
        badgeKey: "explorer",
        name: "Explorer",
        description: "Attempt challenges in 5 different topics",
        icon: "compass",
      },
      {
        badgeKey: "path-complete",
        name: "Path Finder",
        description: "Complete a learning path",
        icon: "map",
      },
    ];

    for (const badge of badges) {
      const existing = await ctx.db
        .query("badges")
        .withIndex("by_badge_key", (q) => q.eq("badgeKey", badge.badgeKey))
        .unique();

      if (existing === null) {
        await ctx.db.insert("badges", {
          badgeKey: badge.badgeKey,
          name: badge.name,
          description: badge.description,
          icon: badge.icon,
          createdAt: now,
        });
      }
    }

    return null;
  },
});
