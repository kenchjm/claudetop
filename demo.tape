Output demo.gif
Set Width 920
Set Height 320
Set FontSize 13
Set FontFamily "JetBrains Mono"
Set Theme "Catppuccin Mocha"
Set Padding 15
Set TypingSpeed 40ms

Type "# claudetop — htop for your Claude Code sessions"
Enter
Sleep 1s

Type "# Here's what it looks like after 20 minutes on Opus:"
Enter
Sleep 500ms

Type@0ms 'echo '"'"'{"cwd":"/Users/dev/my-saas/src/app","model":{"id":"claude-opus-4-6","display_name":"Opus"},"workspace":{"current_dir":"/Users/dev/my-saas/src/app","project_dir":"/Users/dev/my-saas"},"cost":{"total_cost_usd":4.82,"total_duration_ms":1200000,"total_lines_added":256,"total_lines_removed":43},"context_window":{"total_input_tokens":285000,"total_output_tokens":52000,"used_percentage":38,"remaining_percentage":62,"current_usage":{"input_tokens":25000,"output_tokens":12000,"cache_creation_input_tokens":15000,"cache_read_input_tokens":200000}}}'"'"' | ~/.claude/claudetop.sh'
Sleep 200ms
Enter
Sleep 3s

Type "# Cache is at 83% — tokens are being reused efficiently"
Enter
Sleep 1.5s

Type "# Now let's check: what if we switched to Sonnet?"
Enter
Sleep 1.5s

Type "# opus:~$3.82  vs  sonnet:~$1.08  — 3.5x cheaper for this task"
Enter
Sleep 2s

Type "# And here's what a bad session looks like:"
Enter
Sleep 500ms

Type@0ms 'echo '"'"'{"cwd":"/Users/dev/my-saas","model":{"id":"claude-opus-4-6","display_name":"Opus"},"workspace":{"current_dir":"/Users/dev/my-saas","project_dir":"/Users/dev/my-saas"},"cost":{"total_cost_usd":18.50,"total_duration_ms":7200000,"total_lines_added":80,"total_lines_removed":20},"context_window":{"total_input_tokens":750000,"total_output_tokens":95000,"used_percentage":82,"remaining_percentage":18,"current_usage":{"input_tokens":180000,"output_tokens":30000,"cache_creation_input_tokens":60000,"cache_read_input_tokens":20000}}}'"'"' | ~/.claude/claudetop.sh'
Sleep 200ms
Enter
Sleep 3s

Type "# COMPACT SOON + LOW CACHE + BURN RATE + $10 MARK — time to start fresh"
Enter
Sleep 2s

Type "# Install: curl -fsSL https://raw.githubusercontent.com/liorwn/claudetop/main/install.sh | bash"
Enter
Sleep 3s
