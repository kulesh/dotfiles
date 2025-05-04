# AI Kata: My AI Pairing Workflow
This is the workflow I use to turn rough ideas into shippable tasks by pairing with an AI Assistant. The goal is to create a workflow where I am only the creator of an idea and for the rest of the steps I am merely a reviewer. We have a long way to go.

Over the past couple of years, this workflow has evolved from generating small scripts in ChatGPT, to uploading files and copy-pasting diffs, to trying to pair with an AI Assistant for everything. Though parts of the workflow has been used for shipping production code most of the time I use this workflow for making and iterating on small projects.

## Lessons Learned
Pairing with an AI Assistant is like (co-)piloting an aircraft cross-country. As the captain, you must set the destination, plot waypoints, communicate clearly, and monitor flight progress closely. You must be prepared to nudge the co-pilot or take control of the aircraft ("my aircraft"). Here are lessons learned from about a year of practice.
* **Vibe sessions are great for shaping an idea:** Using Cursor to vibe code something is an effective form of brainstorming. I play with the *actuation of an idea* and shape it with precise feedback.
* **Write everything down:** The workflow for turning vibeware into software is made up of several pairing sessions with an AI Assistant. LLMs backing the AI Assistants are stateless. Therefore, most of the state keeping, like what we are working on, where we left-off, during a session and between sessions is written to Markdown files. I usually feed a set of these files into the Assistant as context to bootstrap a session. I recommend writing everything down (idea briefs, todo lists, bug list) in text and making it part of the repo. Latest versions of the tools, like Cursor,  do this for you.
* **A grokkable chunk is the working unit:** Every pairing session I do with an AI Assistant has a clear start and end. I keep the output of each session to a grokkable chunk. By "grokkable", I mean, I should know what we just finished, how it fits into the rest of the puzzle, and how it works.
* **Mental model of the system is still with the human:** Mental model of the working software is still in my head. I haven't put any time to figure out how to get this mental model out of my head and into a file. Having said that, keeping an accurate mental model in my head is useful to steer the Assistant quickly when it inevitably goes into a rabbit-hole.
* **Clear and shared lexicon is important:** Giving components and screens of your product unambiguous names saves a lot of time and frustration because you can direct the assistant precisely. Especially useful when the Assistant goes awry and fixes the wrong thing. In the absence of names, using a URL (if webapp) of a view/page is useful. Even multimodal Assistants with a screenshot in the correct context can still get lost. "The ``Foo`` button on ``Bar#index`` page is not functioning" is more effective than "``Foo`` button is not functioning" even when ``Foo`` button was the thing the Assistant is currently fixing.
* **Finding flow has been difficult:** My lone-wolf coding workflow is: I spend time to figure out what/how I am going to solve, create a plan in my head, put on the headphones and go at it for hours. I find it difficult to stay in flow while the Assistant is working but feel I should stay in flow so I can continue to push the Assistant in the right direction. While the assistant is working I am usually reviewing what we wrote but the token spitter is too fast and I end up context switching too frequently. I limit the pairing sessions to one hour.
* **Plan-Review-Execute cycle all the way down**: Each step, no matter how big or small, is a plan-review-execute cycle. I often feed the result
  of one step as input to the next explicitly; review and edit the output; then send it for execution. In the execute step I ask the Assistant to update the input file to keep track of things, for example: ``Go through the bugs.md file and pick up three open bugs to fix in this session. Update the file as we fix the bugs.``
