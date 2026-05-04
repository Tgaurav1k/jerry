# `jerry` — Design Document

**Project:** jerry — Lawyer-Client Consultation Platform
**Document Purpose:** UI/UX design system + screen specifications. Companion to Architecture.md, MVP-Tech-Doc.md, and PRD.md.
**Audience:** Flutter developers + Cursor AI for UI implementation.
**Version:** 1.0 (MVP)

> **How to use this doc:** Section 3 (Design Tokens) should be translated directly into Flutter `ThemeData`. Sections 5-9 give you widget-level specs. Section 10 gives screen-by-screen layouts.

---

## 1. Design Philosophy

`jerry`'s visual identity is built on three core principles from the brief:

### 1.1 Bento Grid Layout (Adapted for Mobile)
Content is organized into **modular rounded cards of varying sizes** — like a Japanese bento box. On desktop this means a multi-column grid; on mobile (our target) it translates to **stacked cards with differing prominence** (hero cards, full-width cards, paired half-cards). The key idea: information is **visually chunked**, not run-on.

### 1.2 Calm UI
Low visual noise, generous whitespace, muted tones. No harsh dividers — use soft shadows and subtle color shifts instead. Typography carries the hierarchy, not borders. Interactions feel unhurried. Think: Apple Health, Linear, Notion — not Jira, not MS Teams.

### 1.3 Glassmorphism (Selective)
Reserved for overlays, modals, and detail panels — **not the entire UI**. Glass creates the sense of "this is layered on top" for modal context (incoming call, filter sheet, rating modal). Over-use destroys readability.

### 1.4 Supporting Principles
- **Mobile-first** — designed for one-handed phone use; bottom-weighted actions
- **Trust signals** — verification badges, clear ratings, transparent pricing (when added) — legal advice requires visible credibility
- **Reduced cognitive load** — user is often stressed (legal issues); UI must be obvious, forgiving, calm

---

## 2. Brand Identity

### 2.1 Logo Direction (to be finalized)
Wordmark: lowercase `jerry` in a rounded sans-serif with slight weight variation. Color: deep slate-blue primary.
Mark: a stylized "j" shaped like a chat bubble + speech tick. Works as favicon/app icon.

