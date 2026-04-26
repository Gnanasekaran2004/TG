// ============================================================================
// Trip-GUY — Travel Super-App
// Copyright (c) 2026 Gnanasekaran D. All Rights Reserved.
//
// PROPRIETARY AND CONFIDENTIAL
//
// This source code and all associated files are the exclusive intellectual
// property of Gnanasekaran D. Unauthorized copying, modification, distribution,
// or use of this file, via any medium, is strictly prohibited.
//
// Contact : sgnana238@gmail.com | +91 8248094569
// Country : India
// License : See LICENSE file at the project root for full terms.
// ============================================================================
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trip_guy/features/social/data/datasources/firebase_trip_datasource.dart';
import '../../../../core/theme/colors.dart';
import '../../../../injection_container.dart' as di;

// ─── Map Style URLs ──────────────────────────────────────────────────────────
// Liberty style: most detailed — shows small streets, neighborhoods, POIs
const _styleLight = 'https://tiles.openfreemap.org/styles/liberty';
const _styleDark  = 'https://tiles.openfreemap.org/styles/dark';

// ─── Enums / Models ──────────────────────────────────────────────────────────
enum MapLayer  { standard, dark }
enum MapMode   { explore, navigate }

/// 12 POI categories covering everyday needs
enum PoiCategory {
  hotels, food, sights, transport, medical,
  pharmacy, atm, petrol, police, parks, shopping, airport,
}

extension PoiExt on PoiCategory {
  String get label => const {
    PoiCategory.hotels:    'Hotels',
    PoiCategory.food:      'Restaurants',
    PoiCategory.sights:    'Sights',
    PoiCategory.transport: 'Transit',
    PoiCategory.medical:   'Hospitals',
    PoiCategory.pharmacy:  'Pharmacy',
    PoiCategory.atm:       'ATMs',
    PoiCategory.petrol:    'Petrol',
    PoiCategory.police:    'Police',
    PoiCategory.parks:     'Parks',
    PoiCategory.shopping:  'Shopping',
    PoiCategory.airport:   'Airport',
  }[this]!;

  IconData get icon => const {
    PoiCategory.hotels:    Icons.hotel_outlined,
    PoiCategory.food:      Icons.restaurant_outlined,
    PoiCategory.sights:    Icons.camera_alt_outlined,
    PoiCategory.transport: Icons.directions_transit_outlined,
    PoiCategory.medical:   Icons.local_hospital_outlined,
    PoiCategory.pharmacy:  Icons.local_pharmacy_outlined,
    PoiCategory.atm:       Icons.atm_outlined,
    PoiCategory.petrol:    Icons.local_gas_station_outlined,
    PoiCategory.police:    Icons.local_police_outlined,
    PoiCategory.parks:     Icons.park_outlined,
    PoiCategory.shopping:  Icons.shopping_bag_outlined,
    PoiCategory.airport:   Icons.flight_outlined,
  }[this]!;

  Color get color => const {
    PoiCategory.hotels:    Color(0xFF6C63FF),
    PoiCategory.food:      Color(0xFFf7971e),
    PoiCategory.sights:    Color(0xFF11998e),
    PoiCategory.transport: Color(0xFF8E2DE2),
    PoiCategory.medical:   Color(0xFFFF5252),
    PoiCategory.pharmacy:  Color(0xFF00b09b),
    PoiCategory.atm:       Color(0xFF2196F3),
    PoiCategory.petrol:    Color(0xFFFF6F00),
    PoiCategory.police:    Color(0xFF1565C0),
    PoiCategory.parks:     Color(0xFF43A047),
    PoiCategory.shopping:  Color(0xFFE91E63),
    PoiCategory.airport:   Color(0xFF0097A7),
  }[this]!;

  String get hexColor => const {
    PoiCategory.hotels:    '#6C63FF',
    PoiCategory.food:      '#f7971e',
    PoiCategory.sights:    '#11998e',
    PoiCategory.transport: '#8E2DE2',
    PoiCategory.medical:   '#FF5252',
    PoiCategory.pharmacy:  '#00b09b',
    PoiCategory.atm:       '#2196F3',
    PoiCategory.petrol:    '#FF6F00',
    PoiCategory.police:    '#1565C0',
    PoiCategory.parks:     '#43A047',
    PoiCategory.shopping:  '#E91E63',
    PoiCategory.airport:   '#0097A7',
  }[this]!;

  /// Overpass API query for this category (uses `around` radius in metres)
  String overpassQuery(double lat, double lng, int radius) {
    final area = '(around:$radius,$lat,$lng)';
    switch (this) {
      case PoiCategory.hotels:
        return 'node["tourism"~"hotel|guest_house|hostel|motel"]$area;';
      case PoiCategory.food:
        return 'node["amenity"~"restaurant|cafe|fast_food|food_court|bar|pub"]$area;';
      case PoiCategory.sights:
        return 'node["tourism"~"attraction|museum|viewpoint|monument|gallery|zoo|theme_park"]$area;';
      case PoiCategory.transport:
        return 'node["public_transport"~"station|stop_position"]["name"]$area;'
            'node["amenity"~"bus_station|ferry_terminal"]["name"]$area;';
      case PoiCategory.medical:
        return 'node["amenity"~"hospital|clinic|doctors"]["name"]$area;';
      case PoiCategory.pharmacy:
        return 'node["amenity"="pharmacy"]$area;';
      case PoiCategory.atm:
        return 'node["amenity"="atm"]$area;node["amenity"="bank"]["atm"="yes"]$area;';
      case PoiCategory.petrol:
        return 'node["amenity"="fuel"]$area;';
      case PoiCategory.police:
        return 'node["amenity"~"police|fire_station"]$area;';
      case PoiCategory.parks:
        return 'node["leisure"~"park|garden|playground|nature_reserve"]["name"]$area;'
            'way["leisure"~"park|garden"]["name"]$area;';
      case PoiCategory.shopping:
        return 'node["shop"~"supermarket|mall|department_store|convenience|clothes|electronics"]$area;';
      case PoiCategory.airport:
        return 'node["aeroway"~"aerodrome|terminal"]["name"]$area;'
            'way["aeroway"="aerodrome"]["name"]$area;';
    }
  }
}

class _Place {
  final String name;
  final double lat, lon;
  final String type;
  final String country;
  const _Place(this.name, this.lat, this.lon, {this.type = '', this.country = ''});
}

class _Poi {
  final String name;
  final LatLng pos;
  final PoiCategory cat;
  final String? phone;
  final String? website;
  const _Poi(this.name, this.pos, this.cat, {this.phone, this.website});
}

class _RouteStep {
  final String instruction;
  final String distance;
  final IconData icon;
  const _RouteStep(this.instruction, this.distance, this.icon);
}

// ─── Main Page ───────────────────────────────────────────────────────────────
class LiveMapPage extends StatefulWidget {
  const LiveMapPage({super.key});
  @override
  State<LiveMapPage> createState() => _LiveMapPageState();
}

class _LiveMapPageState extends State<LiveMapPage> {
  MapLibreMapController? _ctrl;
  bool _mapReady = false;

  late final Stream<QuerySnapshot> _userTripsStream;

  MapMode  _mode  = MapMode.explore;
  MapLayer _layer = MapLayer.standard;
  bool _show3dBuildings = false;

  // GPS
  LatLng? _userPos;
  bool _isLocating  = false;
  bool _isTracking  = false;
  MyLocationTrackingMode _trackingMode = MyLocationTrackingMode.none;
  StreamSubscription<Position>? _trackSub;

