# focus

A simple, no-nonsense website blocker for macOS — with **lockable focus sessions you can't quit early**.

`focus` blocks sites at the OS level by editing `/etc/hosts`, so they're blocked in **every browser** at once. There's no extension to disable, no app to force-quit. When you start a *locked* session, a root background daemon re-applies the block every few seconds and survives reboots — so hand-editing your hosts file (or deleting the tool) won't get you back on Instagram until the timer runs out.

It comes in two flavors that share the same state:

- **`focus`** — a small, dependency-free Bash CLI.
- **`focus-tui`** — a full-screen terminal UI (Python + [Textual](https://textual.textualize.io/)) with a live toggle list.

Both read the same roster (`~/.focus-sites`) and edit the same managed block in `/etc/hosts`, so you can mix and match freely.

---

## Why

Browser extensions are trivial to disable the moment you feel the itch. `focus` is different:

- **Every browser, at once.** Blocking happens at the DNS/hosts layer, below the browser.
- **Commitment mode.** `focus lock 90m` starts a session with **no early unlock**. A root-owned daemon re-applies the block every 5 seconds, reverts manual edits automatically, and survives reboots. You can *extend* a lock, never shorten it.
- **Clean.** Everything lives inside a clearly-marked block in `/etc/hosts`; the rest of your file is never touched.

---

## Install

```bash
git clone https://github.com/ponchodelosrios98/screen-block.git
cd screen-block
chmod +x focus focus-tui
```

Optionally put them on your `PATH`:

```bash
sudo cp focus /usr/local/bin/focus
```

### Requirements

- **macOS** (uses `/etc/hosts` + `mDNSResponder`).
- `focus` — Bash only, no dependencies.
- `focus-tui` — [`uv`](https://github.com/astral-sh/uv) (the script declares its own deps and runs itself). Or run it with any Python ≥ 3.10 that has `textual>=0.80` installed.

Editing `/etc/hosts` requires `sudo`; you'll be prompted for your password.

---

## Usage — CLI

```bash
./focus block instagram.com twitter.com   # block one or more sites
./focus unblock instagram.com             # unblock specific sites
./focus on                                # re-block everything on your list
./focus off                               # unblock everything (break time)
./focus list                              # show what's currently blocked
./focus lock 90m                          # LOCK your list for a set time
./focus status                            # show lock state + time left
```

Your block list lives in `~/.focus-sites`, so `on`/`off` remember it between sessions.

### Lock sessions (commitment mode)

```bash
./focus lock 90m       # lock for 90 minutes — no early unlock
./focus lock 2h        # or 2 hours
./focus lock 1h30m     # combined
./focus lock 45        # a bare number means minutes
```

While a lock is active:

- `off` and `unblock` are **refused**.
- You can `block` more sites (they get folded into the enforced set), but never remove them.
- `focus lock <longer>` **extends** the session; a shorter or equal duration is rejected.
- When the timer expires, the daemon unblocks everything and removes itself.

Durations accept `s`, `m`, `h`, `d` (e.g. `90m`, `2h`, `1h30m`), or a bare number for minutes.

---

## Usage — TUI

```bash
./focus-tui
```

A live table of your sites, each individually **● blocked** or **○ allowed**. Toggling flips it in `/etc/hosts` immediately.

| Key      | Action                          |
|----------|---------------------------------|
| `space`  | toggle the selected site        |
| `a`      | add a site                      |
| `d`      | delete a site                   |
| `l`      | lock a focus session            |
| `o`      | block all                       |
| `f`      | allow all                       |
| `r`      | refresh                         |
| `q`      | quit                            |

The TUI authenticates `sudo` once up front (a normal password prompt before the UI opens), then reuses the cached credential.

---

## How it works

- **The block.** Both tools rewrite a single region of `/etc/hosts` delimited by:

  ```
  # >>> focus block >>>
  127.0.0.1 instagram.com
  127.0.0.1 www.instagram.com
  # <<< focus block <<<
  ```

  Anything outside those markers is left untouched. After each change, the DNS cache is flushed (`dscacheutil -flushcache` + `killall -HUP mDNSResponder`).

- **The lock.** `focus lock` installs a root LaunchDaemon (`com.focus.enforcer`) plus a small enforcer script and a lock file under `/Library/Application Support/focus/`. The daemon loops every 5 seconds: while the lock file's expiry epoch is in the future it re-applies the block; once it expires it unblocks everything, removes the daemon, plist and lock file, and exits. `KeepAlive` + `RunAtLoad` mean it comes back after a reboot.

Because the enforcer, plist and lock file are root-owned, the tool can't casually clear them — that's the whole point.

---

## Uninstall

Nothing is installed globally unless you copied `focus` to `/usr/local/bin` or ran a lock. To remove a stuck locked session (only possible with `sudo`, by design), wait for the timer — or, if you truly must:

```bash
sudo launchctl bootout system/com.focus.enforcer
sudo rm -f /Library/LaunchDaemons/com.focus.enforcer.plist \
           /usr/local/libexec/focus-enforcer
sudo rm -rf "/Library/Application Support/focus"
```

Then remove the managed block from `/etc/hosts` (everything between the two `focus block` markers).

---

## License

[MIT](LICENSE) — do whatever you want. Contributions welcome.
