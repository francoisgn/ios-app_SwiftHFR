#!/usr/bin/env python3
"""Issue claims and the PR link check (AGENTS.md §5, §8).

A session claims an issue with a comment whose first line is `/claim <session-id>` and gives it back with `/release`.
The first claim wins; another session's `/claim` is refused until the holder releases. Only comments from repository
members count (author association OWNER, MEMBER or COLLABORATOR), so outsiders cannot take or drop a claim on a public repo.

Commands (run by the workflows, standard library only, GitHub REST through GITHUB_TOKEN):
    issue_claims.py check-pr      PR event: the body links an open issue and states the claim that holds it.
    issue_claims.py sync-issue    Issue comment event: labels the issue and answers a refused claim.
"""
from __future__ import annotations

import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass, field

SESSION_ID = re.compile(r"^[a-z]+/[A-Za-z0-9._-]{1,64}$")
COMMAND = re.compile(r"^/(claim|release)(?:[ \t]+(\S+))?[ \t]*$")
MEMBERS = {"OWNER", "MEMBER", "COLLABORATOR"}
ISSUE_LINK = re.compile(r"\b(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?|refs?)\s+#(\d+)\b", re.IGNORECASE)
CLAIM_LINE = re.compile(r"^Claim:[ \t]*(\S+)[ \t]*$", re.MULTILINE)
EXEMPT_AUTHORS = {"dependabot[bot]"}
HTML_COMMENT = re.compile(r"<!--.*?-->", re.DOTALL)
CLAIMED_LABEL = "status: claimed"
READY_LABEL = "status: ready"


@dataclass
class ClaimState:
    """Result of replaying an issue's comments in order."""

    holder: str | None = None
    refused: list[tuple[str, str]] = field(default_factory=list)  # (session that asked, holder at that time)
    invalid: list[str] = field(default_factory=list)  # malformed session ids


def parse_command(body: str) -> tuple[str, str | None] | None:
    """`("claim", id)` or `("release", id or None)` from the first non-empty line of a comment, else None."""
    for line in (body or "").splitlines():
        if line.strip():
            match = COMMAND.match(line.strip())
            return (match.group(1), match.group(2)) if match else None
    return None


def replay(comments: list[dict]) -> ClaimState:
    """Claim state after `comments` (GitHub REST issue comments, oldest first)."""
    state = ClaimState()
    for comment in comments:
        if comment.get("author_association") not in MEMBERS:
            continue
        command = parse_command(comment.get("body", ""))
        if command is None:
            continue
        verb, session = command
        if verb == "claim":
            if session is None or not SESSION_ID.match(session):
                state.invalid.append(session or "")
            elif state.holder is None:
                state.holder = session
            elif state.holder != session:
                state.refused.append((session, state.holder))
        elif session is None or session == state.holder:
            # `/release` alone frees the issue; `/release <id>` only when it names the holder.
            state.holder = None
    return state


def pr_errors(body: str, author: str, issues: dict[int, dict], claims: dict[int, ClaimState]) -> list[str]:
    """Reasons the PR fails the check; empty when it passes. `issues`/`claims` are keyed by the linked numbers."""
    if author in EXEMPT_AUTHORS:
        return []
    body = normalized(body)
    errors = []
    numbers = linked_issues(body)
    if not numbers:
        errors.append("The PR body must link its issue in this repository: `Closes #N` (or `Refs #N` for partial work).")
    claim_match = CLAIM_LINE.search(body)
    claimant = claim_match.group(1) if claim_match else None
    if claimant is None:
        errors.append("The PR body must state the claim it works under: a line `Claim: <session-id>`.")
    for number in numbers:
        issue = issues.get(number)
        if issue is None:
            errors.append(f"#{number} does not exist.")
            continue
        if "pull_request" in issue:
            errors.append(f"#{number} is a pull request, not an issue.")
            continue
        if issue.get("state") != "open":
            errors.append(f"#{number} is closed.")
            continue
        holder = claims[number].holder
        if holder is None:
            errors.append(f"#{number} is not claimed: comment `/claim {claimant or '<session-id>'}` on it first.")
        elif claimant is not None and holder != claimant:
            errors.append(f"#{number} is claimed by `{holder}`, not by `{claimant}`.")
    return errors


