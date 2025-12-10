# Laws of UX for iOS Development

> A comprehensive guide to UX principles for building iOS applications.
> Optimized for AI-assisted development with Claude Code, Cursor, Copilot, and similar tools.
>
> **Source:** [lawsofux.com](https://lawsofux.com) by Jon Yablonski
> **License:** [CC BY-NC-ND 4.0](https://creativecommons.org/licenses/by-nc-nd/4.0/)

---

## How to Use This Document

This document serves as a reference guide for AI coding assistants when developing iOS applications. Include relevant sections in your prompts or add this file to your project's context to ensure UX best practices are followed.

### Quick Reference for AI Prompts

```
When asking AI to build UI components, reference specific laws:
- "Following Fitts's Law, make the primary action button large and easily tappable"
- "Apply Miller's Law - limit the menu options to 5-7 items"
- "Use the Von Restorff Effect to make the CTA stand out"
```

---

## Table of Contents

1. [Core Heuristics](#1-core-heuristics)
2. [Gestalt Principles](#2-gestalt-principles)
3. [Cognitive Load & Memory](#3-cognitive-load--memory)
4. [Behavior & Motivation](#4-behavior--motivation)
5. [Perception & Attention](#5-perception--attention)
6. [System Design](#6-system-design)
7. [iOS-Specific Implementation Guide](#7-ios-specific-implementation-guide)
8. [Quick Reference Tables](#8-quick-reference-tables)
9. [Code Snippets & Patterns](#9-code-snippets--patterns)

---

## 1. Core Heuristics

### 1.1 Aesthetic-Usability Effect

> **Users often perceive aesthetically pleasing design as design that's more usable.**

#### Key Takeaways
- Aesthetically pleasing design creates a positive response in users' brains, leading them to believe the design works better
- Users are more tolerant of minor usability issues when the design is visually appealing
- Visual polish can mask usability problems—test thoroughly regardless of aesthetics

#### iOS Implementation

```swift
// GOOD: Polished, consistent visual design
struct ContentCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Consistent corner radius throughout app
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            
            // Consistent spacing and typography
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
        }
        .padding()
    }
}

// Use SF Symbols for consistent, polished iconography
Image(systemName: "checkmark.circle.fill")
    .symbolRenderingMode(.hierarchical)
    .foregroundStyle(.green)
```

#### Design Checklist
- [ ] Consistent corner radii (Apple recommends continuous corners)
- [ ] Proper use of SF Symbols with appropriate rendering modes
- [ ] Consistent spacing using multiples of 4 or 8 points
- [ ] Appropriate use of materials and blur effects
- [ ] Smooth animations with proper easing curves

---

### 1.2 Hick's Law

> **The time it takes to make a decision increases with the number and complexity of choices.**

#### Key Takeaways
- Minimize choices when response times are critical
- Break complex tasks into smaller steps to decrease cognitive load
- Highlight recommended options to avoid overwhelming users
- Use progressive onboarding for new users
- Don't simplify to the point of abstraction

#### iOS Implementation

```swift
// GOOD: Limited, clear choices with recommended option highlighted
struct PlanSelectionView: View {
    var body: some View {
        VStack(spacing: 16) {
            ForEach(plans) { plan in
                PlanCard(plan: plan, isRecommended: plan.id == "pro")
            }
        }
    }
}

// GOOD: Progressive disclosure with expandable sections
struct SettingsView: View {
    var body: some View {
        List {
            // Group related settings, hide advanced options
            Section("General") {
                // 3-5 most common settings
            }
            
            DisclosureGroup("Advanced") {
                // Less common settings revealed on demand
            }
        }
    }
}

// BAD: Too many options at once
struct BadMenuView: View {
    var body: some View {
        // 15+ menu items without grouping = decision paralysis
        List(allMenuItems) { item in
            MenuRow(item: item)
        }
    }
}
```

#### Guidelines
| Scenario | Max Options | Strategy |
|----------|-------------|----------|
| Tab Bar | 5 | iOS limit, prioritize core features |
| Action Sheet | 5-7 | Group with destructive at bottom |
| Settings Screen | 5-7 per section | Use sections and disclosure groups |
| Onboarding | 1 per screen | Progressive disclosure |

---

### 1.3 Fitts's Law

> **The time to acquire a target is a function of the distance to and size of the target.**

#### Key Takeaways
- Touch targets should be large enough for accurate selection
- Touch targets should have ample spacing between them
- Place interactive elements in easily reachable areas

#### iOS Implementation

```swift
// Apple's minimum touch target: 44x44 points
struct ProperButton: View {
    var body: some View {
        Button(action: { }) {
            Image(systemName: "plus")
                .font(.system(size: 17))
        }
        .frame(minWidth: 44, minHeight: 44) // Minimum touch target
    }
}

// For thumb-friendly design, consider reachability zones
struct ThumbFriendlyLayout: View {
    var body: some View {
        VStack {
            Spacer()
            
            // Primary actions at bottom, easily reachable by thumb
            HStack(spacing: 16) {
                Button("Secondary") { }
                    .frame(minHeight: 50)
                
                Button("Primary Action") { }
                    .frame(minHeight: 50)
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}

// Proper spacing between interactive elements
struct ButtonGroup: View {
    var body: some View {
        HStack(spacing: 12) { // Minimum 8pt spacing between targets
            ForEach(actions) { action in
                Button(action.title) { }
                    .frame(minWidth: 44, minHeight: 44)
            }
        }
    }
}
```

#### Touch Target Guidelines
| Element | Minimum Size | Recommended Size |
|---------|--------------|------------------|
| Buttons | 44x44 pt | 50x50 pt |
| List Rows | 44 pt height | 48-60 pt height |
| Icon Buttons | 44x44 pt | Include padding |
| Spacing | 8 pt | 12-16 pt |

#### Reachability Zones (iPhone)
```
┌─────────────────────────┐
│     Hard to Reach       │  <- Navigation, less frequent actions
│                         │
│     Natural Reach       │  <- Content, scrolling
│                         │
│     Easy Reach          │  <- Primary actions, tab bar
└─────────────────────────┘
        👍 Thumb
```

---

### 1.4 Jakob's Law

> **Users spend most of their time on other apps. They prefer your app to work the same way as the apps they already know.**

#### Key Takeaways
- Users transfer expectations from familiar apps to new ones
- Leverage existing mental models—don't reinvent standard interactions
- When making changes, allow users time to adapt with familiar alternatives

#### iOS Implementation

```swift
// GOOD: Follow iOS conventions
struct StandardNavigationView: View {
    var body: some View {
        NavigationStack {
            List(items) { item in
                NavigationLink(destination: DetailView(item: item)) {
                    ItemRow(item: item)
                }
            }
            .navigationTitle("Items")
            .toolbar {
                // Standard placement: trailing for primary action
                ToolbarItem(placement: .primaryAction) {
                    Button(action: addItem) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

// GOOD: Standard swipe actions users expect
struct SwipeableRow: View {
    var body: some View {
        Text(item.title)
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    delete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .swipeActions(edge: .leading) {
                Button {
                    toggleFavorite()
                } label: {
                    Label("Favorite", systemImage: "star")
                }
                .tint(.yellow)
            }
    }
}

// GOOD: Standard pull-to-refresh
struct RefreshableList: View {
    var body: some View {
        List(items) { item in
            ItemRow(item: item)
        }
        .refreshable {
            await loadData()
        }
    }
}
```

#### iOS Conventions to Follow
| Pattern | User Expectation | Implementation |
|---------|------------------|----------------|
| Navigation | Back button top-left | `NavigationStack` |
| Destructive Actions | Red, confirmation required | `.destructive` role |
| Pull to Refresh | Pull down to refresh | `.refreshable` modifier |
| Swipe Actions | Swipe to reveal actions | `.swipeActions` modifier |
| Tab Bar | Bottom navigation, 5 max | `TabView` |
| Search | Pull down or search bar | `.searchable` modifier |
| Share | Standard share sheet | `ShareLink` |

---

### 1.5 Miller's Law

> **The average person can only keep 7 (plus or minus 2) items in their working memory.**

#### Key Takeaways
- Don't use "magical number seven" to justify unnecessary limitations
- Organize content into smaller chunks for easier processing
- Short-term memory capacity varies based on context and prior knowledge

#### iOS Implementation

```swift
// GOOD: Chunked phone number input
struct PhoneNumberField: View {
    @State private var areaCode = ""
    @State private var prefix = ""
    @State private var lineNumber = ""
    
    var body: some View {
        HStack(spacing: 8) {
            TextField("555", text: $areaCode)
                .frame(width: 50)
            Text("-")
            TextField("123", text: $prefix)
                .frame(width: 50)
            Text("-")
            TextField("4567", text: $lineNumber)
                .frame(width: 60)
        }
        .keyboardType(.numberPad)
    }
}

// GOOD: Grouped settings
struct SettingsView: View {
    var body: some View {
        List {
            Section("Account") {
                // 3-4 items max per section
                NavigationLink("Profile") { ProfileView() }
                NavigationLink("Security") { SecurityView() }
                NavigationLink("Privacy") { PrivacyView() }
            }
            
            Section("Preferences") {
                NavigationLink("Notifications") { NotificationsView() }
                NavigationLink("Appearance") { AppearanceView() }
                NavigationLink("Language") { LanguageView() }
            }
            
            Section("Support") {
                NavigationLink("Help Center") { HelpView() }
                NavigationLink("Contact Us") { ContactView() }
            }
        }
    }
}

// GOOD: Chunked verification code input
struct VerificationCodeInput: View {
    @State private var code: [String] = Array(repeating: "", count: 6)
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<6, id: \.self) { index in
                SingleDigitField(text: $code[index])
                    .frame(width: 44, height: 52)
                
                // Visual separator after 3rd digit
                if index == 2 {
                    Text("—")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
```

#### Chunking Guidelines
| Content Type | Chunk Size | Example |
|--------------|------------|---------|
| Phone Numbers | 3-4 digits | 555-123-4567 |
| Credit Cards | 4 digits | 1234 5678 9012 3456 |
| Verification Codes | 3 digits | 123-456 |
| Menu Items | 5-7 items | Per section |
| Onboarding Steps | 3-5 steps | With progress indicator |

---

### 1.6 Occam's Razor

> **Among competing hypotheses that predict equally well, the one with the fewest assumptions should be selected.**

#### Key Takeaways
- The best method for reducing complexity is to avoid it in the first place
- Analyze each element and remove as many as possible without compromising function
- Consider completion only when no additional items can be removed

#### iOS Implementation

```swift
// GOOD: Simple, focused interface
struct SimpleTaskView: View {
    @State private var taskTitle = ""
    
    var body: some View {
        VStack(spacing: 20) {
            TextField("What needs to be done?", text: $taskTitle)
                .textFieldStyle(.roundedBorder)
            
            Button("Add Task") {
                addTask()
            }
            .buttonStyle(.borderedProminent)
            .disabled(taskTitle.isEmpty)
        }
        .padding()
    }
}

// BAD: Overloaded with unnecessary options
struct OvercomplicatedTaskView: View {
    var body: some View {
        VStack {
            TextField("Task", text: $taskTitle)
            TextField("Description", text: $description)
            DatePicker("Due Date", selection: $dueDate)
            Picker("Priority", selection: $priority) { ... }
            Picker("Category", selection: $category) { ... }
            Picker("Assignee", selection: $assignee) { ... }
            Toggle("Recurring", isOn: $isRecurring)
            ColorPicker("Color", selection: $color)
            // Too much for simple task creation!
        }
    }
}

// GOOD: Progressive complexity - start simple, reveal more on demand
struct SmartTaskView: View {
    @State private var showAdvanced = false
    
    var body: some View {
        VStack {
            // Essential fields always visible
            TextField("What needs to be done?", text: $taskTitle)
            
            // Advanced options hidden by default
            DisclosureGroup("More Options", isExpanded: $showAdvanced) {
                DatePicker("Due Date", selection: $dueDate)
                Picker("Priority", selection: $priority) { ... }
            }
            
            Button("Add Task") { addTask() }
        }
    }
}
```

#### Simplification Checklist
- [ ] Can this feature be removed without hurting core functionality?
- [ ] Can this be progressive disclosure instead of always visible?
- [ ] Is there a simpler way to achieve the same goal?
- [ ] Would a new user understand this immediately?

---

### 1.7 Pareto Principle (80/20 Rule)

> **For many events, roughly 80% of the effects come from 20% of the causes.**

#### Key Takeaways
- Inputs and outputs are often not evenly distributed
- Focus the majority of effort on areas that benefit the most users
- Identify and optimize the critical 20% of features

#### iOS Implementation

```swift
// Focus on the 20% of features used 80% of the time
struct OptimizedHomeView: View {
    var body: some View {
        VStack {
            // Most used features prominently displayed
            QuickActionsGrid() // The 20% - optimize these heavily
            
            // Less used features accessible but not prominent
            NavigationLink("All Features") {
                FullFeatureList() // The 80% - functional but less polished
            }
        }
    }
}

// Optimize the critical path
struct CheckoutFlow: View {
    var body: some View {
        // This is a high-value flow - invest heavily here
        // - Fast loading
        // - Error prevention
        // - Clear feedback
        // - Minimal steps
    }
}
```

#### Application Strategy
| Focus Area | Investment | Rationale |
|------------|------------|-----------|
| Core Features | High | Used by most users, most often |
| Onboarding | High | First impression, retention impact |
| Error States | Medium | Prevent frustration |
| Edge Cases | Low | Rare scenarios |
| Power User Features | Low | Small audience |

---

### 1.8 Parkinson's Law

> **Any task will inflate until all of the available time is spent.**

#### Key Takeaways
- Limit task completion time to user expectations
- Use autofill and smart defaults to reduce time spent
- Reducing actual duration from expected duration improves UX

#### iOS Implementation

```swift
// GOOD: Autofill and smart defaults reduce time
struct SmartFormView: View {
    @State private var email = ""
    @State private var name = ""
    
    var body: some View {
        Form {
            TextField("Email", text: $email)
                .textContentType(.emailAddress) // Enable autofill
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
            
            TextField("Full Name", text: $name)
                .textContentType(.name) // Enable autofill
            
            // Pre-filled based on location
            TextField("Country", text: $country)
                .onAppear {
                    country = Locale.current.region?.identifier ?? ""
                }
        }
    }
}

// GOOD: Quick actions reduce task time
struct QuickAddView: View {
    var body: some View {
        HStack {
            // One-tap common actions
            Button("Add Photo") { addPhoto() }
            Button("Add Location") { addLocation() }
            Button("Add Note") { addNote() }
        }
    }
}

// Use .textContentType for autofill
TextField("Address", text: $address)
    .textContentType(.fullStreetAddress)

TextField("Credit Card", text: $cardNumber)
    .textContentType(.creditCardNumber)
```

#### Time-Saving Patterns
| Pattern | Implementation | Time Saved |
|---------|----------------|------------|
| Autofill | `.textContentType()` | 10-30 seconds |
| Smart Defaults | Pre-populated fields | 5-15 seconds |
| Recent Items | Show history | 5-20 seconds |
| One-Tap Actions | Quick action buttons | 3-10 seconds |
| Biometrics | Face ID/Touch ID | 5-10 seconds |

---

## 2. Gestalt Principles

### 2.1 Law of Proximity

> **Objects that are near, or proximate to each other, tend to be grouped together.**

#### Key Takeaways
- Proximity establishes relationships between elements
- Elements in close proximity are perceived as sharing similar functionality
- Proper spacing helps users understand information hierarchy

#### iOS Implementation

```swift
// GOOD: Related elements grouped with proximity
struct ProductCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Tight spacing = related content
            Text(product.name)
                .font(.headline)
            Text(product.price)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.bottom, 16) // More space separates from next group
        
        VStack(alignment: .leading, spacing: 4) {
            // Another related group
            Text("Description")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(product.description)
                .font(.body)
        }
    }
}

// GOOD: Form sections with proper spacing
struct FormView: View {
    var body: some View {
        VStack(spacing: 24) { // Large spacing between sections
            
            VStack(alignment: .leading, spacing: 8) { // Small spacing within section
                Text("Personal Information")
                    .font(.headline)
                TextField("Name", text: $name)
                TextField("Email", text: $email)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Address")
                    .font(.headline)
                TextField("Street", text: $street)
                TextField("City", text: $city)
            }
        }
    }
}
```

#### Spacing Guidelines
| Relationship | Spacing | Use Case |
|--------------|---------|----------|
| Tightly Related | 4-8 pt | Label + value, title + subtitle |
| Related | 12-16 pt | Items in a group |
| Separate Groups | 24-32 pt | Different sections |
| Major Sections | 40+ pt | Page sections |

---

### 2.2 Law of Similarity

> **The human eye tends to perceive similar elements as a complete picture, shape, or group, even if those elements are separated.**

#### Key Takeaways
- Visually similar elements are perceived as related
- Color, shape, size, and style signal grouping
- Ensure links and actions are visually differentiated from content

#### iOS Implementation

```swift
// GOOD: Consistent styling for similar elements
struct ActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray5))
            .foregroundColor(.primary)
            .cornerRadius(8)
    }
}

// All primary actions look the same
Button("Save") { }.buttonStyle(ActionButtonStyle())
Button("Submit") { }.buttonStyle(ActionButtonStyle())
Button("Confirm") { }.buttonStyle(ActionButtonStyle())

// All secondary actions look the same
Button("Cancel") { }.buttonStyle(SecondaryButtonStyle())
Button("Skip") { }.buttonStyle(SecondaryButtonStyle())

// GOOD: Consistent card styling
struct StandardCard: View {
    var body: some View {
        content
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}
```

#### Similarity Guidelines
| Element Type | Consistent Properties |
|--------------|----------------------|
| Primary Buttons | Color, size, corner radius |
| Secondary Buttons | Different color, same size/radius |
| Cards | Corner radius, shadow, padding |
| Icons | Size, weight, color |
| Error States | Red color, similar icon style |
| Success States | Green color, similar icon style |

---

### 2.3 Law of Common Region

> **Elements tend to be perceived as groups if they share an area with a clearly defined boundary.**

#### Key Takeaways
- Common region creates clear structure
- Borders and backgrounds define groups
- Helps users quickly understand relationships

#### iOS Implementation

```swift
// GOOD: Cards create common regions
struct GroupedContent: View {
    var body: some View {
        VStack(spacing: 16) {
            // Card creates a common region
            VStack(alignment: .leading, spacing: 8) {
                Text("Account")
                    .font(.headline)
                Text("John Doe")
                Text("john@example.com")
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            
            // Another common region
            VStack(alignment: .leading, spacing: 8) {
                Text("Subscription")
                    .font(.headline)
                Text("Pro Plan")
                Text("Renews Dec 2025")
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

// GOOD: Using List sections for grouping
struct SettingsView: View {
    var body: some View {
        List {
            Section {
                // Items in this section are grouped by iOS
                NavigationLink("Profile") { }
                NavigationLink("Account") { }
            } header: {
                Text("Account Settings")
            }
            
            Section {
                NavigationLink("Notifications") { }
                NavigationLink("Privacy") { }
            } header: {
                Text("App Settings")
            }
        }
        .listStyle(.insetGrouped) // Creates clear visual regions
    }
}
```

---

### 2.4 Law of Uniform Connectedness

> **Elements that are visually connected are perceived as more related than elements with no connection.**

#### Key Takeaways
- Use lines, arrows, or visual connections to show relationships
- Connected elements are perceived as a unit
- Useful for step indicators and flows

#### iOS Implementation

```swift
// GOOD: Connected step indicator
struct StepIndicator: View {
    let totalSteps: Int
    let currentStep: Int
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<totalSteps, id: \.self) { step in
                // Step circle
                Circle()
                    .fill(step <= currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Text("\(step + 1)")
                            .font(.caption2)
                            .foregroundColor(step <= currentStep ? .white : .gray)
                    )
                
                // Connecting line (except after last step)
                if step < totalSteps - 1 {
                    Rectangle()
                        .fill(step < currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal)
    }
}

// GOOD: Timeline with connected events
struct TimelineView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(events.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 12) {
                    // Vertical connecting line
                    VStack(spacing: 0) {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 12, height: 12)
                        
                        if index < events.count - 1 {
                            Rectangle()
                                .fill(Color.accentColor.opacity(0.3))
                                .frame(width: 2)
                                .frame(height: 60)
                        }
                    }
                    
                    // Event content
                    EventCard(event: events[index])
                }
            }
        }
    }
}
```

---

### 2.5 Law of Prägnanz (Simplicity)

> **People will perceive and interpret ambiguous or complex images as the simplest form possible.**

#### Key Takeaways
- The human eye finds simplicity and order in complex shapes
- Simple figures are better processed and remembered
- Design with basic, recognizable shapes

#### iOS Implementation

```swift
// GOOD: Simple, recognizable icons
struct SimpleIcon: View {
    var body: some View {
        // SF Symbols are designed for simplicity
        Image(systemName: "house.fill")
            .font(.system(size: 24))
        
        // Simple custom shapes
        Circle()
            .fill(Color.accentColor)
            .frame(width: 40, height: 40)
            .overlay(
                Image(systemName: "plus")
                    .foregroundColor(.white)
            )
    }
}

// GOOD: Simple loading indicator
struct SimpleLoader: View {
    var body: some View {
        ProgressView()
            .progressViewStyle(.circular)
        // Not a complex custom animation
    }
}

// GOOD: Simple, clear status indicators
struct StatusIndicator: View {
    let status: Status
    
    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: 8, height: 8)
    }
}
```

---

## 3. Cognitive Load & Memory

### 3.1 Cognitive Load

> **The amount of mental resources needed to understand and interact with an interface.**

#### Types of Cognitive Load
- **Intrinsic:** Effort to carry information and track goals
- **Extraneous:** Mental processing from unnecessary design elements

#### iOS Implementation

```swift
// GOOD: Reduce extraneous cognitive load
struct CleanInterface: View {
    var body: some View {
        VStack(spacing: 20) {
            // Clear, single focus
            Text("What would you like to do?")
                .font(.title2)
            
            // Limited, clear options
            ForEach(mainActions) { action in
                ActionButton(action: action)
            }
        }
        .padding()
    }
}

// BAD: High cognitive load
struct ClutteredInterface: View {
    var body: some View {
        VStack {
            // Multiple competing elements
            BannerAd()
            NotificationBadge()
            PromoCard()
            FeatureAnnouncement()
            // User doesn't know where to focus
            MainContent()
            RecommendationCarousel()
            SocialProof()
        }
    }
}

// GOOD: Progressive disclosure reduces cognitive load
struct ProgressiveSettings: View {
    var body: some View {
        List {
            // Show only what's needed
            Section("Frequently Used") {
                Toggle("Notifications", isOn: $notifications)
                Toggle("Dark Mode", isOn: $darkMode)
            }
            
            // Hide complexity
            NavigationLink("Advanced Settings") {
                AdvancedSettingsView()
            }
        }
    }
}
```

#### Cognitive Load Reduction Strategies
| Strategy | Implementation |
|----------|----------------|
| Progressive Disclosure | `DisclosureGroup`, Navigation |
| Chunking | Group related items |
| Consistency | Reusable components |
| Recognition over Recall | Show options, don't make users remember |
| Remove Distractions | Minimal, focused interfaces |

---

### 3.2 Chunking

> **Breaking down information into smaller, meaningful groups.**

#### iOS Implementation

```swift
// GOOD: Chunked credit card input
struct CreditCardInput: View {
    @State private var chunks: [String] = ["", "", "", ""]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                TextField("0000", text: $chunks[index])
                    .frame(width: 60)
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .onChange(of: chunks[index]) { newValue in
                        // Auto-advance to next field
                        if newValue.count == 4 && index < 3 {
                            // Focus next field
                        }
                    }
            }
        }
    }
}

// GOOD: Chunked content in lists
struct ChunkedList: View {
    var body: some View {
        List {
            Section("Today") {
                ForEach(todayItems) { item in
                    ItemRow(item: item)
                }
            }
            
            Section("This Week") {
                ForEach(weekItems) { item in
                    ItemRow(item: item)
                }
            }
            
            Section("Earlier") {
                ForEach(earlierItems) { item in
                    ItemRow(item: item)
                }
            }
        }
    }
}
```

---

### 3.3 Working Memory

> **A cognitive system that temporarily holds 4-7 items for 20-30 seconds.**

#### Key Takeaways
- Support recognition over recall
- Carry information forward through flows
- Don't rely on users remembering previous screens

#### iOS Implementation

```swift
// GOOD: Show selected items throughout flow
struct CheckoutFlow: View {
    let selectedItems: [Item]
    
    var body: some View {
        VStack {
            // Always show what user selected
            ScrollView(.horizontal) {
                HStack {
                    ForEach(selectedItems) { item in
                        ItemThumbnail(item: item)
                    }
                }
            }
            .frame(height: 80)
            
            // Checkout form
            CheckoutForm()
        }
    }
}

// GOOD: Persist search/filter state
struct SearchableList: View {
    @State private var searchText = ""
    @State private var selectedFilters: Set<Filter> = []
    
    var body: some View {
        VStack {
            // Show active filters (recognition over recall)
            if !selectedFilters.isEmpty {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(Array(selectedFilters)) { filter in
                            FilterChip(filter: filter) {
                                selectedFilters.remove(filter)
                            }
                        }
                    }
                }
            }
            
            List(filteredItems) { item in
                ItemRow(item: item)
            }
        }
        .searchable(text: $searchText)
    }
}

// GOOD: Breadcrumbs for deep navigation
struct DeepNavigation: View {
    var body: some View {
        VStack(alignment: .leading) {
            // Show path taken
            HStack {
                Text("Home")
                Image(systemName: "chevron.right")
                Text("Category")
                Image(systemName: "chevron.right")
                Text("Subcategory")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            // Current content
            ContentView()
        }
    }
}
```

---

### 3.4 Mental Model

> **A user's compressed understanding of how a system works.**

#### Key Takeaways
- Match design to users' existing mental models
- Use familiar patterns and metaphors
- Bridge the gap between your model and the user's model

#### iOS Implementation

```swift
// GOOD: Follows email mental model
struct MailboxView: View {
    var body: some View {
        List {
            NavigationLink("Inbox", destination: InboxView())
            NavigationLink("Sent", destination: SentView())
            NavigationLink("Drafts", destination: DraftsView())
            NavigationLink("Trash", destination: TrashView())
        }
        // Users expect these standard categories
    }
}

// GOOD: Shopping cart follows e-commerce mental model
struct CartView: View {
    var body: some View {
        VStack {
            // Items in cart (like physical shopping)
            List(cartItems) { item in
                CartItemRow(item: item)
            }
            
            // Subtotal, like receipt
            VStack {
                HStack {
                    Text("Subtotal")
                    Spacer()
                    Text(subtotal, format: .currency(code: "USD"))
                }
                HStack {
                    Text("Shipping")
                    Spacer()
                    Text(shipping, format: .currency(code: "USD"))
                }
                Divider()
                HStack {
                    Text("Total").bold()
                    Spacer()
                    Text(total, format: .currency(code: "USD")).bold()
                }
            }
            .padding()
            
            // Checkout button
            Button("Checkout") { }
                .buttonStyle(.borderedProminent)
        }
    }
}
```

---

## 4. Behavior & Motivation

### 4.1 Goal-Gradient Effect

> **The tendency to approach a goal increases with proximity to the goal.**

#### iOS Implementation

```swift
// GOOD: Progress indicator that motivates
struct ProfileCompletionView: View {
    let completedSteps: Int
    let totalSteps: Int
    
    var progress: Double {
        Double(completedSteps) / Double(totalSteps)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Profile \(Int(progress * 100))% complete")
                    .font(.headline)
                Spacer()
                Text("\(completedSteps)/\(totalSteps)")
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: progress)
                .tint(.accentColor)
            
            // Show next step to complete
            if completedSteps < totalSteps {
                Button("Complete: Add profile photo") {
                    // Next action
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// GOOD: Onboarding with progress
struct OnboardingFlow: View {
    @State private var currentStep = 0
    let totalSteps = 4
    
    var body: some View {
        VStack {
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { step in
                    Circle()
                        .fill(step <= currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            
            // Current step content
            OnboardingStep(step: currentStep)
            
            // Show "Almost done!" when close
            if currentStep >= totalSteps - 2 {
                Text("Almost done!")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
        }
    }
}

// GOOD: Give users a head start (artificial progress)
struct LoyaltyCard: View {
    var body: some View {
        VStack {
            Text("2/10 stamps collected")
            
            HStack(spacing: 8) {
                // 2 stamps already filled = head start
                ForEach(0..<10, id: \.self) { i in
                    Circle()
                        .fill(i < 2 ? Color.accentColor : Color.gray.opacity(0.2))
                        .frame(width: 30, height: 30)
                }
            }
            
            Text("8 more for a free drink!")
                .font(.caption)
        }
    }
}
```

---

### 4.2 Zeigarnik Effect

> **People remember uncompleted tasks better than completed tasks.**

#### iOS Implementation

```swift
// GOOD: Show incomplete tasks prominently
struct TaskDashboard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Incomplete tasks highlighted
            if !incompleteTasks.isEmpty {
                VStack(alignment: .leading) {
                    Text("Continue where you left off")
                        .font(.headline)
                    
                    ForEach(incompleteTasks.prefix(3)) { task in
                        IncompleteTaskCard(task: task)
                    }
                }
            }
            
            // Completed tasks less prominent
            Section("Completed") {
                ForEach(completedTasks) { task in
                    CompletedTaskRow(task: task)
                }
            }
        }
    }
}

// GOOD: Draft indicator
struct DocumentsList: View {
    var body: some View {
        List {
            if !drafts.isEmpty {
                Section("Drafts") {
                    ForEach(drafts) { draft in
                        HStack {
                            Image(systemName: "doc.badge.ellipsis")
                                .foregroundColor(.orange)
                            Text(draft.title)
                            Spacer()
                            Text("Continue")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
            
            Section("Documents") {
                ForEach(documents) { doc in
                    DocumentRow(document: doc)
                }
            }
        }
    }
}
```

---

### 4.3 Peak-End Rule

> **People judge an experience based on how they felt at its peak and at its end, rather than the average.**

#### iOS Implementation

```swift
// GOOD: Celebrate completion (positive end)
struct CompletionView: View {
    var body: some View {
        VStack(spacing: 24) {
            // Celebratory visual
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("You're all set!")
                .font(.title)
                .bold()
            
            Text("Your order is confirmed and on its way.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Optional: confetti animation
        }
        .padding()
    }
}

// GOOD: Handle errors gracefully (avoid negative peak)
struct ErrorRecoveryView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Something went wrong")
                .font(.headline)
            
            Text("Don't worry, your progress has been saved.")
                .foregroundColor(.secondary)
            
            Button("Try Again") {
                retry()
            }
            .buttonStyle(.borderedProminent)
            
            Button("Contact Support") {
                contactSupport()
            }
        }
    }
}

// GOOD: Delightful micro-interactions at key moments
struct LikeButton: View {
    @State private var isLiked = false
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isLiked.toggle()
            }
            // Haptic feedback at peak moment
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        } label: {
            Image(systemName: isLiked ? "heart.fill" : "heart")
                .foregroundColor(isLiked ? .red : .gray)
                .scaleEffect(isLiked ? 1.2 : 1.0)
        }
    }
}
```

---

### 4.4 Paradox of the Active User

> **Users never read manuals but start using software immediately.**

#### iOS Implementation

```swift
// GOOD: Contextual hints, not upfront tutorials
struct ContextualHint: View {
    @State private var showHint = true
    
    var body: some View {
        VStack {
            ContentView()
            
            // Show hint in context when relevant
            if showHint {
                HStack {
                    Image(systemName: "lightbulb")
                    Text("Tip: Swipe left to delete items")
                    Spacer()
                    Button("Got it") {
                        showHint = false
                    }
                }
                .padding()
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
}

// GOOD: Tooltips on first use
struct FirstTimeTooltip: ViewModifier {
    let key: String
    let message: String
    @State private var showTooltip = false
    
    func body(content: Content) -> some View {
        content
            .popover(isPresented: $showTooltip) {
                Text(message)
                    .padding()
            }
            .onAppear {
                if !UserDefaults.standard.bool(forKey: "tooltip_\(key)") {
                    showTooltip = true
                    UserDefaults.standard.set(true, forKey: "tooltip_\(key)")
                }
            }
    }
}

// GOOD: Empty states as teaching moments
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No items yet")
                .font(.headline)
            
            Text("Tap the + button to add your first item")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Add Item") {
                addFirstItem()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
```

---

### 4.5 Flow State

> **The mental state of complete immersion in an activity with energized focus and enjoyment.**

#### iOS Implementation

```swift
// GOOD: Remove distractions during focused tasks
struct FocusedWritingView: View {
    @State private var text = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        TextEditor(text: $text)
            .padding()
            .navigationBarHidden(true)
            .statusBarHidden(true)
            .overlay(alignment: .topTrailing) {
                Button("Done") {
                    dismiss()
                }
                .padding()
            }
    }
}

// GOOD: Provide immediate feedback
struct InteractiveForm: View {
    @State private var email = ""
    @State private var isValidEmail = false
    
    var body: some View {
        HStack {
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .onChange(of: email) { newValue in
                    // Immediate validation feedback
                    isValidEmail = isValidEmailFormat(newValue)
                }
            
            if isValidEmail {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
    }
}

// GOOD: Match challenge to skill level
struct DifficultyProgression: View {
    @State private var currentLevel = 1
    
    var body: some View {
        // Gradually increase complexity
        switch currentLevel {
        case 1:
            BeginnerChallengeView()
        case 2:
            IntermediateChallengeView()
        default:
            AdvancedChallengeView()
        }
    }
}
```

---

## 5. Perception & Attention

### 5.1 Serial Position Effect

> **Users best remember the first and last items in a series.**

#### iOS Implementation

```swift
// GOOD: Important items at start and end of tab bar
struct MainTabView: View {
    var body: some View {
        TabView {
            // First position - most important
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            
            // Middle positions - secondary features
            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
            
            FavoritesView()
                .tabItem {
                    Label("Favorites", systemImage: "heart")
                }
            
            // Last position - important (profile/settings)
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
        }
    }
}

// GOOD: Key actions at edges of toolbar
struct ContentView: View {
    var body: some View {
        NavigationStack {
            content
                .toolbar {
                    // Left edge - navigation (highly remembered)
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Back") { }
                    }
                    
                    // Right edge - primary action (highly remembered)
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") { }
                    }
                }
        }
    }
}

// GOOD: Important info at start and end of lists
struct PricingList: View {
    var body: some View {
        VStack(spacing: 16) {
            // First - hook them
            PlanCard(plan: .starter, highlight: "Most Popular")
            
            // Middle - other options
            PlanCard(plan: .basic)
            PlanCard(plan: .standard)
            
            // Last - memorable premium option
            PlanCard(plan: .premium, highlight: "Best Value")
        }
    }
}
```

---

### 5.2 Von Restorff Effect (Isolation Effect)

> **When multiple similar objects are present, the one that differs is most likely to be remembered.**

#### iOS Implementation

```swift
// GOOD: Highlight recommended option
struct PricingView: View {
    var body: some View {
        HStack(spacing: 12) {
            // Standard cards
            PlanCard(plan: .basic)
            
            // Highlighted card - different
            VStack {
                Text("RECOMMENDED")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.accentColor)
                    .cornerRadius(12)
                
                PlanCard(plan: .pro)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.accentColor, lineWidth: 3)
                    )
            }
            
            PlanCard(plan: .enterprise)
        }
    }
}

// GOOD: Make primary CTA stand out
struct ActionButtons: View {
    var body: some View {
        VStack(spacing: 12) {
            // Primary - visually distinct
            Button("Get Started") {
                startOnboarding()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            // Secondary - less prominent
            Button("Learn More") {
                showInfo()
            }
            .buttonStyle(.bordered)
        }
    }
}

// GOOD: Highlight new or important items
struct NotificationList: View {
    var body: some View {
        List(notifications) { notification in
            HStack {
                if notification.isUnread {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 8, height: 8)
                }
                
                NotificationRow(notification: notification)
            }
            .listRowBackground(
                notification.isUnread ? Color.accentColor.opacity(0.1) : Color.clear
            )
        }
    }
}
```

---

### 5.3 Selective Attention

> **Focusing attention on a subset of stimuli—usually those related to our goals.**

#### Key Takeaways
- **Banner Blindness:** Users ignore banner-like content
- **Change Blindness:** Significant changes go unnoticed without cues

#### iOS Implementation

```swift
// GOOD: Don't put important content in banner-like positions
struct ContentView: View {
    var body: some View {
        VStack {
            // AVOID: Important info in banner position
            // ImportantMessageBanner() // Users will ignore this
            
            // BETTER: Integrate important info with content
            List {
                // Important message as list item
                ImportantMessageRow()
                    .listRowBackground(Color.orange.opacity(0.1))
                
                ForEach(items) { item in
                    ItemRow(item: item)
                }
            }
        }
    }
}

// GOOD: Animate changes to prevent change blindness
struct AnimatedUpdate: View {
    @State private var count = 0
    
    var body: some View {
        HStack {
            Text("Items: ")
            Text("\(count)")
                .contentTransition(.numericText()) // Animate number changes
        }
    }
}

// GOOD: Draw attention to important changes
struct NotificationBadge: View {
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "bell")
                .font(.system(size: 24))
            
            // Badge draws attention
            Text("3")
                .font(.caption2)
                .foregroundColor(.white)
                .padding(4)
                .background(Color.red)
                .clipShape(Circle())
                .offset(x: 8, y: -8)
        }
    }
}
```

---

### 5.4 Cognitive Bias

> **Systematic errors in thinking that influence perception and decision-making.**

#### iOS Implementation

```swift
// GOOD: Use defaults wisely (default bias)
struct SubscriptionView: View {
    @State private var selectedPlan = "yearly" // Default to preferred option
    
    var body: some View {
        Picker("Plan", selection: $selectedPlan) {
            Text("Monthly - $9.99").tag("monthly")
            Text("Yearly - $79.99 (Save 33%)").tag("yearly") // Pre-selected
        }
    }
}

// GOOD: Social proof (bandwagon effect)
struct ProductView: View {
    var body: some View {
        VStack {
            Text(product.name)
            
            // Social proof
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("4.8 (2,459 reviews)")
                    .font(.caption)
            }
            
            Text("Join 50,000+ happy customers")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// GOOD: Scarcity (loss aversion) - use ethically
struct LimitedOfferView: View {
    var body: some View {
        VStack {
            Text("Limited Time Offer")
                .font(.headline)
                .foregroundColor(.red)
            
            // Only if genuinely limited
            if remainingStock < 10 {
                Text("Only \(remainingStock) left!")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
}

// GOOD: Anchoring effect for pricing
struct PricingComparison: View {
    var body: some View {
        VStack {
            // Higher price as anchor
            Text("$199")
                .strikethrough()
                .foregroundColor(.secondary)
            
            // Discounted price seems better
            Text("$99")
                .font(.title)
                .bold()
                .foregroundColor(.green)
            
            Text("50% off")
                .foregroundColor(.green)
        }
    }
}
```

---

## 6. System Design

### 6.1 Doherty Threshold

> **Productivity soars when response time is under 400ms.**

#### Response Time Guidelines
| Duration | Perception | Action Required |
|----------|------------|-----------------|
| < 100ms | Instantaneous | None |
| < 400ms | Optimal | None |
| < 1s | Flow maintained | None |
| < 10s | Attention held | Progress indicator |
| > 10s | Context lost | Background + notification |

#### iOS Implementation

```swift
// GOOD: Optimistic UI updates (instant feedback)
struct LikeButton: View {
    @State private var isLiked = false
    
    var body: some View {
        Button {
            // Optimistic update - instant feedback
            isLiked.toggle()
            
            // Haptic feedback
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            
            // Actual API call in background
            Task {
                do {
                    try await api.toggleLike()
                } catch {
                    // Revert on failure
                    isLiked.toggle()
                }
            }
        } label: {
            Image(systemName: isLiked ? "heart.fill" : "heart")
                .foregroundColor(isLiked ? .red : .gray)
        }
    }
}

// GOOD: Skeleton loading for perceived performance
struct SkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(height: 200)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 200, height: 20)
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 150, height: 16)
        }
        .shimmering() // Add shimmer animation
    }
}

// GOOD: Progress indication for longer operations
struct UploadView: View {
    @State private var uploadProgress: Double = 0
    
    var body: some View {
        VStack {
            ProgressView(value: uploadProgress)
            Text("\(Int(uploadProgress * 100))%")
        }
    }
}

// GOOD: Prefetch data for perceived speed
struct ContentList: View {
    @StateObject private var viewModel = ContentViewModel()
    
    var body: some View {
        List(viewModel.items) { item in
            ContentRow(item: item)
                .onAppear {
                    // Prefetch when item appears
                    viewModel.prefetchIfNeeded(for: item)
                }
        }
    }
}
```

---

### 6.2 Tesler's Law (Conservation of Complexity)

> **Every system has inherent complexity that cannot be reduced—only moved between system and user.**

#### iOS Implementation

```swift
// GOOD: System handles complexity, not user
struct SmartAddressForm: View {
    @State private var address = ""
    @State private var suggestions: [Address] = []
    
    var body: some View {
        VStack {
            TextField("Address", text: $address)
                .onChange(of: address) { newValue in
                    // System handles address lookup complexity
                    fetchAddressSuggestions(newValue)
                }
            
            // Auto-complete suggestions
            ForEach(suggestions) { suggestion in
                Button(suggestion.formatted) {
                    // System auto-fills all fields
                    applyAddress(suggestion)
                }
            }
        }
    }
}

// GOOD: Smart defaults reduce user decisions
struct NewEventView: View {
    @State private var date = Date()
    @State private var duration = 60 // Default 1 hour
    @State private var reminder = 15 // Default 15 min before
    
    var body: some View {
        Form {
            DatePicker("When", selection: $date)
            
            // Pre-filled with smart defaults
            Picker("Duration", selection: $duration) {
                Text("30 min").tag(30)
                Text("1 hour").tag(60) // Default
                Text("2 hours").tag(120)
            }
        }
    }
}

// GOOD: Wizard pattern for complex tasks
struct OnboardingWizard: View {
    @State private var step = 0
    
    var body: some View {
        VStack {
            // Break complexity into manageable steps
            switch step {
            case 0:
                AccountStep(onNext: { step = 1 })
            case 1:
                PreferencesStep(onNext: { step = 2 })
            case 2:
                PersonalizationStep(onComplete: { finish() })
            default:
                EmptyView()
            }
        }
    }
}
```

---

### 6.3 Postel's Law (Robustness Principle)

> **Be liberal in what you accept, and conservative in what you send.**

#### iOS Implementation

```swift
// GOOD: Accept various input formats
struct FlexibleDateInput: View {
    @State private var dateText = ""
    @State private var parsedDate: Date?
    
    var body: some View {
        TextField("Date (e.g., Dec 25, 12/25, tomorrow)", text: $dateText)
            .onChange(of: dateText) { newValue in
                // Accept multiple formats
                parsedDate = parseFlexibleDate(newValue)
            }
    }
    
    func parseFlexibleDate(_ text: String) -> Date? {
        let formatters = [
            "MM/dd/yyyy",
            "MM-dd-yyyy",
            "MMM d, yyyy",
            "MMMM d, yyyy",
            "yyyy-MM-dd"
        ]
        
        // Try each format
        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            if let date = formatter.date(from: text) {
                return date
            }
        }
        
        // Try natural language
        if text.lowercased() == "today" { return Date() }
        if text.lowercased() == "tomorrow" { return Calendar.current.date(byAdding: .day, value: 1, to: Date()) }
        
        return nil
    }
}

// GOOD: Accept various phone formats
struct PhoneInput: View {
    @State private var phone = ""
    
    var formattedPhone: String {
        // Accept: 5551234567, 555-123-4567, (555) 123-4567, +1 555 123 4567
        let digits = phone.filter { $0.isNumber }
        return formatPhoneNumber(digits)
    }
    
    var body: some View {
        TextField("Phone", text: $phone)
            .keyboardType(.phonePad)
            .onChange(of: phone) { _ in
                // Auto-format as user types
                phone = formattedPhone
            }
    }
}

// GOOD: Helpful error messages with suggestions
struct ValidationError: View {
    let error: ValidationError
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "exclamationmark.circle")
                Text(error.message)
            }
            .foregroundColor(.red)
            
            if let suggestion = error.suggestion {
                Text("Did you mean: \(suggestion)?")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
```

---

### 6.4 Choice Overload

> **Too many options leads to decision paralysis and reduced satisfaction.**

#### iOS Implementation

```swift
// GOOD: Curated options with "See All"
struct FilteredOptions: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("Popular Categories")
                .font(.headline)
            
            // Show only top 5-6 options
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))]) {
                ForEach(topCategories.prefix(6)) { category in
                    CategoryButton(category: category)
                }
            }
            
            // Option to see more
            NavigationLink("See All Categories") {
                AllCategoriesView()
            }
            .font(.subheadline)
        }
    }
}

// GOOD: Smart filtering reduces choices
struct ProductFilter: View {
    @State private var priceRange: ClosedRange<Double> = 0...1000
    @State private var selectedCategories: Set<Category> = []
    
    var body: some View {
        VStack {
            // Filters reduce visible options
            ScrollView(.horizontal) {
                HStack {
                    ForEach(quickFilters) { filter in
                        FilterChip(filter: filter)
                    }
                }
            }
            
            // Filtered results
            Text("\(filteredProducts.count) products")
                .font(.caption)
            
            ProductGrid(products: filteredProducts)
        }
    }
}

// GOOD: Comparison tool for complex decisions
struct ComparisonView: View {
    let products: [Product]
    
    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(products) { product in
                    VStack(alignment: .leading) {
                        ProductImage(product: product)
                        Text(product.name).font(.headline)
                        Text(product.price, format: .currency(code: "USD"))
                        
                        // Side-by-side feature comparison
                        ForEach(comparisonFeatures) { feature in
                            HStack {
                                Text(feature.name)
                                Spacer()
                                Image(systemName: product.has(feature) ? "checkmark" : "xmark")
                            }
                        }
                    }
                    .frame(width: 200)
                }
            }
        }
    }
}
```

---

## 7. iOS-Specific Implementation Guide

### Human Interface Guidelines Alignment

| UX Law | HIG Principle | Implementation |
|--------|---------------|----------------|
| Fitts's Law | Touch targets 44pt+ | `frame(minWidth: 44, minHeight: 44)` |
| Jakob's Law | Platform conventions | Standard navigation, gestures |
| Miller's Law | Information architecture | Tab bar limit, section grouping |
| Hick's Law | Progressive disclosure | `DisclosureGroup`, sheets |
| Doherty Threshold | Responsiveness | Optimistic UI, skeleton loading |

### Accessibility Considerations

```swift
// All UX laws should maintain accessibility
struct AccessibleButton: View {
    var body: some View {
        Button(action: action) {
            Label("Add Item", systemImage: "plus")
        }
        .frame(minWidth: 44, minHeight: 44) // Fitts's Law
        .accessibilityLabel("Add new item") // VoiceOver
        .accessibilityHint("Double tap to add a new item to your list")
    }
}

// Respect user preferences
struct ResponsiveText: View {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    var body: some View {
        Text("Content")
            .font(.body) // Respects Dynamic Type
    }
}
```

### Animation Guidelines

```swift
// Standard iOS animation durations
extension Animation {
    static let uxStandard = Animation.easeInOut(duration: 0.3)
    static let uxQuick = Animation.easeOut(duration: 0.15)
    static let uxSpring = Animation.spring(response: 0.4, dampingFraction: 0.7)
}

// Use consistent animations
struct AnimatedView: View {
    var body: some View {
        content
            .animation(.uxStandard, value: someValue)
    }
}
```

---

## 8. Quick Reference Tables

### Decision Making & Choice

| Law | Summary | iOS Pattern |
|-----|---------|-------------|
| Hick's Law | More choices = Slower decisions | 5-7 options max, progressive disclosure |
| Choice Overload | Too many = Paralysis | Filters, recommendations, defaults |
| Occam's Razor | Simplest is best | Remove unnecessary UI elements |
| Pareto Principle | 80/20 rule | Focus on core 20% of features |

### Memory & Cognition

| Law | Summary | iOS Pattern |
|-----|---------|-------------|
| Miller's Law | 7±2 items in memory | Chunk content, limit options |
| Cognitive Load | Minimize mental effort | Progressive disclosure, consistency |
| Working Memory | 4-7 items, 20-30 seconds | Show state, reduce recall needs |
| Chunking | Group related items | Sections, formatted inputs |

### Gestalt Principles

| Principle | Summary | iOS Pattern |
|-----------|---------|-------------|
| Proximity | Near = Related | Proper spacing (8, 16, 24pt) |
| Similarity | Same style = Related | Consistent button/card styles |
| Common Region | Shared boundary = Group | Cards, sections, backgrounds |
| Connectedness | Connected = Related | Step indicators, timelines |

### Behavior & Motivation

| Law | Summary | iOS Pattern |
|-----|---------|-------------|
| Goal-Gradient | Closer = Faster | Progress indicators, "Almost done!" |
| Zeigarnik | Incomplete = Memorable | Draft indicators, continue prompts |
| Peak-End Rule | Peak + End = Memory | Celebrate completion, recover errors |
| Flow | Challenge = Skill | Remove distractions, immediate feedback |

### Perception & Attention

| Law | Summary | iOS Pattern |
|-----|---------|-------------|
| Serial Position | First + Last remembered | Important items at edges |
| Von Restorff | Different = Remembered | Highlight CTAs, recommended options |
| Selective Attention | Goal-focused | Avoid banner-like important content |
| Cognitive Bias | Mental shortcuts | Smart defaults, social proof |

### System Performance

| Law | Summary | iOS Pattern |
|-----|---------|-------------|
| Doherty Threshold | <400ms = Optimal | Optimistic UI, skeleton loading |
| Tesler's Law | Complexity exists | Move complexity to system |
| Postel's Law | Accept varied input | Flexible parsing, helpful errors |
| Fitts's Law | Big + Close = Fast | 44pt+ targets, thumb-friendly |

---

## 9. Code Snippets & Patterns

### Reusable Components

```swift
// MARK: - Standard Button Styles (Similarity, Fitts's Law)

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50) // Proper touch target
            .background(Color.accentColor)
            .cornerRadius(12)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.accentColor)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(12)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

// MARK: - Card Component (Common Region, Proximity)

struct StandardCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
    }
}

// MARK: - Progress Indicator (Goal-Gradient, Zeigarnik)

struct StepProgress: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<totalSteps, id: \.self) { step in
                    Capsule()
                        .fill(step < currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(height: 4)
                }
            }
            
            HStack {
                Text("Step \(currentStep) of \(totalSteps)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if currentStep > totalSteps / 2 {
                    Text("Almost there!")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
            }
        }
    }
}

// MARK: - Skeleton Loading (Doherty Threshold)

struct SkeletonModifier: ViewModifier {
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.5), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: isAnimating ? 200 : -200)
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

extension View {
    func shimmering() -> some View {
        modifier(SkeletonModifier())
    }
}

// MARK: - Empty State (Active User Paradox)

struct EmptyState: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(actionTitle, action: action)
                .buttonStyle(PrimaryButtonStyle())
                .frame(width: 200)
        }
        .padding(40)
    }
}

// MARK: - Contextual Tooltip (Active User Paradox)

struct TooltipModifier: ViewModifier {
    let message: String
    let key: String
    @State private var showTooltip = false
    @AppStorage private var hasShown: Bool
    
    init(message: String, key: String) {
        self.message = message
        self.key = key
        self._hasShown = AppStorage(wrappedValue: false, "tooltip_shown_\(key)")
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if showTooltip {
                    Text(message)
                        .font(.caption)
                        .padding(8)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .shadow(radius: 4)
                        .offset(y: -40)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .onAppear {
                if !hasShown {
                    withAnimation(.spring().delay(0.5)) {
                        showTooltip = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            showTooltip = false
                            hasShown = true
                        }
                    }
                }
            }
    }
}

extension View {
    func tooltip(_ message: String, key: String) -> some View {
        modifier(TooltipModifier(message: message, key: key))
    }
}
```

---

## AI Prompt Templates

Use these templates when asking AI assistants to build iOS features:

### General UI Review
```
Review this SwiftUI view against Laws of UX principles:
- Fitts's Law: Are touch targets at least 44pt?
- Hick's Law: Are there too many choices?
- Proximity: Is related content grouped properly?
- Jakob's Law: Does it follow iOS conventions?

[paste code here]
```

### Building New Features
```
Build a [feature description] in SwiftUI following these UX laws:
- Apply Fitts's Law for touch targets (minimum 44pt)
- Use Miller's Law for chunking (5-7 items per group)
- Follow Jakob's Law with standard iOS patterns
- Implement Goal-Gradient Effect with progress indication
- Meet Doherty Threshold with optimistic UI updates
```

### Accessibility Check
```
Review this component for accessibility while maintaining UX laws:
- Touch targets meet Fitts's Law (44pt minimum)
- Labels support VoiceOver
- Respects Dynamic Type
- Color contrast sufficient
- Animations respect reduced motion

[paste code here]
```

---

## Version History

- **v1.0** - December 2025 - Initial iOS-focused documentation

---

*This document is optimized for use with AI coding assistants. Include relevant sections in your prompts or add the entire file to your project context for consistent UX-compliant iOS development.*
