import { query, mutation } from "./_generated/server";
import { v } from "convex/values";
import { requireUser } from "./lib/auth";

type DayStats = { total: number; completed: number };

function buildDayStats(
  challenges: Array<{ day: number; completed: boolean }>
): Map<number, DayStats> {
  const stats = new Map<number, DayStats>();
  for (const ch of challenges) {
    const day = ch.day;
    if (typeof day !== "number") continue;
    const current = stats.get(day) ?? { total: 0, completed: 0 };
    current.total += 1;
    if (ch.completed) current.completed += 1;
    stats.set(day, current);
  }
  return stats;
}

function isDayComplete(stats?: DayStats): boolean {
  if (!stats || stats.total <= 0) return false;
  const required = Math.ceil((stats.total * 2) / 3);
  return stats.completed >= required;
}

type ChallengeSeed = {
  topic: string;
  title: string;
  description: string;
  challengeType: string;
};

function buildDefaultDayChallenges(
  topic: string,
  day: number,
  baseTitle?: string,
  baseDescription?: string,
  challengeType = "quiz"
): ChallengeSeed[] {
  const safeTopic = topic || "General";
  return [
    {
      topic: safeTopic,
      title: baseTitle ?? safeTopic,
      description:
        baseDescription ?? `Build your understanding of ${safeTopic}.`,
      challengeType,
    },
  ];
}

function buildChallengesForDay(
  day: number,
  topicFallback: string,
  item: any
): ChallengeSeed[] {
  const topic = item?.topic ?? topicFallback;
  const challengeType =
    (item?.challenge_type ?? item?.type ?? "quiz").toString().toLowerCase();
  const baseTitle = item?.title ?? topic;
  const baseDescription =
    item?.description ?? `Build your understanding of ${topic}.`;

  const rawSubtopics = Array.isArray(item?.subtopics) ? item.subtopics : [];
  const seeds: ChallengeSeed[] = [];

  if (rawSubtopics.length > 0) {
    for (const sub of rawSubtopics) {
      if (typeof sub === "string") {
        const subTopic = sub;
        seeds.push({
          topic: subTopic,
          title: subTopic,
          description: `Explore ${subTopic} through focused questions.`,
          challengeType,
        });
        continue;
      }
      const subTopic = sub?.topic ?? sub?.title ?? topic;
      seeds.push({
        topic: subTopic,
        title: sub?.title ?? subTopic,
        description:
          sub?.description ?? `Explore ${subTopic} through focused questions.`,
        challengeType:
          (sub?.challenge_type ?? challengeType).toString().toLowerCase(),
      });
    }
  } else {
    seeds.push({
      topic,
      title: baseTitle,
      description: baseDescription,
      challengeType,
    });
  }

  const seen = new Set<string>();
  const deduped: ChallengeSeed[] = [];
  for (const seed of seeds) {
    const key = seed.title.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    deduped.push(seed);
  }

  return deduped.slice(0, 8);
}

export const listSelectable = query({
  args: {},
  returns: v.array(
    v.object({
      path: v.object({
        _id: v.id("learningPaths"),
        _creationTime: v.number(),
        name: v.string(),
        title: v.optional(v.string()),
        description: v.optional(v.string()),
        isActive: v.boolean(),
        createdByUserId: v.optional(v.id("users")),
        createdAt: v.number(),
      }),
      topicCount: v.number(),
      totalSteps: v.number(),
    })
  ),
  handler: async (ctx) => {
    const paths = await ctx.db
      .query("learningPaths")
      .withIndex("by_is_active_and_created_at", (q) => q.eq("isActive", true))
      .order("asc")
      .collect();

    const results: Array<{
      path: (typeof paths)[0];
      topicCount: number;
      totalSteps: number;
    }> = [];

    for (const path of paths) {
      const topics = await ctx.db
        .query("learningPathTopics")
        .withIndex("by_path_id_and_step_number", (q) =>
          q.eq("pathId", path._id)
        )
        .collect();

      results.push({
        path,
        topicCount: topics.length,
        totalSteps: topics.length,
      });
    }

    return results;
  },
});