  // Explore
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  bool _isSearching   = false;
  bool _showResults   = false;
  List<_Place> _searchResults  = [];
  final List<_Place> _recentSearches = [];   // last 5 recent places
  LatLng? _pinnedPos;
  String? _pinnedName;
  PoiCategory? _activeCategory;
  List<_Poi> _dynamicPois    = [];
  bool _isLoadingPois = false;

  // Navigate
  final _fromCtrl = TextEditingController();
  final _toCtrl   = TextEditingController();
  LatLng? _fromPos, _toPos;
  String? _fromName, _toName;
  bool _editingFrom    = true;
  bool _isNavSearching = false;
  List<_Place> _navResults    = [];
  bool _showNavResults        = false;
  List<LatLng> _routePts      = [];
  String? _routeDist, _routeTime;
  bool _isRouting             = false;
  List<_RouteStep> _routeSteps = [];

  // Reverse geocode on map tap
  bool _isReverseGeocoding = false;

  // Layer handles
  Line?   _routeLine;
  Symbol? _pinnedSymbol;
  Symbol? _fromSymbol;
  Symbol? _toSymbol;
  List<Circle>  _poiCircles  = [];
  List<Circle>  _tripCircles = [];
  List<Symbol>  _tripLabels  = [];

  List<QueryDocumentSnapshot> _lastTrips = [];

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _userTripsStream = di.sl<FirebaseTripDataSource>().streamUserTrips(uid);
  }

  @override
  void dispose() {
    _trackSub?.cancel();
    _searchCtrl.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ─── onMapCreated ────────────────────────────────────────────────────────
  void _onMapCreated(MapLibreMapController controller) {
    _ctrl = controller;
    _ctrl!.onCircleTapped.add(_onCircleTapped);
    _ctrl!.onSymbolTapped.add(_onSymbolTapped);
    setState(() => _mapReady = true);
    _redrawTripMarkers(_lastTrips);
  }

  void _onStyleLoaded() {
    if (_show3dBuildings) {
      _ctrl?.setLayerVisibility('building-3d', true).catchError((_) {});
    }
    _redrawRoute();
    _redrawPois();
    _redrawPins();
    _redrawTripMarkers(_lastTrips);
  }

  // ─── Distance utils ──────────────────────────────────────────────────────
  double _distanceKm(LatLng a, LatLng b) {
    const R = 6371.0;
    final lat1 = a.latitude  * math.pi / 180;
    final lat2 = b.latitude  * math.pi / 180;
    final dLat = (b.latitude  - a.latitude)  * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final x = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return R * 2 * math.atan2(math.sqrt(x), math.sqrt(1 - x));
  }

  String _fmtDist(double km) =>
      km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';

  // ─── Destination → LatLng (extended city list) ───────────────────────────
  LatLng _getCoordinates(String dest) {
    final d = dest.toLowerCase();
    const cities = <String, LatLng>{
      'paris':       LatLng(48.8566, 2.3522),    'france':      LatLng(46.2276, 2.2137),
      'tokyo':       LatLng(35.6762, 139.6503),  'japan':       LatLng(36.2048, 138.2529),
      'rome':        LatLng(41.9028, 12.4964),   'italy':       LatLng(41.8719, 12.5674),
      'bali':        LatLng(-8.4095, 115.1889),  'indonesia':   LatLng(-0.7893, 113.9213),
      'london':      LatLng(51.5074, -0.1278),
      'new york':    LatLng(40.7128, -74.0060),  'new delhi':   LatLng(28.6139, 77.2090),
      'delhi':       LatLng(28.6139, 77.2090),   'india':       LatLng(20.5937, 78.9629),
      'dubai':       LatLng(25.2048, 55.2708),   'uae':         LatLng(23.4241, 53.8478),
      'bangkok':     LatLng(13.7563, 100.5018),  'thailand':    LatLng(15.8700, 100.9925),
      'singapore':   LatLng(1.3521, 103.8198),
      'sydney':      LatLng(-33.8688, 151.2093), 'australia':   LatLng(-25.2744, 133.7751),
      'mumbai':      LatLng(19.0760, 72.8777),   'chennai':     LatLng(13.0827, 80.2707),
      'bangalore':   LatLng(12.9716, 77.5946),   'bengaluru':   LatLng(12.9716, 77.5946),
      'hyderabad':   LatLng(17.3850, 78.4867),   'kolkata':     LatLng(22.5726, 88.3639),
      'pune':        LatLng(18.5204, 73.8567),   'ahmedabad':   LatLng(23.0225, 72.5714),
      'jaipur':      LatLng(26.9124, 75.7873),   'rajasthan':   LatLng(27.0238, 74.2179),
      'goa':         LatLng(15.2993, 74.1240),   'kerala':      LatLng(10.8505, 76.2711),
      'kochi':       LatLng(9.9312, 76.2673),    'coimbatore':  LatLng(11.0168, 76.9558),
      'madurai':     LatLng(9.9252, 78.1198),    'trichy':      LatLng(10.7905, 78.7047),
      'swiss':       LatLng(46.8182, 8.2275),    'switzerland': LatLng(46.8182, 8.2275),
      'berlin':      LatLng(52.5200, 13.4050),   'germany':     LatLng(51.1657, 10.4515),
      'barcelona':   LatLng(41.3851, 2.1734),    'spain':       LatLng(40.4637, -3.7492),
      'amsterdam':   LatLng(52.3676, 4.9041),    'toronto':     LatLng(43.6532, -79.3832),
      'new zealand': LatLng(-40.9006, 174.8860), 'maldives':    LatLng(3.2028, 73.2207),
    };
    for (final k in cities.keys) {
      if (d.contains(k)) return cities[k]!;
    }
    return const LatLng(20.0, 0.0);
  }

  String _tripHexColor(String cat) => const {
    'Beach': '#FF6584', 'Cultural': '#8E2DE2',
    'Road Trip': '#f7971e', 'Cruise': '#11998e', 'Business': '#2C3E50',
  }[cat] ?? '#6C63FF';

  // ─── GPS ────────────────────────────────────────────────────────────────
  Future<void> _locateMe() async {
    if (!_mapReady) return;
    setState(() => _isLocating = true);
    try {
      bool svc = await Geolocator.isLocationServiceEnabled();
      if (!svc) { _snack('Please enable GPS/Location.'); return; }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) { _snack('Location permission denied.'); return; }
      }
      if (perm == LocationPermission.deniedForever) {
        _snack('Location denied permanently — enable in Settings.'); return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 20));
      final pt = LatLng(pos.latitude, pos.longitude);
      setState(() => _userPos = pt);
      await _ctrl!.animateCamera(CameraUpdate.newLatLngZoom(pt, 15.5));
      _snack('Location found!', success: true);
      // Auto-fetch nearby places after locating
      await _autoFetchNearby(pt);
    } catch (_) {
      _snack('Could not find location. Try again.');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  /// Auto-fetch restaurants + medical nearby when GPS is first found
  Future<void> _autoFetchNearby(LatLng pt) async {
    // Only show if not already browsing a category
    if (_activeCategory != null) return;
    setState(() { _isLoadingPois = true; _dynamicPois = []; });
    await _removePois();
    try {
      final q = '[out:json][timeout:12];('
          '${PoiCategory.food.overpassQuery(pt.latitude, pt.longitude, 800)}'
          '${PoiCategory.medical.overpassQuery(pt.latitude, pt.longitude, 2000)}'
          '${PoiCategory.pharmacy.overpassQuery(pt.latitude, pt.longitude, 1000)}'
          ');out center 40;';
      final res = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'), body: q);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final pois = _parseOverpassElements(data['elements'] as List, null);
        if (mounted) {
          setState(() => _dynamicPois = pois);
          await _redrawPois();
          if (pois.isNotEmpty) _snack('Found ${pois.length} nearby places 📍', success: true);
        }
      }
    } catch (_) {}
    finally { if (mounted) setState(() => _isLoadingPois = false); }
  }

  Future<void> _toggleTracking() async {
    if (!_mapReady) return;
    if (_isTracking) {
      await _trackSub?.cancel();
      setState(() { _isTracking = false; _trackSub = null; _trackingMode = MyLocationTrackingMode.none; });
      await _ctrl!.updateMyLocationTrackingMode(MyLocationTrackingMode.none);
      return;
    }
    setState(() { _isTracking = true; _trackingMode = MyLocationTrackingMode.trackingGps; });
    await _ctrl!.updateMyLocationTrackingMode(MyLocationTrackingMode.trackingGps);
    _trackSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).listen((p) {
      if (!mounted) return;
      setState(() => _userPos = LatLng(p.latitude, p.longitude));
      _ctrl?.animateCamera(CameraUpdate.newLatLng(_userPos!));
    }, onError: (_) { if (mounted) setState(() => _isTracking = false); });
    _snack('Live tracking on', success: true);
  }

  // ─── Map tap → reverse geocode ──────────────────────────────────────────
  Future<void> _onMapTap(LatLng pos) async {
    if (_isReverseGeocoding) return;
    FocusScope.of(context).unfocus();
    setState(() { _isReverseGeocoding = true; _showResults = false; _showNavResults = false; });
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=${pos.latitude}&lon=${pos.longitude}'
        '&format=json&addressdetails=1&zoom=18',
      );
      final res = await http.get(uri, headers: {'User-Agent': 'TripGuyApp/1.0'});
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        _showAddressSheet(pos, data);
      }
    } catch (_) {
      _snack('Could not load address info.');
    } finally {
      if (mounted) setState(() => _isReverseGeocoding = false);
    }
  }

  void _showAddressSheet(LatLng pos, Map<String, dynamic> data) {
    final addr    = data['address'] as Map<String, dynamic>? ?? {};
    final name    = data['display_name']?.toString().split(',').first.trim() ?? 'Unknown';
    final road    = addr['road']      ?? addr['pedestrian'] ?? addr['path'] ?? '';
    final suburb  = addr['suburb']    ?? addr['neighbourhood'] ?? addr['quarter'] ?? '';
    final city    = addr['city']      ?? addr['town']   ?? addr['village'] ?? addr['county'] ?? '';
    final state   = addr['state']     ?? '';
    final country = addr['country']   ?? '';
    final postcode= addr['postcode']  ?? '';
    final type    = data['type']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 20)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.location_on, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (type.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.primary.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                  child: Text(type.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600)),
                ),
            ])),
            IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
          ]),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          // Address lines
          if (road.isNotEmpty)     _addrRow(Icons.signpost_outlined,      road),
          if (suburb.isNotEmpty)   _addrRow(Icons.location_city_outlined, suburb),
          if (city.isNotEmpty)     _addrRow(Icons.apartment_outlined,     '$city${postcode.isNotEmpty ? ' — $postcode' : ''}'),
          if (state.isNotEmpty)    _addrRow(Icons.map_outlined,           state),
          if (country.isNotEmpty)  _addrRow(Icons.public_outlined,        country),
          // Coords
          _addrRow(Icons.my_location, '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}'),
          if (_userPos != null)
            _addrRow(Icons.directions_walk_outlined,
              '${_fmtDist(_distanceKm(_userPos!, pos))} from you'),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _pinnedPos = pos; _pinnedName = name;
                  _activeCategory = null; _dynamicPois = [];
                });
                _ctrl?.animateCamera(CameraUpdate.newLatLngZoom(pos, 15.0));
                _redrawPins();
              },
              icon: const Icon(Icons.pin_drop_outlined, size: 16),
              label: const Text('Pin Location'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _mode = MapMode.navigate;
                  _toPos = pos; _toName = name; _toCtrl.text = name;
                });
              },
              icon: const Icon(Icons.directions, size: 16),
              label: const Text('Navigate'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            )),
          ]),
        ]),
      ),
    );
  }

  Widget _addrRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Icon(icon, size: 15, color: Colors.grey),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
    ]),
  );

  // ─── Search ──────────────────────────────────────────────────────────────
  void _onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(q, navigate: false));
  }

  void _onNavSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(q, navigate: true));
  }

  Future<void> _search(String q, {required bool navigate}) async {
    if (q.trim().isEmpty) {
      setState(() {
        if (navigate) { _navResults = []; _showNavResults = false; }
        else          { _searchResults = []; _showResults = false; }
      });
      return;
    }
    setState(() => navigate ? _isNavSearching = true : _isSearching = true);
    try {
      // limit=10 + addressdetails for richer results
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(q)}&format=json&limit=10&addressdetails=1&extratags=1',
      );
      final res = await http.get(uri, headers: {'User-Agent': 'TripGuyApp/1.0'});
      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List).map((e) {
          final addr = e['address'] as Map<String, dynamic>? ?? {};
          final country = addr['country']?.toString() ?? '';
          final type    = e['type']?.toString() ?? '';
          return _Place(
            e['display_name'] as String,
            double.parse(e['lat'] as String),
            double.parse(e['lon'] as String),
            type: type, country: country,
          );
        }).toList();
        setState(() {
          if (navigate) { _navResults = list; _showNavResults = list.isNotEmpty; }
          else          { _searchResults = list; _showResults = list.isNotEmpty; }
        });
      }
    } catch (_) {
      _snack('Search failed — check connection');
    } finally {
      if (mounted) setState(() { _isNavSearching = false; _isSearching = false; });
    }
  }

  Future<void> _pickExploreResult(_Place p) async {
    final pt   = LatLng(p.lat, p.lon);
    final name = p.name.split(',').first.trim();
    _addToRecent(p);
    setState(() {
      _pinnedPos = pt; _pinnedName = name;
      _showResults = false; _searchCtrl.text = name;
      _activeCategory = null; _dynamicPois = [];
    });
    FocusScope.of(context).unfocus();
    await _ctrl?.animateCamera(CameraUpdate.newLatLngZoom(pt, 14.5));
    _redrawPins();
    // Auto-load nearby POIs for searched location
    _fetchLivePoisAt(PoiCategory.food, pt);
  }

  void _pickNavResult(_Place p) {
    final pt   = LatLng(p.lat, p.lon);
    final name = p.name.split(',').first.trim();
    _addToRecent(p);
    setState(() {
      if (_editingFrom) { _fromPos = pt; _fromName = name; _fromCtrl.text = name; }
      else              { _toPos   = pt; _toName   = name; _toCtrl.text   = name; }
      _navResults = []; _showNavResults = false;
    });
    FocusScope.of(context).unfocus();
    if (_fromPos != null && _toPos != null) _getRoute();
  }

  void _addToRecent(_Place p) {
    _recentSearches.removeWhere((r) => r.name == p.name);
    _recentSearches.insert(0, p);
    if (_recentSearches.length > 5) _recentSearches.removeLast();
  }

  // ─── Routing with turn-by-turn steps ────────────────────────────────────
  Future<void> _getRoute() async {
    if (_fromPos == null || _toPos == null || !_mapReady) {
      _snack('Set both From and To locations'); return;
    }
    setState(() { _isRouting = true; _routePts = []; _routeDist = null; _routeTime = null; _routeSteps = []; });
    try {
      final url = 'https://router.project-osrm.org/route/v1/driving/'
          '${_fromPos!.longitude},${_fromPos!.latitude};'
          '${_toPos!.longitude},${_toPos!.latitude}'
          '?overview=full&geometries=geojson&steps=true&annotations=false';
      final res = await http.get(Uri.parse(url), headers: {'User-Agent': 'TripGuyApp/1.0'});
      if (res.statusCode == 200) {
        final data  = jsonDecode(res.body);
        if ((data['routes'] as List).isEmpty) { _snack('No route found'); return; }
        final route = data['routes'][0];
        final coords = route['geometry']['coordinates'] as List;
        final distM  = (route['distance'] as num).toDouble();
        final durS   = (route['duration'] as num).toDouble();
        final pts    = coords.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();

        // Parse turn-by-turn steps
        final legs  = route['legs'] as List;
        final steps = <_RouteStep>[];
        for (final leg in legs) {
          for (final step in (leg['steps'] as List)) {
            steps.add(_parseStep(step));
          }
        }

        setState(() {
          _routePts   = pts;
          _routeDist  = distM < 1000 ? '${distM.round()} m' : '${(distM / 1000).toStringAsFixed(1)} km';
          _routeTime  = durS  < 3600 ? '${(durS / 60).round()} min' : '${(durS / 3600).toStringAsFixed(1)} hr';
          _routeSteps = steps;
        });
        await _redrawRoute();
        if (pts.isNotEmpty) {
          double minLat = pts.map((p) => p.latitude).reduce(math.min);
          double maxLat = pts.map((p) => p.latitude).reduce(math.max);
          double minLng = pts.map((p) => p.longitude).reduce(math.min);
          double maxLng = pts.map((p) => p.longitude).reduce(math.max);
          await _ctrl!.animateCamera(CameraUpdate.newLatLngBounds(
            LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)),
            left: 60, top: 120, right: 60, bottom: 160,
          ));
        }
        _snack('Route: $_routeDist · $_routeTime', success: true);
      }
    } catch (_) {
      _snack('Could not get route');
    } finally {
      if (mounted) setState(() => _isRouting = false);
    }
  }

  _RouteStep _parseStep(Map<String, dynamic> step) {
    final maneuver  = step['maneuver'] as Map<String, dynamic>? ?? {};
    final type      = maneuver['type']?.toString() ?? 'continue';
    final modifier  = maneuver['modifier']?.toString() ?? '';
    final name      = step['name']?.toString() ?? '';
    final distM     = (step['distance'] as num?)?.toDouble() ?? 0;
    final dist      = distM < 1000 ? '${distM.round()} m' : '${(distM / 1000).toStringAsFixed(1)} km';
    String inst;
    IconData icon;
    switch (type) {
      case 'depart':  inst = 'Head ${modifier.isNotEmpty ? "$modifier " : ""}on ${name.isNotEmpty ? name : "the road"}'; icon = Icons.play_arrow; break;
      case 'arrive':  inst = 'Arrive at destination'; icon = Icons.flag; break;
      case 'turn':
        final dir = modifier == 'left' || modifier == 'slight left' || modifier == 'sharp left' ? 'left' : 'right';
        icon = dir == 'left' ? Icons.turn_left : Icons.turn_right;
        inst = 'Turn $modifier${name.isNotEmpty ? " onto $name" : ""}';
        break;
      case 'roundabout': inst = 'Enter roundabout${name.isNotEmpty ? " — $name" : ""}'; icon = Icons.roundabout_left; break;
      case 'merge':   inst = 'Merge ${modifier.isNotEmpty ? "$modifier " : ""}${name.isNotEmpty ? "onto $name" : ""}'; icon = Icons.merge; break;
      case 'fork':    inst = 'Keep $modifier${name.isNotEmpty ? " on $name" : ""}'; icon = Icons.fork_right; break;
      default:        inst = 'Continue${name.isNotEmpty ? " on $name" : ""}'; icon = Icons.straight;
    }
    return _RouteStep(inst, dist, icon);
  }

  void _showRouteSteps() {
    if (_routeSteps.isEmpty) { _snack('No steps available'); return; }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize:     0.3,
        maxChildSize:     0.9,
        builder: (_, sc) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            // Handle
            Container(margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(children: [
                const Icon(Icons.turn_right, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Turn-by-Turn · $_routeDist · $_routeTime',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
              ])),
            const Divider(height: 1),
            Expanded(child: ListView.builder(
              controller: sc,
              itemCount: _routeSteps.length,
              itemBuilder: (_, i) {
                final s = _routeSteps[i];
                return ListTile(
                  dense: true,
                  leading: Container(padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: AppColors.primary.withAlpha(15), shape: BoxShape.circle),
                    child: Icon(s.icon, color: AppColors.primary, size: 18)),
                  title: Text(s.instruction, style: const TextStyle(fontSize: 13)),
                  trailing: Text(s.distance, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                );
              },
            )),
          ]),
        ),
      ),
    );
  }

  // ─── Live POI fetch (Overpass API — radius-based) ────────────────────────
  Future<void> _fetchLivePois(PoiCategory cat) async {
    if (_activeCategory == cat) {
      setState(() { _activeCategory = null; _dynamicPois = []; });
      await _removePois();
      return;
    }
    final refPos = _pinnedPos ?? _userPos;
    if (refPos == null) {
      _snack('Locate yourself or search a place first.');
      return;
    }
    await _fetchLivePoisAt(cat, refPos);
  }

  Future<void> _fetchLivePoisAt(PoiCategory cat, LatLng center) async {
    setState(() { _activeCategory = cat; _isLoadingPois = true; _dynamicPois = []; });
    await _removePois();
    _snack('Scanning for ${cat.label} nearby...', success: true);
    try {
      const radius = 1500; // 1.5 km radius
      final q = '[out:json][timeout:15];(${cat.overpassQuery(center.latitude, center.longitude, radius)});out center 40;';
      final res = await http.post(Uri.parse('https://overpass-api.de/api/interpreter'), body: q);
      if (res.statusCode == 200) {
        final pois = _parseOverpassElements(jsonDecode(res.body)['elements'] as List, cat);
        // Sort by distance from reference
        if (_userPos != null) {
          pois.sort((a, b) => _distanceKm(_userPos!, a.pos).compareTo(_distanceKm(_userPos!, b.pos)));
        }
        if (mounted) {
          setState(() => _dynamicPois = pois);
          await _redrawPois();
          if (pois.isEmpty) {
            _snack('No ${cat.label} found nearby. Try zooming out.');
          } else {
            _snack('Found ${pois.length} ${cat.label} within 1.5 km', success: true);
          }
        }
      }
    } catch (_) {
      if (mounted) _snack('Failed to load ${cat.label}. Check connection.');
    } finally {
      if (mounted) setState(() => _isLoadingPois = false);
    }
  }

  List<_Poi> _parseOverpassElements(List elements, PoiCategory? cat) {
    final List<_Poi> result = [];
    for (final el in elements) {
      final lat  = (el['lat'] ?? el['center']?['lat']) as num?;
      final lon  = (el['lon'] ?? el['center']?['lon']) as num?;
      if (lat == null || lon == null) continue;
      final tags  = el['tags'] as Map? ?? {};
      final name  = tags['name']?.toString() ?? tags['amenity']?.toString() ?? '';
      if (name.isEmpty) continue;
      final phone   = tags['phone']?.toString() ?? tags['contact:phone']?.toString();
      final website = tags['website']?.toString() ?? tags['contact:website']?.toString();
      // Detect category from tags if not provided
      final resolvedCat = cat ?? _detectCategory(tags);
      result.add(_Poi(name, LatLng(lat.toDouble(), lon.toDouble()), resolvedCat,
          phone: phone, website: website));
    }
    return result;
  }

  PoiCategory _detectCategory(Map tags) {
    final amenity = tags['amenity']?.toString() ?? '';
    final tourism = tags['tourism']?.toString() ?? '';
    final shop    = tags['shop']?.toString()    ?? '';
    if (['restaurant','cafe','fast_food','bar','pub'].contains(amenity)) return PoiCategory.food;
    if (['hospital','clinic','doctors'].contains(amenity)) return PoiCategory.medical;
    if (amenity == 'pharmacy') return PoiCategory.pharmacy;
    if (amenity == 'fuel') return PoiCategory.petrol;
    if (amenity == 'atm' || amenity == 'bank') return PoiCategory.atm;
    if (['police','fire_station'].contains(amenity)) return PoiCategory.police;
    if (['hotel','guest_house','hostel','motel'].contains(tourism)) return PoiCategory.hotels;
    if (shop.isNotEmpty) return PoiCategory.shopping;
    return PoiCategory.sights;
  }

  // ─── Layer management ────────────────────────────────────────────────────
  Future<void> _redrawRoute() async {
    if (_ctrl == null) return;
    if (_routeLine   != null) { await _ctrl!.removeLine(_routeLine!);    _routeLine   = null; }
    if (_fromSymbol  != null) { await _ctrl!.removeSymbol(_fromSymbol!); _fromSymbol  = null; }
    if (_toSymbol    != null) { await _ctrl!.removeSymbol(_toSymbol!);   _toSymbol    = null; }
    if (_routePts.isNotEmpty) {
      _routeLine = await _ctrl!.addLine(LineOptions(
        geometry: _routePts, lineColor: '#2453E0', lineWidth: 5.0, lineOpacity: 0.95,
      ));
    }
    await _redrawPins();
  }

  Future<void> _redrawPins() async {
    if (_ctrl == null) return;
    if (_pinnedSymbol != null) { await _ctrl!.removeSymbol(_pinnedSymbol!); _pinnedSymbol = null; }
    if (_fromSymbol   != null) { await _ctrl!.removeSymbol(_fromSymbol!);   _fromSymbol   = null; }
    if (_toSymbol     != null) { await _ctrl!.removeSymbol(_toSymbol!);     _toSymbol     = null; }
    if (_pinnedPos != null && _mode == MapMode.explore) {
      _pinnedSymbol = await _ctrl!.addSymbol(SymbolOptions(
        geometry: _pinnedPos!, iconImage: 'marker-15', iconSize: 2.5, iconColor: '#8E2DE2',
        textField: _pinnedName ?? '', textOffset: const Offset(0, 2.0),
        textSize: 13.0, textColor: '#1A1A2E', textHaloColor: '#FFFFFF', textHaloWidth: 1.5,
      ));
    }
    if (_fromPos != null && _mode == MapMode.navigate) {
      _fromSymbol = await _ctrl!.addSymbol(SymbolOptions(
        geometry: _fromPos!, iconImage: 'marker-15', iconSize: 2.0, iconColor: '#00C48C',
        textField: _fromName ?? 'Start', textOffset: const Offset(0, 2.0),
        textSize: 12.0, textColor: '#005C2F', textHaloColor: '#FFFFFF', textHaloWidth: 1.5,
      ));
    }
    if (_toPos != null && _mode == MapMode.navigate) {
      _toSymbol = await _ctrl!.addSymbol(SymbolOptions(
        geometry: _toPos!, iconImage: 'marker-15', iconSize: 2.0, iconColor: '#FF4757',
        textField: _toName ?? 'End', textOffset: const Offset(0, 2.0),
        textSize: 12.0, textColor: '#7F0000', textHaloColor: '#FFFFFF', textHaloWidth: 1.5,
      ));
    }
  }

  Future<void> _removePois() async {
    if (_ctrl == null) return;
    for (final c in _poiCircles) {
      await _ctrl!.removeCircle(c);
    }
    _poiCircles = [];
  }

  Future<void> _redrawPois() async {
    await _removePois();
    if (_ctrl == null) return;
    for (final poi in _dynamicPois) {
      final c = await _ctrl!.addCircle(CircleOptions(
        geometry: poi.pos, circleRadius: 11.0,
        circleColor: poi.cat.hexColor,
        circleStrokeWidth: 2.0, circleStrokeColor: '#FFFFFF', circleOpacity: 0.92,
      ));
      _poiCircles.add(c);
    }
  }

  Future<void> _redrawTripMarkers(List<QueryDocumentSnapshot> trips) async {
    if (_ctrl == null) return;
    for (final c in _tripCircles) {
      await _ctrl!.removeCircle(c);
    }
    for (final s in _tripLabels) {
      await _ctrl!.removeSymbol(s);
    }
    _tripCircles = []; _tripLabels = [];
    for (final doc in trips) {
      final data  = doc.data() as Map<String, dynamic>;
      final dest  = data['destination']?.toString() ?? '';
      final title = data['title']?.toString() ?? 'Trip';
      final cat   = data['category']?.toString() ?? '';
      final hex   = _tripHexColor(cat);
      final pt    = _getCoordinates(dest);
      final circle = await _ctrl!.addCircle(CircleOptions(
        geometry: pt, circleRadius: 14.0, circleColor: hex,
        circleStrokeWidth: 2.5, circleStrokeColor: '#FFFFFF', circleOpacity: 0.9,
      ));
      _tripCircles.add(circle);
      final label = await _ctrl!.addSymbol(SymbolOptions(
        geometry: pt, textField: title, textOffset: const Offset(0, 2.5),
        textSize: 12.0, textColor: '#1A1A2E',
        textHaloColor: '#FFFFFF', textHaloWidth: 1.5, textMaxWidth: 8.0,
      ));
      _tripLabels.add(label);
    }
  }

  // ─── Circle tap ─────────────────────────────────────────────────────────
  void _onCircleTapped(Circle c) {
    final idx = _poiCircles.indexOf(c);
    if (idx >= 0 && idx < _dynamicPois.length) { _showPoiSheet(_dynamicPois[idx]); return; }
    final tidx = _tripCircles.indexOf(c);
    if (tidx >= 0 && tidx < _lastTrips.length) {
      final data = _lastTrips[tidx].data() as Map<String, dynamic>;
      _snack('📍 ${data['title']} → ${data['destination']}', success: true);
    }
  }

  void _onSymbolTapped(Symbol _) {}

  // ─── 3D Buildings toggle (style-native layer) ────────────────────────────
  Future<void> _toggle3d() async {
    if (_ctrl == null) return;
    setState(() => _show3dBuildings = !_show3dBuildings);
    try {
      await _ctrl!.setLayerVisibility('building-3d', _show3dBuildings);
    } catch (_) {}
    _snack(_show3dBuildings ? '3D buildings on (zoom ≥ 15)' : '3D buildings off',
        success: _show3dBuildings);
  }

  // ─── Clear helpers ────────────────────────────────────────────────────────
  void _clearExplore() {
    _searchCtrl.clear();
    setState(() {
      _pinnedPos = null; _pinnedName = null;
      _searchResults = []; _showResults = false;
      _activeCategory = null; _dynamicPois = [];
    });
    _removePois();
    if (_pinnedSymbol != null) { _ctrl?.removeSymbol(_pinnedSymbol!); _pinnedSymbol = null; }
    _ctrl?.animateCamera(CameraUpdate.newLatLngZoom(const LatLng(20.0, 30.0), 2.5));
  }

  void _clearRoute() {
    _fromCtrl.clear(); _toCtrl.clear();
    setState(() {
      _fromPos = null; _toPos = null; _fromName = null; _toName = null;
      _routePts = []; _routeDist = null; _routeTime = null; _routeSteps = [];
    });
    _redrawRoute();
  }

  void _snack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? Colors.green : null,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _userTripsStream,
      builder: (context, snapshot) {
        final trips = snapshot.data?.docs ?? [];
        if (_mapReady && trips.length != _lastTrips.length) {
          _lastTrips = trips;
          WidgetsBinding.instance.addPostFrameCallback((_) => _redrawTripMarkers(trips));
        } else {
          _lastTrips = trips;
        }

        final styleUrl = _layer == MapLayer.standard ? _styleLight : _styleDark;

        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            setState(() { _showResults = false; _showNavResults = false; });
          },
          child: Stack(children: [
            // ── MAP ──────────────────────────────────────────────────────
            MapLibreMap(
              styleString:           styleUrl,
              initialCameraPosition: const CameraPosition(target: LatLng(20.0, 30.0), zoom: 2.5),
              onMapCreated:          _onMapCreated,
              onStyleLoadedCallback: _onStyleLoaded,
              onMapClick:            (_, coords) => _onMapTap(coords),
              myLocationEnabled:      true,
              myLocationRenderMode:   MyLocationRenderMode.compass,
              myLocationTrackingMode: _trackingMode,
              tiltGesturesEnabled:   true,
              rotateGesturesEnabled: true,
              scrollGesturesEnabled: true,
              zoomGesturesEnabled:   true,
              compassEnabled:        true,
              attributionButtonPosition: AttributionButtonPosition.bottomLeft,
              minMaxZoomPreference:  const MinMaxZoomPreference(1.5, 20.0),
            ),

            // Reverse geocoding loader
            if (_isReverseGeocoding)
              Positioned(
                top: 80, left: 0, right: 0,
                child: Center(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 8)],
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                    SizedBox(width: 8),
                    Text('Loading address...', style: TextStyle(fontSize: 12)),
                  ]),
                )),
              ),

            // ── TOP: Search / Navigate ────────────────────────────────────
            Positioned(
              top: 12, left: 16, right: 16,
              child: Row(children: [
                Expanded(
                  child: _mode == MapMode.explore
                      ? _ExploreSearch(
                          controller:  _searchCtrl,
                          isSearching: _isSearching,
                          onChanged:   _onSearchChanged,
                          onSubmitted: (q) => _search(q, navigate: false),
                          onClear:     _clearExplore,
                        )
                      : _NavigatePanel(
                          fromCtrl: _fromCtrl, toCtrl: _toCtrl,
                          fromName: _fromName, toName: _toName,
                          isSearching: _isNavSearching, isRouting: _isRouting, editingFrom: _editingFrom,
                          onFromTap: () => setState(() => _editingFrom = true),
                          onToTap:   () => setState(() => _editingFrom = false),
                          onFromChanged: _onNavSearchChanged, onToChanged: _onNavSearchChanged,
                          onGetRoute: _getRoute,
                          onSwap: () => setState(() {
                            final t = _fromCtrl.text; _fromCtrl.text = _toCtrl.text; _toCtrl.text = t;
                            final p = _fromPos; _fromPos = _toPos; _toPos = p;
                            final n = _fromName; _fromName = _toName; _toName = n;
                            if (_fromPos != null && _toPos != null) _getRoute();
                          }),
                          onClear: _clearRoute,
                        ).animate().fade(duration: 250.ms),
                ),
                const SizedBox(width: 8),
                _ModeToggle(mode: _mode, onToggle: () => setState(() {
                  _mode = _mode == MapMode.explore ? MapMode.navigate : MapMode.explore;
                  _showResults = false; _showNavResults = false;
                })),
              ]).animate().fade(duration: 300.ms).slideY(begin: -0.2, end: 0),
            ),

            // ── Search results ────────────────────────────────────────────
            if (_showResults && _mode == MapMode.explore)
              Positioned(
                top: 76, left: 16, right: 72,
                child: _ResultsList(
                  results: _searchResults, recent: _recentSearches,
                  onSelect: _pickExploreResult, userPos: _userPos,
                ).animate().fade(duration: 200.ms),
              ),

            if (_showNavResults && _mode == MapMode.navigate)
              Positioned(
                top: 148, left: 16, right: 72,
                child: _ResultsList(
                  results: _navResults, recent: [],
                  onSelect: _pickNavResult, userPos: _userPos,
                ).animate().fade(duration: 200.ms),
              ),

            // ── POI category chips ────────────────────────────────────────
            if (_mode == MapMode.explore)
              Positioned(
                top: 76, left: 0, right: 0,
                child: _CategoryStrip(
                  active: _activeCategory, isLoading: _isLoadingPois,
                  onSelect: _fetchLivePois,
                ).animate().fade(delay: 150.ms),
              ),

            // ── RIGHT FABs ────────────────────────────────────────────────
            Positioned(
              right: 14, bottom: 140,
              child: Column(children: [
                _MapBtn(icon: _layer == MapLayer.standard ? Icons.dark_mode_outlined : Icons.wb_sunny_outlined,
                    tooltip: 'Toggle style', onTap: () => setState(() => _layer = _layer == MapLayer.standard ? MapLayer.dark : MapLayer.standard)),
                const SizedBox(height: 8),
                _MapBtn(icon: Icons.business, tooltip: '3D Buildings',
                    color: _show3dBuildings ? AppColors.primary : Colors.white,
                    textColor: _show3dBuildings ? Colors.white : Colors.black87,
                    onTap: _toggle3d),
                const SizedBox(height: 8),
                _MapBtn(icon: Icons.add, tooltip: 'Zoom in',
                    onTap: () => _ctrl?.animateCamera(CameraUpdate.zoomIn())),
                const SizedBox(height: 8),
                _MapBtn(icon: Icons.remove, tooltip: 'Zoom out',
                    onTap: () => _ctrl?.animateCamera(CameraUpdate.zoomOut())),
                const SizedBox(height: 8),
                _MapBtn(icon: Icons.my_location, tooltip: 'Locate me',
                    color: AppColors.primary, textColor: Colors.white,
                    isLoading: _isLocating, onTap: _locateMe),
                const SizedBox(height: 8),
                _MapBtn(
                    icon: _isTracking ? Icons.gps_fixed : Icons.gps_not_fixed,
                    tooltip: _isTracking ? 'Stop tracking' : 'Live track',
                    color: _isTracking ? Colors.green : Colors.white,
                    textColor: _isTracking ? Colors.white : Colors.black87,
                    onTap: _toggleTracking),
                const SizedBox(height: 8),
                _MapBtn(icon: Icons.navigation, tooltip: 'North up',
                    onTap: () => _ctrl?.animateCamera(CameraUpdate.bearingTo(0))),
              ]),
            ),

            // ── BOTTOM PANEL ──────────────────────────────────────────────
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _BottomPanel(
                mode: _mode, userLocated: _userPos != null, isTracking: _isTracking,
                activeCategory: _activeCategory, visibleCount: _dynamicPois.length,
                pinnedName: _pinnedName, routeDist: _routeDist, routeTime: _routeTime,
                fromName: _fromName, toName: _toName,
                hasSteps: _routeSteps.isNotEmpty,
                onStepsTap: _showRouteSteps,
                nearbyPois: _mode == MapMode.explore && _dynamicPois.isNotEmpty
                    ? _dynamicPois.take(5).toList() : [],
                userPos: _userPos,
                distFn: _userPos != null ? (pos) => _fmtDist(_distanceKm(_userPos!, pos)) : null,
                onPoiTap: _showPoiSheet,
                onAllPoisTap: _dynamicPois.isNotEmpty ? _showAllPoisSheet : null,
              ),
            ),

            if (!_mapReady)
              const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          ]),
        );
      },
    );
  }

  // ─── POI detail sheet ─────────────────────────────────────────────────────
  void _showPoiSheet(_Poi poi) {
    final dist = _userPos != null ? _fmtDist(_distanceKm(_userPos!, poi.pos)) : null;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 20)],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: poi.cat.color.withAlpha(20), shape: BoxShape.circle),
            child: Icon(poi.cat.icon, color: poi.cat.color, size: 28)),
          const SizedBox(width: 16),
          Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(poi.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: poi.cat.color.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                child: Text(poi.cat.label, style: TextStyle(color: poi.cat.color, fontSize: 11, fontWeight: FontWeight.w600))),
              if (dist != null) ...[
                const SizedBox(width: 8),
                Icon(Icons.directions_walk_outlined, size: 13, color: Colors.grey[500]),
                const SizedBox(width: 3),
                Text(dist, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ],
            ]),
            if (poi.phone   != null) _addrRow(Icons.phone_outlined,   poi.phone!),
            if (poi.website != null) _addrRow(Icons.language_outlined, poi.website!),
            const SizedBox(height: 8),
            Row(children: [
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  // Auto-set "From" as current location so route calculates immediately
                  setState(() {
                    _mode = MapMode.navigate;
                    _toPos  = poi.pos;
                    _toName = poi.name;
                    _toCtrl.text = poi.name;
                    if (_userPos != null) {
                      _fromPos  = _userPos;
                      _fromName = 'My Location';
                      _fromCtrl.text = 'My Location';
                    }
                  });
                  // Calculate route immediately if we have both points
                  if (_userPos != null) _getRoute();
                },
                icon: const Icon(Icons.directions_outlined, size: 16),
                label: const Text('Directions'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
              TextButton.icon(
                onPressed: () {
                  _ctrl?.animateCamera(CameraUpdate.newLatLngZoom(poi.pos, 17.0));
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.zoom_in_map, size: 16),
                label: const Text('Zoom'),
                style: TextButton.styleFrom(foregroundColor: AppColors.secondary),
              ),
            ]),
          ])),
        ]),
      ),
    );
  }  // end _showPoiSheet

  // ─── Full POI list sheet ─────────────────────────────────────────────────
  void _showAllPoisSheet() {
    // Sort by distance from user if available
    final sorted = List<_Poi>.from(_dynamicPois);
    if (_userPos != null) {
      sorted.sort((a, b) => _distanceKm(_userPos!, a.pos).compareTo(_distanceKm(_userPos!, b.pos)));
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize:     0.35,
        maxChildSize:     0.95,
        builder: (_, sc) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            // Handle
            Container(margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(children: [
                Icon(_activeCategory?.icon ?? Icons.place_outlined, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  '${_activeCategory?.label ?? 'Nearby'} — ${sorted.length} found',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
              ])),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: sc,
                itemCount:  sorted.length,
                separatorBuilder: (_, _) => const Divider(height: 1, indent: 70),
                itemBuilder: (_, i) {
                  final poi  = sorted[i];
                  final dist = _userPos != null ? _fmtDist(_distanceKm(_userPos!, poi.pos)) : null;
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: poi.cat.color.withAlpha(18), shape: BoxShape.circle),
                      child: Icon(poi.cat.icon, color: poi.cat.color, size: 20),
                    ),
                    title:    Text(poi.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(poi.cat.label, style: TextStyle(fontSize: 11, color: poi.cat.color)),
                    trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (dist != null) Text(dist, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                    onTap: () {
                      Navigator.pop(context);
                      _showPoiSheet(poi);
                    },
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Explore Search Bar ───────────────────────────────────────────────────────
class _ExploreSearch extends StatelessWidget {
  final TextEditingController controller;
  final bool isSearching;
  final ValueChanged<String> onChanged, onSubmitted;
  final VoidCallback onClear;
  const _ExploreSearch({required this.controller, required this.isSearching,
      required this.onChanged, required this.onSubmitted, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: controller, onChanged: onChanged, onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: 'Search cities, streets, places...',
          prefixIcon: isSearching
              ? const Padding(padding: EdgeInsets.all(14),
                  child: SizedBox(width: 18, height: 18 ,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)))
              : const Icon(Icons.search_rounded, color: AppColors.primary),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(icon: const Icon(Icons.close, size: 18, color: Colors.grey), onPressed: onClear)
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

// ─── Navigate Panel ───────────────────────────────────────────────────────────
class _NavigatePanel extends StatelessWidget {
  final TextEditingController fromCtrl, toCtrl;
  final String? fromName, toName;
  final bool isSearching, isRouting, editingFrom;
  final VoidCallback onFromTap, onToTap, onGetRoute, onSwap, onClear;
  final ValueChanged<String> onFromChanged, onToChanged;
  const _NavigatePanel({required this.fromCtrl, required this.toCtrl,
      required this.fromName, required this.toName,
      required this.isSearching, required this.isRouting, required this.editingFrom,
      required this.onFromTap, required this.onToTap, required this.onGetRoute,
      required this.onSwap, required this.onClear,
      required this.onFromChanged, required this.onToChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _field(context, fromCtrl, Icons.trip_origin, Colors.green, 'From (origin)', editingFrom, onFromTap, onFromChanged),
        Row(children: [const Spacer(),
          IconButton(icon: const Icon(Icons.swap_vert_circle_outlined, color: AppColors.primary), onPressed: onSwap, iconSize: 22)]),
        _field(context, toCtrl, Icons.place, Colors.red, 'To (destination)', !editingFrom, onToTap, onToChanged),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: isRouting ? null : onGetRoute,
          icon: isRouting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.directions, size: 18),
          label: Text(isRouting ? 'Calculating...' : 'Get Route'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12)),
        )),
        TextButton.icon(onPressed: onClear,
          icon: const Icon(Icons.clear, size: 14), label: const Text('Clear', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(foregroundColor: Colors.grey)),
      ]),
    );
  }

  Widget _field(BuildContext ctx, TextEditingController ctrl, IconData icon, Color c, String hint,
      bool active, VoidCallback onTap, ValueChanged<String> onChange) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active ? c.withAlpha(15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? c : Colors.grey.withAlpha(60)),
        ),
        child: Row(children: [
          Icon(icon, color: c, size: 18), const SizedBox(width: 8),
          Expanded(child: TextField(controller: ctrl, onChanged: onChange, onTap: onTap,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(hintText: hint, border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero))),
        ]),
      ),
    );
  }
}

