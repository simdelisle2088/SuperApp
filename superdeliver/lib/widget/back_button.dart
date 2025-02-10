import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:superdeliver/variables/svg.dart';

class BackButtonWidget extends StatelessWidget {
  final String location;
  final String confirmationMessage;

  const BackButtonWidget(
    this.location, {
    this.confirmationMessage = 'êtes-vous sûr de vouloir quitter la page?',
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        if (location.isNotEmpty) {
          showLogoutConfirmationDialog(context, confirmationMessage);
        } else {
          // Handle the case where location is empty
          print('Location is empty');
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(255, 66, 59, 59),
      ),
      child: ColorFiltered(
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        child: SvgPicture.string(backIconString),
      ),
    );
  }

  void showLogoutConfirmationDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmation'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('Quitter'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacementNamed(context, location);
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