export const getActive = query({
  args: {},
  returns: v.union(
    v.null(),
    v.object({
      userPath: v.object({
        _id: v.id("userLearningPaths"),
        _creationTime: v.number(),
        userId: v.id("users"),
        pathId: v.optional(v.id("learningPaths")),
        currentStep: v.number(),
        startedAt: v.number(),
        completedAt: v.optional(v.number()),
        isComplete: v.boolean(),
        isActive: v.optional(v.boolean()),
        durationDays: v.number(),
        dailyMinutes: v.number(),
        level: v.optional(v.string()),
        isCustom: v.boolean(),
        aiPathJson: v.optional(v.string()),
        createdAt: v.number(),
        updatedAt: v.number(),
      }),
      pathName: v.optional(v.string()),
      pathDescription: v.optional(v.string()),
      progress: v.object({
        completedDays: v.number(),
        totalDays: v.number(),
        percentComplete: v.number(),
      }),
    })
  ),
  handler: async (ctx) => {
    const userId = await requireUser(ctx);

    let activePaths = await ctx.db
      .query("userLearningPaths")
      .withIndex("by_user_id_and_is_active_and_started_at", (q) =>
        q.eq("userId", userId).eq("isActive", true)
      )
      .order("desc")
      .take(1);

    if (activePaths.length === 0) {
      const fallback = await ctx.db
        .query("userLearningPaths")
        .withIndex("by_user_id_and_is_complete_and_started_at", (q) =>
          q.eq("userId", userId).eq("isComplete", false)
        )
        .order("desc")
        .take(10);

      if (fallback.length === 0) return null;
      activePaths = fallback.filter((p) => p.isActive !== false).slice(0, 1);
      if (activePaths.length === 0) return null;
    }
    const userPath = activePaths[0];

    let pathName: string | undefined;
    let pathDescription: string | undefined;
    if (userPath.pathId !== undefined) {
      const path = await ctx.db.get(userPath.pathId);
      if (path !== null) {
        pathName = path.title ?? path.name;
        pathDescription = path.description;
      }
    }

    const allChallenges = await ctx.db
      .query("userPathChallenges")
      .withIndex("by_user_path_id_and_day", (q) =>
        q.eq("userPathId", userPath._id)
      )
      .collect();

    const maxChallengeDay = allChallenges.reduce((max, c) =>
      typeof c.day === "number" ? Math.max(max, c.day) : max, 0
    );
    const totalDays = Math.max(userPath.durationDays ?? 0, maxChallengeDay, 1);
    const dayStats = buildDayStats(allChallenges);
    let completedDays = 0;
    for (let day = 1; day <= totalDays; day++) {
      if (isDayComplete(dayStats.get(day))) {
        completedDays++;
      }
    }
    const percentComplete = Math.min(
      100,
      Math.round((completedDays / totalDays) * 100)
    );

    return {
      userPath,
      pathName,
      pathDescription,
      progress: {
        completedDays,
        totalDays,
        percentComplete,
      },
    };
  },
});


export const listCompleted = query({
  args: { limit: v.optional(v.number()) },
  returns: v.array(
    v.object({
      userPath: v.object({
        _id: v.id("userLearningPaths"),
        _creationTime: v.number(),
        userId: v.id("users"),
        pathId: v.optional(v.id("learningPaths")),
        currentStep: v.number(),
        startedAt: v.number(),
        completedAt: v.optional(v.number()),
        isComplete: v.boolean(),
        isActive: v.optional(v.boolean()),
        durationDays: v.number(),
        dailyMinutes: v.number(),
        level: v.optional(v.string()),
        isCustom: v.boolean(),
        aiPathJson: v.optional(v.string()),
        createdAt: v.number(),
        updatedAt: v.number(),
      }),
      pathName: v.optional(v.string()),
      pathDescription: v.optional(v.string()),
    })
  ),
  handler: async (ctx, args) => {
    const userId = await requireUser(ctx);
    const max = args.limit ?? 20;

    const completedPaths = await ctx.db
      .query("userLearningPaths")
      .withIndex("by_user_id_and_is_complete_and_started_at", (q) =>
        q.eq("userId", userId).eq("isComplete", true)
      )
      .order("desc")
      .take(max);

    const results: Array<{
      userPath: (typeof completedPaths)[0];
      pathName: string | undefined;
      pathDescription: string | undefined;
    }> = [];

    for (const userPath of completedPaths) {
      let pathName: string | undefined;
      let pathDescription: string | undefined;
      if (userPath.pathId !== undefined) {
        const path = await ctx.db.get(userPath.pathId);
        pathName = path?.title ?? path?.name;
        pathDescription = path?.description;
      }
      results.push({ userPath, pathName, pathDescription });
    }

    return results;
  },
});


