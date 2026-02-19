# =============================================================================
# risk_engine.py — ZeroPenalty Dynamic Risk Engine
# Combines: OSM Road Type + Accident Hotspots + Time-Based Risk
# Works ONLINE (APIs) + OFFLINE (fallback logic)
# =============================================================================

import logging
import requests
from datetime import datetime, time as dtime

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

OSM_TIMEOUT = 5        # seconds — API timeout
OVERPASS_URL = "https://overpass-api.de/api/interpreter"

# Road type → base speed limit + base risk
ROAD_RISK_MAP = {
    # Highway / Fast roads
    "motorway":        {"speed_limit": 100, "risk": "LOW",    "multiplier": 1.0},
    "motorway_link":   {"speed_limit": 80,  "risk": "LOW",    "multiplier": 1.0},
    "trunk":           {"speed_limit": 80,  "risk": "LOW",    "multiplier": 1.1},
    "trunk_link":      {"speed_limit": 60,  "risk": "LOW",    "multiplier": 1.1},
    # Primary roads
    "primary":         {"speed_limit": 60,  "risk": "LOW",    "multiplier": 1.2},
    "primary_link":    {"speed_limit": 50,  "risk": "MEDIUM", "multiplier": 1.3},
    # Secondary roads
    "secondary":       {"speed_limit": 50,  "risk": "MEDIUM", "multiplier": 1.4},
    "secondary_link":  {"speed_limit": 40,  "risk": "MEDIUM", "multiplier": 1.4},
    # Tertiary roads
    "tertiary":        {"speed_limit": 40,  "risk": "MEDIUM", "multiplier": 1.5},
    "tertiary_link":   {"speed_limit": 30,  "risk": "MEDIUM", "multiplier": 1.5},
    # Urban / Residential
    "residential":     {"speed_limit": 30,  "risk": "MEDIUM", "multiplier": 1.6},
    "living_street":   {"speed_limit": 20,  "risk": "HIGH",   "multiplier": 2.0},
    "unclassified":    {"speed_limit": 30,  "risk": "MEDIUM", "multiplier": 1.5},
    # Special zones
    "pedestrian":      {"speed_limit": 10,  "risk": "HIGH",   "multiplier": 3.0},
    "footway":         {"speed_limit": 10,  "risk": "HIGH",   "multiplier": 3.0},
    "service":         {"speed_limit": 20,  "risk": "HIGH",   "multiplier": 2.0},
    "track":           {"speed_limit": 20,  "risk": "HIGH",   "multiplier": 2.0},
    "path":            {"speed_limit": 10,  "risk": "HIGH",   "multiplier": 3.0},
}

# Amenity tags → risk boost
AMENITY_RISK_BOOST = {
    "school":      {"risk_bump": 2, "label": "School Zone"},
    "college":     {"risk_bump": 1, "label": "College Zone"},
    "university":  {"risk_bump": 1, "label": "University Zone"},
    "hospital":    {"risk_bump": 2, "label": "Hospital Zone"},
    "clinic":      {"risk_bump": 1, "label": "Clinic Zone"},
    "marketplace": {"risk_bump": 2, "label": "Market Zone"},
    "place_of_worship": {"risk_bump": 1, "label": "Religious Area"},
    "bus_station": {"risk_bump": 1, "label": "Bus Station"},
    "railway_station": {"risk_bump": 2, "label": "Railway Station"},
}

# Risk level ordering for comparison
RISK_ORDER = {"LOW": 0, "MEDIUM": 1, "HIGH": 2}
RISK_FROM_ORDER = {0: "LOW", 1: "MEDIUM", 2: "HIGH"}

# ---------------------------------------------------------------------------
# OSM Road Type Fetcher
# ---------------------------------------------------------------------------

def fetch_road_type_osm(lat: float, lng: float) -> dict:
    """
    Query OpenStreetMap Overpass API to get road type + nearby amenities.

    Returns:
        dict with keys: road_type, amenities, source="online"
        On failure: fallback dict with source="offline"
    """
    # Overpass query — road within 30m + amenities within 100m
    query = f"""
    [out:json][timeout:{OSM_TIMEOUT}];
    (
      way(around:30,{lat},{lng})[highway];
      node(around:100,{lat},{lng})[amenity];
    );
    out tags;
    """

    try:
        resp = requests.post(
            OVERPASS_URL,
            data={"data": query},
            timeout=OSM_TIMEOUT
        )
        resp.raise_for_status()
        data = resp.json()

        road_type = None
        amenities = []

        for element in data.get("elements", []):
            tags = element.get("tags", {})
            # Extract road type from ways
            if element["type"] == "way" and "highway" in tags:
                if road_type is None:
                    road_type = tags["highway"]
            # Extract amenities from nodes
            if element["type"] == "node" and "amenity" in tags:
                amenity = tags["amenity"]
                if amenity in AMENITY_RISK_BOOST:
                    amenities.append(amenity)

        logger.info(f"OSM online: road_type={road_type}, amenities={amenities}")
        return {
            "road_type": road_type or "unclassified",
            "amenities": list(set(amenities)),
            "source": "online"
        }

    except requests.Timeout:
        logger.warning("OSM API timeout — using offline fallback")
        return {"road_type": "unclassified", "amenities": [], "source": "offline_timeout"}
    except requests.RequestException as e:
        logger.warning(f"OSM API error: {e} — using offline fallback")
        return {"road_type": "unclassified", "amenities": [], "source": "offline_error"}
    except Exception as e:
        logger.error(f"Unexpected OSM error: {e}")
        return {"road_type": "unclassified", "amenities": [], "source": "offline_error"}


