

# **iOS Design System**

*Liquid Glass Edition*

Inspired by Apple's native apps, Gentler Streak, Things 3, and Craft

Version 1.0

December 2025

# **Design Philosophy**

This design system embodies the principle that great design is invisible—it gets out of the way and lets users focus on what matters. Drawing from Apple's Liquid Glass language, we embrace translucency, fluidity, and hierarchy while maintaining the warmth and humanity of apps like Gentler Streak, the precision of Things 3, and the elegance of Craft.

## **Core Principles**

1. **Clarity First:** Every element serves a purpose. Remove anything that doesn't help the user accomplish their goal.

2. **Content is King:** Controls and chrome should recede, allowing content to take center stage.

3. **Fluid Hierarchy:** Interface elements should gracefully adapt—expanding when focused, shrinking when secondary.

4. **Human Touch:** Design should feel warm and inviting, never cold or intimidating.

5. **Delight in Details:** Subtle animations and thoughtful micro-interactions create moments of joy.

## **Design Inspirations**

### **Apple Liquid Glass**

Apple's 2025 design language introduces a translucent material that reflects and refracts its surroundings. Key characteristics include real-time light adaptation, dynamic morphing of controls, depth through layered glass effects, and seamless transitions between states.

### **Gentler Streak**

This Apple Design Award winner demonstrates that fitness apps can be encouraging rather than demanding. It uses soft, calming color palettes with soothing blues and greens, friendly illustrations through the "Yorhart" character, non-judgmental language in all UI copy, and progress visualization that celebrates consistency over intensity.

### **Things 3**

Cultured Code's masterpiece proves that minimalism and power can coexist. Key learnings include extreme attention to detail in every pixel, keyboard-first design philosophy, visual hierarchy through subtle shading and spacing, and a distraction-free interface that feels like paper.

### **Craft**

Craft shows how documents can be beautiful without sacrificing function. Notable elements include block-based content that feels natural, elegant typography that enhances readability, seamless cross-platform experience, and rich formatting without visual clutter.

# **Color System**

Our palette balances Apple's signature blue with bold accent colors for emphasis. The system supports both light and dark appearances while maintaining accessibility standards.

## **Primary Palette**

| Swatch | Name | Hex | Usage |
| :---- | :---- | :---- | :---- |
|   | **Primary Blue** | \#007AFF | CTAs, links, active states |
|   | **Deep Purple** | \#5856D6 | Secondary actions, tags |
|   | **Success Green** | \#34C759 | Confirmations, positive |
|   | **Warning Orange** | \#FF9500 | Alerts, attention needed |
|   | **Error Red** | \#FF3B30 | Errors, destructive actions |

## **Neutral Palette**

| Swatch | Name | Hex | Usage |
| :---- | :---- | :---- | :---- |
|   | **Label** | \#1D1D1F | Primary text, headings |
|   | **Secondary Label** | \#6E6E73 | Captions, metadata |
|   | **Tertiary Label** | \#AEAEB2 | Placeholders, disabled |
|   | **Background** | \#F5F5F7 | Page backgrounds |
|   | **Glass Tint** | \#E8F4FD | Liquid Glass surfaces |

## **Usage Guidelines**

* Use Primary Blue sparingly—reserve for primary actions and key interactive elements

* Maintain minimum 4.5:1 contrast ratio for text on backgrounds (WCAG AA)

* For Liquid Glass effects, use background blur (radius 20-40pt) with 80-90% opacity

* In dark mode, reduce saturation by 10-15% to prevent color vibration

# **Typography**

Typography is the foundation of visual hierarchy. We use San Francisco, Apple's system font, optimized for legibility across all sizes and weights.

## **Type Scale**

| Style | Size | Weight | Usage |
| :---- | :---- | :---- | :---- |
| Large Title | 34pt | Bold | Screen titles, hero sections |
| Title 1 | 28pt | Bold | Section headers |
| Title 2 | 22pt | Bold | Subsection headers |
| Headline | 17pt | Semibold | List item titles, emphasis |
| Body | 17pt | Regular | Main content, descriptions |
| Callout | 16pt | Regular | Secondary body text |
| Footnote | 13pt | Regular | Captions, timestamps |
| Caption | 12pt | Regular | Labels, helper text |

## **Typography Best Practices**

* Use Dynamic Type to respect user accessibility preferences

* Limit line length to 60-75 characters for optimal readability

* Maintain 1.4-1.6 line height ratio for body text

* Use only 2-3 weights per screen to maintain hierarchy

* Avoid using all caps except for very short labels

# **Spacing & Layout**

Consistent spacing creates rhythm and helps users scan content efficiently. Our spacing system uses an 8-point grid as the foundation.

## **Spacing Scale**

| Token | Value | Usage |
| :---- | :---- | :---- |
| space-xs | 4pt | Tight spacing, icon padding |
| space-sm | 8pt | Related element gaps, compact lists |
| space-md | 16pt | Standard content padding, card margins |
| space-lg | 24pt | Section separators, form field gaps |
| space-xl | 32pt | Major section breaks, hero spacing |
| space-2xl | 48pt | Page margins, generous whitespace |

## **Layout Principles**

* Use 16pt horizontal margins on iPhone, 20pt on iPad

* Group related content with less space; separate distinct sections with more

* Allow content to breathe—generous whitespace improves comprehension by 20%

* Align elements to the 8pt grid for visual harmony

* Use Safe Area insets to respect notches and home indicators

## **Corner Radius Scale**

Rounded corners soften interfaces and feel more human. Use these standard radii consistently:

* Small (8pt): Buttons, text fields, tags

* Medium (12pt): Cards, list cells, popovers

