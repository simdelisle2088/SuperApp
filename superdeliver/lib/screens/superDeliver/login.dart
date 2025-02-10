import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_svg/svg.dart';
import 'package:here_sdk/consent.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.engine.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:superdeliver/providers/order_provider.dart';
import 'package:superdeliver/environment/environment.dart';
import 'package:superdeliver/stores/store.dart';
import 'package:superdeliver/variables/colors.dart';
import 'package:superdeliver/variables/svg.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:superdeliver/widget/help_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController vehiculeController = TextEditingController();

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => OrderProvider(
          Provider.of<Environment>(context, listen: false).apiUrl, context),
      child: Scaffold(
        body: Stack(
          children: [
            SingleChildScrollView(
              child: Container(
                height: MediaQuery.of(context).size.height,
                padding: const EdgeInsets.only(
                    top: 50, left: 40, right: 40, bottom: 20),
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage("assets/images/background_hp.png"),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const LogoWidget(),
                      const SizedBox(height: 30),
                      InputField(
                        controller: usernameController,
                        hint: 'Utilisateur',
                      ),
                      const SizedBox(height: 30),
                      InputField(
                        controller: passwordController,
                        hint: 'Mot de passe',
                        isPassword: true,
                      ),
                      const SizedBox(height: 30),
                      LoginButton(onPressed: () async {
                        await handleLogin();
                      }),
                    ],
                  ),
                ),
              ),
            ),
            const Positioned(
              right: 20,
              top: 40,
              child: HelpButton(initialLocation: "0"),
            ),
          ],
        ),
      ),
    );
  }

  /// Handles the login process for the user.
  ///
  /// This function is responsible for sending a POST request to the API with the
  /// provided username and password, and then storing the received token, cookie,
  /// sdk_key_id, sdk_key, driverId, and storeId securely. It also initializes the
  /// SDK and requests user consent.
  ///
  /// If the API returns a 200 status code, it means the login was successful and
  /// the user is redirected to the order list. If the API returns an error, a
  /// snackbar is shown with the error message.
  ///
  /// @param {BuildContext} context The context of the widget.
  /// @return {Future<void>} A future that completes when the login process is done.
  ///
  /// Example:
  /// ```dart
  /// handleLogin(); // Call the handleLogin function
  /// ```
  Future<void> handleLogin() async {
    final username = usernameController.text;
    final password = passwordController.text;

    try {
      if (username.isEmpty || password.isEmpty) {
        if (mounted) {
          Provider.of<OrderProvider>(context, listen: false)
              .showSnackBar(context, 'Veuillez remplir tous les champs.');
        }
        return;
      }

      final apiUrl = Provider.of<Environment>(context, listen: false).apiUrl;
      final url = Uri.parse('$apiUrl/register/login');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      final data = json.decode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        // Store token securely
        await storeTokenSecurely(data["token"]);

        // Store cookie
        await storeCookie(data["token"], driverCookieKey);

        // Store sdk_key_id and sdk_key securely
        const secureStorage = FlutterSecureStorage();
        await secureStorage.write(key: 'sdk_key_id', value: data["sdk_key_id"]);
        await secureStorage.write(key: 'sdk_key', value: data["sdk_key"]);

        // Store driverId securely
        await secureStorage.write(
            key: 'driverId', value: data["driverId"].toString());

        // Store storeId securely
        await secureStorage.write(
            key: 'storeId', value: data["storeId"].toString());

        // Initialize SDK
        SdkContext.init(IsolateOrigin.main);
        SDKOptions sdkOptions = SDKOptions.withAccessKeySecretAndCachePath(
          data["sdk_key_id"], // Ensure sdk_key_id is an integer
          data["sdk_key"],
          "",
        );

        // Make shared instance
        await SDKNativeEngine.makeSharedInstance(sdkOptions);

        // Block when no permissions
        await blockWhenNoPermissions(context);

        // Request user consent
        ConsentEngine consentEngine = ConsentEngine();
        await consentEngine.requestUserConsent(context);

        // Check if the widget is still mounted before navigating
        if (mounted) {
          // Redirect to order list and fetch orders
          await Provider.of<OrderProvider>(context, listen: false)
              .fillOrderAndRedirectWhenArrived(context);
        }
      } else {
        if (mounted) {
          Provider.of<OrderProvider>(context, listen: false)
              .showSnackBar(context, data['detail']);
        }
      }
    } catch (e) {
      if (mounted) {
        Provider.of<OrderProvider>(context, listen: false)
            .showSnackBar(context, "Une erreur s'est produite.");
      }
    }
  }

  Future<void> blockWhenNoPermissions(BuildContext context) async {
    // Request permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.locationWhenInUse,
      Permission.locationAlways,
    ].request();

    // Check if all permissions are granted
    if (statuses.values.every((status) => status.isGranted)) {
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Permissions requises"),
        content: RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                style: TextStyle(color: Colors.black),
                text:
                    "Accès à la caméra requis : Cette application a besoin d'accéder à votre caméra pour vous permettre de capturer et de télécharger des photos directement.\n\n",
              ),
              TextSpan(
                style: TextStyle(color: Colors.black),
                text:
                    "Accès à la localisation demandé : Autorisez l'accès à la localisation lorsque vous utilisez l'application pour activer la navigation en temps réel et les services basés sur la localisation.\n\n",
              ),
              TextSpan(
                style: TextStyle(color: Colors.black),
                text:
                    "Accès continu à la localisation : Accorder un accès continu à la localisation permet à l'application de vous fournir des notifications et des mises à jour basées sur la localisation même lorsque vous n'utilisez pas activement l'application.",
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (!statuses.values.every((status) => status.isGranted)) {
                await blockWhenNoPermissions(context);
              }
            },
            child: const Text('Ok'),
          ),
        ],
      ),
    );
  }
}

class LogoWidget extends StatelessWidget {
  const LogoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 20),
      child: Column(
        children: [
          SvgPicture.string(
            svgString,
            width: 110,
            height: 110,
          ),
          const SizedBox(height: 10),
          Text(
            'SUPERDELIVER',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.normal,
              fontSize: 24.sp,
              fontFamily: 'LexendZetta',
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool isPassword;
  final TextStyle? textStyle;

  const InputField({
    super.key,
    required this.controller,
    required this.hint,
    this.isPassword = false,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      enableSuggestions: !isPassword,
      autocorrect: !isPassword,
      style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.normal, fontSize: 28),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white),
        ),
      ),
    );
  }
}

class LoginButton extends StatelessWidget {
  final VoidCallback onPressed;

  const LoginButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.8,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all<Color>(superBlue),
        ),
        child: const Text(
          'Login',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
