# AI-Native Timer System Design Document

## Executive Summary

This document outlines the system design for the AI-Native Timer application as specified in the product specification. The design focuses on creating a voice-first, context-aware timer system that leverages natural language processing to reduce cognitive load for users. This document serves as the technical blueprint for the development team to implement the MVP and subsequent iterations.

The architecture follows domain-driven design principles with a service-oriented approach, emphasizing clean separation of concerns while maintaining a monolithic structure for the MVP. The system leverages modern AI capabilities for natural language understanding while keeping the rest of the technology stack pragmatic and proven.

## 1. Domain-Driven Design (DDD) Analysis

### Bounded Contexts

![Bounded Contexts Diagram](https://via.placeholder.com/800x500)

| Bounded Context | Description | Key Responsibilities |
|----------------|-------------|----------------------|
| **Timer Core** | Central domain handling timer creation and execution | Timer engine, phase transitions, timer state management |
| **Voice Processing** | Handles voice input and natural language understanding | Speech recognition, intent parsing, command execution |
| **Routine Management** | Manages saved timer routines | Routine creation, editing, organization, templates |
| **Contextual Intelligence** | Provides smart adjustments based on environment | Location processing, knowledge base queries, adjustment calculation |
| **Session Analytics** | Records and analyzes timer usage | History logging, streak tracking, visualization |
| **User Management** | Handles user data and preferences | User profiles, purchase status, preferences |

### Core Domain and Subdomains

- **Core Domain**: Timer Core + Voice Processing
  - These represent our key competitive advantage and differentiation
  
- **Supporting Subdomains**:
  - Routine Management
  - Contextual Intelligence  
  - Session Analytics
  
- **Generic Subdomains**:
  - User Management
  - Scheduling
  - Sharing

### Ubiquitous Language

| Term | Definition | Technical Implementation |
|------|------------|--------------------------|
| Routine | A saved sequence of timed phases | `Routine` entity with metadata and collection of phases |
| Phase | Single timed segment within a routine | `Phase` entity with duration and position properties |
| Ad-hoc Timer | Timer created for immediate use | Temporary `Timer` instance without persistent routine |
| Contextual Adjustment | Duration modification based on environment | Function that transforms base duration using environmental data |
| Knowledge Base | Curated timing formulas | Structured database of activities and adjustment rules |
| Streak | Consecutive days with completed routines | Calculated property derived from session history |
| Variance | Consistency measure of completion times | Statistical function over session durations |
| Session | Single execution instance of a routine | `Session` entity with timestamps and completion data |
| Schedule | Future automatic execution plan | `Schedule` entity with recurrence and notification rules |
| Stacked Rings | Visual for multiple concurrent timers | UI component with concentric progress indicators |

### Domain Model

#### Aggregates and Entities

![Domain Model](https://via.placeholder.com/800x500)

**User Aggregate**
- `User` (root entity)
  - UserID (identifier)
  - PurchaseStatus (free/paid)
  - Preferences (settings)

**Routine Aggregate**
- `Routine` (root entity)
  - RoutineID (identifier)
  - Name, Description, Category
  - Collection of `Phase` entities
  - Created/Modified dates

**Timer Execution Aggregate**
- `Timer` (root entity)
  - TimerID (identifier)  
  - Reference to Routine
  - Current state (running, paused, completed)
  - StartTime, ElapsedTime, RemainingTime
  - CurrentPhase reference

**Session History Aggregate**
- `Session` (root entity)
  - SessionID (identifier)
  - Reference to Routine
  - StartTime, CompletionTime
  - CompletionStatus
  - Collection of completed phases with actual durations
  - ContextualFactors applied

**Schedule Aggregate**
- `Schedule` (root entity)
  - ScheduleID (identifier)
  - Reference to Routine
  - RecurrencePattern
  - Enabled status
  - Notification settings

#### Value Objects

- `Duration`: Immutable representation of time spans
- `Location`: Geographical position with altitude
- `AdjustmentFactor`: Percentage modifier with explanation
- `RoutineTemplate`: Shareable routine definition without user data
- `TimerState`: Enum representing possible timer states

#### Domain Events

- `RoutineCreated`: Triggered when a new routine is saved
- `TimerStarted`: Marks the beginning of timer execution
- `PhaseTransition`: Signals a change from one phase to another
- `TimerCompleted`: Marks the successful completion of all phases
- `AdjustmentApplied`: Records the application of a contextual adjustment
- `SessionRecorded`: Confirms the logging of a completed session

## 2. C4 Model Architecture Diagrams

### Context Diagram

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│                     AI-Native Timer                     │
│                                                         │
└───────────────────────────┬─────────────────────────────┘
                            │
           ┌───────────────┴────────────────┐
           │                                │
           ▼                                ▼
┌─────────────────────┐          ┌─────────────────────┐
│                     │          │                     │
│       Users         │          │   LLM Services      │
│                     │          │                     │
└─────────────────────┘          └─────────────────────┘
           │                                │
           │               ┌────────────────┘
           │               │
           ▼               ▼
┌─────────────────────┐  ┌─────────────────────┐
│                     │  │                     │
│  Location Services  │  │   Apple Services    │
│                     │  │   (iCloud, Store)   │
└─────────────────────┘  └─────────────────────┘
```

The AI-Native Timer system interfaces with:

- **Users**: Through iOS mobile application with voice and touch interfaces
- **LLM Services**: Cloud-based language model for natural language understanding
- **Location Services**: For altitude and geographical context data
- **Apple Services**: For iCloud synchronization and in-app purchases

### Container Diagram

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│                               AI-Native Timer System                         │
│                                                                              │
│  ┌────────────────────────────┐       ┌─────────────────────────────────┐   │
│  │                            │       │                                 │   │
│  │    iOS Mobile Application  │◄─────►│   Natural Language Processor    │   │
│  │    (Swift/SwiftUI)         │       │   (Transformer-based LLM)       │   │
│  │                            │       │                                 │   │
│  └───────────┬────────────────┘       └─────────────────────────────────┘   │
│              │                                                               │
│              │                                                               │
│              ▼                                                               │
│  ┌────────────────────────────┐       ┌─────────────────────────────────┐   │
│  │                            │       │                                 │   │
│  │    Local Data Storage      │◄─────►│   Knowledge Base Service        │   │
│  │    (Core Data/SQLite)      │       │   (Versioned JSON/SQLite)       │   │
│  │                            │       │                                 │   │
│  └────────────────────────────┘       └─────────────────────────────────┘   │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

The AI-Native Timer system consists of:

1. **iOS Mobile Application**: The primary user interface built with Swift/SwiftUI
2. **Natural Language Processor**: Handles voice input interpretation using transformer-based LLM
3. **Local Data Storage**: Manages user data, routines, and sessions using Core Data/SQLite
4. **Knowledge Base Service**: Provides contextual adjustment data and formulas

### Component Diagram (iOS Mobile Application)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│                          iOS Mobile Application                              │
│                                                                              │
│  ┌────────────────────────┐   ┌────────────────────────┐                    │
│  │                        │   │                        │                    │
│  │   Voice Processing     │   │   Timer Engine         │                    │
│  │   Component            │◄─►│   Component            │                    │
│  │                        │   │                        │                    │
│  └──────────┬─────────────┘   └──────────┬─────────────┘                    │
│             │                            │                                   │
│             ▼                            ▼                                   │
│  ┌────────────────────────┐   ┌────────────────────────┐                    │
│  │                        │   │                        │                    │
│  │   Routine Management   │   │   Session Analytics    │                    │
│  │   Component            │◄─►│   Component            │                    │
│  │                        │   │                        │                    │
│  └──────────┬─────────────┘   └──────────┬─────────────┘                    │
│             │                            │                                   │
│             ▼                            ▼                                   │
│  ┌────────────────────────┐   ┌────────────────────────┐                    │
│  │                        │   │                        │                    │
│  │   Contextual           │   │   UI Visualization     │                    │
│  │   Intelligence         │◄─►│   Component            │                    │
│  │                        │   │                        │                    │
│  └────────────────────────┘   └────────────────────────┘                    │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

The primary components in the iOS application:

1. **Voice Processing Component**: Captures and processes voice input for command execution
2. **Timer Engine Component**: Core timer functionality and state management
3. **Routine Management Component**: Handles saved timer configurations
4. **Session Analytics Component**: Records and analyzes timer usage
5. **Contextual Intelligence Component**: Provides context-aware timer adjustments
6. **UI Visualization Component**: Renders the timer interface and visualizations

## 3. Critical System Components

### Voice Processing Component

**Responsibilities:**
- Capture voice input via iOS speech recognition
- Process natural language to extract timer intentions
- Parse complex timer descriptions into structured sequences
- Translate voice commands into timer operations

**Interfaces:**
- `recognizeSpeech(audio: AudioData) -> String`
- `parseTimerIntent(text: String) -> TimerIntent`
- `extractRoutineDefinition(text: String) -> RoutineDefinition`
- `processVoiceCommand(command: String) -> TimerCommand`

**Dependencies:**
- iOS Speech Recognition framework
- Cloud-based LLM service
- Timer Engine Component

**Risk Assessment: HIGH**
- Natural language understanding relies on external LLM service
- Voice recognition accuracy in noisy environments
- Complex parsing of free-form timer descriptions
- Potential latency issues with cloud-based processing

### Timer Engine Component

**Responsibilities:**
- Manage the lifecycle of active timers
- Handle timer state transitions (start, pause, resume, stop)
- Process phase transitions and completions
- Coordinate multiple concurrent timers
- Trigger notifications for timer events

**Interfaces:**
- `createTimer(routine: Routine) -> Timer`
- `startTimer(timerId: UUID) -> TimerState`
- `pauseTimer(timerId: UUID) -> TimerState`
- `stopTimer(timerId: UUID) -> TimerState`
- `getActiveTimers() -> [Timer]`
- `getTimerState(timerId: UUID) -> TimerState`

**Dependencies:**
- iOS Local Notification framework
- Routine Management Component
- Session Analytics Component

**Risk Assessment: MEDIUM**
- Accurate time tracking when app is backgrounded
- Battery consumption with multiple active timers
- Phase transitions in background state
- Handling system interruptions (calls, alerts)

### Routine Management Component

**Responsibilities:**
- Create and edit timer routines
- Auto-suggest routine names
- Organize routines into categories
- Manage routine templates
- Handle routine sharing and import

**Interfaces:**
- `createRoutine(definition: RoutineDefinition) -> Routine`
- `suggestName(routine: Routine) -> String`
- `saveRoutine(routine: Routine) -> UUID`
- `getRoutines(category: Category?) -> [Routine]`
- `shareRoutine(routineId: UUID) -> RoutineTemplate`
- `importRoutine(template: RoutineTemplate) -> Routine`

**Dependencies:**
- Local Data Storage
- Contextual Intelligence Component
- Natural Language Processor (for name suggestions)

**Risk Assessment: LOW**
- Efficient storage and retrieval of routines
- Synchronization of routines across devices
- Generating meaningful name suggestions

### Contextual Intelligence Component

**Responsibilities:**
- Determine relevant contextual factors
- Query knowledge base for adjustment rules
- Calculate adjustments based on context
- Generate explanations for adjustments
- Update knowledge base with new information

**Interfaces:**
- `getContextualFactors() -> [ContextualFactor]`
- `calculateAdjustment(phase: Phase, factors: [ContextualFactor]) -> AdjustmentFactor`
- `explainAdjustment(adjustment: AdjustmentFactor) -> String`
- `queryKnowledgeBase(activity: String) -> [AdjustmentRule]`

**Dependencies:**
- Location Services
- Knowledge Base Service
- Timer Engine Component

**Risk Assessment: MEDIUM**
- Accuracy of contextual adjustments
- Comprehensiveness of knowledge base
- User acceptance of automatic adjustments
- Location permission requirements

### Session Analytics Component

**Responsibilities:**
- Record completed timer sessions
- Calculate streak information
- Generate statistics on routine usage
- Visualize session history and patterns
- Sync session data across devices

**Interfaces:**
- `recordSession(timer: Timer) -> Session`
- `calculateStreak(routineId: UUID) -> Int`
- `getSessionHistory(filter: SessionFilter) -> [Session]`
- `getUsageStatistics(routineId: UUID) -> UsageStatistics`

**Dependencies:**
- Local Data Storage
- iCloud Synchronization
- Timer Engine Component

**Risk Assessment: LOW**
- Efficient storage of potentially large history
- Privacy considerations for usage data
- Synchronization conflicts across devices

### UI Visualization Component

**Responsibilities:**
- Render timer interface with stacked rings
- Display routine creation and editing UI
- Visualize session history and analytics
- Provide gesture-based interactions
- Support accessibility features

**Interfaces:**
- `renderTimerView(timer: Timer) -> View`
- `renderRoutineCreationView() -> View`
- `renderHistoryView(sessions: [Session]) -> View`
- `renderStackedTimers(timers: [Timer]) -> View`

**Dependencies:**
- SwiftUI/UIKit frameworks
- Timer Engine Component
- Routine Management Component
- Session Analytics Component

**Risk Assessment: MEDIUM**
- Performance of stacked timer visualizations
- Accessibility compliance
- Intuitive gesture handling
- Animation smoothness

## 4. Architecture Decision Records (ADRs)

### ADR 1: Cloud vs. Local Natural Language Processing

**Context:** The system needs to process natural language input to convert user voice commands into structured timer definitions. This requires sophisticated natural language understanding capabilities.

**Options Considered:**
1. **Pure Cloud-Based Processing**: Send all voice data to a cloud LLM service for processing
2. **Hybrid Approach**: Use on-device processing for basic commands, cloud for complex parsing
3. **Pure On-Device Processing**: Implement a smaller on-device LLM for all processing

**Decision:** Implement a hybrid approach for MVP, with a path toward increasing on-device processing in future iterations.

**Rationale:**
- On-device processing alone cannot match the understanding capabilities needed for complex timer descriptions
- Pure cloud approach introduces latency and privacy concerns
- Hybrid approach provides balance of capability, privacy, and performance

**Consequences:**
- Positive: Better natural language understanding, reduced cloud dependency for basic commands
- Negative: Increased complexity in implementation, potential offline limitations
- Positive: Clear path to more on-device processing as technology improves

### ADR 2: Data Storage Strategy

**Context:** The application needs to store user routines, session history, and knowledge base data while supporting cross-device synchronization.

**Options Considered:**
1. **Pure Core Data with iCloud Sync**: Use Core Data for all storage with automatic iCloud synchronization
2. **Hybrid SQLite + Core Data**: Use SQLite for knowledge base, Core Data for user data
3. **Pure Document-Based Storage**: Store everything as JSON documents in the filesystem

**Decision:** Implement Core Data with iCloud sync for user data (routines, sessions) and a versioned SQLite database for the knowledge base.

**Rationale:**
- Core Data provides efficient synchronization via CloudKit for user-specific data
- SQLite offers better performance for the knowledge base which requires complex queries
- Separating user data from knowledge base simplifies updates and versioning

**Consequences:**
- Positive: Efficient synchronization for user data across devices
- Negative: Two separate storage systems to maintain
- Positive: Knowledge base can be updated independently of app updates

### ADR 3: Backend Service Requirements

**Context:** We need to decide whether the MVP requires a dedicated backend service or can operate as a standalone application.

**Options Considered:**
1. **No Backend**: Completely standalone app with cloud service API calls directly from the client
2. **Minimal Backend**: Lightweight serverless functions for specific operations only
3. **Full Backend Service**: Comprehensive backend with user accounts, data storage, etc.

**Decision:** Implement the MVP with no dedicated backend, using direct API calls to LLM services and leveraging iCloud for synchronization.

**Rationale:**
- Simplifies initial development and deployment
- Reduces operational costs and complexity
- iCloud already handles identity and synchronization needs
- LLM providers offer direct API access that can be used securely from the client

**Consequences:**
- Positive: Faster time to market with reduced complexity
- Negative: Limited to Apple ecosystem for user authentication and sync
- Negative: Some operations may require client-side implementation that could be more efficient server-side
- Positive: Clearer privacy story with minimal data leaving the user's devices

### ADR 4: LLM Selection and Integration

**Context:** We need a natural language model that can accurately parse timer descriptions and commands.

**Options Considered:**
1. **OpenAI GPT-4**: Highly capable but potentially expensive
2. **Anthropic Claude**: Strong at following complex instructions
3. **Open-Source Models**: Models like Llama 3 or Mistral with local fine-tuning
4. **Custom-Trained Domain-Specific Model**: Train a specialized model for timer descriptions

**Decision:** Use Anthropic Claude via API for the MVP with a fallback to simpler models for basic commands.

**Rationale:**
- Claude excels at following instructions and has shown strong performance in structural parsing
- API-based approach allows for seamless upgrades as model improves
- Can be integrated with a simpler model for basic commands to reduce costs
- Development team has existing experience with Claude's API

**Consequences:**
- Positive: High-quality parsing for complex timer descriptions
- Negative: API dependency and associated costs
- Positive: Natural path to incorporating open-source models as they improve
- Negative: Network connectivity required for complex commands

### ADR 5: Background Processing Strategy

**Context:** Timers need to continue running and notify users even when the app is backgrounded or the device is locked.

**Options Considered:**
1. **Local Notifications Only**: Rely solely on scheduled local notifications
2. **Background Execution**: Request extended background execution time
3. **Hybrid Approach**: Use background execution with fallback to notifications

**Decision:** Implement a hybrid approach using background execution modes where available with notification fallbacks.

**Rationale:**
- Background execution provides the best user experience when available
- iOS limits background execution time, requiring a fallback mechanism
- Local notifications ensure timer functionality even with strict background limitations
- Hybrid approach maximizes reliability across different usage scenarios

**Consequences:**
- Positive: More reliable timer execution in background states
- Negative: Increased implementation complexity
- Positive: Better battery performance than pure background execution
- Negative: Potential for inconsistent user experience depending on system state

### ADR 6: UI Architecture Pattern

**Context:** We need a UI architecture that supports complex state management and reactive updates for timer visualizations.

**Options Considered:**
1. **UIKit with MVC**: Traditional iOS architecture
2. **SwiftUI with MVVM**: Modern declarative UI with view models
3. **The Composable Architecture (TCA)**: Comprehensive state management framework
4. **UIKit + Combine**: Traditional UI with reactive programming

**Decision:** Implement SwiftUI with MVVM as the primary architecture, with TCA concepts for complex state management in key areas.

**Rationale:**
- SwiftUI provides declarative UI that simplifies complex visualizations
- MVVM pattern works well with SwiftUI's data binding
- TCA concepts (without full framework adoption) provide clear state management
- Approach balances modern practices with pragmatic implementation

**Consequences:**
- Positive: Cleaner separation of UI and business logic
- Negative: SwiftUI has some limitations compared to UIKit
- Positive: Better testability through view model separation
- Negative: Learning curve for developers not familiar with SwiftUI/MVVM
- Positive: Easier to maintain and evolve as requirements change

### ADR 7: Synchronization Approach

**Context:** Users expect their routines and history to synchronize seamlessly across devices.

**Options Considered:**
1. **CloudKit Direct**: Use Apple's CloudKit framework directly
2. **Core Data with NSPersistentCloudKitContainer**: Leverage automatic sync
3. **Custom Sync Protocol**: Implement our own synchronization logic
4. **Third-Party Sync Solution**: Use a service like Firebase or Realm

**Decision:** Implement Core Data with NSPersistentCloudKitContainer for automatic iCloud synchronization.

**Rationale:**
- Provides automatic conflict resolution
- Deeply integrated with iOS ecosystem
- Minimal additional code required
- Handles authentication through Apple ID

**Consequences:**
- Positive: Simplifies sync implementation
- Negative: Limited to Apple ecosystem
- Positive: Uses Apple's infrastructure for reliability
- Negative: Less control over sync behavior
- Positive: Better privacy through Apple's data handling policies

## 5. Technical Implementation Guidelines

### Recommended Technology Stack

#### iOS Application (MVP)
- **UI Framework**: SwiftUI with UIKit integration where needed
- **Architecture Pattern**: MVVM with TCA-inspired state management
- **Data Persistence**: Core Data with CloudKit synchronization
- **Knowledge Base**: SQLite database with JSON schema
- **Natural Language Processing**: Anthropic Claude API with local fallbacks
- **Voice Recognition**: iOS Speech Recognition framework
- **Concurrency**: Swift Concurrency (async/await)
- **Dependency Management**: Swift Package Manager
- **Testing**: XCTest with dependencies on Quick and Nimble for BDD-style tests

#### Backend Services (Future)
- **API Framework**: Node.js with Express or NestJS
- **Database**: PostgreSQL with JSON support
- **Authentication**: OAuth2 with Apple ID integration
- **Serverless Functions**: AWS Lambda or Firebase Cloud Functions
- **API Documentation**: OpenAPI/Swagger

### Data Storage Strategy

#### Core Data Schema
- Define entities for User, Routine, Phase, Timer, Session, and Schedule
- Use CloudKit integration for automatic synchronization
- Implement versioning mechanisms for schema migrations
- Store binary data (like audio snippets) in separate files referenced by Core Data

#### Knowledge Base
- SQLite database with JSON fields for flexible schema evolution
- Version-controlled updates separate from app updates
- Local-first with asynchronous updates from central repository
- Implement efficient query patterns for contextual lookups

#### Caching Strategy
- Cache LLM responses for similar commands to reduce API usage
- Store frequently used routines in memory for quick access
- Implement intelligent preloading of likely-to-be-used routines
- Cache contextual adjustments for offline usage

### API Design Principles

#### External API Communication
- RESTful design for cloud service interactions
- JWT-based authentication where required
- Implement appropriate rate limiting and retry logic
- Graceful degradation when services are unavailable

#### Internal Module Communication
- Clear interfaces between components
- Event-driven communication for loose coupling
- Dependency injection for testability
- Protocol-oriented design to enable mock implementations

### Security and Privacy Implementation

#### Data Protection
- Store sensitive data in iOS Keychain
- Use app groups for secure container access
- Implement appropriate data retention policies
- Secure all network communications with TLS

#### Voice Data Handling
- Process voice data locally when possible
- Minimize data sent to external services
- Implement clear user consent flows
- Do not persist raw voice recordings

#### LLM API Security
- Secure API keys using Keychain
- Implement request signing and verification
- Avoid sending personally identifiable information
- Use content filtering to prevent misuse

### Performance Optimization Strategies

#### Battery Usage
- Implement intelligent background execution modes
- Use push notifications instead of polling where possible
- Optimize audio processing pipeline
- Implement dormant states for inactive timers

#### UI Performance
- Use efficient drawing techniques for timer visualizations
- Implement progressive loading for history views
- Cache complex UI calculations
- Use time profiler to identify and resolve bottlenecks

#### Memory Management
- Implement appropriate caching strategies
- Use lazy loading for non-critical resources
- Monitor and optimize memory usage in background states
- Implement memory warnings response handling

## 6. Engineering Team FAQ

### System Architecture

**Q: Why did we choose a monolithic approach rather than microservices for the MVP?**  
A: The monolithic approach allows us to iterate quickly, avoid premature optimization, and maintain simplicity. Since the MVP is primarily a client-side iOS application, a monolithic architecture provides the best balance of development speed and maintainability. We've designed with clear boundaries between components to facilitate future decomposition if needed.

**Q: How will the system scale as we add more users and routines?**  
A: The MVP design is primarily client-side with cloud services for LLM processing, which inherently scales well. User data is stored in iCloud, leveraging Apple's infrastructure. As we grow, we may introduce dedicated backend services for knowledge base updates, advanced analytics, and cross-platform support. The component-based design facilitates this evolution.

**Q: What's our strategy for handling offline usage?**  
A: The application will use a local-first approach where core timer functionality works offline. We'll cache previously processed voice commands and implement fallback parsing for basic commands that don't require cloud LLM services. The knowledge base will be available offline with periodic updates when online. Complex natural language processing will require connectivity, but we'll clearly communicate this limitation to users.

### Development Approach

**Q: How will we implement Test-Driven Development with AI assistants?**  
A: We'll define clear interfaces between components and write comprehensive tests before implementation. AI assistants will help generate test cases and implementation code based on these interfaces. We'll use property-based testing for complex algorithms like contextual adjustments and fuzz testing for the voice processing pipeline. Each component will have a test suite that verifies its contract with other components.

**Q: What's our approach to managing technical debt?**  
A: We'll maintain an architectural decision log to document trade-offs. Each sprint will allocate time for refactoring and technical improvements. We've designed the system with clear component boundaries to contain technical debt within specific areas. We'll use static analysis tools and linters to maintain code quality and regularly review areas that might accrue debt, such as the voice processing and LLM integration.

**Q: How will we handle versioning of the knowledge base?**  
A: The knowledge base will have a separate versioning system from the application. We'll implement a schema versioning mechanism and migration path. Updates will be delivered as separate packages that can be applied incrementally. Each knowledge base version will be compatible with a range of application versions, and we'll maintain backward compatibility for at least two major releases.

### Technical Challenges

**Q: How will we optimize battery usage while running multiple timers?**  
A: We'll implement a unified timer engine that coordinates multiple logical timers through a single system timer. We'll use iOS background modes judiciously, preferring scheduled notifications for longer durations. The system will batch updates and notifications to minimize wake cycles and optimize UI refreshes to reduce energy usage. We'll also implement intelligent sleep modes for timers with distant deadlines.

**Q: How will we handle the latency of cloud-based LLM processing?**  
A: We'll implement a progressive response strategy. Basic commands will be processed locally for immediate feedback. For complex inputs, we'll provide immediate acknowledgment while processing in the background. We'll also cache common commands and implement predictive preloading based on user patterns. The UI will provide clear feedback about processing status to manage user expectations.

**Q: How will we ensure the reliability of contextual adjustments?**  
A: We'll start with a conservative adjustment model based on well-established formulas (like altitude adjustments for cooking). Each adjustment will include a confidence score, and we'll only apply high-confidence adjustments automatically. Users will be able to view and override adjustments. We'll collect anonymized performance data (with consent) to improve adjustment accuracy over time.

### Implementation Details

**Q: What's our approach to handling background execution limits in iOS?**  
A: We'll implement a tiered approach:
1. For short timers (<10 minutes), we'll request standard background execution
2. For medium timers (10-60 minutes), we'll use a combination of background execution and scheduled notifications
3. For long timers (>60 minutes), we'll primarily use scheduled notifications with periodic state verification
We'll also provide users with best practices to ensure timer reliability (like keeping the app in the foreground for critical timers).

**Q: How will we handle voice processing in noisy environments?**  
A: We'll implement a multi-stage approach to voice processing:
1. Use iOS's built-in noise cancellation when available
2. Implement a confidence threshold for voice recognition
3. Provide clear visual feedback and confirmation for low-confidence recognition
4. Offer quick correction options when recognition may be incorrect
5. Maintain a history of recent commands for easy reuse
We'll also continuously train and improve our language model with diverse audio samples to enhance recognition in challenging environments.

**Q: What's our strategy for reducing LLM API costs while maintaining quality?**  
A: We'll implement several cost-optimization strategies:
1. Use a tiered model approach - simple commands use lighter models or on-device processing
2. Cache common or similar requests to avoid duplicate processing
3. Implement intelligent prompt design to maximize efficiency
4. Batch similar requests when possible
5. Continuously monitor usage patterns to identify optimization opportunities
6. Provide higher quality processing for paid users while maintaining acceptable quality for free users

## Appendix A: Component Interfaces

### Voice Processing Component

```swift
protocol VoiceProcessingService {
    /// Capture and process voice input
    func captureVoice() async throws -> String
    
    /// Process natural language into timer intent
    func processCommand(_ text: String) async throws -> TimerIntent
    
    /// Extract structured routine from description
    func extractRoutine(_ description: String) async throws -> RoutineDefinition
    
    /// Check if a command can be processed locally
    func canProcessLocally(_ command: String) -> Bool
}

enum TimerIntent {
    case create(RoutineDefinition)
    case start(identifier: UUID?)
    case pause(identifier: UUID?)
    case resume(identifier: UUID?)
    case stop(identifier: UUID?)
    case modify(identifier: UUID, modification: TimerModification)
    case schedule(RoutineDefinition, schedulingInfo: SchedulingInfo)
    case unknown(originalText: String)
}

struct RoutineDefinition {
    let name: String?
    let description: String?
    let category: String?
    let phases: [PhaseDefinition]
}

struct PhaseDefinition {
    let name: String
    let baseDuration: TimeInterval
    let repeatCount: Int
}

enum TimerModification {
    case extendCurrentPhase(by: TimeInterval)
    case skipToNextPhase
    case changeName(to: String)
    case addPhase(phase: PhaseDefinition, after: Int)
    case removePhase(at: Int)
}
```

### Timer Engine Component

```swift
protocol TimerEngine {
    /// Create a new timer from a routine
    func createTimer(from routine: Routine) throws -> Timer
    
    /// Start a timer
    func startTimer(identifier: UUID) throws -> TimerState
    
    /// Pause a running timer
    func pauseTimer(identifier: UUID) throws -> TimerState
    
    /// Resume a paused timer
    func resumeTimer(identifier: UUID) throws -> TimerState
    
    /// Stop a timer
    func stopTimer(identifier: UUID) throws -> TimerState
    
    /// Get all active timers
    func getActiveTimers() -> [Timer]
    
    /// Get a specific timer by ID
    func getTimer(identifier: UUID) -> Timer?
    
    /// Register for timer events
    func registerForEvents(observer: TimerObserver)
    
    /// Unregister from timer events
    func unregisterFromEvents(observer: TimerObserver)
}

protocol TimerObserver: AnyObject {
    func timerDidStart(_ timer: Timer)
    func timerDidPause(_ timer: Timer)
    func timerDidResume(_ timer: Timer)
    func timerDidComplete(_ timer: Timer)
    func timerDidTransitionToPhase(_ timer: Timer, phase: Phase, index: Int)
    func timerDidUpdateRemainingTime(_ timer: Timer, timeRemaining: TimeInterval)
}

enum TimerState {
    case idle
    case running
    case paused
    case completed
    case error(description: String)
}
```

### Routine Management Component

```swift
protocol RoutineManager {
    /// Create a new routine
    func createRoutine(definition: RoutineDefinition) throws -> Routine
    
    /// Save a routine
    func saveRoutine(_ routine: Routine) throws -> UUID
    
    /// Delete a routine
    func deleteRoutine(identifier: UUID) throws
    
    /// Get all routines
    func getAllRoutines() -> [Routine]
    
    /// Get routines by category
    func getRoutines(in category: String) -> [Routine]
    
    /// Get routine by ID
    func getRoutine(identifier: UUID) -> Routine?
    
    /// Suggest a name for a routine
    func suggestName(for routine: Routine) async -> String
    
    /// Share a routine as a template
    func shareRoutine(identifier: UUID) throws -> RoutineTemplate
    
    /// Import a routine from a template
    func importRoutine(from template: RoutineTemplate) throws -> Routine
}
```

### Contextual Intelligence Component

```swift
protocol ContextualIntelligence {
    /// Get current contextual factors
    func getCurrentFactors() async -> [ContextualFactor]
    
    /// Calculate adjustments for a phase
    func calculateAdjustments(for phase: Phase, with factors: [ContextualFactor]) -> [AdjustmentFactor]
    
    /// Get explanation for an adjustment
    func explainAdjustment(_ adjustment: AdjustmentFactor) -> String
    
    /// Query the knowledge base
    func queryKnowledgeBase(activity: String) -> [AdjustmentRule]
    
    /// Check if an activity is recognized
    func isKnownActivity(_ activity: String) -> Bool
}

struct ContextualFactor {
    let type: FactorType
    let value: Any
    
    enum FactorType {
        case location
        case altitude
        case temperature
        case humidity
        case barometricPressure
        case timeOfDay
        case dayOfWeek
        case custom(name: String)
    }
}

struct AdjustmentFactor {
    let baseValue: TimeInterval
    let adjustedValue: TimeInterval
    let factorApplied: Double
    let confidence: Double
    let explanation: String
    let source: AdjustmentSource
    
    enum AdjustmentSource {
        case knowledgeBase(rule: String)
        case userPreference
        case learningModel
        case defaultRule
    }
}
```

### Session Analytics Component

```swift
protocol SessionAnalytics {
    /// Record a completed session
    func recordSession(_ session: Session) throws
    
    /// Get session history
    func getSessionHistory(filter: SessionFilter?) -> [Session]
    
    /// Calculate streak for a routine
    func calculateStreak(routineId: UUID) -> Int
    
    /// Get usage statistics for a routine
    func getUsageStatistics(routineId: UUID?) -> UsageStatistics
    
    /// Export session data
    func exportSessions(matching filter: SessionFilter?) throws -> Data
    
    /// Delete session history
    func deleteSessions(matching filter: SessionFilter?) throws
}

struct SessionFilter {
    let routineId: UUID?
    let startDate: Date?
    let endDate: Date?
    let completionStatus: CompletionStatus?
    
    enum CompletionStatus {
        case completed
        case partial
        case abandoned
    }
}

struct UsageStatistics {
    let totalSessions: Int
    let completedSessions: Int
    let averageDuration: TimeInterval
    let longestStreak: Int
    let currentStreak: Int
    let variance: Double
    let mostActiveDay: Weekday
    let mostActiveTime: TimeOfDay
}
```

# AI-Native Timer: System Design Document

## Executive Summary

This document outlines the technical architecture and implementation plan for the AI-Native Timer application based on the provided product specification. The design follows domain-driven development principles with a focus on clean separation of concerns while maintaining a manageable service-oriented architecture appropriate for the MVP stage.

The AI-Native Timer reimagines timers by leveraging natural language understanding and contextual intelligence, allowing users to create sophisticated timing sequences through simple voice commands. Our architecture supports the core product proposition: zero mental overhead, context-smart adjustments, habit intelligence, and a cross-device experience.

This design prioritizes a robust iOS implementation for the MVP while establishing clean boundaries between components to facilitate future expansion. We've adopted a practical approach that balances user experience with implementation feasibility, focusing on reliable timer execution, intelligent voice processing, and contextual awareness.

## 1. Domain-Driven Design (DDD) Analysis

### Bounded Contexts

We've identified six primary bounded contexts that organize the system according to business capabilities:

| Bounded Context | Description | Key Responsibilities |
|----------------|-------------|----------------------|
| **Timer Core** | Central domain handling timer creation and execution | Timer engine, phase transitions, timer state management |
| **Voice Processing** | Handles voice input and natural language understanding | Speech recognition, intent parsing, command execution |
| **Routine Management** | Manages saved timer routines | Routine creation, editing, organization, templates |
| **Contextual Intelligence** | Provides smart adjustments based on environment | Location processing, knowledge base queries, adjustment calculation |
| **Session Analytics** | Records and analyzes timer usage | History logging, streak tracking, visualization |
| **User Management** | Handles user data and preferences | User profiles, purchase status, preferences |

### Core Domain and Subdomains

- **Core Domain**: Timer Core + Voice Processing
  - These represent our key competitive advantage and differentiation
  
- **Supporting Subdomains**:
  - Routine Management
  - Contextual Intelligence  
  - Session Analytics
  
- **Generic Subdomains**:
  - User Management
  - Scheduling
  - Sharing

### Ubiquitous Language

Our domain model uses consistent terminology from the product specification:

| Term | Definition | Technical Implementation |
|------|------------|--------------------------|
| Routine | A saved sequence of timed phases | `Routine` entity with metadata and collection of phases |
| Phase | Single timed segment within a routine | `Phase` entity with duration and position properties |
| Ad-hoc Timer | Timer created for immediate use | Temporary `Timer` instance without persistent routine |
| Contextual Adjustment | Duration modification based on environment | Function that transforms base duration using environmental data |
| Knowledge Base | Curated timing formulas | Structured database of activities and adjustment rules |
| Streak | Consecutive days with completed routines | Calculated property derived from session history |
| Variance | Consistency measure of completion times | Statistical function over session durations |
| Session | Single execution instance of a routine | `Session` entity with timestamps and completion data |
| Schedule | Future automatic execution plan | `Schedule` entity with recurrence and notification rules |
| Stacked Rings | Visual for multiple concurrent timers | UI component with concentric progress indicators |

### Domain Model

#### Aggregates and Entities

Our domain model identifies five primary aggregates:

**User Aggregate**
- `User` (root entity)
  - UserID (identifier)
  - PurchaseStatus (free/paid)
  - Preferences (settings)

**Routine Aggregate**
- `Routine` (root entity)
  - RoutineID (identifier)
  - Name, Description, Category
  - Collection of `Phase` entities
  - Created/Modified dates

**Timer Execution Aggregate**
- `Timer` (root entity)
  - TimerID (identifier)  
  - Reference to Routine
  - Current state (running, paused, completed)
  - StartTime, ElapsedTime, RemainingTime
  - CurrentPhase reference

**Session History Aggregate**
- `Session` (root entity)
  - SessionID (identifier)
  - Reference to Routine
  - StartTime, CompletionTime
  - CompletionStatus
  - Collection of completed phases with actual durations
  - ContextualFactors applied

**Schedule Aggregate**
- `Schedule` (root entity)
  - ScheduleID (identifier)
  - Reference to Routine
  - RecurrencePattern
  - Enabled status
  - Notification settings

#### Value Objects

- `Duration`: Immutable representation of time spans
- `Location`: Geographical position with altitude
- `AdjustmentFactor`: Percentage modifier with explanation
- `RoutineTemplate`: Shareable routine definition without user data
- `TimerState`: Enum representing possible timer states

#### Domain Events

- `RoutineCreated`: Triggered when a new routine is saved
- `TimerStarted`: Marks the beginning of timer execution
- `PhaseTransition`: Signals a change from one phase to another
- `TimerCompleted`: Marks the successful completion of all phases
- `AdjustmentApplied`: Records the application of a contextual adjustment
- `SessionRecorded`: Confirms the logging of a completed session

## 2. C4 Model Architecture Diagrams

### Context Diagram

The AI-Native Timer system interfaces with:

- **Users**: Through iOS mobile application with voice and touch interfaces
- **LLM Services**: Cloud-based language model for natural language understanding
- **Location Services**: For altitude and geographical context data
- **Apple Services**: For iCloud synchronization and in-app purchases

### Container Diagram

The AI-Native Timer system consists of:

1. **iOS Mobile Application**: The primary user interface built with Swift/SwiftUI
2. **Natural Language Processor**: Handles voice input interpretation using transformer-based LLM
3. **Local Data Storage**: Manages user data, routines, and sessions using Core Data/SQLite
4. **Knowledge Base Service**: Provides contextual adjustment data and formulas

### Component Diagram (iOS Mobile Application)

The primary components in the iOS application:

1. **Voice Processing Component**: Captures and processes voice input for command execution
2. **Timer Engine Component**: Core timer functionality and state management
3. **Routine Management Component**: Handles saved timer configurations
4. **Session Analytics Component**: Records and analyzes timer usage
5. **Contextual Intelligence Component**: Provides context-aware timer adjustments
6. **UI Visualization Component**: Renders the timer interface and visualizations

## 3. Critical System Components

### Voice Processing Component

**Responsibilities:**
- Capture voice input via iOS speech recognition
- Process natural language to extract timer intentions
- Parse complex timer descriptions into structured sequences
- Translate voice commands into timer operations

**Interfaces:**
- `recognizeSpeech(audio: AudioData) -> String`
- `parseTimerIntent(text: String) -> TimerIntent`
- `extractRoutineDefinition(text: String) -> RoutineDefinition`
- `processVoiceCommand(command: String) -> TimerCommand`

**Dependencies:**
- iOS Speech Recognition framework
- Cloud-based LLM service
- Timer Engine Component

**Risk Assessment: HIGH**
- Natural language understanding relies on external LLM service
- Voice recognition accuracy in noisy environments
- Complex parsing of free-form timer descriptions
- Potential latency issues with cloud-based processing

### Timer Engine Component

**Responsibilities:**
- Manage the lifecycle of active timers
- Handle timer state transitions (start, pause, resume, stop)
- Process phase transitions and completions
- Coordinate multiple concurrent timers
- Trigger notifications for timer events

**Interfaces:**
- `createTimer(routine: Routine) -> Timer`
- `startTimer(timerId: UUID) -> TimerState`
- `pauseTimer(timerId: UUID) -> TimerState`
- `stopTimer(timerId: UUID) -> TimerState`
- `getActiveTimers() -> [Timer]`
- `getTimerState(timerId: UUID) -> TimerState`

**Dependencies:**
- iOS Local Notification framework
- Routine Management Component
- Session Analytics Component

**Risk Assessment: MEDIUM**
- Accurate time tracking when app is backgrounded
- Battery consumption with multiple active timers
- Phase transitions in background state
- Handling system interruptions (calls, alerts)

### Routine Management Component

**Responsibilities:**
- Create and edit timer routines
- Auto-suggest routine names
- Organize routines into categories
- Manage routine templates
- Handle routine sharing and import

**Interfaces:**
- `createRoutine(definition: RoutineDefinition) -> Routine`
- `suggestName(routine: Routine) -> String`
- `saveRoutine(routine: Routine) -> UUID`
- `getRoutines(category: Category?) -> [Routine]`
- `shareRoutine(routineId: UUID) -> RoutineTemplate`
- `importRoutine(template: RoutineTemplate) -> Routine`

**Dependencies:**
- Local Data Storage
- Contextual Intelligence Component
- Natural Language Processor (for name suggestions)

**Risk Assessment: LOW**
- Efficient storage and retrieval of routines
- Synchronization of routines across devices
- Generating meaningful name suggestions

### Contextual Intelligence Component

**Responsibilities:**
- Determine relevant contextual factors
- Query knowledge base for adjustment rules
- Calculate adjustments based on context
- Generate explanations for adjustments
- Update knowledge base with new information

**Interfaces:**
- `getContextualFactors() -> [ContextualFactor]`
- `calculateAdjustment(phase: Phase, factors: [ContextualFactor]) -> AdjustmentFactor`
- `explainAdjustment(adjustment: AdjustmentFactor) -> String`
- `queryKnowledgeBase(activity: String) -> [AdjustmentRule]`

**Dependencies:**
- Location Services
- Knowledge Base Service
- Timer Engine Component

**Risk Assessment: MEDIUM**
- Accuracy of contextual adjustments
- Comprehensiveness of knowledge base
- User acceptance of automatic adjustments
- Location permission requirements

### Session Analytics Component

**Responsibilities:**
- Record completed timer sessions
- Calculate streak information
- Generate statistics on routine usage
- Visualize session history and patterns
- Sync session data across devices

**Interfaces:**
- `recordSession(timer: Timer) -> Session`
- `calculateStreak(routineId: UUID) -> Int`
- `getSessionHistory(filter: SessionFilter) -> [Session]`
- `getUsageStatistics(routineId: UUID) -> UsageStatistics`

**Dependencies:**
- Local Data Storage
- iCloud Synchronization
- Timer Engine Component

**Risk Assessment: LOW**
- Efficient storage of potentially large history
- Privacy considerations for usage data
- Synchronization conflicts across devices

### UI Visualization Component

**Responsibilities:**
- Render timer interface with stacked rings
- Display routine creation and editing UI
- Visualize session history and analytics
- Provide gesture-based interactions
- Support accessibility features

**Interfaces:**
- `renderTimerView(timer: Timer) -> View`
- `renderRoutineCreationView() -> View`
- `renderHistoryView(sessions: [Session]) -> View`
- `renderStackedTimers(timers: [Timer]) -> View`

**Dependencies:**
- SwiftUI/UIKit frameworks
- Timer Engine Component
- Routine Management Component
- Session Analytics Component

**Risk Assessment: MEDIUM**
- Performance of stacked timer visualizations
- Accessibility compliance
- Intuitive gesture handling
- Animation smoothness

## 4. Architecture Decision Records (ADRs)

### ADR 1: Cloud vs. Local Natural Language Processing

**Context:** The system needs to process natural language input to convert user voice commands into structured timer definitions. This requires sophisticated natural language understanding capabilities.

**Options Considered:**
1. **Pure Cloud-Based Processing**: Send all voice data to a cloud LLM service for processing
2. **Hybrid Approach**: Use on-device processing for basic commands, cloud for complex parsing
3. **Pure On-Device Processing**: Implement a smaller on-device LLM for all processing

**Decision:** Implement a hybrid approach for MVP, with a path toward increasing on-device processing in future iterations.

**Rationale:**
- On-device processing alone cannot match the understanding capabilities needed for complex timer descriptions
- Pure cloud approach introduces latency and privacy concerns
- Hybrid approach provides balance of capability, privacy, and performance

**Consequences:**
- Positive: Better natural language understanding, reduced cloud dependency for basic commands
- Negative: Increased complexity in implementation, potential offline limitations
- Positive: Clear path to more on-device processing as technology improves

### ADR 2: Data Storage Strategy

**Context:** The application needs to store user routines, session history, and knowledge base data while supporting cross-device synchronization.

**Options Considered:**
1. **Pure Core Data with iCloud Sync**: Use Core Data for all storage with automatic iCloud synchronization
2. **Hybrid SQLite + Core Data**: Use SQLite for knowledge base, Core Data for user data
3. **Pure Document-Based Storage**: Store everything as JSON documents in the filesystem

**Decision:** Implement Core Data with iCloud sync for user data (routines, sessions) and a versioned SQLite database for the knowledge base.

**Rationale:**
- Core Data provides efficient synchronization via CloudKit for user-specific data
- SQLite offers better performance for the knowledge base which requires complex queries
- Separating user data from knowledge base simplifies updates and versioning

**Consequences:**
- Positive: Efficient synchronization for user data across devices
- Negative: Two separate storage systems to maintain
- Positive: Knowledge base can be updated independently of app updates

### ADR 3: Backend Service Requirements

**Context:** We need to decide whether the MVP requires a dedicated backend service or can operate as a standalone application.

**Options Considered:**
1. **No Backend**: Completely standalone app with cloud service API calls directly from the client
2. **Minimal Backend**: Lightweight serverless functions for specific operations only
3. **Full Backend Service**: Comprehensive backend with user accounts, data storage, etc.

**Decision:** Implement the MVP with no dedicated backend, using direct API calls to LLM services and leveraging iCloud for synchronization.

**Rationale:**
- Simplifies initial development and deployment
- Reduces operational costs and complexity
- iCloud already handles identity and synchronization needs
- LLM providers offer direct API access that can be used securely from the client

**Consequences:**
- Positive: Faster time to market with reduced complexity
- Negative: Limited to Apple ecosystem for user authentication and sync
- Negative: Some operations may require client-side implementation that could be more efficient server-side
- Positive: Clearer privacy story with minimal data leaving the user's devices

### ADR 4: LLM Selection and Integration

**Context:** We need a natural language model that can accurately parse timer descriptions and commands.

**Options Considered:**
1. **OpenAI GPT-4**: Highly capable but potentially expensive
2. **Anthropic Claude**: Strong at following complex instructions
3. **Open-Source Models**: Models like Llama 3 or Mistral with local fine-tuning
4. **Custom-Trained Domain-Specific Model**: Train a specialized model for timer descriptions

**Decision:** Use Anthropic Claude via API for the MVP with a fallback to simpler models for basic commands.

**Rationale:**
- Claude excels at following instructions and has shown strong performance in structural parsing
- API-based approach allows for seamless upgrades as model improves
- Can be integrated with a simpler model for basic commands to reduce costs
- Development team has existing experience with Claude's API

**Consequences:**
- Positive: High-quality parsing for complex timer descriptions
- Negative: API dependency and associated costs
- Positive: Natural path to incorporating open-source models as they improve
- Negative: Network connectivity required for complex commands

### ADR 5: Background Processing Strategy

**Context:** Timers need to continue running and notify users even when the app is backgrounded or the device is locked.

**Options Considered:**
1. **Local Notifications Only**: Rely solely on scheduled local notifications
2. **Background Execution**: Request extended background execution time
3. **Hybrid Approach**: Use background execution with fallback to notifications

**Decision:** Implement a hybrid approach using background execution modes where available with notification fallbacks.

**Rationale:**
- Background execution provides the best user experience when available
- iOS limits background execution time, requiring a fallback mechanism
- Local notifications ensure timer functionality even with strict background limitations
- Hybrid approach maximizes reliability across different usage scenarios

**Consequences:**
- Positive: More reliable timer execution in background states
- Negative: Increased implementation complexity
- Positive: Better battery performance than pure background execution
- Negative: Potential for inconsistent user experience depending on system state

### ADR 6: UI Architecture Pattern

**Context:** We need a UI architecture that supports complex state management and reactive updates for timer visualizations.

**Options Considered:**
1. **UIKit with MVC**: Traditional iOS architecture
2. **SwiftUI with MVVM**: Modern declarative UI with view models
3. **The Composable Architecture (TCA)**: Comprehensive state management framework
4. **UIKit + Combine**: Traditional UI with reactive programming

**Decision:** Implement SwiftUI with MVVM as the primary architecture, with TCA concepts for complex state management in key areas.

**Rationale:**
- SwiftUI provides declarative UI that simplifies complex visualizations
- MVVM pattern works well with SwiftUI's data binding
- TCA concepts (without full framework adoption) provide clear state management
- Approach balances modern practices with pragmatic implementation

**Consequences:**
- Positive: Cleaner separation of UI and business logic
- Negative: SwiftUI has some limitations compared to UIKit
- Positive: Better testability through view model separation
- Negative: Learning curve for developers not familiar with SwiftUI/MVVM
- Positive: Easier to maintain and evolve as requirements change

### ADR 7: Synchronization Approach

**Context:** Users expect their routines and history to synchronize seamlessly across devices.

**Options Considered:**
1. **CloudKit Direct**: Use Apple's CloudKit framework directly
2. **Core Data with NSPersistentCloudKitContainer**: Leverage automatic sync
3. **Custom Sync Protocol**: Implement our own synchronization logic
4. **Third-Party Sync Solution**: Use a service like Firebase or Realm

**Decision:** Implement Core Data with NSPersistentCloudKitContainer for automatic iCloud synchronization.

**Rationale:**
- Provides automatic conflict resolution
- Deeply integrated with iOS ecosystem
- Minimal additional code required
- Handles authentication through Apple ID

**Consequences:**
- Positive: Simplifies sync implementation
- Negative: Limited to Apple ecosystem
- Positive: Uses Apple's infrastructure for reliability
- Negative: Less control over sync behavior
- Positive: Better privacy through Apple's data handling policies

## 5. Technical Implementation Guidelines

### Recommended Technology Stack

#### iOS Application (MVP)
- **UI Framework**: SwiftUI with UIKit integration where needed
- **Architecture Pattern**: MVVM with TCA-inspired state management
- **Data Persistence**: Core Data with CloudKit synchronization
- **Knowledge Base**: SQLite database with JSON schema
- **Natural Language Processing**: Anthropic Claude API with local fallbacks
- **Voice Recognition**: iOS Speech Recognition framework
- **Concurrency**: Swift Concurrency (async/await)
- **Dependency Management**: Swift Package Manager
- **Testing**: XCTest with dependencies on Quick and Nimble for BDD-style tests

#### Backend Services (Future)
- **API Framework**: Node.js with Express or NestJS
- **Database**: PostgreSQL with JSON support
- **Authentication**: OAuth2 with Apple ID integration
- **Serverless Functions**: AWS Lambda or Firebase Cloud Functions
- **API Documentation**: OpenAPI/Swagger

### Data Storage Strategy

#### Core Data Schema
- Define entities for User, Routine, Phase, Timer, Session, and Schedule
- Use CloudKit integration for automatic synchronization
- Implement versioning mechanisms for schema migrations
- Store binary data (like audio snippets) in separate files referenced by Core Data

#### Knowledge Base
- SQLite database with JSON fields for flexible schema evolution
- Version-controlled updates separate from app updates
- Local-first with asynchronous updates from central repository
- Implement efficient query patterns for contextual lookups

#### Caching Strategy
- Cache LLM responses for similar commands to reduce API usage
- Store frequently used routines in memory for quick access
- Implement intelligent preloading of likely-to-be-used routines
- Cache contextual adjustments for offline usage

### API Design Principles

#### External API Communication
- RESTful design for cloud service interactions
- JWT-based authentication where required
- Implement appropriate rate limiting and retry logic
- Graceful degradation when services are unavailable

#### Internal Module Communication
- Clear interfaces between components
- Event-driven communication for loose coupling
- Dependency injection for testability
- Protocol-oriented design to enable mock implementations

### Security and Privacy Implementation

#### Data Protection
- Store sensitive data in iOS Keychain
- Use app groups for secure container access
- Implement appropriate data retention policies
- Secure all network communications with TLS

#### Voice Data Handling
- Process voice data locally when possible
- Minimize data sent to external services
- Implement clear user consent flows
- Do not persist raw voice recordings

#### LLM API Security
- Secure API keys using Keychain
- Implement request signing and verification
- Avoid sending personally identifiable information
- Use content filtering to prevent misuse

### Performance Optimization Strategies

#### Battery Usage
- Implement intelligent background execution modes
- Use push notifications instead of polling where possible
- Optimize audio processing pipeline
- Implement dormant states for inactive timers

#### UI Performance
- Use efficient drawing techniques for timer visualizations
- Implement progressive loading for history views
- Cache complex UI calculations
- Use time profiler to identify and resolve bottlenecks

#### Memory Management
- Implement appropriate caching strategies
- Use lazy loading for non-critical resources
- Monitor and optimize memory usage in background states
- Implement memory warnings response handling

## 6. Engineering Team FAQ

### System Architecture

**Q: Why did we choose a monolithic approach rather than microservices for the MVP?**  
A: The monolithic approach allows us to iterate quickly, avoid premature optimization, and maintain simplicity. Since the MVP is primarily a client-side iOS application, a monolithic architecture provides the best balance of development speed and maintainability. We've designed with clear boundaries between components to facilitate future decomposition if needed.

**Q: How will the system scale as we add more users and routines?**  
A: The MVP design is primarily client-side with cloud services for LLM processing, which inherently scales well. User data is stored in iCloud, leveraging Apple's infrastructure. As we grow, we may introduce dedicated backend services for knowledge base updates, advanced analytics, and cross-platform support. The component-based design facilitates this evolution.

**Q: What's our strategy for handling offline usage?**  
A: The application will use a local-first approach where core timer functionality works offline. We'll cache previously processed voice commands and implement fallback parsing for basic commands that don't require cloud LLM services. The knowledge base will be available offline with periodic updates when online. Complex natural language processing will require connectivity, but we'll clearly communicate this limitation to users.

### Development Approach

**Q: How will we implement Test-Driven Development with AI assistants?**  
A: We'll define clear interfaces between components and write comprehensive tests before implementation. AI assistants will help generate test cases and implementation code based on these interfaces. We'll use property-based testing for complex algorithms like contextual adjustments and fuzz testing for the voice processing pipeline. Each component will have a test suite that verifies its contract with other components.

**Q: What's our approach to managing technical debt?**  
A: We'll maintain an architectural decision log to document trade-offs. Each sprint will allocate time for refactoring and technical improvements. We've designed the system with clear component boundaries to contain technical debt within specific areas. We'll use static analysis tools and linters to maintain code quality and regularly review areas that might accrue debt, such as the voice processing and LLM integration.

**Q: How will we handle versioning of the knowledge base?**  
A: The knowledge base will have a separate versioning system from the application. We'll implement a schema versioning mechanism and migration path. Updates will be delivered as separate packages that can be applied incrementally. Each knowledge base version will be compatible with a range of application versions, and we'll maintain backward compatibility for at least two major releases.

### Technical Challenges

**Q: How will we optimize battery usage while running multiple timers?**  
A: We'll implement a unified timer engine that coordinates multiple logical timers through a single system timer. We'll use iOS background modes judiciously, preferring scheduled notifications for longer durations. The system will batch updates and notifications to minimize wake cycles and optimize UI refreshes to reduce energy usage. We'll also implement intelligent sleep modes for timers with distant deadlines.

**Q: How will we handle the latency of cloud-based LLM processing?**  
A: We'll implement a progressive response strategy. Basic commands will be processed locally for immediate feedback. For complex inputs, we'll provide immediate acknowledgment while processing in the background. We'll also cache common commands and implement predictive preloading based on user patterns. The UI will provide clear feedback about processing status to manage user expectations.

**Q: How will we ensure the reliability of contextual adjustments?**  
A: We'll start with a conservative adjustment model based on well-established formulas (like altitude adjustments for cooking). Each adjustment will include a confidence score, and we'll only apply high-confidence adjustments automatically. Users will be able to view and override adjustments. We'll collect anonymized performance data (with consent) to improve adjustment accuracy over time.

### Implementation Details

**Q: What's our approach to handling background execution limits in iOS?**  
A: We'll implement a tiered approach:
1. For short timers (<10 minutes), we'll request standard background execution
2. For medium timers (10-60 minutes), we'll use a combination of background execution and scheduled notifications
3. For long timers (>60 minutes), we'll primarily use scheduled notifications with periodic state verification
We'll also provide users with best practices to ensure timer reliability (like keeping the app in the foreground for critical timers).

**Q: How will we handle voice processing in noisy environments?**  
A: We'll implement a multi-stage approach to voice processing:
1. Use iOS's built-in noise cancellation when available
2. Implement a confidence threshold for voice recognition
3. Provide clear visual feedback and confirmation for low-confidence recognition
4. Offer quick correction options when recognition may be incorrect
5. Maintain a history of recent commands for easy reuse
We'll also continuously train and improve our language model with diverse audio samples to enhance recognition in challenging environments.

**Q: What's our strategy for reducing LLM API costs while maintaining quality?**  
A: We'll implement several cost-optimization strategies:
1. Use a tiered model approach - simple commands use lighter models or on-device processing
2. Cache common or similar requests to avoid duplicate processing
3. Implement intelligent prompt design to maximize efficiency
4. Batch similar requests when possible
5. Continuously monitor usage patterns to identify optimization opportunities
6. Provide higher quality processing for paid users while maintaining acceptable quality for free users

## Conclusion

This system design document outlines a comprehensive technical approach for implementing the AI-Native Timer application as specified in the product requirements. By following domain-driven design principles and adopting a service-oriented architecture, we've created a blueprint that balances immediate implementation needs with future scalability.

The MVP will focus on delivering an exceptional iOS experience that showcases the core value propositions: natural language understanding, contextual intelligence, and habit tracking. Our architecture establishes clear component boundaries, well-defined interfaces, and thoughtful technology choices that enable rapid development while minimizing technical debt.

As we move forward with implementation, this document will serve as a guide for the development team, helping to ensure consistency in approach and alignment with the product vision. Regular reviews and updates to this design will be necessary as we learn from implementation challenges and user feedback.

## Figures
%% C4 Context Diagram for AI-Native Timer System
graph TB
    subgraph "AI-Native Timer System"
        AI["AI-Native Timer"]
    end
    
    User["Users"]
    LLM["LLM Services"]
    Location["Location Services"]
    Apple["Apple Services<br>(iCloud, Store)"]
    
    User <-->|"Voice & Touch<br>Interface"| AI
    AI <-->|"Natural Language<br>Processing"| LLM
    AI <-->|"Contextual<br>Data"| Location
    AI <-->|"Sync & Purchases"| Apple
    
    style AI fill:#f9f,stroke:#333,stroke-width:2px
    style User fill:#bbf,stroke:#333,stroke-width:1px
    style LLM fill:#bfb,stroke:#333,stroke-width:1px
    style Location fill:#fbb,stroke:#333,stroke-width:1px
    style Apple fill:#bff,stroke:#333,stroke-width:1px


%% C4 Container Diagram for AI-Native Timer System
graph TB
    User["User<br>(iOS Device)"]
    
    subgraph "AI-Native Timer System"
        iOSApp["iOS Mobile App<br>(Swift/SwiftUI)"]
        NLP["Natural Language<br>Processor<br>(Transformer LLM)"]
        Storage["Local Data Storage<br>(Core Data/SQLite)"]
        KnowledgeBase["Knowledge Base<br>Service<br>(Versioned JSON/SQLite)"]
    end
    
    subgraph "External Services"
        CloudLLM["Cloud LLM API<br>(Anthropic Claude)"]
        iCloud["iCloud<br>(CloudKit)"]
        LocService["Location Services<br>(iOS/CoreLocation)"]
    end
    
    User <--> iOSApp
    iOSApp <--> NLP
    iOSApp <--> Storage
    iOSApp <--> KnowledgeBase
    NLP <--> CloudLLM
    Storage <--> iCloud
    iOSApp <--> LocService
    
    style User fill:#bbf,stroke:#333,stroke-width:1px
    style iOSApp fill:#f9f,stroke:#333,stroke-width:2px
    style NLP fill:#bfb,stroke:#333,stroke-width:1px
    style Storage fill:#fbb,stroke:#333,stroke-width:1px
    style KnowledgeBase fill:#bff,stroke:#333,stroke-width:1px
    style CloudLLM fill:#fcf,stroke:#333,stroke-width:1px
    style iCloud fill:#cff,stroke:#333,stroke-width:1px
    style LocService fill:#ffc,stroke:#333,stroke-width:1px

%% Component Diagram for iOS Mobile App
graph TB
    subgraph "iOS Mobile Application"
        VoiceProc["Voice Processing<br>Component"]
        TimerEngine["Timer Engine<br>Component"]
        RoutineMgmt["Routine Management<br>Component"]
        SessionAnalytics["Session Analytics<br>Component"]
        ContextIntel["Contextual Intelligence<br>Component"]
        UIVis["UI Visualization<br>Component"]
    end
    
    VoiceProc <--> TimerEngine
    VoiceProc <--> RoutineMgmt
    TimerEngine <--> RoutineMgmt
    TimerEngine <--> SessionAnalytics
    RoutineMgmt <--> ContextIntel
    RoutineMgmt <--> SessionAnalytics
    SessionAnalytics <--> UIVis
    ContextIntel <--> UIVis
    TimerEngine <--> UIVis
    
    %% External dependencies
    VoiceProc -.-> CloudLLM["Cloud LLM API"]
    ContextIntel -.-> LocService["Location Services"]
    RoutineMgmt -.-> CoreData["Core Data"]
    SessionAnalytics -.-> iCloud["iCloud Sync"]
    
    style VoiceProc fill:#f9d,stroke:#333,stroke-width:2px
    style TimerEngine fill:#9df,stroke:#333,stroke-width:2px
    style RoutineMgmt fill:#df9,stroke:#333,stroke-width:2px
    style SessionAnalytics fill:#fd9,stroke:#333,stroke-width:2px
    style ContextIntel fill:#d9f,stroke:#333,stroke-width:2px
    style UIVis fill:#9fd,stroke:#333,stroke-width:2px
    
    style CloudLLM fill:#ddd,stroke:#333,stroke-width:1px
    style LocService fill:#ddd,stroke:#333,stroke-width:1px
    style CoreData fill:#ddd,stroke:#333,stroke-width:1px
    style iCloud fill:#ddd,stroke:#333,stroke-width:1px

%% Domain Model for AI-Native Timer
classDiagram
    class User {
        +UUID id
        +PurchaseStatus status
        +Preferences preferences
        +Date createdDate
    }
    
    class Routine {
        +UUID id
        +String name
        +String description
        +String category
        +List~Phase~ phases
        +Date createdDate
        +Date modifiedDate
    }
    
    class Phase {
        +UUID id
        +String name
        +TimeInterval baseDuration
        +List~AdjustmentRule~ adjustmentRules
        +int position
        +int repeatCount
    }
    
    class Timer {
        +UUID id
        +UUID routineId
        +TimerState status
        +Date startTime
        +int currentPhaseIndex
        +TimeInterval elapsedTime
        +TimeInterval remainingTime
        +start()
        +pause()
        +resume()
        +stop()
    }
    
    class Session {
        +UUID id
        +UUID routineId
        +Date startTime
        +Date completionTime
        +CompletionStatus status
        +List~PhaseExecution~ phaseLog
        +List~ContextualFactor~ contextualFactors
    }
    
    class Schedule {
        +UUID id
        +UUID routineId
        +RecurrencePattern recurrence
        +Date startTime
        +boolean enabled
        +NotificationSettings notifications
    }
    
    class ContextualFactor {
        +FactorType type
        +Any value
    }
    
    class AdjustmentFactor {
        +TimeInterval baseValue
        +TimeInterval adjustedValue
        +double factorApplied
        +double confidence
        +String explanation
        +AdjustmentSource source
    }
    
    User "1" -- "many" Routine : creates
    Routine "1" -- "many" Phase : contains
    Routine "1" -- "many" Timer : used by
    Timer "1" -- "1" Session : generates
    Routine "1" -- "many" Schedule : can have
    Timer "many" -- "many" ContextualFactor : affected by
    Phase "1" -- "many" AdjustmentFactor : modified by
