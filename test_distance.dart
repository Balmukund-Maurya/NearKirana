import 'package:latlong2/latlong.dart';

void main() {
  final p1 = const LatLng(28.6139, 77.2090);
  final p2 = const LatLng(28.6140, 77.2090); // slightly different, should be ~11 meters
  
  final dist = const Distance().as(LengthUnit.Meter, p1, p2);
  final dist2 = const Distance().distance(p1, p2);
  
  print('as: $dist');
  print('distance: $dist2');
}