export const listIncomplete = query({
  args: { limit: v.optional(v.number()) },
  returns: v.array(
    v.object({
      userPath: v.object({
        _id: v.id("userLearningPaths"),
        _creationTime: v.number(),
        userId: v.id("users"),
        pathId: v.optional(v.id("learningPaths")),
        currentStep: v.number(),
        startedAt: v.number(),
        completedAt: v.optional(v.number()),
        isComplete: v.boolean(),
        isActive: v.optional(v.boolean()),
        durationDays: v.number(),
        dailyMinutes: v.number(),
        level: v.optional(v.string()),
        isCustom: v.boolean(),
        aiPathJson: v.optional(v.string()),
        createdAt: v.number(),
        updatedAt: v.number(),
      }),
      pathName: v.optional(v.string()),
      pathDescription: v.optional(v.string()),
      progress: v.object({
        completedDays: v.number(),
        totalDays: v.number(),
        percentComplete: v.number(),
      }),
    })
  ),
  handler: async (ctx, args) => {
    const userId = await requireUser(ctx);
    const max = args.limit ?? 20;

    const incompletePaths = await ctx.db
      .query("userLearningPaths")
      .withIndex("by_user_id_and_is_complete_and_started_at", (q) =>
        q.eq("userId", userId).eq("isComplete", false)
      )
      .order("desc")
      .take(max);

    const results: Array<{
      userPath: (typeof incompletePaths)[0];
      pathName: string | undefined;
      pathDescription: string | undefined;
      progress: { completedDays: number; totalDays: number; percentComplete: number };
    }> = [];

    for (const userPath of incompletePaths) {
      let pathName: string | undefined;
      let pathDescription: string | undefined;
      if (userPath.pathId !== undefined) {
        const path = await ctx.db.get(userPath.pathId);
        pathName = path?.title ?? path?.name;
        pathDescription = path?.description;
      }

      const allChallenges = await ctx.db
        .query("userPathChallenges")
        .withIndex("by_user_path_id_and_day", (q) =>
          q.eq("userPathId", userPath._id)
        )
        .collect();

      const maxChallengeDay = allChallenges.reduce((max, c) =>
        typeof c.day === "number" ? Math.max(max, c.day) : max, 0
      );
      const totalDays = Math.max(
        userPath.durationDays ?? 0,
        maxChallengeDay,
        1
      );
      const dayStats = buildDayStats(allChallenges);
      let completedDays = 0;
      for (let day = 1; day <= totalDays; day++) {
        if (isDayComplete(dayStats.get(day))) {
          completedDays++;
        }
      }
      const percentComplete = Math.min(
        100,
        Math.round((completedDays / totalDays) * 100)
      );

      results.push({
        userPath,
        pathName,
        pathDescription,
        progress: {
          completedDays,
          totalDays,
          percentComplete,
        },
      });
    }

    return results;
  },
});


export const listChallengesForPath = query({
  args: { userPathId: v.id("userLearningPaths") },
  returns: v.array(
    v.object({
      _id: v.id("userPathChallenges"),
      _creationTime: v.number(),
      userPathId: v.id("userLearningPaths"),
      userId: v.id("users"),
      day: v.number(),
      topic: v.string(),
      challengeType: v.string(),
      title: v.string(),
      description: v.string(),
      completed: v.boolean(),
      bestAccuracy: v.optional(v.number()),
      createdAt: v.number(),
      updatedAt: v.number(),
    })
  ),
  handler: async (ctx, args) => {
    const userId = await requireUser(ctx);

    const userPath = await ctx.db.get(args.userPathId);
    if (userPath === null) throw new Error("Learning path not found");
    if (userPath.userId !== userId) throw new Error("Not your learning path");

    return await ctx.db
      .query("userPathChallenges")
      .withIndex("by_user_path_id_and_day", (q) =>
        q.eq("userPathId", args.userPathId)
      )
      .order("asc")
      .collect();
  },
});


