# =============================================================================
# config.py — ZeroPenalty Risk Zone Intelligence Module
# Application configuration and default zone definition.
# =============================================================================

import os

# ---------------------------------------------------------------------------
# Application Settings
# ---------------------------------------------------------------------------

APP_NAME = "ZeroPenalty Risk Zone Intelligence Module"
APP_VERSION = "1.0.0"
DEBUG = os.getenv("FLASK_DEBUG", "false").lower() == "true"
PORT = int(os.getenv("PORT", 5000))
HOST = os.getenv("HOST", "0.0.0.0")

# Path to the zones database (relative to project root)
ZONES_DB_PATH = os.path.join(os.path.dirname(__file__), "zones.json")

# ---------------------------------------------------------------------------
# Penalty Settings
# ---------------------------------------------------------------------------

# Base penalty in INR (Indian Rupees) — applied before multiplier
BASE_PENALTY = 500  # ₹500 base fine for overspeeding

# ---------------------------------------------------------------------------
# Default Zone
# Returned when the driver is not inside any defined risk zone.
# Represents a standard open road with relaxed rules.
# ---------------------------------------------------------------------------

DEFAULT_ZONE = {
    "id": "zone_default",
    "name": "Open Road (Default Zone)",
    "risk_level": "LOW",
    "speed_limit": 60,          # km/h — standard urban road limit
    "penalty_multiplier": 1.0,  # No extra multiplier for default zone
    "alert_strength": "NORMAL",
    "description": "No special risk zone detected. Standard road rules apply."
}

# ---------------------------------------------------------------------------
# Valid Enum Values (used for validation and documentation)
# ---------------------------------------------------------------------------

VALID_RISK_LEVELS = {"HIGH", "MEDIUM", "LOW"}
VALID_ALERT_STRENGTHS = {"STRONG", "NORMAL"}
