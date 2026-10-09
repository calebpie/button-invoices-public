# HIG checklist for the UX review

Built Oct 9, 2026 from Apple's live Human Interface Guidelines (each page's JSON at
developer.apple.com/tutorials/data/design/human-interface-guidelines/<page>.json, the data
the web pages render; page dates are Apple's "updated" notes). One line per guideline that
applies to this app on her iPhone 15 Pro Max (iOS 27, Automatic light/dark, default text
size, Bold Text off). Out of scope: iPad, VoiceOver and other assistive tech, multitasking,
accounts. Kept from Accessibility: target size, contrast, text size.

Links are https://developer.apple.com/design/human-interface-guidelines/<page>.
"Result" is filled in during the review: ok, nit N (Docs/ui-nits.md), spec (a deliberate
SPEC.md choice), or n/a.

## Foundations

| Page | Guideline | Result |
|---|---|---|
| design-principles (Jun 2026) | Agency: "make it easy to recover from mistakes"; guided flows easy to skip or escape | ok (undo, discard questions; see nit 16) |
| design-principles | Familiarity: "Keep visuals and interactions consistent" once a behavior is established | nits 13, 15, 29 |
| design-principles | Familiarity: "Provide clear feedback" — show when controls are available, when content changes | nits 12, 34 |
| design-principles | Simplicity: "Include just what's necessary"; establish hierarchy | ok |
| designing-for-ios | Controls easier to reach in the middle or bottom of the screen; swipe back and row swipes matter | ok (Next, bottom bar) |
| layout (Sep 2026) | Most important items near the top and leading side | ok |
| layout | Align elements; indentation means subordinate | nit 23 |
| layout | Group related items with space, containers or separators | nit 24 |
| layout | Controls on Liquid Glass, separated from content by a scroll edge effect, not a solid background | ok (scroll edge effect on all bars) |
| layout | Respect safe areas and system margins | nit 23 |
| layout | Adapt to text-size changes (stack, grow rows) | spec (AdaptiveRow); not rechecked at large sizes |
| typography | 17 pt default, 11 pt minimum; avoid light weights | ok (smallest seen 11 pt, nit 35) |
| typography | Keep hierarchy distinct; few typefaces; prefer built-in text styles | nit 30 |
| typography | Text styles scale with Dynamic Type; avoid truncation as size grows | spec (bars capped at xxxLarge); she uses the default |
| color (Dec 2025) | Don't use one color for two meanings (accent for interactive vs plain text) | ok |
| color | Light, dark and increased-contrast variants for custom colors | ok (spec) |
| color | Don't rely on color alone | nits 17, 31 |
| color | Don't hard-code system color values; use semantic colors as intended | ok |
| color | Liquid Glass: color sparingly, on the background of primary actions only; not on several controls | ok |
| color | iOS: grouped background colors for grouped lists | ok |
| dark-mode | Looks good in both; Auto may switch while the app runs | ok (every screen seen in both) |
| dark-mode | Contrast at least 4.5:1, aim for 7:1 for custom colors in small text | nits 17, 25 |
| dark-mode | Soften white backgrounds of content images in Dark Mode | PDF page is white in dark mode: accepted (a document) |
| dark-mode | Prefer system background colors (base vs elevated in sheets) | ok |
| materials (Sep 2025) | Liquid Glass only in the control layer, not the content layer; sparingly on custom controls | ok |
| materials | Regular glass by default; clear only over rich media | ok |
| sf-symbols | Fill variants for tab bars and swipe actions; outline in toolbars and lists | ok |
| sf-symbols | Consistent rendering; symbol animations judiciously | ok |
| icons | One icon style, weight matched to text; standard symbols for standard actions (trash, square.and.arrow.up, plus.square.on.square for Duplicate, archivebox, ellipsis) | nit 29 (two ⋯ shapes: ellipsis.circle and ellipsis), otherwise ok |
| writing (Dec 2025) | One term per concept; a list of common terms | nits 13, 29 |
| writing | Labels are verbs; consistent capitalization per element type | nit 22 |
| writing | Multistep flows: consistent Next/Continue; "Done" at the end | ok |
| writing | Possessives sparingly and consistently; never "we" | ok |
| writing | Say "tap", not "click" | ok |
| writing | Empty states give a next step and a button | ok |
| writing | Errors next to the problem, say how to fix it, no blame | nits 12, 14 |
| writing | Hints in text fields; errors beside the field | ok |
| motion (Sep 2025) | Motion purposeful; brief, precise feedback; no motion on frequent interactions | ok (nits 1–7 covered motion) |
| motion | Let people cancel motion; don't make them wait for an animation | ok |
| motion | Feedback motion follows the gesture (dismiss the way it came in) | ok |
| accessibility | Contrast: 4.5:1 up to 17 pt, 3:1 at 18 pt or bold (WCAG AA) | nits 17, 25 |
| accessibility | Targets 44×44 pt (28×28 minimum); about 12 pt between bezeled controls, 24 pt around unbezeled ones | nit 21 |
| accessibility | Offer an on-screen alternative to every gesture | ok (context menus, buttons) |
| accessibility | Avoid time-boxed elements that dismiss themselves | ok |
| branding (Sep 2026) | Accent color judiciously: primary actions and status, not broadly on controls | ok |
| branding | Familiar components; branding defers to content | ok |
| privacy | Ask for permission only when the feature is used; purpose string in sentence case with a period | device check (Docs/m3-test.md, Part 1, step 5) |
| app-icons (Jun 2026) | Layered icon for Liquid Glass, dark and tinted | ok (spec) |

