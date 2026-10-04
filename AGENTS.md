# Notes for coding agents

## Project
Chronoception is a personal, Lyubishchev-style time log. Using it is three steps: write
(or say) what you are about to do, start, end. Everything else happens quietly.

Product requirements (Chinese): `docs/requirements.md`.

## Targets
- `Chronoception` — iOS app, deployment target iOS 26.0. Dev device: iPhone 13 Pro
  (no Apple Intelligence, so on-device Foundation Models are not available). It keeps
  the log.
- `ChronoceptionWatch` — watchOS app, deployment target watchOS 26.0. Dev device:
  Apple Watch SE (2nd generation), whose last supported OS is watchOS 26. Never raise
  this deployment target; guard any watchOS 27 API with `#available`. Deliberately
  minimal: speak, start, end.
- `ChronoceptionKit` (`Packages/ChronoceptionKit`) — shared, UI-free Swift package.
  Put models and logic here so it can be tested with `swift test`.

## Rules
- The Xcode project is generated. Never edit `Chronoception.xcodeproj`; change
  `project.yml` and run `xcodegen generate`. Run it after adding or removing files too.
- Never commit secrets. `Config/Local.xcconfig` is git-ignored; API keys must never
  appear in any tracked file.
- Data lives in SwiftData (`ChronoceptionKit/Models`, `ChronoceptionKit/Store`). Read
  and write the log through `TimeLog`; it enforces the invariants and saves after each
  change. Views may read with `@Query`.
- The user keeps real data on the device. Never change stored properties in
  `SchemaV1`: add `SchemaV2` plus a stage in `ChronoceptionMigrationPlan`, and test the
  migration. Computed properties are fine.
- No categories: the user rejected them. `ActivityCategory` stays in the schema only to
  avoid a migration. An entry's title is stored in `note`; read it with `title`.
- Times: a running entry keeps its exact start (so its timer starts at zero); finished
  entries are whole minutes and last at least one (`TimeLog.minimumDuration`). Ending
  never deletes an entry. Show times 24-hour with `TimeText`, durations with
  `DurationFormat`.

## Tidying titles (MiniMax)
- An event starts at once with the words as typed; the words are also kept as its
  `VoiceNote`. `TitleTidier` then asks MiniMax, in the background and without any UI,
  for a short title and an earlier start if the words gave one ("九点就开始了").
- Tidying never overrides the user: a title or start changed by hand is left alone.
  Failures (no key, offline) are kept on the note and retried on launch, network
  return and foreground.
- Kit: `TidyPrompt`, `TidyResult`, `EventTidier`, `MiniMaxClient` (OpenAI-compatible
  chat completions; `.china` is api.minimax.cn, `.international` api.minimax.io).
- The API key is the user's and lives only in the Keychain (`APIKeyStore`). Never put
  a real key in code, tests or logs; tests use fake transports.
- Try tidying without a key: launch a Debug build with `-fakeParser`.

## Watch sync
- No iCloud (free provisioning), so WatchConnectivity. The phone is the source of
  truth. The watch sends `WatchCommand`s (start/stop with the event's id) and shows the
  `WatchSnapshot` the phone publishes as application context.
- Commands may arrive late or twice: `TimeLog.apply(_: WatchCommand)` ignores
  duplicates, files a late start as ending when the next entry began, and ignores
  stops for entries already ended.
- The watch sends with `sendMessage` when reachable and nothing is queued, otherwise
  `transferUserInfo`, so commands stay in order. It ignores snapshots older than its
  own last change.
- `WatchLink` (phone) is created at launch, since a watch message can wake the app in
  the background. Publish after anything changes what is running.

## UI
- Chinese only. Colors come from `Theme` (Claude's palette: ivory paper, warm ink,
  clay accent, with dark-mode values); don't use system colors. Inside a `Button`,
  use `Theme` colors rather than `.primary`/`.secondary`, which pick up the tint.
- Lists and forms use `.paperBackground()` and `.paperRows()`.
- Present entry sheets through `EntrySheet` (fresh id). Never fetch inside `body`,
  and don't keep a model a view may delete in state; copy what you show instead.

## Commands
- Generate project: `xcodegen generate`
- Unit tests (fast, runs on the Mac): `swift test --package-path Packages/ChronoceptionKit`
- Compile check without signing:
  `xcodebuild -project Chronoception.xcodeproj -scheme Chronoception -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build | xcbeautify`
- App icon (hourglass; light, dark and tinted, plus the watch and the README copy):
  edit and run `swift scripts/render-app-icon.swift`; don't edit the PNGs by hand.
- Sample data: launch a Debug build with `-demo` for a believable day held in memory;
  the real log is untouched.
- README: `README.md` (English) and `README.zh-CN.md` (Chinese) say the same thing,
  so change both. Screenshots in `docs/images` come from `-demo`, taken with
  `xcrun simctl io <udid> screenshot` (iPhone ones halved with `sips -Z 1311`). Open the
  saved file to check it: the simulator tool's own screenshots can lag behind.
- Simulator text input: its keyboard is Chinese Pinyin and typed ASCII turns into
  pinyin, so put text on the pasteboard and paste it:
  `LANG=en_US.UTF-8 xcrun simctl pbcopy <udid>` (UTF-8 locale needed for Chinese).
  The watch simulator's text input takes no typing at all.
- Watch app on a simulator that matches the real watch (SE 2, watchOS 26.5; the
  default watchOS 27 simulators accept APIs the device does not have):
  `xcodebuild -project Chronoception.xcodeproj -scheme ChronoceptionWatch -destination 'platform=watchOS Simulator,OS=26.5,name=Apple Watch SE 2 44mm' build | xcbeautify`
- Sync test: pair that watch with an iPhone simulator (`xcrun simctl pair`, then
  `xcrun simctl pair_activate`), install each app, start on one side, end on the other.
