# Lightswitch

![Lightswitch](screenshot.png)

Don't multitask: dump the thought and get back to work. Press **Super + N**,
type, press **Enter twice**, and it's gone. Flip it on, flip it off.

Notes go to `~/Notes/lightswitch.md` as a plain Markdown checklist
(`- [ ] 2026-11-22 14:03 · call the bank`), so any editor can read them.

## Why it's fast

Lightswitch stays resident with its window hidden (started on login with
`lightswitch daemon`). Super + N runs `lightswitch-toggle`, a libc-only client
that pokes the resident app over a Unix socket in about a millisecond, so the
window is a show, not a launch.

## Shortcuts

| Key | Does |
| --- | --- |
| Super + N | Show / hide |
| Enter | Next note (each line is one note) |
| Enter twice | Save everything and hide |
| Shift + Enter | Line break inside a note |
| Esc, or click away | Hide, keep the draft |
| Tab | Switch between writing and the *later* list |
| Space / Enter / X | Mark done (later list) |
| J / K, arrows | Move (later list) |
| Ctrl + Z | Undo done |
| Ctrl + O | Open the notes file |
| F1 | Shortcut overlay |

## Commands

```sh
lightswitch                 # show/hide (starts it if needed)
lightswitch later           # open on the later list
lightswitch add "call bank" # save without the window
lightswitch list [--json]   # print open notes
lightswitch path            # notes file
lightswitch quit            # stop the resident app
```

## Build

```sh
bin/build     # build/lightswitch and build/lightswitch-toggle
bin/test      # backend tests, offscreen
bin/install   # makepkg -fsi, then restarts the resident copy
```
