# Chronoception

A personal, Lyubishchev-style time-awareness app: say what you are doing into your
Apple Watch, and let the iPhone turn it into a time log.

## Requirements
- Xcode 26 or later, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- iOS 26+ and watchOS 26+

## Getting started
```sh
cp Config/Local.xcconfig.example Config/Local.xcconfig  # your Team ID and bundle prefix
xcodegen generate
open Chronoception.xcodeproj
```
The Xcode project is generated from `project.yml` and is not checked in.

## Layout
| Path | What |
| --- | --- |
| `iOS/` | iPhone app |
| `Watch/` | Apple Watch app |
| `Packages/ChronoceptionKit/` | Shared models and logic (`swift test`) |
| `Config/` | Build settings; `Local.xcconfig` is yours and git-ignored |

## License
MIT
