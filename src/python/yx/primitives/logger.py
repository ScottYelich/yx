"""
Emoji-based logger matching the Swift implementation
"""

import sys
import os
from datetime import datetime
from enum import Enum
from typing import Optional


class LogLevel(Enum):
    """Log levels with associated emojis"""
    DEBUG = ("🔍", "DEBUG", 0)
    INFO = ("ℹ️", "INFO", 1)
    WARNING = ("⚠️", "WARNING", 2)
    ERROR = ("❌", "ERROR", 3)
    SUCCESS = ("✅", "SUCCESS", 1)

    @property
    def priority(self) -> int:
        """Get numeric priority for comparison"""
        return self.value[2]


class Logger:
    """Emoji-based logger for YX framework"""

    def __init__(self, name: str = "YX", min_level: Optional[LogLevel] = None):
        """
        Initialize logger.

        Args:
            name: Logger name
            min_level: Minimum log level to display (None = read from LOG_LEVEL env var)
        """
        self.name = name

        # Read from environment if not specified
        if min_level is None:
            env_level = os.environ.get("LOG_LEVEL", "info").lower()
            if env_level == "silent":
                # Silent mode: set to impossibly high level
                self.min_level = None
            elif env_level == "debug":
                self.min_level = LogLevel.DEBUG
            elif env_level == "market":
                # Market level maps to INFO for YX framework, but actually we want to suppress INFO
                # Market level should only show important messages (WARNING/ERROR/SUCCESS)
                self.min_level = LogLevel.ERROR
            else:  # "info" or unknown
                self.min_level = LogLevel.INFO
        else:
            self.min_level = min_level

    def _log(self, level: LogLevel, message: str, emoji: Optional[str] = None):
        """Internal logging method"""
        # Silent mode - don't log anything
        if self.min_level is None:
            return

        # Compare priorities
        if level.priority < self.min_level.priority:
            return

        timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
        icon = emoji if emoji else level.value[0]
        print(f"{icon} [{timestamp}] {message}", file=sys.stderr)

    def debug(self, message: str, emoji: Optional[str] = None):
        """Log debug message"""
        self._log(LogLevel.DEBUG, message, emoji)

    def info(self, message: str, emoji: Optional[str] = None):
        """Log info message"""
        self._log(LogLevel.INFO, message, emoji)

    def warning(self, message: str, emoji: Optional[str] = None):
        """Log warning message"""
        self._log(LogLevel.WARNING, message, emoji)

    def error(self, message: str, emoji: Optional[str] = None):
        """Log error message"""
        self._log(LogLevel.ERROR, message, emoji)

    def success(self, message: str, emoji: Optional[str] = None):
        """Log success message"""
        self._log(LogLevel.SUCCESS, message, emoji)

    # Convenience methods with specific emojis (matching Swift)
    def network(self, message: str):
        """Log network message"""
        self._log(LogLevel.INFO, message, "🌐")

    def packet(self, message: str):
        """Log packet message"""
        self._log(LogLevel.INFO, message, "📦")

    def send(self, message: str):
        """Log send message"""
        self._log(LogLevel.INFO, message, "📤")

    def receive(self, message: str):
        """Log receive message"""
        self._log(LogLevel.INFO, message, "📥")

    def key(self, message: str):
        """Log cryptography message"""
        self._log(LogLevel.INFO, message, "🔐")

    def guid(self, message: str):
        """Log GUID message"""
        self._log(LogLevel.INFO, message, "🧩")

    def timer(self, message: str):
        """Log timer message"""
        self._log(LogLevel.INFO, message, "⏱️")

    def test(self, message: str):
        """Log test message"""
        self._log(LogLevel.INFO, message, "🧪")

    def broadcast(self, message: str):
        """Log broadcast message"""
        self._log(LogLevel.INFO, message, "📣")

    def tool(self, message: str):
        """Log tool message"""
        self._log(LogLevel.INFO, message, "🔧")


# Global default logger instance
default_logger = Logger()