## Patterns

| Page | Guideline | Result |
|---|---|---|
| entering-data | Prefill sensible defaults; offer choices over typing | nit 20 |
| entering-data | Validate as people type; Next available only once required data is in | nits 12, 17 |
| entering-data | Accept paste and drag | ok |
| feedback | Status near the item it describes | ok |
| feedback | Alerts only for critical, actionable info | ok |
| feedback | Warn only for unexpected, irreversible data loss | spec (delete confirmations kept on purpose) |
| feedback | Confirm significant completions; show why a command can't run | ok (Finish haptic) |
| loading | Show something at once; progress for anything over a moment | device check (Part 4, step 2) |
| modality | Modal only with a clear benefit; short, simple tasks | ok |
| modality | No "app within an app": a single path, no buttons that look like dismiss | ok |
| modality | Full-screen modal for complex multistep tasks (photo editing, camera) | ok (cutout, receipt) |
| modality | Obvious dismissal (top toolbar button or swipe down) | nit 33 |
| modality | Confirm before closing when content would be lost | nit 16 |
| modality | Title that names the task | ok |
| modality | One modal at a time; dismiss before presenting another | ok |
| undo-and-redo | Shake/three-finger undo, named ("Undo Name") | ok (Undo Delete Draft seen) |
| undo-and-redo | Show the result of an undo (scroll to it) | ok (nit 4) |
| undo-and-redo | Multiple undos | ok |
| searching (Jun 2026) | One clear place to search; show its scope in the placeholder | ok |
| searching | Suggestions or recents before typing | not adopted (search box is empty-state shapes) |
| collaboration-and-sharing | Share button in a convenient place (toolbar); system share sheet | ok |
| settings | Minimal settings; task options where the task is; nothing that duplicates system settings | ok |
| launching | Launch instantly; restore the previous state granularly | ok |
| offering-help | Tips short, for simple features, cadence-limited, easy to dismiss | ok |
| onboarding | Teach in context rather than up front | ok |
| playing-haptics | System patterns by their documented meaning; consistent; not overused | ok |

## Components

