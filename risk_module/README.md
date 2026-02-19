# ZeroPenalty — Risk Zone Intelligence Module

A production-ready GPS-based risk zone detection and traffic rule enforcement engine built with Python 3.9 and Flask.

---

## Project Structure

```
ZeroPenalty/
├── app.py            # Flask REST API — routes and request handling
├── zone_engine.py    # Core logic — zone detection and rule application
├── config.py         # App settings and default zone configuration
├── zones.json        # Zone database (Pune, India examples)
├── requirements.txt  # Python dependencies
└── README.md
```

---

## Setup

```bash
# 1. Install dependencies
pip install -r requirements.txt

# 2. Run the server
python app.py

# 3. Server starts at:
#    http://localhost:5000
```

### Environment Variables (optional)

| Variable      | Default   | Description                     |
|---------------|-----------|---------------------------------|
| `PORT`        | `5000`    | Server port                     |
| `HOST`        | `0.0.0.0` | Server host                     |
| `FLASK_DEBUG` | `false`   | Enable debug mode (`true/false`)|

---

## API Reference

### `GET /`
Health check and module status.

**Response:**
```json
{
  "status": "success",
  "data": {
    "module": "ZeroPenalty Risk Zone Intelligence Module",
    "version": "1.0.0",
    "status": "operational",
    "zones_loaded": 10,
    "database_healthy": true
  }
}
```

---

### `GET /zone?lat=&lng=&speed=`
Detect the current risk zone and evaluate driving rules.

**Query Parameters:**

| Parameter | Type  | Required | Description                          |
|-----------|-------|----------|--------------------------------------|
| `lat`     | float | ✅       | User latitude (decimal, -90 to 90)   |
| `lng`     | float | ✅       | User longitude (decimal, -180 to 180)|
| `speed`   | float | ✅       | Current speed in km/h (0 to 500)     |

**Example Request:**
```
GET /zone?lat=18.5284&lng=73.8742&speed=35
```

**Example Response (overspeeding in HIGH zone):**
```json
{
  "status": "success",
  "data": {
    "zone_id": "zone_001",
    "zone_name": "Pune Railway Station Zone",
    "risk_level": "HIGH",
    "description": "Dense pedestrian and vehicle traffic near the main railway station",
    "speed_limit_kmh": 20,
    "alert_strength": "STRONG",
    "penalty_multiplier": 3.0,
    "current_speed_kmh": 35.0,
    "overspeed": true,
    "overspeed_by_kmh": 15.0,
    "base_penalty_inr": 500,
    "penalty_inr": 1500.0,
    "is_default_zone": false
  }
}
```

**Example Response (within speed limit):**
```json
{
  "status": "success",
  "data": {
    "zone_name": "Pune Railway Station Zone",
    "risk_level": "HIGH",
    "speed_limit_kmh": 20,
    "current_speed_kmh": 18.0,
    "overspeed": false,
    "overspeed_by_kmh": 0.0,
    "penalty_inr": 0.0
  }
}
```

**Example Response (outside all zones — default):**
```json
{
  "status": "success",
  "data": {
    "zone_id": "zone_default",
    "zone_name": "Open Road (Default Zone)",
    "risk_level": "LOW",
    "speed_limit_kmh": 60,
    "alert_strength": "NORMAL",
    "is_default_zone": true
  }
}
```

---

## Predefined Pune Zones

| Zone                         | Risk   | Speed Limit | Penalty Multiplier |
|------------------------------|--------|-------------|---------------------|
| Pune Railway Station Zone    | HIGH   | 20 km/h     | 3.0×                |
| FC Road School Zone          | HIGH   | 15 km/h     | 3.5×                |
| Laxmi Road Market Zone       | HIGH   | 20 km/h     | 2.5×                |
| Shivajinagar Hospital Zone   | HIGH   | 20 km/h     | 3.0×                |
| Hinjewadi IT Park Zone       | MEDIUM | 40 km/h     | 1.8×                |
| Viman Nagar Residential Zone | MEDIUM | 30 km/h     | 1.5×                |
| Katraj Ghat Blind Curve Zone | HIGH   | 25 km/h     | 2.8×                |
| Koregaon Park Nightlife Zone | MEDIUM | 35 km/h     | 2.0×                |
| Hadapsar Industrial Zone     | LOW    | 50 km/h     | 1.2×                |
| Baner Road Construction Zone | HIGH   | 20 km/h     | 2.5×                |

---

## Penalty Formula

```
penalty_inr = BASE_PENALTY × penalty_multiplier   (if overspeeding)
penalty_inr = 0                                   (if within limit)

BASE_PENALTY = ₹500 (configurable in config.py)
```

---

## Adding New Zones

Add entries to `zones.json`:

```json
{
  "id": "zone_011",
  "name": "My New Zone",
  "risk_level": "HIGH",
  "speed_limit": 20,
  "penalty_multiplier": 2.5,
  "alert_strength": "STRONG",
  "latitude": 18.5200,
  "longitude": 73.8600,
  "radius": 300,
  "description": "Description of the zone"
}
```

Restart the server — zones are loaded at startup.

---

## Mobile App Integration

The API returns clean, flat JSON ready for direct consumption by iOS/Android apps. Recommended polling interval: **every 3–5 seconds** while the app is in foreground navigation mode.

Use `alert_strength` to trigger:
- `STRONG` → vibration + audio alert + red UI highlight
- `NORMAL` → subtle notification

Use `overspeed` boolean for real-time speed violation indicators.
