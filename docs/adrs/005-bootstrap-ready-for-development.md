# ADR-005: Bootstrap Leaves the Machine Ready for Development

**Status:** Accepted
**Date:** 2026-10-24

## Context

After ADR-004, a fresh Mac had packages, dotfiles and tools, but still needed manual steps before real work: create an SSH key, add it to GitHub, and clone each repo. `install.sh` had a 90-line interactive SSH key script; the port initially dropped it.

## Decision

The bootstrap task ends by authenticating with GitHub and cloning the user's repos into `~/dev` as managed projects.

### GitHub identity

| State | Action |
|-------|--------|
| Not logged in to gh | `gh auth login --git-protocol ssh --web`: generates `~/.ssh/id_ed25519`, uploads it, configures git for SSH |
| Logged in, no key | `ssh-keygen`, then `gh ssh-key add` |
| Logged in, key present | Nothing |

### Commit signing

Every commit and tag is signed with the same SSH key (`gpg.format = ssh` in `.gitconfig`). Per machine, bootstrap:

- registers the key on GitHub as a *signing* key (separate from authentication; needs the `admin:ssh_signing_key` scope, requested at login or added with `gh auth refresh`), so GitHub shows commits as Verified
- writes `~/.config/git/allowed_signers` from all of the account's signing keys, so `git log --show-signature` verifies commits from every machine
- on macOS, stores the passphrase in the Keychain and loads the key into the agent. `ssh-keygen` signs via the agent and ignores `UseKeychain`; `.zshrc` reloads the key after a reboot so non-interactive tools (editors, coding agents, sandboxed shells) can sign

`StrictHostKeyChecking accept-new` for github.com means the first clone doesn't stop to confirm GitHub's host key; a changed key is still rejected.

### Repositories

`gh repo list --source --no-archived` at bootstrap time, so there's no list to maintain. Each repo goes through `cloneproject`, the same command used by hand, so cloned repos are ordinary projects: trusted, and visible to `lsprojects`, `workon` and `updateproject`.

- Skips the dotfiles repo and anything already in `~/dev`; re-runs clone only new repos
- Each clone runs in its own process; failures are listed at the end and don't stop the bootstrap
- Forks and archived repos are excluded; `cloneproject` fetches one on demand

### cloneproject clones first

`cloneproject` used to create an empty base project and pull into it, guessing `main` or `master` with git's errors hidden. On the first fresh-machine run every repo failed with no visible cause, each failure left an empty project that later runs skipped, and repos with other default branches couldn't be cloned.

It now runs `git clone`, and only on success adds `.mise.toml` (if the repo has none) and trusts it. Cloned repos no longer get the base template's generated README, CLAUDE.md and AGENTS.md.

## Rejected alternatives

- **mise `[bootstrap.repos]`** clones but doesn't create projects; repos wouldn't be trusted or recognized by the project commands.
- **A checked-in repo list** must be kept in sync with GitHub by hand.
- **Printing "run `gh auth login`" as a next step**: a developer machine should be ready to push without follow-up.

## Consequences

**Positive:**
- A fresh Mac reaches a full `~/dev` with one command, a browser sign-in and a passphrase
- New GitHub repos arrive on the next `mise bootstrap`

**Negative:**
- Bootstrap is interactive at the end (browser sign-in, key passphrase)
- Every owned repo is cloned, including ones not needed on this machine
- Requires gh's `admin:public_key` scope, which `gh auth login` requests
