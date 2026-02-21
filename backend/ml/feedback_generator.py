"""
Smart Feedback Generator
Combines ML cluster info + event patterns to generate personalized coaching
"""


FEEDBACK_RULES = [
    # (condition_fn, feedback_template)
    {
        "condition": lambda t: t.get("overspeed_count", 0) >= 3 and t.get("high_risk_events", 0) >= 2,
        "feedback": "You had {overspeed_count} overspeeding events in high-risk zones like school areas. "
                    "Try maintaining the posted speed limit of 25 km/h near schools and hospitals.",
        "priority": 10,
    },
    {
        "condition": lambda t: t.get("overspeed_count", 0) >= 3 and t.get("medium_risk_events", 0) >= 2,
        "feedback": "Multiple overspeeding events detected in residential areas. "
                    "Consider keeping your speed under 40 km/h in these zones.",
        "priority": 8,
    },
    {
        "condition": lambda t: t.get("overspeed_count", 0) >= 5,
        "feedback": "You exceeded the speed limit {overspeed_count} times during this trip. "
                    "Try using cruise control on highways to maintain a steady speed.",
        "priority": 7,
    },
    {
        "condition": lambda t: t.get("harsh_brake_count", 0) >= 3,
        "feedback": "Frequent harsh braking detected ({harsh_brake_count} times). "
                    "Maintain a safe following distance and anticipate traffic ahead.",
        "priority": 8,
    },
    {
        "condition": lambda t: t.get("sharp_turn_count", 0) >= 3,
        "feedback": "Multiple sharp turns detected ({sharp_turn_count} times). "
                    "Slow down before turns and use smoother steering inputs.",
        "priority": 6,
    },
    {
        "condition": lambda t: t.get("rash_accel_count", 0) >= 3,
        "feedback": "Rapid acceleration detected {rash_accel_count} times. "
                    "Gradual acceleration is safer and more fuel-efficient.",
        "priority": 6,
    },
    {
        "condition": lambda t: t.get("local_score", 100) >= 90,
        "feedback": "Excellent driving! Your score of {local_score:.0f} shows great awareness. Keep it up! 🌟",
        "priority": 5,
    },
    {
        "condition": lambda t: t.get("local_score", 100) >= 70,
        "feedback": "Good trip overall! Focus on reducing the events flagged above for an even better score.",
        "priority": 3,
    },
    {
        "condition": lambda t: t.get("local_score", 100) < 50,
        "feedback": "This trip had several safety concerns. Consider taking a break if you're tired, "
                    "and focus on one improvement area at a time.",
        "priority": 9,
    },
]

CLUSTER_ADVICE = {
    "Aggressive": [
        "Your driving pattern is classified as Aggressive. Focus on speed control and smoother maneuvers.",
        "Consider planning extra travel time — rushing leads to aggressive driving.",
    ],
    "Moderate": [
        "You're an improving driver! Consistent focus on speed limits will help you reach Safe Driver tier.",
    ],
    "Cautious": [
        "You're a cautious driver — great job! Keep maintaining these safe habits.",
    ],
}


class FeedbackGenerator:
    def generate(self, trip: dict, cluster_label: str = "Moderate") -> list:
        """Generate personalized feedback for a trip."""
        applicable = []

        for rule in FEEDBACK_RULES:
            try:
                if rule["condition"](trip):
                    text = rule["feedback"].format(**trip)
                    applicable.append((rule["priority"], text))
            except (KeyError, ValueError):
                continue

        # Sort by priority descending and take top 3
        applicable.sort(key=lambda x: x[0], reverse=True)
        feedback = [text for _, text in applicable[:3]]

        # Add cluster-based advice
        cluster_advice = CLUSTER_ADVICE.get(cluster_label, [])
        if cluster_advice:
            feedback.append(cluster_advice[0])

        # Ensure at least one feedback item
        if not feedback:
            feedback.append("Complete more trips to receive personalized coaching insights.")

        return feedback


# Global instance
feedback_generator = FeedbackGenerator()
