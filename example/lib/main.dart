import 'package:flutter/material.dart';
import 'package:barcode_port/scanner_widgets.dart';

void main() => runApp(
  const MaterialApp(
    home: ScannerExample(
      useProcessing: bool.fromEnvironment('SCANNER_EXAMPLE_POLICY'),
    ),
  ),
);

class ScannerExample extends StatefulWidget {
  const ScannerExample({super.key, this.scanner, this.useProcessing = false});

  /// ScannerListener owns and disposes this source or the default scanner.
  final BarcodeScanner? scanner;
  final bool useProcessing;

  @override
  State<ScannerExample> createState() => _ScannerExampleState();
}

class _ScannerExampleState extends State<ScannerExample> {
  static final _demoPattern = RegExp(r'^[A-Z0-9_-]+$');
  bool _enabled = true;
  String _message = 'Scanning enabled.';
  String _diagnostic = 'No discarded input.';
  int _count = 0;

  BarcodeScanner _createScanner() =>
      widget.scanner ??
      Scanner(
        options: const ScannerOptions(configureIminOutput: true),
        processing: widget.useProcessing
            ? ScanProcessingOptions(
                normalize: (value) => value.toUpperCase(),
                accept: _demoPattern.hasMatch,
                duplicateWindow: const Duration(milliseconds: 500),
              )
            : const ScanProcessingOptions(),
      );

  void _setEnabled(bool enabled) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _enabled = enabled;
      _message = enabled ? 'Scanning enabled.' : 'Stopped.';
    });
  }

  Future<void> _openCover({bool dialog = false}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (dialog) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Scanning paused'),
          content: const Text('Close this dialog to return to the scan area.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Another page')),
            body: const Center(
              child: Text(
                'Scanning is paused while this page covers the scan area.',
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ScannerListener(
    createScanner: _createScanner,
    enabled: _enabled,
    onScan: (scan) =>
        setState(() => _message = 'Scan ${++_count}: ${scan.barcode}'),
    onDiagnostic: (diagnostic) => setState(
      () => _diagnostic =
          'Ignored input: ${diagnostic.reason.name} (${diagnostic.inputLength} characters)',
    ),
    onError: (error, _) => setState(() => _message = 'Scanner error: $error'),
    child: Scaffold(
      appBar: AppBar(title: const Text('BarcodePort example')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_message, key: const ValueKey('scan-result')),
            const SizedBox(height: 8),
            Text(_diagnostic, key: const ValueKey('scan-diagnostic')),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton(
                  onPressed: () => _setEnabled(true),
                  child: const Text('Start'),
                ),
                OutlinedButton(
                  onPressed: () => _setEnabled(false),
                  child: const Text('Stop'),
                ),
                OutlinedButton(
                  onPressed: _openCover,
                  child: const Text('Open another page'),
                ),
                OutlinedButton(
                  onPressed: () => _openCover(dialog: true),
                  child: const Text('Open dialog'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Reception pauses when this page is covered or the app becomes inactive.',
            ),
            const SizedBox(height: 12),
            Text(
              widget.useProcessing
                  ? 'Demo policy: uppercase codes, letters/digits/_/-, 500 ms repeat window.'
                  : 'Default policy: internal codes and repeated scans are accepted.',
            ),
            const SizedBox(height: 24),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Manual input (HID passes through while focused)',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
