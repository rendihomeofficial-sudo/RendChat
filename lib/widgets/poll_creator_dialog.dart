import 'package:flutter/material.dart';
import '../theme/whatsapp_theme.dart';

class PollCreatorDialog extends StatefulWidget {
  final Function(String question, List<String> options) onCreated;

  const PollCreatorDialog({super.key, required this.onCreated});

  @override
  State<PollCreatorDialog> createState() => _PollCreatorDialogState();
}

class _PollCreatorDialogState extends State<PollCreatorDialog> {
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length < 10) {
      setState(() {
        _optionControllers.add(TextEditingController());
      });
    }
  }

  void _removeOption(int index) {
    if (_optionControllers.length > 2) {
      setState(() {
        final c = _optionControllers.removeAt(index);
        c.dispose();
      });
    }
  }

  void _submit() {
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a poll question')),
      );
      return;
    }

    final options = _optionControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide at least 2 options')),
      );
      return;
    }

    widget.onCreated(question, options);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WhatsAppTheme.darkBg,
      appBar: AppBar(
        title: const Text('Create Poll'),
        actions: [
          TextButton(
            onPressed: _submit,
            child: const Text(
              'Create',
              style: TextStyle(
                color: WhatsAppTheme.primaryTeal,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Question',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: WhatsAppTheme.primaryTeal,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _questionController,
            maxLines: 2,
            minLines: 1,
            autofocus: true,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Ask a question...',
              filled: true,
              fillColor: WhatsAppTheme.darkSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Options',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: WhatsAppTheme.primaryTeal,
            ),
          ),
          const SizedBox(height: 8),
          ..._optionControllers.asMap().entries.map((entry) {
            final idx = entry.key;
            final controller = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.drag_indicator_rounded, color: WhatsAppTheme.darkTextSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: 'Option ${idx + 1}',
                        filled: true,
                        fillColor: WhatsAppTheme.darkSurface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  if (_optionControllers.length > 2)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                      onPressed: () => _removeOption(idx),
                    ),
                ],
              ),
            );
          }),
          if (_optionControllers.length < 10)
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: WhatsAppTheme.primaryTeal,
                alignment: Alignment.centerLeft,
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add option'),
              onPressed: _addOption,
            ),
        ],
      ),
    );
  }
}