def normalized(body: str | None) -> str:
    """PR body without CR (the web editor sends CRLF) and without HTML comments (template hints are not links)."""
    return HTML_COMMENT.sub("", (body or "").replace("\r\n", "\n").replace("\r", "\n"))


def linked_issues(body: str) -> list[int]:
    """Issue numbers linked with a closing keyword or `Refs`, in order, without duplicates."""
    return list(dict.fromkeys(int(n) for n in ISSUE_LINK.findall(normalized(body))))


# MARK: - GitHub REST

def api(path: str, method: str = "GET", payload: dict | None = None):
    """JSON from the GitHub REST API (`path` relative to the repository), or None on 404."""
    url = f"https://api.github.com/repos/{os.environ['GITHUB_REPOSITORY']}/{path}"
    data = json.dumps(payload).encode() if payload is not None else None
    request = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": f"Bearer {os.environ['GITHUB_TOKEN']}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    })
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            text = response.read().decode()
            return json.loads(text) if text else None
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return None
        raise


def all_comments(number: int) -> list[dict]:
    comments, page = [], 1
    while True:
        batch = api(f"issues/{number}/comments?per_page=100&page={page}") or []
        comments += batch
        if len(batch) < 100:
            return comments
        page += 1


def event() -> dict:
    with open(os.environ["GITHUB_EVENT_PATH"], encoding="utf-8") as handle:
        return json.load(handle)


def check_pr() -> int:
    pull = event()["pull_request"]
    body, author = pull.get("body") or "", pull["user"]["login"]
    numbers = linked_issues(body)
    issues = {n: issue for n in numbers if (issue := api(f"issues/{n}")) is not None}
    claims = {n: replay(all_comments(n)) for n in issues}
    errors = pr_errors(body, author, issues, claims)
    for error in errors:
        print(f"::error title=Issue and claim::{error}")
    if not errors:
        linked = ", ".join(f"#{n} ({claims[n].holder})" for n in numbers) or "exempt author"
        print(f"Issue and claim OK: {linked}")
    return 1 if errors else 0


def sync_issue() -> int:
    """Replays the whole history (a comment may have been edited or deleted), then fixes the labels."""
    payload = event()
    issue, comment = payload["issue"], payload["comment"]
    if "pull_request" in issue:
        return 0
    number = issue["number"]
    state = replay(all_comments(number))
    labels = {label["name"] for label in issue.get("labels", [])}
    if issue.get("state") == "open":
        if state.holder and CLAIMED_LABEL not in labels:
            api(f"issues/{number}/labels", "POST", {"labels": [CLAIMED_LABEL]})
            if READY_LABEL in labels:
                api(f"issues/{number}/labels/{urllib.parse.quote(READY_LABEL)}", "DELETE")
        elif state.holder is None and CLAIMED_LABEL in labels:
            api(f"issues/{number}/labels/{urllib.parse.quote(CLAIMED_LABEL)}", "DELETE")
            if not labels & {"status: blocked", "status: needs-triage"}:
                api(f"issues/{number}/labels", "POST", {"labels": [READY_LABEL]})
    command = parse_command(comment.get("body", "")) if payload.get("action") == "created" else None
    reply = None
    if command and command[0] == "claim":
        if issue.get("state") != "open":
            reply = "Claim refused: this issue is closed."
        elif command[1] is None or not SESSION_ID.match(command[1]):
            reply = "Claim refused: the session id must look like `cloud/c12-sonnet`, `mac/M1` or `human/<login>`."
        elif state.holder != command[1]:
            reply = f"Claim refused: this issue is claimed by `{state.holder}`. Ask it to `/release`, or the maintainer."
    if reply:
        api(f"issues/{number}/comments", "POST", {"body": reply})
    print(f"#{number}: holder={state.holder}")
    return 0


if __name__ == "__main__":
    commands = {"check-pr": check_pr, "sync-issue": sync_issue}
    if len(sys.argv) != 2 or sys.argv[1] not in commands:
        sys.exit(f"usage: {sys.argv[0]} {{{'|'.join(commands)}}}")
    sys.exit(commands[sys.argv[1]]())
