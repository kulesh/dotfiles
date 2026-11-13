#!/usr/bin/env bats
# Acceptance tests for lib/enclave.zsh: this Mac's GitHub keys, made in the
# Secure Enclave (ADR-015). Stand-ins keep the state a Mac would:
#   sc_auth     enclave keys in $HOME/enclave ("hash label valid created")
#   ssh-keygen  -K writes a handle per enclave key, as macOS names them
#   ssh-add     the agent's keys in $HOME/agent
#   gh          GitHub's keys in $HOME/github ("id<TAB>type<TAB>key<TAB>title")
#   ssh         signs in to GitHub with a registered auth key
# Every command any of them runs is logged in $HOME/calls.

load test_helper

setup() {
    command -v zsh >/dev/null || skip "zsh not installed"
    export HOME=$(scratch)
    mkdir -m 700 "$HOME/.ssh"
    : > "$HOME/enclave"; : > "$HOME/agent"; : > "$HOME/github"; : > "$HOME/calls"
    STUBS=$(scratch)
    export PATH=$STUBS:$PATH

    stub sc_auth <<'EOF'
case $1 in
list-ctk-identities)
    echo "Key Type Public Key Hash Prot Label Common Name Email Address Valid To Valid"
    while read -r hash label valid created; do
        echo "p-256-ne $hash none $label $label 11/12/27, 23:02 $valid"
    done < "$HOME/enclave" ;;
create-ctk-identity)
    while [ $# -gt 0 ]; do [ "$1" = -l ] && label=$2; shift; done
    now=$(date +%s)
    last=$(tail -n 1 "$HOME/enclave" | cut -d' ' -f4)
    # macOS: a second key in the same second gets no certificate, and
    # sc_auth exits 0 all the same.
    if [ -n "$SC_AUTH_BROKEN" ] || [ "$last" = "$now" ]; then echo "Error: Failed to create certificate" >&2; exit 0; fi
    echo "$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n' | tr a-f A-F) $label YES $now" >> "$HOME/enclave" ;;
delete-ctk-identity)
    grep -v "^$3 " "$HOME/enclave" > "$HOME/enclave.new"; mv "$HOME/enclave.new" "$HOME/enclave" ;;
esac
EOF

    stub ssh-keygen <<'EOF'
# -K: a handle and its public key for every enclave key, in this directory.
case " $* " in *" -K "*)
    while read -r hash label valid created; do
        echo "handle for $hash" > "id_ecdsa_sk_rk_$label"
        echo "sk-ecdsa-sha2-nistp256@openssh.com AAAA$hash ssh:" > "id_ecdsa_sk_rk_$label.pub"
    done < "$HOME/enclave" ;;
esac
EOF

    stub ssh-add <<'EOF'
case $1 in
-L) [ -s "$HOME/agent" ] || { echo "The agent has no identities." ; exit 1; }; cat "$HOME/agent" ;;
-d) key=$(cut -d' ' -f1,2 "$2.pub"); grep -vxF "$key" "$HOME/agent" > "$HOME/agent.new"; mv "$HOME/agent.new" "$HOME/agent" ;;
*)  for f; do [ -f "$f.pub" ] && cut -d' ' -f1,2 "$f.pub" >> "$HOME/agent"; done ;;
esac
EOF

    stub gh <<'EOF'
case "$1 $2" in
"auth status") exit 0 ;;
"api user/keys")
    awk -F'\t' '$2 == "authentication" { print $1 "\t" $3 "\t" $4 }' "$HOME/github" ;;
"api user/ssh_signing_keys")
    awk -F'\t' '$2 == "signing" { print $3 }' "$HOME/github" ;;
"ssh-key add")
    file=$3; shift 3
    while [ $# -gt 0 ]; do case $1 in --type) type=$2 ;; --title) title=$2 ;; esac; shift; done
    printf '%s\t%s\t%s\t%s\n' "$(( $(wc -l < "$HOME/github") + 1 ))" "${type:-authentication}" "$(cut -d' ' -f1,2 "$file")" "$title" >> "$HOME/github" ;;
"ssh-key delete")
    awk -F'\t' -v id="$3" '$1 != id' "$HOME/github" > "$HOME/github.new"; mv "$HOME/github.new" "$HOME/github" ;;
