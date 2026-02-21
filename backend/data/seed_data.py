"""
Seed data generator for training ML models with realistic driving data.
"""
import random
import numpy as np
from datetime import datetime, timedelta


def generate_seed_trips(n=100) -> list:
    """Generate synthetic trip data for initial ML model training."""
    trips = []
    base_time = datetime(2025, 1, 1, 8, 0, 0)

    for i in range(n):
        # Create different driver profiles
        profile = random.choice(["cautious", "moderate", "aggressive"])

        if profile == "cautious":
            avg_speed = random.uniform(25, 45)
            max_speed = avg_speed + random.uniform(5, 15)
            overspeed = random.randint(0, 2)
            harsh_brake = random.randint(0, 1)
            sharp_turn = random.randint(0, 1)
            rash_accel = random.randint(0, 1)
            score = random.uniform(80, 100)
        elif profile == "moderate":
            avg_speed = random.uniform(35, 60)
            max_speed = avg_speed + random.uniform(10, 25)
            overspeed = random.randint(1, 5)
            harsh_brake = random.randint(1, 3)
            sharp_turn = random.randint(0, 3)
            rash_accel = random.randint(1, 3)
            score = random.uniform(50, 80)
        else:  # aggressive
            avg_speed = random.uniform(50, 90)
            max_speed = avg_speed + random.uniform(15, 40)
            overspeed = random.randint(4, 12)
            harsh_brake = random.randint(3, 8)
            sharp_turn = random.randint(2, 6)
            rash_accel = random.randint(3, 7)
            score = random.uniform(10, 55)

        high_risk = random.randint(0, overspeed)
        med_risk = random.randint(0, overspeed - high_risk)
        low_risk = overspeed - high_risk - med_risk

        duration = random.randint(300, 3600)
        distance = avg_speed * duration / 3600

        trip_time = base_time + timedelta(hours=random.randint(0, 23), days=i % 30)

        trips.append({
            "driver_id": random.randint(1, 10),
            "start_time": trip_time.isoformat(),
            "end_time": (trip_time + timedelta(seconds=duration)).isoformat(),
            "duration_seconds": duration,
            "distance_km": round(distance, 2),
            "local_score": round(score, 1),
            "avg_speed": round(avg_speed, 1),
            "max_speed": round(max_speed, 1),
            "overspeed_count": overspeed,
            "harsh_brake_count": harsh_brake,
            "sharp_turn_count": sharp_turn,
            "rash_accel_count": rash_accel,
            "high_risk_events": high_risk,
            "medium_risk_events": med_risk,
            "low_risk_events": low_risk,
        })

    return trips
