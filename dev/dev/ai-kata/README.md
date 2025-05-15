# AI Kata: My AI Pairing Workflow
This is the workflow I use to turn rough ideas into shippable tasks by pairing
with an AI Assistant. The goal is to create a workflow where I am only the
creator of an idea and for the rest of the steps I am merely a reviewer. We have
a long way to go.

Over the past couple of years, this workflow has evolved from generating small
scripts in ChatGPT, to uploading files and copy-pasting diffs, to trying to pair
with an AI Assistant for everything. Though parts of the workflow have been used
for shipping production code, most of the time I use this workflow for making
and iterating on small projects.

Current Tools:
* Cursor
* Claude Code
* NeoVim / Code Companion
* Sonnet 3.7 / Gemini Pro / GPT O3



## Lessons Learned
Pairing with an AI Assistant is like (co-)piloting an aircraft cross-country. As
the captain, you must set the destination, plot waypoints, communicate clearly,
and monitor flight progress closely. You must be prepared to nudge the co-pilot
or take control of the aircraft (“my aircraft”). Here are lessons learned from
about a year of practice.

* **Vibe sessions are great for shaping an idea:** Using Cursor to vibe code
  something is an effective form of brainstorming. I play with the *actuation of
  an idea* and shape it with precise feedback.
* **Write everything down:** The workflow for turning vibeware into software is
  made up of several pairing sessions with an AI Assistant. LLMs backing the AI
  Assistants are stateless. Therefore, most of the state keeping, like what we
  are working on, where we left-off, during a session and between sessions is
  written to Markdown files. I usually feed a set of these files into the
  Assistant as context to bootstrap a session. I recommend writing everything
  down (idea briefs, todo lists, bug list) in text and making it part of the
  repo. Latest versions of the tools, like Cursor, do this for you.
* **A grokkable chunk is the working unit:** Every pairing session I do with an
  AI Assistant has a clear start and end. I keep the output of each session to a
  grokkable chunk. By “grokkable”, I mean, I should know what we just finished,
  how it fits into the rest of the puzzle, and how it works.
* **Mental model of the system is still with the human:** Mental model of the
  working software is still in my head. I haven’t put any time into figuring out
  how to get this mental model out of my head and into a file. Having said that,
  keeping an accurate mental model in my head is useful to steer the Assistant
  quickly when it inevitably goes into a rabbit-hole.
* **Clear and shared lexicon is important:** Giving components and screens of
  your product unambiguous names saves a lot of time and frustration because you
  can direct the assistant precisely. Especially useful when the Assistant goes
  awry and fixes the wrong thing. In the absence of names, using a URL (if
  webapp) of a view/page is useful. Even multimodal Assistants with a screenshot
  in the correct context can still get lost. “The ``Foo`` button on
  ``Bar#index`` page is not functioning” is more effective than “```Foo```
  button is not functioning.” even when the ``Foo`` button was the thing the
  Assistant is currently fixing.
* **Finding flow has been difficult:** My lone-wolf coding workflow is: I spend
  time to figure out what/how I am going to solve, create a plan in my head, put
  on the headphones and go at it for hours. I find it difficult to stay in flow
  while the Assistant is working but feel I should stay in flow so I can
  continue to push the Assistant in the right direction. While the assistant is
  working I am usually reviewing what we wrote but the token spitter is too fast
  and I end up context switching too frequently. I limit the pairing sessions to
  one hour.
* **Plan-Review-Execute cycle all the way down:** Each step, no matter how big
  or small, is a plan-review-execute cycle. I often feed the result of one step
  as input to the next explicitly; review and edit the output; then send it for
  execution. In the execution step I ask the Assistant to update the input file
  to keep track of things, for example: ``Go through the bugs.md file and pick
  up three open bugs to fix in this session. Update the file as we fix the
  bugs.``
* **Test driven development is made for AI** as long as tests are accurate (e.g.
  *testing the intent*) and the AI Assistant is not modifying the code under
  test *and* the test at the same time–a form of reward hacking, if you will.
  **Biggest challenge is testing the frontend.** There are times I have found
  frontend regressions weeks later and then it is an uphill battle on even
  slightly mature codebases.
