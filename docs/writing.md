# Writing: comments, docs, commits

Agents copy the prose around them as faithfully as the code. A comment that reads like a riddle
gets imitated by the next file, and a few hundred edits later the whole codebase sounds that way.
Settle the voice early and write it down here, so there is one thing to match.

These are the defaults. Change them here to fit the project; don't add a second style guide next
to this one.

## Voice

Applies to code comments, docstrings, READMEs, `docs/`, and commit bodies.

- **Plain and direct.** Write for a competent teammate new to this code, reading quickly. Short
  sentences, present tense, active voice.
- **Literal, not literary.** No metaphors, aphorisms, or dramatic framing. "Retries three times
  because the server drops ~1% of requests," not "the gatekeeper stands guard against chaos."
- **No history in the code.** "Added for the crash fix," "now uses X instead of Y," "as discussed"
  belong in the commit message, where they are dated and attached to the diff.
- **Words to avoid:** robust, seamless, leverage, ensure that, it's worth noting, load-bearing,
  crucially, elegantly, simply, blazing fast, powerful. Say the specific thing; for speed, the
  measured number.
- **Spelling:** US English.

## Code comments and docstrings

- **Comments say why, not what.** A constraint, an invariant, a workaround and what it works
  around, a consequence that isn't visible from the line itself. If the code already says it,
  delete the comment.
- **Every type gets a `///` docstring** saying what it is for. A member gets one when it is
  `public` or when a reader would otherwise get it wrong: units, what nil means, which thread or
  actor it must run on, what it costs.
- **Docstrings describe the contract**, not the implementation: "Per-core load since the
  previous sample, 0...1; zero on the first call," not "Loops over the cores and…".
- **Use `//` inside a body**, on the line above the code it explains.
- **Cite a decision record by path** when one explains the choice:
  `// See docs/decisions/0003-config-in-dotfiles.md.`
- **No TODO or FIXME comments.** Do the work, or say what is missing in the commit or an issue.
- **`// MARK:`** only in a file with several distinct sections.

```swift
/// Where the app keeps its files. Tests pass their own folder, so they never touch the real
/// config.
public struct AppPaths: Sendable { ... }

// The controller owns the window; left at true, AppKit would also release it on close.
window.isReleasedWhenClosed = false
```

## Commits

Format: [Conventional Commits](https://www.conventionalcommits.org/).

```text
<type>(<scope>): <summary>

<body>

<footer>
```

| Type | For |
|---|---|
| `feat` | New behavior a user or caller can see |
| `fix` | A bug fix |
| `refactor` | Behavior unchanged, structure changed |
| `perf` | Faster or smaller, behavior unchanged |
| `test` | Tests only |
| `docs` | Documentation only |
| `build` | `Package.swift`, scripts, tool configs |
| `chore` | Anything else that doesn't touch shipped code |

- **Summary:** imperative mood ("add", not "added"), lowercase after the colon, no trailing period,
  72 characters max for the whole title line. It completes the sentence "This commit will…".
- **Scope:** optional. When used, it's a tier from [map.md](map.md) (`base`, `meters`, `interface`,
  `app`), or `docs` or `scripts`. Not a filename. Omit it for a change that spans tiers.
- **Body:** required unless the title says everything. Explain why the change was made, what
  alternatives were rejected, and anything a reviewer should look at closely. Don't list the files
  changed; the diff does that. Wrap at 72. A `perf` commit states before and after numbers and how
  they were measured.
- **Footer:** `BREAKING CHANGE: <what breaks>` or `Refs #123`.
- **One logical change per commit.** Formatting, renames, and tier promotions go in their own
  commit, separate from the work that prompted them.

```text
perf(meters): read network counters from NET_RT_IFLIST2

The 64-bit counters remove the wraparound handling that the 32-bit
NET_RT_IFLIST needed, and one buffer is reused across ticks. A tick
drops from 41 µs to 18 µs on the 2015 MacBook Pro, measured over
1,000 ticks in Instruments.
```

`scripts/commit-msg` checks the title format; `./scripts/setup` installs it as a git hook.
