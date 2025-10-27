import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:universal_html/html.dart' as html;
import 'package:xml/xml.dart' as xml;

import 'converter.dart'; // Import the new converter file

void main() {
  runApp(const ConverterApp());
}

class ConverterApp extends StatelessWidget {
  const ConverterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NewPipe to OPML',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.redAccent),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _fileName = 'No file selected';
  Uint8List? _fileBytes;
  bool _isLoading = false;

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        setState(() {
          _fileName = result.files.single.name;
          _fileBytes = result.files.single.bytes;
        });
        _showSnackBar('File selected: $_fileName');
      }
    } catch (e) {
      _showSnackBar('Error picking file: $e', isError: true);
    }
  }

  Future<void> _exportFile() async {
    if (_fileBytes == null) {
      _showSnackBar('Please select a file first', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Decode JSON
      final String jsonString = utf8.decode(_fileBytes!);
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);

      // 2. Convert to OPML
      final xml.XmlDocument opmlDoc = convert(npSubscriptionData:  jsonData);
      final String opmlString = opmlDoc.toXmlString(pretty: true, indent: '  ');
      final Uint8List opmlBytes = utf8.encode(opmlString);

      const String fileName = 'newpipe_export.opml';

      // 3. Save file based on platform
      if (kIsWeb) {
        // Web: Trigger browser download
        final blob = html.Blob([opmlBytes], 'application/xml');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        throw Exception('Platform is unsuported');
      }
    } catch (e) {
      _showSnackBar('Error during conversion or saving: $e', isError: true);
      debugPrint('Export Error: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NewPipe to OPML Converter'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.transform_rounded,
                  size: 60, color: Colors.redAccent),
              const SizedBox(height: 20),
              Text(
                'Convert your NewPipe JSON export to an OPML file.',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text('Select .json File'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                    ),
                    onPressed: _isLoading ? null : _pickFile,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(_fileName, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 32),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                FilledButton.icon(
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Export to .opml'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  onPressed: _fileBytes == null ? null : _exportFile,
                ),
            ],
          ),
        ),
      ),
    );
  }
}