# ---------------------------------------------------------------------------
# Time-Based Risk Calculator
# ---------------------------------------------------------------------------

def get_time_risk(now: datetime = None) -> dict:
    """
    Calculate risk modifier based on current time.

    Risk factors:
        - Night hours (22:00–05:00)     → HIGH risk bump
        - School hours (07:30–09:00 and 13:00–14:30) weekdays → risk bump near schools
        - Late evening (20:00–22:00)    → MEDIUM risk bump
        - Rush hours (08:00–10:00, 17:00–19:30) → MEDIUM bump

    Returns:
        dict with: risk_bump (int 0-2), labels (list), hour, is_night, is_school_hour, is_rush_hour
    """
    if now is None:
        now = datetime.now()

    hour = now.hour
    minute = now.minute
    weekday = now.weekday()  # 0=Monday, 6=Sunday
    is_weekday = weekday < 5

    time_now = now.time()

    is_night = dtime(22, 0) <= time_now or time_now <= dtime(5, 0)
    is_late_evening = dtime(20, 0) <= time_now < dtime(22, 0)
    is_school_hour = is_weekday and (
        dtime(7, 30) <= time_now <= dtime(9, 0) or
        dtime(13, 0) <= time_now <= dtime(14, 30)
    )
    is_rush_hour = is_weekday and (
        dtime(8, 0) <= time_now <= dtime(10, 0) or
        dtime(17, 0) <= time_now <= dtime(19, 30)
    )

    risk_bump = 0
    labels = []

    if is_night:
        risk_bump += 2
        labels.append("🌙 Night Hours — High Risk")
    if is_late_evening:
        risk_bump += 1
        labels.append("🌆 Late Evening")
    if is_rush_hour:
        risk_bump += 1
        labels.append("🚦 Rush Hour")
    if is_school_hour:
        risk_bump += 1
        labels.append("🏫 School Hours")

    return {
        "risk_bump": min(risk_bump, 3),  # cap at 3
        "labels": labels,
        "hour": hour,
        "is_night": is_night,
        "is_school_hour": is_school_hour,
        "is_rush_hour": is_rush_hour,
        "is_late_evening": is_late_evening,
    }


# ---------------------------------------------------------------------------
# Accident Hotspot Fetcher
# ---------------------------------------------------------------------------

def fetch_accident_hotspots(lat: float, lng: float, radius_m: int = 500) -> dict:
    """
    Fetch accident hotspot data from OSM (via Overpass) —
    looks for crash-related tags and highway hazard markers.

    Real Ministry of Road Transport data doesn't have a public REST API,
    so we use OSM community-tagged hazard data as proxy.

    Returns:
        dict with: hotspot_nearby (bool), hotspot_count (int), source
    """
    query = f"""
    [out:json][timeout:{OSM_TIMEOUT}];
    (
      node(around:{radius_m},{lat},{lng})[highway=speed_camera];
      node(around:{radius_m},{lat},{lng})[accident=yes];
      node(around:{radius_m},{lat},{lng})[hazard];
      way(around:{radius_m},{lat},{lng})[accident_prone=yes];
      node(around:{radius_m},{lat},{lng})[highway=stop][barrier=yes];
    );
    out count;
    """

    try:
        resp = requests.post(
            OVERPASS_URL,
            data={"data": query},
            timeout=OSM_TIMEOUT
        )
        resp.raise_for_status()
        data = resp.json()

        count = 0
        if "elements" in data:
            count = len(data["elements"])
        elif "total" in data.get("remarks", ""):
            pass

        logger.info(f"Accident hotspot check: count={count}")
        return {
            "hotspot_nearby": count > 0,
            "hotspot_count": count,
            "source": "online"
        }

    except Exception as e:
        logger.warning(f"Accident hotspot fetch failed: {e}")
        return {"hotspot_nearby": False, "hotspot_count": 0, "source": "offline"}


