#!/usr/bin/env zsh
# enclave.zsh — this Mac's GitHub keys, made in the Secure Enclave (ADR-015)
#
#   role  enclave label     handle                  on GitHub
#   auth  ssh-auth-<date>   ~/.ssh/id_enclave_auth  "<host> enclave"          signs you in
#   sign  ssh-sign-<date>   ~/.ssh/id_enclave_sign  "<host> enclave signing"  verifies commits
#
# The private keys never leave the chip. A handle only tells ssh which key
# to ask the enclave for; it's useless on any other Mac. Bootstrap sources
# this file, calls enclave_key for each role, then retire_file_key.

zmodload zsh/datetime

enclave_provider=/usr/lib/ssh-keychain.dylib
# sc_auth gives each key a certificate for a year: replace keys a month early.
enclave_renew_days=335
# When this run last made a key: two made in the same second get no certificate.
enclave_made_at=0

# This Mac's keys for a role, newest first, one "<hash> <label> <YES|NO>"
# per line; YES while the enclave counts the key valid.
enclave_identities() {   # enclave_identities <role>
    local line
    local -a f
    for line in ${(f)"$(sc_auth list-ctk-identities 2>/dev/null)"}; do
        f=(${=line})
        [[ ${f[4]:-} == ssh-$1-<1900-2999>-<1-12>-<1-31> ]] && print -r -- "$f[2] $f[4] $f[-1]"
    done | sort -r -k2,2
}

enclave_age() {   # enclave_age <label>: days since the date in it
    local made
    strftime -r -s made %Y-%m-%d "${1#ssh-*-}"
    print $(( (EPOCHSECONDS - made) / 86400 ))
}

# The handle of an enclave key, at <handle>, with <handle>.pub naming the
# key it belongs to. ssh-keygen -K exports every key's handle at once.
enclave_export() {   # enclave_export <label> <handle>
    local tmp exported
    tmp=$(mktemp -d "${TMPDIR:-/tmp}/enclave.XXXXXX") || return 1
    exported=$tmp/id_ecdsa_sk_rk_$1
    print -r -- "Exporting the handle of $1 (if ssh-keygen asks for a PIN, press Enter)"
    ( cd "$tmp" && ssh-keygen -w "$enclave_provider" -K -N "" >/dev/null ) &&
        [[ -f $exported ]] &&
        mv -f -- "$exported" "$2" && chmod 600 "$2" &&
        print -r -- "$(cut -d' ' -f1,2 "$exported.pub") $1" > "$2.pub"
    local made=$?
    rm -rf -- "$tmp"
    (( made == 0 )) || print -r -- "Couldn't export the handle of $1" >&2
    return made
}

# GitHub accepts this handle's key, and only it. No config (-F /dev/null):
# its IdentityFile lines would let another key answer. ssh -T always exits 1
# at GitHub; what it says is the answer.
enclave_signs_in() {   # enclave_signs_in <handle>
    local said
    said=$(ssh -F /dev/null -o IdentitiesOnly=yes -o IdentityFile="$1" \
        -o SecurityKeyProvider="$enclave_provider" -T git@github.com 2>&1) || true
    [[ $said == *"successfully authenticated"* ]]
}

