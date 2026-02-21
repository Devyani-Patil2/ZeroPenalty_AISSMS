"""
Driver Clustering using K-Means
Clusters drivers into: Cautious, Moderate, Aggressive
"""
import numpy as np
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler


class DriverClusterer:
    def __init__(self):
        self.model = KMeans(n_clusters=3, random_state=42, n_init=10)
        self.scaler = StandardScaler()
        self.cluster_labels = {0: "Cautious", 1: "Moderate", 2: "Aggressive"}
        self._is_trained = False

    def _extract_features(self, trips: list) -> np.ndarray:
        """Extract features from a list of trip dicts."""
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
            ])
        return np.array(features)

    def train(self, all_trips: list):
        """Train on all available trip data."""
        if len(all_trips) < 3:
            return
        X = self._extract_features(all_trips)
        X_scaled = self.scaler.fit_transform(X)
        self.model.fit(X_scaled)

        # Re-order clusters so 0=Cautious (highest score), 2=Aggressive (lowest)
        centers = self.model.cluster_centers_
        score_idx = 6  # local_score is the last feature
        order = np.argsort(-centers[:, score_idx])  # descending by score
        label_map = {old: new for new, old in enumerate(order)}
        self.cluster_labels = {
            label_map.get(0, 0): "Cautious",
            label_map.get(1, 1): "Moderate",
            label_map.get(2, 2): "Aggressive",
        }
        self._is_trained = True

    def predict(self, driver_trips: list) -> str:
        """Predict cluster label for a driver based on their trips."""
        if not self._is_trained or len(driver_trips) == 0:
            avg_score = np.mean([t.get("local_score", 100) for t in driver_trips]) if driver_trips else 100
            if avg_score >= 80:
                return "Cautious"
            elif avg_score >= 50:
                return "Moderate"
            else:
                return "Aggressive"

        # Aggregate driver's trips into a single feature vector (mean)
        X = self._extract_features(driver_trips)
        X_mean = X.mean(axis=0).reshape(1, -1)
        X_scaled = self.scaler.transform(X_mean)
        cluster_id = self.model.predict(X_scaled)[0]
        return self.cluster_labels.get(cluster_id, "Moderate")


# Global instance
driver_clusterer = DriverClusterer()
