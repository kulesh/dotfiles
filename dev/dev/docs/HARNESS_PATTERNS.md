# Harness Engineering Patterns

This document is a practical pattern catalog for building agent harnesses around LLMs.
It is implementation-focused and biased toward production reliability.

## 0. Scope

This is about harness engineering, not model training:

- Provider abstraction
- Agent loop orchestration
- Tool execution
- Session persistence and branching
- Context management and compaction
- Reliability, retries, and auth
- Extension/plugin systems
- Headless embedding protocols

## 1. Reference Architecture

```text
+----------------------+      +------------------------+
| UI / IDE / CLI / RPC | ---> | Agent Runtime          |
+----------------------+      | - turn state machine   |
                              | - queues/interruptions |
                              | - tool orchestration   |
                              +-----------+------------+
                                          |
                                          v
                              +------------------------+
                              | Provider Adapter Layer |
                              | - normalize messages   |
                              | - map stop reasons     |
                              | - parse streaming      |
                              +-----------+------------+
                                          |
                                          v
                              +------------------------+
                              | LLM Provider APIs      |
                              +------------------------+
```

```text
Session Persistence (append-only DAG)

root -> e1 -> e2 -> e3
              \-> e4 -> e5   (leaf)

Compaction appends summary nodes; traversal from leaf rebuilds context.
```

## 2. Pattern Catalog

### Pattern 1: Canonical Internal Schema

Use one internal `Message` and `Event` contract. All providers and tools adapt to it.

```ts
type Message = UserMessage | AssistantMessage | ToolResultMessage;

type AgentEvent =
  | { type: "turn_start" }
  | { type: "message_update"; message: AssistantMessage }
  | { type: "tool_execution_end"; toolCallId: string; isError: boolean };
```

Why it matters: eliminates cross-provider logic leaks into core loop code.
Repo references: [packages/ai/src/types.ts](packages/ai/src/types.ts), [packages/agent/src/types.ts](packages/agent/src/types.ts).

### Pattern 2: Provider Adapters at the Boundary

Normalize provider quirks before data enters runtime state.

```ts
function normalizeProviderEvent(raw: unknown): AssistantMessageEvent {
  // provider-specific parsing
  // normalize tool IDs, stop reasons, thinking blocks
  return normalized;
}
```

Why it matters: core runtime stays provider-agnostic.
Repo references: [packages/ai/src/providers/transform-messages.ts](packages/ai/src/providers/transform-messages.ts), [packages/ai/src/providers/openai-responses-shared.ts](packages/ai/src/providers/openai-responses-shared.ts), [packages/ai/src/providers/google-shared.ts](packages/ai/src/providers/google-shared.ts).

### Pattern 3: Deterministic Turn State Machine

Per-invocation turn lifecycle (the harness process remains alive after `break`):

```ts
while (true) {
  emit({ type: "turn_start" });
  const assistant = await runModel(context);
  const calls = extractToolCalls(assistant);

  if (calls.length) {
    await executeToolCalls(calls);
    emit({ type: "turn_end" });
    continue;
  }

  const followUps = await getFollowUpMessages();
  emit({ type: "turn_end" });

  if (followUps.length) {
    injectMessages(followUps);
    continue;
  }

  break; // invocation complete; runtime returns to idle
}
```

Why it matters: easier replay, debugging, and testing.
Repo references: [packages/agent/src/agent-loop.ts](packages/agent/src/agent-loop.ts), [packages/agent/src/agent.ts](packages/agent/src/agent.ts).

### Pattern 4: Interruption Queues (Steer vs Follow-up)

Treat interruptions as first-class queue semantics.

```ts
class MessageQueues {
  steering: Message[] = []; // interrupt current path
  followUp: Message[] = []; // run after idle
}
```

Why it matters: cleaner UX for long-running multi-tool turns.
Repo references: [packages/agent/src/agent.ts](packages/agent/src/agent.ts), [packages/agent/src/agent-loop.ts](packages/agent/src/agent-loop.ts).

### Pattern 5: Tool Middleware Chain

Wrap tools with pre/post hooks for policy and auditing.

```ts
async function executeWithHooks(call: ToolCall) {
  const pre = await hooks.toolCall?.(call);
  if (pre?.block) throw new Error(pre.reason ?? "blocked");

  const result = await executeTool(call);
  return (await hooks.toolResult?.({ call, result })) ?? result;
}
```

