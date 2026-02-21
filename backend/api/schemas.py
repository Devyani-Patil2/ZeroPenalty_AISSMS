from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


# --- Trip Event ---
class TripEventSchema(BaseModel):
    event_type: str  # "overspeed", "harsh_brake", "sharp_turn", "rash_accel"
    timestamp: str
    speed: Optional[float] = None
    speed_limit: Optional[float] = None
    zone_type: str  # "HIGH_RISK", "MEDIUM_RISK", "LOW_RISK"
    severity: Optional[float] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None


# --- Trip Upload ---
class TripUploadSchema(BaseModel):
    driver_id: int
    start_time: str
    end_time: str
    duration_seconds: int
    distance_km: float
    local_score: float
    avg_speed: float
    max_speed: float
    overspeed_count: int
    harsh_brake_count: int
    sharp_turn_count: int
    rash_accel_count: int
    high_risk_events: int
    medium_risk_events: int
    low_risk_events: int
    events: List[TripEventSchema]


# --- Trip Response ---
class TripAnalysisResponse(BaseModel):
    trip_id: int
    local_score: float
    ml_score: Optional[float] = None
    is_anomaly: bool
    driver_cluster: str
    risk_prediction: str
    feedback: List[str]
    points_earned: int
    tier: str


# --- Analytics ---
class AnalyticsSummaryResponse(BaseModel):
    total_trips: int
    lifetime_avg_score: float
    last_5_scores: List[float]
    weekly_avg: float
    improvement_pct: float
    total_points: int
    tier: str
    cluster_label: str


# --- Driver Profile ---
class DriverProfileResponse(BaseModel):
    id: int
    name: str
    total_trips: int
    lifetime_avg_score: float
    total_points: int
    tier: str
    cluster_label: str


# --- Feedback ---
class FeedbackResponse(BaseModel):
    trip_id: int
    suggestions: List[str]
    driver_type: str
    risk_level: str
