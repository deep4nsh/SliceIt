# SliceIt Design System: Quick Reference

## Color Palette (Dark Theme Only)

### Backgrounds
```
App Background:     #0F0F0F (near-black)
Surface 1:          #1A1A1A (cards, elevated)
Surface 2:          #242424 (slightly higher)
Surface 3:          #2E2E2E (highest elevation)
```

### Semantic Colors
```
Primary (Actions):  #5B6F82 (slate blue)
Success (Owed):     #10B981 (emerald)
Error (You Owe):    #EF4444 (red)
Warning (Alert):    #F59E0B (amber)
Info (Neutral):     #0EA5E9 (sky blue)
```

### Text
```
Primary:    #FFFFFF (main content)
Secondary:  #A0A0A0 (metadata, 60% opacity)
Tertiary:   #757575 (disabled, 40% opacity)
```

### Borders
```
Default:    #2E2E2E (subtle, one step above bg)
Subtle:     #1E1E1E (very subtle)
Strong:     #3E3E3E (for emphasis)
```

---

## Typography (Inter Font)

| Level | Size | Weight | Use |
|-------|------|--------|-----|
| Display | 40px | 600 | Brand focal points (rare) |
| H1 | 32px | 600 | Page titles |
| H2 | 24px | 600 | Section headers |
| H3 | 18px | 600 | Card titles |
| Subtitle | 12px | 500 | Above card titles |
| Body L | 16px | 400 | Primary content |
| Body | 14px | 400 | Standard body |
| Caption | 12px | 400 | Metadata, timestamps |
| Label | 13px | 500 | Button text, tags |

**Hierarchy Example on Home**:
- Balance amount: Display (40px, 600)
- Label: Subtitle (12px, 500)
- Context: Caption (12px, 400)

---

## Spacing (8pt Grid)

```
Base Unit: 8px

Common Spacings:
- 4px:  Half-unit (rare)
- 8px:  Between elements ✓
- 12px: Half-standard (1.5 units)
- 16px: Standard ✓ (2 units)
- 24px: Large ✓ (3 units)
- 32px: XL ✓ (4 units)
- 48px: Major sections (6 units)

Component Sizing:
- Button height: 44px
- Input height: 44px
- Icon size: 24px
- Avatar size: 40px

Component Padding:
- Cards: 16px
- Buttons: 12px (v) × 16px (h)
- Screen margins: 16px (h), 100px (bottom)
- Touch targets: 44px minimum
```

---

## Component Specifications

### Button
```
Padding: 12px (v) × 16px (h)
Height: 44px (minimum touch target)
Border radius: 8px
Font: Label (13px, 500)

Primary:    #5B6F82 background, white text
Secondary:  #1A1A1A background, white border
Tertiary:   Transparent, primary text
Danger:     #EF4444 background, white text
```

### Card
```
Background: #1A1A1A (surface 1)
Border: 1px #2E2E2E
Border radius: 12px
Padding: 16px
Shadow: None
Spacing below: 12px
```

### Input Field
```
Height: 44px
Background: #1A1A1A
Border: 1px #2E2E2E
Border radius: 8px
Padding: 12px
Font: Body (14px, #FFFFFF)
Placeholder: #757575
Focus: Border #5B6F82, Background #242424
Error: Border #EF4444, Helper #EF4444
```

### Navigation Bar (Bottom)
```
Height: 64px (including safe area)
Background: #1A1A1A
Border: 1px #2E2E2E (top only)
Safe area: Respected

Item (Inactive):
├── Icon: 24px, #757575
├── Label: 11px, weight 500, #A0A0A0
└── Layout: Icon above label

Item (Active):
├── Icon: 24px, #5B6F82
├── Label: 11px, weight 500, #5B6F82
└── Layout: Icon above label

NO blur, NO glassmorphism, NO floating islands
```

---

## Motion Standards

| Interaction | Duration | Easing | Effect |
|-------------|----------|--------|--------|
| Button press | 150ms | easeOut | Opacity 0.8, scale 0.95 |
| Card hover | 200ms | easeOutCubic | Shadow increase, bg change |
| List entry | 300ms | easeOutCubic | Fade + slide up 16px |
| Screen transition | 300ms | easeOutCubic | Fade only |
| Loading spinner | 1000ms | linear | Continuous rotation |

**Philosophy**: Apple-level subtlety. No springs, no bouncing, no excessive animation.

---

## Screen Layouts

