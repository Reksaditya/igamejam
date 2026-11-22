---
name: game-ui-design
description: Design and polish high-craft UI/UX for games and interactive apps (HUDs, menus, diegetic/in-world interfaces, puzzle benches, OS/desktop sims, pixel-art UI, typography, color hierarchy, and tactile feedback) without generic "AI dashboard" clutter.
---

# Game & Interactive UI Design

Use this skill alongside `godot-ui` whenever designing, redesigning, or polishing UI layouts, HUDs, menus, diegetic screens, or interactive apps. `godot-ui` covers Godot 4.7 technical wiring; this skill governs **visual craft, hierarchy, readability, and game feel**.

## 1. Anti-Clutter & Anti-"AI Dashboard" Rules

- **Kill unnecessary boxes:** Do not wrap every label, button, or hint in its own bordered `PanelContainer` or stacked card. Group related elements on one quiet surface or let them sit directly on the canvas with clean alignment and whitespace.
- **Protect the focal area:** In gameplay, puzzle, and simulation screens, the playable surface (world, bench, board, document) owns the visual center. Keep chrome, navigation, and status indicators minimal and tucked cleanly at edges or corners.
- **Cut redundant headers:** If the screen's purpose is obvious from its visuals, skip heavy top header bars and giant title banners. Keep only what the player actively needs (e.g., a subtle corner Back button, compact status, or minimal keybind hint).
- **Use a disciplined palette:** Stick to a small, cohesive palette per context—1 primary surface, 1 subtle secondary tint, 1 high-contrast text/ink color, and 1–2 functional accents (selection/active, success, warning/error). Avoid harsh pure-black boxes behind colorful shapes when a unified soft tint reads cleaner.

## 2. Game-Specific UI Craft

- **Match the fiction (diegetic & thematic cohesion):** Style each screen to fit its in-world context (e.g., workshop metal & blueprint paper, desktop OS chrome vs. web/app content, notebook/library pages) instead of generic web-app cards.
- **3-second glanceability:** Critical gameplay cues—direction arrows, rotation previews, drag targets, lock/unlock/progress badges, and active selections—must be readable at a glance:
  - Back custom-drawn arrows/icons with a dark outline or contrast halo so they stay legible over busy art or metallic surfaces.
  - Pair color changes with shape, icon, or badge differences so states never rely on color alone.
- **Clear icon-first chrome:** Prefer universally understood minimal icons (e.g., power symbol, close `×`, back arrow) with clean `tooltip_text` and `accessibility_name` over verbose button text on tight bars.
- **Intentional layout rhythm:**
  - Use a consistent spacing scale (e.g., 4 / 8 / 12 / 16 px).
  - Center reading/browsing views (libraries, web pages, notes, dialogs) inside a readable max-width column rather than pinning everything to the far left of a wide viewport.
  - Where the fiction calls for a lived-in feel (e.g., a student desktop), scatter default positions intentionally across the canvas while keeping grid snapping and viewport-clamping on resize.

## 3. Typography & Pixel-Font Discipline

- **Pick one clean primary UI font:** For pixelated games, choose a crisp, readable pixel font that is neither overly chunky/thick nor tiny/cramped. Reserve decorative or heavy display fonts strictly for logos or large titles if at all.
- **Balanced size hierarchy:**
  - Micro hints / keybind legends / metadata: `12–13 px` (avoid going below `12 px`).
  - Body text, buttons, inputs, status: `14–16 px`.
  - Section / card headings: `17–19 px`.
  - Primary titles / scores / clocks: `20–26 px`.
- **Localization headroom:** Design buttons, tabs, and fixed-width labels with ~20–25% horizontal breathing room and proper `autowrap_mode` so translated strings (e.g., Bahasa Indonesia vs. English) never clip or overflow.

## 4. Tactile Feedback, Interaction & Juice

- **Distinct control states:** Every interactive element must visibly differentiate `normal`, `hover`, `pressed`, `selected/toggled`, `focused`, and `disabled`.
- **Honest audio & visual feedback:**
  - Trigger UI click SFX **only** when clicking genuinely interactive, enabled controls—never on empty background or passive text.
  - Trim leading silence from UI SFX so clicks feel instantaneous; keep subtle pitch variation and restrained volume so repeated clicks never fatigue the player.
- **Crisp, non-blocking motion:** Keep UI transitions and hover/snap tweens snappy (`0.12–0.25 s`, cubic/quad ease-out). Kill prior tweens before starting new ones, and never let decorative animations block player input.
- **Non-blocking overlays:** Keybind legends, tooltips, and decorative badges must use `MOUSE_FILTER_IGNORE` so they never steal clicks or block drag-and-drop targets.

## 5. Pre-Ship UI Polish Checklist

Before finishing any UI task, verify:
1. **Clutter pass:** Can any border, panel box, title, or label be removed without losing clarity?
2. **Contrast & affordance:** Is it immediately obvious what is clickable/draggable vs. static?
3. **Typography:** Are font sizes consistent, sharp, and free of clipping/truncation?
4. **Responsiveness:** Test at default, narrow, and wide window sizes—centered text columns must still wrap cleanly, and corner hints/icons must never overlap primary controls.
5. **Input completeness:** Verify mouse hover/click/drag, keyboard focus traversal, and screen-exit cleanup.