export const setActivePath = mutation({
  args: { userPathId: v.id("userLearningPaths") },
  returns: v.null(),
  handler: async (ctx, args) => {
    const userId = await requireUser(ctx);
    const now = Date.now();

    const userPath = await ctx.db.get(args.userPathId);
    if (userPath === null) throw new Error("Learning path not found");
    if (userPath.userId !== userId) throw new Error("Not your learning path");
    if (userPath.isComplete) throw new Error("Path is already completed");

    let activePaths = await ctx.db
      .query("userLearningPaths")
      .withIndex("by_user_id_and_is_active_and_started_at", (q) =>
        q.eq("userId", userId).eq("isActive", true)
      )
      .collect();

    if (activePaths.length === 0) {
      activePaths = await ctx.db
        .query("userLearningPaths")
        .withIndex("by_user_id_and_is_complete_and_started_at", (q) =>
          q.eq("userId", userId).eq("isComplete", false)
        )
        .collect();
    }

    for (const ap of activePaths) {
      await ctx.db.patch(ap._id, {
        isActive: false,
        updatedAt: now,
      });
    }

    await ctx.db.patch(userPath._id, {
      isActive: true,
      updatedAt: now,
    });

    return null;
  },
});


export const selectTemplatePath = mutation({
  args: { pathId: v.id("learningPaths") },
  returns: v.id("userLearningPaths"),
  handler: async (ctx, args) => {
    const userId = await requireUser(ctx);
    const now = Date.now();

    let activePaths = await ctx.db
      .query("userLearningPaths")
      .withIndex("by_user_id_and_is_active_and_started_at", (q) =>
        q.eq("userId", userId).eq("isActive", true)
      )
      .collect();

    if (activePaths.length === 0) {
      activePaths = await ctx.db
        .query("userLearningPaths")
        .withIndex("by_user_id_and_is_complete_and_started_at", (q) =>
          q.eq("userId", userId).eq("isComplete", false)
        )
        .collect();
    }

    for (const ap of activePaths) {
      await ctx.db.patch(ap._id, {
        isActive: false,
        updatedAt: now,
      });
    }

    const path = await ctx.db.get(args.pathId);
    if (path === null) throw new Error("Learning path not found");

    const pathTopics = await ctx.db
      .query("learningPathTopics")
      .withIndex("by_path_id_and_step_number", (q) =>
        q.eq("pathId", args.pathId)
      )
      .order("asc")
      .collect();

    const userPathId = await ctx.db.insert("userLearningPaths", {
      userId,
      pathId: args.pathId,
      currentStep: 1,
      startedAt: now,
      isComplete: false,
      isActive: true,
      durationDays: pathTopics.length,
      dailyMinutes: 15,
      isCustom: false,
      createdAt: now,
      updatedAt: now,
    });

    for (const pt of pathTopics) {
      const topic = await ctx.db.get(pt.topicId);
      const topicName = topic?.name ?? "Unknown Topic";
      const seeds = buildDefaultDayChallenges(
        topicName,
        pt.stepNumber,
        topicName,
        pt.description ?? `Complete a quiz on ${topicName}`,
        "quiz"
      );

      for (const seed of seeds) {
        await ctx.db.insert("userPathChallenges", {
          userPathId,
          userId,
          day: pt.stepNumber,
          topic: seed.topic,
          challengeType: seed.challengeType,
          title: seed.title,
          description: seed.description,
          completed: false,
          createdAt: now,
          updatedAt: now,
        });
      }
    }

    return userPathId;
  },
});


