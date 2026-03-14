# claudetop

**htop for your Claude Code sessions.**

Real-time status line showing project context, token usage, cost insights, cache efficiency, smart alerts, and a plugin system for extensibility. Tracks session history for analytics and budgeting.

```
14:32  my-project/src/app  Opus  20m 0s  +256/-43  #auth-refactor
152.3K in / 45.2K out  ████░░░░░░ 38%  $3.47  $5.10/hr  ~$174/mo
cache: 66%  efficiency: $0.012/line  opus:$4.38  sonnet:$0.88  haiku:$0.23
in:80% out:20% (fresh:15% cwrite:7% cread:76%)
$5 MARK  |  main*  |  ♫ Artist - Song  |  PROJ-123  |  CI ✓
```

## Install

```bash
git clone https://github.com/liorwn/claudetop.git
cd claudetop
chmod +x install.sh
./install.sh
```

Then restart Claude Code.

## What you get

### Line 1 — Context
- **Time of day** — turns magenta after 10pm
- **Project name** + relative path within project
- **Model** (Opus / Sonnet / Haiku)
- **Session duration** and **lines changed**
- **Session tag** — `#auth-refactor` (via `CLAUDETOP_TAG` env var)

### Line 2 — Resources
- **Token counts** (formatted as K/M)
- **Context window bar** — green <50%, yellow 50-80%, red 80%+
- **Compact warning** — `COMPACT SOON` at 80%+
- **Actual session cost** + **cost velocity** ($/hr)
- **Monthly forecast** — `~$174/mo` extrapolated from your history

### Line 3 — Efficiency
- **Cache hit ratio** — how much you're saving from caching
- **Output efficiency** — cost per line of code changed
- **Model cost comparison** — cache-aware estimates for Opus, Sonnet, Haiku

### Line 4 — Context Composition
- **Input/output ratio** — what % of tokens are input vs output
- **Cache breakdown** — fresh input, cache writes, cache reads

### Line 5 — Alerts + Plugins
Smart alerts that only appear when triggered:

| Alert | Trigger | Action |
|-------|---------|--------|
| `$5 MARK` / `$10` / `$25` | Cost threshold crossed | Check ROI |
| `OVER BUDGET ($X/$Y)` | Daily budget exceeded | Wrap up or switch models |
| `budget: $X left` | 80%+ of daily budget used | Pace yourself |
| `CONSIDER FRESH SESSION` | >2hrs + >60% context | Start fresh |
| `LOW CACHE` | <20% cache after 5min | Context was reset |
| `BURN RATE` | >$15/hr velocity | Check for loops |
| `SPINNING?` | >$1 spent, 0 lines changed | Stuck in research |
| `TRY /fast` | >$0.05/line on Opus | Switch model |

## Themes

Set `CLAUDETOP_THEME` to control information density:

```bash
export CLAUDETOP_THEME=full      # Default: 3-5 lines, everything
export CLAUDETOP_THEME=minimal   # 2 lines: context + cost
export CLAUDETOP_THEME=compact   # 1 line: project + cost + bar
```

## Session History & Analytics

claudetop automatically logs every session via a `SessionEnd` hook. View your spending:

```bash
claudetop-stats              # Today's summary
claudetop-stats week         # This week
claudetop-stats month        # This month
claudetop-stats all          # All time
claudetop-stats tag auth     # Filter by session tag
```

Output includes: total cost, avg cost/session, tokens used, lines changed, cost by model, cost by project, most expensive session, daily averages.

### Session Tagging

Tag sessions to track costs per feature/initiative:

```bash
export CLAUDETOP_TAG=auth-refactor    # Shows as #auth-refactor
export CLAUDETOP_TAG=billing-fix      # Filter later with: claudetop-stats tag billing-fix
```

## Daily Budget

Set a spending limit per day:

```bash
export CLAUDETOP_DAILY_BUDGET=50    # $50/day
```

Shows `budget: $12 left` at 80% usage, `OVER BUDGET ($52/$50)` when exceeded.

## Monthly Forecast

Automatically extrapolated from your last 7 days of history: `~$174/mo`. No config needed — just requires the SessionEnd hook to be active.

## Plugins

Drop any executable script into `~/.claude/claudetop.d/` and it becomes part of your status line.

Each plugin:
- Receives the full session JSON on **stdin**
- Outputs a single formatted string (ANSI colors OK)
- Has a **1 second timeout** (slow plugins are skipped)

### Bundled plugins

| Plugin | Default | What it does |
|--------|---------|-------------|
| `git-branch.sh` | Enabled | Current branch + dirty indicator (`main*`) |

### Example plugins

Copy from `~/.claude/claudetop.d/_examples/` to enable:

```bash
cp ~/.claude/claudetop.d/_examples/spotify.sh ~/.claude/claudetop.d/
cp ~/.claude/claudetop.d/_examples/gh-ci-status.sh ~/.claude/claudetop.d/
cp ~/.claude/claudetop.d/_examples/meeting-countdown.sh ~/.claude/claudetop.d/
```

| Plugin | What it does |
|--------|-------------|
| `spotify.sh` | Now playing on Spotify (macOS) |
| `gh-ci-status.sh` | GitHub CI status for current branch (`CI ✓` / `CI ✗`) |
| `meeting-countdown.sh` | Next calendar event countdown (`Mtg in 12m`) |
| `ticket-from-branch.sh` | Parse JIRA/Linear ticket from branch name (`PROJ-123`) |
| `weather.sh` | Current weather via wttr.in |
| `news-ticker.sh` | Top Hacker News story |
| `pomodoro.sh` | Focus timer (`touch ~/.claude/pomodoro-start`) |
| `system-load.sh` | CPU load average |

### Write your own

```bash
#!/bin/bash
# ~/.claude/claudetop.d/my-plugin.sh
JSON=$(cat)
MODEL=$(echo "$JSON" | jq -r '.model.display_name')
printf "\033[90mmodel: %s\033[0m" "$MODEL"
```

## How model cost comparison works

Estimates are **cache-aware** — they use your actual cache hit ratio (from the current turn) extrapolated across cumulative token usage:

| Model | Input | Cache Write | Cache Read | Output |
|-------|-------|-------------|------------|--------|
| Opus | $15/MTok | $18.75/MTok | $1.50/MTok | $75/MTok |
| Sonnet | $3/MTok | $3.75/MTok | $0.30/MTok | $15/MTok |
| Haiku | $0.80/MTok | $1.00/MTok | $0.08/MTok | $4/MTok |

## Color coding

All metrics use traffic-light colors:

| Metric | Green | Yellow | Red |
|--------|-------|--------|-----|
| Cost velocity | <$3/hr | <$8/hr | ≥$8/hr |
| Cache ratio | ≥60% | ≥30% | <30% |
| Efficiency | <$0.01/line | <$0.05/line | ≥$0.05/line |
| Context bar | <50% | 50-80% | ≥80% |

## Requirements

- Claude Code (with status line support)
- `jq` (`brew install jq` / `apt install jq`)
- `bc` (pre-installed on macOS and most Linux)

## License

MIT
