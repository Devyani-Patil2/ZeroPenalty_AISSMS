import '../models/trip.dart';

/// Local rule-based feedback generator
class FeedbackEngine {
  static List<String> generateFeedback(Trip trip) {
    final feedback = <String>[];

    // Overspeed in high-risk zones
    if (trip.overspeedCount >= 2 && trip.highRiskEvents >= 1) {
      feedback.add(
        '🏫 You had ${trip.overspeedCount} overspeeding events near schools/hospitals. '
        'Maintain 25 km/h in these sensitive areas.',
      );
    }
    // General overspeed
    else if (trip.overspeedCount >= 3) {
      feedback.add(
        '🚗 ${trip.overspeedCount} overspeeding events detected. '
        'Try staying within posted speed limits.',
      );
    }

    // Harsh braking
    if (trip.harshBrakeCount >= 3) {
      feedback.add(
        '🛑 Frequent harsh braking (${trip.harshBrakeCount} times). '
        'Keep a safe following distance to brake smoothly.',
      );
    }

    // Sharp turns
    if (trip.sharpTurnCount >= 3) {
      feedback.add(
        '↩️ Multiple sharp turns detected (${trip.sharpTurnCount} times). '
        'Slow down before turns for smoother steering.',
      );
    }

    // Rash acceleration
    if (trip.rashAccelCount >= 3) {
      feedback.add(
        '🚀 Rapid acceleration detected ${trip.rashAccelCount} times. '
        'Gradual acceleration is safer and saves fuel.',
      );
    }

    // Score-based
    final score = trip.mlScore ?? trip.localScore;
    if (score >= 90) {
      feedback.add('🌟 Excellent driving! Keep up the great habits!');
    } else if (score >= 70) {
      feedback.add('👍 Good trip! Focus on the areas above to improve further.');
    } else if (score < 50) {
      feedback.add(
        '⚠️ This trip had safety concerns. Take breaks if tired, '
        'and focus on one improvement at a time.',
      );
    }

    if (feedback.isEmpty) {
      feedback.add('✅ No significant issues detected. Keep driving safely!');
    }

    return feedback;
  }
}
