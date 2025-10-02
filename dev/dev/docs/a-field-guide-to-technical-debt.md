# A Field Guide to Technical Debt

All good businesses accrue debt and manage it to their advantage. Similarly, a sound technology strategy must accrue technical debt deliberately and manage it appropriately. Here is my framework for managing technical debt. This is written for both technical and non-technical folk.

## Overview
Taking the metaphor at face value, there are two components to debt: the **type** of debt and the **interest rate**. There are good types of debt at good interest rate (e.g. mortgage at 2%) and there are bad types of debt (e.g. credit card debt at variable APR 26%). A good fiscal discipline handles these debts differently. Similarly, we need to identify different types of technical debt and handle them appropriately.

Programming is how an individual solves a problem based on how they understand it, using code. Software engineering begins when that solution must survive teams, time, and trade-offs (and AI Assistants). [See Titus Winters 2017](https://www.youtube.com/watch?v=tISy7EJQPzI&t=472s). Software engineering, therefore, is a team sport and the following is a strategy for managing technical debt as a team.

## Types of Technical Debt
Most technical debt fall into one of the following types. Each type ought to be handled at the right phase of software engineering, by the right team, and owned by the right person.

### 1. Abstraction Debt

- **What:** Software embodies a model and mechanization of a solution to a problem. Abstractions (e.g., modules, classes, functions) form the language necessary to precisely describe the solution. As problems evolve and solutions follow suit, abstractions become leaky. Classes and modules become overloaded, and boundaries of responsibility blur. This is abstraction debt.

    Accumulation of abstraction debt makes a code base difficult to comprehend which in turn makes forming an accurate mental mode of the software difficult for software engineers (and AI assistants alike). An accurate mental of the software is important for making just the right change to evolve the software. Abstraction debt makes changing software difficult and time consuming.
- **When:** Abstraction debt can and should be handled during the regular development cycle (e.g. sprint). Code reviews should look for overloaded classes and leaky abstractions. A good rule of thumb for spotting abstraction debt is to review the code above and below the layer of abstraction under review (e.g. caller and callee of functions). Refactoring as part of the regular development cycle can delay accumulation of abstraction debt.
- **Sponsor:** Technical Lead / Engineering Manager (EM) should take ownership
  of abstraction debt and have the agency to address it.

### 2. Data Model Debt

- **What:** The atrophy of abstraction often leaks into the data model, creating data model debt. A model (and a relational table) may collect extraneous attributes or develop overly complex foreign key relationships. Sometimes, entire concepts (e.g., subscriptions) are only implemented in code and not reflected in the data model. Unlike abstraction debt, the impact of data model debt can be felt outside of software and product; poor data models can impact reporting and finance.
- **When:** Minor issues can often be addressed alongside abstraction debt. Larger conceptual changes, such as introducing subscriptions, require dedicated effort due to the many dependencies (e.g., reporting) outside of the software. Acknowledge and treat conceptual refactoring as its own stream of work. Bring up and discuss this type of work during regular product planning sessions --quarterly planning or 6-week planning.
- **Sponsor:** Domain Owner (e.g., Director) Group EMs or Directors should bring
  these types of debt to product planning sessions and discuss with the broader
  teams for prioritization.

### 3. System Debt

- **What:** If software is the muscle of a working product, then the underlying infrastructure and system architecture are the skeleton and tendons. When these foundations don't keep up with the evolution of product strategy, business needs, or technology evolution, the application layer must carry extra load to keep the product working. For example, when a platform lacks support for out-of-band async jobs the application layer may decide to take on the responsibility by spawning threads and managing async jobs. This type of mismatch in responsibilities and the mismatch of the system architecture to the product needs form system debt. System debt often results in unnecessarily complex application logic and unreliable product.
- **When:** Addressing system debt is often a cross-disciplinary engineering effort. Form a cross-functional team of infrastructure, security, and product engineers to tackle specific system debt as a dedicated workstream. This work gets discussed and committed to in regular product planning cadence. In large organizations bringing awareness of product evolution early to cross-functional teams (e.g. platform and infrastructure teams) can delay accrual of system debt because those teams can lay the rails ahead of time.
- **Sponsor:** Domain Owner (e.g. Director/VP). Essentially an organizational
  leader who either can foresee the product direction or is aware of production
  direction should own and bring in the teams to address system debt.

### 4. Dependency Debt

- **What:** Modern software products rely on hundreds of open source libraries, frameworks, APIs, and (increasingly) AI models which evolve completely independently. Dependency debt arises when dependencies and dependent software are not kept up to date. Dependency debt can result in security, performance, and reliability issues.
- **When:** As long as the organization has a mature CI/CD pipeline and practice most minor version upgrades can be continuous and automated. Use tools like Dependabot and Renovate to automate at least minor version bumps. More risky major version upgrades can be treated as system debt. Note that continuous and automated upgrades need a robust observability and a continuous deployment pipeline.
- **Avoid:** Do not fork a dependency to address debt. Contribute changes upstream and pull them down.
- **Sponsor:** Domain Owner

### 5. Product Debt

- **What:** Products represent a point-in-time solution to our understanding of a customer problem. Problems evolve, our understanding of problems evolve, and customer needs evolve. Product debt accumulates when a product is incrementally adjusted for years without reevaluating the problem from first principles. Ask: *“Knowing what we know today, how would we solve this problem today?”* This question is worth asking and discussing at various granularities from features to whole products at least annually or biennially. Addressing product debt increases a product's "impute" and simplifies the application logic.
- **When:** During annual planning for large products and quarterly for
  features/small products.
- **Sponsor:** Domain owners for features and executive or someone who has the span and the budget to make wider product changes.

### 6. Experimentation Debt

- **What:** As the effort necessary for setting up an experiment has dropped, so has the bar for what should be an experiment. Very few products are built purely on high conviction and intuition. Most products are the result of countless experiments, stacked on top of one another. Orphan experiments--where no winner is declared or ownership is lost--and poor post-experiment cleanups create extraneous control flows, leaky abstractions, and unreliable metrics. This is experimentation debt. A healthy experimentation practice establishes clear criteria for what merits experimentation, sets firm deadlines for declaring a winner or loser (despite "stat sig"), and enforces strong discipline around cleanup once an experiment concludes.

- **When:** Establish a bar for what should be experimented and a practice for reviewing experiments regularly (monthly, bi-weekly). During this review audit for long-running experiments, audit for orphan experiments, discuss new experiments, and kill new experiments that don't meet the bar. Most experimentation tools provide features to audit health of experiments out of the box.
- **Sponsor:** Domain Owner

### 7. Organizational Debt

- **What:** Software engineering is a team sport that involves the whole organization. An organization’s way of working can decide rate of technical debt accrual. The way of working is: how decisions are made, shared context of organizational priorities, organizational values, etc. A clear and consistent way of working with short feedback cycles and a strong focus on quality can slow the accrual of technical debt.
  - Single biggest frustration of organizational debt is decision speed.
    Decision speed is highly correlated with how fast an organization can ship.
  - Most organizations use the management hierarchy as the only means of making and owning decisions. This undifferentiated hierarchy, lack of expertise in the hierarchy, poor definition of the problem, and not identifying a decision maker often delays decisions.
  - Treating the organization as a programmable entity, and building an internal product to codify its ways of working can find bottlenecks quickly. Build a product to build products. This product deserves the same intent and craftsmanship as customer-facing products. See [Shopify: How we Get Shit Done](https://vimeo.com/456735890)
  - Recruit, *retrain*, retain: It is important to retrain new team members to your organization's way of working. This will help new members produce software consistent with the rest of the team.
  - Open source model: No matter how you design your domains and organization, follow an open source model (internally) for contribution and collaboration. Anyone should be able submit PRs to any repo. New (untrained) eyes tend to spot abstraction debt better than trained eyes.
- **When:** During growth phases pay special attention to organizational debt. Review organizational friction with domain owners and through surveys.
- **Avoid:** Don't reorg too many times. It is important to explain why a reorg is happening and what will improve and how. Don’t outsource the building of the product that builds the product to a third party or purchase an off-the-shelf solution. Build the product that builds products.
- **Sponsor:** Founder(s) / CEO
- **See Also:** [Team Topologies](https://teamtopologies.com/)

### 8. Ergonomic Debt

- **What:** The speed at which a new engineer can fix a bug and deploy the fix to production is the single best measure of engineering ergonomics. Many other types of debt impacts ergonomics, but so do clarity of context, quality of tools, length of feedback cycles, testing infrastructure, and even hardware (e.g. developer laptops, test devices).
- **When:** Set the bar for engineering ergonomics at a new engineer pair programming with a team member and releasing the change to production on day one. Deployment on day one (sounds better than release on day one but it should be release). Engineering ergonomics requires deliberate investment may warrant a dedicated team that owns end-to-end product development ergonomics.
- **Avoid:** Don’t let "day one deployment" become a gimmick. Set the bar at: pair program to *fix a real bug*, test it, deploy it to production, and then send the welcome email with a link to the PR.
- **Sponsor:** CTO

### 9. Emotional Debt

- **What:** As progress is made, expectations also rise. The realization that despite our best effort there is still technical debt is the emotional debt. It is important to evaluate technical debt historically, not just retrospectively: where we were, what we expected, and where we are now. Keep track of progress made and celebrate wins. Also keep track of missed opportunities and acknowledge setbacks. Remind the team there is a strategy and review the strategy regularly with the whole team.
- **When:** Through regular surveys and at least quarterly technical debt readouts at all-hands meetings.
- **Sponsor:** CTO
---

## Interest Rate

The fundamental business advantage of software is the low marginal cost of distributing change. Therefore, the **interest rate** on technical debt is anything that slows down or complicates the ability to make those changes.

Software that rarely changes may carry a low interest rate. However, change frequency isn’t the only factor. Software that doesn’t change often but is mission-critical must be maintained carefully to avoid accumulating system or dependency debt.

> **Prioritize debt repayment based on change frequency:**  
> The higher the frequency of change, the higher the repayment priority.
