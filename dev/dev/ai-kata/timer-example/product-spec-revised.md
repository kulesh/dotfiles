# Product Specification Document: AI-Native Timer

## Introduction & Vision

The AI-Native Timer reimagines timers for the AI era. Rather than forcing users to manually configure timers with specific durations and steps, this application leverages natural language understanding and contextual intelligence to create a frictionless timing experience.

Our vision is to create a timer that feels like a knowledgeable assistant rather than a mechanical stopwatch. Users simply express their timing needs in natural language, and the app intelligently builds, adjusts, runs, and logs the appropriate sequences. The app quietly leverages contextual data (location, eventually health data) while staying invisible unless the user wants to understand what's happening beneath the surface.

The product's core value proposition is:
- **Zero mental overhead** – speak the goal, not the math
- **Context-smart** – silent contextual adjustments for perfect results without thinking
- **Habit intelligence** – streak and variance stats to surface consistency at a glance
- **Own it forever** – one-time purchase unlocks unlimited functionality across devices

## Goals & Objectives

### Primary Goals
1. Create a timer application that reduces cognitive load through natural language understanding
2. Leverage contextual intelligence to improve timer accuracy without user configuration
3. Support complex multi-step routines that previously required mental math or multiple timers
4. Enable habit formation through intelligent logging and streak tracking
5. Provide a business model that prioritizes user value over recurring revenue

### MVP Objectives
1. Deliver core voice-driven timer creation and management
2. Implement free-form routine authoring with name suggestions
3. Build a minimalist visual interface with drag-to-set clock and swipe gestures
4. Integrate location-based adjustments for common activities
5. Create on-device logging and history visualization
6. Implement stacked timer visualization with simple controls
7. Launch with a clear free tier and one-time purchase upgrade path
8. Laser focus on iOS platform first to deliver an exceptional experience before expanding to other platforms

## Personas

### 1. The Focused Achiever
**Name:** Alex  
**Occupation:** Product manager at a tech company  
**Key Needs:**
- Structured work sessions using Pomodoro technique
- Minimal friction when switching between tasks
- Ability to track productivity patterns over time

**How AI-Native Timer Helps:**
- One-command setup of complex work sprints
- Automatic naming and logging of sessions
- Streak tracking to reinforce daily habits

### 2. The Workout Enthusiast  
**Name:** Jordan  
**Occupation:** Fitness instructor  
**Key Needs:**
- Complex interval training routines (HIIT, Tabata, etc.)
- Location-aware workout timing (altitude adjustments)
- Ability to share routines with clients

**How AI-Native Timer Helps:**
- Understands workout terminology ("Start a Tabata 8×20/10")
- Automatically adjusts intensity based on location
- Creates shareable templates for clients

### 3. The Busy Parent
**Name:** Taylor  
**Occupation:** Parent of two young children  
**Key Needs:**
- Managing household routines on schedule
- Handling multiple overlapping activities
- Quick adjustments amid chaos

**How AI-Native Timer Helps:**
- Creates and schedules complex routines like bedtime sequences
- Manages overlapping timers for multiple children
- Allows quick voice modifications without disrupting flow

## User Experience

### Core Interaction Principles
1. **Voice-First Design:** Almost every interaction should be possible through natural language.
2. **Invisible Intelligence:** Contextual adjustments happen silently but can be explained on demand.
3. **Minimal Visual Interface:** Clean, distraction-free UI that appears only when needed.
4. **Consistent Feedback:** Clear visual and audio cues for timer states and transitions.

### Key User Journeys

#### Journey 1: First-Time Setup
1. User downloads and opens app
2. Brief onboarding explains voice-first approach
3. App requests necessary permissions (microphone, location)
4. User is prompted to try creating their first timer with examples
5. Timer creation success triggers explanation of available actions
6. Optional walkthrough of visual interface elements