export const selectFreeMode = mutation({
  args: {},
  returns: v.null(),
  handler: async (ctx) => {
    const userId = await requireUser(ctx);
    const now = Date.now();

    const activePaths = await ctx.db
      .query("userLearningPaths")
      .withIndex("by_user_id_and_is_active_and_started_at", (q) =>
        q.eq("userId", userId).eq("isActive", true)
      )
      .collect();

    let pathsToDeactivate = activePaths;
    if (pathsToDeactivate.length === 0) {
      const fallback = await ctx.db
        .query("userLearningPaths")
        .withIndex("by_user_id_and_is_complete_and_started_at", (q) =>
          q.eq("userId", userId).eq("isComplete", false)
        )
        .collect();
      pathsToDeactivate = fallback.filter((p) => p.isActive !== false);
    }

    for (const ap of pathsToDeactivate) {
      await ctx.db.patch(ap._id, {
        isActive: false,
        updatedAt: now,
      });
    }

    return null;
  },
});


export const createCustomPathFromAi = mutation({
  args: {
    topic: v.string(),
    level: v.string(),
    durationDays: v.number(),
    dailyMinutes: v.number(),
    aiPathJson: v.string(),
    pathDescription: v.optional(v.string()),
  },
  returns: v.id("userLearningPaths"),
  handler: async (ctx, args) => {
    const userId = await requireUser(ctx);
    const now = Date.now();

    const activePaths = await ctx.db
      .query("userLearningPaths")
      .withIndex("by_user_id_and_is_active_and_started_at", (q) =>
        q.eq("userId", userId).eq("isActive", true)
      )
      .collect();

    for (const ap of activePaths) {
      await ctx.db.patch(ap._id, {
        isActive: false,
        updatedAt: now,
      });
    }

    let topicDoc = await ctx.db
      .query("topics")
      .withIndex("by_name_lower", (q) =>
        q.eq("nameLower", args.topic.toLowerCase())
      )
      .unique();

    if (topicDoc === null) {
      const topicId = await ctx.db.insert("topics", {
        name: args.topic,
        nameLower: args.topic.toLowerCase(),
        difficulty: "Medium",
        estimatedTimeMinutes: 15,
        createdAt: now,
      });
      topicDoc = await ctx.db.get(topicId);
    }

    const pathId = await ctx.db.insert("learningPaths", {
      name: args.topic,
      title: args.topic,
      description:
        args.pathDescription ??
        `AI-generated ${args.level} path for ${args.topic}`,
      isActive: false,
      createdByUserId: userId,
      createdAt: now,
    });

    const userPathId = await ctx.db.insert("userLearningPaths", {
      userId,
      pathId,
      currentStep: 1,
      startedAt: now,
      isComplete: false,
      isActive: true,
      durationDays: args.durationDays,
      dailyMinutes: args.dailyMinutes,
      level: args.level,
      isCustom: true,
      aiPathJson: args.aiPathJson,
      createdAt: now,
      updatedAt: now,
    });

    try {
      const parsed = JSON.parse(args.aiPathJson);
      const aiPath = Array.isArray(parsed)
        ? parsed
        : Array.isArray(parsed?.path)
          ? parsed.path
          : [];

        if (aiPath.length > 0) {
         for (let i = 0; i < aiPath.length; i++) {
           const item = aiPath[i];
           const seeds = buildChallengesForDay(i + 1, args.topic, item);
           for (const seed of seeds) {
             await ctx.db.insert("userPathChallenges", {
               userPathId,
               userId,
               day: i + 1,
               topic: seed.topic,
               challengeType: seed.challengeType,
               title: seed.title,
               description: seed.description,
               completed: false,
               createdAt: now,
               updatedAt: now,
             });
           }
         }
        } else {
           for (let day = 1; day <= args.durationDays; day++) {
            const seeds = buildDefaultDayChallenges(
              args.topic,
              day,
              args.topic,
              `Complete a ${args.level} quiz on ${args.topic}`,
              "quiz"
            );
           for (const seed of seeds) {
             await ctx.db.insert("userPathChallenges", {
               userPathId,
               userId,
               day,
               topic: seed.topic,
               challengeType: seed.challengeType,
               title: seed.title,
               description: seed.description,
               completed: false,
               createdAt: now,
               updatedAt: now,
             });
           }
         }
       }
      } catch (e) {
        console.error("createCustomPathFromAi parse error:", { error: String(e) });
         for (let day = 1; day <= args.durationDays; day++) {
          const seeds = buildDefaultDayChallenges(
            args.topic,
            day,
            args.topic,
            `Complete a ${args.level} quiz on ${args.topic}`,
            "quiz"
          );
         for (const seed of seeds) {
           await ctx.db.insert("userPathChallenges", {
             userPathId,
             userId,
             day,
             topic: seed.topic,
             challengeType: seed.challengeType,
             title: seed.title,
             description: seed.description,
             completed: false,
             createdAt: now,
             updatedAt: now,
           });
         }
       }
     }

    return userPathId;
  },
});


