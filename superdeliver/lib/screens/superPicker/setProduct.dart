import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:superdeliver/providers/locator_provider.dart';
import 'package:superdeliver/stores/store.dart';
import 'package:superdeliver/widget/alerts.dart';
import 'package:superdeliver/widget/back_button.dart';
import 'package:superdeliver/widget/dynamic_table.dart';
import '../../widget/background_image.dart';

class SetProduct extends StatefulWidget {
  final int level;
  const SetProduct({super.key, required this.level});

  @override
  _SetProductState createState() => _SetProductState();
}

class _SetProductState extends State<SetProduct> {
  /// A method channel to communicate with the DataWedge plugin.
  static const MethodChannel channel = MethodChannel('datawedge');

  /// The scanned barcode value.
  String lastLocation = '';
  String scannedBarcode = '';
  int stepsCurrent = 0;
  bool unitaire = true;
  bool isArchive = false;
  bool isAlertOpen = false;
  int itemQuantity = 1;

  List<String> stepsText = [
    'Scannez vos produits à placer',
    'Scannez le code de la tablette de rangement'
  ];
  List<String> columnsProduits = ["Produit", "upc"];
  List<Map<String, dynamic>> content = [];
  List<Map<String, dynamic>> contentHistory = [];
  Timer? refreshTimer; // Timer to handle periodic refresh
  late CustomDataTable customDataTable;
  RegExp isUrl = RegExp(r"^(https?:\/\/)?([\w-]+\.)+[\w-]+(\/[\w- ./?%&=]*)?$");

  @override
  void initState() {
    super.initState();
    initializeDataWedge();
    WidgetsBinding.instance.addPostFrameCallback((_) => precacheImages());
  }

  @override
  void dispose() {
    channel.invokeMethod('stopScan');
    refreshTimer?.cancel();
    super.dispose();
  }

  /// Moves items to a new location, either archiving or adding them.
  ///
  /// This function retrieves the current user ID, extracts the UPC codes from the content,
  /// and updates the item locations using the LocatorProvider. It then displays a success
  /// message and resets the default values.
  ///
  /// @param {bool} archive Whether to archive the items (true) or add them (false)
  ///
  void moveItems(bool archive) async {
    var user = await retrieveUserId();
    List<String> upcList =
        content.map((item) => item['upc'] as String).toList();
    List<String> nameList =
        content.map((item) => item['Produit'] as String).toList();

    Map<String, dynamic> res =
        await Provider.of<LocatorProvider>(context, listen: false)
            .setLocalisation(
      upc: upcList,
      name: nameList,
      updatedBy: user,
      loc: scannedBarcode,
      archive: archive,
      quantity: itemQuantity, // Pass quantity to setLocalisation
    );

    if (res.containsKey('error')) {
      return alert(context, res['error'].toString(), SnackBarType.error);
    }
    String text = (archive) ? 'Retiré avec succès!' : 'Ajouté avec succès!';
    alert(context, text, SnackBarType.success);
    setState(() {
      lastLocation = scannedBarcode;
      setDefaultValues();
    });
  }

  /// Reset values to defaults.
  void setDefaultValues() {
    scannedBarcode = '';
    stepsCurrent = 0;
    itemQuantity = 1;
    content.clear();
    customDataTable.unselect();
  }

