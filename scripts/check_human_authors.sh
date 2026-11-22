#!/bin/sh
# Fails when a commit in the range, or a pull request description, credits an AI tool.
# Only people are credited in this repository (AGENTS.md). People may use AI tools; they may say so in words.
#
#   scripts/check_human_authors.sh [range]        # default: origin/main..HEAD
#   PR_BODY="..." scripts/check_human_authors.sh  # also checks a pull request description

range="${1:-origin/main..HEAD}"
ai='claude|anthropic|openai|chatgpt|codex|copilot|gemini|cursor|devin|aider|\[bot\]'
failed=0

authors=$(git log --format='%h  author: %an <%ae>  committer: %cn <%ce>' "$range" | grep -iE "author: [^<]*<[^>]*($ai)|author: [^<]*($ai)|committer: [^<]*($ai)|committer: [^<]*<[^>]*($ai)")
if [ -n "$authors" ]; then
    echo "These commits have an AI as author or committer. Commit as yourself:"
    echo "$authors"
    failed=1
fi

trailers=$(git log --format='%h %(trailers:key=Co-authored-by,valueonly,separator=%x2C )' "$range" | grep -iE "$ai")
if [ -n "$trailers" ]; then
    echo "These commits list an AI as a co-author. Remove the Co-authored-by line:"
    echo "$trailers"
    failed=1
fi

if [ -n "${PR_BODY:-}" ]; then
    # Attribution lines only (they start with the phrase, perhaps after an emoji), so prose that mentions the rule passes.
    body=$(printf '%s\n' "$PR_BODY" | grep -iE "^[^[:alnum:]]*(co-authored-by:.*($ai)|generated (with|by) \[?[^]]*($ai))")
    if [ -n "$body" ]; then
        echo "The pull request description credits an AI. Say in words that you used one if you like, but do not credit it:"
        echo "$body"
        failed=1
    fi
fi

[ "$failed" = 0 ] && echo "Only people are credited."
exit "$failed"
