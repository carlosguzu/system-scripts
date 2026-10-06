# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""
Antigravity Stop Hook: Checks if specific files modified during the turn
belong to a Git repository and have uncommitted changes.
"""

import json
import os
import subprocess
import sys

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

def is_file_dirty(repo_path: str, file_path: str) -> bool:
    try:
        rel_path = os.path.relpath(file_path, repo_path)
        status = subprocess.check_output(
            ["git", "-C", repo_path, "status", "--porcelain", rel_path],
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
    except Exception:
        print("{}")
        sys.exit(0)

    exec_num = payload.get("executionNum", 1)
    if exec_num > 1:
        print("{}")
        sys.exit(0)

    dirty_repos = set()
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
                                    if repo and is_file_dirty(repo, tf):
                                        dirty_repos.add(repo)
                    except Exception:
                        continue
        except Exception:
            pass

    if dirty_repos:
        repos_str = ", ".join(sorted(dirty_repos))
        output = {
            "decision": "continue",
            "reason": (
                f"Se detectaron cambios sin commitear en el repositorio Git: {repos_str}. "
                "Pregúntale obligatoriamente al usuario si desea realizar commit y push antes de finalizar."
            ),
        }
        print(json.dumps(output))
    else:
        print("{}")

if __name__ == "__main__":
    main()
