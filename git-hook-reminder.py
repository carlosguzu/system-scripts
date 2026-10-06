# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""
Antigravity Stop Hook: Checks if files modified during the turn belong to a Git repository
with pending uncommitted changes, and prompts the agent to ask the user.
"""

import json
import os
import subprocess
import sys
from datetime import datetime

LOG_FILE = "/tmp/antigravity_git_hook.log"

def log(msg: str):
    try:
        with open(LOG_FILE, "a") as f:
            f.write(f"[{datetime.now().isoformat()}] {msg}\n")
    except Exception:
        pass

def get_git_repo(path: str) -> str | None:
    try:
        res = subprocess.check_output(
            ["git", "-C", path, "rev-parse", "--show-toplevel"],
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
        return res if res else None
    except Exception:
        return None

def is_repo_dirty(repo_path: str) -> bool:
    try:
        status = subprocess.check_output(
            ["git", "-C", repo_path, "status", "--porcelain"],
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
        return bool(status)
    except Exception:
        return False

def main() -> None:
    try:
        raw = sys.stdin.read()
        payload = json.loads(raw)
    except Exception as e:
        log(f"Failed to read/parse payload: {e}")
        print("{}")
        sys.exit(0)

    log(f"Received payload: {json.dumps(payload)}")

    # Check executionNum or conversation state
    exec_num = payload.get("executionNum", 1)
    conv_id = payload.get("conversationId", "default")
    state_file = f"/tmp/git_hook_reminded_{conv_id}.flag"

    # If already reminded in this turn/session, allow stop
    if exec_num > 1 or os.path.exists(state_file):
        log(f"Bypassing check (exec_num={exec_num}, flag_exists={os.path.exists(state_file)})")
        print("{}")
        sys.exit(0)

    dirty_repos = set()

    # 1. Inspect modified files in transcriptPath
    transcript_path = payload.get("transcriptPath", "")
    if transcript_path and os.path.exists(transcript_path):
        try:
            with open(transcript_path, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    try:
                        step = json.loads(line)
                        for tc in step.get("tool_calls", []):
                            args = tc.get("args", {})
                            tf = args.get("TargetFile")
                            if tf:
                                tf = tf.strip('"')
                                if os.path.exists(tf):
                                    repo = get_git_repo(os.path.dirname(tf))
                                    if repo and is_repo_dirty(repo):
                                        dirty_repos.add(repo)
                    except Exception:
                        continue
        except Exception:
            pass

    # 2. Inspect workspace paths
    for ws in payload.get("workspacePaths", []):
        if os.path.isdir(ws):
            repo = get_git_repo(ws)
            if repo and is_repo_dirty(repo):
                dirty_repos.add(repo)

    if dirty_repos:
        # Mark as reminded so we don't block repeatedly in an infinite loop
        try:
            with open(state_file, "w") as f:
                f.write(datetime.now().isoformat())
        except Exception:
            pass

        repos_str = ", ".join(sorted(dirty_repos))
        output = {
            "decision": "continue",
            "reason": (
                f"Se detectaron cambios sin commitear en el repositorio Git: {repos_str}. "
                "Pregúntale obligatoriamente al usuario si desea realizar commit y push antes de finalizar."
            ),
        }
        log(f"Emitting continue decision: {json.dumps(output)}")
        print(json.dumps(output))
    else:
        log("No dirty repos found, allowing stop.")
        print("{}")

if __name__ == "__main__":
    main()
