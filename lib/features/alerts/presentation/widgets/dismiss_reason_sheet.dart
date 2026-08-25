import 'package:flutter/material.dart';

class DismissReasonSheet extends StatefulWidget {
  final ValueChanged<String> onReasonSelected;

  const DismissReasonSheet({
    super.key,
    required this.onReasonSelected,
  });

  @override
  State<DismissReasonSheet> createState() => _DismissReasonSheetState();
}

class _DismissReasonSheetState extends State<DismissReasonSheet> {
  final TextEditingController _customReasonController = TextEditingController();
  bool _showCustomInput = false;

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Dismissal Reason',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Why are you dismissing this alert?',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),

          if (!_showCustomInput) ...[
            // Option 1: I am on it
            ListTile(
              leading: const Icon(Icons.build_circle_outlined, color: Colors.blue),
              title: const Text('I am on it', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.of(context).pop();
                widget.onReasonSelected('I am on it');
              },
            ),
            const Divider(height: 1),

            // Option 2: Wrong alert
            ListTile(
              leading: const Icon(Icons.report_problem_outlined, color: Colors.orange),
              title: const Text('Wrong alert', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.of(context).pop();
                widget.onReasonSelected('Wrong alert');
              },
            ),
            const Divider(height: 1),

            // Option 3: Something else…
            ListTile(
              leading: const Icon(Icons.edit_note, color: Colors.purple),
              title: const Text('Something else…', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                setState(() {
                  _showCustomInput = true;
                });
              },
            ),
          ] else ...[
            // Custom text input for "Something else..."
            TextField(
              controller: _customReasonController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Enter reason...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showCustomInput = false;
                    });
                  },
                  child: const Text('Back'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final text = _customReasonController.text.trim();
                    if (text.isNotEmpty) {
                      Navigator.of(context).pop();
                      widget.onReasonSelected(text);
                    }
                  },
                  child: const Text('Submit'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