### Home Screen
```
┌────────────────────────────────┐
│ Profile header + Notifications │ 16px padding
├────────────────────────────────┤
│ YOUR BALANCE                    │ 24px top
│ ₹ 8,230 (prominent)            │
│ You are owed this amount        │ 24px bottom
├────────────────────────────────┤
│ You Owe / Owed to You breakdown │ 12px spacing
├────────────────────────────────┤
│ [+ Add Expense] [→ Settle]      │ 24px top/bottom
├────────────────────────────────┤
│ RECENT ACTIVITY                 │ 24px top
│ • Activity item 1               │ 8px between items
│ • Activity item 2               │
│ • Activity item 3               │
│ [View All Activity]             │
├────────────────────────────────┤
│ GROUPS YOU'RE IN                │ 24px top
│ • Group 1 (summary)             │ 12px between
│ • Group 2 (summary)             │
│                                 │ 32px bottom (nav buffer)
└────────────────────────────────┘
```

### Group Detail Page
```
┌────────────────────────────────┐
│ ← Group Name (3 members) ⚙️ 👤  │
├────────────────────────────────┤
│ BALANCES                        │
│ You Owe: ₹ 1,200                │
│ Owed to You: ₹ 500              │
├────────────────────────────────┤
│ MEMBERS                         │
│ • Member 1 - Balance info       │
│ • Member 2 - Balance info       │
│ • Member 3 - Balance info       │
├────────────────────────────────┤
│ SETTLEMENT NEEDED               │
│ → Person A pays Person B ₹500   │
│ → Person C pays Person D ₹800   │
├────────────────────────────────┤
│ RECENT EXPENSES                 │
│ • Expense 1                     │
│ • Expense 2                     │
│ • Expense 3                     │
│ [+ Add Expense]                 │
└────────────────────────────────┘
```

---

## What to AVOID (Hard Rules)

❌ **Glassmorphism**: No BackdropFilter, no blur effects  
❌ **Neumorphism**: No embossed/debossed styles  
❌ **Excessive Gradients**: Max 1 gradient per screen (none preferred)  
❌ **Neon Colors**: No bright/saturated colors  
❌ **Crypto Aesthetics**: No "futuristic" design  
❌ **Excessive Shadows**: Max subtle shadows  
❌ **Heavy Blur**: Only in modals with dark overlay  
❌ **Overly Colorful**: Stick to semantic color system  
❌ **Gradient Text**: Plain text only  
❌ **Gradient Borders**: Plain borders only  
❌ **Decorative Elements**: Everything must be functional  

---

## Implementation Priorities (by Impact)

| Rank | Item | Impact | Effort | Week |
|------|------|--------|--------|------|
| 1 | Design System (colors, typography, spacing) | 🔴 Critical | Medium | 1-2 |
| 2 | Home Screen Redesign | 🔴 Critical | High | 2-3 |
| 3 | Navigation Bar Fix | 🔴 Critical | Medium | 3-4 |
| 4 | Groups + Group Detail | 🟠 High | High | 5-6 |
| 5 | Activity Feed Screen | 🟠 High | High | 6-7 |
| 6 | Button + Input Components | 🟠 High | Medium | 9-10 |
| 7 | Analytics Charts | 🟠 High | Medium | 7-8 |
| 8 | Motion System | 🟡 Medium | Medium | 11 |
| 9 | Testing & Polish | 🔴 Critical | High | 12 |

---

## Accessibility Requirements

- **Contrast**: WCAG AA minimum (4.5:1 for normal text)
- **Touch Targets**: 44px minimum (44×44 or equivalent)
- **Typography**: 14px minimum body size
- **Motion**: Reduced motion support for system setting
- **Color**: Don't rely on color alone to convey information
- **Dark Theme**: Optimized for OLED displays

---

## File Structure for Design System

```
lib/
├── utils/
│   ├── colors.dart          ← Define all colors here
│   ├── text_styles.dart     ← Typography system
│   ├── app_spacing.dart     ← Spacing constants
│   └── theme.dart           ← Theme data (new)
├── widgets/
│   ├── button.dart          ← All button variants
│   ├── card.dart            ← Card component
│   ├── inputs.dart          ← Input fields
│   ├── dialogs.dart         ← Modal dialogs
│   ├── toast.dart           ← Snackbars/toasts
│   ├── navigation.dart      ← Nav bar (new)
│   ├── loading.dart         ← Loading states
│   └── empty_state.dart     ← Empty states
└── screens/
    ├── home_screen.dart     ← Redesigned
    ├── groups_screen.dart   ← Redesigned
    ├── group_detail_screen.dart ← Redesigned
    ├── activity_screen.dart ← New
    └── ...
```

---

## Testing Checklist

Before shipping, verify:
- [ ] No gradient text or borders
- [ ] No blur effects (except modals)
- [ ] No glassmorphism
- [ ] All buttons are 44×44px minimum
- [ ] All text is 14px+ (body size)
- [ ] Contrast is 4.5:1+ (WCAG AA)
- [ ] Spacing follows 8pt grid
- [ ] Animations are 150-300ms
- [ ] Dark theme is optimized
- [ ] No excessive animations
- [ ] Home screen is scannable in 3 seconds
- [ ] Touch targets are clearly defined

---

**Full Details**: See DESIGN_AUDIT_AND_REDESIGN.md for comprehensive specifications