#### Journey 2: Creating a New Routine
1. User initiates creation via voice: "Create a new workout routine"
2. System prompts for details: "What would you like to call it, or tell me what it involves?"
3. User provides free-form description: "It's a warm-up for 5 minutes, then 4 rounds of 45 seconds intense with 15 seconds rest, and a 3-minute cooldown"
4. System parses and displays the interpreted sequence with suggested name
5. User confirms or adjusts via voice or touch
6. System saves routine and offers to start or schedule

#### Journey 3: Running Multiple Timers
1. User starts first timer via voice
2. User starts second timer while first is running
3. Interface shows stacked rings with distinct colors
4. Voice announcements include timer name for clarity
5. User can pause/resume/stop individual timers via voice or tap
6. Session completes and is logged automatically

### Wireframes

**Home Screen**  

```
┌────────────────────────────────────────┐
│                                        │
│              AI Timer                  │
│                                        │
│    ┌──────────────────────────────┐    │
│    │                              │    │
│    │        [ Clock Face ]        │    │
│    │           12:00:00           │    │
│    │         Drag to Set          │    │
│    │                              │    │
│    └──────────────────────────────┘    │
│                                        │
│    ┌──────────────────────────────┐    │
│    │    Recent Routines           │    │
│    │ ┌────────┐ ┌────────┐        │    │
│    │ │Workout │ │Pomodoro│   >>   │    │
│    │ │25m HIIT│ │25/5 min│        │    │
│    │ └────────┘ └────────┘        │    │
│    └──────────────────────────────┘    │
│                                        │
│              [ 🎤 ]                    │
│          Tap to speak                  │
│                                        │
└────────────────────────────────────────┘
```

The home screen features:
- Large microphone button for voice input
- Recent/favorite routines as swipeable cards
- Minimalist clock drag interface for silent setup
- Access to current active timers

**Timer Creation Flow**  

```
┌────────────────────────────────────────┐
│                                        │
│          Create New Routine            │
│                                        │
│    ┌──────────────────────────────┐    │
│    │     "Create a HIIT workout   │    │
│    │      with 30 second rounds   │    │
│    │      and 10 second rests     │    │
│    │      for 10 minutes"         │    │
│    │                              │    │
│    │      [ ▶ ⏺ ⏹ ]               │    │
│    └──────────────────────────────┘    │
│                                        │
│    ┌──────────────────────────────┐    │
│    │ Suggested: "10min HIIT 30/10"│    │
│    │                              │    │
│    │ ┌──────┐┌──────┐┌──────┐     │    │
│    │ │Warm-up││Round ││Rest  │     │    │
│    │ │1:00   ││00:30 ││00:10 │× 10 │    │
│    │ └──────┘└──────┘└──────┘     │    │
│    │                              │    │
│    │  [Edit] [Save] [Start Now]   │    │
│    └──────────────────────────────┘    │
│                                        │
└────────────────────────────────────────┘
```

The timer creation flow includes:
- Voice input visualization (text representation)
- Real-time parsing display
- Suggested routine name
- Editable sequence visualization
- Save/start/schedule options

**Active Timer View**  

```
┌────────────────────────────────────────┐
│                                        │
│             Active Timers              │
│                                        │
│    ┌──────────────────────────────┐    │
│    │         ┌─────────┐          │    │
│    │       ┌─┘         └─┐        │    │
│    │      /               \       │    │
│    │     |     3:45        |      │    │
│    │     |    WARM-UP      |      │    │
│    │      \               /       │    │
│    │       └─┐         ┌─┘        │    │
│    │         └─────────┘          │    │
│    │                              │    │
│    │   Next: Round 1 - 00:30      │    │
│    │                              │    │
│    │   [⏸] [⏭] [⏹]                │    │
│    └──────────────────────────────┘    │
│                                        │
│    ┌──────────────────────────────┐    │
│    │ Other Active:                │    │
│    │ Cooking Timer - 12:31        │    │
│    └──────────────────────────────┘    │
│                                        │
└────────────────────────────────────────┘
```

