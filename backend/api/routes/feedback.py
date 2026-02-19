"""
Feedback API routes — ML-powered personalized suggestions
"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from models.database import get_db, Trip, Driver
from api.schemas import FeedbackResponse
from ml.feedback_generator import feedback_generator
from ml.risk_predictor import risk_predictor

router = APIRouter(prefix="/api/feedback", tags=["feedback"])


@router.get("/{trip_id}", response_model=FeedbackResponse)
def get_feedback(trip_id: int, db: Session = Depends(get_db)):
    """Get ML-generated personalized feedback for a trip."""
    trip = db.query(Trip).filter(Trip.id == trip_id).first()
    if not trip:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Trip not found")

    driver = db.query(Driver).filter(Driver.id == trip.driver_id).first()
    cluster = driver.cluster_label if driver else "Moderate"

    trip_dict = {
        "avg_speed": trip.avg_speed,
        "max_speed": trip.max_speed,
        "overspeed_count": trip.overspeed_count,
        "harsh_brake_count": trip.harsh_brake_count,
        "sharp_turn_count": trip.sharp_turn_count,
        "rash_accel_count": trip.rash_accel_count,
        "local_score": trip.local_score,
        "high_risk_events": trip.high_risk_events,
        "medium_risk_events": trip.medium_risk_events,
        "low_risk_events": trip.low_risk_events,
    }

    suggestions = feedback_generator.generate(trip_dict, cluster)
    risk_level = risk_predictor.predict(trip_dict)

    return FeedbackResponse(
        trip_id=trip.id,
        suggestions=suggestions,
        driver_type=cluster,
        risk_level=risk_level,
    )
