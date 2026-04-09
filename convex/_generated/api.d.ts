/* eslint-disable */
/**
 * Generated `api` utility.
 *
 * THIS CODE IS AUTOMATICALLY GENERATED.
 *
 * To regenerate, run `npx convex dev`.
 * @module
 */

import type * as analytics from "../analytics.js";
import type * as badges from "../badges.js";
import type * as challenges from "../challenges.js";
import type * as exams from "../exams.js";
import type * as lib_auth from "../lib/auth.js";
import type * as lib_gcseCore from "../lib/gcseCore.js";
import type * as paths from "../paths.js";
import type * as preferences from "../preferences.js";
import type * as progress from "../progress.js";
import type * as recommendations from "../recommendations.js";
import type * as seeds from "../seeds.js";
import type * as sessionAnalysis from "../sessionAnalysis.js";
import type * as topics from "../topics.js";
import type * as users from "../users.js";

import type {
  ApiFromModules,
  FilterApi,
  FunctionReference,
} from "convex/server";

declare const fullApi: ApiFromModules<{
  analytics: typeof analytics;
  badges: typeof badges;
  challenges: typeof challenges;
  exams: typeof exams;
  "lib/auth": typeof lib_auth;
  "lib/gcseCore": typeof lib_gcseCore;
  paths: typeof paths;
  preferences: typeof preferences;
  progress: typeof progress;
  recommendations: typeof recommendations;
  seeds: typeof seeds;
  sessionAnalysis: typeof sessionAnalysis;
  topics: typeof topics;
  users: typeof users;
}>;

/**
 * A utility for referencing Convex functions in your app's public API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = api.myModule.myFunction;
 * ```
 */
export declare const api: FilterApi<
  typeof fullApi,
  FunctionReference<any, "public">
>;

/**
 * A utility for referencing Convex functions in your app's internal API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = internal.myModule.myFunction;
 * ```
 */
export declare const internal: FilterApi<
  typeof fullApi,
  FunctionReference<any, "internal">
>;

export declare const components: {};