The active timer view includes:
- Concentric progress rings for multiple timers
- Current phase name and remaining time
- Upcoming phase preview
- Quick action buttons (pause/skip/stop)
- List of other active timers

**History & Logging View**  

```
┌────────────────────────────────────────┐
│                                        │
│              Timer History             │
│                                        │
│    ┌──────────────────────────────┐    │
│    │ April 2025                   │    │
│    │ M T W T F S S                │    │
│    │ ░ ▒ ▒ ▒ ░ ░ ░   < Week 1 >   │    │
│    │ ░ ▒ █ █ █ ▒ ░   < Week 2 >   │    │
│    │ ▒ █ █ █ █ ▒ ░   < Week 3 >   │    │
│    │ ░ ▒ █ ▒ ░ ░ ░   < Week 4 >   │    │
│    │                              │    │
│    │ Current streak: 12 days      │    │
│    └──────────────────────────────┘    │
│                                        │
│    ┌──────────────────────────────┐    │
│    │ Recent Sessions:             │    │
│    │ > HIIT Workout - Today 9:15am│    │
│    │ > Pomodoro - Today 11:45am   │    │
│    │ > Cooking - Yesterday 6:30pm │    │
│    │                              │    │
│    │ [Filter] [Search] [Export]   │    │
│    └──────────────────────────────┘    │
│                                        │
└────────────────────────────────────────┘
```

The history view includes:
- Calendar heatmap showing activity
- Routine-specific streak visualization
- Completion time variance graphs
- Detailed session list with timestamps
- Filter/search capabilities

## Feature Requirements

### 1. Voice Understanding & Natural Language Processing

#### Functionality
- Parse free-form voice descriptions into structured timer sequences
- Understand common timing terminology (Pomodoro, Tabata, HIIT, etc.)
- Support modification of existing timers via voice
- Enable voice control during timer execution (pause, skip, extend, etc.)

#### Acceptance Criteria
- System correctly interprets 95% of clear voice commands for supported use cases
- Timer creation from voice input completes in under 3 seconds
- Voice commands work in moderately noisy environments
- System provides clear error feedback when unable to parse input

### 2. Routine Creation & Management

#### Functionality
- Support multi-step sequences with variable durations
- Auto-suggest appropriate names for new routines
- Enable editing/customization of saved routines
- Organize routines into categories (Workouts, Cooking, Productivity, etc.)

#### Acceptance Criteria
- Unlimited ad-hoc timer creation in free tier
- One saved routine allowed in free tier
- Unlimited saved routines in paid tier
- Routines synchronize across user's devices

### 3. Contextual Intelligence

#### Functionality
- Adjust cooking times based on altitude/location
- Recognize and apply standard timing formulas for common activities
- Provide explanations for adjustments when requested
- Learn from user behavior over time (future enhancement)

#### Acceptance Criteria
- System accurately calculates altitude-based adjustments
- Knowledge base covers at least 50 common timed activities
- Explanations are clear and technically accurate
- Adjustments happen automatically without user configuration

### 4. Multiple Timer Management

#### Functionality
- Run multiple timers concurrently
- Visualize overlapping timers distinctly
- Provide clear audio and visual cues for each timer
- Allow individual control of each active timer

#### Acceptance Criteria
- Support for at least 5 simultaneous timers
- Each timer clearly identifiable by name and visual cue
- Voice commands can target specific timers by name
- Performance impact is minimal on device resources

### 5. Session Logging & Analytics

#### Functionality
- Automatically log all completed timer sessions
- Track streaks for routine adherence
- Visualize variance in completion times
- Support filtering and searching of session history

#### Acceptance Criteria
- All logs stored locally on device
- Data syncs across devices via native services (iCloud)
- History view loads within 1 second for up to 1 year of data
- Export functionality for personal data

### 6. Scheduling & Automation

#### Functionality
- Schedule routines for automatic start
- Set recurring schedules (daily, weekdays, etc.)
- Receive notifications before scheduled starts
- Enable/disable scheduled routines easily