export const tweakActivePathFromAi = mutation({
  args: {
    durationDays: v.number(),
    dailyMinutes: v.number(),
    aiPathJson: v.string(),
    pathDescription: v.optional(v.string()),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    const userId = await requireUser(ctx);
    const now = Date.now();

    const activePaths = await ctx.db
      .query("userLearningPaths")
      .withIndex("by_user_id_and_is_active_and_started_at", (q) =>
        q.eq("userId", userId).eq("isActive", true)
      )
      .order("desc")
      .take(1);

    if (activePaths.length === 0)
      throw new Error("No active learning path found");
    const userPath = activePaths[0];

    await ctx.db.patch(userPath._id, {
      durationDays: args.durationDays,
      dailyMinutes: args.dailyMinutes,
      aiPathJson: args.aiPathJson,
      updatedAt: now,
    });

    if (args.pathDescription && userPath.pathId !== undefined) {
      await ctx.db.patch(userPath.pathId, {
        description: args.pathDescription,
      });
    }

    const existingChallenges = await ctx.db
      .query("userPathChallenges")
      .withIndex("by_user_path_id_and_completed_and_day", (q) =>
        q.eq("userPathId", userPath._id).eq("completed", false)
      )
      .collect();

    for (const ch of existingChallenges) {
      await ctx.db.delete(ch._id);
    }

    let pathTopic = "General";
    if (userPath.pathId !== undefined) {
      const path = await ctx.db.get(userPath.pathId);
      if (path !== null) {
        pathTopic = path.name;
      }
    }

    try {
      const parsed = JSON.parse(args.aiPathJson);
      const aiPath = Array.isArray(parsed)
        ? parsed
        : Array.isArray(parsed?.path)
          ? parsed.path
          : [];

      if (aiPath.length > 0) {
        for (let i = 0; i < aiPath.length; i++) {
          const item = aiPath[i];
          const seeds = buildChallengesForDay(i + 1, pathTopic, item);
          for (const seed of seeds) {
            await ctx.db.insert("userPathChallenges", {
              userPathId: userPath._id,
              userId,
              day: i + 1,
              topic: seed.topic,
              challengeType: seed.challengeType,
              title: seed.title,
              description: seed.description,
              completed: false,
              createdAt: now,
              updatedAt: now,
            });
          }
        }
      } else {
        for (let day = 1; day <= args.durationDays; day++) {
          const seeds = buildDefaultDayChallenges(
            pathTopic,
            day,
            pathTopic,
            `Complete a quiz on ${pathTopic}`,
            "quiz"
          );
          for (const seed of seeds) {
            await ctx.db.insert("userPathChallenges", {
              userPathId: userPath._id,
              userId,
              day,
              topic: seed.topic,
              challengeType: seed.challengeType,
              title: seed.title,
              description: seed.description,
              completed: false,
              createdAt: now,
              updatedAt: now,
            });
          }
        }
      }
    } catch (e) {
      console.error("tweakActivePathFromAi parse error:", { error: String(e) });
      for (let day = 1; day <= args.durationDays; day++) {
        const seeds = buildDefaultDayChallenges(
          pathTopic,
          day,
          pathTopic,
          `Complete a quiz on ${pathTopic}`,
          "quiz"
        );
        for (const seed of seeds) {
          await ctx.db.insert("userPathChallenges", {
            userPathId: userPath._id,
            userId,
            day,
            topic: seed.topic,
            challengeType: seed.challengeType,
            title: seed.title,
            description: seed.description,
            completed: false,
            createdAt: now,
            updatedAt: now,
          });
        }
      }
    }

    return null;
  },
});


