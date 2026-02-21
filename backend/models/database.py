from sqlalchemy import create_engine, Column, Integer, Float, String, DateTime, ForeignKey, JSON
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship
from datetime import datetime

DATABASE_URL = "sqlite:///./zeropenalty.db"
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


class Driver(Base):
    __tablename__ = "drivers"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, default="Driver")
    created_at = Column(DateTime, default=datetime.utcnow)
    cluster_label = Column(String, default="Moderate")
    total_points = Column(Integer, default=0)
    tier = Column(String, default="Improving")
    trips = relationship("Trip", back_populates="driver")


class Trip(Base):
    __tablename__ = "trips"

    id = Column(Integer, primary_key=True, index=True)
    driver_id = Column(Integer, ForeignKey("drivers.id"))
    start_time = Column(DateTime)
    end_time = Column(DateTime)
    duration_seconds = Column(Integer, default=0)
    distance_km = Column(Float, default=0.0)
    local_score = Column(Float, default=100.0)
    ml_score = Column(Float, nullable=True)
    avg_speed = Column(Float, default=0.0)
    max_speed = Column(Float, default=0.0)
    overspeed_count = Column(Integer, default=0)
    harsh_brake_count = Column(Integer, default=0)
    sharp_turn_count = Column(Integer, default=0)
    rash_accel_count = Column(Integer, default=0)
    high_risk_events = Column(Integer, default=0)
    medium_risk_events = Column(Integer, default=0)
    low_risk_events = Column(Integer, default=0)
    points_earned = Column(Integer, default=0)
    is_anomaly = Column(Integer, default=0)
    feedback = Column(JSON, nullable=True)
    events_json = Column(JSON, nullable=True)

    driver = relationship("Driver", back_populates="trips")


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db():
    Base.metadata.create_all(bind=engine)