#### Acceptance Criteria
- Reliable scheduled starts (>99% accuracy)
- Intuitive schedule creation interface
- Clear visualization of upcoming scheduled timers
- Quick toggle to enable/disable without deletion

### 7. Sharing & Collaboration

#### Functionality
- Share routine templates via system share sheet
- Import shared routines
- Optionally include anonymized performance data
- Future: community template library (post-MVP)

#### Acceptance Criteria
- Generated share files are compact (<10KB)
- Shared routines maintain all sequence data
- Import process requires minimal steps
- Privacy controls clearly explained

## Data Model (Conceptual)

### Core Entities

**User**
- DeviceID
- PurchaseStatus (Free/Paid)
- Preferences
- Created date

**Routine**
- RoutineID
- Name
- Description
- Category
- Phases (array of Phase objects)
- CreatedDate
- ModifiedDate
- Creator (User)

**Phase**
- PhaseID
- Name
- Duration (base)
- Adjustment rules
- Position in sequence
- RepeatCount

**Timer**
- TimerID
- RoutineID (reference)
- Status (idle, running, paused, completed)
- StartTime
- CurrentPhase
- ElapsedTime
- RemainingTime

**Session**
- SessionID
- RoutineID (reference)
- StartTime
- CompletionTime
- CompletionStatus (completed, partial, abandoned)
- PhaseLog (array of completed phases with actual durations)
- ContextualFactors (location, altitude, etc.)

**Schedule**
- ScheduleID
- RoutineID (reference)
- RecurrencePattern
- StartTime
- Enabled status
- NotificationSettings

### Relationships
- User creates many Routines
- Routine contains many Phases
- Routine is used by many Timers
- Timer generates one Session per execution
- Routine can have many Schedules

## MVP Scope

### Features Included in MVP

**Core Experience**
- ✅ Voice-driven timer creation and control
- ✅ Free-form routine authoring with AI name suggestion
- ✅ Minimalist visual interface with drag-to-set clock
- ✅ Multiple timer visualization (stacked rings)
- ✅ Voice and tap controls for timer management

**Intelligence & Context**
- ✅ Altitude/location-based adjustments for common activities
- ✅ Knowledge base of standard timing formulas
- ✅ Explanation capability for adjustments

**Management & Organization**
- ✅ On-device session logging and history
- ✅ Basic streak and variance visualization
- ✅ Simple routine organization
- ✅ One saved routine in free tier

**Monetization**
- ✅ Clear free vs. paid feature differentiation
- ✅ One-time in-app purchase ($3-4)
- ✅ Cross-device unlock via Apple account

**Platform**
- ✅ iOS-only for initial release

### Features Reserved for Post-MVP

**Advanced Intelligence**
- ❌ Health-metric adjustments (heart rate, body temp)
- ❌ Learning from usage patterns
- ❌ Smart coaching tips and suggestions

**Community & Sharing**
- ❌ Community template library
- ❌ Rating and discovery of shared routines
- ❌ Advanced template customization

**Integration & Export**
- ❌ Integration with health platforms (Strava, HealthKit)
- ❌ Advanced data export and visualization
- ❌ API for third-party integration

**Advanced Input & Control**
- ❌ Wearable-only standalone mode
- ❌ Spatial gesture control
- ❌ Advanced voice model customization

**Platform Expansion**
- ❌ Android support
- ❌ Web interface

## Product Roadmap

### Phase 1: MVP Development (3 months)
- Week 1-2: Core architecture and data model implementation for iOS
- Week 3-4: Basic voice understanding pipeline with cloud-based LLM integration
- Week 5-6: Timer engine and visualization
- Week 7-8: Contextual adjustments and knowledge base
- Week 9-10: Session logging and history views
- Week 11: Monetization implementation
- Week 12: Testing, bug fixes, and polish

### Phase 2: First Enhancement (2 months post-launch)
- Enhanced sharing capabilities
- Basic community template library
- Expanded knowledge base with decoupled update mechanism
- Performance optimizations
- User feedback implementation

