import { QueryCtx, MutationCtx } from "../_generated/server";
import { Id } from "../_generated/dataModel";


export async function getCurrentUserId(
  ctx: QueryCtx | MutationCtx
): Promise<Id<"users"> | null> {
  const identity = await ctx.auth.getUserIdentity();
  if (identity === null) {
    return null;
  }

  const user = await ctx.db
    .query("users")
    .withIndex("by_auth_subject", (q) => q.eq("authSubject", identity.subject))
    .unique();

  return user?._id ?? null;
}


export async function requireUser(
  ctx: QueryCtx | MutationCtx
): Promise<Id<"users">> {
  const userId = await getCurrentUserId(ctx);
  if (userId === null) {
    throw new Error("Unauthenticated: no user found");
  }
  return userId;
}


export function assertOwnership(
  userId: Id<"users">,
  resourceOwnerId: Id<"users">
): void {
  if (userId !== resourceOwnerId) {
    throw new Error("Forbidden: you do not own this resource");
  }
}
