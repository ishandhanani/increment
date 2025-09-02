# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "google-api-python-client",
#     "google-auth-httplib2",
#     "google-auth-oauthlib",
#     "textual",
# ]
# ///

from __future__ import annotations
import os
import sys
import argparse
import time
from typing import List, Dict, Tuple, Iterable
from collections import Counter, defaultdict

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

# Full Gmail scope so we can delete permanently & manage filters
SCOPES = ["https://mail.google.com/"]

# ---------- Auth / Service ----------

def get_service(prompt_consent: bool = False):
    creds = None
    if os.path.exists("token.json"):
        creds = Credentials.from_authorized_user_file("token.json", SCOPES)

    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file("credentials.json", SCOPES)
            creds = flow.run_local_server(port=0, prompt="consent" if prompt_consent else "auto")
        with open("token.json", "w") as token:
            token.write(creds.to_json())

    print("Active scopes:", ", ".join(creds.scopes or []))
    return build("gmail", "v1", credentials=creds), creds

# ---------- Utilities ----------

def get_label_map(service) -> Dict[str, str]:
    labels = service.users().labels().list(userId="me").execute().get("labels", [])
    return {l["name"]: l["id"] for l in labels}

def inbox_stats(service) -> Tuple[int, int]:
    # Label list includes counts for system labels
    labels = service.users().labels().list(userId="me").execute().get("labels", [])
    inbox_total = inbox_unread = 0
    for l in labels:
        if l["name"] == "INBOX":
            inbox_total = l.get("messagesTotal", 0)
            inbox_unread = l.get("messagesUnread", 0)
            break
    return inbox_total, inbox_unread

def list_message_ids(service, q: str = "", label_ids: List[str] | None = None, limit: int | None = None) -> List[str]:
    ids = []
    page_token = None
    while True:
        call = service.users().messages().list(
            userId="me",
            q=q or None,
            labelIds=label_ids or None,
            maxResults=500,
            pageToken=page_token
        )
        res = call.execute()
        msgs = res.get("messages", [])
        ids.extend(m["id"] for m in msgs)
        if limit and len(ids) >= limit:
            return ids[:limit]
        page_token = res.get("nextPageToken")
        if not page_token:
            break
    return ids

def batch_get(service, ids: List[str], payload: str = "metadata", metadata_headers: List[str] | None = None):
    # payload: "metadata" or "full"
    # For speed we read metadata (From, Subject, Date, List-Unsubscribe)
    items = []
    for i in range(0, len(ids), 100):  # respectful chunk
        chunk = ids[i:i+100]
        for mid in chunk:
            try:
                msg = service.users().messages().get(
                    userId="me",
                    id=mid,
                    format=payload,
                    metadataHeaders=(metadata_headers or ["From", "Subject", "Date", "List-Unsubscribe"])
                ).execute()
                items.append(msg)
            except HttpError as e:
                print(f"warn: get {mid} -> {e}")
        # tiny pause to be gentle
        time.sleep(0.05)
    return items

def header(hs: List[Dict[str, str]], name: str) -> str | None:
    for h in hs:
        if h.get("name", "").lower() == name.lower():
            return h.get("value")
    return None

def domain_from_from_header(val: str | None) -> str | None:
    # Extract domain from 'From: "Name" <user@domain>'
    if not val: return None
    import re
    m = re.search(r"<([^>]+)>", val)
    email = m.group(1) if m else val
    m2 = re.search(r"@([A-Za-z0-9\.-]+)", email)
    return m2.group(1).lower() if m2 else None

# ---------- Discovery ----------

def discover(service):
    total, unread = inbox_stats(service)
    print(f"📬 INBOX: {total} total, {unread} unread")

    # 1) Top senders in INBOX (last 6 months)
    print("\n— Top senders in INBOX (last 6 months) —")
    q_recent_inbox = 'in:inbox newer_than:6m'
    ids = list_message_ids(service, q=q_recent_inbox, limit=3000)  # cap for speed
    msgs = batch_get(service, ids)
    sender_counts = Counter()
    domain_counts = Counter()
    newsletter_count = 0
    for m in msgs:
        hs = m.get("payload", {}).get("headers", [])
        frm = header(hs, "From")
        dom = domain_from_from_header(frm)
        if frm: sender_counts[frm] += 1
        if dom: domain_counts[dom] += 1
        if header(hs, "List-Unsubscribe"):
            newsletter_count += 1

    for s, c in sender_counts.most_common(15):
        print(f"{c:5d}  {s}")
    print("\nTop domains:")
    for d, c in domain_counts.most_common(10):
        print(f"{c:5d}  {d}")
    print(f"\nNewsletters (List-Unsubscribe detected) in sample: {newsletter_count}")

    # 2) Category buckets
    for cat in ["promotions", "social", "updates", "forums"]:
        q = f"in:inbox category:{cat}"
        cnt = len(list_message_ids(service, q=q, limit=5000))
        print(f"Category {cat:10s}: {cnt}")

    # 3) Old mail buckets
    for age in ["1y", "6m", "3m"]:
        q = f"in:inbox older_than:{age}"
        cnt = len(list_message_ids(service, q=q, limit=10000))
        print(f"Older than {age:>3}: {cnt}")

    # 4) Large items
    big_cnt = len(list_message_ids(service, q="in:inbox larger:5M", limit=5000))
    attach_cnt = len(list_message_ids(service, q="in:inbox has:attachment", limit=5000))
    print(f"Larger than 5MB: {big_cnt}")
    print(f"Has attachments : {attach_cnt}")

    print("\nTip: use `preview --query 'in:inbox category:promotions older_than:6m'` next.")

