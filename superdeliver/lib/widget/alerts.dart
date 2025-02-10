import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

// Enum to define SnackBar types
enum SnackBarType { alert, error, success, warning }

// Enum to define SnackBar position
enum SnackBarPosition { top, center, bottom }

final AudioPlayer _audioPlayer = AudioPlayer();

// Function to show SnackBar programmatically
void alert(BuildContext context, String message, SnackBarType type,
    {Duration duration = const Duration(seconds: 4),
    SnackBarPosition position = SnackBarPosition.center,
    bool showDismissButton = false,
    VoidCallback? onSnackBarTapped,
    VoidCallback? onDismissButtonPressed,
    VoidCallback? onSnackBarDismissed}) {
  final mediaQueryData = MediaQuery.of(context);
  const double bottomMargin = 50.0;
  const double topMargin = 50.0;

  // Determine the background color, icon, and semantics label based on the SnackBar type
  late Color backgroundColor;
  late IconData icon;
  late String semanticsLabel;
  late String sound;

  switch (type) {
    case SnackBarType.error:
      backgroundColor = Colors.red;
      icon = Icons.error;
      semanticsLabel = 'Error';
      sound = 'sound_error.mp3';
      break;
    case SnackBarType.success:
      backgroundColor = Colors.green;
      icon = Icons.check_circle;
      semanticsLabel = 'Success';
      sound = 'sound_success.mp3';
      break;
    case SnackBarType.alert:
    default:
      backgroundColor = Colors.orange;
      icon = Icons.warning;
      semanticsLabel = 'Alert';
      sound = 'sound_alert.mp3';
      break;
  }

  // Play sound on start
  _audioPlayer.play(AssetSource('sounds/$sound')).catchError((error) {
    debugPrint('Error playing sound: $error');
  });

  // Adjust position based on the selected SnackBarPosition
  EdgeInsetsGeometry margin;
  switch (position) {
    case SnackBarPosition.top:
      margin = EdgeInsets.only(
          bottom: mediaQueryData.size.height - topMargin - 36,
          left: 12,
          right: 12);
      break;
    case SnackBarPosition.bottom:
      margin = const EdgeInsets.only(bottom: bottomMargin, left: 12, right: 12);
      break;
    case SnackBarPosition.center:
    default:
      margin = EdgeInsets.only(
          bottom: mediaQueryData.size.height / 2 - 24, left: 12, right: 12);
      break;
  }

  if (!context.mounted) return;

  ScaffoldMessenger.of(context).hideCurrentSnackBar();

  // Show the SnackBar
  ScaffoldMessenger.of(context)
      .showSnackBar(
        SnackBar(
          content: GestureDetector(
            onTap: () {
              if (onSnackBarTapped != null) {
                onSnackBarTapped();
              }
              // Optionally hide the SnackBar if desired
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Icon(icon, color: Colors.white, semanticLabel: semanticsLabel),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    textAlign: TextAlign.left,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          backgroundColor: backgroundColor,
          duration:
              duration == Duration.zero ? const Duration(days: 1) : duration,
          behavior: SnackBarBehavior.floating,
          margin: margin,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          action: showDismissButton
              ? SnackBarAction(
                  label: 'Dismiss',
                  textColor: Colors.white,
                  onPressed: () {
                    if (onDismissButtonPressed != null) {
                      onDismissButtonPressed();
                    }
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                )
              : null,
        ),
      )
      .closed
      .then((reason) {
    // Check if SnackBar was dismissed due to swipe or programmatic action
    if (reason == SnackBarClosedReason.swipe ||
        reason == SnackBarClosedReason.remove ||
        reason == SnackBarClosedReason.hide) {
      if (onSnackBarDismissed != null) {
        onSnackBarDismissed();
      }
    }
  });
}
