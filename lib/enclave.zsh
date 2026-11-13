#!/usr/bin/env zsh
# enclave.zsh — this Mac's GitHub keys, made in the Secure Enclave (ADR-015)
#
#   role  enclave label     handle                  on GitHub
#   auth  ssh-auth-<date>   ~/.ssh/id_enclave_auth  "<host> enclave"          signs you in
#   sign  ssh-sign-<date>   ~/.ssh/id_enclave_sign  "<host> enclave signing"  verifies commits
#
# The private keys never leave the chip. A handle only tells ssh which key
# to ask the enclave for; it's useless on any other Mac. Bootstrap sources
# this file and calls enclave_key for each role. Every change goes through
# bootstrap's run(), so a preview prints it instead.

zmodload zsh/datetime

enclave_provider=/usr/lib/ssh-keychain.dylib
# sc_auth gives each key a certificate for a year: replace keys a month early.
enclave_renew_days=335

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
    if previewing; then print -r -- "would export the handle of $1 to $2"; return 0; fi
    local tmp exported
    tmp=$(mktemp -d "${TMPDIR:-/tmp}/enclave.XXXXXX") || return 1
    exported=$tmp/id_ecdsa_sk_rk_$1
    print -r -- "Exporting the handle of $1 (if ssh-keygen asks for a PIN, press Enter)"
    ( cd "$tmp" && ssh-keygen -w "$enclave_provider" -K -N "" >/dev/null )
    if [[ ! -f $exported ]]; then
        rm -rf -- "$tmp"
        print -r -- "ssh-keygen exported no handle for $1" >&2
        return 1
    fi
    mv -f -- "$exported" "$2" && chmod 600 "$2"
    print -r -- "$(cut -d' ' -f1,2 "$exported.pub") $1" > "$2.pub"
    rm -rf -- "$tmp"
}

# Make sure this Mac has a current enclave key for <role>: made, exported,
# registered on GitHub for its job, and in the agent. A key 11 months old,
# or one the enclave no longer counts valid, is replaced; the one it
# replaces leaves the enclave once the new one works, and an auth key's
# GitHub entry goes with it. A signing key's entry stays, so the commits
# it signed stay Verified.
enclave_key() {   # enclave_key <role: auth|sign>
    local role=$1 handle=$HOME/.ssh/id_enclave_$1 host
    local hash label valid current= key keys agent signed_in id k title
    local -a stale=()
    host=$(hostname -s)

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
        run sc_auth create-ctk-identity -l "$current" -k p-256-ne -t none
        previewing && return 0
        # sc_auth can print an error and exit 0: the listing decides.
        if [[ $'\n'"$(enclave_identities "$role")" != *" $current "* ]]; then
            print -r -- "$current isn't in the Secure Enclave after sc_auth made it; run bootstrap again" >&2
            return 1
        fi
        # Two keys made in the same second get no certificate.
        sleep 2
    fi

    if [[ ! -f $handle || "$(cut -d' ' -f3 "$handle.pub" 2>/dev/null)" != $current ]]; then
        enclave_export "$current" "$handle" || return 1
    fi
    previewing && [[ ! -f $handle.pub ]] && return 0
    key=$(cut -d' ' -f1,2 "$handle.pub")

    case $role in
        auth)
            keys=$(gh api user/keys --jq '.[] | [.id, .key, .title] | @tsv') || return 1
            [[ $'\n'$keys$'\n' == *$'\t'"$key"$'\t'* ]] ||
                run gh ssh-key add "$handle.pub" --type authentication --title "$host enclave" ;;
        sign)
            keys=$(gh api user/ssh_signing_keys --jq '.[].key') || return 1
            [[ $'\n'$keys$'\n' == *$'\n'"$key"$'\n'* ]] ||
                run gh ssh-key add "$handle.pub" --type signing --title "$host enclave signing" ;;
    esac

    agent=$(ssh-add -L 2>/dev/null) || true
    [[ $agent == *"$key"* ]] || run env SSH_SK_PROVIDER="$enclave_provider" ssh-add -q "$handle"

    (( $#stale )) || return 0
    if [[ $role == auth ]]; then
        # ssh -T always exits 1 at GitHub; what it says is the answer.
        signed_in=$(ssh -o IdentitiesOnly=yes -o IdentityFile="$handle" -o SecurityKeyProvider="$enclave_provider" \
            -T git@github.com 2>&1) || true
        if [[ $signed_in != *"successfully authenticated"* ]]; then
            print -r -- "The new key $current couldn't sign in to GitHub; the old one stays until it can. Run bootstrap again." >&2
            return 1
        fi
        while IFS=$'\t' read -r id k title; do
            [[ -n $id && $title == "$host enclave" && $k != $key ]] && run gh ssh-key delete "$id" --yes
        done <<< "$keys"
    fi
    for hash in $stale; do run sc_auth delete-ctk-identity -h "$hash"; done
}
