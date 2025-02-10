import 'dart:convert';
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

/// A login screen for locators.
class LoginScreenTransfer extends StatefulWidget {
  const LoginScreenTransfer({super.key});

  @override
  LoginScreenTransferState createState() => LoginScreenTransferState();
}

/// The state of the login screen for locators.
class LoginScreenTransferState extends State<LoginScreenTransfer> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

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
      if (username.isEmpty || password.isEmpty) {
        Provider.of<OrderProvider>(context, listen: false)
            .showSnackBar(context, 'Veuillez remplir tous les champs.');
        return;
      }

      final apiUrl = Provider.of<Environment>(context, listen: false).apiUrl;
      final url = Uri.parse('$apiUrl/register/login_xfer');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      final data = json.decode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        // Store token securely
        await storeTokenSecurely(data["token"]);

        // Store cookie with locator-specific key
        await storeCookie(data["token"], xferCookieKey);

        const secureStorage = FlutterSecureStorage();
        // Store storeId securely
        await secureStorage.write(
            key: 'storeId', value: data["storeId"].toString());
        // Store userId securely
        await secureStorage.write(
            key: 'userId', value: data["user_id"].toString());
        // Store username securely
        await secureStorage.write(key: 'username', value: data["username"]);

        // Navigate to the /scan_location route
        Navigator.pushReplacementNamed(context, '/xferStores',
            arguments: username);
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
            svgTransfer,
            width: 110,
            height: 110,
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
