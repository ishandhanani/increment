#!/usr/bin/env python3
"""
Inboxy CLI interface
"""

import sys
import time
from datetime import datetime

import click
from rich.console import Console
from rich.table import Table
from rich.progress import Progress, SpinnerColumn, TextColumn
from dotenv import load_dotenv

from .gmail import GmailClient
from .ai import EmailAI
from .digest import DigestGenerator

# Load environment
load_dotenv()
console = Console()


@click.group(invoke_without_command=True)
@click.pass_context
def cli(ctx):
    """Inboxy - AI-powered Gmail client
    
    Commands:
      (default)  Show inbox
      preview    Preview and manage emails  
      digest     Generate AI digest
    """
    if ctx.invoked_subcommand is None:
        show_inbox()


def show_inbox():
    """Default view - show inbox like Gmail"""
    gmail = GmailClient()
    
    console.print("\n[bold]📬 Inbox[/bold]\n")
    
    # Get recent emails
    messages = gmail.get_emails("in:inbox", max_results=50)
    
    if not messages:
        console.print("[dim]No emails in inbox[/dim]")
        return
    
    # Create table
    table = Table(show_header=True, header_style="bold")
    table.add_column("", width=2)  # Priority indicator
    table.add_column("From", width=25)
    table.add_column("Subject", width=45)
    table.add_column("Date", width=12)
    
    console.print("[dim]Loading inbox...[/dim]\n")
    
    for msg in messages[:20]:
        headers = gmail.get_headers(msg)
        
        # Extract fields
        sender = headers.get('from', 'Unknown')
        if '<' in sender:
            sender = sender.split('<')[0].strip().strip('"')
        sender = sender[:25]
        
        subject = headers.get('subject', 'No subject')[:45]
        
        # Parse date
        date_str = headers.get('date', '')
        try:
            if datetime.now().strftime('%d %b') in date_str:
                date_display = "Today"
            else:
                date_parts = date_str.split(',')[-1].strip().split()[:3]
                if len(date_parts) >= 2:
                    date_display = f"{date_parts[0]} {date_parts[1]}"
                else:
                    date_display = date_str[:12]
        except:
            date_display = date_str[:12]
        
        # Priority indicator
        priority = ""
        if any(word in subject.lower() for word in ['urgent', 'important', 'asap']):
            priority = "🔴"
        elif any(word in sender.lower() for word in ['newsletter', 'noreply']):
            priority = "📰"
        
        table.add_row(priority, sender, subject, date_display)
    
    console.print(table)
    
    if len(messages) > 20:
        console.print(f"\n[dim]... and {len(messages) - 20} more[/dim]")
    
    console.print("\n[dim]Commands: preview, digest[/dim]")


# Common cleanup presets
CLEANUP_PRESETS = {
    # Aliases for Gmail categories
    'promotions': 'category:promotions',
    'promo': 'category:promotions',
    'social': 'category:social',
    'updates': 'category:updates',
    'forums': 'category:forums',
    'newsletters': 'list:*',  # Has List-Unsubscribe header
    
    # Time-based cleanup
    'old-promotions': 'category:promotions older_than:7d',
    'old-social': 'category:social older_than:30d',
    'old-updates': 'category:updates older_than:14d',
    'old-newsletters': 'list:* older_than:14d',
    
    # Common noise patterns
    'notifications': 'from:(noreply OR no-reply OR notifications OR alerts)',
    'automated': 'from:(automated OR system OR mailer-daemon)',
    'unread-old': 'is:unread older_than:30d',
    
    # Bulk cleanup
    'noise': '(category:promotions OR category:social) older_than:7d',
    'old-noise': '(category:promotions OR category:social OR category:updates) older_than:30d',
    'ancient': 'older_than:1y',
}