esac
EOF

    stub ssh <<'EOF'
for arg; do case $arg in IdentityFile=*) handle=${arg#IdentityFile=} ;; esac; done
key=$(cut -d' ' -f1,2 "$handle.pub" 2>/dev/null)
if [ -n "$key" ] && awk -F'\t' -v k="$key" '$2 == "authentication" && $3 == k { f = 1 } END { exit !f }' "$HOME/github"; then
    echo "Hi kulesh! You've successfully authenticated, but GitHub does not provide shell access." >&2
fi
exit 1
EOF
    stub hostname 'echo orion'
}

stub() {   # stub <command> [body]: a stand-in that logs each call; body from stdin without one
    { echo '#!/bin/sh'; echo "echo \"$1 \$*\" >> \"\$HOME/calls\""; if [ -n "${2:-}" ]; then echo "$2"; else cat; fi; } > "$STUBS/$1"
    chmod +x "$STUBS/$1"
}

enclave() {   # enclave <zsh code>: run it with lib/enclave.zsh loaded, every step for real
    run zsh -c "source '$DOTFILES_ROOT/lib/enclave.zsh'; run() { \"\$@\"; }; previewing() { false; }; $1"
}

days_ago() { zsh -c "zmodload zsh/datetime; strftime %Y-%m-%d \$(( EPOCHSECONDS - $1 * 86400 ))"; }

registered() {   # registered <type> <handle>: GitHub has the handle's key for that job
    awk -F'\t' -v t="$1" -v k="$(cut -d' ' -f1,2 "$2.pub")" '$2 == t && $3 == k { f = 1 } END { exit !f }' "$HOME/github"
}

in_agent() { grep -qxF "$(cut -d' ' -f1,2 "$1.pub")" "$HOME/agent"; }

# An older pair, as an earlier run left it: in the enclave, exported, on GitHub.
old_pair() {   # old_pair <date> [valid]
    local role label
    for role in auth sign; do
        label=ssh-$role-$1
        echo "OLD${role} $label ${2:-YES} 1" >> "$HOME/enclave"
        echo "handle" > "$HOME/.ssh/id_enclave_$role"
        echo "sk-ecdsa-sha2-nistp256@openssh.com AAAAOLD$role $label" > "$HOME/.ssh/id_enclave_$role.pub"
    done
    printf '1\tauthentication\tsk-ecdsa-sha2-nistp256@openssh.com AAAAOLDauth\torion enclave\n' >> "$HOME/github"
    printf '2\tsigning\tsk-ecdsa-sha2-nistp256@openssh.com AAAAOLDsign\torion enclave signing\n' >> "$HOME/github"
}

@test "a Mac without enclave keys gets an auth key and a signing key, each registered for its job and in the agent" {
    enclave 'enclave_key auth && enclave_key sign'
    [ "$status" -eq 0 ]
    [ "$(wc -l < "$HOME/enclave")" -eq 2 ]
    grep -q "sc_auth create-ctk-identity -l ssh-auth-$(days_ago 0) -k p-256-ne -t none" "$HOME/calls"
    grep -q "sc_auth create-ctk-identity -l ssh-sign-$(days_ago 0) -k p-256-ne -t none" "$HOME/calls"
    for role in auth sign; do
        [ -f "$HOME/.ssh/id_enclave_$role" ]
        [ "$(stat -c %a "$HOME/.ssh/id_enclave_$role" 2>/dev/null || stat -f %Lp "$HOME/.ssh/id_enclave_$role")" = 600 ]
        in_agent "$HOME/.ssh/id_enclave_$role"
    done
    registered authentication "$HOME/.ssh/id_enclave_auth"
    registered signing "$HOME/.ssh/id_enclave_sign"
    ! registered signing "$HOME/.ssh/id_enclave_auth" || false
    ! registered authentication "$HOME/.ssh/id_enclave_sign" || false
    grep -q $'\torion enclave$' "$HOME/github"
    grep -q $'\torion enclave signing$' "$HOME/github"
}

@test "the public key names the enclave key it belongs to" {
    enclave 'enclave_key auth'
    [ "$status" -eq 0 ]
    [ "$(cut -d' ' -f3 "$HOME/.ssh/id_enclave_auth.pub")" = "ssh-auth-$(days_ago 0)" ]
}

