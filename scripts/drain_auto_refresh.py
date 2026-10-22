import json
import sys
import urllib.error
import urllib.request
import urllib.parse
import time

with open("scripts/.cluster_creds.json", "r") as f:
    creds = json.load(f)

token_url = creds["token_url"]
client_id = creds["client_id"]
client_secret = creds["client_secret"]
url = token_url.split("/realms/")[0].rstrip("/")
realm = "legacyvault"

access_token = None
token_expires_at = 0

def get_token():
    global access_token, token_expires_at
    if access_token and time.time() < token_expires_at - 10:
        return access_token
    
    data = urllib.parse.urlencode({
        "grant_type": "client_credentials",
        "client_id": client_id,
        "client_secret": client_secret
    }).encode("utf-8")
    
    req = urllib.request.Request(token_url, data=data, method="POST")
    with urllib.request.urlopen(req) as resp:
        res = json.loads(resp.read().decode("utf-8"))
        access_token = res["access_token"]
        expires_in = res.get("expires_in", 60)
        token_expires_at = time.time() + expires_in
        return access_token

base = f"{url}/admin/realms/{realm}/iga/change-requests"

def call(path, method="GET", body=None):
    token = get_token()
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    req = urllib.request.Request(path, data=body, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read().decode("utf-8")
            return r.status, (json.loads(raw) if raw.strip() else None)
    except urllib.error.HTTPError as e:
        if e.code == 401:
            # Force refresh token and retry once
            global access_token
            access_token = None
            token = get_token()
            headers["Authorization"] = f"Bearer {token}"
            req2 = urllib.request.Request(path, data=body, method=method, headers=headers)
            try:
                with urllib.request.urlopen(req2) as r2:
                    raw2 = r2.read().decode("utf-8")
                    return r2.status, (json.loads(raw2) if raw2.strip() else None)
            except urllib.error.HTTPError as e2:
                return e2.code, e2.read().decode("utf-8")[:200]
        return e.code, e.read().decode("utf-8")[:200]
    except Exception as e:
        return "ERR", str(e)[:200]

NEVER_DRAIN = {"DISABLE_IGA", "DELETE_REALM", "OFFBOARD_REALM"}

def pending():
    status, data = call(f"{base}?status=PENDING")
    if status != 200 or data is None:
        print(f"   could not list change requests: {status} {data}")
        return []
    if isinstance(data, dict):
        items = [(k, v.get("actionType", "?")) for k, v in data.items()]
    else:
        items = [(c.get("id"), c.get("actionType", "?")) for c in data if c.get("id")]
    kept = [(cid, action) for cid, action in items if action not in NEVER_DRAIN]
    return kept

print(f"==> Draining IGA change requests for realm '{realm}' with auto-refresh...")
total = 0

for round_no in range(1, 15):
    items = pending()
    if not items:
        print(f"   round {round_no}: queue empty!")
        break

    print(f"--- Round {round_no}: {len(items)} items pending ---")
    progressed = False
    for cid, action in items:
        a_status, a_body = call(f"{base}/{cid}/authorize", "POST", b"{}")
        c_status, c_body = call(f"{base}/{cid}/commit", "POST", b"{}")
        ok = c_status in (200, 204)
        if ok:
            progressed = True
            total += 1
            print(f"   [OK] {action:<26} {str(cid)[:8]} committed")
        elif c_status == 412:
            print(f"   [WAIT] {action:<24} {str(cid)[:8]} 412: dependsOn not yet ready")
        else:
            print(f"   [FAIL] {action:<24} {str(cid)[:8]} auth={a_status} commit={c_status}: {c_body}")

    if not progressed:
        print(f"   round {round_no}: nothing committed; stopping to avoid spin.")
        break

print(f"==> Total committed across all rounds: {total}")