  /// Initializes the DataWedge plugin and sets up the method call handler.
  Future<void> initializeDataWedge() async {
    try {
      await channel.invokeMethod('startScan');
      channel.setMethodCallHandler((MethodCall call) async {
        if (call.method == 'barcodeScanned') {
          if (call.arguments.length > 14 || isUrl.hasMatch(call.arguments)) {
            return alert(
                context,
                'Assurez-vous de scanner un codebarre et non un QR Code.',
                SnackBarType.alert);
          }
          final locatorProvider =
              Provider.of<LocatorProvider>(context, listen: false);

          // Continue with your code logic
          switch (stepsCurrent) {
            case 0:
              //scan object UPC first
              if (call.arguments.length == 9 || call.arguments.length == 10) {
                return (unitaire)
                    ? alert(
                        context,
                        'Assurez-vous de scanner un produit et non la tablette.',
                        SnackBarType.alert)
                    : setState(() {
                        scannedBarcode = call.arguments;
                      });
              }
              var list = await locatorProvider.fetchItem(call.arguments);
              if (list.containsKey('status') && list['status'] == 503) {
                return alert(
                    context, 'Erreur de connection', SnackBarType.error);
              }

              setState(() {
                content.add({
                  "Produit": list['data']?['item'] ?? 'inconnu',
                  "upc": list['data']?['upc'] ?? call.arguments,
                  "description":
                      list['data']?['description'] ?? "Aucune description",
                  "locations": (list['data']?['locations']?.isNotEmpty ?? false)
                      ? list['data']['locations'].join(', ')
                      : "Aucune locations",
                });

                customDataTable = CustomDataTable(
                    columnNames: columnsProduits,
                    rowsData: List.from(content) // Create new list reference
                    );

                if (unitaire) {
                  stepsCurrent = 1;
                }
              });

              break;
            case 1:
              //scan tablette code second
              if (call.arguments.length != 9 && call.arguments.length != 10) {
                return alert(context, 'Veuillez scanner une tablette.',
                    SnackBarType.alert);
              }
              setState(() {
                moveItems(isArchive);
                scannedBarcode = call.arguments;
                lastLocation = scannedBarcode;
              });
              break;
          }
        }
      });
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print("Failed to initialize scanner: '${e.message}'.");
      }
    }
  }

  /// Preloads the images to improve performance.
  Future<void> precacheImages() async {
    await precacheImage(
      const AssetImage('assets/images/background_hp-vert.png'),
      context,
    );
  }

  /// Verify if a new order as appeared in the last minutes so it can alert the user and redirect to the right page
  Future<bool> checkNewOrders(LocatorProvider provider) async {
    return await provider.checkNewOrders(widget.level);
  }

  /// A timer that do 'checkNewOrders' every few seconds.
  Future<void> startPeriodicRefresh(LocatorProvider provider) async {
    refreshTimer?.cancel(); // Cancel any existing timer
    refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      bool hasNewOrder = await checkNewOrders(provider);
      if (hasNewOrder && !isAlertOpen) {
        isAlertOpen = true;
        alert(
          context,
          "Une nouvelle commande est prête!",
          SnackBarType.alert,
          duration: const Duration(days: 1),
          position: SnackBarPosition.top,
          onSnackBarTapped: () {
            if (content.isNotEmpty) {
              showCantChangePageDialog(context);
              // isAlertOpen = false;
              return;
            }
            timer.cancel();
            Navigator.pushReplacementNamed(context, '/level',
                arguments: widget.level);
          },
          onSnackBarDismissed: () {
            isAlertOpen = false;
          },
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var locatorProvider = Provider.of<LocatorProvider>(context, listen: false);
    startPeriodicRefresh(locatorProvider);
    customDataTable =
        CustomDataTable(columnNames: columnsProduits, rowsData: content);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Stack(
          children: [
            const BackgroundImage(
              url: 'assets/images/background_hp-vert.png',
            ),
            Container(
              height: MediaQuery.of(context).size.height,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _instructionText(),
                    if (unitaire) _unitaryContent() else _nonUnitaryContent(),
                    const SizedBox(height: 8),
                    if (lastLocation.isNotEmpty)
                      Text(
                        'Tablette Précédente: $lastLocation',
                        textAlign: TextAlign.left,
                        style: TextStyle(fontSize: 18, color: Colors.grey[300]),
                      ),
                    const SizedBox(
                        height:
                            100), // Extra space to prevent overlap with buttonGroup
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: buttonGroup(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _unitaryContent() {
    return Column(
      children: [
        _productDisplay(),
        _locationDisplay(),
        _quantitySelector(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                if (content.isNotEmpty) return;
                setDefaultValues();
                isArchive = !isArchive;
              });
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all<Color>(
                content.isNotEmpty
                    ? Colors.grey
                    : (isArchive ? Colors.red : Colors.green),
              ),
            ),
            child: Text(
              isArchive ? "Mode Retirer" : "Mode Ajouter",
              style: const TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _quantitySelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Quantity: ",
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        IconButton(
          icon: const Icon(Icons.remove, color: Colors.white),
          onPressed: () {
            if (itemQuantity > 1) {
              setState(() {
                itemQuantity--;
              });
            }
          },
        ),
        SizedBox(
          width: 80, // Increased width for larger input field
          child: TextField(
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Colors.white), // White border
              ),
              filled: true,
              fillColor: Colors.grey[800], // Dark background for contrast
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10), // Increased padding
            ),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            controller: TextEditingController(text: itemQuantity.toString()),
            onSubmitted: (value) {
              final int? enteredQuantity = int.tryParse(value);
              if (enteredQuantity != null && enteredQuantity > 0) {
                setState(() {
                  itemQuantity = enteredQuantity;
                });
              }
            },
            onTap: () {
              TextEditingController().clear();
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add, color: Colors.white),
          onPressed: () {
            setState(() {
              itemQuantity++;
            });
          },
        ),
      ],
    );
  }

  Widget _nonUnitaryContent() {
    return Column(
      children: [
        customDataTable,
        _locationDisplay(),
        if (content.isNotEmpty && scannedBarcode != '') buttonGroupAddRemove(),
      ],
    );
  }

  Widget buttonGroupAddRemove() {
    Widget button(String text, Color color, IconData icon, bool archive) {
      return Expanded(
        child: ElevatedButton(
          onPressed: () async {
            moveItems(archive);
          },
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all<Color>(color),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        button('Retirer', Colors.red, Icons.clear, true),
        const SizedBox(width: 8),
        button('Ajouter', Colors.green, Icons.add, false)
      ],
    );
  }

  Widget buttonGroup() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.transparent, // Optional: Adjust background color if needed
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          const BackButtonWidget(
            '/scanLocation',
            confirmationMessage:
                "ATTENTION\n Veuillez être sure d'avoir terminer de placer les produits actifs. Êtes-vous sûr de vouloir quitter la page? \nATTENTION",
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                if (content.isNotEmpty) return;
                setDefaultValues();
                unitaire = !unitaire;
              });
            },
            style: ButtonStyle(
                backgroundColor: (content.isNotEmpty)
                    ? WidgetStateProperty.all<Color>(Colors.grey[500]!)
                    : (unitaire)
                        ? WidgetStateProperty.all<Color>(Colors.green)
                        : WidgetStateProperty.all<Color>(Colors.blue)),
            child: Text(
              (unitaire) ? "Unitaire" : "Batch scan",
              style: const TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (unitaire) {
                return setState(() {
                  setDefaultValues();
                });
              }
              if (stepsCurrent != 0) return;
              if (customDataTable.getSelectedIndices().isEmpty) {
                return alert(context, "Veuillez sélectionner au moin un item.",
                    SnackBarType.alert);
              }
              showDeleteConfirmationDialog(context);
            },
            style: ButtonStyle(
                backgroundColor: (stepsCurrent == 0 || unitaire)
                    ? WidgetStateProperty.all<Color>(Colors.red)
                    : WidgetStateProperty.all<Color>(Colors.grey[500]!)),
            child: Icon(Icons.delete,
                color: (stepsCurrent == 0 || unitaire)
                    ? Colors.grey[300]
                    : Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _instructionText() {
    return SizedBox(
      height: 76,
      width: double.infinity,
      child: Center(
          child: Text(
        stepsText[stepsCurrent],
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 20, color: Colors.grey[300], fontWeight: FontWeight.bold),
      )),
    );
  }

  Widget _productDisplay() {
    Widget buildText(String label, String? value) {
      return Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            '$label ${value ?? ''}',
            textAlign: TextAlign.left,
            style: const TextStyle(
              fontSize: 20,
              color: Colors.black87,
            ),
          ));
    }

    return Container(
        decoration: BoxDecoration(
            color: Colors.grey[300], borderRadius: BorderRadius.circular(10.0)),
        width: double.infinity,
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start, // Aligns children to the left
          children: [
            buildText('UPC:', content.isEmpty ? '' : content[0]['upc']),
            buildText('Nom:', content.isEmpty ? '' : content[0]['Produit']),
            buildText('Description:',
                content.isEmpty ? '' : content[0]['description']),
            buildText(
                'Emplacement:',
                content.isEmpty
                    ? ''
                    : (content[0]['locations'].isNotEmpty)
                        ? content[0]['locations']
                        : "Aucune locations"),
          ],
        ));
  }

  Widget _locationDisplay() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
          color: Colors.grey[300], borderRadius: BorderRadius.circular(10.0)),
      height: 32,
      width: double.infinity,
      child: Center(
          child: Text(
        scannedBarcode.isNotEmpty
            ? scannedBarcode
            : 'aucune tablette sélectionnée',
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 18,
            color:
                (scannedBarcode.isNotEmpty) ? Colors.black87 : Colors.black54),
      )),
    );
  }

  void showCantChangePageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmation'),
          content: Text((content.length == 1)
              ? 'Veuillez terminer de placer votre produit actif'
              : 'Veuillez terminer de placer les produits actifs'),
          actions: <Widget>[
            TextButton(
              child: const Text('Ok'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmation'),
          content: const Text('êtes-vous sûr de vouloir supprimer la liste?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Supprimer'),
              onPressed: () {
                setState(() {
                  customDataTable.handleDeletion();
                });
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Annuler'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