export const checkAndAdvanceStep = mutation({
  args: {},
  returns: v.object({
    advanced: v.boolean(),
    newStep: v.optional(v.number()),
    pathComplete: v.optional(v.boolean()),
  }),
  handler: async (ctx) => {
    const userId = await requireUser(ctx);
    const now = Date.now();

    const activePaths = await ctx.db
      .query("userLearningPaths")
      .withIndex("by_user_id_and_is_active_and_started_at", (q) =>
        q.eq("userId", userId).eq("isActive", true)
      )
      .order("desc")
      .take(1);

    if (activePaths.length === 0) {
      return { advanced: false };
    }

    const userPath = activePaths[0];
    const currentDay = userPath.currentStep;

    const dayChallenges = await ctx.db
      .query("userPathChallenges")
      .withIndex("by_user_path_id_and_day", (q) =>
        q.eq("userPathId", userPath._id).eq("day", currentDay)
      )
      .collect();

    if (dayChallenges.length === 0) {
      return { advanced: false };
    }

    const completedCount = dayChallenges.filter((c) => c.completed).length;
    const requiredCount = Math.ceil((dayChallenges.length * 2) / 3);
    const allDone = completedCount >= requiredCount;

    if (!allDone) {
      return { advanced: false };
    }

    const allChallenges = await ctx.db
      .query("userPathChallenges")
      .withIndex("by_user_path_id_and_day", (q) =>
        q.eq("userPathId", userPath._id)
      )
      .collect();

    const maxChallengeDay = allChallenges.reduce((max, c) =>
      typeof c.day === "number" ? Math.max(max, c.day) : max, 0
    );
    const totalDays = Math.max(userPath.durationDays ?? 0, maxChallengeDay, 1);
    const dayStats = buildDayStats(allChallenges);
    const incompleteDays: number[] = [];
    for (let day = 1; day <= totalDays; day++) {
      if (!isDayComplete(dayStats.get(day))) {
        incompleteDays.push(day);
      }
    }

    if (incompleteDays.length === 0) {
      await ctx.db.patch(userPath._id, {
        isComplete: true,
        isActive: false,
        completedAt: now,
        currentStep: currentDay,
        updatedAt: now,
      });
      return {
        advanced: true,
        newStep: undefined,
        pathComplete: true,
      };
    }

    const nextStep =
      incompleteDays.find((d) => d > currentDay) ?? incompleteDays[0];

    await ctx.db.patch(userPath._id, {
      currentStep: nextStep,
      updatedAt: now,
    });

    return {
      advanced: true,
      newStep: nextStep,
      pathComplete: false,
    };
  },
});


export const markPathChallengeComplete = mutation({
  args: {
    challengeId: v.id("userPathChallenges"),
    accuracy: v.number(),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    const userId = await requireUser(ctx);
    const challenge = await ctx.db.get(args.challengeId);

    if (challenge === null) throw new Error("Path challenge not found");
    if (challenge.userId !== userId) throw new Error("Not your challenge");

    const now = Date.now();
    const normalizedAccuracy = Number.isFinite(args.accuracy)
      ? Math.max(0, Math.min(1, args.accuracy))
      : 0;
    const existingBest =
      challenge.bestAccuracy !== undefined &&
      Number.isFinite(challenge.bestAccuracy)
        ? challenge.bestAccuracy
        : undefined;
    const bestAccuracy =
      existingBest === undefined
        ? normalizedAccuracy
        : Math.max(existingBest, normalizedAccuracy);

    const completed = bestAccuracy >= 0.75;

    await ctx.db.patch(args.challengeId, {
      completed,
      bestAccuracy,
      updatedAt: now,
    });

    return null;
  },
});
