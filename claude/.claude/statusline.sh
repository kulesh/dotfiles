#!/bin/bash

# Read stdin JSON input
input=$(cat)

# Extract information from JSON
cwd=$(echo "$input" | jq -r '.workspace.current_dir')

# Calculate context usage percentage
context_info=""
usage=$(echo "$input" | jq '.context_window.current_usage')
if [ "$usage" != "null" ]; then
  # Get current context usage (input + cache tokens)
  current=$(echo "$usage" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
  size=$(echo "$input" | jq '.context_window.context_window_size')

  if [ "$current" != "null" ] && [ "$size" != "null" ]; then
    pct=$((current * 100 / size))

    # Color code based on usage: green (<50%), yellow (50-80%), red (>80%)
    if [ "$pct" -lt 50 ]; then
      color=$(printf '\033[32m')  # Green
    elif [ "$pct" -lt 80 ]; then
      color=$(printf '\033[33m')  # Yellow
    else
      color=$(printf '\033[31m')  # Red
    fi

    context_info=$(printf " %s[%d%%]" "$color" "$pct")
  fi
fi

# Get username and hostname
username=$(whoami)
hostname=$(hostname -s)

# Get directory name (basename of current path)
dir_display=$(basename "$cwd")

# Get git information if in a git repository
git_info=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  # Get branch name
  branch=$(git -C "$cwd" branch --show-current 2>/dev/null || echo "detached")

  # Check for changes (skip optional locks to avoid interference)
  git_status=$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)

  # Determine status indicators with colors
  staged=""
  unstaged=""
  untracked=""

  if echo "$git_status" | grep -q '^[MADRCU]'; then
    staged=$(printf '\033[32m●')  # Green dot for staged changes
  fi

  if echo "$git_status" | grep -q '^.[MD]'; then
    unstaged=$(printf '\033[33m●')  # Yellow dot for unstaged changes
  fi

  if echo "$git_status" | grep -q '^??'; then
    untracked=$(printf '\033[31m●')  # Red dot for untracked files
  fi

  # Build git info string with colors
  # Format: [green_branch green_staged yellow_unstaged red_untracked blue_bracket]
  git_info=$(printf " [%s%s%s%s%s%s]" \
    "$(printf '\033[32m')" "$branch" \
    "$staged" "$unstaged" "$untracked" \
    "$(printf '\033[34m')")
fi

# Build the status line matching zsh PROMPT format
# Format: white(username@hostname dir) git_info context_info white(%)
printf '%s%s@%s %s%s%s%s' \
  "$(printf '\033[37m')" \
  "$username" \
  "$hostname" \
  "$dir_display" \
  "$git_info" \
  "$context_info" \
  "$(printf '\033[37m')"