### 2.2 Tonality
- **Voice:** Calm, clear, reassuring. Never corporate-jargony. Never overly casual either (it's legal, not food delivery).
- **Writing examples:**
  - ✅ "Finding the right lawyer for you…"
  - ❌ "Awesome! Let's match you with a legal superstar!"
  - ✅ "Your lawyer is reviewing your message."
  - ❌ "We got this! 🔥"
- **No emojis** in product copy. (Lawyers evaluating the platform will notice.)

### 2.3 App Icon
Rounded-square (iOS + Android adaptive icon). Slate-blue background (#2B3F5C) with white "j" chat-bubble mark centered.

---

## 3. Design Tokens

These are the values Flutter `ThemeData` + reusable tokens will be built from. Hard-code nothing; reference tokens everywhere.

### 3.1 Color System

#### Neutrals (Slate Family)
```
slate-50   #F6F7F9   App background
slate-100  #EDF0F4   Card background (on white)
slate-200  #DDE2EA   Hairline dividers (rare; mostly use shadows)
slate-300  #C0C8D5   Placeholder text, disabled states
slate-400  #8F9AAC   Secondary text
slate-500  #64718A   Supporting text, icons (inactive)
slate-600  #475268   Body text
slate-700  #323B4D   Headings
slate-800  #1E2535   Strong headings, dark mode surface
slate-900  #0E121C   Dark mode background
```

#### Primary (Soft Blue)
```
blue-50   #EEF4FC
blue-100  #D6E3F6
blue-200  #A9C3EB
blue-300  #7CA3E0
blue-400  #5687D6
blue-500  #3B6FC8   ← Primary brand
blue-600  #2B5AAE
blue-700  #1F4489
blue-800  #153163
blue-900  #0D1F40
```

**Usage:** Primary CTAs, links, active tab indicators, selected states.

#### Accent (Sage Green)
```
sage-50   #F0F5EE
sage-100  #DDE9D8
sage-200  #BDD4B2
sage-300  #98BA8B
sage-400  #779F67
sage-500  #5E874C   ← Accent / success
sage-600  #496B3A
sage-700  #37502C
sage-800  #263819
sage-900  #16200F
```

**Usage:** Online presence dot, success toasts, approved badges, rating stars (filled).

#### Semantic Colors
```
success  #5E874C  (same as sage-500)
warning  #C89637  (muted amber)
error    #B5473D  (desaturated brick red, not alarm red)
info     #3B6FC8  (same as blue-500)
```

#### Call-to-Action Accents (used sparingly)
```
call-voice   #2B5AAE  (slate-blue)
call-video   #5E874C  (sage green) — reinforces "calm" feel even on a big action
call-end     #B5473D  (error brick)
```

### 3.2 Typography

**Font Family:** `Inter` (primary) → `SF Pro Text` (iOS fallback) → `Roboto` (Android fallback). Inter via Google Fonts package — bundled, not runtime-fetched.

**Why Inter:** Excellent legibility at small sizes, modern but timeless, pairs well with muted palettes, wide weight range.

#### Type Scale
| Token | Size | Line-height | Weight | Use |
|---|---|---|---|---|
| `display-lg` | 32 | 40 | 700 | Splash, welcome hero |
| `display` | 28 | 36 | 700 | Screen titles (rare) |
| `heading-1` | 24 | 32 | 600 | Main screen titles |
| `heading-2` | 20 | 28 | 600 | Section headers |
| `heading-3` | 18 | 26 | 600 | Card titles |
| `body-lg` | 16 | 24 | 400 | Primary body text |
| `body` | 14 | 22 | 400 | Default body text |
| `body-sm` | 13 | 20 | 400 | Secondary info |
| `caption` | 12 | 18 | 500 | Metadata, timestamps |
| `caption-sm` | 11 | 16 | 500 | Micro-labels |
| `button` | 15 | — | 600 | Button text |
| `button-sm` | 13 | — | 600 | Small button text |

**Weights used:** 400 (regular), 500 (medium), 600 (semibold), 700 (bold). No 300 or 900.

**Letter spacing:** default (0) for body, -0.2% for headings ≥20px, +0.5% for caption uppercase labels.

### 3.3 Spacing (4pt Grid)

```
space-0    0px
space-1    4px    (tight)
space-2    8px    (default inline gap)
space-3    12px   (compact stack)
space-4    16px   (default stack gap)
space-5    20px
space-6    24px   (section gap)
space-8    32px   (large section gap)
space-10   40px
space-12   48px   (screen-top spacing)
space-16   64px   (hero spacing)
```

**Mobile safe area padding:** 20px horizontal (`space-5`) on both sides for primary content.

### 3.4 Corner Radius

```
radius-xs    4px    (tags, small pills)
radius-sm    8px    (buttons, inputs)
radius-md    12px   (cards, bottom sheets)
radius-lg    16px   (hero cards)
radius-xl    20px   (modals)
radius-2xl   28px   (large feature cards)
radius-pill  999px  (chips, avatars)
radius-avatar 50%   (profile photos)
```

**Default card radius:** 16px (`radius-lg`). This is the "bento feel" — chunky but not exaggerated.

### 3.5 Elevation (Soft Shadows, No Harsh Dividers)

```
elevation-0  none
elevation-1  0 1px 2px  rgba(30,37,53,0.04), 0 1px 1px rgba(30,37,53,0.03)
elevation-2  0 2px 6px  rgba(30,37,53,0.06), 0 1px 2px rgba(30,37,53,0.04)
elevation-3  0 4px 16px rgba(30,37,53,0.08), 0 2px 4px rgba(30,37,53,0.04)
elevation-4  0 8px 32px rgba(30,37,53,0.12), 0 4px 8px rgba(30,37,53,0.06)  (modals)
elevation-5  0 16px 48px rgba(30,37,53,0.16), 0 8px 16px rgba(30,37,53,0.08) (floating CTAs)
```

**Rule:** Never use `elevation-0` + border to create a card boundary. Always use `elevation-1` minimum.

### 3.6 Glassmorphism Spec (for overlays only)

```
background: rgba(255, 255, 255, 0.72)
backdrop-filter: blur(24px) saturate(180%)
border: 1px solid rgba(255, 255, 255, 0.8)
box-shadow: elevation-4
```

**Flutter implementation:** Use `BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12))` wrapped in a `Container` with translucent color. Apply sparingly.

**Where to use glass:**
- Incoming call overlay (behind caller info card)
- Filter bottom sheet
- Rating modal
- Image preview overlay
- Profile dropdown on lawyer detail

**Where NOT to use glass:**
- Regular cards (use solid surface with shadow)
- Text-heavy screens
- List backgrounds
- Headers / app bars

### 3.7 Motion Tokens

```
duration-fast     120ms   (hover-like feedback, ripples)
duration-base     200ms   (default transitions)
duration-slow     320ms   (modal enters, page transitions)
duration-slower   480ms   (empty states, rare moments)

easing-standard   cubic(0.2, 0.0, 0.0, 1.0)    (default)
easing-emphasized cubic(0.3, 0.0, 0.8, 0.15)   (attention)
easing-decelerate cubic(0.0, 0.0, 0.2, 1.0)    (entering)
easing-accelerate cubic(0.4, 0.0, 1.0, 1.0)    (exiting)
```

**Motion principles:**
- Nothing should "snap." Everything eases.
- Transitions should feel inevitable, not flashy.
- Long lists scroll with momentum (iOS-style on both platforms).
- Page transitions: gentle slide + fade combined, never cut.

---

## 4. Iconography

### 4.1 Icon Library
**Primary:** `lucide-icons` (via `lucide_icons` Flutter package) — clean, consistent stroke weight, matches Calm UI aesthetic.
**Fallback:** Flutter built-in `Icons.*` for platform-standard cases.

### 4.2 Icon Sizing
```
icon-xs    14px    (inline with body-sm)
icon-sm    16px    (inline with body)
icon-md    20px    (button icons, list items)
icon-lg    24px    (navigation tabs, app bar actions)
icon-xl    32px    (feature tiles)
icon-2xl   48px    (empty states, onboarding)
```

### 4.3 Icon Stroke Weight
Default: `1.75px` stroke (Lucide default). Never fill icons unless they represent state (e.g., filled star = rated, outline star = not rated).

### 4.4 Common Icons Map
| Concept | Icon |
|---|---|
| Chat | `message-circle` |
| Voice call | `phone` |
| Video call | `video` |
| Profile | `user` |
| Home / Lawyers | `scale` (legal motif) |
| History | `clock` |
| Settings | `settings-2` |
| Search | `search` |
| Filter | `sliders-horizontal` |
| Online indicator | filled circle (no icon, just colored dot) |
| Verified | `badge-check` (filled sage) |
| Rating star (filled) | `star` filled |
| Rating star (empty) | `star` outline |
| Back | `chevron-left` |
| Close | `x` |
| Logout | `log-out` |
| Upload | `upload-cloud` |
| Approve | `check-circle-2` |
| Reject | `x-circle` |
| Notifications | `bell` |

---

## 5. Component Library

Each component below defines: **anatomy, states, sizes, usage rules, Flutter widget notes.**

### 5.1 Buttons

#### 5.1.1 Primary Button
```
┌─────────────────────────┐
│   Continue              │
└─────────────────────────┘
```
- **Bg:** `blue-500` · **Text:** white · **Radius:** `radius-sm` (8px)
- **Height:** 48px · **Padding:** 16px horizontal
- **Hover/press:** bg darkens to `blue-600`
- **Disabled:** bg `slate-200`, text `slate-400`
- **Loading state:** replace text with small white spinner, disable tap

#### 5.1.2 Secondary Button
- **Bg:** white · **Text:** `blue-500` · **Border:** 1px `blue-200`
- **Press:** bg `blue-50`

#### 5.1.3 Tertiary / Text Button
- **Bg:** transparent · **Text:** `blue-500` · **No border**
- **Press:** subtle `blue-50` bg circular ripple

#### 5.1.4 Destructive Button
- **Bg:** `error` (#B5473D) · **Text:** white
- Used for: End Call, Delete Account, Reject Lawyer

#### 5.1.5 Icon Button (circular)
- **Size:** 40px · 48px · 56px
- **Bg:** white with `elevation-2`
- **Icon:** `icon-md` centered
- Used for: camera flip, mute, back

### 5.2 Input Fields

```
Label text (caption, slate-500)
┌─────────────────────────────┐
│  Placeholder or value        │
└─────────────────────────────┘
Helper text (caption-sm, slate-400)
```
- **Bg:** `slate-50` · **Border:** none by default
- **Focused:** 2px border `blue-500`, bg white, smooth transition
- **Error:** 2px border `error`, helper text `error` color
- **Height:** 52px · **Radius:** `radius-sm`
- **Label:** caption, positioned above (not floating)

#### OTP Input — special component
- 6 separate boxes, each 48x56px, `radius-sm`, `slate-100` bg
- Auto-advance on digit entry
- Current focus box has `blue-500` border
- On paste of 6-digit code, distributes to all boxes

### 5.3 Bento Cards

This is the **signature component** of `jerry`'s UI. All major content surfaces use bento cards.

#### 5.3.1 Standard Bento Card
```
┌───────────────────────────────┐
│                               │
│  Card content                 │
│                               │
└───────────────────────────────┘
```
- **Bg:** white · **Radius:** `radius-lg` (16px) · **Elevation:** `elevation-1`
- **Padding:** `space-5` (20px) default, `space-4` (16px) compact
- No border. Separation comes from shadow + background contrast.

#### 5.3.2 Hero Bento Card
Larger, more prominent. Used for: featured lawyer on home, call-to-action cards.
- **Radius:** `radius-xl` (20px) · **Elevation:** `elevation-2`
- **Padding:** `space-6` (24px)
- May have subtle gradient overlay

#### 5.3.3 Paired Bento Cards
Two cards side-by-side in a row, 50/50 split, with `space-3` (12px) gap between them. Common on lawyer home dashboard: "Consultations Today" + "Online Now".

#### 5.3.4 Metric Bento Card (SuperAdmin)
```
┌─────────────────────┐
│                     │
│   1,243             │  ← heading-1
│   Total Users       │  ← body-sm slate-500
│                     │
│   ▲ 12% vs last wk  │  ← caption sage-500
│                     │
└─────────────────────┘
```

#### 5.3.5 Flutter Widget Pseudocode

```dart
class BentoCard extends StatelessWidget {
  final Widget child;
  final BentoCardSize size; // standard, hero, compact
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  // build with white bg, radiusLg, elevation-1, InkWell ripple if tappable
}
```

### 5.4 Lawyer Card (specialized Bento)

```
┌──────────────────────────────────────────┐
│  ┌────┐                                   │
│  │ ◉  │  Adv. Meera Kapoor     ●online   │
│  │ ph │  Criminal · Family                │
│  └────┘  Mumbai, MH · EN, HI, PN          │
│          ★ 4.8  (124 ratings) · 7yrs exp  │
└──────────────────────────────────────────┘
```
- Avatar: 56x56, `radius-avatar`
- Online dot: 10px diameter, sage-500, positioned top-right of avatar with 2px white ring
- Name: `heading-3`
- Specialties line: `body-sm` slate-500
- Location + languages: `caption` slate-500
- Rating row: `caption` with filled star icon
- Tap target: entire card

### 5.5 Chat Message Bubbles

```
Received (left-aligned):
┌──────────────────────┐
│ Hello, how can I help │
│ you today?            │
└──────────────────────┘
 10:42 AM

Sent (right-aligned):
                   ┌──────────────────────┐
                   │ I need advice about a │
                   │ notice I received.    │
                   └──────────────────────┘
                              10:43 AM · Read
```
- Received: bg `slate-100`, text `slate-700`
- Sent: bg `blue-500`, text white
- Radius: asymmetric — 16px on three corners, 4px on the "tail" corner (bottom-left for received, bottom-right for sent)
- Max width: 76% of screen width
- Timestamp: `caption-sm` slate-400, below bubble on own-message side
- Status indicator (sent only): "Sending" / "Delivered" / "Read" in `caption-sm`, sage-500 when read

### 5.6 Navigation

#### 5.6.1 Bottom Tab Bar (User + Lawyer)
Floating bar near bottom of screen, not edge-to-edge. Glass background.

```
        ┌──────────────────────────────────┐
        │   [Home]  [Chats]  [History] [Me]│
        └──────────────────────────────────┘
         ◀─────────── 16px margin ──────────▶
```
- 4 tabs (User): Home, Chats, History, Profile
- 4 tabs (Lawyer): Dashboard, Chats, History, Profile
- Floating: 16px from bottom edge, 20px horizontal margin
- Height: 64px · Radius: `radius-xl` (20px)
- Background: **glassmorphism** (`rgba(255,255,255,0.85)` + blur)
- Elevation: `elevation-3`
- Active tab: `blue-500` icon + label, subtle `blue-50` pill background
- Inactive: `slate-500` icon + label

#### 5.6.2 App Bar (per-screen top)
- Height: 56px
- Bg: transparent (content scrolls under on supported screens) or `slate-50`
- Title: `heading-2` slate-700
- Left: back button (chevron-left icon button) or menu
- Right: optional action icons (search, filter, more)
- No bottom border — rely on scroll shadow when content scrolls underneath

### 5.7 Bottom Sheets (Glass)

Used for: filter selection, more options menu, rating modal, OTP re-request.

- **Container:** glass effect (rgba white 0.92 + blur 24px)
- **Radius:** `radius-xl` top corners only (20px), 0 bottom
- **Grabber bar:** 40px wide, 4px tall, slate-300 centered at top
- **Padding:** `space-6` (24px) horizontal, `space-4` top
- **Dismiss:** swipe down, tap outside, or close button
- **Entrance animation:** slide up from bottom, `duration-base` `easing-decelerate`

### 5.8 Avatars

- **Sizes:** xs (24), sm (32), md (40), lg (56), xl (80), 2xl (120)
- **Radius:** always 50%
- **Fallback** (no photo): circle filled with `slate-200`, initials in white `heading-3` (or sized proportionally)
- **Online indicator dot:** 10-14px (proportional), sage-500, positioned bottom-right, with 2px white ring

### 5.9 Badges

#### Verified Badge
`badge-check` icon (filled), sage-500 color, 14x14px, inline next to lawyer name.

#### Specialty Tag (Pill)
- Bg: `blue-50` · Text: `blue-700` · `body-sm`
- Padding: 4px 10px · Radius: `radius-pill`

#### Status Badges (Admin queue)
- Pending Review: amber bg + text
- Approved: sage bg + text
- Rejected: error bg + text

### 5.10 Toasts / Snackbars

- Position: bottom, floating with 16px from edge, above tab bar
- Bg: `slate-800` · Text: white · `body`
- Radius: `radius-md`
- Icon on left (success/warning/error variant)
- Duration: 3.5s for info, 5s for error
- Slide up + fade in, ease out opposite

### 5.11 Empty States

Each empty state has:
- Illustration (custom minimal line art in slate-400, 120-160px)
- `heading-3` descriptive headline
- `body-sm` helper paragraph
- Optional primary CTA button

Examples:
- No lawyers found: "No lawyers match your filters. Try widening your search."
- No chats yet: "Your conversations will appear here."
- No consultations: "Start chatting with a lawyer to build your history."

### 5.12 Loading States

- **Skeleton loaders** for lists (not spinners). Grey shimmer rectangles shaped like actual content.
- **Inline spinner** for button loading (white 16px spinner inside primary button).
- **Full-screen spinner** only for critical blocking operations (first-time auth).
- Skeleton pulse animation: `duration-slower` infinite ease-in-out.

---

## 6. Screen-by-Screen Specifications

### 6.1 Splash Screen
- Duration: 1.5s max (longer = user frustration)
- Center: "jerry" wordmark at `display-lg`, slate-700
- Below: tagline in `body` slate-500: "Legal help, instantly"
- Bg: `slate-50`
- No progress indicator (keep calm)

### 6.2 Welcome / Onboarding Carousel
3 cards, swipeable, each a full-screen bento-style illustration + copy.

**Card 1:** "Find the right lawyer, fast" · illustration of magnifying glass over scale
**Card 2:** "Chat, call, or video — your choice" · illustration of three modes
**Card 3:** "Verified lawyers across India" · illustration of badge + map pin

Bottom: page dots indicator, "Get Started" primary button (appears on last card), "Skip" text button top-right.

### 6.3 Role Selection Screen
Two big tappable cards, vertically stacked:

```
┌────────────────────────────────────┐
│                                    │
│   🙂  I need legal help             │
│       Sign up as a client           │
│                                    │
└────────────────────────────────────┘

┌────────────────────────────────────┐
│                                    │
│   ⚖  I am a lawyer                 │
│       Sign up as a lawyer           │
│                                    │
└────────────────────────────────────┘
```
- Each card: `elevation-2`, tap ripples to `blue-50` bg briefly then navigates
- Icons: lucide, `icon-2xl`, slate-600

### 6.4 Sign Up Form (User)
- App bar: back button + "Create account" title
- Fields (stacked, `space-4` between):
  - Full name
  - Email
  - Password (eye toggle for visibility)
  - Confirm password
  - City (dropdown with search)
  - State (dropdown)
  - Preferred language (dropdown — 12 options)
- Terms checkbox: "I agree to Terms & Privacy Policy" (links inline)
- Primary button "Send OTP" at bottom, full-width, fixed above keyboard

### 6.5 Sign Up Form (Lawyer)
Same as user form +:
- Bio preview (multi-line, 300 char max — can be filled later)
- Specialties selection (opens bottom sheet with chip multi-select)
- Languages spoken (multi-select)
- Years of experience (numeric)
- License number field
- Note: "You'll upload your license after verifying email." shown as helper text

### 6.6 OTP Verification Screen
- Illustration top: envelope icon in sage-500, 64px
- `heading-1`: "Check your email"
- `body` slate-500: "We sent a 6-digit code to {email}"
- OTP input (6 boxes, auto-advance)
- Countdown: "Resend in 0:30" (slate-400), becomes tappable "Resend" link at 0:00
- Primary button "Verify" (enables only when 6 digits entered)
- Bottom text button: "Change email"

### 6.7 Login Screen
- Minimal: email, password, "Forgot password?" link
- Primary "Sign In" button
- Separator: "or" with hairline on sides
- Bottom: "New to jerry? Create account" text button

### 6.8 Multi-Device Conflict Dialog (modal)
Glass bottom sheet variant:
```
┌─────────────────────────────────────┐
│                                     │
│  🔒 Already signed in                │
│                                     │
│  You're signed in on:                │
│  📱 iPhone 13 · Mumbai               │
│  Last active 2 minutes ago           │
│                                     │
│  ┌─────────────────────────────┐    │
│  │ Log Out Other Device         │    │  (primary)
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │ Cancel                        │    │  (secondary)
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
```

### 6.9 Lawyer License Upload Screen (post-signup)
- `heading-2`: "Verify your practice"
- `body` slate-500: "Upload your Bar Council registration certificate for admin verification. This usually takes 24–48 hours."
- Big dotted-border upload area (40% of screen height):
  - Upload icon 48px
  - "Tap to upload PDF, JPG, or PNG (max 5 MB)"
  - When file selected: filename + size + small `x` to remove
- License number input
- Primary button "Submit for Review" — disabled until both file + number present

### 6.10 Lawyer "Under Review" Screen
Waiting room after license submitted, before approval.
- Illustration: clock + document, sage-400, 160px
- `heading-2`: "Review in progress"
- `body` slate-500: "Our team is verifying your credentials. You'll get a notification as soon as you're approved."
- Meta info: "Submitted: [date]"
- Secondary button: "Logout"
- Disabled rest of app.

### 6.11 User Home — Lawyer List Screen
**Layout:**
- App bar: "Find a lawyer" title, search icon right, filter icon right
- Sticky below app bar: horizontal scrolling **specialty chips** row (default "All" + list of specialties)
- Below: a **"Featured lawyer"** hero bento card (top-rated online lawyer for user's language)
- Below that: "All lawyers" heading + grid of lawyer cards (stacked, not columns)
- Scroll to reveal more with skeleton loaders
- Pull-to-refresh
- Bottom tab bar floating

### 6.12 Filter Bottom Sheet
Glass bottom sheet, 70% screen height:
- Grabber
- `heading-3`: "Filters"
- Sections (collapsible):
  - **Specialty** (chips, multi-select)
  - **Location** (city picker)
  - **Languages** (chips, multi-select)
  - **Online only** (toggle)
  - **Min rating** (slider 1-5)
- Footer fixed: "Clear all" (text button left) + "Apply filters" (primary right)

### 6.13 Lawyer Detail Screen
**Layout (scrollable, hero-first):**
- Parallax header (240px): large profile photo background + `elevation-2` overlay card bottom half containing name, verified badge, online dot, specialties, rating
- Below: stacked bento cards:
  - **Bio card** — full bio text
  - **Quick facts card** (paired bentos): Years exp · Languages
  - **Specialties card** — chips
  - **Recent reviews card** — list of 5 latest ratings with stars + text
- Fixed at bottom (above tab bar): 3 action buttons in a row — `Chat`, `Voice`, `Video`. If lawyer offline, all disabled with single "Unavailable" overlay instead.

### 6.14 Chat Thread Screen
**Layout:**
- App bar: back + small avatar + name + online dot · right: voice/video call icon buttons
- Main: scrollable message list (newest at bottom)
  - Date separators: small chip centered ("Today", "Yesterday", "12 April")
  - Typing indicator: 3 animated dots in a `slate-100` bubble (left side)
- Bottom input area (always visible):
  - Fixed above keyboard when active
  - Text field (multiline, auto-grow to 4 lines max) in `slate-50` pill with 20px radius
  - Right: circular send icon button (blue-500), disabled when empty
  - In MVP: no attachment button (deferred)

### 6.15 Chats List Screen
- App bar: "Messages"
- Search bar pinned at top (slate-50 pill input)
- List of threads — each is a bento row:
  - Avatar + online dot
  - Name + last message preview
  - Timestamp (right) + unread count pill (sage-500)
- Sorted by recent message
- Swipe-left on thread: reveals "Delete" action (red, local only — doesn't delete from server)

### 6.16 Incoming Call Screen (Lawyer side)
**Full-screen glass overlay:**
- Backdrop blur of whatever screen user was on
- Large avatar (120px) top-centered
- Caller name `heading-1` white
- "Incoming video call…" `body` slate-100
- Pulsing outer ring around avatar (subtle, `duration-slower` sine)
- Bottom: two circular buttons (80px each), 40px apart:
  - Reject: `error` bg, phone-x icon
  - Accept: `sage-500` bg, phone/video icon
- Swipe-up on accept button for "accept + mute" option (v2)

### 6.17 Active Call Screen (Video)
**Layout:**
- Full-screen remote video stream
- Top overlay (glass, auto-hide after 3s, tap to show):
  - Back "minimize" button (top-left) — call continues in small floating window
  - Call duration (top-center) · `heading-3` white
  - Network strength icon (top-right)
- Local video preview: small floating card bottom-right (120x160px), `radius-md`, draggable
- Bottom overlay (glass):
  - Icon buttons row (5 total, 56px each): mute mic, toggle video, flip camera, speaker, end call
  - End call button is `error` bg (stands out)

### 6.18 Active Call Screen (Voice)
Same as video but:
- No remote/local video streams
- Background: gradient (slate-800 to slate-900)
- Huge avatar centered (240px) with subtle pulse ring
- Status: "Connected · 02:14" below avatar

### 6.19 Post-Call Rating Modal
Glass bottom sheet auto-appears after call ends:
- `heading-2`: "How was your consultation?"
- Avatar + name of lawyer
- 5 stars, tappable (fill animates sage-500 on tap)
- On 4+ stars: optional text field "Share feedback (optional)"
- On <4 stars: text field becomes required, prompt "Help us understand what went wrong"
- "Submit" primary button · "Skip" text button

### 6.20 Consultation History Screen
- App bar: "History"
- Filter chips row: "All" · "Chat" · "Voice" · "Video"
- List of bento row items:
  - Lawyer avatar + name
  - Type icon + duration
  - Date + time (right-aligned)
  - Star rating given (small, right)
- Tap → detail view with rebill (future: rebook) option

### 6.21 Profile Screen (User)
- Hero: large avatar (upload on tap), name, email
- Stats row: 3 metric bentos — "Consultations" · "Avg rating given" · "Member since"
- Sections (each a bento card list):
  - **Personal info**: edit name, phone, language, location
  - **Notifications**: toggle settings
  - **Privacy**: policy links
  - **Support**: help, contact
  - **About**: terms, version
- Bottom: "Log out" red text button

### 6.22 Profile Screen (Lawyer)
Similar to user but extended:
- Big hero: avatar + name + verified badge + online/offline toggle prominent
- Stats bentos: "Total consultations" · "Avg rating" · "Languages"
- **Professional info** card (bio, specialties, years, rate) — editable
- **Availability settings** card
- Rest similar to user profile

### 6.23 Lawyer Dashboard / Home
- App bar: "Hi, {Name}"
- Online toggle bar fixed under app bar (big, obvious — critical control)
- Hero bento: "Today's snapshot"
  - 3 metrics paired: consultations today · current streak · today's rating avg
- Next bento: "Recent messages" (top 3 with quick reply)
- Next bento: "This week" chart (simple line/bar chart of consultations)
- Bento: "Improve your profile" nudge card if profile <80% complete

### 6.24 Admin — Approval Queue Screen
- App bar: "Pending Reviews" with count badge
- Filter: "Oldest first" (default) toggle
- List of bento items:
  - Lawyer avatar + name
  - License number + submitted date
  - "Awaiting Review" amber pill
  - Tap → approval review screen

### 6.25 Admin — Lawyer Review Screen
- App bar with lawyer name + back
- Hero bento: full lawyer profile (everything they submitted)
- Big bento: "License Document" with inline PDF/image viewer
- Bottom fixed: 2 buttons side-by-side — "Reject" (secondary error style) + "Approve" (primary)
- Reject opens bottom sheet with required reason textarea

### 6.26 SuperAdmin — Dashboard
- App bar: "Dashboard"
- 6 metric bentos in a paired grid (2 columns on phones, scrollable):
  - Total Users (+% vs last week)
  - Total Lawyers (+% vs last week)
  - Consultations This Week
  - Avg Platform Rating
  - Pending Approvals (tappable → approval queue)
  - Active Admins
- Below: "Admin Management" bento → full-screen admin CRUD on tap

### 6.27 SuperAdmin — Admin Management Screen
- "+" button top-right to create admin
- List of existing admins (bento rows): name, email, created date, active toggle
- Create Admin form (full screen, on tap of +): email, name, temp password

---

## 7. Animations & Micro-Interactions

### 7.1 Screen Transitions
- **Forward navigation:** slide right-to-left + fade, `duration-base`, `easing-standard`
- **Modal presentation:** slide up from bottom, `duration-slow`, `easing-decelerate`
- **Back / dismissal:** reverse of entry
- **Root tab switch:** no slide — crossfade only, `duration-fast`

### 7.2 Button Press
- Scale down to 0.97 on press-in, `duration-fast`
- Scale back with slight overshoot on release (spring-like)
- Ripple contained within button radius

### 7.3 Online Dot Pulse
Sage-500 dot subtly scales 1.0 → 1.15 → 1.0 over 2s loop. Conveys "alive" without demanding attention.

### 7.4 Incoming Call Avatar Pulse
Outer ring around avatar expands and fades, `duration-slower`, loops. White at 30% opacity.

### 7.5 Message Sending Status
- "Sending" text appears beneath message immediately on tap send
- Smoothly transitions to "Delivered" on ack (crossfade, `duration-fast`)
- "Read" shows sage-500 checkmark

### 7.6 Rating Stars
On tap, star fills from center outward with slight scale pop (1.0 → 1.25 → 1.0), filling tap-index and all below.

### 7.7 Filter Chip Selection
Chip scales slightly up and bg transitions `slate-100 → blue-100` over `duration-fast`.

### 7.8 Toast Enter
Slides up 20px from bottom + fades in, `duration-base`, `easing-decelerate`.

### 7.9 Skeleton Loader Shimmer
Diagonal gradient sweep, `duration-slower`, infinite, `easing-standard`.

### 7.10 Avoid
- Bouncy / spring-heavy animations (clashes with Calm UI)
- Parallax on every scroll (only hero images on detail screens)
- Excessive fade-ins on content load — use skeletons instead

---

## 8. Responsive Behavior

### 8.1 Target Devices (Mobile-Only in MVP)

| Device | Width | Notes |
|---|---|---|
| Small phone | 360px (Pixel 4a, iPhone SE) | Minimum support, test everything |
| Standard phone | 390px (iPhone 13/14) | Primary design target |
| Large phone | 430px (iPhone 14 Pro Max) | Ample space, no layout changes |
| Small tablet | 600-768px | Flutter builds will run; single-column layout scales up with wider padding |

### 8.2 Layout Rules
- Content max-width: 500px on tablets+ (centered, with extra slate-50 padding)
- Tab bar: always 16px from bottom, 20px horizontal margin
- Bento cards: never exceed 500px width
- Text: max 65 characters per line (enforced by container width on tablets)

### 8.3 Safe Area Handling
- Respect notch / dynamic island (iOS) with `SafeArea` widget
- Respect bottom home indicator (extra 8px bottom on iOS)
- Android gesture bar: account for 16px extra bottom padding on screens without floating tab bar

### 8.4 Landscape Orientation
- **Video call only** supports landscape
- All other screens: force portrait via `SystemChrome.setPreferredOrientations`

---

## 9. Accessibility

### 9.1 Contrast
- All text meets WCAG AA (4.5:1 for body, 3:1 for large text)
- Primary CTA (`blue-500` on white): 5.1:1 ✅
- Body text (`slate-600` on `slate-50`): 7.8:1 ✅

### 9.2 Touch Targets
- Minimum 44x44px (iOS) / 48x48px (Android)
- Icon buttons: always ≥40px visible + 4-8px padding inside tap area for 48px total

### 9.3 Dynamic Type
- All text uses `MediaQuery.textScaleFactor` to respect system font scaling
- Test at 1.3x and 1.5x — layout must not break

### 9.4 Screen Reader Support
- `Semantics` widget on all interactive elements
- Meaningful labels: "Call Lawyer Meera, video call" (not just "call button")
- Image assets: `semanticsLabel` described or marked `excludeFromSemantics: true` for decorative

### 9.5 Color Independence
- Never use color alone to convey info. Pair with icon or text.
- Example: online status = sage dot + "Online" label (not just the dot)

### 9.6 Focus States
- Clear focus rings for keyboard navigation (even on mobile for hardware keyboard users)
- Focus ring: 2px `blue-500`, offset 2px

---

## 10. Flutter Implementation Notes

### 10.1 Theme Setup (Primary Tokens)

```dart
// lib/shared/theme/app_theme.dart

class AppColors {
  // Neutrals
  static const slate50 = Color(0xFFF6F7F9);
  static const slate100 = Color(0xFFEDF0F4);
  static const slate600 = Color(0xFF475268);
  static const slate700 = Color(0xFF323B4D);
  // Primary
  static const blue500 = Color(0xFF3B6FC8);
  static const blue600 = Color(0xFF2B5AAE);
  // Sage
  static const sage500 = Color(0xFF5E874C);
  // Semantic
  static const error = Color(0xFFB5473D);
  static const warning = Color(0xFFC89637);
  // (full list from section 3.1)
}

class AppSpacing {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const s8 = 32.0;
}

class AppRadius {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
}

class AppShadows {
  static const elevation1 = [BoxShadow(color: Color(0x0A1E2535), offset: Offset(0, 1), blurRadius: 2)];
  static const elevation2 = [BoxShadow(color: Color(0x0F1E2535), offset: Offset(0, 2), blurRadius: 6)];
  static const elevation3 = [BoxShadow(color: Color(0x141E2535), offset: Offset(0, 4), blurRadius: 16)];
}
```

### 10.2 Reusable Widgets to Build First

**Priority 1 (needed on every screen):**
- `BentoCard` — standard card with tap ripple
- `PrimaryButton` / `SecondaryButton` / `TextButton` (app-styled)
- `AppTextField` — with label, helper, error states
- `AppAppBar` — custom app bar
- `AppAvatar` — with online dot variant
- `StatusPill` — specialty chip / status badge

**Priority 2:**
- `LawyerCard` (composed of BentoCard + AppAvatar + StatusPill)
- `OtpInput` — 6-box auto-advance
- `GlassBottomSheet` — reusable glass container for modals
- `ChatBubble` — message bubble (sent + received variants)
- `FilterChip` — selectable chip

**Priority 3:**
- `IncomingCallOverlay`
- `CallControls` — bottom sheet for video/voice call
- `RatingStars` — interactive + display-only

### 10.3 Third-Party Package Recommendations

| Package | Use |
|---|---|
| `google_fonts` | Inter font bundling |
| `lucide_icons` | Icon library |
| `flutter_animate` | Clean declarative animations |
| `cached_network_image` | Profile photo caching |
| `shimmer` | Skeleton loaders |
| `pinput` | OTP input (instead of custom) |
| `flutter_svg` | Vector illustrations on empty states |

### 10.4 Glass Effect Implementation

```dart
class GlassContainer extends StatelessWidget {
  final Widget child;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(AppRadius.xl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.72),
            border: Border.all(color: Colors.white.withOpacity(0.8)),
            borderRadius: borderRadius ?? BorderRadius.circular(AppRadius.xl),
            boxShadow: AppShadows.elevation4,
          ),
          child: child,
        ),
      ),
    );
  }
}
```

### 10.5 Performance Guidelines

- Use `const` constructors aggressively (free perf)
- Wrap list items in `RepaintBoundary` if they have complex sub-trees
- Use `ListView.builder` for all lists (never `Column` with `.map()`)
- Images: always use `cached_network_image` with placeholder + memCacheHeight/Width
- Avoid `Opacity` widget — use `AnimatedOpacity` or `FadeTransition` instead (they're cheaper)
- Don't blur entire screens; blur only the overlay rectangle

---

## 11. Asset List

### 11.1 Illustrations Needed (commission or stock)
- Welcome carousel (3 illustrations)
- Empty states (5): no lawyers, no chats, no history, no network, generic error
- Lawyer onboarding (license upload hero)
- "Under review" (clock + document)
- Success celebrations (approval, first-consultation-done)

**Style:** minimal line art, two-color max (slate-500 + accent), no shading, 1.5px strokes.

### 11.2 Icons
Lucide library handles all functional icons (see Section 4.4).

### 11.3 App Icon
Rounded-square variants for iOS (1024x1024) + Android adaptive (foreground + background layers).

### 11.4 Launch Screen
iOS `LaunchScreen.storyboard` + Android `launch_background.xml`: slate-50 bg with "jerry" wordmark centered.

---

## 12. Dark Mode (Deferred to v2)

**Not in MVP** — but tokens are designed such that adding dark mode is a ~2-day job later:
- `slate-50` becomes `slate-900` for bg
- Cards become `slate-800` with subtle lift shadow
- Text inverts (`slate-700` ↔ `slate-100`)
- Primary blue stays same (works on both)
- Sage stays same
- Glass becomes: `rgba(30,37,53,0.72)` with white text

---

## 13. Design-to-Dev Handoff Guidance

When Cursor AI is implementing:
1. Build the design tokens file first (Section 10.1)
2. Build the 6 Priority-1 reusable widgets (Section 10.2)
3. Build the auth flow screens (6.1 → 6.8) to validate the design system works end-to-end before moving on
4. Build User home (6.11) + Lawyer detail (6.13) as the next validation — these prove the Bento card system
5. Build chat (6.14, 6.15) — validates real-time UI
6. Build call screens (6.16, 6.17, 6.18, 6.19) — most complex UI
7. Build everything else in PRD feature order

Never skip the reusable widgets step. Building one-off UIs for each screen will result in design drift.

---

*End of Design.md — ready for review. This completes the 4-document set.*
