"""Push the local HEAD's content to GitHub via the REST API (gh CLI transport).

Why: the campus network resets connections to github.com:443 and ssh :22/:443,
but api.github.com works through the gh CLI. Normal `git push` therefore fails.
This script mirrors the content of local HEAD onto the remote branch:

  1. list local files from `git ls-tree -r HEAD` (blob SHAs match GitHub's)
  2. fetch the remote branch tree; upload only blobs whose SHA is new
  3. create a full tree (handles deletions), a commit, and update the ref

Remote history is a mirror of local content (commit SHAs differ from local  - 
GitHub is the deploy target; the local repo is the source of truth).

Usage:  python tools/push_via_api.py [--repo OWNER/NAME] [--branch main] [-m MSG]
Run from the repository root.
"""
import argparse
import base64
import json
import os
import subprocess
import sys
import tempfile

def sh(args, **kw):
    r = subprocess.run(args, capture_output=True, text=True, **kw)
    if r.returncode != 0:
        raise RuntimeError(f"{' '.join(args)}\n{r.stderr}")
    return r.stdout

def gh_api(path, method="GET", body=None, ok404=False):
    args = ["gh", "api", path, "-X", method] if method != "GET" else ["gh", "api", path]
    tmp = None
    try:
        if body is not None:
            tmp = tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8")
            json.dump(body, tmp)
            tmp.close()
            args += ["--input", tmp.name]
        r = subprocess.run(args, capture_output=True, text=True)
        if r.returncode != 0:
            if ok404 and ("404" in r.stderr or "409" in r.stderr or "empty" in r.stderr.lower()):
                return None
            raise RuntimeError(f"gh api {path} failed:\n{r.stderr[:2000]}")
        return json.loads(r.stdout) if r.stdout.strip() else {}
    finally:
        if tmp:
            os.unlink(tmp.name)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default="Ahmad0Maaitah/MANG3095")
    ap.add_argument("--branch", default="main")
    ap.add_argument("-m", "--message", default=None)
    ap.add_argument("--replace", action="store_true",
                    help="publish HEAD as a single parentless commit and force-update the branch (rewrites remote history)")
    a = ap.parse_args()

    # local state
    head = sh(["git", "rev-parse", "HEAD"]).strip()
    msg = a.message or sh(["git", "log", "-1", "--pretty=%B"]).strip()
    entries = []
    for line in sh(["git", "ls-tree", "-r", "HEAD"]).splitlines():
        meta, path = line.split("\t", 1)
        mode, typ, sha = meta.split()
        entries.append({"path": path, "mode": mode, "type": typ, "sha": sha})
    print(f"local HEAD {head[:10]} '{msg.splitlines()[0]}' - {len(entries)} files")

    # remote state
    ref = gh_api(f"repos/{a.repo}/git/ref/heads/{a.branch}", ok404=True)
    parent = ref["object"]["sha"] if ref else None
    remote_shas = set()
    if parent:
        rt = gh_api(f"repos/{a.repo}/git/trees/{parent}?recursive=1")
        remote_shas = {t["sha"] for t in rt.get("tree", []) if t["type"] == "blob"}
        print(f"remote head {parent[:10]} - {len(remote_shas)} known blobs")
    else:
        print("remote branch is empty")

    # upload missing blobs
    todo = [e for e in entries if e["sha"] not in remote_shas]
    print(f"uploading {len(todo)} new/changed blobs...")
    for i, e in enumerate(todo, 1):
        raw = subprocess.run(["git", "cat-file", "blob", e["sha"]], capture_output=True)
        if raw.returncode != 0:
            raise RuntimeError(f"git cat-file failed for {e['path']}")
        b64 = base64.b64encode(raw.stdout).decode()
        res = gh_api(f"repos/{a.repo}/git/blobs", "POST", {"content": b64, "encoding": "base64"})
        if res["sha"] != e["sha"]:
            raise RuntimeError(f"SHA mismatch for {e['path']}: {res['sha']} != {e['sha']}")
        if i % 10 == 0 or i == len(todo):
            print(f"  {i}/{len(todo)}")

    # tree + commit + ref (full tree => deletions handled)
    tree_body = {"tree": [{"path": e["path"], "mode": e["mode"], "type": "blob", "sha": e["sha"]}
                          for e in entries]}
    tree = gh_api(f"repos/{a.repo}/git/trees", "POST", tree_body)
    parents = [] if a.replace else ([parent] if parent else [])
    commit_body = {"message": msg, "tree": tree["sha"], "parents": parents}
    commit = gh_api(f"repos/{a.repo}/git/commits", "POST", commit_body)
    if ref:
        gh_api(f"repos/{a.repo}/git/refs/heads/{a.branch}", "PATCH",
               {"sha": commit["sha"], "force": bool(a.replace)})
    else:
        gh_api(f"repos/{a.repo}/git/refs", "POST",
               {"ref": f"refs/heads/{a.branch}", "sha": commit["sha"]})
    print(f"pushed: https://github.com/{a.repo}/commit/{commit['sha'][:10]}")

if __name__ == "__main__":
    main()
