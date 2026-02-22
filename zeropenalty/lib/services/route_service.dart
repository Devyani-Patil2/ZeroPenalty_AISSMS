import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

class RouteService {
  // Free API Key from https://openrouteservice.org/
  // The user can add their own key here.
  static const String _apiKey =
      '5b3ce3597851110001cf6248d689626359be4327a3c74902161b3699'; // Placeholder/Demo Key
  static const String _baseUrl =
      'https://api.openrouteservice.org/v2/directions/driving-car';

  final Dio _dio = Dio();

  /// Fetches a road-snapped path between start and end coordinates.
  /// Returns a list of LatLng points.
  Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    try {
      final response = await _dio.get(
        _baseUrl,
        queryParameters: {
          'api_key': _apiKey,
          'start': '${start.longitude},${start.latitude}',
          'end': '${end.longitude},${end.latitude}',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> coords =
            response.data['features'][0]['geometry']['coordinates'];
        return coords
            .map((c) => LatLng(c[1] as double, c[0] as double))
            .toList();
      } else {
        throw Exception('Failed to fetch route: ${response.statusCode}');
      }
    } catch (e) {
      print('RouteService Error: $e');
      return []; // Return empty on error
    }
  }
}
