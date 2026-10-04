#!/usr/bin/env python3
"""Choose a split direction with one key from a Herdr command popup."""

import importlib.util
import json
import os
import subprocess
import sys
import termios
import tty


def choose_direction(tool):
    print(f"{tool}: [r] right  [b/Enter] below\n[Esc] cancel", flush=True)
    fd = sys.stdin.fileno()
    previous = termios.tcgetattr(fd)
    try:
        # Do not flush: the direction key may already be queued when we start.
        tty.setcbreak(fd, termios.TCSANOW)
        while True:
            key = os.read(fd, 1)
            if key in (b"r", b"b", b"\r", b"\n"):
                return "right" if key == b"r" else "down"
            if key in (b"", b"\x1b", b"\x03", b"\x04"):
                return None
    finally:
        termios.tcsetattr(fd, termios.TCSANOW, previous)


def run_json(*args):
    binary = os.environ.get("HERDR_BIN_PATH") or "herdr"
    result = subprocess.run(
        [binary, *args], text=True, capture_output=True, check=False
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip()
                           or f"Herdr command failed: {' '.join(args)}")
    # `pane run` succeeds without printing a JSON response.
    if not result.stdout.strip():
        return {}
    payload = json.loads(result.stdout)
    if "error" in payload:
        raise RuntimeError(json.dumps(payload["error"], ensure_ascii=False))
    return payload["result"]


def active_context():
    workspace = os.environ.get("HERDR_ACTIVE_WORKSPACE_ID")
    pane = os.environ.get("HERDR_ACTIVE_PANE_ID")
    cwd = os.environ.get("HERDR_ACTIVE_PANE_CWD")
    if not workspace or not pane or not cwd:
        raise RuntimeError("Run this shortcut from a Herdr pane with a working directory.")
    return workspace, pane, cwd


def installed_plugin(plugin_id):
    plugins = run_json("plugin", "list", "--json")["plugins"]
    for plugin in plugins:
        if plugin["plugin_id"] == plugin_id and plugin.get("enabled", False):
            return plugin
    raise RuntimeError(f"Plugin is not installed or enabled: {plugin_id}")


def open_reviewr(direction, workspace, pane, cwd):
    plugin = installed_plugin("persiyanov.reviewr")
    panes = run_json("pane", "list", "--workspace", workspace)["panes"]
    # Match the installed reviewr toggle's workspace-wide behavior.
    existing = [p for p in panes if p.get("label") == "reviewr"]
    if existing:
        for review_pane in existing:
            run_json("pane", "close", review_pane["pane_id"])
        return
    check = subprocess.run(
        ["git", "-C", cwd, "rev-parse", "--show-toplevel"],
        capture_output=True, check=False,
    )
    if check.returncode:
        raise RuntimeError(f"Not a Git repository: {cwd}")
    # Older reviewr releases call this entrypoint 'sidebar'; newer ones use 'pane'.
    entrypoint = next(
        (p["id"] for p in plugin.get("panes", []) if p["id"] in ("sidebar", "pane")),
        None,
    )
    if not entrypoint:
        raise RuntimeError("reviewr has no supported pane entrypoint.")
    run_json(
        "plugin", "pane", "open", "--plugin", "persiyanov.reviewr",
        "--entrypoint", entrypoint, "--placement", "split",
        "--target-pane", pane,
        "--direction", direction, "--cwd", cwd, "--no-focus",
    )


def open_hunk(direction, workspace, pane, cwd):
    plugin = installed_plugin("hunk.diff")
    # Reuse the plugin's command builder so its executable, diff and theme
    # defaults remain identical to worktree-split, including the bunx fallback.
    script = os.path.join(plugin["plugin_root"], "hunk_herdr.py")
    spec = importlib.util.spec_from_file_location("hunk_herdr", script)
    if spec is None or spec.loader is None:
        raise RuntimeError("Cannot load the Hunk plugin command builder.")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    command = module.shell_command(cwd, "worktree")
    result = run_json(
        "pane", "split", pane, "--direction", direction,
        "--cwd", cwd, "--focus",
    )
    new_pane = result["pane"]["pane_id"]
    run_json("pane", "rename", new_pane, "hunk")
    run_json("pane", "run", new_pane, command)


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ("reviewr", "hunk"):
        raise RuntimeError("Usage: open-diff.py reviewr|hunk")
    # Match the plugin actions' PATH additions for Homebrew and common installs.
    os.environ["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + os.environ.get("PATH", "")
    tool = sys.argv[1]
    direction = choose_direction(tool)
    if direction is None:
        return
    context = active_context()
    if tool == "reviewr":
        open_reviewr(direction, *context)
    else:
        open_hunk(direction, *context)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
    except Exception as error:
        print(f"\r\n{error}", file=sys.stderr, flush=True)
        if sys.stdin.isatty():
            input("Press Enter to close.")
        sys.exit(1)