# ---------- Preview / Actions ----------

def preview(service, query: str, sample: int = 10, show_headers: bool = True):
    ids = list_message_ids(service, q=query)
    print(f"🔎 Query: {query}")
    print(f"Found: {len(ids)} messages")
    if not ids:
        return
    msgs = batch_get(service, ids[:sample])
    print(f"\nSample {min(sample, len(ids))} messages:")
    for m in msgs:
        hs = m.get("payload", {}).get("headers", [])
        frm = header(hs, "From") or "(no From)"
        sub = header(hs, "Subject") or "(no Subject)"
        date = header(hs, "Date") or "(no Date)"
        print(f"• {date} | {frm} | {sub}")

def _chunked(iterable: List[str], n: int = 500) -> Iterable[List[str]]:
    for i in range(0, len(iterable), n):
        yield iterable[i:i+n]

def delete_by_query(service, query: str):
    ids = list_message_ids(service, q=query)
    print(f"🗑 Deleting {len(ids)} messages for query: {query}")
    if not ids:
        return
    confirm = input("Type 'yes' to permanently delete (bypasses Trash): ").strip().lower()
    if confirm != "yes":
        print("Aborted.")
        return
    for batch in _chunked(ids, 500):
        service.users().messages().batchDelete(userId="me", body={"ids": batch}).execute()
        print(f"Deleted batch of {len(batch)} (progress {min(len(ids), ids.index(batch[-1])+1)}/{len(ids)})")
    t,u = inbox_stats(service)
    print(f"✅ Done. INBOX now: {t} total, {u} unread")

def archive_by_query(service, query: str):
    # Remove INBOX label (archive)
    ids = list_message_ids(service, q=query)
    print(f"🗃 Archiving {len(ids)} messages for query: {query}")
    if not ids:
        return
    confirm = input("Type 'yes' to archive (remove from INBOX): ").strip().lower()
    if confirm != "yes":
        print("Aborted.")
        return
    label_map = get_label_map(service)
    inbox_id = label_map.get("INBOX")
    for batch in _chunked(ids, 500):
        service.users().messages().batchModify(
            userId="me",
            body={"ids": batch, "removeLabelIds": [inbox_id], "addLabelIds": []}
        ).execute()
        print(f"Archived batch of {len(batch)}")
    t,u = inbox_stats(service)
    print(f"✅ Done. INBOX now: {t} total, {u} unread")

# ---------- Filters (future-proofing) ----------

def create_filter(service, from_addr: str, action: str):
    """
    action: 'delete' or 'archive'
    """
    label_map = get_label_map(service)
    inbox_id = label_map.get("INBOX")
    body = {
        "criteria": {"from": from_addr},
        "action": {}
    }
    if action == "delete":
        body["action"]["addLabelIds"] = ["TRASH"]
    elif action == "archive":
        body["action"]["removeLabelIds"] = [inbox_id]
    else:
        raise ValueError("action must be 'delete' or 'archive'")
    res = service.users().settings().filters().create(userId="me", body=body).execute()
    print(f"Created filter {res.get('id')} for from:{from_addr} -> {action}")

# ---------- CLI ----------

def main():
    parser = argparse.ArgumentParser(description="Inbox cleanup helper")
    sub = parser.add_subparsers(dest="cmd", required=True)

    sub.add_parser("discover", help="Show stats, top senders, buckets")

    p_prev = sub.add_parser("preview", help="Preview a Gmail query")
    p_prev.add_argument("--query", required=True)
    p_prev.add_argument("--sample", type=int, default=10)

    p_del = sub.add_parser("delete", help="Delete (permanent) by query")
    p_del.add_argument("--query", required=True)

    p_arc = sub.add_parser("archive", help="Archive (remove INBOX) by query")
    p_arc.add_argument("--query", required=True)

    p_flt = sub.add_parser("filter", help="Create filter for a sender")
    p_flt.add_argument("--from", dest="from_addr", required=True)
    p_flt.add_argument("--action", choices=["delete","archive"], required=True)

    args = parser.parse_args()
    service, _ = get_service()

    if args.cmd == "discover":
        total, unread = inbox_stats(service)
        print(f"📬 INBOX: {total} total, {unread} unread")
        discover(service)

    elif args.cmd == "preview":
        total, unread = inbox_stats(service)
        print(f"📬 INBOX: {total} total, {unread} unread")
        preview(service, args.query, args.sample)

    elif args.cmd == "delete":
        total, unread = inbox_stats(service)
        print(f"📬 INBOX: {total} total, {unread} unread")
        preview(service, args.query, sample=10)
        delete_by_query(service, args.query)

    elif args.cmd == "archive":
        total, unread = inbox_stats(service)
        print(f"📬 INBOX: {total} total, {unread} unread")
        preview(service, args.query, sample=10)
        archive_by_query(service, args.query)

    elif args.cmd == "filter":
        create_filter(service, args.from_addr, args.action)

if __name__ == "__main__":
    main()

