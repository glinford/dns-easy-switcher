# Repository Guidelines

## Project Structure & Module Organization
- `DNS Easy Switcher/`: Swift/SwiftUI source files (menu bar UI, views, and DNS logic).
- `DNS Easy Switcher/Assets.xcassets`: App icons, images, and other bundled assets.
- `DNS Easy Switcher/Preview Content/`: SwiftUI preview assets.
- `DNS Easy Switcher.xcodeproj`: Xcode project file.
- `Releases/`: Packaged release artifacts (if present).
- Root images `screenshot.png` and `settings.png` are used in the README.

## Build, Test, and Development Commands
- Open `DNS Easy Switcher.xcodeproj` in Xcode 15+ and press Run to build and launch.
- Optional CLI build (adjust scheme if needed):
  ```bash
  xcodebuild -project "DNS Easy Switcher.xcodeproj" -scheme "DNS Easy Switcher" -configuration Debug
  ```
- No automated test target is currently checked in.

## Coding Style & Naming Conventions
- Follow Swift/SwiftUI conventions and Xcode’s default formatting (4-space indentation).
- Types use `PascalCase`; functions/properties use `camelCase`.
- Prefer file names to match the primary type (e.g., `MenuBarView.swift`).
- Keep UI strings and asset names consistent with existing assets in `Assets.xcassets`.

## Testing Guidelines
- There are no unit/UI tests in the repo today. If adding tests, use a new Xcode test target such as `DNS Easy SwitcherTests/` and name files `*Tests.swift`.
- Perform manual checks for menu bar behavior, DNS switching, Touch ID prompts, and settings persistence.

## Commit & Pull Request Guidelines
- Recent commits use short, direct messages (e.g., `fix persistence`, `About`) and release markers like `Signed v1.0.7`.
- Keep commit messages concise and imperative; note release versioning when applicable.
- PRs should include: a brief summary, the macOS version tested (e.g., Sonoma 14.x), and screenshots for UI changes.

## Security & Configuration Notes
- DNS changes require elevated privileges; the app uses `DNS_Easy_Switcher.entitlements` for macOS capabilities.
- Be mindful of Touch ID flows when modifying authentication or system settings behavior.
