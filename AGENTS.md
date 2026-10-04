# Notes for coding agents

## Project
Chronoception is a personal, Lyubishchev-style time log. The Apple Watch captures
short voice notes; the iPhone does the heavier processing.

## Targets
- `Chronoception` — iOS app, deployment target iOS 26.0. Dev device: iPhone 13 Pro
  (no Apple Intelligence, so on-device Foundation Models are not available).
- `ChronoceptionWatch` — watchOS app, deployment target watchOS 26.0. Dev device:
  Apple Watch SE (2nd generation), whose last supported OS is watchOS 26. Never raise
  this deployment target; guard any watchOS 27 API with `#available`.
- `ChronoceptionKit` (`Packages/ChronoceptionKit`) — shared, UI-free Swift package.
  Put models and parsing logic here so it can be tested with `swift test`.

## Rules
- The Xcode project is generated. Never edit `Chronoception.xcodeproj`; change
  `project.yml` and run `xcodegen generate`. Run it after adding or removing files too.
- Never commit secrets. `Config/Local.xcconfig` is git-ignored; API keys must never
  appear in any tracked file.

## Commands
- Generate project: `xcodegen generate`
- Unit tests (fast, runs on the Mac): `swift test --package-path Packages/ChronoceptionKit`
- Compile check without signing:
  `xcodebuild -project Chronoception.xcodeproj -scheme Chronoception -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build | xcbeautify`
