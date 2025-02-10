import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Make sure you have this package added
import 'package:superdeliver/providers/transfer_provider.dart';
import 'package:superdeliver/screens/superTransfer/transfer.dart';
import 'package:superdeliver/widget/logout_button.dart';

class StoreXferPage extends StatefulWidget {
  const StoreXferPage({super.key});

  @override
  State<StoreXferPage> createState() => _StoreXferPageState();
}

class _StoreXferPageState extends State<StoreXferPage> {
  // List of descriptive category names
  final List<String> categoryDescriptions = [
    "St-Hubert St-Jean",
    "St-Hubert Château",
    "St-Jean St-Hubert",
    "St-Jean Château",
    "Château St-Hubert",
    "Château St-Jean",
  ];

  // Mapping of descriptive names to category IDs
  final Map<String, String> categoryMapping = {
    "St-Hubert St-Jean": '000012',
    "St-Hubert Château": '000013',
    "St-Jean St-Hubert": '000021',
    "St-Jean Château": '000023',
    "Château St-Hubert": '000031',
    "Château St-Jean": '000032',
  };

  // Selected category description
  String? selectedDescription;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/background_hp.png"),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Main Content
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(10.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10.0,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Select a Category:',
                    style:
                        TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16.0),
                  DropdownButtonFormField<String>(
                    value: selectedDescription,
                    hint: const Text('Choose a category'),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 12.0, horizontal: 12.0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: const BorderSide(
                          color: Colors.grey,
                          width: 1.5,
                        ),
                      ),
                    ),
                    items: categoryDescriptions.map((String description) {
                      return DropdownMenuItem<String>(
                        value: description,
                        child: Text(
                          description,
                          style: const TextStyle(fontSize: 20.0),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedDescription = newValue;
                      });
                    },
                  ),
                  const SizedBox(height: 16.0),
                  ElevatedButton(
                    onPressed: selectedDescription != null
                        ? () {
                            // Safely retrieve customerId
                            final customerId =
                                categoryMapping[selectedDescription];

                            // Get the TransferProvider instance from Provider
                            final transferProvider =
                                Provider.of<TransferProvider>(
                              context,
                              listen: false,
                            );

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TransferPage(
                                  customerId: customerId ?? 'defaultCustomerId',
                                  transferProvider: transferProvider,
                                ),
                              ),
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12.0,
                        horizontal: 24.0,
                      ),
                      textStyle: const TextStyle(fontSize: 16.0),
                    ),
                    child: const Text('Choisir'),
                  ),
                ],
              ),
            ),
          ),
          // Logout Button
          const LogoutButton(),
        ],
      ),
    );
  }
}
