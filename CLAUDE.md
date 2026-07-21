# Token-Saving Directives (CRITICAL)
- Minimize Explanations: Do not explain basic concepts, syntax, or dependencies unless explicitly requested.
- Code Diff Economy: Never output an entire 200-line source file if only 5 lines are changing. Only print lines with context diff markers (e.g., `// ... existing code ...`).
- Strict File Targeting: Do not read entire directories. Ask me for explicit file paths if you need deeper context.
- Terminal Output Control: If a command produces more than 20 lines of output, summarize the logs instead of printing them out in full text.

# Build & Test Commands
- Build: npm run build
- Test: npm test

# Git Commit Messages
- After finishing work, recommend a commit message as a single-line title only (no body, no bullet list).
- Do not run `git commit` yourself — the user commits manually.