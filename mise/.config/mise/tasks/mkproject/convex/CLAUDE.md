# CLAUDE.md

This file provides guidance to Claude Code when working with this Convex + Next.js project.

## First Things First

BEFORE ANYTHING ELSE: run 'bd onboard' and follow the instructions

## Project Overview

This is a full-stack web application using:

- **Frontend**: Next.js 16 (App Router) with React 19
- **Backend**: Convex (reactive database + serverless functions)
- **Auth**: Convex Auth with password authentication
- **Styling**: Tailwind CSS + shadcn/ui components

## Key Commands

```bash
# Development (run in separate terminals)
bunx convex dev          # Start Convex dev server (required first!)
bun run dev              # Start Next.js dev server

# Build & Deploy
bun run build            # Build Next.js for production
bunx convex deploy       # Deploy Convex to production

# Quality
bun run typecheck        # TypeScript type checking
bun run lint             # ESLint
```

## Project Structure

```
<project-name>/
├── app/                      # Next.js App Router
│   ├── layout.tsx            # Root layout with providers
│   ├── page.tsx              # Home page
│   └── globals.css           # Tailwind + CSS variables
├── components/
│   ├── providers.tsx         # Convex client provider
│   ├── sign-in-form.tsx      # Auth form component
│   ├── user-menu.tsx         # User dropdown
│   ├── task-list.tsx         # Example CRUD component
│   └── ui/                   # shadcn/ui components
├── convex/                   # Convex backend
│   ├── _generated/           # Auto-generated (gitignored)
│   ├── schema.ts             # Database schema
│   ├── auth.ts               # Auth configuration
│   ├── auth.config.ts        # Auth providers config
│   ├── http.ts               # HTTP routes
│   ├── users.ts              # User queries
│   └── tasks.ts              # Example queries/mutations
├── lib/
│   └── utils.ts              # cn() helper for Tailwind
└── .env.local                # Environment variables
```

## Convex Development Patterns

### Function Types

**Queries** - Read data, automatically cached and real-time:
```typescript
import { query } from "./_generated/server";
import { v } from "convex/values";

export const list = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("tasks")
      .withIndex("by_user", (q) => q.eq("userId", args.userId))
      .collect();
  },
});
```

**Mutations** - Write data, transactional:
```typescript
import { mutation } from "./_generated/server";
import { v } from "convex/values";

export const create = mutation({
  args: { text: v.string() },
  handler: async (ctx, args) => {
    const userId = await auth.getUserId(ctx);
    if (!userId) throw new Error("Not authenticated");
    return await ctx.db.insert("tasks", {
      text: args.text,
      completed: false,
      userId,
    });
  },
});
```

**Actions** - Call external APIs (not transactional):
```typescript
import { action } from "./_generated/server";
import { v } from "convex/values";

export const sendEmail = action({
  args: { to: v.string(), subject: v.string() },
  handler: async (ctx, args) => {
    // Call external API here
    await fetch("https://api.email.com/send", { ... });
  },
});
```

### Schema Design

```typescript
// convex/schema.ts
import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  tasks: defineTable({
    text: v.string(),
    completed: v.boolean(),
    userId: v.id("users"),
    createdAt: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_user_created", ["userId", "createdAt"]),
});
```

### Client-Side Usage

```typescript
"use client";

import { useQuery, useMutation } from "convex/react";
import { api } from "@/convex/_generated/api";

function TaskList() {
  // Real-time query - automatically updates
  const tasks = useQuery(api.tasks.list);

  // Mutation hook
  const createTask = useMutation(api.tasks.create);

  const handleCreate = async () => {
    await createTask({ text: "New task" });
    // No need to refetch - updates automatically!
  };
}
```

### Authentication Patterns

```typescript
// In Convex functions - get current user
import { auth } from "./auth";

export const myQuery = query({
  handler: async (ctx) => {
    const userId = await auth.getUserId(ctx);
    if (!userId) return null; // Not authenticated
    // ... rest of handler
  },
});
```

```typescript
// In React components
import { Authenticated, Unauthenticated, AuthLoading } from "convex/react";

function App() {
  return (
    <>
      <AuthLoading>Loading...</AuthLoading>
      <Unauthenticated>
        <SignInForm />
      </Unauthenticated>
      <Authenticated>
        <Dashboard />
      </Authenticated>
    </>
  );
}
```

## Common Operations

### Adding a New Table

1. Update `convex/schema.ts`:
```typescript
export default defineSchema({
  // ... existing tables
  posts: defineTable({
    title: v.string(),
    content: v.string(),
    authorId: v.id("users"),
  }).index("by_author", ["authorId"]),
});
```

2. Create `convex/posts.ts` with queries/mutations

3. Run `bunx convex dev` - schema syncs automatically

### Adding shadcn Components

```bash
bunx shadcn@latest add dialog
bunx shadcn@latest add dropdown-menu
bunx shadcn@latest add toast
```

Components are added to `components/ui/`.

### Environment Variables

For Convex functions, set via dashboard or CLI:
```bash
bunx convex env set API_KEY "your-key"
```

Access in actions (not queries/mutations):
```typescript
const apiKey = process.env.API_KEY;
```

## Notes for Claude Code

- Always run `bunx convex dev` before `bun run dev`
- The `convex/_generated/` folder is auto-generated - never edit it
- Queries and mutations must be deterministic (no Math.random, Date.now)
- Use `ctx.db.system.now()` for current timestamp in functions
- File uploads use Convex storage API, not filesystem
- For external API calls, use actions, not queries/mutations
