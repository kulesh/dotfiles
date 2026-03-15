# The Business of Software

## Philosophy and Practices from the Trenches

_This is an abridged version of a document I have been writing since at least 2011. Primary function of the document has been to help me form first principle-based explainations for various aspects of engineering. Secondary function of the document has been to help with pattern-matching (i.e. intuition) as I put in more years in the trenches._

<!-- Do we need to repurpose this document to address the broader product
development disciplines -->

Value of a business is a sum total of the problems it solves for its customers. In order to create value, a business identifies what customers need, creates products to capture the value, makes them aware of the products, sells the products, distributes the products, and generates profits. Profits are reinvested to turn these seemingly linear stages into a cycle. A _technology business_ defines and implements each stage of the cycle maximally in software. A good implementation makes the stages programmable. Programmable stages help the business continuously compress the completion of the cycle thereby accelerating value creation. A software engineering team that understands their customer needs and that rapidly iterates to meet their needs is an indispensable partner in the business. The rest of this (abridged) document outlines a recipe for creating such a software engineering team.

## Software Engineering

Programming is a pursuit of an individual to solve a problem in the way they understand it by crafting code. Software engineering is programming pursued by a team over a long period of time to solve many problems. Therefore, software engineering is a team sport whereas programming is an individual pursuit. The past and present of software exists on a continuum. The decisions made in the past still influence the business and the decisions made today will influence the business for years to come. Therefore, who we engineer with is just as important as how we engineer software.

## Highly Effective Engineer

We borrow the term “highly effective” from Stephen R. Covey. Highly effective engineers consistently produce the desirable solutions while improving the craft with which they produce those results. Highly effective engineers understand the problems deeply, collaborate to complement their strengths, find good solutions fast, and learn from early mistakes.

## Team

Every person in a team is an expert in their respective field first and takes on different roles. For example, every person in a team is an engineer first and take on different roles, like engineering manager, in a team. Each person earns their titles in their career to demarcate progress and maturity in their trade. A team led by an engineer has a leader who can empathize with the team’s challenges and can advocate for the team effectively. Team is the atomic unit of the organization. Form teams with high cohesion to problems and loose coupling between teams. Each problem is owned by a team with sufficient expertise and agency to solve the problem. No one works alone. Work moves to teams. People do not move to work. We succeed and fail as a team. A team’s success is predicated on a psychologically safe environment for its members to work together.

## The Problem

What problem are we trying to solve? The number of words used to answer that question is inversely correlated to the clarity of the problem. Well-defined problems get solved; ill-defined problems get chased. People don't spend enough time with a problem before attempting to solve it. Teams should own well-defined, first order business problems with a clear outcome.

## Team of Teams

An organization is a team of teams; not a bunch of people. An effective organization has leaders at all levels who have the breadth and depth of expertise with the agency to make good trade-offs fast.

## Leaders

A leader is someone who takes ownership of a situation and makes it better for everyone involved. A team where every engineer has the breadth of technical knowledge and can go deep on-demand. A team where everyone immerses themselves in the details so they can make good trade-offs fast. Recruit, retrain, and retain a team of highly effective engineers. <!-- doesn't quite fit together -->

## Recruit

When recruiting mission alignment comes first. Recruit people who are aligned to the mission of the business. Recruit for the organization. Do not recruit for a specific team. Seek out people interested in solving the problems our customers face, those who collaborate to complement their strengths, and those who learn continuously. It is our responsibility to set each candidate up to put their best foot forward. Assess engineers based on their understanding of first principles in software engineering and computer science not based on their accreditation.

## Retrain

We accept engineers from all walks of life and experience. We commit ourselves to train new engineers on our technology stack, toolchain, and practices they need to be familiar with to be highly effective. We begin to keep our commitment by starting every new engineer’s journey with a deployment to production on day one--without exception. On week one the new engineer and the manager agree on a 90-day role success plan. Role success plan gets commitments from all parties to succeed in the joint endeavor both as an employee and as an employer.

## Retain

Context creates belonging. We commit ourselves to give our engineers all the necessary context they need to understand why they are solving the problems the way they are solving them. We should strive to retain engineers for as long as their tenure at the organization is beneficial to their career trajectory. It is inevitable for some engineers to move on to new roles in new places while others find new roles within our organization to grow their skills. We use the role success plans to structure the progress of engineers and their career trajectory to the point every engineer knows their answer to “Why are you here?”

