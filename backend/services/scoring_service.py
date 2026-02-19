"""
ML-Enhanced Scoring Service
Combines local rule-based score with ML predictions
"""
import numpy as np


class ScoringService:
    # Base penalties per event type
    BASE_PENALTIES = {
        "overspeed": 5,
        "harsh_brake": 3,
        "sharp_turn": 2,
        "rash_accel": 3,
    }

    # Zone multipliers
    ZONE_MULTIPLIERS = {
        "HIGH_RISK": 2.0,
        "MEDIUM_RISK": 1.5,
        "LOW_RISK": 1.0,
    }

    @staticmethod
    def calculate_local_score(events: list) -> float:
        """Calculate rule-based score from event list."""
        total_deduction = 0.0
        for event in events:
            event_type = event.get("event_type", "")
            zone_type = event.get("zone_type", "LOW_RISK")

            base = ScoringService.BASE_PENALTIES.get(event_type, 2)
            multiplier = ScoringService.ZONE_MULTIPLIERS.get(zone_type, 1.0)
            total_deduction += base * multiplier

        score = max(0, 100 - total_deduction)
        return round(score, 1)

    @staticmethod
    def calculate_ml_score(local_score: float, risk_prediction: str,
                           is_anomaly: bool, cluster: str) -> float:
        """
        Combine local score with ML insights for an enhanced score.
        ML score adjusts the local score based on:
        - Risk prediction alignment
        - Anomaly detection
        - Driver cluster context
        """
        ml_score = local_score

        # Adjust based on predicted risk vs actual score
        if risk_prediction == "High" and local_score > 60:
            ml_score -= 5  # ML thinks it's riskier than the score shows
        elif risk_prediction == "Low" and local_score < 80:
            ml_score += 3  # ML thinks driver is better than events suggest

        # Anomaly penalty
        if is_anomaly:
            ml_score -= 5

        # Cluster context bonus - reward consistent safe drivers
        if cluster == "Cautious" and local_score >= 70:
            ml_score += 3
        elif cluster == "Aggressive" and local_score < 60:
            ml_score -= 2

        ml_score = max(0, min(100, ml_score))
        return round(ml_score, 1)

    @staticmethod
    def calculate_points(score: float) -> int:
        """Calculate reward points from score."""
        return int(score * 1.5)

    @staticmethod
    def get_tier(avg_score: float) -> str:
        """Get tier based on average score."""
        if avg_score >= 80:
            return "Safe Driver"
        elif avg_score >= 50:
            return "Improving"
        else:
            return "Risky"

    @staticmethod
    def get_color_grade(score: float) -> str:
        """Get color grade for a score."""
        if score >= 80:
            return "green"
        elif score >= 50:
            return "yellow"
        else:
            return "red"


scoring_service = ScoringService()
