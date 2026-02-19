"""
Analytics API routes — trend data, driver profile
"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from models.database import get_db, Trip, Driver
from api.schemas import AnalyticsSummaryResponse, DriverProfileResponse
from services.scoring_service import scoring_service

router = APIRouter(prefix="/api/analytics", tags=["analytics"])


@router.get("/summary/{driver_id}", response_model=AnalyticsSummaryResponse)
def get_analytics_summary(driver_id: int, db: Session = Depends(get_db)):
    """Get analytics summary for a driver."""
    driver = db.query(Driver).filter(Driver.id == driver_id).first()
    if not driver:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Driver not found")

    trips = db.query(Trip).filter(Trip.driver_id == driver_id)\
        .order_by(Trip.start_time.desc()).all()

    total_trips = len(trips)
    all_scores = [t.ml_score or t.local_score for t in trips] if trips else [100.0]

    lifetime_avg = sum(all_scores) / len(all_scores)
    last_5 = all_scores[:5]

    # Weekly average (last 7 trips as proxy)
    weekly_scores = all_scores[:7] if len(all_scores) >= 7 else all_scores
    weekly_avg = sum(weekly_scores) / len(weekly_scores)

    # Improvement percentage
    if len(all_scores) >= 4:
        recent_avg = sum(all_scores[:len(all_scores) // 2]) / (len(all_scores) // 2)
        older_avg = sum(all_scores[len(all_scores) // 2:]) / (len(all_scores) - len(all_scores) // 2)
        improvement = ((recent_avg - older_avg) / max(older_avg, 1)) * 100
    else:
        improvement = 0.0

    return AnalyticsSummaryResponse(
        total_trips=total_trips,
        lifetime_avg_score=round(lifetime_avg, 1),
        last_5_scores=[round(s, 1) for s in last_5],
        weekly_avg=round(weekly_avg, 1),
        improvement_pct=round(improvement, 1),
        total_points=driver.total_points,
        tier=driver.tier,
        cluster_label=driver.cluster_label,
    )


@router.get("/profile/{driver_id}", response_model=DriverProfileResponse)
def get_driver_profile(driver_id: int, db: Session = Depends(get_db)):
    """Get driver profile."""
    driver = db.query(Driver).filter(Driver.id == driver_id).first()
    if not driver:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Driver not found")

    trips = db.query(Trip).filter(Trip.driver_id == driver_id).all()
    total_trips = len(trips)
    all_scores = [t.ml_score or t.local_score for t in trips] if trips else [100.0]
    lifetime_avg = sum(all_scores) / len(all_scores)

    return DriverProfileResponse(
        id=driver.id,
        name=driver.name,
        total_trips=total_trips,
        lifetime_avg_score=round(lifetime_avg, 1),
        total_points=driver.total_points,
        tier=driver.tier,
        cluster_label=driver.cluster_label,
    )
