import 'dart:math' as math;
// ignore: library_prefixes
import 'package:geocoding/geocoding.dart' as geoCoding;
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static LocationService? _instance;
  static LocationService get instance => _instance ??= LocationService._();

  LocationService._();

  final Location _location = Location();

  Future<bool> requestPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  Future<bool> isLocationEnabled() async {
    return await _location.serviceEnabled();
  }

  Future<bool> enableLocationService() async {
    return await _location.requestService();
  }

  Future <LocationData?> getCurrentLocation() async{
    try{
      final hasPermission = await requestPermission();
      if(!hasPermission) return null;

      final isEnabled = await isLocationEnabled();
      if(!isEnabled){
        final enabled = await enableLocationService();
        if(!enabled) return null;
      }

      return await _location.getLocation();
    } catch(e){
      print('Error getting location: $e');
      return null;
    }
  }

  Future <String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try{
      final placemarks = await geoCoding.placemarkFromCoordinates(latitude,longitude);

      if(placemarks.isNotEmpty){
        final placemark = placemarks.first;
        return '${placemark.name}, ${placemark.subLocality},'
        '${placemark.locality}, ${placemark.administrativeArea}';
      }

      return null;
    } catch (e) {
      print('Error getting address:$e');
      return null;
    }
  }

  Stream <LocationData> getLocationStream(){
    return _location.onLocationChanged;
  }

  double calculateDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ){
    //using haversine formula
    const double earthRadius = 6371; //Earth's radius in km

    final double dlat = _toRadians(lat2 - lat1);
    final double dlon = _toRadians(lon2 - lon1);

    final double a = (dlat / 2).sin() * (dlat / 2).sin() + lat1.cos() * lat2.cos() * (dlon / 2).sin() * (dlon / 2).sin();

    final double c = 2 * a.sqrt().asin();

    return earthRadius * c;

  }

  double _toRadians(double degree){
    return degree * (3.141592653589793 / 180);
  }
}

extension on double{
    double sin() => math.sin(this);
    double cos() => math.cos(this);
    double sqrt() => math.sqrt(this);
    double asin() => math.asin(this);
}