Why it matters: central policy point without modifying tool implementations.
Repo references: [packages/coding-agent/src/core/extensions/wrapper.ts](packages/coding-agent/src/core/extensions/wrapper.ts), [packages/coding-agent/src/core/extensions/runner.ts](packages/coding-agent/src/core/extensions/runner.ts).

### Pattern 6: Append-Only Session DAG

Persist immutable entries with `id`, `parentId`, and `leaf`.

```ts
type SessionEntry = {
  id: string;
  parentId: string | null;
  type: "message" | "compaction" | "metadata";
  payload: unknown;
};
```

Why it matters: safe branching/forking and deterministic history reconstruction.
Repo references: [packages/coding-agent/src/core/session-manager.ts](packages/coding-agent/src/core/session-manager.ts).

### Pattern 7: Rebuild Context by Traversal

Never mutate old messages in-place. Rebuild from leaf to root path.

```ts
function buildContext(entries: SessionEntry[], leafId: string): Message[] {
  const path = collectPathToRoot(entries, leafId);
  return materializeMessages(path);
}
```

Why it matters: supports branch navigation and replay.
Repo references: [packages/coding-agent/src/core/session-manager.ts](packages/coding-agent/src/core/session-manager.ts) (`buildSessionContext`).

### Pattern 8: Compaction Pipeline (Not Blind Truncation)

`prepare -> summarize -> append summary -> rebuild`.

```ts
const prep = prepareCompaction(pathEntries, settings);
const summary = await summarize(prep.messagesToSummarize);
appendCompaction({ summary, firstKeptEntryId: prep.firstKeptEntryId });
const context = rebuildFromLeaf();
```

Why it matters: predictable context-window control with retained intent.
Repo references: [packages/coding-agent/src/core/compaction/compaction.ts](packages/coding-agent/src/core/compaction/compaction.ts), [packages/coding-agent/src/core/agent-session.ts](packages/coding-agent/src/core/agent-session.ts) (`compact`, auto-compaction hooks).

### Pattern 9: Branch Summaries on Tree Navigation

Summarize the branch you are leaving, attach as a synthetic context node.

```ts
const abandoned = collectAbandonedEntries(oldLeafId, targetLeafId);
if (abandoned.length) {
  const summary = await summarize(abandoned);
  appendBranchSummary(summary);
}
```

Why it matters: avoids context loss when users jump across branches.
Repo references: [packages/coding-agent/src/core/compaction/branch-summarization.ts](packages/coding-agent/src/core/compaction/branch-summarization.ts), [packages/coding-agent/src/core/agent-session.ts](packages/coding-agent/src/core/agent-session.ts) (`navigateTree`).

### Pattern 10: Split Reliability Handling

Overflow and transient errors require different recovery paths.

```ts
if (isContextOverflow(err)) {
  await compactContext();
  await continueTurn();
} else if (isRetryable(err)) {
  await sleep(backoff(attempt));
  return retry();
}
throw err;
```

Why it matters: avoids retry loops that can never succeed.
Repo references: [packages/ai/src/utils/overflow.ts](packages/ai/src/utils/overflow.ts), [packages/coding-agent/src/core/agent-session.ts](packages/coding-agent/src/core/agent-session.ts) (`_checkCompaction`, `_isRetryableError`, `_autoRetry`).

### Pattern 11: Lock-Safe OAuth Refresh

Refresh tokens with inter-process file lock.

```ts
await withFileLock(authPath, async () => {
  const creds = readAuth();
  if (Date.now() < creds.expiresAt) return creds.accessToken;
  const next = await refresh(creds.refreshToken);
  writeAuth(next);
  return next.accessToken;
});
```

Why it matters: prevents race conditions and token corruption.
Repo references: [packages/coding-agent/src/core/auth-storage.ts](packages/coding-agent/src/core/auth-storage.ts).

### Pattern 12: Scoped Resource Layering

Load resources by scope with deterministic precedence.

```ts
type Scope = "project" | "user" | "temporary";
type Resource = { path: string; scope: Scope; source: string; enabled: boolean };

// project overrides user; temporary can inject runtime resources
const merged = mergeByPrecedence(resources);
```

Why it matters: predictable extension/skill/prompt discovery in teams.
Repo references: [packages/coding-agent/src/core/resource-loader.ts](packages/coding-agent/src/core/resource-loader.ts), [packages/coding-agent/src/core/package-manager.ts](packages/coding-agent/src/core/package-manager.ts), [packages/coding-agent/src/core/settings-manager.ts](packages/coding-agent/src/core/settings-manager.ts).

### Pattern 13: Stable Headless RPC Protocol

JSONL commands and event stream for embedding in IDE/web backends.

