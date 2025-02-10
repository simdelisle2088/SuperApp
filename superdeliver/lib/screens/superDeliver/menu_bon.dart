// ignore_for_file: file_names
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:superdeliver/providers/order_provider.dart';
import 'package:superdeliver/screens/superDeliver/order_routes.dart';
import 'package:superdeliver/screens/superDeliver/photo.dart';
import 'package:superdeliver/variables/colors.dart';
import 'package:url_launcher/url_launcher.dart';

List<CameraDescription>? cameras;
CameraDescription? firstCamera;

class MenuBon extends StatefulWidget {
  const MenuBon({super.key});

  @override
  MenuBonState createState() => MenuBonState();
}

class MenuBonState extends State<MenuBon> {
  bool showContactPopup = false;

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          buildBackground(),
          buildGradientContainer(context),
          buildExitButton(context),
          if (showContactPopup) contactPopup(context),
        ],
      ),
    );
  }

  Widget buildExitButton(BuildContext context) {
    return Positioned(
      bottom: 20,
      right: 20,
      child: ElevatedButton(
        onPressed: () => showLogoutConfirmationDialog(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: superRed,
          foregroundColor: Colors.white,
        ),
        child: const Text('Déconnexion'),
      ),
    );
  }

  Widget buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/images/background_hp.png"),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget buildGradientContainer(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Consumer<OrderProvider>(
        builder: (context, orderProvider, child) {
          String orderNumber = '';
          if (orderProvider.orders.isNotEmpty) {
            orderNumber = orderProvider.orders.first.order_number;
          }
          return Container(
            margin: const EdgeInsets.only(top: 50),
            width: MediaQuery.of(context).size.width * 0.9,
            height: 350,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
                colors: [gradientPale, gradientFonce],
              ),
            ),
            child: Center(
              child: Stack(
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      viewOrderParts(context),
                      contactButton(context),
                      photoButton(context),
                      livrasion(context, orderProvider),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget viewOrderParts(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        Navigator.pushReplacementNamed(context, '/confirmation');
      },
      style: ElevatedButton.styleFrom(
          backgroundColor: menuBlue,
          foregroundColor: Colors.white,
          minimumSize: Size(MediaQuery.of(context).size.width * 0.72, 50)),
      child: const Text('Pièces de la commande'),
    );
  }

  Widget contactButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          showContactPopup = !showContactPopup;
        });
      },
      style: ElevatedButton.styleFrom(
          backgroundColor: menuBlue,
          foregroundColor: Colors.white,
          minimumSize: Size(MediaQuery.of(context).size.width * 0.72, 50)),
      child: const Text('Contacter le Dispatch'),
    );
  }

  Widget photoButton(BuildContext context) {
    return Consumer<OrderProvider>(
      builder: (context, orderProvider, child) {
        return ElevatedButton(
          onPressed: () {
            if (firstCamera != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PhotoCaptureView(camera: firstCamera!),
                ),
              );
            } else {
              if (kDebugMode) {
                print('Camera not initialized');
              }
            }
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: menuBlue,
              foregroundColor: Colors.white,
              minimumSize: Size(MediaQuery.of(context).size.width * 0.72, 50)),
          child: const Text('Prendre une photo'),
        );
      },
    );
  }

  Widget livrasion(BuildContext context, OrderProvider orderProvider) {
    return ElevatedButton(
      onPressed: () async {
        bool success = await orderProvider.updateOrderDeliveryStatus(context);

        if (success) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const OrderRoute(),
            ),
          );
        } else {
          // Show an error message
          if (kDebugMode) {
            print('Erreur!!!');
          }
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        minimumSize: Size(MediaQuery.of(context).size.width * 0.72, 50),
      ),
      child: const Text('Livrée'),
    );
  }

  Widget contactPopup(BuildContext context) {
    return Positioned.fill(
      child: Align(
        alignment: Alignment.center,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.72,
          height: 300,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('St-Hubert'),
                buildPhoneNumber("450-676-1850"),
                const SizedBox(height: 20),
                const Text('St-Jean-Sur-Richelieu'),
                buildPhoneNumber("450-515-2000"),
                const SizedBox(height: 20),
                const Text('Châteauguay'),
                buildPhoneNumber("450-507-2010"),
                const SizedBox(height: 30),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/menuBon'),
                  child:
                      const Text("Cancel", style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildPhoneNumber(String phoneNumber) {
    return InkWell(
      onTap: () async {
        await makePhoneCall(phoneNumber);
      },
      child: Text(
        phoneNumber,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 18,
          color: Colors.blue,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      throw 'Could not launch $launchUri';
    }
  }

  Future<void> initializeCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras != null && cameras!.isNotEmpty) {
        setState(() {
          firstCamera = cameras![0];
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing camera: $e');
      }
    }
  }
}
