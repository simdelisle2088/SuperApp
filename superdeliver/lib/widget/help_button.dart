import 'package:flutter/material.dart';
import '../screens/superDeliver/guide.dart';

// Updated HelpButton class
class HelpButton extends StatelessWidget {
  final String initialLocation;

  const HelpButton({super.key, required this.initialLocation});

  static const IconData question_mark_rounded =
      IconData(0xf036b, fontFamily: 'MaterialIcons');

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton(
        color: Colors.white,
        icon: const Icon(question_mark_rounded),
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all<Color>(Colors.blue),
          shadowColor: WidgetStateProperty.all<Color>(Colors.black26),
          elevation: WidgetStateProperty.all<double>(10),
        ),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MarkdownPage(initialLocation: initialLocation),
          ),
        ),
      ),
    );
  }

}
