# Harness and Embodiment: A Conceptual Framework for AI Systems

Drafted on November 2025

I find conceptual frameworks useful for focusing attention, energy, and investment. Layers create boundaries that help me decide what fits where, what to build, and where to invest. These boundaries are never perfect, but frameworks provide a consistent vocabulary for evolving my thinking over time.

We’re building AI systems fast that it’s worth pausing to ask what we’re actually building and how the pieces fit together.

## The Messy Middle

Language models by themselves don’t affect systems, organizations, or outcomes. To be effective, a model must be situated within an environment and its presence must be perceptible to that environment. For example, the model needs to play a specific role in the environment—like a pair programmer to a developer or a paralegal to a lawyer. Most environments are built for humans and are not inherently legible to models. In order to situate the model we need to create affordances that make environments legible for the model. We are defining protocols and building a lot of software to create these affordances. I think we are lumping together things that deserve separate attention. Borrowing from robotics, my mental model for AI systems consists of four conceptual layers:

```
MODEL           (intelligence, reasoning)
  ↓
HARNESS         (capability amplification)
  ↓
EMBODIMENT      (situated existence)
  ↓
ENVIRONMENT     (systems, people, organizations)
```

The middle two layers are where much of today’s software is being built and where many of the most interesting design decisions are happening. I think the distinction is useful because they solve different problems.

## The Core Distinction

The distinction is fundamentally about what each layer is responsible for.

**Harness** amplifies a model's capabilities. It extends what the model can do by giving it tools, structure, and leverage. A harness brings a model's capabilities _out_ to be used.

**Embodiment** situates those capabilities within an environment. It brings an environment's affordances, like context, identity, constraints, and history, _in_ for the model to act on. Affordances are the actionable properties of an environment that a model can perceive and act upon.

If harness is the software layer that amplifies a model’s capabilities, embodiment is the layer that situates the model within a specific environment by providing the model an identity, context, constraints, history, and relationships that shape its behavior over time.

## What Bothers Me

I started thinking about this when I got frustrated with how coding agents are evolving. Something felt off about which features are being built, and I couldn't name it. We keep building features to amplify the model’s capabilities, but we do far less to bring the development environment to the model. Give the model more tools, more context, more structure and developers benefit. That's true. The model still lacks a solid grasp of its environment and doesn’t feel as situated as a real pair-programming partner would.

For example, models are good at creating and maintaining todo lists to stay on task within a session. However, the IDEs/TUIs are not bringing a developer's environment, like project roadmap, progress tracking, developer's role, blockers, etc., to the model. Current thinking over-indexes on extending the harness, rather than recognizing embodiment as a distinct layer and deliberately creating affordances that let the model affect its environment effectively.

## Why the Distinction Matters

There are already so many terms in this field, why introduce another one, especially a conceptual one? I think some of the confusion around agent vs. skills vs. MCP, seem to come from us conflating the _what_ and the _how_. I needed something in the what-space to organize the how-space, and that is useful for forming a mental model of a fast evolving space. Some questions I’ve found useful include: How is this product perceived by its environment? What affordances does the environment already have? What would embodiment for this product actually look like?

One question that’s already proven useful is: What business are you in—model, harness, or embodiment? You can operate across all three, but only if it’s intentional.

A **harness company** is in the infrastructure business. Your value proposition is making models more powerful, more connected, more able to act. You're amplifying capability.

An **embodiment company** is in the identity business. Your value proposition is making models situated, persistent, relational. You're building presence.

I think most businesses will end up being embodiment businesses because that is where the value accrues. However, knowing what you are investing your attention, energy, and resources in will help differentiate the product in a crowded market.

## Is Embodiment More Than Context Engineering?

Context engineering describes the how, but embodiment involves more than context alone. Context is a necessary affordance but I don't think it is sufficient for effective embodiment. Embodiment requires:

- **Context**: what's happening now (e.g., current repo, code blocks being attended to, etc.)
- **Identity**: who the model is in this instantiation (e.g., "staff engineer in Rails", "working on payment system migration for a $10B vol")
- **Constraints**: what it cannot or should not do (e.g., "don't change test payment pivot point", "space-shuttle programming mode")
- **Role**: how it relates to the humans and systems around it (e.g., “pairing buddy for Jane,” “occasionally advises Jane on UX”)