### Phase 3: Platform Expansion (3 months post-Phase 2)
- Apple Watch companion app
- Widget support for iOS
- Android development begins
- Basic health metric integration
- Advanced visualization of habits and trends

### Phase 4: Intelligence Evolution (4 months post-Phase 3)
- Local LLM integration (reducing cloud dependency)
- Smart coaching based on usage patterns
- Advanced contextual intelligence
- Dynamic routine adjustments
- Expanded integration options

## Shared Lexicon

**Routine**
A saved sequence of timed phases that can be executed as a unit

**Phase**
A single timed segment within a routine with a specific duration and purpose

**Ad-hoc Timer**
A timer created for immediate use without being saved as a routine

**Contextual Adjustment**
Automatic modification of timer duration based on environmental factors

**Knowledge Base**
Curated information about standard timing formulas for common activities

**Streak**
Consecutive days/sessions where a routine was completed successfully

**Variance**
Statistical measure of how consistent completion times are for a routine

**Session**
A single execution instance of a routine, logged with start/end times

**Schedule**
A recurring or one-time future automatic execution of a routine

**Stacked Rings**
Visual representation of multiple concurrent timers as concentric circles

**LLM (Large Language Model)**
AI model used to process natural language input and convert goals to specific timer durations

## Success Metrics

### User Engagement
- DAU/MAU ratio > 40% (indicating strong recurring usage)
- Average routines created per user > 3
- Voice command utilization > 80% of total interactions
- Session completion rate > 75%

### Business Performance
- Free-to-paid conversion rate > 15%
- User retention: 60% at 30 days, 40% at 90 days
- Positive App Store rating > 4.5 stars
- Word-of-mouth referrals > 20% of new users

### Technical Performance
- Voice recognition accuracy > 95%
- App load time < 2 seconds
- Battery impact < 5% for typical daily usage
- Crash-free sessions > 99.5%

### Product Satisfaction
- Context adjustment usefulness rating > 4/5
- Voice interaction satisfaction > 4/5
- Feature discoverability score > 4/5
- "Would recommend" score > 8/10

## Open Questions and Assumptions

### Open Questions
1. **Privacy vs. Functionality**: How do we balance offline processing (privacy) with the need for advanced voice understanding that currently requires cloud-based LLMs?
2. **Knowledge Base Evolution**: What's the best approach to expanding the knowledge base over time and eventually decoupling it from app updates?
3. **Context Permissions**: How aggressively should we request location/health permissions that enable contextual intelligence?
4. **Voice Feedback**: What's the right balance of voice feedback to avoid both confusion and annoyance?
5. **Platform Extensions**: Should we prioritize watch extensions before or after core enhancements?
6. **LLM Costs**: How do we optimize cloud LLM usage to maintain reasonable operating costs?

### Assumptions
1. Users will overwhelmingly prefer voice input for timer creation when available
2. Contextual adjustments will provide meaningful value across our target use cases
3. A one-time purchase model will be sustainable with potential need for subscription options if local LLMs remain unavailable
4. Local-first data approach with iCloud sync will satisfy privacy concerns
5. Current iOS voice recognition capabilities paired with cloud-based LLMs are sufficient for our MVP needs
6. On-device LLMs will become more capable and accessible within the next 1-2 years

## FAQ

### General Product Questions
**Q: How does this differ from saying "Set a timer for 5 minutes" to Siri/Google Assistant?**  
A: Unlike simple voice assistants, our app understands the goal behind the timer. For example, instead of saying "Set a timer for 6 minutes" to boil an egg, the user says "Set a timer to boil an egg" and the app automatically sets the appropriate time based on their location (e.g., 6 minutes in New York vs. 7 minutes in Denver due to altitude differences). The app also understands complex sequences, manages multiple timers elegantly, and builds a personal history of your routines.

**Q: What happens if the user is in a situation where voice input isn't appropriate?**  
A: The app includes a minimal visual interface with a drag-to-set clock and favorite routines accessible via swipe gestures.