@test "a second run changes nothing" {
    enclave 'enclave_key auth && enclave_key sign'
    : > "$HOME/calls"
    enclave 'enclave_key auth && enclave_key sign'
    [ "$status" -eq 0 ]
    ! grep -q "create-ctk-identity\|ssh-key add\|ssh-key delete\|delete-ctk-identity" "$HOME/calls" || false
    [ "$(wc -l < "$HOME/enclave")" -eq 2 ]
}

@test "a key sc_auth reports making but doesn't list stops the run and says so" {
    SC_AUTH_BROKEN=1 enclave 'enclave_key auth'
    [ "$status" -ne 0 ]
    [[ "$output" == *"ssh-auth-"*"isn't in the Secure Enclave"* ]]
    [ ! -e "$HOME/.ssh/id_enclave_auth" ]
    [ ! -s "$HOME/github" ]
}

@test "a lost handle is exported again from the same key" {
    enclave 'enclave_key auth'
    local key=$(cut -d' ' -f1,2 "$HOME/.ssh/id_enclave_auth.pub")
    rm "$HOME/.ssh/id_enclave_auth" "$HOME/.ssh/id_enclave_auth.pub"
    : > "$HOME/calls"
    enclave 'enclave_key auth'
    [ "$status" -eq 0 ]
    [ "$(cut -d' ' -f1,2 "$HOME/.ssh/id_enclave_auth.pub")" = "$key" ]
    ! grep -q "create-ctk-identity" "$HOME/calls" || false
}

# The certificate on an enclave key lasts a year.
@test "keys 11 months old are replaced: the old auth key leaves GitHub, the old signing key stays for the commits it signed" {
    old_pair "$(days_ago 340)"
    enclave 'enclave_key auth && enclave_key sign'
    [ "$status" -eq 0 ]
    [ "$(cut -d' ' -f3 "$HOME/.ssh/id_enclave_auth.pub")" = "ssh-auth-$(days_ago 0)" ]
    [ "$(cut -d' ' -f3 "$HOME/.ssh/id_enclave_sign.pub")" = "ssh-sign-$(days_ago 0)" ]
    registered authentication "$HOME/.ssh/id_enclave_auth"
    registered signing "$HOME/.ssh/id_enclave_sign"
    ! grep -q "AAAAOLDauth" "$HOME/github" || false
    grep -q $'\tsigning\tsk-ecdsa-sha2-nistp256@openssh.com AAAAOLDsign' "$HOME/github"
    ! grep -q "^OLD" "$HOME/enclave" || false
    [ "$(wc -l < "$HOME/enclave")" -eq 2 ]
}

@test "keys 10 months old are kept" {
    old_pair "$(days_ago 300)"
    enclave 'enclave_key auth && enclave_key sign'
    [ "$status" -eq 0 ]
    ! grep -q "create-ctk-identity" "$HOME/calls" || false
    grep -q "^OLDauth " "$HOME/enclave"
}

@test "a key the enclave marks invalid is replaced whatever its age" {
    old_pair "$(days_ago 10)" NO
    enclave 'enclave_key auth'
    [ "$status" -eq 0 ]
    [ "$(cut -d' ' -f3 "$HOME/.ssh/id_enclave_auth.pub")" = "ssh-auth-$(days_ago 0)" ]
    ! grep -q "^OLDauth " "$HOME/enclave" || false
}

@test "an old auth key stays until the new one signs in to GitHub" {
    old_pair "$(days_ago 340)"
    stub ssh 'exit 255'
    enclave 'enclave_key auth'
    [ "$status" -ne 0 ]
    [[ "$output" == *"couldn't sign in to GitHub"* ]]
    grep -q "AAAAOLDauth" "$HOME/github"
    grep -q "^OLDauth " "$HOME/enclave"
}

@test "only this Mac's own enclave keys are touched" {
    echo "OTHER someone-elses-key YES 1" >> "$HOME/enclave"
    old_pair "$(days_ago 340)"
    printf '9\tauthentication\tssh-ed25519 AAAAlaptop\tlaptop\n' >> "$HOME/github"
    enclave 'enclave_key auth && enclave_key sign'
    [ "$status" -eq 0 ]
    grep -q "^OTHER " "$HOME/enclave"
    grep -q "AAAAlaptop" "$HOME/github"
}