```json
{"id":"req_1","type":"prompt","message":"fix failing tests"}
{"id":"req_1","type":"response","command":"prompt","success":true}
{"type":"turn_start"}
{"type":"message_update","message":{"role":"assistant","content":[{"type":"text","text":"..."}]}}
{"type":"agent_end","messages":[...]}
```

Why it matters: decouples runtime from presentation layer.
Repo references: [packages/coding-agent/src/modes/rpc/rpc-types.ts](packages/coding-agent/src/modes/rpc/rpc-types.ts), [packages/coding-agent/src/modes/rpc/rpc-mode.ts](packages/coding-agent/src/modes/rpc/rpc-mode.ts), [packages/coding-agent/src/modes/rpc/rpc-client.ts](packages/coding-agent/src/modes/rpc/rpc-client.ts).

### Pattern 14: Hard Output Bounds for Tools

Bound file/shell outputs by bytes and lines, plus continuation hints.

```ts
const out = truncateHead(content, { maxLines: 2000, maxBytes: 50_000 });
return out.truncated
  ? `${out.content}\n[Use offset=${nextOffset} to continue]`
  : out.content;
```

Why it matters: prevents runaway context growth and latency spikes.
Repo references: [packages/coding-agent/src/core/tools/read.ts](packages/coding-agent/src/core/tools/read.ts), [packages/coding-agent/src/core/tools/truncate.ts](packages/coding-agent/src/core/tools/truncate.ts), [packages/coding-agent/src/core/bash-executor.ts](packages/coding-agent/src/core/bash-executor.ts).

### Pattern 15: Runtime Provider Registration

Allow dynamic provider registration from extensions/plugins.

```ts
registry.registerProvider("corp-ai", {
  api: "openai-responses",
  baseUrl: "https://proxy.corp/v1",
  streamSimple: corpStreamSimple,
  models: [
    {
      id: "corp-coder",
      name: "Corp Coder",
      reasoning: true,
      input: ["text"],
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
      contextWindow: 256000,
      maxTokens: 32000
    }
  ]
});
```

Why it matters: supports enterprise proxies and custom model backends.
Repo references: [packages/coding-agent/src/core/model-registry.ts](packages/coding-agent/src/core/model-registry.ts), [packages/ai/src/api-registry.ts](packages/ai/src/api-registry.ts), [packages/coding-agent/src/core/extensions/types.ts](packages/coding-agent/src/core/extensions/types.ts) (`registerProvider` API).

## 3. Minimal Reference Implementation Layout

```text
harness/
  core/
    types.ts               # canonical schema
    event-bus.ts           # typed event dispatch
    agent-loop.ts          # turn state machine
    queues.ts              # steer/follow-up queue logic
    tool-runner.ts         # middleware + execution
    session-store.ts       # append-only DAG + rebuild
    compaction.ts          # prepare/summarize/append
    reliability.ts         # retry vs overflow decisioning
  providers/
    registry.ts            # provider registration
    openai.ts              # adapter
    anthropic.ts           # adapter
    google.ts              # adapter
    normalize.ts           # shared transforms
  extensions/
    runtime.ts             # extension API surface
    hooks.ts               # hook contracts
  transport/
    rpc-types.ts           # command/response/event protocol
    rpc-server.ts          # JSONL stdin/stdout mode
  tools/
    read.ts
    write.ts
    edit.ts
    bash.ts
    truncate.ts
  auth/
    auth-store.ts          # lock-safe token refresh
  tests/
    loop.test.ts
    session-dag.test.ts
    compaction.test.ts
    retry-overflow.test.ts
    rpc.test.ts
```

## 4. Implementation Order (Practical)

1. Build canonical types and event stream.
2. Build provider adapter interface and one provider.
3. Implement deterministic loop and tool runner.
4. Add append-only session store + context rebuild.
5. Add compaction and overflow handling.
6. Add retry handling for transient errors.
7. Add extension hook system.
8. Add headless RPC protocol.
9. Add scoped resource loading and runtime provider registration.

## 5. Quality Gates

Ship only when these pass:

- Same prompt + same mocked provider stream => identical event sequence.
- Session rebuild from persisted entries is deterministic.
- Overflow path compacts and resumes without manual intervention.
- Retry path never retries overflow-class errors.
- Tool output limits are enforced under large outputs.
- OAuth refresh is safe under concurrent process refresh attempts.
- RPC protocol remains backward compatible across versions.

## References
1- https://justin.poehnelt.com/posts/rewrite-your-cli-for-ai-agents/

