# 0003. A strict JSON config file, rewritten whole, with sections that may be left out

- **Date:** 2026-11-01
- **Status:** accepted

## Context

Settings live in `~/.config/menumeters/config.json` so they can be versioned and copied with
other dotfiles, and the settings window edits the same file. The plan's lean scope for it: one
section per meter with an on/off switch, read and written off the main thread, a file that
doesn't parse logged and left alone with the app on defaults until it is fixed, and hand edits
applied while the app runs. The owner's house style (`~/projects/app-conventions`, persistence)
goes further: comments and trailing commas allowed, the settings window patching one value in
place to keep the user's comments, and the last good settings kept while the file has an error.
simple-spotlight implements that in about 1,700 lines.

## Decision

The file is strict JSON, written whole by the settings window (sorted keys, two-space indent). A
key or a whole section left out keeps its default; an unknown key, a value of the wrong kind or
out of range, and `showsPercent` and `showsGraph` both false are errors naming the key, such as
`cpu.intervalSeconds`. A file with any error sets nothing: the app runs on the defaults, saves
are refused, and the settings window locks its controls and shows the error. A missing file is
replaced by the default file, at launch and while running, so deleting it resets the settings.

`ConfigStore` is an actor publishing states through an `AsyncStream`, as the house style says,
and watches the file's folder with simple-spotlight's FSEvents `FolderWatcher`, batching changes
for 0.3 s so an editor's save in place has finished before the file is read. A symbolic link at
the file's path is kept: the write replaces its target, and the target's folder is watched too.

## Alternatives considered

- **Comments and patching in place, as simple-spotlight:** the larger part of its config code,
  for a file with a handful of keys per meter. Left for later; the file format is strict JSON
  now, so allowing comments later breaks no file.
- **Every key required:** each new meter section, and each new setting, would turn the owner's
  existing file into an error during the build-out.
- **Keeping the last good settings while the file has an error:** the plan settled on the
  defaults, which is also what the app would start with if launched with the broken file.
- **`UserDefaults`:** not a file the user can version or edit.

## Consequences

- Rewriting the whole file drops anything the user added that isn't a known key, but such a
  file is an error and is never rewritten.
- A setting with a new name in a later phase needs no migration: the old file reads, with the
  new key at its default.
- Adding comments later means replacing the whole-file write with a patch of the changed values.
