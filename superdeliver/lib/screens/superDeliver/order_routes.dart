import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/gestures.dart';
import 'package:here_sdk/location.dart';
import 'package:here_sdk/mapview.dart';
// ignore: library_prefixes
import 'package:here_sdk/navigation.dart' as HERE_NAVIGATION;
// ignore: library_prefixes
import 'package:here_sdk/routing.dart' as HERE;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:superdeliver/environment/environment.dart';
import 'package:superdeliver/models/order_details.dart';
import 'package:superdeliver/providers/order_provider.dart';

class OrderRoute extends StatefulWidget {
  const OrderRoute({super.key});
  @override
  // ignore: library_private_types_in_public_api
  OrderRouteState createState() => OrderRouteState();
}

class OrderRouteState extends State<OrderRoute> {
  final ValueNotifier<String> maneuverNotifier = ValueNotifier<String>('');
  final ValueNotifier<bool> isArrivedNotifier = ValueNotifier<bool>(false);
  late NavigationManager navigationManager;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Ensures the context is available after the widget tree is built
      navigationManager = NavigationManager(
        maneuverNotifier: maneuverNotifier,
        isArrivedNotifier: isArrivedNotifier,
        context: context,
      );
    });
  }

  @override
  void dispose() {
    navigationManager.stopNavigation();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          HereMap(onMapCreated: (HereMapController controller) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              navigationManager.startNavigation(controller, context);
            });
          }),
          Positioned(
            top: 24,
            left: 0,
            right: 0,
            child: buildNavigationHeader(),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: buildNavigationFooter(context),
          ),
        ],
      ),
    );
  }

  Widget buildNavigationHeader() {
    return ValueListenableBuilder<String>(
      valueListenable: maneuverNotifier,
      builder: (context, maneuver, child) {
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Color.fromARGB(255, 18, 1, 175),
          ),
          child: Row(
            children: [
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  maneuver,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildNavigationFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: const Color.fromARGB(255, 18, 1, 175),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              // Stop the navigation
              navigationManager.stopNavigation();
              // Set route_started to false for the current route
              final orderProvider =
                  Provider.of<OrderProvider>(context, listen: false);
              orderProvider.setRouteStarted(false, context);
              Navigator.pushReplacementNamed(context, '/orderList');
            },
          ),
          Expanded(
            child: Consumer<OrderProvider>(
              builder: (context, orderProvider, child) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text("Confirmation"),
                          content: const Text(
                              "Vous êtes arrivé à destination. Confirmez-vous?"),
                          actions: <Widget>[
                            TextButton(
                              child: const Text("Annuler"),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                            TextButton(
                              child: const Text("OK"),
                              onPressed: () async {
                                // Stop the navigation
                                navigationManager.stopNavigation();
                                // Mark the order as arrived
                                Navigator.pushReplacementNamed(
                                    context, '/confirmation');
                                // Navigate to the confirmation screen
                                await orderProvider.markAsArrived(context);
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: Text(
                    textAlign: TextAlign.center,
                    orderProvider.getCurrentOrderFormattedAddressCopy(context),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class NavigationManager extends ChangeNotifier {
  final ValueNotifier<String> maneuverNotifier;
  final ValueNotifier<bool> isArrivedNotifier;
  late Order currentOrder;
  late List<Order> orders;

  final FlutterTts flutterTts = FlutterTts();
  final HERE.RoutingEngine routingEngine = HERE.RoutingEngine();

  final PositioningLocationProvider locationProvider =
      PositioningLocationProvider();
  final HERE_NAVIGATION.VisualNavigator visualNavigator =
      HERE_NAVIGATION.VisualNavigator();

  GeoCoordinates currentLocation = GeoCoordinates(0.0, 0.0);
  GeoCoordinates destinationLocation = GeoCoordinates(
    0.0,
    0.0,
  );

  Timer timer = Timer(Duration.zero, () {});
  int routeDeviationCounter = 0;
  String formatedAddress = '';
  double speed = 0.0;
  String apiUrl = '';
  int store = 0;

  static const double derivationTrigger = 60.0;
  static const double msToKmhFactor = 3.6;
  static const double speechRate = 0.5;
  static const int deviationRound = 3;
  static const double volume = 1.0;
  static const double pitch = 1.0;

  NavigationManager({
    required this.maneuverNotifier,
    required this.isArrivedNotifier,
    required BuildContext context,
  }) {
    // Get the current order details from the provider
    currentOrder = Provider.of<OrderProvider>(context, listen: false)
        .getCurrentOrderCopy(context);

    orders = Provider.of<OrderProvider>(context, listen: false).orders;

    // Get the API URL from the environment provider
    apiUrl = Provider.of<Environment>(context, listen: false).apiUrl;

    // Get the formatted address from the provider
    formatedAddress = Provider.of<OrderProvider>(context, listen: false)
        .getCurrentOrderFormattedAddressCopy(context);

    // Use order coordinates for subsequent orders
    destinationLocation =
        GeoCoordinates(currentOrder.latitude, currentOrder.longitude);

    // Initialize the text-to-speech engine
    initTts();

    // Setup the location provider
    setupLocationProvider();

    // Set the arrival listener
    arrivalListener();

    // Set the navigable location listener
    setSpeedListener();

    // Set the event text listener
    setManeuverListener();

    // Start the progress tick timer
    // startSendingTelemetry();

    // Enable the route progress
    visualNavigator.isRouteProgressVisible = true;

    // Enable the extrapolation
    visualNavigator.isExtrapolationEnabled = true;
  }

  void initTts() async {
    // Set the language, speech rate, volume, and pitch
    await flutterTts.setLanguage('fr-CA');
    await flutterTts.setSpeechRate(speechRate);
    await flutterTts.setVolume(volume);
    await flutterTts.setPitch(pitch);
  }

  void speakManeuver(String maneuverText) async {
    // Speak the maneuver instruction
    await flutterTts.speak(maneuverText);
  }

  Future<void> startNavigation(
      HereMapController controller, BuildContext context) async {
    if (orders.isNotEmpty) {
      final currentRouteNumber = orders.first.route;
      for (var order in orders) {
        if (order.route == currentRouteNumber && !order.route_started) {
          order.route_started = true;
        }
      }
    }

    notifyListeners();

    try {
      // Fetch the first order for navigation
      final currentOrder = orders.first;

      // Fetch or generate destination coordinates using OrderProvider
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      destinationLocation = await orderProvider.fetchOrGenerateCoordinates(
          context, currentOrder.order_number, currentOrder.job);

      // Load the map scene
      controller.mapScene.loadSceneForMapScheme(MapScheme.normalDay,
          (MapError? error) {
        if (error != null) return;
      });

      // Enable traffic visualization
      controller.mapScene.enableFeatures({
        'trafficFlow': MapFeatures.trafficFlow,
        'trafficIncidents': MapFeatures.trafficIncidents,
      });

      // Set the camera to the current location
      controller.camera.lookAtPoint(currentLocation);

      // Enable map gestures
      controller.gestures.disableDefaultAction(GestureType.twoFingerTap);
      controller.gestures.disableDefaultAction(GestureType.twoFingerPan);
      controller.gestures.disableDefaultAction(GestureType.doubleTap);
      controller.gestures.disableDefaultAction(GestureType.pan);

      // Set the frame rate
      controller.frameRate = 30;

      // Start the visual navigator
      visualNavigator.startRendering(controller);

      // Get the first maneuver
      HERE.Maneuver? firstManeuver = visualNavigator.getManeuver(1);

      if (firstManeuver != null) {
        maneuverNotifier.value = firstManeuver.text;

        // Speak the first maneuver
        speakManeuver(
          "Début de l'itinéraire vers ${currentOrder.address}. ${firstManeuver.text}",
        );
      } else {
        if (kDebugMode) {
          print('First maneuver is null');
        }
      }

      calculateRoute(controller);
      setRouteDeviationListener(controller);
    } catch (e) {
      if (kDebugMode) {
        print('Error starting navigation: $e');
      }
    }
  }

  void stopNavigation() {
    try {
      // Set the route to null
      visualNavigator.route = null;
      // Stop the navigation
      visualNavigator.stopRendering();
      // Update the notifier
      isArrivedNotifier.value = true;
      // Stop sending telemetry
      // stopSendingTelemetry();
      // Stop the location provider
      locationProvider.stop();
      // Inform the user about the arrival
      speakManeuver("Vous êtes arrivé à destination!");
      // Stop the Text-to-Speech engine
      flutterTts.stop();
    } catch (e) {
      if (kDebugMode) {
        print('Error on destination reached: $e');
      }
    }
  }

  void arrivalListener() {
    // Set the destination reached listener
    visualNavigator.destinationReachedListener =
        HERE_NAVIGATION.DestinationReachedListener(
      () {
        // Stop the navigation
        stopNavigation();
      },
    );
  }

  void applyTrafficColorScheme(HERE.Route route, HereMapController controller) {
    for (var section in route.sections) {
      int startIndex = 0;

      for (var span in section.spans) {
        Color color;
        final jamFactor = span.trafficSpeed.jamFactor;
        if (jamFactor! > 8) {
          color = Colors.red; // Heavy traffic
        } else if (jamFactor > 4) {
          color = Colors.yellow; // Moderate traffic
        } else {
          color = Colors.green; // Light or no traffic
        }

        // Extract polyline for the span
        var spanPolylinePoints = section.geometry.vertices
            .sublist(startIndex, startIndex + span.lengthInMeters);
        final geoPolyline = GeoPolyline(spanPolylinePoints);

        // Create and style the MapPolyline
        final mapPolyline = MapPolyline.withRepresentation(
            geoPolyline,
            (Paint()
              ..color = color
              ..strokeWidth = 10) as MapPolylineRepresentation);
        controller.mapScene.addMapPolyline(mapPolyline);

        startIndex += span.lengthInMeters;
      }
    }
  }

  void calculateRoute(HereMapController controller) {
    try {
      // Reset the deviation counter
      routeDeviationCounter = 0;

      // Define waypoints using current and destination locations
      List<HERE.Waypoint> routeWaypoints = [
        HERE.Waypoint.withDefaults(currentLocation),
        HERE.Waypoint.withDefaults(destinationLocation),
      ];

      // Configure route text options for French language in Canada using the metric system
      HERE.RouteTextOptions textOptions = HERE.RouteTextOptions()
        ..language = LanguageCode.frCa
        ..unitSystem = UnitSystem.metric;

      HERE.AvoidanceOptions avoidanceOptions = HERE.AvoidanceOptions()
        ..roadFeatures = [HERE.RoadFeatures.tollRoad, HERE.RoadFeatures.ferry];

      // Configure route options with default values
      HERE.RouteOptions routeOptions = HERE.RouteOptions.withDefaults()
        ..alternatives = 3
        ..optimizationMode = HERE.OptimizationMode.fastest
        ..trafficOptimizationMode = HERE.TrafficOptimizationMode.timeDependent;

      // Configure car routing options
      HERE.CarOptions carOptions = HERE.CarOptions()
        ..routeOptions = routeOptions
        ..textOptions = textOptions
        ..avoidanceOptions = avoidanceOptions;

      // Define the callback for routing response
      void setVisualNavigatorRoute(
          HERE.RoutingError? routingError, List<HERE.Route>? routeList) {
        if (routeList != null && routeList.isNotEmpty) {
          // Set the first valid route
          visualNavigator.route = routeList.first;
          applyTrafficColorScheme(routeList.first, controller);
        } else if (routingError != null) {
          // Handle routing error
          if (kDebugMode) {
            print('Routing error: $routingError');
          }
        }
      }

      // Initiate route calculation
      routingEngine.calculateCarRoute(
          routeWaypoints, carOptions, setVisualNavigatorRoute);
    } catch (e) {
      // Log errors only if debug mode is enabled
      if (kDebugMode) {
        print('Error in route calculation: $e');
      }
    }
  }

  void setRouteDeviationListener(HereMapController controller) {
    visualNavigator.routeDeviationListener =
        HERE_NAVIGATION.RouteDeviationListener(
      (HERE_NAVIGATION.RouteDeviation routeDeviation) async {
        try {
          // Get the current route
          HERE.Route route = visualNavigator.route!;

          // Get the current map matched location
          HERE_NAVIGATION.MapMatchedLocation currentMapMatchedLocation =
              routeDeviation.currentLocation.mapMatchedLocation!;

          // Get the current location and define the last location variables
          currentLocation = currentMapMatchedLocation.coordinates;
          GeoCoordinates lastGeoCoordinatesOnRoute = GeoCoordinates(0.0, 0.0);

          // Get the last location on the route
          HERE_NAVIGATION.NavigableLocation? lastLocationOnRoute =
              routeDeviation.lastLocationOnRoute;

          // If the last location is not null, get the last map matched location
          if (lastLocationOnRoute != null) {
            // Get the last map matched location
            HERE_NAVIGATION.MapMatchedLocation? lastMapMatchedLocationOnRoute =
                lastLocationOnRoute.mapMatchedLocation;

            if (lastMapMatchedLocationOnRoute == null) {
              // Get the last original location
              lastGeoCoordinatesOnRoute =
                  lastLocationOnRoute.originalLocation.coordinates;
            } else {
              // Get the last map matched location
              lastGeoCoordinatesOnRoute =
                  lastMapMatchedLocationOnRoute.coordinates;
            }
          } else {
            // Get the first location on the route
            lastGeoCoordinatesOnRoute =
                route.sections.first.departurePlace.originalCoordinates!;
          }

          // Calculate the distance between the current and last location
          double distanceInMeters =
              currentLocation.distanceTo(lastGeoCoordinatesOnRoute);

          // Verify if the distance exceeded the allowed deviation
          if (distanceInMeters > derivationTrigger) {
            routeDeviationCounter = routeDeviationCounter + 1;
            if (routeDeviationCounter > deviationRound) {
              // Calculate the new route first
              calculateRoute(controller);

              // Send deviation details to the server
              // await sendRouteDeviationToAPI();

              // Reset the counter after handling the deviation
              routeDeviationCounter = 0;
            }
          } else {
            // Reset the counter if within acceptable limits
            routeDeviationCounter = 0;
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error handling route deviation: $e');
          }
        }
      },
    );
  }

  void setManeuverListener() {
    visualNavigator.maneuverNotificationOptions =
        HERE_NAVIGATION.ManeuverNotificationOptions(
      LanguageCode.frCa,
      UnitSystem.metric,
    );

    visualNavigator.maneuverNotificationListener =
        // ignore: deprecated_member_use
        HERE_NAVIGATION.ManeuverNotificationListener(
      (String maneuverText) {
        maneuverNotifier.value = maneuverText;
        speakManeuver(maneuverText);
      },
    );
  }

  void setSpeedListener() {
    // Set the navigable location listener
    visualNavigator.navigableLocationListener =
        HERE_NAVIGATION.NavigableLocationListener(
      (currentNavigableLocation) {
        try {
          // Get the current location state
          Location locationState = currentNavigableLocation.originalLocation;

          // Get the speed in m/s
          double msSpeed = locationState.speedInMetersPerSecond!;

          // Convert the speed to km/h
          speed = msSpeed * msToKmhFactor;
        } catch (e) {
          if (kDebugMode) {
            print('Error obtaining speed: $e');
          }
        }
      },
    );
  }

  void setupLocationProvider() {
    try {
      // Add the listener to the location provider
      locationProvider.addListener(visualNavigator);
      // Start the location provider
      locationProvider.start();
      // Set the current location
      if (locationProvider.locationEngine.lastKnownLocation != null) {
        // Set the current location if it's not null
        currentLocation =
            locationProvider.locationEngine.lastKnownLocation!.coordinates;
      } else {
        // Handle the case where lastKnownLocation is null
        currentLocation = GeoCoordinates(45.48749522117045,
            -73.38440766183881); // Set to a default location or handle appropriately
      }
    } on InstantiationException {
      throw Exception("Initialization of LocationSimulator failed.");
    }
  }
}

class PositioningLocationProvider implements LocationListener {
  final LocationEngine locationEngine = LocationEngine();
  final List<LocationListener> listeners = <LocationListener>[];

  void start() {
    if (locationEngine.lastKnownLocation != null) {
      onLocationUpdated(locationEngine.lastKnownLocation!);
    }
    locationEngine.setBackgroundLocationAllowed(true);
    locationEngine.setBackgroundLocationIndicatorVisible(true);
    locationEngine.setPauseLocationUpdatesAutomatically(true);
    locationEngine
      ..addLocationListener(this)
      ..startWithLocationAccuracy(LocationAccuracy.navigation);
  }

  void stop() {
    locationEngine
      ..setBackgroundLocationAllowed(false)
      ..setBackgroundLocationIndicatorVisible(false)
      ..setPauseLocationUpdatesAutomatically(false)
      ..removeLocationListener(this)
      ..stop();
  }

  void addListener(LocationListener listener) => listeners.add(listener);

  @override
  void onLocationUpdated(Location location) {
    for (final LocationListener listener in listeners) {
      listener.onLocationUpdated(location);
    }
  }
}