**Q: Can the app function fully offline?**  
A: For the MVP, we'll require internet connectivity for natural language processing, as we'll be using cloud-based LLMs to convert goals (e.g., "Timer for soft-boiled eggs") to specific timer durations (e.g., "set timer to 6 minutes"). Core timer functionality will work offline once timers are created, and in future versions, we aim to transition to on-device LLMs that would enable fully offline operation.

### Technical Implementation Questions
**Q: How do we ensure accurate voice understanding without sending data to the cloud?**  
A: For the MVP, we'll rely on cloud-based LLMs for natural language understanding, with appropriate privacy controls. Future iterations will shift toward more local LLMs as on-device models become more capable, gradually reducing cloud dependency.

**Q: What's the approach to handling device background states?**  
A: We'll use local notifications for timer completions when backgrounded, with optional awakening for critical phase transitions.

**Q: How will the knowledge base be structured and updated?**  
A: The knowledge base will be a versioned local database with periodic silent updates through the app update mechanism for MVP. Later releases will decouple app updates from knowledge updates to allow for more frequent knowledge base enhancements.

### Business Model Questions
**Q: Why limit free tier to one saved routine instead of time-limiting features?**  
A: This approach delivers real value while creating a natural upgrade moment. It avoids the typical "trial" feeling that leads to abandonment.

**Q: Are there plans for subscription features in the future?**  
A: The primary business model is designed around one-time purchases. Future specialized packs may be sold separately, but core functionality will remain subscription-free. The only caveat to this is the availability of capable local models. If we continue to rely on cloud-based LLMs, we may need to introduce subscription options to cover the ongoing costs of remote model usage on users' behalf.

**Q: How will feature parity be maintained across iOS and Android?**  
A: We will start with iOS for MVP to focus our resources on delivering an exceptional experience on a single platform first. Once the iOS version is stable and successful, we'll develop Android support with a core feature set that works identically across both platforms, with platform-specific optimizations for voice and background handling.

## Original Prompt

You are an experienced product manager. You are tasked with turning the attached Idea Brief into a detailed Product Specification Document (Product Spec). This product spec will be used by the product development team (engineers, designers, data science) to understand the product vision, guide system design and architectural decisions for both the Minimum Viable Product (MVP) and future iterations. Therefore, the document should focus on:
* Introduction & Vision: Product vision and value proposition to align the team
* Goals & Objectives: Clear high-level goals for the product, primary objectives for the MVP
* Personas: Profile of target users; focusing on their needs and how the product and MVP will meet those needs
* User Experience: User journeys, interaction models, interface requirements, and any design principles drawn from the idea brief
* Feature Requirements: Detailed description of capabilities with acceptance criteria for MVP. Please feel free to use screen mocks and wireframes to communicate UX clearly.
* Data Model (Conceptual): Identify key data entities the system needs to manage or user personas interact with
* MVP Scope: Clear delineation of features for the initial release
* Product Roadmap: Prioritization and phasing of features up to MVP and beyond MVP
* Shared Lexicon: A collection of terms that together describe the product and its function precisely to the team. Each term unequivocally communicates a specific concept to the team; and together a set of terms help form precise mental models about the product.
* Success Metrics: KPIs to measure product effectiveness
* Open Questions and Assumptions: List any ambiguities in the brief or assumptions made
* FAQ: Put yourself in the shoes of the product development team and write a frequently asked/answered questions section
* Original Prompt: Please include this prompt word-for-word
* Sign-off: Please sign-off with your name (e.g. model string), knowledge cutoff, and timestamp
Ensure the language is clear, concise, and targeted at a technical audience. Focus on the what and why, leaving the how (specific implementation details) largely to the development team, while providing enough detail to guide their technical design. Please make sure output is in Markdown format.

## Sign-off
Claude 3.7 Sonnet  
Knowledge cutoff: October 2024  
Saturday, May 03, 2025, 11:45 AM
