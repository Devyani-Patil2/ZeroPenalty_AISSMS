"""
Trip API routes — upload trips, get ML analysis
"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from datetime import datetime

from models.database import get_db, Trip, Driver
from api.schemas import TripUploadSchema, TripAnalysisResponse
from ml.driver_clustering import driver_clusterer
from ml.risk_predictor import risk_predictor
from ml.anomaly_detector import anomaly_detector
from ml.feedback_generator import feedback_generator
from services.scoring_service import scoring_service

router = APIRouter(prefix="/api/trips", tags=["trips"])


def _trip_to_dict(trip: Trip) -> dict:
    return {
        "driver_id": trip.driver_id,
        "start_time": trip.start_time.isoformat() if trip.start_time else "",
        "end_time": trip.end_time.isoformat() if trip.end_time else "",
        "duration_seconds": trip.duration_seconds,
        "distance_km": trip.distance_km,
        "local_score": trip.local_score,
        "avg_speed": trip.avg_speed,
        "max_speed": trip.max_speed,
        "overspeed_count": trip.overspeed_count,
        "harsh_brake_count": trip.harsh_brake_count,
        "sharp_turn_count": trip.sharp_turn_count,
        "rash_accel_count": trip.rash_accel_count,
        "high_risk_events": trip.high_risk_events,
        "medium_risk_events": trip.medium_risk_events,
        "low_risk_events": trip.low_risk_events,
    }


@router.post("", response_model=TripAnalysisResponse)
def upload_trip(trip_data: TripUploadSchema, db: Session = Depends(get_db)):
    """Upload a trip and get ML-enhanced analysis."""

    # Ensure driver exists
    driver = db.query(Driver).filter(Driver.id == trip_data.driver_id).first()
    if not driver:
        driver = Driver(id=trip_data.driver_id, name=f"Driver {trip_data.driver_id}")
        db.add(driver)
        db.commit()
        db.refresh(driver)

    # Get driver's historical trips
    past_trips_db = db.query(Trip).filter(Trip.driver_id == trip_data.driver_id).all()
    past_trips = [_trip_to_dict(t) for t in past_trips_db]

    trip_dict = trip_data.dict()
    trip_dict.pop("events", None)

    # --- ML Pipeline ---

    # 1. Driver Clustering
    all_trips_db = db.query(Trip).all()
    all_trips = [_trip_to_dict(t) for t in all_trips_db]
    if len(all_trips) >= 3:
        driver_clusterer.train(all_trips)
    cluster_label = driver_clusterer.predict(past_trips + [trip_dict])

    # 2. Risk Prediction
    if len(all_trips) >= 5:
        risk_predictor.train(all_trips)
    risk_prediction = risk_predictor.predict(trip_dict)

    # 3. Anomaly Detection
    if len(past_trips) >= 5:
        anomaly_detector.train(past_trips)
    is_anomaly = anomaly_detector.is_anomaly(trip_dict, past_trips)

    # 4. ML-Enhanced Score
    ml_score = scoring_service.calculate_ml_score(
        trip_data.local_score, risk_prediction, is_anomaly, cluster_label
    )

    # 5. Feedback
    feedback = feedback_generator.generate(trip_dict, cluster_label)

    # 6. Points & Tier
    points = scoring_service.calculate_points(ml_score)

    # Save trip to DB
    trip_record = Trip(
        driver_id=trip_data.driver_id,
        start_time=datetime.fromisoformat(trip_data.start_time),
        end_time=datetime.fromisoformat(trip_data.end_time),
        duration_seconds=trip_data.duration_seconds,
        distance_km=trip_data.distance_km,
        local_score=trip_data.local_score,
        ml_score=ml_score,
        avg_speed=trip_data.avg_speed,
        max_speed=trip_data.max_speed,
        overspeed_count=trip_data.overspeed_count,
        harsh_brake_count=trip_data.harsh_brake_count,
        sharp_turn_count=trip_data.sharp_turn_count,
        rash_accel_count=trip_data.rash_accel_count,
        high_risk_events=trip_data.high_risk_events,
        medium_risk_events=trip_data.medium_risk_events,
        low_risk_events=trip_data.low_risk_events,
        points_earned=points,
        is_anomaly=1 if is_anomaly else 0,
        feedback=feedback,
        events_json=[e.dict() for e in trip_data.events],
    )
    db.add(trip_record)

    # Update driver stats
    driver.total_points += points
    all_scores = [t.local_score for t in past_trips_db] + [trip_data.local_score]
    avg_score = sum(all_scores) / len(all_scores)
    driver.tier = scoring_service.get_tier(avg_score)
    driver.cluster_label = cluster_label

    db.commit()
    db.refresh(trip_record)

    return TripAnalysisResponse(
        trip_id=trip_record.id,
        local_score=trip_data.local_score,
        ml_score=ml_score,
        is_anomaly=is_anomaly,
        driver_cluster=cluster_label,
        risk_prediction=risk_prediction,
        feedback=feedback,
        points_earned=points,
        tier=driver.tier,
    )


@router.get("/{trip_id}/analysis", response_model=TripAnalysisResponse)
def get_trip_analysis(trip_id: int, db: Session = Depends(get_db)):
    """Get ML analysis for an existing trip."""
    trip = db.query(Trip).filter(Trip.id == trip_id).first()
    if not trip:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Trip not found")

    driver = db.query(Driver).filter(Driver.id == trip.driver_id).first()

    return TripAnalysisResponse(
        trip_id=trip.id,
        local_score=trip.local_score,
        ml_score=trip.ml_score,
        is_anomaly=bool(trip.is_anomaly),
        driver_cluster=driver.cluster_label if driver else "Moderate",
        risk_prediction="Medium",
        feedback=trip.feedback or [],
        points_earned=trip.points_earned,
        tier=driver.tier if driver else "Improving",
    )
