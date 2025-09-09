"""
Gmail API client for Inboxy
"""

import os
import json
import hashlib
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Optional

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn

console = Console()

# Gmail API scope
SCOPES = ["https://mail.google.com/"]


class GmailClient:
    """Gmail API client with caching support"""
    
    def __init__(self, cache_ttl: int = 3600):
        self.service = self._get_gmail_service()
        self.cache_dir = Path(".cache")
        self.cache_dir.mkdir(exist_ok=True)
        self.cache_ttl = cache_ttl
    
    def _get_gmail_service(self):
        """Initialize Gmail API service"""
        creds = None
        if os.path.exists("token.json"):
            creds = Credentials.from_authorized_user_file("token.json", SCOPES)
        
        if not creds or not creds.valid:
            if creds and creds.expired and creds.refresh_token:
                creds.refresh(Request())
            else:
                if not os.path.exists("credentials.json"):
                    console.print("[red]Error: credentials.json not found![/red]")
                    console.print("Please download from Google Cloud Console")
                    raise FileNotFoundError("credentials.json not found")
                
                flow = InstalledAppFlow.from_client_secrets_file("credentials.json", SCOPES)
                creds = flow.run_local_server(port=0)
            
            with open("token.json", "w") as token:
                token.write(creds.to_json())
        
        return build("gmail", "v1", credentials=creds)
    
    def _get_cache_key(self, query: str, max_results: int) -> str:
        """Generate cache key for a query"""
        key = f"{query}_{max_results}"
        return hashlib.md5(key.encode()).hexdigest()
    
    def _get_cached_emails(self, cache_key: str) -> Optional[List[Dict]]:
        """Get emails from cache if fresh"""
        cache_file = self.cache_dir / f"emails_{cache_key}.json"
        if cache_file.exists():
            age = datetime.now().timestamp() - cache_file.stat().st_mtime
            if age < self.cache_ttl:
                with open(cache_file, 'r') as f:
                    return json.load(f)
        return None
    
    def _cache_emails(self, cache_key: str, emails: List[Dict]):
        """Cache emails to disk"""
        cache_file = self.cache_dir / f"emails_{cache_key}.json"
        with open(cache_file, 'w') as f:
            json.dump(emails, f)
    
    def get_emails(self, query: str = "in:inbox", max_results: int = 50, use_cache: bool = True) -> List[Dict]:
        """Fetch emails from Gmail with caching"""
        # Check cache first
        if use_cache:
            cache_key = self._get_cache_key(query, max_results)
            cached = self._get_cached_emails(cache_key)
            if cached:
                console.print("[dim]Using cached emails...[/dim]")
                return cached
        
        try:
            results = self.service.users().messages().list(
                userId="me",
                q=query,
                maxResults=max_results
            ).execute()
            
            messages = results.get("messages", [])
            
            if not messages:
                return []
            
            # Fetch full message details
            full_messages = []
            with Progress(
                SpinnerColumn(),
                TextColumn("[progress.description]{task.description}"),
                BarColumn(),
                TextColumn("[progress.percentage]{task.percentage:>3.0f}%"),
                console=console,
                transient=True
            ) as progress:
                task = progress.add_task("Fetching emails...", total=len(messages))
                
                for i, msg in enumerate(messages):
                    try:
                        full_msg = self.service.users().messages().get(
                            userId="me",
                            id=msg["id"],
                            format="full"
                        ).execute()
                        full_messages.append(full_msg)
                        progress.update(task, completed=i+1)
                    except HttpError as e:
                        console.print(f"[yellow]Failed to fetch {msg['id']}: {e}[/yellow]")
                        progress.update(task, completed=i+1)
            
            # Cache the results
            if use_cache:
                cache_key = self._get_cache_key(query, max_results)
                self._cache_emails(cache_key, full_messages)
            
            return full_messages
            
        except HttpError as e:
            console.print(f"[red]Gmail API error: {e}[/red]")
            return []
    
    def delete_email(self, message_id: str):
        """Delete an email permanently"""
        try:
            self.service.users().messages().delete(
                userId="me",
                id=message_id
            ).execute()
            return True
        except HttpError as e:
            console.print(f"[red]Failed to delete {message_id}: {e}[/red]")
            return False
    
    def archive_email(self, message_id: str):
        """Archive an email (remove from inbox)"""
        try:
            self.service.users().messages().modify(
                userId="me",
                id=message_id,
                body={'removeLabelIds': ['INBOX']}
            ).execute()
            return True
        except HttpError as e:
            console.print(f"[red]Failed to archive {message_id}: {e}[/red]")
            return False
    
    def get_headers(self, message: Dict) -> Dict[str, str]:
        """Extract email headers"""
        headers = {}
        for header in message.get("payload", {}).get("headers", []):
            headers[header["name"].lower()] = header["value"]
        return headers
    
    def get_body(self, message: Dict) -> str:
        """Extract email body text"""
        import base64
        
        def extract_parts(payload):
            body = ""
            if "parts" in payload:
                for part in payload["parts"]:
                    if part["mimeType"] == "text/plain":
                        data = part["body"].get("data", "")
                        if data:
                            body += base64.urlsafe_b64decode(data).decode("utf-8", errors="ignore")
                    elif "parts" in part:
                        body += extract_parts(part)
            elif payload.get("body", {}).get("data"):
                body = base64.urlsafe_b64decode(payload["body"]["data"]).decode("utf-8", errors="ignore")
            return body
        
        return extract_parts(message.get("payload", {}))[:3000]  # Limit to 3000 chars
    
    def clear_cache(self):
        """Clear all cached emails"""
        import shutil
        if self.cache_dir.exists():
            shutil.rmtree(self.cache_dir)
            self.cache_dir.mkdir()
            console.print("[dim]Cache cleared[/dim]")