# Make sure this Mac has a current enclave key for <role>, in the agent and
# registered on GitHub for its job. A key 11 months old, or one the enclave
# no longer counts valid, is replaced: the new key's handle is exported
# beside the one in use, registered, proven (an auth key signs in), and only
# then swapped in. The old key then leaves the enclave, and an old auth key
# leaves GitHub; an old signing key stays there, so its commits stay Verified.
enclave_key() {   # enclave_key <role: auth|sign>
    local role=$1 handle=$HOME/.ssh/id_enclave_$1
    if previewing; then
        print -r -- "would make sure this Mac has a current $role key in the Secure Enclave"
        return 0
    fi
    local hash label valid current= in_use= key keys agent id k title
    local -a stale=()

    while read -r hash label valid; do
        [[ -n $hash ]] || continue
        if [[ -z $current && $valid == YES ]] && (( $(enclave_age "$label") < enclave_renew_days )); then
            current=$label
        else
            stale+=("$hash")
        fi
    done <<< "$(enclave_identities "$role")"

    if [[ -z $current ]]; then
        current=ssh-$role-$(strftime %Y-%m-%d $EPOCHSECONDS)
        (( EPOCHSECONDS - enclave_made_at < 2 )) && sleep 2
        sc_auth create-ctk-identity -l "$current" -k p-256-ne -t none
        enclave_made_at=$EPOCHSECONDS
        # sc_auth can print an error and exit 0: the listing decides.
        if [[ "$(enclave_identities "$role")" != *" $current "* ]]; then
            print -r -- "$current isn't in the Secure Enclave after sc_auth made it; run bootstrap again" >&2
            return 1
        fi
    fi

    # The handle in use stays until the new one has proven itself.
    local next=$handle
    if [[ "$(cut -d' ' -f3 "$handle.pub" 2>/dev/null)" != $current ]]; then
        [[ -f $handle.pub ]] && { next=$handle.next; in_use=$(cut -d' ' -f1,2 "$handle.pub"); }
        enclave_export "$current" "$next" || return 1
    fi
    key=$(cut -d' ' -f1,2 "$next.pub")

    case $role in
        auth)
            keys=$(gh api user/keys --jq '.[] | [.id, .key, .title] | @tsv') || return 1
            [[ $'\n'$keys$'\n' == *$'\t'"$key"$'\t'* ]] ||
                gh ssh-key add "$next.pub" --type authentication --title "$(hostname -s) enclave" ;;
        sign)
            keys=$(gh api user/ssh_signing_keys --jq '.[].key') || return 1
            [[ $'\n'$keys$'\n' == *$'\n'"$key"$'\n'* ]] ||
                gh ssh-key add "$next.pub" --type signing --title "$(hostname -s) enclave signing" ;;
    esac

    if [[ $role == auth ]] && [[ -n $in_use || $#stale -gt 0 ]] && ! enclave_signs_in "$next"; then
        print -r -- "The new key $current couldn't sign in to GitHub; the old one stays until it can. Run bootstrap again." >&2
        return 1
    fi
    if [[ $next != $handle ]]; then
        ssh-add -d "$handle" &>/dev/null
        mv -f -- "$next" "$handle" && mv -f -- "$next.pub" "$handle.pub" || return 1
    fi

    agent=$(ssh-add -L 2>/dev/null) || true
    [[ $agent == *"$key"* ]] || SSH_SK_PROVIDER=$enclave_provider ssh-add -q "$handle"

    if [[ $role == auth && -n $in_use ]]; then
        while IFS=$'\t' read -r id k title; do
            [[ -n $id && $k == $in_use ]] && gh ssh-key delete "$id" --yes
        done <<< "$keys"
    fi
    for hash in $stale; do sc_auth delete-ctk-identity -h "$hash"; done
}

# The file key this Mac used before (~/.ssh/id_ed25519) could be copied off
# it; once the enclave auth key signs in, ask to retire it. On yes, its
# sign-in entry leaves GitHub, its signing entry stays so the commits it
# signed stay Verified, and the files go. Asked again on every run until
# answered yes; without a terminal, never asked.
retire_file_key() {
    local file=$HOME/.ssh/id_ed25519 key keys id k title reply
    [[ -f $file.pub ]] || return 0
    if previewing; then print -r -- "would ask to retire $file"; return 0; fi
    [[ -t 0 ]] || return 0
    enclave_signs_in "$HOME/.ssh/id_enclave_auth" || return 0

    print -r -- "This Mac signs in to GitHub and signs commits with its Secure Enclave keys now."
    print -r -- "Retiring $file removes it from GitHub's sign-in keys and deletes it here; servers or"
    print -r -- "other services that accept it stop accepting it. Commits it signed stay Verified."
    read -r "reply?Retire it? [y/N] " || reply=
    if [[ $reply != [yY]* ]]; then
        print -r -- "Kept $file; bootstrap asks again next time."
        return 0
    fi

    key=$(cut -d' ' -f1,2 "$file.pub")
    keys=$(gh api user/keys --jq '.[] | [.id, .key, .title] | @tsv') || return 1
    while IFS=$'\t' read -r id k title; do
        [[ -n $id && $k == $key ]] && gh ssh-key delete "$id" --yes
    done <<< "$keys"
    ssh-add -d "$file" &>/dev/null
    rm -f -- "$file" "$file.pub"
    print -r -- "Retired $file"
}
