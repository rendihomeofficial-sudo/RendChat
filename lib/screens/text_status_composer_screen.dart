import 'package:flutter/material.dart';
import '../theme/whatsapp_theme.dart';

class TextStatusComposerScreen extends StatefulWidget {
  const TextStatusComposerScreen({super.key});

  @override
  State<TextStatusComposerScreen> createState() => _TextStatusComposerScreenState();
}

class _TextStatusComposerScreenState extends State<TextStatusComposerScreen> {
  final _controller = TextEditingController();
  final List<Color> _colors = const [
    Color(0xFF005C4B),
    Color(0xFF1E3A8A),
    Color(0xFF701A75),
    Color(0xFF831843),
    Color(0xFF9A3412),
    Color(0xFF14532D),
    Color(0xFF312E81),
  ];
  int _colorIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _cycleColor() {
    setState(() {
      _colorIndex = (_colorIndex + 1) % _colors.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = _colors[_colorIndex];

    return Scaffold(
      backgroundColor: currentColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Top Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.color_lens_outlined, color: Colors.white, size: 26),
                    tooltip: 'Change Background Color',
                    onPressed: _cycleColor,
                  ),
                  IconButton(
                    icon: const Icon(Icons.text_fields_rounded, color: Colors.white, size: 26),
                    tooltip: 'Font Style',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Switched to Sans-serif Bold')),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Text Input
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Type a status',
                    hintStyle: TextStyle(color: Colors.white60, fontSize: 30),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),

            // Send FAB
            Positioned(
              bottom: 24,
              right: 20,
              child: FloatingActionButton(
                backgroundColor: WhatsAppTheme.primaryTeal,
                foregroundColor: Colors.white,
                child: const Icon(Icons.send_rounded),
                onPressed: () {
                  final text = _controller.text.trim();
                  if (text.isNotEmpty) {
                    Navigator.pop(context, text);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Status update posted!')),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
