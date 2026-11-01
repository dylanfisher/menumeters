# MenuMeters

Lightweight macOS menu bar meters for CPU, memory, disk, and network: a modern, low-overhead
rewrite of [MenuMeters](https://github.com/yujitach/menumeters).

Runs on macOS 12 or later, on Apple silicon and Intel Macs. What it shows and how it differs from
yujitach's fork: [docs/spec.md](docs/spec.md).

## Install

Download `MenuMeters.app` from GitHub Releases and move it to Applications. The app is not
notarized yet, so clear the quarantine flag before the first launch:

```sh
xattr -dr com.apple.quarantine /Applications/MenuMeters.app
```

Settings live in `~/.config/menumeters/config.json`, which the settings window edits and any text
editor can too. Files the app writes for itself go in `~/Library/Application Support/MenuMeters/`.

## Develop

Building needs the Xcode version in `.xcode-version` (Swift 6.2 or later). The Command Line Tools
alone can't build the universal binary or run Swift Testing.

| Task | Command |
|---|---|
| Set up a clone, install the commit hook | `./scripts/setup` |
| Build and launch the app | `./scripts/dev` |
| Run tests | `./scripts/test` |
| Fix formatting | `./scripts/format` |
| Full gate: format, build, tier rules, tests | `./scripts/check` |
| Build the universal release `.app` | `./scripts/bundle -c release -a universal` |

`scripts/bundle` signs ad hoc unless `SIGN_ID` names a signing identity in your keychain.

Where code goes: [docs/map.md](docs/map.md). How to write comments and commits:
[docs/writing.md](docs/writing.md). Why the stack is what it is:
[docs/decisions/](docs/decisions/).

## License

GPL-2.0. See [LICENSE](LICENSE).
