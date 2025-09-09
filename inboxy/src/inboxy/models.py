"""
Data models for Inboxy
"""

from enum import Enum
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field


class EmailCategory(Enum):
    """Email categorization buckets"""
    ACTION_REQUIRED = "action_required"  # Needs response/action
    FYI_REVIEW = "fyi_review"  # Information only
    CALENDAR_EVENT = "calendar_event"  # Contains meeting/event info
    NEWSLETTER = "newsletter"  # Subscriptions
    PROMOTION = "promotion"  # Marketing/sales
    SOCIAL = "social"  # Social networks
    AUTO_DELETE = "auto_delete"  # Spam/junk
    IMPORTANT = "important"  # VIP or urgent


class Priority(Enum):
    """Email priority levels"""
    URGENT = 5  # Immediate action needed
    HIGH = 4    # Within 24 hours
    MEDIUM = 3  # Within 2-3 days
    LOW = 2     # When convenient
    NONE = 1    # No action needed


class CalendarEvent(BaseModel):
    """Calendar event details extracted from email"""
    title: str = Field(description="Event title")
    date: Optional[str] = Field(None, description="Event date")
    time: Optional[str] = Field(None, description="Event time")
    location: Optional[str] = Field(None, description="Event location")


class EmailAnalysisResponse(BaseModel):
    """Structured response from AI email analysis"""
    category: str = Field(description="Email category")
    priority: int = Field(description="Priority level 1-5", ge=1, le=5)
    summary: str = Field(description="1-2 sentence summary of the email")
    action_needed: Optional[str] = Field(None, description="What action is required, if any")
    suggested_response: Optional[str] = Field(None, description="Suggested response if action required")
    calendar_event: Optional[CalendarEvent] = Field(None, description="Calendar event details if detected")
    key_points: List[str] = Field(default_factory=list, description="2-3 key points from the email")
    sentiment: str = Field("neutral", description="Email sentiment")


class EmailAnalysis:
    """Result of AI email analysis"""
    def __init__(self, message_id: str, headers: Dict[str, str], response: EmailAnalysisResponse):
        self.message_id = message_id
        self.subject = headers.get("subject", "No subject")
        self.sender = headers.get("from", "Unknown")
        self.date = headers.get("date", "Unknown")
        self.category = EmailCategory(response.category)
        self.priority = Priority(response.priority)
        self.summary = response.summary
        self.action_needed = response.action_needed
        self.suggested_response = response.suggested_response
        self.calendar_event = response.calendar_event.model_dump() if response.calendar_event else None
        self.key_points = response.key_points
        self.sentiment = response.sentiment
        self.is_thread = False
        self.thread_position = None

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for serialization"""
        return {
            'message_id': self.message_id,
            'subject': self.subject,
            'sender': self.sender,
            'date': self.date,
            'category': self.category.value,
            'priority': self.priority.value,
            'summary': self.summary,
            'action_needed': self.action_needed,
            'suggested_response': self.suggested_response,
            'calendar_event': self.calendar_event,
            'key_points': self.key_points,
            'sentiment': self.sentiment
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'EmailAnalysis':
        """Create from dictionary"""
        response = EmailAnalysisResponse(
            category=data['category'],
            priority=data['priority'],
            summary=data['summary'],
            action_needed=data.get('action_needed'),
            suggested_response=data.get('suggested_response'),
            calendar_event=CalendarEvent(**data['calendar_event']) if data.get('calendar_event') else None,
            key_points=data.get('key_points', []),
            sentiment=data.get('sentiment', 'neutral')
        )
        return cls(
            data['message_id'],
            {'subject': data['subject'], 'from': data['sender'], 'date': data['date']},
            response
        )