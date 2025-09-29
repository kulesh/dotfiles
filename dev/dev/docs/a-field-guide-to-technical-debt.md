# A Field Guide to Technical Debt

All good businesses accrue debt and manage it to their advantage. Similarly, a sound technology strategy must accrue technical debt deliberately and manage it appropriately. Here is my framework for managing technical debt. This is written for both technical and non-technical folk.

## Overview
Taking the metaphor at face value, there are two components to debt: the **type** of debt and the **interest rate**. There are good types of debt at good interest rate (e.g. mortgage at 2%) and there are bad types of debt (e.g. credit card debt at variable APR 26%). A good fiscal discipline handles these debts differently. Similarly we need to dig deeper to identify different types of technical debt and handle them differently.

Programming is how an individual solves a problem based on how they understand it, using code. Software engineering begins when that solution must survive teams, time, and trade-offs (and AI Assistants). [See Titus Winters 2017](https://www.youtube.com/watch?v=tISy7EJQPzI&t=472s). Software engineering is a team sport and the following is a strategy for managing technical debt.

## Types of Technical Debt
Most technical debt fall into one of the following types. Each type ought to be handled at the right phase of software engineering, by the right team, and owned by the right organizational leader.

### 1. Abstraction Debt

- **What:** Software embodies a model and mechanization of a solution to a problem. Abstractions (e.g., modules, classes, functions) form the language necessary to precisely describe the solution. As problems evolve and solutions follow suit, abstractions become leaky. Classes and modules become overloaded, and boundaries of responsibility blur. This is abstraction debt.

    A codebase that has accrued abstraction debt is difficult to comprehend. It becomes difficult for the software engineers to form an accurate mental model of the software which in turns makes changes hard and fragile.
- **When:** Abstraction debt can and should be handled during the regular development cycle (e.g. sprint). Code reviews should look for overload classes or leaky abstraction. Always be refactoring as part of the regular development cycle.
- **Sponsor:** Technical Lead / Engineering Manager (EM)

### 2. Data Model Debt

- **What:** The atrophy of abstraction often leaks into the data model, creating data model debt. A model (and a relational table) may collect extraneous attributes or develop overly complex foreign key relationships. Sometimes, entire concepts (e.g., subscriptions) are only implemented in code and not reflected in the data model. Unlike abstraction debt, the impact of data model debt can be felt outside of software and product; poor data models can impact reporting and finance.
- **When:** Minor issues can often be addressed alongside abstraction debt. Larger conceptual changes, such as introducing subscriptions, require dedicated effort due to many dependencies (e.g., reporting). Acknowledge and treat conceptual refactoring as its own stream. Bring up and discuss this type of work during regular product planning sessions --quarterly planning or 6-week planning.
- **Sponsor:** Domain Owner (e.g., Director)

### 3. System Debt

- **What:** If software is the muscle of a working product, then the underlying frameworks and system architecture are the skeleton and tendons. When these foundations don't keep up with the evolution of product strategy, business needs, or technology, the software must carry extra load to keep the product working. This results in unnecessary complexity and fragility—this is system debt.
- **When:** Addressing system debt is often a cross-disciplinary engineering effort. Form a cross-functional team of infrastructure, security, and product engineers to tackle specific system debt as a dedicated workstream. This work gets discussed and committed to during regular product planning cadence.
- **Sponsor:** Domain Owner

### 4. Dependency Debt

- **What:** Modern software products rely on hundreds of open-source libraries, frameworks, and APIs, which evolve independently. Dependency debt arises when dependencies are not kept up to date.
- **When:** Minor version upgrades should be continuous and automated (e.g., Dependabot, Renovate). More risky major version upgrades can be treated as system debt. Note that continuous and automated upgrades need a robust observability and a continuous deployment pipeline.
- **Avoid:** Do not fork a dependency to address debt. Contribute changes upstream and pull them down.
- **Sponsor:** Domain Owner

### 5. Product Debt

- **What:** Products represent a point-in-time solution to our understanding of a customer problem. Problems evolve, our understanding of problems evolve, and customer needs evolve. Product debt accumulates when the product is incrementally adjusted for years without reevaluating the problem from first principles. Ask: *“Knowing what we know today, how would we solve this from scratch?”* This is worth discussing with the team at least annually or biennially.
- **When:** During annual/biennial planning.
- **Sponsor:** Executive

### 6. Experimentation Debt

- **What:** Very few products are built purely on high conviction and intuition. Most are the result of countless experiments, stacked on top of one another. Orphan experiments--where no winner is declared or ownership is lost--and poor post-experiment cleanup create extraneous control flows, leaky abstractions, and unreliable metrics. This is experimentation debt. A healthy experimentation practice establishes clear criteria for what merits experimentation, sets firm deadlines for declaring a winner or loser (despite "stat sig"), and enforces strong discipline around cleanup once the experiment concludes.

- **When:** Establish a practice for reviewing experiments regularly (monthly, bi-weekly). During this review audit for long-running experiments (end them), audit for orphan experiments, and discuss new experiments. Most experimentation tools provide these features out of the box.
- **Sponsor:** Domain Owner

### 7. Organizational Debt

- **What:** Software engineering is a team sport that involves the whole organization. The organization’s way of working and the value it places on product quality are major contributors to technical debt. Clear, consistent way of working and a strong focus on quality help slow the accrual of technical debt.
  - Treat the organization as a programmable entity, and build an internal product to codify its ways of working. Build a product to build products. This product deserves the same intent and craftsmanship as customer-facing products.
  - Recruit, *retrain*, retain: It is important to retrain new team members to your organization's way of working. This will help produce software consistent with the rest of the team.
  - Open source model: No matter how you design your domains and organization follow an open source model (internally) for contributions and collaborations. New eyes tend to spot abstraction debts better than trained eyes.
- **When:** Especially during the organization’s growth phase.
- **Avoid:** Don’t outsource this to a third party or purchase an off-the-shelf solution. Build the product that builds products.
- **Sponsor:** Founder(s) / CEO

### 8. Ergonomic Debt

- **What:** The speed at which a new engineer can fix a bug and deploy the fix to production is the single best measure of engineering ergonomics. Many other types of debt impact ergonomics, but so do clarity of context, quality of tools, length of feedback cycles, testing infrastructure, and even hardware (e.g. developer laptops, test devices).
- **When:** Set the bar for developer ergonomics at a new engineer pair programming with a team member and releasing the change to production. Deployment on day one (sounds better than release on day one but it should be release). Developer ergonomics requires deliberate investment may warrant a dedicated team that owns end-to-end product development ergonomics.
- **Avoid:** Don’t let "day one deployment" become a gimmick. Instead, pair program to *fix a real bug*, test it, deploy it to production, and then send a welcome email with a link to the MR.
- **Sponsor:** CTO

### 9. Emotional Debt

- **What:** "*Progress happens gradually for people to notice and setbacks happen suddenly for people to miss.*" As progress is made, expectations rise. The realization that despite our best effort there is still technical debt is the emotional debt. It’s important to evaluate technical debt historically, not just retrospectively: where we were, what we expected, and where we are now. Celebrate wins. Acknowledge setbacks. Remind the team there is a strategy and review the strategy.
- **When:** Through regular surveys and at least quarterly technical debt readouts at all-hands meetings.
- **Sponsor:** CTO
---

## Interest Rate

The fundamental business advantage of software is the low marginal cost of distributing change. Therefore, the **interest rate** on technical debt is anything that slows down or complicates the ability to make those changes.

Software that rarely changes may carry a low interest rate. However, change frequency isn’t the only factor. Software that doesn’t change often but is mission-critical must be maintained carefully to avoid accumulating system or dependency debt.

> **Prioritize debt repayment based on change frequency:**  
> The higher the frequency of change, the higher the repayment priority.
