# LookGrade design system

This guide describes the current SwiftUI implementation. The earlier Aura design specification is not the color source for this snapshot.

## Visual language

The app uses a calm dark green background, slightly lifted surfaces, warm cream text, and mint/sky accents. Coral highlights the main scan action. Category colors make reports and progress views easy to cross-reference.

| Token | Current dark value | Source |
| --- | --- | --- |
| Primary background | `#101817` | `AppColors.bgPrimary` |
| Surface | `#182321` | `AppColors.bgSurface` |
| Elevated surface | `#202D2A` | `AppColors.bgSurfaceElevated` |
| Primary text | `#F6F0E3` | `AppColors.textPrimary` |
| Secondary text | `#A9B7B3` | `AppColors.textSecondary` |
| Primary accent | `#72C89F` | `AppColors.accentPrimary` |
| Gradient endpoint | `#6EB7ED` | `AppColors.accentGradEnd` |

The authoritative tokens are in [AppColors.swift](FaceRate/DesignSystem/AppColors.swift). Main product screens also use the shared `JoyColors` palette; inspect the implementation when extending a component rather than duplicating hex values.

## Typography and components

[AppTypography](FaceRate/DesignSystem/AppTypography.swift) defines named text roles and uses system fonts with UIFontMetrics scaling. Rounded numerals support scores and compact counters; standard system text supports paragraphs. Radius/surface tokens and shared components keep reports, buttons, bars, rings, empty states, and navigation consistent.

The app requests a dark appearance at composition. Dynamic Type support exists in typography helpers, but that does not prove every large-text layout is verified. Check long translations, accessibility sizes, safe areas, and iPad width when changing a screen.

## Miro

[MiroMascotView](FaceRate/Shared/MiroMascotView.swift) integrates the bundled Rive character with onboarding and product guidance. The production `.riv` resource is included; working backups and exported animation previews are excluded from the canonical source tree.

## Localization

English, Turkish, Spanish, Brazilian Portuguese, French, German, Russian, Arabic, Hindi, Simplified Chinese, and Japanese resources are shipped. `L10n` supplies locale-sensitive text and Arabic right-to-left layout. Translations are part of the app, not text painted over screenshots.

## Screens and evidence

Home emphasizes the latest result and next action; Report exposes categories and findings; Tips ranks suggestions; Progress compares local scans. Score animation and chart history illustrate product state without establishing clinical or objective appearance validity.

See [SCREENSHOTS.md](docs/SCREENSHOTS.md) for the supplied captures' dates, seed data, and presentation-only adjustments.