// ─── Search Results ───────────────────────────────────────────────────────────
class _ResultsList extends StatelessWidget {
  final List<_Place> results, recent;
  final void Function(_Place) onSelect;
  final LatLng? userPos;
  const _ResultsList({required this.results, required this.recent,
      required this.onSelect, required this.userPos});

  double _dist(_Place p) {
    if (userPos == null) return 0;
    const R = 6371.0;
    final lat1 = userPos!.latitude  * math.pi / 180;
    final lat2 = p.lat * math.pi / 180;
    final dL   = (p.lat  - userPos!.latitude)  * math.pi / 180;
    final dLo  = (p.lon  - userPos!.longitude) * math.pi / 180;
    final a = math.sin(dL/2)*math.sin(dL/2)+math.cos(lat1)*math.cos(lat2)*math.sin(dLo/2)*math.sin(dLo/2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
  String _fmtDist(_Place p) { final d = _dist(p); return d < 1 ? '${(d*1000).round()} m' : '${d.toStringAsFixed(0)} km'; }

  @override
  Widget build(BuildContext context) {
    final showRecent = results.isEmpty && recent.isNotEmpty;
    final items = showRecent ? recent : results;
    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 12)],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (showRecent)
          Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(children: [
              const Icon(Icons.history, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text('Recent searches', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ])),
        Flexible(child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 4),
          shrinkWrap: true,
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
          itemBuilder: (_, i) {
            final p = items[i];
            final short = p.name.split(',').first.trim();
            final sub   = p.name.split(',').skip(1).take(2).join(',').trim();
            final type  = p.type;
            return ListTile(dense: true,
              leading: Icon(
                type == 'city' || type == 'town' || type == 'village' ? Icons.location_city_outlined :
                type == 'hospital' || type == 'clinic' ? Icons.local_hospital_outlined :
                type == 'restaurant' || type == 'cafe' ? Icons.restaurant_outlined :
                type == 'hotel' ? Icons.hotel_outlined :
                showRecent ? Icons.history : Icons.search,
                color: AppColors.primary, size: 20),
              title: Text(short, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: sub.isNotEmpty ? Text(sub, style: const TextStyle(fontSize: 11, color: Colors.grey)) : null,
              trailing: userPos != null
                  ? Text(_fmtDist(p), style: TextStyle(fontSize: 10, color: Colors.grey[500]))
                  : null,
              onTap: () => onSelect(p),
            );
          },
        )),
      ]),
    );
  }
}

