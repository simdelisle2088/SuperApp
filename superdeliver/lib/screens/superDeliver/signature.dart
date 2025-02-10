// ignore_for_file: no_leading_underscores_for_local_identifiers, use_build_context_synchronously
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:superdeliver/environment/environment.dart';
import 'package:superdeliver/models/order_details.dart';
import 'package:superdeliver/providers/order_provider.dart';
import 'package:superdeliver/stores/store.dart';
import 'package:superdeliver/variables/colors.dart';
import 'package:http/http.dart' as http;
// import 'package:audioplayers/audioplayers.dart';

class SignatureView extends StatefulWidget {
  const SignatureView({super.key});

  @override
  SignatureViewState createState() => SignatureViewState();
}

class SignatureViewState extends State<SignatureView> {
  List<Offset?> points = <Offset?>[];
  final GlobalKey repaintBoundaryKey = GlobalKey();
  final TextEditingController _textFieldController = TextEditingController();

  Future<void> saveAndUploadSignature(Environment env) async {
    try {
      final ui.Image image = await _captureSignature();
      final Uint8List compressedBytes = await _compressSignature(image);
      await _uploadSignature(env, compressedBytes);
    } catch (e) {
      if (kDebugMode) {
        print('Error occurred during compression or upload: $e');
      }
      showSnackBar("Une erreur s'est produite. Veuillez réessayer.");
    }
  }

  Future<ui.Image> _captureSignature() async {
    RenderRepaintBoundary boundary = repaintBoundaryKey.currentContext!
        .findRenderObject() as RenderRepaintBoundary;
    return await boundary.toImage(pixelRatio: 3.0);
  }

  Future<Uint8List> _compressSignature(ui.Image image) async {
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    Uint8List pngBytes = byteData!.buffer.asUint8List();
    return await FlutterImageCompress.compressWithList(
      pngBytes,
      minWidth: 192,
      minHeight: 192,
      quality: 82,
      format: CompressFormat.webp,
    );
  }

  Future<void> _uploadSignature(
      Environment env, Uint8List compressedBytes) async {
    Order order = Provider.of<OrderProvider>(context, listen: false)
        .getCurrentOrderCopy(context);
    String filename =
        "${order.store}_${order.customer}_${order.order_number}_${await getSignatureName()}.webp";
    final dir = await getTemporaryDirectory();
    File file = File('${dir.path}/$filename');
    await file.writeAsBytes(compressedBytes);

    var url = Uri.parse('${env.apiUrl}/save_images/signature');
    final String token = await retrieveTokenSecurely();

    var request = http.MultipartRequest('POST', url)
      ..headers.addAll({'X-Deliver-Auth': token})
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    var response = await request.send();
    if (response.statusCode != 200) {
      var bytes = await response.stream.toBytes();
      var res = jsonDecode(utf8.decode(bytes));
      showSnackBar(res["detail"]);
    } else {
      dir.delete(recursive: true);
    }
  }

  void showSnackBar(String message) {
    final snackBar = SnackBar(
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height / 2 - 24,
          left: 12,
          right: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  Future<String?> displayTextInputDialog(BuildContext context) async {
    _textFieldController.clear();
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Entrez le nom'),
          content: TextField(
            controller: _textFieldController,
            decoration: const InputDecoration(hintText: "Name"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.pop(context, _textFieldController.text);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> showSaveSuccessDialog() async {
    if (points.isEmpty || points.length < 2) {
      showSnackBar("Veuillez fournir une signature avant d'enregistrer.");
      return;
    }

    String? name = await displayTextInputDialog(context);
    if (name == null || name.trim().isEmpty) {
      showSnackBar("Veuillez saisir un nom avant d'enregistrer.");
      return;
    }

    const FlutterSecureStorage secureStorage = FlutterSecureStorage();
    await secureStorage.write(key: 'signatureName', value: name);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Signature Saved'),
          content: const Text(
              'Souhaitez-vous enregistrer cette signature et revenir au menu principal ?'),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                // Play the audio message
                // final player = AudioPlayer();
                // await player.play(AssetSource('assets/dont_forget_to_take_the_returns.mp3'));

                await saveAndUploadSignature(
                  Provider.of<Environment>(context, listen: false),
                );
                Navigator.pushReplacementNamed(context, '/menuBon');
              },
              child: const Text('Yes'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('No'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/menuBon');
          },
        ),
        title: const Text('Signature'),
        actions: [
          Transform.scale(
            scale: 1.5,
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.only(right: 30),
              child: IconButton(
                icon: const Icon(Icons.save),
                color: superRed,
                onPressed: () async {
                  showSaveSuccessDialog();
                },
              ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onPanUpdate: (DragUpdateDetails details) {
          setState(() {
            RenderBox object = context.findRenderObject() as RenderBox;
            Offset localPosition = object.globalToLocal(details.globalPosition);
            points = List.from(points)..add(localPosition);
          });
        },
        onPanEnd: (DragEndDetails details) => points.add(null),
        child: RepaintBoundary(
          key: repaintBoundaryKey,
          child: CustomPaint(
            painter: SignaturePainter(points),
            size: Size.infinite,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: superBlue,
        foregroundColor: Colors.white,
        onPressed: () {
          setState(() => points.clear());
        },
        child: const Icon(Icons.clear),
      ),
    );
  }
}

class SignaturePainter extends CustomPainter {
  SignaturePainter(this.points);

  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
