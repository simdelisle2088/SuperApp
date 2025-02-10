import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:superdeliver/providers/Inventory_provider.dart';
import 'package:superdeliver/providers/picker_provider.dart';
import 'package:superdeliver/stores/store.dart';
import 'package:superdeliver/variables/colors.dart';
import 'package:superdeliver/widget/version.dart';

/// A stateful widget that handles the scan screen functionality.
class ScanScreenLocator extends StatefulWidget {
  /// Creates a new instance of [ScanScreenLocator].
  const ScanScreenLocator({super.key});

  @override
  _ScanScreenState createState() => _ScanScreenState();
}

/// The state class for [ScanScreenLocator].
class _ScanScreenState extends State<ScanScreenLocator> {
  late String username;
  String _selectedValue = 'Tout'; // Default selected value

  @override
  void initState() {
    super.initState();
    username = 'Utilisateur'; // Initialize with default value
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    retrieveUsername();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          const BackgroundImage(),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Bonjour, $username',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
                const Text(
                  'Choisissez votre action !',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 20),
                _buildDropdown(),
                const SizedBox(height: 30),
                _buildPlacerProduitButton(context),
                const SizedBox(height: 20),
                _buildPickerProduitButton(context),
                const SizedBox(height: 20),
                _buildInventoryButton(context),
                const SizedBox(height: 20),
                _buildReturnButton(context),
              ],
            ),
          ),
          const LogoutButton(),
          _buildHelpButton(context),
          const VersionDisplay(),
        ],
      ),
    );
  }

  Widget _buildDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9.0),
        ),
        child: DropdownButton<String>(
          value: _selectedValue,
          items: ['Tout', 'Bas', 'Mezzanine', 'Haut']
              .map((value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  ))
              .toList(),
          onChanged: (newValue) {
            setState(() {
              _selectedValue = newValue!;
            });
          },
          dropdownColor: Colors.white,
          isExpanded: true,
          underline: const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildPlacerProduitButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        final int level = _getLevelFromDropdown(_selectedValue);
        Navigator.pushReplacementNamed(
          context,
          '/setProduct',
          arguments: level, // Pass the level to 'Placer un produit' view
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(255, 52, 134, 55),
        minimumSize: const Size(250, 60),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
        ),
      ),
      child: const Text(
        'Placer un produit',
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }

  Widget _buildPickerProduitButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        final int level = _getLevelFromDropdown(_selectedValue);
        // Optionally fetch orders by level
        Provider.of<PickerProvider>(context, listen: false)
            .fetchPickingOrdersByLevel(level);
        Navigator.pushReplacementNamed(
          context,
          '/level',
          arguments: level, // Pass the level to 'Picker un produit' view
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        minimumSize: const Size(250, 60),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
        ),
      ),
      child: const Text(
        'Picker un produit',
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }

  Widget _buildInventoryButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        // Navigate to the inventory page
        Navigator.pushReplacementNamed(
          context,
          '/inventory',
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromRGBO(0, 61, 166, 1),
        minimumSize: const Size(250, 60),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
        ),
      ),
      child: const Text(
        'Inventaire',
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }

  Widget _buildReturnButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        Navigator.pushReplacementNamed(
          context,
          '/return',
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(255, 165, 177, 5),
        minimumSize: const Size(250, 60),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
        ),
      ),
      child: const Text(
        'Retours',
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }

  int _getLevelFromDropdown(String value) {
    return const {
          'Tout': -1,
          'Bas': 1,
          'Mezzanine': 2,
          'Haut': 3,
          'Show Room': 0
        }[value] ??
        -1;
  }

  void showImagePrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('Pour Trouver un produit, suivez cette légende:'),
              const SizedBox(height: 10),
              Image.asset('assets/images/legende.png'),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> retrieveUsername() async {
    const secureStorage = FlutterSecureStorage();
    String? storedUsername = await secureStorage.read(key: 'username');
    if (storedUsername != null && storedUsername.isNotEmpty) {
      setState(() {
        username = storedUsername;
      });
    }
  }

  Widget _buildHelpButton(BuildContext context) {
    return Positioned(
      top: 20,
      right: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Aide',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
            onPressed: () => showImagePrompt(context),
          ),
        ],
      ),
    );
  }
}

Future<void> showLogoutConfirmation(BuildContext context) async {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter?'),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
            },
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
              locatorLogout(context); // Call the logout function
            },
            child: const Text('Déconnexion'),
          ),
        ],
      );
    },
  );
}

// =============== CLASSES ====================================

/// A widget that displays the background image.
class BackgroundImage extends StatelessWidget {
  /// Creates a new instance of [BackgroundImage].
  const BackgroundImage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/background_hp.png"),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

/// A logout button that displays a confirmation dialog when pressed.
class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      right: 20,
      child: Container(
        decoration: BoxDecoration(
          color: superRed,
          borderRadius: BorderRadius.circular(8),
        ),
        child: IconButton(
          onPressed: () => showLogoutConfirmation(context),
          icon: const Icon(
            Icons.logout,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}