// ─── POI Category Chip Strip ──────────────────────────────────────────────────
class _CategoryStrip extends StatelessWidget {
  final PoiCategory? active;
  final bool isLoading;
  final void Function(PoiCategory) onSelect;
  const _CategoryStrip({required this.active, required this.isLoading, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        children: PoiCategory.values.map((cat) {
          final isActive = active == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isActive, showCheckmark: false,
              avatar: isActive && isLoading
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(cat.icon, size: 15, color: isActive ? Colors.white : cat.color),
              label: Text(cat.label, style: TextStyle(fontSize: 12, color: isActive ? Colors.white : null)),
              backgroundColor: Theme.of(context).colorScheme.surface,
              selectedColor: cat.color,
              side: BorderSide(color: cat.color.withAlpha(80)),
              elevation: isActive ? 4 : 1,
              shadowColor: cat.color.withAlpha(60),
              onSelected: (_) => onSelect(cat),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Mode Toggle ──────────────────────────────────────────────────────────────
class _ModeToggle extends StatelessWidget {
  final MapMode mode;
  final VoidCallback onToggle;
  const _ModeToggle({required this.mode, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        width: 50, height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: AppColors.primary.withAlpha(80), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Icon(mode == MapMode.navigate ? Icons.explore_outlined : Icons.directions,
            color: Colors.white, size: 22),
      ),
    );
  }
}

// ─── Round FAB Button ─────────────────────────────────────────────────────────
class _MapBtn extends StatelessWidget {
  final IconData icon; final String tooltip;
  final Color color, textColor; final bool isLoading;
  final VoidCallback onTap;
  const _MapBtn({required this.icon, required this.tooltip, required this.onTap,
      this.color = Colors.white, this.textColor = Colors.black87, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return Tooltip(message: tooltip, child: GestureDetector(onTap: onTap,
      child: Container(width: 44, height: 44,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 10, offset: const Offset(0, 3))]),
        child: Center(child: isLoading
            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: textColor))
            : Icon(icon, color: textColor, size: 20)))));
  }
}

