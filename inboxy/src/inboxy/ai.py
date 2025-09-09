"""
AI-powered email analysis for Inboxy
"""

import os
import json
import hashlib
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Optional
from collections import defaultdict

import openai
import instructor
from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn

from .models import (
    EmailAnalysis, EmailAnalysisResponse, EmailCategory, 
    Priority, CalendarEvent
)

console = Console()


class EmailAI:
    """AI-powered email analysis and processing"""
    
    def __init__(self, gmail_client):
        self.gmail = gmail_client
        self.ai_client = self._init_ai_client()
        self.cache_dir = Path(".cache")
        self.cache_dir.mkdir(exist_ok=True)
        self.cache_ttl = 3600  # 1 hour cache
        
        # Load important domains/contacts from env
        self.important_domains = self._load_important_domains()
        self.important_contacts = self._load_important_contacts()
    
    def _init_ai_client(self):
        """Initialize instructor client with OpenRouter"""
        api_key = os.getenv("OPENROUTER_API_KEY")
        if not api_key:
            console.print("[red]Error: OPENROUTER_API_KEY not set in .env[/red]")
            raise ValueError("OPENROUTER_API_KEY not set")
        
        base_client = openai.OpenAI(
            base_url="https://openrouter.ai/api/v1",
            api_key=api_key
        )
        return instructor.from_openai(base_client)
    
    def _load_important_domains(self) -> List[str]:
        """Load important domains from env"""
        domains = os.getenv("IMPORTANT_DOMAINS", "")
        return [d.strip() for d in domains.split(",") if d.strip()]
    
    def _load_important_contacts(self) -> List[str]:
        """Load VIP contacts from env"""
        contacts = os.getenv("VIP_CONTACTS", "")
        return [c.strip() for c in contacts.split(",") if c.strip()]
    
    def analyze_email(self, message: Dict) -> Optional[EmailAnalysis]:
        """Analyze a single email using AI"""
        headers = self.gmail.get_headers(message)
        body = self.gmail.get_body(message)
        
        # Build prompt
        prompt = self._build_analysis_prompt(headers, body)
        
        # Get AI analysis
        try:
            response = self.ai_client.chat.completions.create(
                model=os.getenv("AI_MODEL", "openai/gpt-4-turbo-preview"),
                messages=[
                    {"role": "system", "content": "You are an email assistant helping a busy professional manage their inbox."},
                    {"role": "user", "content": prompt}
                ],
                response_model=EmailAnalysisResponse,
                max_tokens=500
            )
            
            return EmailAnalysis(message["id"], headers, response)
            
        except Exception as e:
            console.print(f"[yellow]AI analysis failed: {e}[/yellow]")
            # Return basic analysis as fallback
            return EmailAnalysis(
                message["id"],
                headers,
                EmailAnalysisResponse(
                    category="fyi_review",
                    priority=1,
                    summary="Unable to analyze email",
                    key_points=[]
                )
            )
    
    def _build_analysis_prompt(self, headers: Dict[str, str], body: str) -> str:
        """Build prompt for AI analysis"""
        sender = headers.get("from", "Unknown")
        subject = headers.get("subject", "No subject")
        
        # Check if sender is important
        sender_domain = sender.split("@")[-1].replace(">", "") if "@" in sender else ""
        is_important = (
            sender_domain in self.important_domains or
            any(contact in sender for contact in self.important_contacts)
        )
        
        prompt = f"""Analyze this email and categorize it:

From: {sender}
Subject: {subject}
{"[IMPORTANT SENDER]" if is_important else ""}

Body (truncated):
{body[:2000]}

Categorize as one of:
- action_required: Needs a response or action
- calendar_event: Contains meeting/event information
- newsletter: Subscription/newsletter
- promotion: Marketing/sales
- social: Social network notification
- auto_delete: Spam or junk
- important: VIP or urgent
- fyi_review: Information only

Provide:
1. Priority (1-5, where 5 is most urgent)
2. Brief 1-2 sentence summary
3. What action is needed (if any)
4. Suggested response (if action required)
5. Calendar event details (if detected)
6. 2-3 key points"""
        
        return prompt
    
    def batch_analyze(self, messages: List[Dict], limit: int = 50) -> List[EmailAnalysis]:
        """Analyze multiple emails"""
        analyses = []
        messages_to_analyze = messages[:limit]
        
        # Check cache first
        cache_key = self._get_cache_key_for_batch(messages_to_analyze)
        cached = self._get_cached_analyses(cache_key)
        if cached:
            console.print("[dim]Using cached analysis...[/dim]")
            return cached
        
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            BarColumn(),
            TextColumn("[progress.percentage]{task.percentage:>3.0f}%"),
            console=console,
            transient=True
        ) as progress:
            task = progress.add_task("Analyzing with AI...", total=len(messages_to_analyze))
            
            for i, msg in enumerate(messages_to_analyze):
                try:
                    analysis = self.analyze_email(msg)
                    if analysis:
                        analyses.append(analysis)
                    progress.update(task, completed=i+1)
                except Exception as e:
                    console.print(f"[yellow]Failed to analyze: {e}[/yellow]")
                    progress.update(task, completed=i+1)
        
        # Cache the results
        if analyses:
            self._cache_analyses(cache_key, analyses)
        
        return analyses
    
    def _get_cache_key_for_batch(self, messages: List[Dict]) -> str:
        """Generate cache key for a batch of messages"""
        # Use first and last message IDs
        if messages:
            key = f"batch_{messages[0].get('id', '')}_{messages[-1].get('id', '')}_{len(messages)}"
            return hashlib.md5(key.encode()).hexdigest()
        return "empty"
    
    def _get_cached_analyses(self, cache_key: str) -> Optional[List[EmailAnalysis]]:
        """Get cached analyses"""
        cache_file = self.cache_dir / f"analyses_{cache_key}.json"
        if cache_file.exists():
            age = datetime.now().timestamp() - cache_file.stat().st_mtime
            if age < self.cache_ttl:
                with open(cache_file, 'r') as f:
                    data = json.load(f)
                    return [EmailAnalysis.from_dict(item) for item in data]
        return None
    
    def _cache_analyses(self, cache_key: str, analyses: List[EmailAnalysis]):
        """Cache analyses"""
        cache_file = self.cache_dir / f"analyses_{cache_key}.json"
        data = [a.to_dict() for a in analyses]
        with open(cache_file, 'w') as f:
            json.dump(data, f)
    
    def get_inbox_summary(self, query: str = "in:inbox newer_than:1d", limit: int = 30) -> List[EmailAnalysis]:
        """Get analyzed inbox summary"""
        emails = self.gmail.get_emails(query, limit)
        
        if not emails:
            console.print("[yellow]No emails found[/yellow]")
            return []
        
        console.print(f"\n📧 Found {len(emails)} emails\n")
        
        return self.batch_analyze(emails, limit)