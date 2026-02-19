"""
Anomaly Detector using Isolation Forest
Flags trips that deviate from a driver's normal behavior
"""
import numpy as np
from sklearn.ensemble import IsolationForest


class AnomalyDetector:
    def __init__(self):
        self.model = IsolationForest(
            contamination=0.15,
            random_state=42,
            n_estimators=100
        )
        self._is_trained = False

    def _extract_features(self, trips: list) -> np.ndarray:
        features = []
        for t in trips:
            features.append([
                t.get("avg_speed", 0),
                t.get("max_speed", 0),
                t.get("overspeed_count", 0),
                t.get("harsh_brake_count", 0),
                t.get("sharp_turn_count", 0),
                t.get("rash_accel_count", 0),
                t.get("local_score", 100),
                t.get("distance_km", 0),
                t.get("duration_seconds", 0) / 60.0,  # minutes
            ])
        return np.array(features)

    def train(self, driver_trips: list):
        if len(driver_trips) < 5:
            return
        X = self._extract_features(driver_trips)
        self.model.fit(X)
        self._is_trained = True

    def is_anomaly(self, trip: dict, driver_trips: list) -> bool:
        """Check if a trip is anomalous for this driver."""
        if not self._is_trained or len(driver_trips) < 5:
            # Fallback: flag if score is 30+ below average
            if len(driver_trips) > 0:
                avg_score = np.mean([t.get("local_score", 100) for t in driver_trips])
                return trip.get("local_score", 100) < (avg_score - 30)
            return False

        X = self._extract_features([trip])
        prediction = self.model.predict(X)[0]
        return prediction == -1  # -1 = anomaly

    def get_anomaly_details(self, trip: dict, driver_trips: list) -> str:
        """Get a human-readable explanation of why a trip is anomalous."""
        if len(driver_trips) == 0:
            return ""

        avgs = {
            "overspeed": np.mean([t.get("overspeed_count", 0) for t in driver_trips]),
            "braking": np.mean([t.get("harsh_brake_count", 0) for t in driver_trips]),
            "turns": np.mean([t.get("sharp_turn_count", 0) for t in driver_trips]),
            "accel": np.mean([t.get("rash_accel_count", 0) for t in driver_trips]),
        }

        deviations = []
        if trip.get("overspeed_count", 0) > avgs["overspeed"] * 2:
            ratio = trip["overspeed_count"] / max(avgs["overspeed"], 1)
            deviations.append(f"{ratio:.1f}x more overspeeding than your average")
        if trip.get("harsh_brake_count", 0) > avgs["braking"] * 2:
            ratio = trip["harsh_brake_count"] / max(avgs["braking"], 1)
            deviations.append(f"{ratio:.1f}x more harsh braking than usual")
        if trip.get("sharp_turn_count", 0) > avgs["turns"] * 2:
            ratio = trip["sharp_turn_count"] / max(avgs["turns"], 1)
            deviations.append(f"{ratio:.1f}x more sharp turns than normal")

        if deviations:
            return "Unusual trip: " + "; ".join(deviations)
        return "This trip showed unusual patterns compared to your baseline"


# Global instance
anomaly_detector = AnomalyDetector()
