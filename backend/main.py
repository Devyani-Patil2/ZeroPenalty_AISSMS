"""
ZeroPenalty — Python Backend
FastAPI server with ML-powered driving analysis
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from models.database import init_db
from api.routes import trips, analytics, feedback
from data.seed_data import generate_seed_trips
from ml.driver_clustering import driver_clusterer
from ml.risk_predictor import risk_predictor

app = FastAPI(
    title="ZeroPenalty API",
    description="ML-powered driving behavior analysis backend",
    version="1.0.0",
)

# CORS — allow Flutter app to connect
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register routes
app.include_router(trips.router)
app.include_router(analytics.router)
app.include_router(feedback.router)


@app.on_event("startup")
def startup():
    """Initialize database and pre-train ML models with seed data."""
    init_db()

    # Generate seed data and pre-train models
    seed_trips = generate_seed_trips(100)
    driver_clusterer.train(seed_trips)
    risk_predictor.train(seed_trips)
    print("✅ Database initialized")
    print("✅ ML models pre-trained with 100 seed trips")


@app.get("/")
def root():
    return {
        "app": "ZeroPenalty API",
        "version": "1.0.0",
        "status": "running",
        "endpoints": {
            "trips": "/api/trips",
            "analytics": "/api/analytics/summary/{driver_id}",
            "profile": "/api/analytics/profile/{driver_id}",
            "feedback": "/api/feedback/{trip_id}",
            "docs": "/docs",
        }
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
