import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:superdeliver/providers/order_provider.dart';
import 'package:superdeliver/environment/environment.dart';
import 'package:superdeliver/stores/store.dart';
import 'package:superdeliver/variables/colors.dart';
import 'package:superdeliver/variables/svg.dart';
import 'package:superdeliver/widget/device_info.dart';
import 'package:superdeliver/widget/store_device_info.dart';

/// A login screen for locators.
class LoginScreenLocator extends StatefulWidget {
  const LoginScreenLocator({super.key});

  @override
  LoginScreenLocatorState createState() => LoginScreenLocatorState();
}

/// The state of the login screen for locators.
class LoginScreenLocatorState extends State<LoginScreenLocator> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          height: MediaQuery.of(context).size.height,
          padding:
              const EdgeInsets.only(top: 50, left: 40, right: 40, bottom: 20),
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/images/background_hp.png"),
              fit: BoxFit.cover,
            ),
          ),
          child: Stack(
            children: [
              Center(
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
                      await handleLoginLocator();
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> handleLoginLocator() async {
    final username = usernameController.text;
    final password = passwordController.text;

    try {
      setState(() {
        isLoading = true;
      });

      if (username.isEmpty || password.isEmpty) {
        Provider.of<OrderProvider>(context, listen: false)
            .showSnackBar(context, 'Veuillez remplir tous les champs.');
        return;
      }

      final Map<String, dynamic> deviceInfo =
          await DeviceInfoService.getDeviceInfo();

      final apiUrl = Provider.of<Environment>(context, listen: false).apiUrl;
      final url = Uri.parse('$apiUrl/register/login_locator');

      final requestBody = {
        'username': username,
        'password': password,
        'deviceInfo': deviceInfo,
      };

      final response = await http
          .post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Device-Type': Platform.operatingSystem,
          'X-App-Version': '1.0.0',
        },
        body: jsonEncode(requestBody),
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException(
              'La connexion au serveur a pris trop de temps.');
        },
      );

      final data = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        const secureStorage = FlutterSecureStorage();

        // Store authentication information
        await storeTokenSecurely(data["token"]);
        await storeCookie(data["token"], locatorCookieKey);

        // Store user information
        await secureStorage.write(
            key: 'storeId', value: data["storeId"].toString());
        await secureStorage.write(
            key: 'userId', value: data["user_id"].toString());
        await secureStorage.write(key: 'username', value: data["username"]);

        // Store device information using our dedicated service
        await DeviceStorageService.storeDeviceInfo(deviceInfo);

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/scanLocation',
              arguments: username);
        }
      } else {
        String errorMessage = data['detail'] ?? "Une erreur s'est produite.";

        if (response.statusCode == 401) {
          errorMessage = 'Nom d\'utilisateur ou mot de passe incorrect.';
        } else if (response.statusCode == 403) {
          errorMessage =
              'Accès refusé. Veuillez contacter votre administrateur.';
        }

        if (mounted) {
          Provider.of<OrderProvider>(context, listen: false)
              .showSnackBar(context, errorMessage);
        }
      }
    } on TimeoutException {
      if (mounted) {
        Provider.of<OrderProvider>(context, listen: false).showSnackBar(
            context, "Le serveur ne répond pas. Veuillez réessayer.");
      }
    } catch (e) {
      print('Login error: $e');
      if (mounted) {
        Provider.of<OrderProvider>(context, listen: false)
            .showSnackBar(context, "Une erreur s'est produite.");
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }
}

/// A logo widget for the login screen.
class LogoWidget extends StatelessWidget {
  const LogoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 20),
      child: Column(
        children: [
          SvgPicture.string(
            svgPicker,
            width: 110,
            height: 110,
          ),
        ],
      ),
    );
  }
}

/// An input field for the login screen.
///
/// Parameters:
/// - `controller`: The text editing controller for the input field.
/// - `hint`: The hint text for the input field.
/// - `isPassword`: Whether the input field is for a password (default: false).
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

/// A login button for the login screen.
///
/// Parameters:
/// - `onPressed`: The callback function to be called when the button is pressed.
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
