import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() {
  runApp(const GuidePage());
}

class GuidePage extends StatelessWidget {
  const GuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Guide SuperDeliver',
      debugShowCheckedModeBanner: false,
      home: MarkdownPage(initialLocation: 'section3'),
    );
  }
}

class MarkdownPage extends StatelessWidget {
  final String initialLocation;

  const MarkdownPage({super.key, required this.initialLocation});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guide SuperDeliver'),
      ),
      body: FutureBuilder<String>(
        future:
            rootBundle.loadString('assets/guide/superDeliver/superdeliver.md'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Error loading markdown file'));
          } else {
            return MarkdownViewer(
              markdownContent: snapshot.data!,
              initialLocation: initialLocation,
            );
          }
        },
      ),
    );
  }
}

class MarkdownViewer extends StatefulWidget {
  final String markdownContent;
  final String initialLocation;

  const MarkdownViewer(
      {super.key,
      required this.markdownContent,
      required this.initialLocation});

  @override
  _MarkdownViewerState createState() => _MarkdownViewerState();
}

class _MarkdownViewerState extends State<MarkdownViewer> {
  final ScrollController _scrollController = ScrollController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollToInitialPosition());
  }

  void _scrollToInitialPosition() {
    final sections = {
      '1': 0.0, //login
    };
    final offset = sections[widget.initialLocation] ?? 0.0;
    _scrollController.jumpTo(offset);
  }

  @override
  Widget build(BuildContext context) {
    return Markdown(
      data: widget.markdownContent,
      controller: _scrollController,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 18.0),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
