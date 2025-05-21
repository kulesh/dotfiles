# A Field Guide to Technical Debt

All good businesses accrue debt and manage it to their advantage. Similarly, a sound technology strategy must accrue technical debt deliberately and manage it appropriately. Taking the metaphor at face value, there are two components to debt: the **type** of debt and the **interest rate**.

---

## Types of Technical Debt
Programming is how an individual solves a problem based on how they understand it, using code. Software engineering begins when that solution must survive teams, time, and trade-offs (and AI Assistants). [See Titus Winters 2017](https://www.youtube.com/watch?v=tISy7EJQPzI&t=472s)

[Needless to say How AI Assistants can help version of this is in the works]

### Abstraction Debt

- **What:** Software embodies a model and mechanization of a solution to a problem. Abstractions (e.g., modules, classes, functions) form the language necessary to precisely describe the solution. As problems evolve and solutions follow suit, abstractions become leaky. Classes and modules become overloaded, and boundaries of responsibility blur. This is abstraction debt.
- **When:** Always be refactoring as part of the regular development cycle.
- **Sponsor:** Technical Lead / Engineering Manager (EM)

### Data Model Debt

- **What:** The atrophy of abstraction often leaks into the data model, creating data model debt. A model may collect extraneous attributes or develop overly complex foreign key relationships. Sometimes, entire concepts (e.g., subscriptions) are only implemented in code and not reflected in the data model. Unlike abstraction debt, the impact of data model debt can be felt outside of software and product—in areas like reporting and finance.
- **When:** Minor issues can often be addressed alongside abstraction debt. Larger conceptual changes, such as introducing subscriptions, require dedicated effort due to many dependencies (e.g., reporting). Acknowledge and treat this work as its own stream.
- **Sponsor:** Domain Owner (e.g., Director)

### System Debt

- **What:** If software is the muscle of a working product, then the underlying frameworks and system architecture are the skeleton and tendons. When these foundations don't keep up with the evolution of product strategy, business needs, or technology, the software must carry extra load to keep the product working. This results in unnecessary complexity and fragility—this is system debt.
- **When:** Addressing system debt is often a cross-disciplinary engineering effort. Form a cross-functional team of infrastructure, security, and product engineers to tackle specific system debt as a dedicated workstream.
- **Sponsor:** Domain Owner

### Dependency Debt

- **What:** Modern software products rely on hundreds of open-source libraries and frameworks, which evolve independently. Dependency debt arises when dependencies are not kept up to date.
- **When:** Minor version upgrades should be continuous and automated (e.g., Dependabot). Major version upgrades may be treated as system debt.
- **Avoid:** Do not fork a dependency to address debt. Contribute changes upstream and pull them down.
- **Sponsor:** Domain Owner

### Product Debt

- **What:** Products represent a point-in-time solution to our understanding of a problem. As problems evolve, product debt accumulates when the product is incrementally adjusted for years without reevaluating the problem from first principles. Ask: *“Knowing what we know today, how would we solve this from scratch?”* This is worth discussing with the team at least annually or biennially.
- **When:** During annual planning.
- **Sponsor:** Executive

### Organizational Debt

- **What:** Software engineering is a team sport that involves the whole organization. The organization’s way of working and the value it places on product quality are major contributors to technical debt. Clear, consistent way of working and a strong focus on quality help slow the accrual of technical debt.

  Treat the organization as a programmable entity, and build an internal product to codify its ways of working. Build a product to build products. This product deserves the same intent and craftsmanship as customer-facing products.
- **When:** During the organization’s growth phase.
- **Avoid:** Don’t outsource this to a third party or purchase an off-the-shelf solution. BUild the product that builds products.
- **Sponsor:** Founder(s) / CEO

### Ergonomic Debt

- **What:** The speed at which a new engineer can fix a bug and deploy the fix to production is the single best measure of engineering ergonomics. Many other types of debt impact this, but so do clarity of context, tool quality, feedback cycles, testing infrastructure, and even hardware (laptops, test devices).
- **When:** Aim for deployment on day one for new engineers. This requires deliberate investment. In larger organizations, it may warrant a dedicated team.
- **Avoid:** Don’t let "day one deploy" become a gimmick. Instead, pair program to *fix a real bug*, test it, deploy it to production, and then send a welcome email with a link to the MR.
- **Sponsor:** CTO

### Emotional Debt

- **What:** "*Progress happens gradually for people to notice and setbacks happen suddenly for people to miss.*" As progress is made, expectations rise. The realization that despite our best effort there is still technical debt is the emotional debt. It’s important to evaluate technical debt historically, not just retrospectively: where we were, what we expected, and where we are now. Celebrate wins. Acknowledge setbacks.
- **When:** Through regular surveys and at least quarterly technical debt readouts at all-hands meetings.
- **Sponsor:** CTO
---

## Interest Rate

The fundamental business advantage of software is the low marginal cost of distributing change. Therefore, the **interest rate** on technical debt is anything that slows down or complicates the ability to make those changes.

Software that rarely changes may carry a low interest rate. However, change frequency isn’t the only factor. Software that doesn’t change often but is mission-critical must be maintained carefully to avoid accumulating system or dependency debt.

> **Prioritize debt repayment based on change frequency:**  
> The higher the frequency of change, the higher the repayment priority.
