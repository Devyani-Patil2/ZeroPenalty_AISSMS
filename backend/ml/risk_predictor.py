"""
Risk Predictor using Random Forest
Predicts risk level for a trip based on features
"""
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import LabelEncoder


class RiskPredictor:
    def __init__(self):
        self.model = RandomForestClassifier(n_estimators=50, random_state=42)
        self.label_encoder = LabelEncoder()
        self._is_trained = False

    def _extract_features(self, trips: list) -> np.ndarray:
        features = []
        for t in trips:
            hour = 12
            if "start_time" in t and t["start_time"]:
                try:
                    from datetime import datetime
                    dt = datetime.fromisoformat(t["start_time"])
                    hour = dt.hour
                except Exception:
                    pass

            features.append([
                hour,
                t.get("avg_speed", 0),
                t.get("max_speed", 0),
                t.get("overspeed_count", 0),
                t.get("harsh_brake_count", 0),
                t.get("sharp_turn_count", 0),
                t.get("rash_accel_count", 0),
                t.get("high_risk_events", 0),
                t.get("medium_risk_events", 0),
                t.get("distance_km", 0),
            ])
        return np.array(features)

    def _score_to_risk(self, score: float) -> str:
        if score >= 80:
            return "Low"
        elif score >= 50:
            return "Medium"
        else:
            return "High"

    def train(self, trips: list):
        if len(trips) < 5:
            return
        X = self._extract_features(trips)
        y = [self._score_to_risk(t.get("local_score", 100)) for t in trips]
        y_encoded = self.label_encoder.fit_transform(y)
        self.model.fit(X, y_encoded)
        self._is_trained = True

    def predict(self, trip: dict) -> str:
        if not self._is_trained:
            return self._score_to_risk(trip.get("local_score", 100))

        X = self._extract_features([trip])
        pred = self.model.predict(X)[0]
        return self.label_encoder.inverse_transform([pred])[0]

    def predict_proba(self, trip: dict) -> dict:
        if not self._is_trained:
            risk = self._score_to_risk(trip.get("local_score", 100))
            return {"Low": 0.0, "Medium": 0.0, "High": 0.0, risk: 1.0}

        X = self._extract_features([trip])
        proba = self.model.predict_proba(X)[0]
        classes = self.label_encoder.classes_
        return {cls: float(p) for cls, p in zip(classes, proba)}


# Global instance
risk_predictor = RiskPredictor()