@cli.command()
@click.option('--query', default="in:inbox", help='Gmail query or preset (promotions, social, old-noise, etc)')
@click.option('--limit', default=20, help='Number of emails to show')
@click.option('--delete', is_flag=True, help='Delete matching emails')
@click.option('--archive', is_flag=True, help='Archive matching emails')
@click.option('--list-presets', is_flag=True, help='Show available cleanup presets')
def preview(query, limit, delete, archive, list_presets):
    """Preview emails matching a Gmail query or preset
    
    Examples:
        inboxy preview --query promotions           # All promotional emails
        inboxy preview --query old-promotions       # Promotions older than 7 days
        inboxy preview --query old-noise --delete   # Delete old promotional/social emails
        inboxy preview --query newsletters          # All newsletters (with unsubscribe)
        inboxy preview --list-presets              # Show all available presets
    """
    # Show presets if requested
    if list_presets:
        console.print("\n[bold]Available Cleanup Presets:[/bold]\n")
        
        table = Table(show_header=True, header_style="bold magenta")
        table.add_column("Preset", style="cyan", width=20)
        table.add_column("Gmail Query", style="green")
        table.add_column("Description", style="dim")
        
        descriptions = {
            'promotions': 'All promotional emails',
            'social': 'Social media notifications',
            'updates': 'Updates and notifications',
            'forums': 'Forum and mailing list emails',
            'newsletters': 'Emails with unsubscribe headers',
            'old-promotions': 'Promotions older than 7 days',
            'old-social': 'Social emails older than 30 days',
            'old-updates': 'Updates older than 14 days',
            'old-newsletters': 'Newsletters older than 14 days',
            'notifications': 'Automated notifications',
            'automated': 'System/automated emails',
            'unread-old': 'Unread emails older than 30 days',
            'noise': 'Promotions/social older than 7 days',
            'old-noise': 'All categories older than 30 days',
            'ancient': 'Emails older than 1 year',
        }
        
        for preset, gmail_query in CLEANUP_PRESETS.items():
            desc = descriptions.get(preset, '')
            table.add_row(preset, gmail_query[:50] + '...' if len(gmail_query) > 50 else gmail_query, desc)
        
        console.print(table)
        console.print("\n[dim]Use: inboxy preview --query [preset-name][/dim]")
        return
    
    gmail = GmailClient()
    
    # Check if query is a preset
    original_query = query
    if query.lower() in CLEANUP_PRESETS:
        query = CLEANUP_PRESETS[query.lower()]
        console.print(f"\n🔍 Using preset '[cyan]{original_query}[/cyan]'")
        console.print(f"   Gmail query: [green]{query}[/green]\n")
    else:
        console.print(f"\n🔍 Query: [cyan]{query}[/cyan]\n")
    
    # Fetch messages
    messages = gmail.get_emails(query, max_results=limit if not (delete or archive) else 500)
    
    if not messages:
        console.print("[green]No emails found[/green]")
        return
    
    console.print(f"Found [bold]{len(messages)}[/bold] emails\n")
    
    # Show preview table
    if not delete and not archive:
        table = Table(show_header=True)
        table.add_column("#", width=3)
        table.add_column("From", width=25)
        table.add_column("Subject", width=40)
        table.add_column("Date", width=12)
        
        for i, msg in enumerate(messages[:limit], 1):
            headers = gmail.get_headers(msg)
            
            sender = headers.get('from', 'Unknown')
            if '<' in sender:
                sender = sender.split('<')[0].strip().strip('"')
            sender = sender[:25]
            
            subject = headers.get('subject', 'No subject')[:40]
            date = headers.get('date', 'Unknown')[:12]
            
            table.add_row(str(i), sender, subject, date)
        
        console.print(table)
        
        if len(messages) > limit:
            console.print(f"\n[dim]Showing first {limit} of {len(messages)} total[/dim]")
    
    # Handle actions
    if delete:
        console.print(f"\n[red]⚠️  This will PERMANENTLY delete {len(messages)} emails[/red]")
        if click.confirm("Are you sure?"):
            with Progress(
                SpinnerColumn(),
                TextColumn("[progress.description]{task.description}"),
                console=console,
                transient=True
            ) as progress:
                task = progress.add_task("Deleting emails...", total=len(messages))
                
                for i, msg in enumerate(messages):
                    gmail.delete_email(msg['id'])
                    progress.update(task, advance=1)
                    time.sleep(0.05)  # Rate limiting
            
            console.print("[green]✅ Emails deleted[/green]")
    
    elif archive:
        if click.confirm(f"\n⚠️  Archive {len(messages)} emails?"):
            with Progress(
                SpinnerColumn(),
                TextColumn("[progress.description]{task.description}"),
                console=console,
                transient=True
            ) as progress:
                task = progress.add_task("Archiving emails...", total=len(messages))
                
                for i, msg in enumerate(messages):
                    gmail.archive_email(msg['id'])
                    progress.update(task, advance=1)
                    time.sleep(0.05)  # Rate limiting
            
            console.print("[green]✅ Emails archived[/green]")


@cli.command()
@click.option('--days', default=1, help='Days to look back')
@click.option('--send', is_flag=True, help='Email the digest')
@click.option('--fresh', is_flag=True, help='Skip cache, fetch fresh data')
def digest(days, send, fresh):
    """Generate AI-powered email digest"""
    if fresh:
        # Clear cache
        gmail = GmailClient()
        gmail.clear_cache()
    
    generator = DigestGenerator()
    html_content, md_content = generator.generate(days)
    
    if not html_content:
        return
    
    # Show summary
    lines = md_content.split('\n')
    for line in lines[2:10]:
        if line and not line.startswith('#'):
            console.print(line)
    
    if send:
        console.print("\n📮 Sending digest...")
        generator.send(html_content)


def main():
    """Main entry point for the CLI"""
    try:
        cli()
    except KeyboardInterrupt:
        console.print("\n[yellow]Interrupted[/yellow]")
        sys.exit(0)
    except Exception as e:
        console.print(f"\n[red]Error: {e}[/red]")
        sys.exit(1)