# =============================================================================
# app.py — ZeroPenalty Risk Zone Intelligence Module
# Flask REST API — exposes zone detection and rule evaluation endpoints.
# =============================================================================

import logging
import threading
from flask import Flask, request, jsonify, send_from_directory

from config import APP_NAME, APP_VERSION, DEBUG, HOST, PORT
from zone_engine import load_zones, evaluate_driver
from risk_engine import get_time_risk

# ---------------------------------------------------------------------------
# Logging Configuration
# ---------------------------------------------------------------------------

logging.basicConfig(
    level=logging.DEBUG if DEBUG else logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Flask App Initialization
# ---------------------------------------------------------------------------

app = Flask(__name__)

# Pre-load zones at startup to avoid repeated disk I/O on each request.
# Stored in a list wrapper so it can be mutated by the hot-reload endpoint.
_zones_lock = threading.Lock()

try:
    ZONES_CACHE = load_zones()
    logger.info(f"{APP_NAME} v{APP_VERSION} — Zone database loaded successfully.")
except Exception as e:
    ZONES_CACHE = []
    logger.critical(f"Failed to load zone database on startup: {e}")


# ---------------------------------------------------------------------------
# Helper: Unified JSON Response Builder
# ---------------------------------------------------------------------------

def success_response(data: dict, status: int = 200):
    """Wrap a successful response in a standard envelope."""
    return jsonify({
        "status": "success",
        "data": data
    }), status


def error_response(message: str, status: int = 400):
    """Wrap an error response in a standard envelope."""
    return jsonify({
        "status": "error",
        "message": message
    }), status


# ---------------------------------------------------------------------------
# Helper: Query Parameter Validator
# ---------------------------------------------------------------------------

def parse_float_param(name: str, value: str, min_val: float = None, max_val: float = None) -> tuple:
    """
    Parse and validate a float query parameter.

    Returns:
        (float_value, None) on success
        (None, error_message) on failure
    """
    try:
        parsed = float(value)
    except (TypeError, ValueError):
        return None, f"Parameter '{name}' must be a valid number. Got: '{value}'"

    if min_val is not None and parsed < min_val:
        return None, f"Parameter '{name}' must be >= {min_val}. Got: {parsed}"

    if max_val is not None and parsed > max_val:
        return None, f"Parameter '{name}' must be <= {max_val}. Got: {parsed}"

    return parsed, None


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.route("/", methods=["GET"])
def health_check():
    """
    GET /
    Returns the module's operational status and metadata.
    Useful for load balancer health checks and mobile app connectivity tests.
    """
    return success_response({
        "module": APP_NAME,
        "version": APP_VERSION,
        "status": "operational",
        "zones_loaded": len(ZONES_CACHE),
        "database_healthy": len(ZONES_CACHE) > 0,
        "endpoints": {
            "health": "GET /",
            "dashboard": "GET /dashboard",
            "zone_check": "GET /zone?lat=<latitude>&lng=<longitude>&speed=<speed_kmh>",
            "reload_zones": "POST /reload-zones"
        }
    })


@app.route("/dashboard", methods=["GET"])
def dashboard():
    """
    GET /dashboard
    Serves the visual Risk Zone Intelligence dashboard.
    Open in browser to interact with zone detection visually.
    """
    return send_from_directory(".", "dashboard.html")


@app.route("/zone", methods=["GET"])
def get_zone():
    """
    GET /zone?lat=<latitude>&lng=<longitude>&speed=<speed_kmh>

    Detects the risk zone for the given GPS coordinates and evaluates
    the driver's speed against the zone's rules.

    Query Parameters:
        lat   (required) — Latitude in decimal degrees  [-90, 90]
        lng   (required) — Longitude in decimal degrees [-180, 180]
        speed (required) — Current speed in km/h        [0, 500]

    Returns:
        JSON object with zone metadata, rule evaluation, and penalty details.

    Example:
        GET /zone?lat=18.5284&lng=73.8742&speed=35

    Response (overspeeding in HIGH zone):
        {
          "status": "success",
          "data": {
            "zone_id": "zone_001",
            "zone_name": "Pune Railway Station Zone",
            "risk_level": "HIGH",
            "speed_limit_kmh": 20,
            "current_speed_kmh": 35.0,
            "overspeed": true,
            "overspeed_by_kmh": 15.0,
            "alert_strength": "STRONG",
            "penalty_multiplier": 3.0,
            "base_penalty_inr": 500,
            "penalty_inr": 1500.0,
            "is_default_zone": false,
            "description": "..."
          }
        }
    """
    # --- Check database health ---
    if not ZONES_CACHE:
        logger.error("Zone database is unavailable. Cannot process request.")
        return error_response(
            "Zone database is currently unavailable. Please try again later.",
            status=503
        )

    # --- Extract and validate query parameters ---
    raw_lat = request.args.get("lat")
    raw_lng = request.args.get("lng")
    raw_speed = request.args.get("speed")

    if not all([raw_lat, raw_lng, raw_speed]):
        return error_response(
            "Missing required parameters. Provide: lat, lng, speed. "
            "Example: /zone?lat=18.5284&lng=73.8742&speed=30"
        )

    lat, err = parse_float_param("lat", raw_lat, min_val=-90.0, max_val=90.0)
    if err:
        return error_response(err)

    lng, err = parse_float_param("lng", raw_lng, min_val=-180.0, max_val=180.0)
    if err:
        return error_response(err)

    speed, err = parse_float_param("speed", raw_speed, min_val=0.0, max_val=500.0)
    if err:
        return error_response(err)

    # --- Run zone evaluation pipeline ---
    # ?dynamic=false → use only static zones.json (faster, offline)
    use_dynamic = request.args.get("dynamic", "true").lower() != "false"

    try:
        result = evaluate_driver(
            user_lat=lat,
            user_lng=lng,
            speed=speed,
            zones=ZONES_CACHE,
            use_dynamic=use_dynamic
        )
    except Exception as e:
        logger.exception(f"Unexpected error during zone evaluation: {e}")
        return error_response(
            "An internal error occurred while evaluating the zone.",
            status=500
        )

    return success_response(result)


@app.route("/time-risk", methods=["GET"])
def time_risk():
    """
    GET /time-risk
    Returns current time-based risk factors (night/rush hour/school hours).
    Used by dashboard to show live time context without a full zone check.
    """
    try:
        data = get_time_risk()
        return success_response(data)
    except Exception as e:
        return error_response(f"Time risk calculation failed: {e}", status=500)


@app.route("/reload-zones", methods=["POST"])
def reload_zones():
    """
    POST /reload-zones

    Hot-reloads zones.json without restarting the server.
    Call this after manually editing zones.json to apply changes immediately.

    Returns:
        JSON with updated zone count on success, or error on failure.

    Example:
        curl -X POST http://localhost:5000/reload-zones
    """
    global ZONES_CACHE
    try:
        new_zones = load_zones()
        with _zones_lock:
            ZONES_CACHE = new_zones
        logger.info(f"Zone database hot-reloaded successfully — {len(ZONES_CACHE)} zones loaded.")
        return success_response({
            "message": "Zone database reloaded successfully.",
            "zones_loaded": len(ZONES_CACHE)
        })
    except FileNotFoundError:
        logger.error("zones.json not found during hot-reload.")
        return error_response("zones.json not found. Check the file path.", status=404)
    except ValueError as e:
        logger.error(f"Invalid zones.json during hot-reload: {e}")
        return error_response(f"Invalid zones.json format: {e}", status=422)
    except Exception as e:
        logger.exception(f"Unexpected error during zone hot-reload: {e}")
        return error_response("Failed to reload zone database.", status=500)


# ---------------------------------------------------------------------------
# Error Handlers
# ---------------------------------------------------------------------------

@app.errorhandler(404)
def not_found(e):
    return error_response(f"Endpoint not found. Check the API documentation at GET /", status=404)


@app.errorhandler(405)
def method_not_allowed(e):
    return error_response("HTTP method not allowed for this endpoint.", status=405)


@app.errorhandler(500)
def internal_server_error(e):
    logger.error(f"Unhandled internal server error: {e}")
    return error_response("Internal server error.", status=500)


# ---------------------------------------------------------------------------
# Entry Point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    logger.info(f"Starting {APP_NAME} v{APP_VERSION} on {HOST}:{PORT}")
    app.run(host=HOST, port=PORT, debug=DEBUG)
