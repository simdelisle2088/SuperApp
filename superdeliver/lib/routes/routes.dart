import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:superdeliver/providers/transfer_provider.dart';
import 'package:superdeliver/screens/superPicker/returns.dart';
import 'package:superdeliver/screens/superTransfer/login.dart';
import 'package:superdeliver/screens/superTransfer/transfer.dart';
import 'package:superdeliver/screens/superTransfer/transfersBracket.dart'
    // ignore: library_prefixes
    as transfersBracket;
import 'package:superdeliver/screens/superDeliver/confirmation_page.dart';
import 'package:superdeliver/screens/superDeliver/login.dart';
import 'package:superdeliver/screens/superDeliver/menu_bon.dart';
import 'package:superdeliver/screens/superDeliver/order_routes.dart';
import 'package:superdeliver/screens/superDeliver/scan_screen.dart';
import 'package:superdeliver/screens/superDeliver/orders.dart';
import 'package:superdeliver/main.dart';
import 'package:superdeliver/screens/superDeliver/signature.dart';
import 'package:superdeliver/screens/superPicker/Inventory.dart';
import 'package:superdeliver/screens/superPicker/login.dart';
import 'package:superdeliver/screens/superPicker/productListByLvl.dart';
import 'package:superdeliver/screens/superPicker/scan_location.dart';
import 'package:superdeliver/screens/superPicker/setProduct.dart';

Map<String, WidgetBuilder> getAppRoutes() {
  return {
    '/home': (context) => const HomeScreen(),
    '/superdeliverLogin': (context) => const LoginScreen(),
    '/superLocatorLogin': (context) => const LoginScreenLocator(),
    '/superXferLogin': (context) => const LoginScreenTransfer(),
    '/scan': (context) => const ScanScreen(),
    '/scanLocation': (context) => const ScanScreenLocator(),
    '/orderList': (context) => const OrderListScreen(),
    '/orderRoutes': (context) => const OrderRoute(),
    '/menuBon': (context) => const MenuBon(),
    '/signature': (context) => const SignatureView(),
    '/confirmation': (context) => const ConfirmationPage(),
    '/inventory': (context) => const Inventory(),
    '/return': (context) => const ReturnScreen(),
    '/xferStores': (context) => const transfersBracket.StoreXferPage(),
    '/setProduct': (context) {
      final int level = ModalRoute.of(context)!.settings.arguments as int;
      return SetProduct(level: level);
    },
    '/level': (context) {
      final int initialLevel =
          ModalRoute.of(context)!.settings.arguments as int;
      return ProductListByLvl(initialLevel: initialLevel);
    },
  };
}

/// Dynamically handle routes with arguments
Route<dynamic>? onGenerateRoute(RouteSettings settings) {
  if (settings.name == '/transfers') {
    // Ensure arguments are provided and are of the correct type
    if (settings.arguments is Map<String, dynamic>) {
      final args = settings.arguments as Map<String, dynamic>;

      final customerId = args['customerId'] as String?;

      if (customerId != null) {
        return MaterialPageRoute(
          builder: (context) => TransferPage(
            customerId: customerId,
            transferProvider:
                Provider.of<TransferProvider>(context, listen: false),
          ),
        );
      } else {
        // If customerId is null, log and return a default route
        debugPrint('Error: Missing customerId for /transfers route');
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: const Center(
              child: Text('Missing customerId. Please try again.'),
            ),
          ),
        );
      }
    } else {
      // If arguments are invalid, log and return a default route
      debugPrint('Error: Invalid arguments for /transfers route');
      return MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Error')),
          body: const Center(
            child: Text('Invalid route arguments. Please try again.'),
          ),
        ),
      );
    }
  }

  // Return null for unknown routes
  return null;
}