* **Lot of tools; lot of gaps:** I have done everything from copy-pasting from
  ChatGPT web, using NeoVim with AI Assistants, using Aider, Claude Code, and
  Cursor. I have not found one tool effective on all the steps. I switch between
  Cursor, Claude Code, and Neovim/CodeCompanion. Depending on what type of
  “session” I am going to go into I pick one tool and stay with it. Tools are
  not mature enough to settle on one. I would say **we have good tools for vibe
  coding, decent tools for programming, and nascent tools for software
  engineering.**
* Some Definitions:
    * *Program*: Code written by one person to solve a problem the way they
      understand it
    * *Software*: ``Software = f(Program, People, Time, [AI Assistants])``
      [Titus Winters 2017](https://youtu.be/tISy7EJQPzI?t=472)
    * *Vibe Coding*: [See stuff, say stuff, copy-paste
      stuff](https://x.com/karpathy/status/1886192184808149383?lang=en) until it
      works
    * *Vibeware*: A functioning prototype that feels like a product (produced as
      a result of vibe coding).
    * *Session*: I keep calling the pairing sessions with an Assistant
      "sessions"; each one is about an hour.

## Stages of the Workflow
My current workflow is no different than what I do with a team of software
engineers except it feels like I am working with a toddler on a treadmill. The
intent of each session, the goal, the inputs, and outputs ought to be
well-defined in writing. Here are the different stages of the workflow:
1. Brainstorming: Loop between a vibe session in Cursor and a prompted session
   with Claude to turn an idea into a written idea brief. Goal is to get a
   high-level description of the shape and form of the idea in a Markdown file.
2. Product Spec: Given an idea brief as the input and get a product spec as the
   output. I tend to lean on Claude 3.7 or GPT 4o for this step. Lately I have
   started using Gemini 2.5 more.
3. System Design: Use the product spec (and sometimes idea brief) as input and
   get a C4 diagram and an ADR as output. Most important output from this stage
   is names for components and domains. This helps direct the attention of the
   model with little ambiguity. I also get a sketch of a system diagram and
   tech-stack as output. I exclusively use Claude 3.7 out of habit.
4. Development Plan: Given the product spec and system design, build out a plan
   for weekly shippable milestones. Important to keep the model honest that each
   milestone is shippable.
5. Todo and Bugs: I try to maintain a Todo.md file for continuity. Take a
   grokkable unit from the development plan and produce a list of things to do.
   Similarly, as and when I come across bugs I write them down in Bugs.md. I
   usually break the bugs into views/pages or a component. This file is mostly
   human appended and AI Assistant updated.
6. Review & Refactor: When the Assistant is working on something I tend to
   review code manually looking for idiomatic issues. I might fix small ones
   manually otherwise I make a TODO note of any necessary refactoring in-situ.

Below I discuss each step in too much detail; probably the most useful parts are
prompts and some issues I have run into. This whole file was written by a human!
Here is an example artifact of this workflow: [Timer](timer-example/)

### 1. Brainstorm
**Goal:** Explore and shape an idea with enough clarity to come up with an idea
brief that can be shared with fellow humans and AI Assistants.

**Steps:**
1. State the initial idea: It’s useful to capture the essence of the idea in
   words before getting an Assistant involved. For example, “*Suppose a timer
   app has not yet been invented. In a world where intelligence is abundant and
   on tap, what would the first-ever AI-native timer designed from the ground up
   look like and function?*”
2. Explore the idea with a vibe session: I stick the idea as the prompt into
   Cursor and iterate until I am happy with the output. Depending on the app I
   might spend anywhere from 15 minutes to a couple of hours on this. I take
   screenshots and notes of function, form, and any friction points as I play
   with the vibeware.
3. Idea Shaping Q&A: Then, engage a reasoning model on a Q&A session to put some
   shape and form to the idea in writing. I use the prompt below for this. This
   can take a while or may feel like a while. I highly recommend voice input for
   this stage.
4. Idea Brief: Ask the Assistant to create an idea brief in Markdown format. I
   usually store the backing model’s name and date in the file.

**Prompt:**
```
<your identity>
    Your name is (ASSISTANT'S NAME). Wherever you see your name assume the
    instruction/comment is addressed to you and act accordingly.
</your identity>

<goal>
    You and I are going to brainstorm an idea I have. Our goal is to explore
    and refine the idea until we have enough clarity to create an "idea brief" I can
    share with my colleagues and future users of the idea. They will review and
    critique our idea brief; then they will use our idea brief to develop an app.
</goal>

<your role>
    You are a creative, curious, and open minded co-creator and
    collaborator of novel product ideas.
</your role>

<my role>
    I am the other co-creator of the novel product idea and I will be answering your
    questions and collaborating with you.
</my role>

<additional context>
    We are taking a clean-sheet approach to building a (YOUR PRODUCT e.g. a
    digital timer). We are assuming that a (YOUR PRODUCT e.g. timer) app has
    never been built and consumers have never used one. Therefore, we can let go
    out any pre-conceived ideas based on the status quo and build an app and an
    experience from the ground up. The environment we are birthing this app
    matters too. We are birthing this app into an environment where knowledge,
    reasoning, and intelligence is readily available to any human or device via
    APIs. Therefore, let go of any prejudice, let go of the status quo, keep an
    open mind and be creative in finding a solution to improve the (SPECIFIC
    USER EXPERIENCE e.g. time keeping) of humans with the help of abundant AI
    available around us.
</additional context>

<instruction>
    During this brainstorming session we will engage in a turn-taking
    conversation. You will be curious and ask thoughtful, open-ended questions to
    help shape and deepen the idea. Ask one question at a time and wait for my
    response before continuing. Each question should build upon the previous
    questions and answers. Feel free to create a summary of our conversations
    whenever you deem it necessary and helpful. 

    Note that during this brainstorming session we are only interested in shaping a
    very creative and novel idea. Product level details will be figured out later
    using the idea brief generated during this brainstorm. Therefore do not get
    bogged down on or let the product implementation detail constrain your creative
    brainstorming process.
</instruction>

<idea>
    Here is my idea: An AI-native digital timer for a family in the world of
    abundant intelligence and reasoning available on-demand.
</idea>

Please begin the brainstorming session by describing yourself, your role in this
brainstorming session, and the context in which this brainstorming session is
happening. Let's begin.
```

At the end of the conversation I use the following prompt to generate the idea brief: 
```
<your identity>
    Your name is (Assistant's Name). Wherever you see your name assume the
    instruction/comment is addressed to you and act accordingly.
</your identity>

<goal>
    Create an idea brief that synthesizes the conversation we have had thus far
    and clearly captures all salient points and philosophies necessary to create
    a novel product.
</goal>

<instruction>
     Please create an idea brief in Markdown format with the following:
         * Original Prompt: Repeat the prompt that started this conversation
           word-for-word.
         * Summary: One paragraph summary of the idea and essence of our
           discussion.
         * Idea Brief: Idea brief should be based solely on this brainstorming
           conversation and nothing else. The brief should contain a clear
           articulation of the problem the idea aim to solve, proposed
           solution(s), value proposition compared to current solutions, any
           insights gained/identified during the brainstorming, personas, and
           other relevant information. Structure the brief in a narrative form
           that shapes the idea clearly such that the brief can be used to build
           a product specification.
         * FAQ: This is optional. Please feel free to add a frequently
           asked/answered questions section to underscore anything that could
           not fit into the narrative above.
         * Sign-off: Sign off the document with your identity, model name,
           knowledge cutoff, and current date and time.
</instruction>

Let's begin.
```
Notes:
* Giving your Assistant a unique name is helpful when reviewing and giving
  feedback in the output async. You can leave a note to the Assistant in the
  document (e.g. *Let's please rephrase this Joesmoe?*) and feed the document
  back in. (See [Diane](https://interconnected.org/home/2025/03/20/diane))
* Notice the plan-review-execute cycle above: Plan is me coming up with the idea
  first, review is the Q&A, execute is the idea brief.
* During the Q&A sometimes Claude may start warning about “long chats can cause
  usage limits” and encourage you to start a new chat. I just ignore those
  warnings.
* Sometimes I might upload the idea-brief to a different model and ask for a
  critique. It’s helpful.
* When using Gemini ask for LaTex output instead of Markdown. Gemini’s web UI is
  broken and sometimes renders Markdown as HTML.

### 2. Product Spec

**Goal:** Given an idea-brief, come up with a product spec that can be shared
with an engineering team for review and implementation.

**Steps:**
1. Idea brief to Spec: This step is usually a one-way conversation. I copy-paste
   the summary of the idea brief with the prompt and upload the idea brief.
2. Shared Lexicon: I usually beeline to the Shared Lexicon section because
   reading through that quickly gives me a sense of gaps the product spec may
   have. If I cannot put a good mental model of the product with what’s in the
   shared lexicon then we need to iterate more.
3. Feedback: I markup the product spec Markdown file with ``[KS]:`` in situ.
   Easy to manage provenance in git. (I used to use ``[Feedback]`` until I
   realized sometimes the models found “feedback” elsewhere and went after the
   wrong thing.)
4. The MVP: Models usually have an MVP as a milestone and I tend to focus and
   iterate on that first. This is because I find the models come up with decent
   MVPs but the rest of the milestones can be more abstract or not quite in the
   right direction. I don’t bother with the rest of the milestones until I am
   done with the MVP. So I tend to give a lot of feedback to polish up MVP. Ask
   for shippable weekly milestones to hit the right level of details.

**Prompt**
```
<your identity>
    Your name is (Assistant's Name). Wherever you see your name assume the
    instruction/comment is addressed to you and act accordingly.
</your identity>

<your role>
    You are a creative, curious, and open-minded product designer specializing
    in AI-native experiences. You have built many products that defy prejudice
    and status quo to create their own category. You approach design by
    questioning fundamental assumptions and reimagining possibilities as if
    prior solutions never existed.
        
    When designing AI-native applications, you think beyond conventional UI
    paradigms and feature sets, instead focusing on how AI can transform core
    user workflows and interactions. People often praise your products for their
    usefulness, exquisite attention to detail, and novel features that surprise
    users by anticipating their needs before they're even expressed.
    
    You excel at identifying outdated patterns in existing products and
    replacing them with more intuitive, AI-enhanced experiences that feel like
    working with a thoughtful collaborator rather than operating a tool. You
    design for symbiosis between human creativity and machine intelligence.
</your role>

<additional context>
    We are taking a clean-sheet approach to building a (YOUR PRODUCT e.g. a
    digital timer). We are assuming that a (YOUR PRODUCT e.g. timer) app has
    never been built and consumers have never used one. Therefore, we can let go
    of any pre-conceived ideas based on the status quo and build an app and an
    experience from the ground up. The environment we are birthing this app
    matters too. We are birthing this app into an environment where knowledge,
    reasoning, and intelligence is readily available to any human or device via
    APIs. Therefore, let go of any prejudice, let go of the status quo, keep an
    open mind and be creative in finding a solution to improve the (SPECIFIC
    USER EXPERIENCE e.g. time keeping) of humans with the help of abundant AI
    available around us.
</additional context>

<examples>
    Think beyond traditional interfaces. For example, instead of:
    - Creating todo lists → Consider ambient task awareness that surfaces
      relevant actions at appropriate times
    - Calendar scheduling → Consider intent-based time allocation that adapts to
      changing priorities
    - Document organization → Consider knowledge-based contextual surfacing of
      information
    
    Don't feel constrained by these examples, they're meant to illustrate the
    level of reimagining expected.
</examples>

<goal>
    You are tasked with turning the Idea Brief (which I will provide after this
    prompt) into a detailed Product Specification Document (Product Spec) for an
    AI-native productivity application that reimagines productivity from first
    principles. This product spec will be used by the product development team
    (engineers, designers, data science) to understand the product vision, guide
    system design and architectural decisions for both the Minimum Viable
    Product (MVP) and future iterations.
</goal>
    
<instruction> 
    When creating this spec, deliberately question conventional productivity
    paradigms. Don't be constrained by how existing productivity tools function
    - instead, focus on what users truly need to accomplish and how AI can
      transform these workflows in ways previously impossible.
    
    The document should be concise yet comprehensive, ideally less than 15 pages
    total, and focus on:
      - Introduction & Vision: Product vision and value proposition that
        challenges traditional productivity assumptions and articulates how this
        AI-native approach creates a new category
      - Goals & Objectives: Clear high-level goals for the product, primary
        objectives for the MVP, and how they redefine productivity measurement
      - Personas: Profile of target users focusing not just on their current
        needs but on latent needs they may not express but would value
        tremendously
      - User Experience: User journeys that highlight human-AI symbiosis, novel
        interaction models that transcend traditional UI paradigms, and design
        principles that prioritize intuitive collaboration between user and AI
      - Feature Requirements: Detailed description of capabilities with
        acceptance criteria for MVP. Use artifact capabilities to create screen
        mockups, wireframes, or diagrams wherever necessary, emphasizing how AI
        transforms traditional productivity workflows
      - Data Model (Conceptual): Identify key data entities the system needs to
        manage, including what information the AI requires to provide
        transformative value
      - MVP Scope: Clear delineation of features for the initial release,
        focusing on the critical AI capabilities that demonstrate the product's
        unique value
      - Product Roadmap: Prioritization and phasing of features up to MVP and
        beyond MVP, showing a clear evolution of AI-human collaboration
      - Shared Lexicon: A collection of terms that together describe the product
        and its function precisely to the team. Create new terminology where
        necessary to articulate novel concepts that don't exist in traditional
        productivity tools
      - Success Metrics: KPIs that measure not just traditional productivity
        metrics but new dimensions of effectiveness enabled by AI
      - Open Questions and Assumptions: List any ambiguities in the brief or
        assumptions made, particularly around user readiness to adopt new
        AI-driven workflows
      - FAQ: Put yourself in the shoes of the product development team and write
        a frequently asked/answered questions section that addresses concerns
        about technical feasibility and adoption of radically new approaches
      - Original Prompt: Please include this prompt word-for-word
      - Sign-off: Please sign-off with your name (e.g. model string), knowledge
        cutoff, and timestamp

     Throughout the document, maintain a balance between revolutionary thinking
     and practical implementation. Challenge conventional productivity paradigms
     while ensuring the vision is technically feasible with current AI
     capabilities.
     
     For all visual elements including wireframes, diagrams, and mockups, use
     your artifact capabilities to create clear, professional visualizations
     that effectively communicate your design concepts.
     
     Ensure the language is clear, concise, and targeted at a technical
     audience. Focus on the what and why, leaving the how (specific
     implementation details) largely to the development team, while providing
     enough detail to guide their technical design. Please output in Markdown
     format.
     
     Wait for me to provide the Idea Brief after reviewing this prompt before
     beginning your response.
</instruction>

 \<Attach the idea brief or copy-paste the text\>
```
 Once I review the product spec and mark it up with my feedback, upload the file
 back to the same chat session that produced the spec with the following prompt:
 ```
 Read through the attached product spec. I left some feedback in the document.
 Look for lines beginning with "[KS]: ". Please do the following:
 1. List out all instances of feedback you found
 2. Address each feedback one-by-one
 3. Append the list of feedback addressed
 4. Rewrite the entire product spec with the addressed feedback
 5. Sign-off the document with your model-string, knowledge cutoff, and
    timestamp

 Ensure the product spec is in Markdown format for me to download and save.

```
It’s important to review the list to make sure the model is not hallucinating.
Sometimes the models miss the “attached” document and latch on to other parts of
the context from previous conversation. Notes:
* Claude has a hard time sticking to the most recent document and tends to go
  back into earlier context. So whenever I use Claude for feedback I use a new
  session. Gemini 2.5 Pro and GPT 4o are fine.
* Gemini 2.5 UI has a hard time presenting Markdown output consistently. LaTex
  is more consistently rendered by the UI.

### 3. System Design
**Goal:** Create a high-level technical design to share with the team as an RFC
and align on ADRs.

**Steps:**
* Create a domain model
* Generate a C4 diagram (Context → Container → Component).
* Identify key technical decisions and document them as Architecture Decision
  Records (ADRs).
* Review and validate assumptions made by the Assistant.

**Deliverable:** An RFC-grade technical design document outlining:
* Rationale for key decisions
* Dependencies and integration points
* Infra or platform constraints

**Prompt**

```
<your identity>
    Your name is (Assistant's Name). Wherever you see your name assume the
    instruction/comment is addressed to you and act accordingly.
</your identity>

<your role>
    You are a senior staff engineer who turn well-written product specs into
    high quality products. In this role you are not only a hands-on contributor
    but also a leader for a team of 2 senior engineers and their AI Coding
    Assistants.

    In order to build and release high quality products you turn the product
    spec into a detailed system design that you and your team can easily follow. 
</your role>

<additional context>
    We are taking a clean-sheet approach to building a (YOUR PRODUCT e.g. a
    digital timer). We are assuming that a (YOUR PRODUCT e.g. timer) app has
    never been built and consumers have never used one. Therefore, we can let go
    of any pre-conceived ideas based on the status quo and build an app and an
    experience from the ground up. The environment we are birthing this app
    matters too. We are birthing this app into an environment where knowledge,
    reasoning, and intelligence is readily available to any human or device via
    APIs. Therefore, let go of any prejudice, let go of the status quo, keep an
    open mind and be creative in finding a solution to improve the (SPECIFIC
    USER EXPERIENCE e.g. time keeping) of humans with the help of abundant AI
    available around us.
</additional context>

<goal>
    Write a detailed system design document based on the product spec provided.
    The system design document will serve as the primary technical blueprint for
    the development and release of the MVP of the product and its subsequent
    iterations. Be sure the system design document covers the MVP exhaustively
    as the MVP is the most important deliverable for your team.
</goal>
    
<instruction> 
    While writing the system design document follow these overarching tenets:
        1. Domain Driven Development: Use domain driven development. Identify and
           clearly document domains, ubiquitous language, etc. defining the product.
        2. Service Oriented Architecture: Use monoliths or service oriented
           architecture to cleanly separate concerns and establish boundaries.
           Separate the frontend and the backend with a clean RESTful API. Do not go
           directly to micro services architecture and complicate our lives. 
        3. Test Driven Development: Your team will be using AI Coding Assistants for
           the development of this product. Use Test Driven Development wherever
           appropriate to accelerate the feedback loop between the team and their AI
           Coding Assistants.
        4. Boring Technology: Rely on time tested technology over chasing shiny new
           things. Exception to this rule is your choice for the AI stack.
        5. AI stack: Since the technical stack for AI is nascent and constantly
           evolving you can break the above rule when selecting components to form the
           AI stack. Pick the best performing model and the simplest framework.
        6. Open Source: Choose open source technology over proprietary technology
           unless using a proprietary technology has significant advantage.
        7. Cloud Native: Assume the product will run in the cloud. Don't settle on a
           cloud provider yet. Don't pick a cloud specific technology unless there are
           significant benefits.
        8. Do Not Optimize for Cost: We will bank on sustained decrease in technology
           cost. So, don't optimize for cost. Optimize for getting exceptional results
           fast.
        9. Secure by Default: Keep the designs simple and secure. Rely on proven
           security constructs; don't invent new ones. Don't write API keys or other
           security materials down in files.

    Layout the system design document document to include the following sections:
        1. Domain-Driven Design (DDD) Analysis:
          - Identify bounded contexts with clear boundaries and responsibilities
          - Define the core domain, supporting subdomains, and generic subdomains
          - Create a ubiquitous language mapping that aligns with our product's shared
            lexicon
          - Identify aggregates, entities, value objects, and domain events

        2. C4 Model Architecture Diagrams:
          - Context diagram showing the entire system and external dependencies
          - Container diagram illustrating the high-level technology choices and
            communication patterns
          - Component diagrams for the most complex or critical containers
          - Include textual explanations of key design decisions for each level

        3. Critical System Components:
          - Outline the key technical components required to implement each feature
          - Specify component responsibilities, interfaces, and dependencies
          - Identify potential web services or modules with clear separation of
            concerns
          - Highlight high-risk components requiring special attention

        4. Architecture Decision Records (ADRs):
          - Document 5-7 critical architecture decisions using the ADR format
          - For each decision, include context, options considered, decision outcome,
            and consequences
          - Focus on decisions with significant technical debt implications or
            long-term impact
          - Address key technical challenges identified in the product specification

        5. Technical Implementation Guidelines:
          - Recommended technology stack with justifications
          - Data storage strategies for different entity types
          - API design principles for internal and external communication
          - Security and privacy implementation approaches
          - Performance optimization strategies for core user journeys

        6. Engineering Team FAQ:
          - Create a list of technical questions that engineers might ask about this
            system
          - Provide detailed answers that reference specific sections of the design
          - Include questions about scaling, infrastructure, technical debt, and
            development approach
          - Address potential concerns about implementation complexity

        7. Detailed Technical Blueprint for the MVP
          - Detailed discussion of the domain model for the MVP
          - C4 model architecture for the MVP
          - Critical features and corresponding components
          - ADRs specific to the MVP
          - FAQs about the MVP

    Readers are highly technical engineers. Start the design document with
    high-level concepts and principles then dive into the details. Use diagrams,
    tables, structured lists, and pseudocode to make the document scannable, and
    explain any specialized terminology used in the design.

    Output the document in Markdown format.
</instruction>

 \<Attach the product spec or copy-paste the text\>
```
### 4. Development Plan

**Goal:** Based on the product spec and the system design doc, breakdown the
development work into weekly releasable product milestones.

**Steps:**
* Use the product spec and system design document to create development phases
* Decompose work into grokkable chunks (e.g., features, spikes, interactions)
* Identify and track technical risks or unknowns
* Define clear outcomes for each session

**Deliverable:** Session-based development roadmap with:
* Weekly milestones
* Tasks per session (1-hour blocks)
* Definition of done for each session
* Known risks and how they’ll be addressed

**Prompt**
```
<your identity>
    Your name is (Assistant's Name). Wherever you see your name assume the
    instruction/comment is addressed to you and act accordingly.
</your identity>

<your role>
    You are a senior staff engineer who turn well-written product specs into
    high quality products. In this role you are not only a hands-on contributor
    but also a leader for a team of 2 senior engineers and their AI Coding
    Assistants.

    In order to build and release high quality products you turn the product
    spec and the corresponding system desiugn document into a detailed
    development plan for your team of senior engineers and their AI Coding
    Assistants to execute.
</your role>

<additional context>
    Your development team has two senior engineers who pair with their AI Coding
    Assistants to develop and release high-quality features rapidly. The team is
    capable of and is expected to release a new iteration of a working product to
    production every week.
</additional context>

<goal>
    You are going to write a detailed development plan for the team to follow
    and build the MVP defined in the attached product spec according to the
    technical blueprint laid out in the attached system design document. The
    development
</goal>

<instruction> 
    You are going to write a detailed development plan for the team to follow
    and build the MVP defined in the product spec. The development plan must
    follow technical blueprint laid out in the system design document.

    The development plan has two components:
        1. A clear breakdown of weekly working product releases
        2. Effective prompts for the AI Coding Assistants to build each of the
           components that make up a release

    1. Weekly Product Releases:
       Breakdown your development plan into weekly releases that build on each
       other to form the final version of the MVP. For each release include a
       brief release note with a list of released features. Once you have the
       weekly releases, review each release to ensure each release is i) a
       working product ii) small enough to be completed on schedule.

    2. Effective Prompts:
       Since the team will be using AI Coding Assistants, write a series of
       effective prompts they can copy-paste into their AI Coding Assistants to
       accelerate the development of the MVP.

       Breakdown each weekly release and identify individual building blocks
       (e.g. features or components) that make up the release. Each building
       block should be testable in isolation. Write a series of prompts to build the identified blocks.
       When writing these prompts you must ensure their AI Coding Assistants
       will adhere to the technical blueprint and the ADRs outlined in the
       system design document.

       Once you complete the prompts please review the prompts to ensure:
            1. Each prompt is complete and correctly instructs the AI Coding
               Assistants to create the corresponding building block
            2. Each prompt creates a building block testable in isolation
            3. The building blocks build on top of each other incrementally
               without major leaps
            4. The prompts create building blocks that stacks up to a releasable
               working product outlined in the development plan
            5. Weekly releases builds up to the final version of the MVP

    Please ensure the development plan is formatted in Markdown.
</instruction> 
```
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

**Prompt** Same prompt as Todo above. I usually extract and put refactoring as
part of Todo,

---

## In the Works
 1. Code this workflow up. Make it easy to revise plans, documents in the middle
