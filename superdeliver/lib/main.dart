import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:here_sdk/consent.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.engine.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:superdeliver/environment/environment.dart';
import 'package:superdeliver/providers/Inventory_provider.dart';
import 'package:superdeliver/providers/order_provider.dart';
import 'package:superdeliver/providers/picker_provider.dart';
import 'package:superdeliver/providers/locator_provider.dart';
import 'package:superdeliver/providers/transfer_provider.dart';
import 'package:superdeliver/routes/routes.dart';
import 'package:superdeliver/screens/superDeliver/orders.dart';
import 'package:superdeliver/screens/superPicker/scan_location.dart';
import 'package:superdeliver/stores/store.dart';
import 'package:superdeliver/variables/svg.dart';
import 'package:superdeliver/widget/version.dart';
import 'package:wakelock/wakelock.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  const environment = String.fromEnvironment('ENV', defaultValue: 'dev');
  Environment env = (environment == "prod")
      ? Environment.production()
      : Environment.development();

  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Retrieve token and SDK keys securely
  final token = await retrieveTokenSecurely();
  final sdkKeys = await retrieveSdkKeys();
  final sdkKeyId = sdkKeys["sdk_key_id"];
  final sdkKey = sdkKeys["sdk_key"];

  // Retrieve cookie data
  final locatorCookie = await retrievePickerCookie(locatorCookieKey);
  final driverCookie = await retrieveCookie(driverCookieKey);
  final xferCookie = await retrieveCookie(xferCookieKey);

  // Initialize SDK and set initial route based on the token and cookie
  String initialRoute = '/home';
  if (token.isNotEmpty && sdkKeyId != null && sdkKey.isNotEmpty) {
    SdkContext.init(IsolateOrigin.main);
    SDKOptions sdkOptions = SDKOptions.withAccessKeySecretAndCachePath(
      sdkKeyId,
      sdkKey,
      "", // Assuming the third parameter is a string for cache path
    );
    await SDKNativeEngine.makeSharedInstance(sdkOptions);

    if (locatorCookie != null) {
      initialRoute = '/scanLocation';
    } else if (driverCookie != null) {
      initialRoute = '/orderList';
    } else if (xferCookie != null) {
      initialRoute = '/xferStores';
    }
  }
  runApp(MyApp(
    env: env,
    initialRoute: initialRoute,
  ));
  Wakelock.enable();
}

class MyApp extends StatelessWidget {
  final Environment env;
  final String initialRoute;

  const MyApp({
    super.key,
    required this.env,
    required this.initialRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Provider<Environment>.value(
      value: env,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (context) => OrderProvider(
                Provider.of<Environment>(context, listen: false).apiUrl,
                context),
          ),
          ChangeNotifierProvider(
              create: (context) => PickerProvider(env.apiUrl)),
          ChangeNotifierProvider(
              create: (context) => LocatorProvider(env.apiUrl)),
          ChangeNotifierProvider(
              create: (context) => InventoryProvider(env.apiUrl)),
          ChangeNotifierProvider(
              create: (context) => TransferProvider(env.apiUrl)),
        ],
        child: MaterialApp(
          scaffoldMessengerKey: scaffoldMessengerKey,
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          supportedLocales: HereSdkConsentLocalizations.supportedLocales,
          localizationsDelegates:
              HereSdkConsentLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) {
              ScreenUtil.init(
                context,
                designSize: const Size(360, 690),
                minTextAdapt: true,
              );
              switch (initialRoute) {
                case '/scanLocation':
                  return const ScanScreenLocator();
                case '/orderList':
                  return const OrderListScreen();
                case '/home':
                default:
                  return const HomeScreen();
              }
            },
          ),
          initialRoute: initialRoute,
          routes: getAppRoutes(),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/background_hp.png"),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, '/superdeliverLogin');
                  },
                  child: SvgPicture.string(
                    svgDeliver,
                    width: 120,
                    height: 120,
                  ), // SuperDeliver
                ),
                const SizedBox(height: 30),
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, '/superLocatorLogin');
                  },
                  child: SvgPicture.string(
                    svgPicker,
                    width: 120,
                    height: 120,
                  ), // SuperLocator
                ),
                const SizedBox(height: 30),
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, '/superXferLogin');
                  },
                  child: SvgPicture.string(
                    svgTransfer,
                    width: 120,
                    height: 120,
                  ),
                ),
              ],
            ),
          ),
          const VersionDisplay()
        ],
      ),
    );
  }
}