Although the discussion so far has focused on coding agents, the distinction between harness and embodiment is more general and applies equally to enterprise and consumer products. An enterprise copilot's harness lets it query databases, generate reports, draft emails, integrate with Slack and Jira. Its embodiment is understanding org structure, knowing what a person's role allows them to see, carrying strategic context from past interactions, recognizing team norms about what gets a message versus a ticket. A customer support agent's harness lets it look up orders, issue refunds, search the knowledge base. Its embodiment is knowing this customer's history, understanding the brand voice, remembering that this particular customer prefers concise answers, and there are unusally large number of customers still waiting on the line.

## Boundaries: Where Harness Ends and Embodiment Begins

The conceptual boundary between harness and embodiment is about _what_--what each layer is responsible for. Conceptual boundaries will inevitably blur during implementation—just as you wouldn’t derive the OSI model by inspecting the Linux kernel’s network stack.

**Skills and MCPs** are sometimes talked about interchangeably, but I think they fall on different sides of the boundary. Skills amplify what a model can do—new capabilities, new actions, new tools. That's harness. MCPs (Model Context Protocols) bring an environment's affordances to the model, connecting it to the systems, data, and context the model needs to situate itself. That's embodiment.

**Memory** is another example. Short-term memory, holding state within a session and enabling multi-step tasks, is harness. Think of it like cache. Long-term memory, accumulated knowledge, persistent knowledge, learned preferences, is embodiment. It's constitutive, shaping what the model _is_ over time. Think of it like experience.

**Agents** also straddle the boundry. The orchestration machinery, tool selection, retries, planning loops, is harness. But the agent's role, its constraints, its accumulated context about this particular environment? That's embodiment. I think of Agent Communication Protocol as a way of making remote affordances available to local embodiments. (In this conceptual model, tools like Claude Code, Codex, Cursor, OpenCode, and Toad are embodiments; a session is the agent.)
[](TODOD^^)

**Sandboxing** is another example where a model's harness defines what the model can and cannot do within a session whereas an external sandbox (e.g. sandbox-exec) defines what the embodiment can and cannot do in the environment.

The implication: harness is minimally stateful, horizontal, and operates over short time horizon. Embodiment is stateful, vertical, and evolves over long time horizons.

## The Flywheel

If harness is the outbound arc (Model → Environment) and embodiment is the inbound arc (Environment → Model), then what matters isn't either layer in isolation. It's the flywheel. This is similar to Jim Collins' concept of flywheels, where every push reinforces a central outcome. A well-designed AI system has the same property: each action by the model should improve the embodiment (more context, better calibration), which should improve the next action. We don't yet have good ways to measure flywheel effectiveness but I suspect the teams that figure this out will build systems that compound in ways that harness-only systems can't.

## Gaps to Fill

If this framework is useful, it also reveals where the work isn't being done yet. Some gaps I see:

**Environments aren't model-legible.** Models are introduced into environments exclusively designed for humans. When we design harness we take into account what the underlying model "knows" and ensure the harness is "in distribution." I think we need similar discipline to designing affordances for environments--whether these environments are IDEs or large enterprises. MCPs are a good first step but without careful editing/tuning they often flood the available context.

**Embodiment tooling is immature.** We have sophisticated harness infrastructure—agent frameworks, tool libraries, orchestration systems—but far less support for embodiment as a first-class concern. Embodiment is not recognized as a separate layer hence each affordance exist not in cohesion. Long-term memory, organizational context, role management, and constraint systems exist largely independent of one another. There's an opportunity for platforms that make embodiment as easy to build as harness.

**Feedback loops are broken.** Most AI systems are open-loop: the model acts, but the outcome doesn’t update the embodiment. The model doesn't learn that its last suggestion broke the build, or that this user prefers shorter responses, or that this part of the codebase is unusually fragile. Closing these loops is an unsolved problem.

**We lack embodiment metrics.** We can measure harness performance: latency, tool success rates, tokens per task. We don't have good ways to measure embodiment quality. How situated is this model? How well does it understand its environment? How much does the loop compound over time? The teams that develop these metrics will have an advantage.
