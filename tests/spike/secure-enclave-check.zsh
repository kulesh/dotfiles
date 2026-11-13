#!/usr/bin/env zsh
# secure-enclave-check.zsh — can this Mac sign git commits with Secure
# Enclave SSH keys, through ssh-agent, inside the workon -s sandbox?
#
# A spike for ADR-015, run by hand on a Mac (macOS 26 or later):
#   zsh ~/.dotfiles/tests/spike/secure-enclave-check.zsh
# It makes two throwaway enclave keys without Touch ID (labels
# dotfiles-check-a and -b), exports their handles, loads one into the agent,
# signs a commit outside and inside the sandbox, and verifies both. At the
# end it removes what it made: the two identities, the agent entry and its
# own temporary directory. Nothing else is touched. If ssh-keygen asks for
# a PIN, press Enter. Paste the whole output back.

setopt no_err_exit pipe_fail extended_glob
provider=/usr/lib/ssh-keychain.dylib
labels=(dotfiles-check-a dotfiles-check-b)
work=$(mktemp -d "${TMPDIR:-/tmp}/se-check.XXXXXX") || exit 1
handle=

step() { print -P "\n%B== $*%b"; }
ok()   { print -P "%F{green}OK%f   $*"; }
bad()  { print -P "%F{red}FAIL%f $*"; }

cleanup() {
    step "Cleanup"
    [[ -n $handle && -f $handle ]] && SSH_SK_PROVIDER=$provider ssh-add -d "$handle" 2>&1
    local label hash
    for label in $labels; do
        for hash in $(sc_auth list-ctk-identities 2>/dev/null | awk -v l="$label" '$4 == l { print $2 }'); do
            sc_auth delete-ctk-identity -h "$hash" && ok "deleted identity $label ($hash)" || bad "could not delete $label ($hash)"
        done
    done
    rm -rf -- "$work"
    sc_auth list-ctk-identities 2>&1 | grep -q dotfiles-check && bad "a dotfiles-check identity is left" || ok "no dotfiles-check identity left"
}
trap cleanup EXIT

step "This Mac"
sw_vers
ssh -V 2>&1
[[ -e $provider ]] && ok "$provider exists" || bad "$provider is missing"
print -r -- "SSH_AUTH_SOCK=${SSH_AUTH_SOCK:-unset}"
print -r -- "Existing CTK identities:"
sc_auth list-ctk-identities 2>&1

step "sc_auth usage for create-ctk-identity"
sc_auth help 2>&1 | grep -iA12 'create-ctk-identity' | head -30

step "Create two enclave keys, no Touch ID (-t none)"
# sc_auth can print an error and still exit 0, so a key exists only once
# the listing shows it.
exists() { sc_auth list-ctk-identities 2>/dev/null | awk -v l="$1" '$4 == l { f = 1 } END { exit !f }'; }
create() {   # create <label> [sc_auth options...]
    sc_auth create-ctk-identity -l "$1" -k p-256-ne -t none "${@:2}" 2>&1
    if exists "$1"; then ok "created $1 ${*:2}"; else bad "no identity $1 after: create ${*:2}"; fi
}
create dotfiles-check-a
# The second key failed once with "Failed to create certificate", made in
# the same second as the first: try after a pause, then with its own
# common name, then with an email too.
sleep 2
create dotfiles-check-b
exists dotfiles-check-b || { sleep 2; create dotfiles-check-b -N dotfiles-check-b; }
exists dotfiles-check-b || { sleep 2; create dotfiles-check-b -N dotfiles-check-b -E check-b@example.com; }
sc_auth list-ctk-identities 2>&1

step "What the manual says about validity and expiry"
man sc_auth 2>/dev/null | col -b | grep -inE -B1 -A3 'valid|expir|year|days' | head -40

step "Export the key handles (press Enter at a PIN prompt)"
( cd "$work" && ssh-keygen -w "$provider" -K -N "" 2>&1 )
print -r -- "Files written:"
ls -l "$work"
for pub in $work/*.pub(N); do print -r -- "--- ${pub:t}"; cat "$pub"; done
handles=($work/id_*~*.pub(N.))
print -r -- "${#handles} handle(s): ${handles:t}"
handle=${handles[1]:-}
[[ -n $handle ]] && ok "handle: ${handle:t}" || { bad "no handle exported"; exit 1; }
pub=$handle.pub

step "Load the handle into ssh-agent"
SSH_SK_PROVIDER=$provider ssh-add "$handle" 2>&1 && ok "ssh-add" || bad "ssh-add"
ssh-add -L 2>&1 | grep -F "$(cut -d' ' -f2 "$pub")" >/dev/null && ok "the agent lists the enclave key" || bad "the agent doesn't list the enclave key"

print -r -- "check@example.com $(cut -d' ' -f1,2 "$pub")" > "$work/allowed_signers"
sign_commit() {   # sign_commit <repo> [command prefix...]: an empty commit, signed with the enclave key
    local repo=$1; shift
    "$@" git -C "$repo" -c user.name=check -c user.email=check@example.com \
        -c gpg.format=ssh -c user.signingkey="$pub" -c commit.gpgsign=true \
        commit -q --allow-empty -m check 2>&1
}
verify() {   # verify <repo>
    git -C "$1" -c gpg.ssh.allowedSignersFile="$work/allowed_signers" verify-commit HEAD 2>&1
}

step "Sign a commit through the agent"
git init -q "$work/outside"
sign_commit "$work/outside" && ok "signed" || bad "signing"
verify "$work/outside" && ok "verified" || bad "verification"

step "Sign a commit inside the workon -s sandbox"
profile=${XDG_CONFIG_HOME:-$HOME/.config}/sandbox/profiles/default.sb
grep -q '(param "PROJECT")' "$profile" && ok "profile takes PROJECT (dsync is current)" || bad "profile is older than ad63c6a; run dsync first"
git init -q "$work/inside"
sign_commit "$work/inside" sandbox-exec -f "$profile" -D "HOME=$HOME" -D "PROJECT=$work/inside" -D "SSH_REAL=${${:-$HOME/.ssh}:A}" \
    && ok "signed in the sandbox" || bad "signing in the sandbox"
verify "$work/inside" && ok "verified" || bad "verification"

step "Sign without the agent, with the handle and the provider directly"
git init -q "$work/direct"
SSH_SK_PROVIDER=$provider SSH_AUTH_SOCK= git -C "$work/direct" -c user.name=check -c user.email=check@example.com \
    -c gpg.format=ssh -c user.signingkey="$handle" -c commit.gpgsign=true commit -q --allow-empty -m check 2>&1 \
    && ok "signed without the agent" || bad "signing without the agent"
