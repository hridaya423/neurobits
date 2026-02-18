import { query } from "./_generated/server";
import { Doc } from "./_generated/dataModel";
import { v } from "convex/values";
import { requireUser } from "./lib/auth";

export const listAll = query({
  args: {},
  returns: v.array(
    v.object({
      _id: v.id("badges"),
      _creationTime: v.number(),
      badgeKey: v.string(),
      name: v.string(),
      description: v.optional(v.string()),
      icon: v.optional(v.string()),
      createdAt: v.number(),
    })
  ),
  handler: async (ctx) => {
    return await ctx.db.query("badges").collect();
  },
});


export const listMine = query({
  args: {},
  returns: v.array(
    v.object({
      badge: v.object({
        _id: v.id("badges"),
        _creationTime: v.number(),
        badgeKey: v.string(),
        name: v.string(),
        description: v.optional(v.string()),
        icon: v.optional(v.string()),
        createdAt: v.number(),
      }),
      awardedAt: v.number(),
    })
  ),
  handler: async (ctx) => {
    const userId = await requireUser(ctx);

    const userBadges = await ctx.db
      .query("userBadges")
      .withIndex("by_user_id_and_awarded_at", (q) => q.eq("userId", userId))
      .order("desc")
      .collect();

    const results: Array<{
      badge: Doc<"badges">;
      awardedAt: number;
    }> = [];

    for (const ub of userBadges) {
      const badge = await ctx.db.get(ub.badgeId);
      if (badge !== null) {
        results.push({ badge, awardedAt: ub.awardedAt });
      }
    }

    return results;
  },
});
