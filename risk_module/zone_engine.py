# =============================================================================
# zone_engine.py — ZeroPenalty Risk Zone Intelligence Module
# Core business logic: zone loading, GPS detection, and rule application.
# Supports: Dynamic Risk (OSM + Time + Accidents) with zones.json fallback.
# =============================================================================

import json
import logging
from typing import Optional
from geopy.distance import geodesic

from config import ZONES_DB_PATH, DEFAULT_ZONE, BASE_PENALTY
from risk_engine import calculate_dynamic_risk, get_time_risk

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Zone Loader
# ---------------------------------------------------------------------------

def load_zones(filepath: str = ZONES_DB_PATH) -> list:
    """Load zone definitions from zones.json (static fallback database)."""
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            data = json.load(f)
        if "zones" not in data or not isinstance(data["zones"], list):
            raise ValueError("zones.json must contain a top-level 'zones' array.")
        logger.info(f"Loaded {len(data['zones'])} zone(s) from {filepath}")
        return data["zones"]
    except FileNotFoundError:
        logger.error(f"Zone database not found at path: {filepath}")
        raise
    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse zones.json: {e}")
        raise ValueError(f"Invalid JSON in zone database: {e}") from e


# ---------------------------------------------------------------------------
# Static Zone Detection (zones.json fallback)
# ---------------------------------------------------------------------------

def detect_zone_static(user_lat: float, user_lng: float, zones: list) -> dict:
    """Detect zone from static zones.json using geodesic distance."""
    user_coords = (user_lat, user_lng)
    closest_zone = None
    closest_distance = float("inf")

    for zone in zones:
        zone_coords = (zone["latitude"], zone["longitude"])
        distance_meters = geodesic(user_coords, zone_coords).meters
        if distance_meters <= zone["radius"] and distance_meters < closest_distance:
            closest_distance = distance_meters
            closest_zone = zone

    if closest_zone:
        logger.info(f"Static zone matched: '{closest_zone['name']}' [{closest_distance:.1f}m]")
        return closest_zone

    logger.info("No static zone matched — using DEFAULT zone.")
    return DEFAULT_ZONE


# ---------------------------------------------------------------------------
# Rule Application Engine
# ---------------------------------------------------------------------------

def apply_rules(zone: dict, speed: float) -> dict:
    """Apply driving rules for the detected zone and evaluate driver's speed."""
    speed_limit = zone.get("speed_limit") or zone.get("speed_limit_kmh", 60)
    penalty_multiplier = zone.get("penalty_multiplier", 1.0)
    is_overspeeding = speed > speed_limit
    penalty = round(BASE_PENALTY * penalty_multiplier, 2) if is_overspeeding else 0.0

    # Time factors — always computed server-side
    time_info = zone.get("time_factors") or get_time_risk()

    return {
        "zone_id":            zone.get("id") or zone.get("zone_id", "dynamic"),
        "zone_name":          zone.get("name") or zone.get("zone_name", "Unknown Zone"),
        "risk_level":         zone.get("risk_level", "LOW"),
        "description":        zone.get("description", ""),
        "speed_limit_kmh":    speed_limit,
        "alert_strength":     zone.get("alert_strength", "NORMAL"),
        "penalty_multiplier": penalty_multiplier,
        "current_speed_kmh":  speed,
        "overspeed":          is_overspeeding,
        "overspeed_by_kmh":   round(max(0.0, speed - speed_limit), 2),
        "base_penalty_inr":   BASE_PENALTY,
        "penalty_inr":        penalty,
        "is_default_zone":    zone.get("id") == DEFAULT_ZONE.get("id") or zone.get("is_default_zone", False),
        "is_dynamic":         zone.get("is_dynamic", False),
        "road_type":          zone.get("road_type"),
        "amenities_nearby":   zone.get("amenities_nearby", []),
        "data_source":        zone.get("data_source", "static"),
        "accident_hotspot":   zone.get("accident_hotspot", False),
        "time_factors": {
            "is_night":       time_info.get("is_night", False),
            "is_school_hour": time_info.get("is_school_hour", False),
            "is_rush_hour":   time_info.get("is_rush_hour", False),
            "hour":           time_info.get("hour", 0),
            "labels":         time_info.get("labels", []),
        }
    }


# ---------------------------------------------------------------------------
# Unified Entry Point — Dynamic + Static Fallback
# ---------------------------------------------------------------------------

def evaluate_driver(user_lat: float, user_lng: float, speed: float, zones: list, use_dynamic: bool = True) -> dict:
    """
    Full pipeline: detect zone + apply rules.

    Dynamic mode (default): OSM road type + accidents + time risk.
    If OSM fails → auto-fallback to static zones.json.
    Static mode: zones.json only.
    """
    if use_dynamic:
        try:
            dynamic_zone = calculate_dynamic_risk(user_lat, user_lng)

            # OSM offline + static zone exists → prefer static zone (more specific)
            if dynamic_zone.get("data_source", "").startswith("offline"):
                static_zone = detect_zone_static(user_lat, user_lng, zones)
                if static_zone.get("id") != DEFAULT_ZONE.get("id"):
                    logger.info("OSM offline — using matched static zone.")
                    return apply_rules(static_zone, speed)
                logger.info("OSM offline — using dynamic fallback data.")
            return apply_rules(dynamic_zone, speed)

        except Exception as e:
            logger.error(f"Dynamic evaluation failed: {e} — falling back to static.")

    zone = detect_zone_static(user_lat, user_lng, zones)
    return apply_rules(zone, speed)