## Career path

While a career path is useful to demarcate progress, we must understand a career path is non-linear. We should emphasize skill acquisition, mastery, and effectiveness over attainment of titles at regular intervals. As an organization we must provide equitable compensation and recognition for their contributions.

### Roles and Responsibilities

Leadership is a role. Anyone can assume a role. A level in an engineering career path is earned. Each level is associated with a title and comes with corresponding responsibilities and rewards.
• Apprentice Engineer:
Learning computer programming and becoming an excellent programmer with the goal of becoming a productive member of a software engineering team.
• Engineer:
An individual contributor in a software engineering team consistently shipping parts of features.
• Senior Engineer:
Senior most individual contributor in a team who works independently to shape entire features and work with the team to continuously ship the features.
• Engineering Manager:
Leader, coach, mentor, and manager of a 4-5 person team responsible for consistent and quality deliverables of the team.
• Engineering Director:
A domain owner focused on the improvement of a whole domain: people, practices, and technology within a business area.
• VP Engineering:
Organizational leader responsible for building and operating an entire engineering team (of teams).
• Staff engineer:
An engineer who takes ownership of a problem an organization has but didn’t know how to solve and solve it for the organization.
• Principal Engineer:
An engineer who identifies problems an organization didn’t know it had and solves the problems.
• Distinguished Engineer:
An engineer who identifies problems an industry didn’t know it had and solves the problem for the benefit of the industry.
• CTO:
A technology leader who identifies, simplifies, and scales solutions across the business.

## Processes, Practices, and Habits

It is important to differentiate between a habit, a practice and a process. A habit is an activity developed and adopted by an individual to the betterment of oneself. A practice is an activity developed by the team, for the team, for operating effectively. A process is enforced on a team by a third party to keep the team accountable. Shared processes and practices pull individuals together into teams and teams together into an organization. We should strive to turn processes into practices and practices into habits.

### Practices

Build it, run it, break it, fix it
Each team is responsible for and equipped to build, test, deploy, and run the products they build. Engineers in the organization, therefore, staff an on-call rotation for the products they build. Engineers build quality into the product they build and partner with their product counterparts to verify the quality of the product. [Engineers build products they can monitor the health of… review metrics regularly… and care for its operation in production.]
Internal Open Source
Collaborate with internal open source models to reduce coordination.
Continuous Deployment
Every change we make, we deploy to production. As a team we practice continuous deployment. Not continuous delivery. Not [just] continuous integration. We practice continuous deployment.

## Tenets in Tension

Shared tenets establish alignment on how we work and make decisions. High alignment fosters autonomy and agency. These tenets live within the values of the organization.
#1. Understand what customers value: Understanding what customers value is crucial to building the products customers need. Spend as much time as necessary to understand your customers' problems from their point of view before thinking about solutions.
#2. Collaborate to complement strengths: Effective software engineering combines lessons from multiple disciplines and diverse points of views to solve problems. Collaborate to complement your strengths. Coordination is not collaboration. Shun coordination.

#3. Make new mistakes: Rapid experimentation, making mistakes, learning from the mistakes, applying the lessons effectively, and making new mistakes compounds our growth and reduces the cost of failures. Avoid making avoidable mistakes. Avoid repeating the mistakes.

#4. Get going, then get good: Rapid iteration is at the heart of great outcomes. Get started, collaborate to get feedback, ship, get customer feedback, and make it better.
#5. Alignment fosters autonomy: Alignment creates trust which promotes autonomy. Highly effective teams are highly aligned and self-sufficient. Share early and often to align. Seek help to make teams autonomous over building means of coordination.
#6. Peer through abstractions: We use abstractions to encapsulate complexity. Peering through abstractions and understanding what lies beneath helps us solve problems over managing the problems. This is true of any problems; software or otherwise.
#7. Take ownership, earn trust: Earn trust and respect by owning problems and solving them reliably and consistently. When you own a problem, know that you’re not alone.

#8. Assume positive intent: Begin with the most generous interpretation of the actions and delve deeper to find the true intent.

#9. Optimize the whole: When optimizing, consider the impact on dependencies and lean into optimizing the whole. Avoid premature optimizations.

#10. Confidence over caution:
Caution breeds fragility. Embrace failures and create systems to be
resilient.
