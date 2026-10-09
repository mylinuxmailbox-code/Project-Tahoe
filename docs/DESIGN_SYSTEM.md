# Project Tahoe X86 — Design System

- **Purpose**: Define the visual language, design tokens, and component behavior
- **Status**: Draft

## 1. Visual Principles

- Translucent, layered surfaces inspired by Liquid Glass
- Transparent top menu bar
- Rounded window frames with consistent corner radii
- Floating sidebars and refined toolbars
- Subtle blur, vibrancy, transparency, and depth where the platform supports it
- Carefully tuned typography, spacing, and icon scale
- Smooth, interruptible animations
- Context-aware light and dark appearances
- Consistent icon grid, silhouette, and visual weight

Blur and transparency are applied selectively to preserve contrast, readability, and performance.

## 2. Theme Modes

- **Light**: bright surfaces, dark text, accent used sparingly
- **Dark**: deep surfaces, light text, accent kept readable
- **Auto**: follow system or user preference

The theme engine must define both a semantic palette and a concrete Qt/QML mapping.

## 3. Design Tokens

The following token families must be defined centrally:

- Colors and semantic colors
- Typography and font scale
- Spacing
- Window and panel radii
- Shadows
- Blur levels
- Transparency levels
- Animation durations and easing
- Icon sizes
- Menu bar dimensions
- Dock sizing and magnification
- Sidebar dimensions
- Focus indicators
- Accessibility contrast rules

All apps and components must consume the same token source.

## 4. Fluid Glass Approximation

On Linux we cannot necessarily use macOS Liquid Glass directly. The design system should approximate the *visual intent*:

- Translucent panels with enough contrast for text
- Soft separators instead of heavy borders
- Layered depth through opacity and subtle shadow
- Rounded controls that sit visually above content
- Clear hierarchy without making controls recede too far

We should degrade to simple translucent or opaque surfaces when blur/advanced rendering is unavailable.

## 5. Layout Standards

- Menu bar at the top
- Dock at the bottom by default, with position/size preferences
- Sidebars on the left in file and settings contexts
- Floating sheets/dialogs for actions
- Consistent content margins and sidebar widths

## 6. Motion Philosophy

- Fast initial response, then smooth follow-through
- Interruptible Dock and window animations
- Avoid long entrances that delay interaction
- Reduce motion when the user requests accessibility preferences

## 7. Icon Strategy

- Maintain a central icon registry with names, sizes, variants, and fallbacks
- Use macOS Tahoe-style proportions as the reference where the user supplies assets
- For missing icons, create original substitutes that preserve proportions and visual weight
- Do not randomly remix icon packs or rely on emoji as permanent system icons
- Support light/dark/tinted variants where appropriate

## 8. Component Behavior Rules

- No decorative toggle that only changes appearance
- No fake progress, fake upload, fake search, or fake AI reply
- Empty, loading, error, and confirmation states must be explicit
- Interactive controls must have accessible labels and keyboard behavior
- Text contrast must remain acceptable in both theme modes

