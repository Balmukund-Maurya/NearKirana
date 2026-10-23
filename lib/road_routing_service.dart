import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Represents a turn-by-turn road route calculated along actual streets
class RoadRouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final String? primaryRoadName;

  const RoadRouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    this.primaryRoadName,
  });

  int get etaMinutes => (durationSeconds / 60).ceil().clamp(1, 180);

  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  String get formattedEta {
    final mins = etaMinutes;
    if (mins <= 2) return '1–2 mins';
    return '$mins mins';
  }
}

/// Service to fetch authentic road routes along real streets (OSRM / OpenStreetMap)
/// Provides exact road geometries, turn-by-turn curves, and traffic travel approximations.
class RoadRoutingService {
  static final RoadRoutingService _instance = RoadRoutingService._internal();
  factory RoadRoutingService() => _instance;
  RoadRoutingService._internal();

  final Map<String, RoadRouteResult> _cache = {};

  /// Fetches road geometry connecting [start] to [end] along actual streets.
  /// Falls back gracefully to null if offline or endpoint is unreachable.
  Future<RoadRouteResult?> fetchRoadRoute({
    required LatLng start,
    required LatLng end,
  }) async {
    // Cache key rounded to ~10 meters to prevent duplicate fetches on slight jitter
    final startKey =
        '${start.latitude.toStringAsFixed(4)},${start.longitude.toStringAsFixed(4)}';
    final endKey =
        '${end.latitude.toStringAsFixed(4)},${end.longitude.toStringAsFixed(4)}';
    final cacheKey = '$startKey->$endKey';

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 'Ok' &&
            data['routes'] is List &&
            (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final double distance = (route['distance'] as num?)?.toDouble() ?? 0.0;
          final double duration = (route['duration'] as num?)?.toDouble() ?? 0.0;
          final List rawCoords = route['geometry']?['coordinates'] ?? [];

          final List<LatLng> points = rawCoords.map<LatLng>((c) {
            final double lng = (c[0] as num).toDouble();
            final double lat = (c[1] as num).toDouble();
            return LatLng(lat, lng);
          }).toList();

          if (points.isNotEmpty) {
            final result = RoadRouteResult(
              points: points,
              distanceMeters: distance,
              durationSeconds: duration,
            );
            _cache[cacheKey] = result;
            return result;
          }
        }
      }
    } catch (e) {
      debugPrint('[RoadRouting] Notice: Using direct route fallback ($e)');
    }
    return null;
  }
}