* Large (16pt): Modals, sheets, large containers

* Continuous (20pt+): Full-width cards, Liquid Glass bubbles

# **Components**

Components are the building blocks of your interface. Each should feel cohesive with Apple's native components while expressing your app's unique personality.

## **Buttons**

### **Primary Button**

Filled with Primary Blue, white text, 17pt semibold. Use for the single most important action on each screen.

* Height: 50pt minimum (44pt touch target \+ visual padding)

* Corner radius: 12pt (continuous)

* Horizontal padding: 20pt

* States: Default, Pressed (0.85 opacity), Disabled (0.5 opacity)

### **Secondary Button**

Outlined or tinted style for secondary actions. Uses Primary Blue for text and border.

* Border: 1pt stroke with Primary Blue

* Background: Transparent or 10% Primary Blue tint

* Same dimensions as primary button

### **Glass Button (Liquid Glass)**

For Liquid Glass interfaces, use a frosted glass background with vibrancy effect.

* Background: UIBlurEffect with .systemMaterial style

* Use for floating actions and toolbars

* Adapts to light/dark mode automatically

## **Cards**

Cards group related content and provide visual separation. They're essential for list views and dashboards.

* Background: System background color (adapts to appearance)

* Shadow: 0pt offset, 8pt blur, 4% opacity black

* Corner radius: 12pt

* Padding: 16pt all sides

* For Glass Cards: Use .ultraThinMaterial blur effect

## **List Cells**

Inspired by Things 3, list cells should feel clickable without heavy visual treatment.

* Height: 44pt minimum, expand for multi-line content

* Leading padding: 16pt (20pt with icon)

* Use chevron (\>) only when drilling into detail views

* Separator inset: Align with content, not full width

## **Tab Bars**

Following Liquid Glass principles, tab bars should be translucent and morphable.

* Use .ultraThinMaterial for background blur

* Icon size: 24pt (SF Symbols)

* Selected state: Primary Blue fill

* Consider collapsing to pill when scrolling (like iOS 26\)

# **Motion & Animation**

Motion brings interfaces to life. Like Gentler Streak's delightful transitions, animations should feel natural, purposeful, and never gratuitous.

## **Animation Principles**

* Every animation must have a purpose—don't animate just because you can

* Use spring animations for natural, organic movement

* Match system animations where possible (300ms for standard transitions)

* Reduce motion when user has "Reduce Motion" enabled

* Subtle micro-interactions provide feedback and delight

## **Timing Guidelines**

| Animation Type | Duration | Curve |
| :---- | :---- | :---- |
| Button press | 100ms | easeOut |
| Screen transition | 300ms | spring(response: 0.3, damping: 0.75) |
| Modal presentation | 350ms | spring(response: 0.4, damping: 0.8) |
| Tab bar morph | 250ms | easeInOut |
| Content fade | 200ms | easeIn |
| Success celebration | 600ms | spring(response: 0.5, damping: 0.6) |

## **Liquid Glass Motion**

For Liquid Glass elements, motion should feel fluid and organic, like real glass catching light:

* Surface reflections should subtly respond to device tilt (using accelerometer)

* Glass elements should "breathe" with slight scale changes when gaining/losing focus

* Blurred backgrounds should smoothly transition when content changes beneath them

* Tab bars and toolbars should morph smoothly rather than abruptly appearing/disappearing

# **Iconography**

Icons are the universal language of interfaces. SF Symbols provides a comprehensive, consistent icon set that automatically adapts to your app's typography and respects accessibility settings.

## **SF Symbols Guidelines**

* Use SF Symbols exclusively for system icons—they scale beautifully with Dynamic Type

* Default to "Regular" weight; match to adjacent text weight when inline

* Prefer filled variants for selected states, outlined for unselected

* Use multicolor symbols sparingly—stick to monochrome for consistency

## **Icon Sizes**

| Context | Size | Symbol Scale |
| :---- | :---- | :---- |
| Tab Bar | 24pt | Medium |
| Navigation Bar | 22pt | Medium |
| List Cell Accessory | 17pt | Small |
| Button Icon | 20pt | Medium |
| Empty State | 64pt | Large |

## **Custom Icons**

When SF Symbols doesn't have what you need, create custom icons following these guidelines:

* Match the visual weight and optical size of SF Symbols

* Use 2pt stroke weight for outlined icons at 24pt size

* Design on a 24x24pt grid with 2pt padding

* Export as PDF vectors for crisp rendering at all sizes

* Include filled variants for selected states

# **Implementation Notes**

This section provides practical guidance for implementing the design system in SwiftUI and UIKit.

## **SwiftUI Color Extensions**

extension Color {    static let dssPrimary \= Color(hex: "007AFF")    static let dssSecondary \= Color(hex: "5856D6")    static let dssSuccess \= Color(hex: "34C759")    static let dssWarning \= Color(hex: "FF9500")    static let dssError \= Color(hex: "FF3B30")    static let dssLabel \= Color(hex: "1D1D1F")    static let dssSecondaryLabel \= Color(hex: "6E6E73")    static let dssBackground \= Color(hex: "F5F5F7")    static let dssGlassTint \= Color(hex: "E8F4FD")}

## **Glass Material Modifier**

struct GlassMaterial: ViewModifier {    func body(content: Content) \-\> some View {        content            .background(.ultraThinMaterial)            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4\)    }}extension View {    func glassCard() \-\> some View {        modifier(GlassMaterial())    }}

## **Resources**

* Apple Human Interface Guidelines: developer.apple.com/design

* SF Symbols App: Download from Apple Developer

* Liquid Glass Developer Documentation: Available in Xcode 16

*— End of Design System Document —*
