import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:google_navigation_flutter/google_navigation_flutter.dart' as gnav;
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart' as gplaces;

class BlindGPSPage extends StatefulWidget {
  const BlindGPSPage({super.key});
  @override
  State<BlindGPSPage> createState() => _BlindGPSPageState();
}

class _BlindGPSPageState extends State<BlindGPSPage> {
  late final gplaces.FlutterGooglePlacesSdk _places;
  gnav.GoogleNavigationViewController? _navViewController;

  gplaces.Place? _destPlace;
  StreamSubscription<gnav.NavInfoEvent>? _navInfoSub;
  bool _bootstrapped = false;

  
  bool _isGuiding = false;

  @override
  void initState() {
    super.initState();
    _places = gplaces.FlutterGooglePlacesSdk('AIzaSyBDfP-Xx1GoQG5P_IjrwNo-4my62IcBCp4');
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final status = await Permission.location.request();

    if (!await gnav.GoogleMapsNavigator.areTermsAccepted()) {
      await gnav.GoogleMapsNavigator.showTermsAndConditionsDialog(
        'Navigation Terms',
        'Your Company',
      );
    }

    await gnav.GoogleMapsNavigator.initializeNavigationSession(
      taskRemovedBehavior: gnav.TaskRemovedBehavior.continueService,
    );

    setState(() => _bootstrapped = true);

    if (!status.isGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission is required for navigation')),
      );
    }
  }

  @override
  void dispose() {
    _navInfoSub?.cancel();
    gnav.GoogleMapsNavigator.cleanup();
    super.dispose();
  }

  Future<void> _onNavViewCreated(gnav.GoogleNavigationViewController c) async {
    _navViewController = c;

    await c.setMyLocationEnabled(true);
    await c.followMyLocation(gnav.CameraPerspective.tilted);

    // ONE TITLE ONLY: disable the SDK header, keep your AppBar
    await c.setNavigationHeaderEnabled(false);
    await c.setNavigationFooterEnabled(true);

    _navInfoSub = gnav.GoogleMapsNavigator.setNavInfoListener((e) {
      // Hook TTS here if needed
    });
  }

  Future<gplaces.Place?> _pickDestination() async {
    final controller = TextEditingController();
    List<gplaces.AutocompletePrediction> items = [];
    bool isLoading = false;
    String? error;

    return await showModalBottomSheet<gplaces.Place>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      enableDrag: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> query(String q) async {
              if (!mounted) return;
              if (q.trim().isEmpty) {
                setModalState(() {
                  items = [];
                  error = null;
                  isLoading = false;
                });
                return;
              }
              setModalState(() {
                isLoading = true;
                error = null;
              });
              try {
                final res = await _places.findAutocompletePredictions(q.trim());
                setModalState(() {
                  items = res.predictions;
                  isLoading = false;
                });
              } catch (e) {
                setModalState(() {
                  items = [];
                  isLoading = false;
                  error = 'Search failed. Check network/API key.';
                });
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                  left: 12, right: 12, top: 8,
                ),
                child: SizedBox(
                  height: MediaQuery.of(ctx).size.height * 0.7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Search destination',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(ctx).pop(null),
                          ),
                        ],
                      ),
                      TextField(
                        controller: controller,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        decoration: const InputDecoration(
                          hintText: 'Type a place, address, or business',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => query(v),
                        onSubmitted: (v) => query(v),
                      ),
                      const SizedBox(height: 8),
                      if (isLoading) const LinearProgressIndicator(),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(error!, style: const TextStyle(color: Colors.red)),
                        ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: items.isEmpty && !isLoading && error == null
                            ? const Center(child: Text('Start typing to search'))
                            : ListView.builder(
                                itemCount: items.length,
                                itemBuilder: (_, i) {
                                  final p = items[i];
                                  final t1 = p.fullText ?? p.primaryText ?? 'Place';
                                  final t2 = p.secondaryText;
                                  return ListTile(
                                    leading: const Icon(Icons.place),
                                    title: Text(t1, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    subtitle: Text(t2),
                                    onTap: () async {
                                      try {
                                        final detail = await _places.fetchPlace(
                                          p.placeId,
                                          fields: const [
                                            gplaces.PlaceField.Location,
                                            gplaces.PlaceField.Name,
                                            gplaces.PlaceField.Address,
                                          ],
                                        );
                                        final picked = detail.place;
                                        if (picked?.latLng == null) {
                                          Navigator.of(ctx).pop(null);
                                          return;
                                        }
                                        Navigator.of(ctx).pop(picked);
                                      } catch (_) {
                                        Navigator.of(ctx).pop(null);
                                      }
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---- Navigation actions ----
  Future<void> _startNavigation() async {
    if (_destPlace?.latLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a destination first')),
      );
      return;
    }

    gnav.LatLng toNavLatLng(gplaces.LatLng gp) =>
        gnav.LatLng(latitude: gp.lat, longitude: gp.lng);

    final waypoints = <gnav.NavigationWaypoint>[
      gnav.NavigationWaypoint.withLatLngTarget(
        title: _destPlace?.name ?? 'Destination',
        target: toNavLatLng(_destPlace!.latLng!),
      ),
    ];

    final status = await gnav.GoogleMapsNavigator.setDestinations(
      gnav.Destinations(
        waypoints: waypoints,
        routingOptions: gnav.RoutingOptions(),
        displayOptions: gnav.NavigationDisplayOptions(showDestinationMarkers: true),
      ),
    );

    if (status == gnav.NavigationRouteStatus.statusOk) {
      await gnav.GoogleMapsNavigator.startGuidance();
      if (mounted) setState(() => _isGuiding = true); // HIDE controls, SHOW Stop
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Route calculation failed')),
      );
    }
  }

  Future<void> _stopNavigation() async {
    await gnav.GoogleMapsNavigator.cleanup();
    await gnav.GoogleMapsNavigator.initializeNavigationSession(
      taskRemovedBehavior: gnav.TaskRemovedBehavior.continueService,
    );
    if (mounted) setState(() => _isGuiding = false); // SHOW controls again
  }

  @override
  Widget build(BuildContext context) {
    if (!_bootstrapped) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Blind GPS — Turn-by-Turn')),
      body: Stack(
        children: [
          // Native navigation view
          Positioned.fill(
            child: gnav.GoogleMapsNavigationView(onViewCreated: _onNavViewCreated),
          ),

          // Overlay controls (only when NOT guiding)
          if (!_isGuiding)
            Positioned(
              left: 12,
              right: 12,
              top: 12 + MediaQuery.of(context).padding.top,
              child: Column(
                children: [
                  _PlaceChip(
                    label: _destPlace?.name ?? 'Choose destination',
                    icon: Icons.flag,
                    onTap: () async {
                      final p = await _pickDestination();
                      if (p != null) setState(() => _destPlace = p);
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.navigation),
                          onPressed: _destPlace == null ? null : _startNavigation,
                          label: const Text('Start navigation'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Stop button (only when guiding) — bottom-right
          if (_isGuiding)
            Positioned(
              right: 16,
              bottom: 16 + MediaQuery.of(context).padding.bottom,
              child: FloatingActionButton.extended(
                onPressed: _stopNavigation,
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlaceChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _PlaceChip({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.6),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const Icon(Icons.search, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}
