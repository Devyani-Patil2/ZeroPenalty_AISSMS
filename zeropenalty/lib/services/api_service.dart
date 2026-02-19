import 'package:dio/dio.dart';
import '../utils/constants.dart';

/// HTTP client for Python backend API
class ApiService {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConstants.apiBaseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));

  /// Upload trip data and get ML analysis
  static Future<Map<String, dynamic>?> uploadTrip(Map<String, dynamic> tripData) async {
    try {
      final response = await _dio.post('/api/trips', data: tripData);
      return response.data;
    } catch (e) {
      print('API Error (uploadTrip): $e');
      return null;
    }
  }

  /// Get ML analysis for a trip
  static Future<Map<String, dynamic>?> getTripAnalysis(int tripId) async {
    try {
      final response = await _dio.get('/api/trips/$tripId/analysis');
      return response.data;
    } catch (e) {
      print('API Error (getTripAnalysis): $e');
      return null;
    }
  }

  /// Get analytics summary
  static Future<Map<String, dynamic>?> getAnalyticsSummary(int driverId) async {
    try {
      final response = await _dio.get('/api/analytics/summary/$driverId');
      return response.data;
    } catch (e) {
      print('API Error (getAnalyticsSummary): $e');
      return null;
    }
  }

  /// Get driver profile
  static Future<Map<String, dynamic>?> getDriverProfile(int driverId) async {
    try {
      final response = await _dio.get('/api/analytics/profile/$driverId');
      return response.data;
    } catch (e) {
      print('API Error (getDriverProfile): $e');
      return null;
    }
  }

  /// Get ML feedback for a trip
  static Future<Map<String, dynamic>?> getFeedback(int tripId) async {
    try {
      final response = await _dio.get('/api/feedback/$tripId');
      return response.data;
    } catch (e) {
      print('API Error (getFeedback): $e');
      return null;
    }
  }
}
