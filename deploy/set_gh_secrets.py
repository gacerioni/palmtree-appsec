#!/usr/bin/env python3
"""Set DEPLOY_HOST / DEPLOY_USER / DEPLOY_SSH_KEY on a GitHub repo without printing values.
usage: DEPLOY_SSH_KEY="$(cat key)" GITHUB_TOKEN=... ./set_gh_secrets.py owner/repo host user
"""
import base64, json, os, sys, urllib.request
from nacl import encoding, public

repo, host, user = sys.argv[1:4]
tok = os.environ["GITHUB_TOKEN"]
hdr = {"Authorization": f"Bearer {tok}", "Accept": "application/vnd.github+json"}

def req(method, path, body=None):
    r = urllib.request.Request(f"https://api.github.com/repos/{repo}{path}", method=method, headers=hdr,
                               data=json.dumps(body).encode() if body else None)
    with urllib.request.urlopen(r) as resp:
        return json.loads(resp.read() or b"{}"), resp.status

pk, _ = req("GET", "/actions/secrets/public-key")
box = public.SealedBox(public.PublicKey(pk["key"].encode(), encoding.Base64Encoder()))
for name, val in {"DEPLOY_HOST": host, "DEPLOY_USER": user, "DEPLOY_SSH_KEY": os.environ["DEPLOY_SSH_KEY"]}.items():
    enc = base64.b64encode(box.encrypt(val.encode())).decode()
    _, st = req("PUT", f"/actions/secrets/{name}", {"encrypted_value": enc, "key_id": pk["key_id"]})
    print(name, st)