* **Test driven development is made for AI** as long as tests are accurate (e.g. testing the intent) and the AI Assistant is not modifying the code *and* the test at the same time--a form of reward hacking, if you will. **Biggest challenge is testing the frontend.** There are times I have found frontend regressions weeks later and then it is an uphill battle on even slightly mature codebases.
* **Lot of tools; lot of gaps:** I have done everything from copy-pasting from ChatGPT web, using NeoVim with AI Assistants, using Aider, Claude Code, and Cursor. I have not found one tool effective on all the steps. I switch between Cursor, Claude Code, and Neovim/CodeCompanion. Depending on what type of "session" I am going to go into I pick one tool and stay with it. Tools are not mature enough to settle on one. I would say we have **good tools for vibe coding, decent tools for programming, and nascent tools for software engineering.**
* **Some Definitions:**
    * *Program*: Code written by one person to solve a problem the way they understand it
    * *Software*: ``Software = f(Program, People, Time, [AI Assistants])`` [Titus Winters 2017](https://youtu.be/tISy7EJQPzI?t=472)
    * *Vibe Coding*: [See stuff, say stuff, copy-paste stuff](https://x.com/karpathy/status/1886192184808149383?lang=en) until it works
    * *Vibeware*: A functioning prototype that feels like a product (produced as a result of vibe coding).
    * *Session*: I keep calling the pairing sessions with an Assistant "sessions"; each one is about an hour.

## Stages of the Workflow
My current workflow is no different than what I do with a team of software engineers except it feels like I am working with a toddler on a treadmill. The intent of each session, the goal, the inputs, and outputs ought to be well-defined in writing. Here are the different stages of the workflow:
1. Brainstorming: Loop between a vibe session in Cursor and a prompted session
   with Claude to turn an idea into a written idea brief. Goal is to get a
   high-level description of the shape and form of the idea in a Markdown file.
2. Product Spec: Given the idea brief as the input and get a product spec as the
   output. I tend to lean on Claude 3.7 or GPT 4o for this step. Lately I have started
   using Gemini 2.5 more.
3. System Design: Use the product spec (and sometimes idea brief) as input and get a C4 diagram and an ADR as output. Most important output from this stage turned out to be names for components and domains. This helps direct the attention of the model with little ambiguity. I also get a sketch of a system diagram and tech-stack. I exclusively use Claude 3.7 out of habit.
4. Development Plan: Given the product spec and system design, build out a plan
   for weekly shippable milestones. Important to keep the model honest that each
   milestone is shippable.
5. Todo and Bugs: I try to maintain a Todo.md file for continuity. Take a grokkable unit from the development plan and produce a list of things to do. Similarly, as and when I come across bugs I write them down in Bugs.md. I
   usually break the bugs into views/pages or a component. This file is mostly human
   appended and AI Assistant updated.
6. Review & Refactor: When the Assistant is working on something I tend to
   review code manually looking for idiomatic issues. I might fix small ones
   manually otherwise I make a TODO note of any necessary refactoring in-situ.

Below I discuss each step in too much details; probably the most useful parts
are prompts and some issues I have run into. This whole file was written by a
human! Here is an example artifact of this workflow: [Timer](timer-example/)


### 1. Brainstorm
**Goal:** Explore and shape an idea with enough clarity to come up with an *idea brief* that can be shared with fellow humans and AI Assistants.

**Steps:**
1. State the initial idea: It's useful to capture the essence of the idea in
  words before getting an Assistant involved. For example, "*Suppose a timer app has not yet been invented. In a world where intelligence is abundant and on tap, what would the first-ever AI-native timer designed from the ground up look like and function?*"
2. Explore the idea with a vibe session: I stick the idea as the prompt
   into Cursor and iterate until I am happy with the output. Depending on the app I might
   spend anywhere from 15 minutes to a couple of hours on this. I take screenshots
   and notes of function, form, and any friction points as I play with the vibeware.
3. Idea Shaping Q&A: Then, engage a reasoning model on a Q&A session to put some shape and
   form to the idea in writing. I use the prompt below for this. This can take a while or
   may feel like a while. I highly recommend voice input for this stage.
4. Idea Brief: Ask the Assistant to create an idea brief in Markdown format. I
   usually store the backing model's name and date in the file.

**Prompt:**
> You and I are going to brainstorm an idea I have. Our goal is to explore and refine the idea until we have enough clarity to create an "idea brief" I can share with colleagues. They will use our idea brief to develop and release a product.
>
> During this brainstorming session we will engage in a turn-taking conversation. You will ask thoughtful, open-ended questions to help shape and deepen the idea. I will be answering your questions. Ask one question at a time and wait for my response before continuing. Each question should build upon the previous questions and answers. Feel free to create a summary of our conversations whenever you deem it necessary and helpful.
>
> Let's begin the brainstorming session; Here is my idea:
> <idea here; same as the Cursor prompt above>

At the end of the conversation I use the following prompt to generate the idea brief: 
> Please create an idea brief in Markdown format with the following:
> * Original Prompt: Repeat the prompt that started this conversation word-for-word.
> * Summary: One paragraph summary of the idea and essence of our discussion.
> * Idea Brief: Idea brief should be based solely on this brainstorming conversation and nothing else. The brief should contain a clear articulation of the problem the idea aim to solve, proposed solution(s), value proposition compared to current solutions, any insights gained/identified during the brainstorming, personas, and other relevant information. 
>   Structure the brief in a narrative form that shapes the idea clearly such that the brief can be used to build a product specification.
> * FAQ: This is optional. Please feel free to add a frequently asked/answered questions
>   section to underscore anything that could not fit into the narrative above.
> * Sign-off: Sign off the document with your identity (e.g. model string) and
>   current date and time.

Notes:
* Notice the plan-review-execute cycle above: Plan is me coming up with the idea first, review is the Q&A, execute is the idea
brief.
* During the Q&A sometimes Claude may start warning about "long chats can cause
  usage limits" and encourage you to start a new chat. I ignore that warning.
* Sometimes I might upload the idea brief to a different model and ask for a
  critique. It's helpful.
* When using Gemini ask for LaTex output instead of Markdown. Gemini's web UI is
  broken and sometimes renders Markdown as HTML.

### 2. Product Spec

**Goal:** Given an idea brief come up with a product spec that can be shared with an engineering team for review and implementation.

**Steps:**
1. Idea brief to Spec: This step is usually a one-way conversation. I copy-paste the summary of the idea brief with the
   prompt and upload the idea brief.
2. Shared Lexicon: I usually beeline to the Shared Lexicon section because reading through that
   quickly gives me a sense of gaps the product spec may have. If I cannot put a
   good mental model of the product with what's in the shared lexicon then we need to iterate more.
3. Feedback: I markup the product spec Markdown file with ``[KS]:`` in situ. Easy to manage provenance in git. (I used to use ``[Feedback]`` until I realized sometimes the models found "feedback" elsewhere and went after the wrong thing.)
4. The MVP: Models usually have an MVP as a milestone and I tend to focus and iterate on that first. This is because I find the models come up with decent MVPs but the rest of the milestones can be more abstract or not quite in the right direction. I don't bother with the rest of the milestones until I am done with the MVP. So I tend to give a lot of feedback to polish up MVP. Ask for shippable weekly milestones to hit the right level of details.

**Prompt**
> You are an experienced product manager. You are tasked with turning the attached Idea Brief into a detailed Product Specification Document (Product Spec). This product spec will be used by the product development team (engineers, designers, data science) to understand the product vision, guide system design and architectural decisions for both the Minimum Viable Product (MVP) and future iterations. Therefore, the document should focus on:
>  - Introduction & Vision: Product vision and value proposition to align the team
>  - Goals & Objectives: Clear high-level goals for the product, primary objectives for the MVP
>  - Personas: Profile of target users; focusing on their needs and how the product and MVP will meet those needs
>  - User Experience: User journeys, interaction models, interface requirements, and any design principles drawn from the idea brief
>  - Feature Requirements: Detailed description of capabilities with acceptance criteria for MVP. Add screen markups and wireframes wherever necessary.
>  - Data Model (Conceptual): Identify key data entities the system needs to manage or user personas interact with
>  - MVP Scope: Clear delineation of features for the initial release
>  - Product Roadmap: Prioritization and phasing of features up to MVP and beyond MVP
>  - Shared Lexicon: A collection of terms that together describe the product and its function precisely to the team. Each term unequivocally communicates a specific concept to the team; and together a set of terms help form precise mental models about the product.
>  - Success Metrics: KPIs to measure product effectiveness
>  - Open Questions and Assumptions: List any ambiguities in the brief or assumptions made 
>  - FAQ: Put yourself in the shoes of the product development team and write a
>    frequently asked/answered questions section
>  - Original Prompt: Please include this prompt word-for-word
>  - Sign-off: Please sign-off with your name (e.g. model string), knowledge cutoff, and timestamp
>
> Ensure the language is clear, concise, and targeted at a technical audience.
> Focus on the what and why, leaving the how (specific implementation details)
> largely to the development team, while providing enough detail to guide their
> technical design. Please output in Markdown format.
>
> \<Attach the idea brief or copy-paste the text\>
>
Once I review the product spec and mark it up with my feedback, upload the file back to the same chat session that produced the spec with the following prompt:
> Read through the attached product spec. I left some feedback in the document. Look for lines beginning with "[KS]: ". Please do the following:
> 1. List out all instances of feedback you found
> 2. Address each feedback one-by-one
> 3. Append the list of feedback addressed
> 4. Rewrite the entire product spec with the addressed feedback
> 5. Sign-off the document with your model-string, knowledge cutoff, and timestamp
>
> Ensure the product spec is in Markdown format for me to download and save.

It's important to review the list to make sure the model is not hallucinating.
Sometimes the models miss the "attached" document and latches on to other parts of the
context from previous conversation.

Notes:
* Claude has a hard time sticking to the most recent document and tend to go
  back into earlier context. So whenever I use Claude for feedback I use a new
  session. Gemini 2.5 Pro and GPT 4o are fine.
* Gemini 2.5 UI has a hard time presenting Markdown output consistently. LaTex
  is more consistently rendered by the UI.

### 3. System Design

**Goal:** Create a high-level technical design to share with the team as an RFC
and align on ADRs.

**Steps:**
- Create a domain model
- Generate a C4 diagram (Context → Container → Component).
- Identify key technical decisions and document them as Architecture Decision Records (ADRs).
- Review and validate assumptions made by the Assistant.

**Deliverable:** An RFC-grade technical design document outlining:
- Rationale for key decisions
- Dependencies and integration points
- Infra or platform constraints

**Prompt**

> You are a Staff Engineer leading a team of 2 senior engineers and their AI Coding Assistants. You are tasked with implementing the product detailed in the attached product spec. Your task is to create a detailed system design document based on the provided product spec. The system design document will serve as the primary technical blueprint for the development and release of the MVP the product and its subsequent iterations. However, let's focus on the MVP first because it is our first and the most important deliverable.
> While working on the system design please keep the following overarching tenets in mind:
> 1. Domain driven development: Use domain driven development. Identify and clearly document domains, ubiquitous language, etc. defining the product.
> 2. Service Oriented Architecture: Use monoliths or service oriented architecture to cleanly separate concerns and establish boundaries. Separate the frontend and the backend with a clean RESTful API. Do not go directly to micro services architecture and complicate our lives. 
> 3. Test Driven Development: The team will be using AI Coding Assistants for the development of this product. Use Test Driven Development wherever appropriate to accelerate the feedback loop between the team and their AI Coding Assistants.
> 4. Boring Technology: Rely on time tested technology over chasing shiny new things. Exception to this rule is your choice for the AI stack.
> 5. AI stack: Since the technical stack for AI is nascent and constantly evolving you can break the above rule when selecting components to form the AI stack. Pick the best performing model and the simplest framework.
> 6. Open Source: Choose open source technology over proprietary technology unless using a proprietary technology has significant advantage.
> 7. Cloud Native: Assume the product will run in the cloud. Don't settle on a cloud provider yet. Don't pick a cloud specific technology unless there are significant benefits.
> 8. Do Not Optimize for Cost: We will bank on sustained decrease in technology cost. So, don't optimize for cost. Optimize for getting exceptional results fast.
> 9. Secure by Default: Keep the designs simple and secure. Rely on proven security constructs; don't invent new ones. Don't write API keys or other security materials in files.
>
> The document shall include the following sections:
>
>1. Domain-Driven Design (DDD) Analysis:
>   - Identify bounded contexts with clear boundaries and responsibilities
>   - Define the core domain, supporting subdomains, and generic subdomains
>   - Create a ubiquitous language mapping that aligns with our product's shared lexicon
>   - Identify aggregates, entities, value objects, and domain events
>
>2. C4 Model Architecture Diagrams:
>   - Context diagram showing the entire system and external dependencies
>   - Container diagram illustrating the high-level technology choices and communication patterns
>   - Component diagrams for the most complex or critical containers
>   - Include textual explanations of key design decisions for each level
>
>3. Critical System Components:
>   - Outline the key technical components required to implement each feature
>   - Specify component responsibilities, interfaces, and dependencies
>   - Identify potential web services or modules with clear separation of concerns
>   - Highlight high-risk components requiring special attention
>
>4. Architecture Decision Records (ADRs):
>   - Document 5-7 critical architecture decisions using the ADR format
>   - For each decision, include context, options considered, decision outcome, and consequences
>   - Focus on decisions with significant technical debt implications or long-term impact
>   - Address key technical challenges identified in the product specification
>
>5. Technical Implementation Guidelines:
>   - Recommended technology stack with justifications
>   - Data storage strategies for different entity types
>   - API design principles for internal and external communication
>   - Security and privacy implementation approaches
>   - Performance optimization strategies for core user journeys
>
>6. Engineering Team FAQ:
>   - Create a list of technical questions that engineers might ask about this system
>   - Provide detailed answers that reference specific sections of the design
>   - Include questions about scaling, infrastructure, technical debt, and development approach
>   - Address potential concerns about implementation complexity
>
>Readers are highly technical engineers. Start the design document with high-level concepts and principles then dive into the details. Use diagrams, tables, structured lists, and pseudocode to make the document scannable, and explain any specialized terminology used in the design. Output the document in Markdown format.
>
> Here is the product spec:
> <Insert/upload product spec>
> 

### 4. Development Plan

**Goal:** Based on the product spec and the system design doc, breakdown the development work into weekly releasable product milestones.

**Steps:**
- Use the product spec and system design document to create development phases
- Decompose work into grokkable chunks (e.g., features, spikes, interactions)
- Identify and track technical risks or unknowns
- Define clear outcomes for each session

**Deliverable:** Session-based development roadmap with:
- Weekly milestones
- Tasks per session (1-hour blocks)
- Definition of done for each session
- Known risks and how they’ll be addressed

**Prompt**
> You are the technical lead responsible for shipping an MVP for a new product.
> Your development team has two senior engineers who pair with their AI Coding
> Assistants to develop and release high-quality features rapidly. The team is
> capable of and is expected to release a new iteration of a working
> product to production every week.
>
> You are going to write a detailed development plan for the team to follow and build the MVP defined in
> the attached product spec according to the technical blueprint laid out in the attached system
> design document. The development plan has two components:
> 1. A clear breakdown of weekly working product releases
> 2. Effective prompts for the AI Coding Assistants to build the components
>    making  up each release
>
> 1. Weekly Product Releases:
> Breakdown your development plan into weekly releases that build on each other to form the final version of the MVP. For each release include a brief release note and list of released features. Once you have the weekly releases, review each release to ensure each release is 1) a working product 2) small enough to be completed on schedule.
>
> 2. Effective Prompts:
> Since the team will be using AI Coding Assistants, write a series of effective prompts they can copy-paste into their AI Coding Assistants to accelerate the development of the MVP. Breakdown each weekly release and identify individual building blocks that make up the release. Each building block should be testable in isolation. Write a series of prompts to build the identified blocks. When writing these prompts you must ensure their AI Coding Assistants will adhere to the technical choices made and ADRs outlined in the system design document. Once you complete writing the series of prompts please review the prompts to ensure:
> 1. Each prompt builds on top of each other incrementally without major leaps
> 2. Series of prompts within a weekly release stacks up to a releasable working product outlined in the development plan
> 3. Weekly releases builds up to the MVP
>
> Please output the entire development plan as Markdown document I can download
> and save.
---

### 5. Todo and Bugs List

**Goal:** Keep a running list of Todos and Bugs for continuity.

**Prompts**
> Please read through the codebase and make a list of Todo items. Ensure there
> are no duplicates between the list and the items in Todo.md. Write the
> finalized list to Todo.md.

> Please read through the Todo.md file and pick an item to work on in this
> session. Do not mark the item as completed until I tell you to do so.
>

I use the same prompt for bugs as well.

---

### 6. Review & Refactor

**Goal:** When the Assistant is generating code I am usually reviewing and
marking up refactoring or style issues in the code.

**Steps:**
- Schedule recurring AI-assisted reviews (daily, weekly, or per milestone).
- Update artifacts as needed (PRD, architecture, plan, etc.).

**Prompt**
Same prompt as Todo above. I usually extract and put refactoring as part of
Todo,

---

## In the Works
1. Giving the assistant a name makes it easy to mark up documents. (See [Diane](https://interconnected.org/home/2025/03/20/diane))
2. Code this workflow up. Make it easy to revise plans, documents in the middle