// ─── Bottom Info Panel ────────────────────────────────────────────────────────
class _BottomPanel extends StatelessWidget {
  final MapMode mode;
  final bool userLocated, isTracking;
  final PoiCategory? activeCategory;
  final int visibleCount;
  final String? pinnedName, routeDist, routeTime, fromName, toName;
  final bool hasSteps;
  final VoidCallback onStepsTap;
  final List<_Poi> nearbyPois;
  final LatLng? userPos;
  final String Function(LatLng)? distFn;
  final void Function(_Poi) onPoiTap;
  final VoidCallback? onAllPoisTap;

  const _BottomPanel({
    required this.mode, required this.userLocated, required this.isTracking,
    required this.activeCategory, required this.visibleCount,
    required this.pinnedName, required this.routeDist, required this.routeTime,
    required this.fromName, required this.toName,
    required this.hasSteps, required this.onStepsTap,
    required this.nearbyPois, required this.userPos, required this.distFn,
    required this.onPoiTap,
    this.onAllPoisTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.fromLTRB(12, 0, 12, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (mode == MapMode.explore) _buildExploreInfo(context)
        else                          _buildNavInfo(context),

        // Nearby POI quick strip
        if (nearbyPois.isNotEmpty && mode == MapMode.explore) ...[
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Nearby', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
            const Spacer(),
            if (onAllPoisTap != null)
              GestureDetector(
                onTap: onAllPoisTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'View All ($visibleCount)',
                    style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              )
            else
              Text('$visibleCount total', style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ]),
          const SizedBox(height: 6),
          SizedBox(
            height: 60,
            child: ListView(scrollDirection: Axis.horizontal, children: nearbyPois.map((poi) {
              final dist = distFn != null ? distFn!(poi.pos) : '';
              return GestureDetector(
                onTap: () => onPoiTap(poi),
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: poi.cat.color.withAlpha(12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: poi.cat.color.withAlpha(60)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(poi.cat.icon, color: poi.cat.color, size: 16),
                    const SizedBox(width: 6),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(poi.name.length > 14 ? poi.name.substring(0, 14) : poi.name,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      if (dist.isNotEmpty) Text(dist, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                    ]),
                  ]),
                ),
              );
            }).toList()),
          ),
        ],
      ]),
    );
  }

  Widget _buildExploreInfo(BuildContext context) {
    if (activeCategory != null && visibleCount > 0) {
      return Row(children: [
        Icon(activeCategory!.icon, color: activeCategory!.color, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text('$visibleCount ${activeCategory!.label} nearby',
            style: const TextStyle(fontWeight: FontWeight.w600))),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: activeCategory!.color.withAlpha(20), borderRadius: BorderRadius.circular(10)),
          child: Text('$visibleCount', style: TextStyle(color: activeCategory!.color, fontWeight: FontWeight.bold))),
      ]);
    }
    if (pinnedName != null) {
      return Row(children: [
        const Icon(Icons.location_pin, color: AppColors.secondary, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text(pinnedName!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
        const Icon(Icons.touch_app_outlined, size: 14, color: Colors.grey),
      ]);
    }
    return Row(children: [
      const Icon(Icons.touch_app_outlined, color: Colors.grey, size: 20),
      const SizedBox(width: 8),
      const Expanded(child: Text('Tap anywhere on map to see address info',
          style: TextStyle(fontSize: 12, color: Colors.grey))),
    ]);
  }

  Widget _buildNavInfo(BuildContext context) {
    if (routeDist != null && routeTime != null) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const Icon(Icons.route, color: AppColors.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$fromName → $toName',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
            Text('$routeDist · $routeTime', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ])),
          if (hasSteps)
            TextButton.icon(
              onPressed: onStepsTap,
              icon: const Icon(Icons.list_alt_outlined, size: 16),
              label: const Text('Steps', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 8)),
            ),
        ]),
      ]);
    }
    return Row(children: [
      const Icon(Icons.directions, color: AppColors.primary, size: 22),
      const SizedBox(width: 10),
      const Expanded(child: Text('Enter From & To to get a route with turn-by-turn',
          style: TextStyle(fontSize: 12, color: Colors.grey))),
    ]);
  }
}
