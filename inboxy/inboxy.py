#!/usr/bin/env python3
"""
Inboxy - convenience wrapper for running without installation
"""

import sys
from pathlib import Path

# Add src to path for development
sys.path.insert(0, str(Path(__file__).parent / "src"))

from inboxy import main

if __name__ == "__main__":
    main()