| Page | Guideline | Result |
|---|---|---|
| tab-bars (Jun 2026) | Navigation only, not actions; always visible except under a modal | ok |
| tab-bars | Single-word labels; filled SF Symbols; empty sections explain why | ok |
| toolbars (Dec 2025) | Standard Back and Close buttons (symbols, not "Back"/"Close" text) | nit 15 |
| toolbars | Titles under 15 characters; not the app name | ok ("Invoice 0261009-2" is 17: acceptable) |
| toolbars | Symbols without borders; one prominent action, on the trailing side | nit 32 |
| toolbars | Large title shrinks to standard on scroll | ok |
| toolbars | Text-labeled and symbol items kept apart | ok |
| toolbars | Standard components with concentric corners | ok |
| sheets (Mar 2026) | Cancel leading, Done trailing; Done always paired with Cancel or Back | ok |
| sheets | Never Cancel, Done and Back together | ok |
| sheets | One sheet at a time; close the first before showing another | ok |
| sheets | Complex or prolonged flows: consider full screen instead of a sheet | ok |
| sheets | Swipe down to dismiss; ask if there are unsaved changes | ok; nit 16 |
| sheets | Medium detent and grabber only where it helps | ok |
| alerts | Sparingly; not for common undoable actions; not at launch | spec (delete questions kept) |
| alerts | Title describes the situation; sentence case if a sentence | nit 29 |
| alerts | Buttons: one or two words, verbs; "Cancel" for cancel; destructive style only for unintended destruction | ok |
| action-sheets | For choices about an action she started; destructive at top, Cancel at bottom; short title | nit 16 |
| lists-and-tables | Grouped style for grouped data; feedback on selection | nit 11 |
| lists-and-tables | Disclosure indicator for drill-in; info button only for info | ok |
| buttons (Dec 2025) | 44×44 pt hit region; press state on custom buttons | nit 21 |
| buttons | One or two prominent buttons per view; style, not size, marks the preferred choice | nit 32 |
| buttons | Title-case verb labels; familiar symbols | nit 22 |
| buttons | Primary role never on a destructive button | ok |
| buttons | Activity indicator inside a button whose action takes time | ok (Saving Photo…) |
| menus (Jun 2026) | Verb labels, title case, no articles; "…" when more input follows | ok |
| menus | Icons on all items of a group or none; standard icons | ok |
| menus | Most used first; destructive last | ok |
| context-menus | Items also available in the main interface; consistent across the app | ok |
| context-menus | Destructive items last and red | ok |
| pull-down-buttons | At least three items; don't hide a view's primary actions in it | nit 28 |
| text-fields | Label plus placeholder; size matches expected text | ok |
| text-fields | Right keyboard type; number formatter; Clear button | ok (Invoice # uses the default keyboard: minor) |
| pickers | Pickers in context; compact date picker when space is tight | nit 19 |
| steppers | Value visible beside the stepper; pair with a field for large changes | ok |
| segmented-controls | Up to about five segments; nouns, title case; text or images, not both | ok |
| toggles | Switch only in a list row; context names what it controls | ok |
| search-fields (Jun 2026) | Placeholder says what can be searched; results while typing | ok |
| search-fields | iOS: search in a toolbar at the bottom if there's room; at the top when there's no bottom toolbar | spec (top; tab app with no bottom toolbar) |
| scroll-views (Jun 2026) | Make scrollable content apparent | ok |
| scroll-views | Automatic scroll edge effect style; one per view; only under floating controls | ok |
| scroll-views | Scroll to bring new content into view | device check (Part 4, step 3) |
| image-views | An interactive image should be a button | nits 18, 34 |
| activity-views | Share button opens the share sheet; no duplicate actions | ok |
| progress-indicators | Determinate when possible; keep moving; description that adds value | ok |
| popovers | Avoid popovers in compact width | nit 16 (system bubble) |
| sliders | Familiar direction; consider a stepper or field alongside | ok |
| status-bars | Content under the status bar obscured by a scroll edge effect | ok |
| home-screen-quick-actions | Short titles, SF Symbols, up to four | nit 13 |

## Inputs

| Page | Guideline | Result |
|---|---|---|
| gestures | Standard gestures mean what people expect (tap, swipe, touch and hold, double tap to zoom, pinch) | ok |
| gestures | Respond immediately; show when a gesture isn't available | nit 18 |
| gestures | Custom gestures only with an on-screen alternative | ok |
| virtual-keyboards (Jun 2025) | Keyboard type matches the content; Return key labeled for the action | ok |
| virtual-keyboards | Keep important UI visible above the keyboard (keyboard layout guide) | device check (Part 4, step 3) |
| virtual-keyboards | Controls above the keyboard only if relevant; Liquid Glass if used | ok (none, spec) |
| keyboards | Standard shortcuts (⌘Z) respected | ok |

## Machine learning (Jun 2026)

| Guideline | Result |
|---|---|
| Critical vs complementary: the cutout, look-alike check and receipt reading are complementary; the app must work without them | ok (fallbacks) |
| Corrections: familiar, easy, guided over freeform; show corrected result at once; persist | ok (Touch Up, Also known as) |
| Corrections: let people correct their corrections | ok |
| Multiple options: most likely first; not too many; easy to tell apart | nit 22; device check (Part 4, step 1) |
| Confidence: translate into plain words; don't show low-confidence results prominently | device check (Part 4, step 1) |
| Limitations: set expectations, show how to get good results, explain poor results | ok (receipt footer) |
| Mistakes: match the fix to the consequence (a wrong amount on an invoice is serious) | ok (amount is shown, never silently filled) |
