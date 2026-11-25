"""Second opinions through Claude Code (EASE_LOOP E5), with a stand-in for the claude program: what it is sent, how its
answer is read, and the words when it is not signed in."""

import json
import stat

import pytest

from dighouse import review


def fake_claude(tmp_path, result: dict) -> str:
    """A claude that saves its arguments and what it was sent, and answers with one result line."""
    exe = tmp_path / "claude"
    exe.write_text("#!/bin/sh\n"
                   f"echo \"$@\" > {tmp_path}/args\n"
                   f"cat > {tmp_path}/stdin\n"
                   f"echo '{json.dumps(result)}'\n")
    exe.chmod(exe.stat().st_mode | stat.S_IEXEC)
    return str(exe)


def test_claude_code_answer_is_read(tmp_path, monkeypatch):
    reply = {"type": "result", "is_error": False,
             "result": '{"inside_ring": "a low round rise", "agrees": true, "note": "A small mound."}'}
    monkeypatch.setenv("DIGHOUSE_CLAUDE", fake_claude(tmp_path, reply))
    agrees, note = review.ask("claude-code/claude-sonnet", ["data:image/png;base64,AAAA"], "Is it built?")
    assert agrees is True and note == "A small mound."
    args = (tmp_path / "args").read_text()
    # No tools, no tool servers, none of the person's settings, no saved session, and the model by its alias.
    for flag in ("--safe-mode", "--strict-mcp-config", "--no-session-persistence", "--model sonnet"):
        assert flag in args
    sent = json.loads((tmp_path / "stdin").read_text())
    kinds = [c["type"] for c in sent["message"]["content"]]
    assert kinds == ["text", "image"] and sent["message"]["content"][1]["source"]["media_type"] == "image/png"


def test_claude_code_not_signed_in_says_what_to_do(tmp_path, monkeypatch):
    reply = {"type": "result", "is_error": True, "result": "Failed to authenticate: OAuth session expired"}
    monkeypatch.setenv("DIGHOUSE_CLAUDE", fake_claude(tmp_path, reply))
    with pytest.raises(RuntimeError, match="not signed in"):
        review.ask("claude-code/claude-haiku", ["data:image/png;base64,AAAA"], "Is it built?")