# ---------------------------------------------------------------------------
# Final Risk Score Calculator
# ---------------------------------------------------------------------------

def calculate_dynamic_risk(lat: float, lng: float) -> dict:
    """
    Full dynamic risk pipeline:
        1. OSM road type (online → offline fallback)
        2. Nearby amenities (school, hospital etc.)
        3. Accident hotspots
        4. Time-based risk

    Returns a complete risk assessment dict.
    """
    # Step 1 — Road type from OSM
    osm_data = fetch_road_type_osm(lat, lng)
    road_type = osm_data["road_type"]
    amenities = osm_data["amenities"]
    osm_source = osm_data["source"]

    # Get base risk from road type
    road_info = ROAD_RISK_MAP.get(road_type, ROAD_RISK_MAP["unclassified"])
    base_risk_level = road_info["risk"]
    base_speed_limit = road_info["speed_limit"]
    base_multiplier = road_info["multiplier"]

    risk_score = RISK_ORDER[base_risk_level]  # 0, 1, or 2
    risk_factors = [f"🛣️ Road Type: {road_type}"]

    # Step 2 — Amenity bump
    amenity_labels = []
    for amenity in amenities:
        boost = AMENITY_RISK_BOOST.get(amenity, {})
        bump = boost.get("risk_bump", 0)
        label = boost.get("label", amenity)
        risk_score += bump
        amenity_labels.append(f"📍 {label}")
        # Reduce speed limit near sensitive amenities
        if bump >= 2:
            base_speed_limit = min(base_speed_limit, 20)
            base_multiplier += 0.5
        elif bump == 1:
            base_speed_limit = min(base_speed_limit, 30)
            base_multiplier += 0.3

    risk_factors.extend(amenity_labels)

    # Step 3 — Accident hotspots
    accident_data = fetch_accident_hotspots(lat, lng)
    if accident_data["hotspot_nearby"]:
        risk_score += 2
        base_multiplier += 0.5
        risk_factors.append(f"⚠️ Accident Hotspot Nearby ({accident_data['hotspot_count']} markers)")

    # Step 4 — Time-based risk
    time_data = get_time_risk()
    risk_score += time_data["risk_bump"]
    risk_factors.extend(time_data["labels"])

    # Night → reduce speed limit further
    if time_data["is_night"]:
        base_speed_limit = max(int(base_speed_limit * 0.7), 20)
        base_multiplier += 0.5
    elif time_data["is_rush_hour"]:
        base_speed_limit = max(int(base_speed_limit * 0.85), 20)
        base_multiplier += 0.2

    # School hours + school nearby → extra strict
    if time_data["is_school_hour"] and any(a in amenities for a in ["school", "college"]):
        base_speed_limit = min(base_speed_limit, 15)
        base_multiplier += 0.8
        risk_factors.append("🏫 Active School Zone — School Hours")

    # Clamp final risk score to HIGH max
    risk_score = min(risk_score, 2)
    final_risk = RISK_FROM_ORDER[risk_score]

    # Alert strength
    alert_strength = "STRONG" if risk_score >= 1 else "NORMAL"

    return {
        # Zone identity
        "zone_id": f"dynamic_{road_type}",
        "zone_name": _build_zone_name(road_type, amenities, time_data),
        "risk_level": final_risk,
        "description": " | ".join(risk_factors),

        # Rules
        "speed_limit": int(base_speed_limit),
        "alert_strength": alert_strength,
        "penalty_multiplier": round(min(base_multiplier, 4.0), 1),

        # Meta
        "is_default_zone": False,
        "is_dynamic": True,
        "road_type": road_type,
        "amenities_nearby": amenities,
        "time_factors": time_data,
        "accident_hotspot": accident_data["hotspot_nearby"],
        "data_source": osm_source,
    }


def _build_zone_name(road_type: str, amenities: list, time_data: dict) -> str:
    """Build a human-readable zone name from dynamic data."""
    parts = []

    if amenities:
        primary = AMENITY_RISK_BOOST.get(amenities[0], {}).get("label", amenities[0])
        parts.append(primary)
    else:
        road_labels = {
            "motorway": "Highway", "trunk": "Trunk Road",
            "primary": "Primary Road", "secondary": "Secondary Road",
            "residential": "Residential Area", "living_street": "Living Street",
            "pedestrian": "Pedestrian Zone", "service": "Service Road",
        }
        parts.append(road_labels.get(road_type, "Urban Road"))

    if time_data["is_night"]:
        parts.append("(Night)")
    elif time_data["is_school_hour"]:
        parts.append("(School Hours)")
    elif time_data["is_rush_hour"]:
        parts.append("(Rush Hour)")

    return " ".join(parts)
