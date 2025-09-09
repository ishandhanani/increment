"""
Email digest generation for Inboxy
"""

import os
import smtplib
from datetime import datetime, timedelta
from typing import List, Dict, Optional, Tuple
from pathlib import Path
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

from jinja2 import Template
from rich.console import Console
from rich.table import Table
from rich.progress import Progress, SpinnerColumn, TextColumn

from .models import EmailAnalysis, EmailCategory, Priority
from .gmail import GmailClient
from .ai import EmailAI

console = Console()

# HTML template for digest
HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; line-height: 1.6; }
        h1 { color: #111; font-size: 24px; margin-bottom: 20px; }
        h2 { color: #111; font-size: 18px; margin-top: 30px; border-bottom: 2px solid #ef4444; padding-bottom: 5px; }
        
        .stats-row { display: flex; gap: 20px; margin: 20px 0; }
        .stat-box { flex: 1; background: #f3f4f6; padding: 15px; border-radius: 8px; text-align: center; }
        .stat-number { font-size: 28px; font-weight: bold; color: #111; }
        .stat-label { color: #6b7280; font-size: 14px; }
        
        .urgent-section { background: #fef2f2; border: 2px solid #ef4444; border-radius: 8px; padding: 15px; margin: 20px 0; }
        .urgent-item { background: white; border-left: 4px solid #dc2626; padding: 12px; margin: 10px 0; border-radius: 4px; }
        .urgent-header { color: #dc2626; font-weight: bold; margin-bottom: 5px; }
        .email-from { color: #6b7280; font-size: 14px; }
        .email-summary { color: #374151; margin: 5px 0; }
        .email-action { background: #fef3c7; padding: 5px 8px; border-radius: 3px; margin: 5px 0; font-size: 14px; }
        
        .delete-section { background: #f9fafb; border: 1px solid #d1d5db; border-radius: 8px; padding: 15px; margin: 20px 0; }
        .delete-item { background: white; padding: 8px; margin: 5px 0; border-left: 3px solid #6b7280; }
        .delete-command { font-family: 'Courier New', monospace; background: #1f2937; color: #10b981; padding: 10px; border-radius: 4px; margin: 10px 0; font-size: 13px; }
        
        .tag { display: inline-block; padding: 2px 6px; border-radius: 3px; font-size: 11px; margin-left: 5px; }
        .tag-urgent { background: #ef4444; color: white; }
        .tag-meeting { background: #8b5cf6; color: white; }
    </style>
</head>
<body>
    <h1>🔴 Morning Priority Report - {{ date }}</h1>
    <p style="color: #6b7280; font-size: 14px;">Click any email subject to open in Gmail</p>
    
    <div class="stats-row">
        <div class="stat-box">
            <div class="stat-number">{{ urgent_count }}</div>
            <div class="stat-label">URGENT</div>
        </div>
        <div class="stat-box">
            <div class="stat-number">{{ action_count }}</div>
            <div class="stat-label">Need Response</div>
        </div>
        <div class="stat-box">
            <div class="stat-number">{{ delete_count }}</div>
            <div class="stat-label">Can Delete</div>
        </div>
        <div class="stat-box">
            <div class="stat-number">{{ total_count }}</div>
            <div class="stat-label">Total</div>
        </div>
    </div>
    
    {% if urgent_items %}
    <div class="urgent-section">
        <h2 style="color: #dc2626; margin-top: 0;">🔴 URGENT - Respond Before Starting Your Day</h2>
        {% for item in urgent_items %}
        <div class="urgent-item">
            <div class="urgent-header">
                #{{ loop.index }}. <a href="{{ item.gmail_link }}" target="_blank" style="color: #dc2626; text-decoration: none;">{{ item.subject }}</a>
                {% if item.is_meeting %}<span class="tag tag-meeting">MEETING</span>{% endif %}
            </div>
            <div class="email-from">From: {{ item.sender }} • {{ item.date }} • <a href="{{ item.gmail_link }}" target="_blank" style="color: #6b7280; font-size: 12px;">🔗 Open in Gmail</a></div>
            <div class="email-summary">{{ item.summary }}</div>
            {% if item.action_needed %}
            <div class="email-action">⚡ Action: {{ item.action_needed }}</div>
            {% endif %}
        </div>
        {% endfor %}
    </div>
    {% endif %}
    
    {% if delete_groups %}
    <div class="delete-section">
        <h2 style="margin-top: 0;">🗑️ Noise to Remove ({{ delete_count }} emails)</h2>
        {% for group in delete_groups %}
        <div style="margin: 15px 0;">
            <h3>{{ group.name }} ({{ group.count }} emails)</h3>
            {% for email in group.samples[:3] %}
            <div class="delete-item">
                • <a href="{{ email.gmail_link }}" target="_blank" style="color: inherit; text-decoration: none;">{{ email.subject }}</a> ({{ email.date }})
            </div>
            {% endfor %}
            <div class="delete-command">💻 python inboxy.py preview --query "{{ group.query }}" --delete</div>
        </div>
        {% endfor %}
    </div>
    {% endif %}
</body>
</html>
"""


class DigestGenerator:
    """Generate email digests"""
    
    def __init__(self):
        self.gmail = GmailClient()
        self.ai = EmailAI(self.gmail)
        self.output_dir = Path("digests")
        self.output_dir.mkdir(exist_ok=True)
    
    def generate(self, days: int = 1) -> Tuple[str, str]:
        """Generate digest for the specified number of days"""
        console.print(f"📅 Generating {days}-day digest...\n")
        
        # Fetch and analyze emails
        since_date = (datetime.now() - timedelta(days=days)).strftime("%Y/%m/%d")
        query = f"in:inbox after:{since_date}"
        
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            console=console,
            transient=True
        ) as progress:
            task = progress.add_task(f"📧 Analyzing emails since {since_date}...", total=None)
            analyses = self.ai.get_inbox_summary(query, limit=100)
            progress.update(task, completed=True)
        
        if not analyses:
            console.print("[yellow]No emails found for digest[/yellow]")
            return "", ""
        
        # Prepare template data
        data = self._prepare_data(analyses)
        
        # Generate HTML
        html_content = Template(HTML_TEMPLATE).render(**data)
        
        # Generate markdown
        md_content = self._generate_markdown(data)
        
        # Save files
        date_str = datetime.now().strftime("%Y%m%d")
        html_path = self.output_dir / f"digest_{date_str}.html"
        md_path = self.output_dir / f"digest_{date_str}.md"
        
        with open(html_path, "w") as f:
            f.write(html_content)
        
        with open(md_path, "w") as f:
            f.write(md_content)
        
        # Show summary stats
        self._show_stats(data)
        
        console.print(f"\n✅ Digest saved to: [green]{html_path}[/green]")
        
        return html_content, md_content
    
    def _prepare_data(self, analyses: List[EmailAnalysis]) -> Dict:
        """Prepare data for template"""
        data = {
            "date": datetime.now().strftime("%A, %B %d, %Y"),
            "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "total_count": len(analyses),
            "urgent_count": 0,
            "action_count": 0,
            "delete_count": 0,
            "urgent_items": [],
            "delete_groups": []
        }
        
        # Find urgent items
        for a in sorted(analyses, key=lambda x: x.priority.value, reverse=True):
            if a.priority.value >= 4 or a.category == EmailCategory.ACTION_REQUIRED:
                data["urgent_count"] += 1
                data["urgent_items"].append({
                    "subject": a.subject[:100],
                    "sender": a.sender.replace('<', '').replace('>', '').strip(),
                    "date": a.date.split(',')[0] if ',' in a.date else a.date[:20],
                    "summary": a.summary,
                    "action_needed": a.action_needed,
                    "gmail_link": f"https://mail.google.com/mail/u/0/#inbox/{a.message_id}",
                    "is_meeting": a.calendar_event is not None
                })
                
                if len(data["urgent_items"]) >= 5:
                    break
        
        # Count action required
        data["action_count"] = len([a for a in analyses if a.category == EmailCategory.ACTION_REQUIRED])
        
        # Find deletable emails
        deletable = []
        for a in analyses:
            if a.category in [EmailCategory.NEWSLETTER, EmailCategory.PROMOTION, EmailCategory.SOCIAL, EmailCategory.AUTO_DELETE]:
                deletable.append(a)
        
        data["delete_count"] = len(deletable)
        
        # Group deletable by sender domain
        sender_groups = {}
        for email in deletable:
            sender = email.sender
            if '@' in sender:
                if '<' in sender:
                    sender = sender.split('<')[1].split('>')[0]
                domain = sender.split('@')[1]
            else:
                domain = "unknown"
            
            if domain not in sender_groups:
                sender_groups[domain] = []
            sender_groups[domain].append(email)
        
        # Create delete groups
        for domain, emails in sorted(sender_groups.items(), key=lambda x: len(x[1]), reverse=True)[:3]:
            if len(emails) >= 2:
                data["delete_groups"].append({
                    "name": f"From {domain}",
                    "count": len(emails),
                    "query": f"from:@{domain}",
                    "samples": [{
                        "subject": e.subject[:50],
                        "date": e.date.split(',')[0] if ',' in e.date else e.date[:15],
                        "gmail_link": f"https://mail.google.com/mail/u/0/#inbox/{e.message_id}"
                    } for e in emails[:3]]
                })
        
        return data
    
    def _generate_markdown(self, data: Dict) -> str:
        """Generate markdown version"""
        lines = [
            f"# 🔴 Morning Priority Report - {data['date']}",
            "",
            f"**URGENT:** {data['urgent_count']} | **Action:** {data['action_count']} | **Delete:** {data['delete_count']} | **Total:** {data['total_count']}",
            ""
        ]
        
        if data["urgent_items"]:
            lines.append("## 🔴 URGENT Items\n")
            for i, item in enumerate(data["urgent_items"], 1):
                lines.append(f"### {i}. {item['subject']}")
                lines.append(f"From: {item['sender']} • {item['date']}")
                lines.append(f"[🔗 Open in Gmail]({item['gmail_link']})")
                lines.append(f"> {item['summary']}")
                if item.get("action_needed"):
                    lines.append(f"**⚡ Action:** {item['action_needed']}")
                lines.append("")
        
        return "\n".join(lines)
    
    def _show_stats(self, data: Dict):
        """Show summary statistics"""
        table = Table(title="📊 Digest Summary", show_header=False)
        table.add_column("Metric", style="cyan")
        table.add_column("Count", style="green")
        
        table.add_row("Total Emails", str(data["total_count"]))
        table.add_row("Urgent Items", str(data["urgent_count"]))
        table.add_row("Need Response", str(data["action_count"]))
        table.add_row("Can Delete", str(data["delete_count"]))
        
        console.print(table)
    
    def send(self, html_content: str, recipient: Optional[str] = None):
        """Send digest via email"""
        recipient = recipient or os.getenv("DIGEST_RECIPIENT_EMAIL")
        if not recipient:
            console.print("[yellow]No recipient email configured[/yellow]")
            return
        
        smtp_user = os.getenv("SMTP_USER")
        smtp_password = os.getenv("SMTP_PASSWORD")
        
        if not all([smtp_user, smtp_password]):
            console.print("[yellow]SMTP not configured[/yellow]")
            return
        
        msg = MIMEMultipart("alternative")
        msg["Subject"] = f"Morning Priority Report - {datetime.now().strftime('%B %d')}"
        msg["From"] = smtp_user
        msg["To"] = recipient
        
        msg.attach(MIMEText(html_content, "html"))
        
        try:
            with Progress(
                SpinnerColumn(),
                TextColumn("[progress.description]{task.description}"),
                console=console,
                transient=True
            ) as progress:
                task = progress.add_task(f"📮 Sending to {recipient}...", total=None)
                
                with smtplib.SMTP("smtp.gmail.com", 587) as server:
                    server.starttls()
                    server.login(smtp_user, smtp_password)
                    server.send_message(msg)
                
                progress.update(task, completed=True)
            
            console.print(f"[green]✅ Digest sent to {recipient}[/green]")
        except Exception as e:
            console.print(f"[red]❌ Failed to send: {e}[/red]")