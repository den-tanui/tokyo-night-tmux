# Widget Reordering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow users to specify which right-bar widgets appear and in what order via a new `@tokyo-night-tmux_show_right_widgets` option, with passthrough for arbitrary tmux `#()` commands and format variables.

**Architecture:** Add a `build_widget_string()` function to `tokyo-night.tmux` that parses the comma-separated option, matches known widget names to their predefined `#()` substitution strings, and passes through `#(` and `#{` entries verbatim. Replace the hardcoded `status-right` with a conditional: use the dynamic builder when the option is set, fall back to the current order otherwise.

**Tech Stack:** Bash 4.2+, tmux (works on all versions)

**Depends on:** Branch `feature/widget-reordering` from `next`.

---

### Branch: `feature/widget-reordering`

Created from `origin/next`. Targets `next` for PR.

---

### Task 1: Create the branch

**Files:**
- Create: `feature/widget-reordering` branch

- [ ] **Step 1: Fetch and branch**

```bash
git fetch origin next
git checkout -b feature/widget-reordering origin/next
```

---

### Task 2: Add `build_widget_string()` to `tokyo-night.tmux`

**Files:**
- Modify: `tokyo-night.tmux`

- [ ] **Step 2: Insert the `build_widget_string()` function**

After line 55 (`window_space=...`) and before line 57 (`netspeed=...`), add:

```bash
# Build a status string from a comma-separated widget list option
# Usage: build_widget_string <option_suffix>
#   e.g. build_widget_string "show_right_widgets" reads @tokyo-night-tmux_show_right_widgets
# Entries starting with #( or #{ are passed through verbatim (arbitrary commands/format vars).
build_widget_string() {
  local option_name="@tokyo-night-tmux_$1"
  local list
  list=$(echo "$TMUX_VARS" | grep "${option_name}" | cut -d" " -f2)
  [[ -z $list ]] && return

  local result=""
  local saved_ifs="$IFS"
  IFS=','
  for item in $list; do
    item="$(echo "$item" | xargs)"  # trim whitespace
    if [[ $item == "#("* ]] || [[ $item == "#{"* ]]; then
      # Passthrough — user-supplied tmux command or format variable
      result+="$item"
    else
      case "$item" in
        battery)  result+="$battery_status" ;;
        path)     result+="$current_path" ;;
        music)    result+="$cmus_status" ;;
        netspeed) result+="$netspeed" ;;
        git)      result+="$git_status" ;;
        wbg)      result+="$wb_git_status" ;;
        datetime) result+="$date_and_time" ;;
        hostname) result+="$hostname" ;;
      esac
    fi
  done
  IFS="$saved_ifs"
  echo "$result"
}
```

- [ ] **Step 3: Replace hardcoded `status-right` with dynamic construction**

Replace line 80:
```bash
tmux set -g status-right "$battery_status$current_path$cmus_status$netspeed$git_status$wb_git_status$date_and_time"
```

With:
```bash
# Widget reordering: if show_right_widgets is set, build from list; else default order
RIGHT_WIDGETS=$(echo "$TMUX_VARS" | grep '@tokyo-night-tmux_show_right_widgets' | cut -d" " -f2)
if [[ -n $RIGHT_WIDGETS ]]; then
  tmux set -g status-right "$(build_widget_string "show_right_widgets")"
else
  tmux set -g status-right "$battery_status$current_path$cmus_status$netspeed$git_status$wb_git_status$date_and_time"
fi
```

---

### Task 3: Verify and commit

- [ ] **Step 4: Run pre-commit checks**

```bash
pre-commit run --all-files
```
Expected: shfmt and codespell pass cleanly. If shfmt changes formatting, the changes are already applied (it uses `-w`).

- [ ] **Step 5: Verify the file reads correctly**

```bash
bat tokyo-night.tmux  # or: head -90 tokyo-night.tmux
```
Check that the function and the new conditional block look right.

- [ ] **Step 6: Commit**

```bash
git add tokyo-night.tmux
git commit -m "feat: add widget reordering via show_right_widgets with arbitrary command passthrough"
```

```bash
git log --oneline -3
```
Expected: shows your new commit on top of `origin/next`.

---

### Self-review

- [ ] `build_widget_string` only matches known widget names after trimming whitespace from each list entry.
- [ ] `#(` and `#{` entries are passed through unmodified.
- [ ] When `show_right_widgets` is unset, behavior is identical to before (backward compatible).
- [ ] When `show_right_widgets` is set, only listed widgets produce `#()` calls — unlisted widgets never run.
