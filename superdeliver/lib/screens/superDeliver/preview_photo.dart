import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:superdeliver/environment/environment.dart';
import 'package:superdeliver/models/order_details.dart';
import 'package:superdeliver/providers/order_provider.dart';
import 'package:superdeliver/stores/store.dart';

class PreviewScreen extends StatelessWidget {
  final String imagePath;

  const PreviewScreen({
    super.key,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preview')),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Image.file(File(imagePath)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Save'),
                onPressed: () => saveImage(
                    context,
                    Provider.of<Environment>(context, listen: false),
                    imagePath),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.close),
                label: const Text('Discard'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> saveImage(
      BuildContext context, Environment env, String path) async {
    try {
      Uint8List imageData = await File(path).readAsBytes();
      Uint8List compressedBytes = await FlutterImageCompress.compressWithList(
        imageData,
        minWidth: 512,
        minHeight: 512,
        quality: 70,
        format: CompressFormat.webp,
      );

      Order order = Provider.of<OrderProvider>(context, listen: false)
          .getCurrentOrderCopy(context);
      String filename =
          "${order.store}_${order.customer}_${order.order_number}_photo.webp";

      final dir = await getTemporaryDirectory();
      File file = File('${dir.path}/$filename');
      await file.writeAsBytes(compressedBytes);
      var url = Uri.parse('${env.apiUrl}/save_images/photo');
      final String token = await retrieveTokenSecurely();

      var request = http.MultipartRequest('POST', url)
        ..headers.addAll({
          'X-Deliver-Auth': token,
        })
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      var response = await request.send();
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Téléchargé avec succès !')));
        dir.delete(recursive: true);
        Navigator.pushReplacementNamed(context, '/menuBon');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Échec du téléchargement avec le statut : ${response.statusCode}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text("Une erreur s'est produite lors de l'enregistrement : $e")));
    }
  }
}
