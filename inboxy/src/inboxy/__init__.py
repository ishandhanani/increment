"""
Inboxy - AI-powered Gmail client for the command line
"""

from .models import EmailCategory, Priority, EmailAnalysis
from .gmail import GmailClient  
from .ai import EmailAI
from .digest import DigestGenerator
from .cli import main

__version__ = "1.0.0"
__all__ = [
    "EmailCategory",
    "Priority", 
    "EmailAnalysis",
    "GmailClient",
    "EmailAI",
    "DigestGenerator",
    "main"
]