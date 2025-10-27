import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
  late TextEditingController _baseUrlController;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    super.dispose();
  }

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
      final String baseUrl = _baseUrlController.text.trim();
      final String? baseRssURL = baseUrl.isEmpty ? null : baseUrl;

      final xml.XmlDocument opmlDoc =
          convert(npSubscriptionData: jsonData, baseRssURL: baseRssURL);
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
      } else if (Platform.isAndroid || Platform.isIOS) {
        // Mobile: Use share sheet
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(opmlBytes);
        await Share.shareXFiles([XFile(filePath)], text: 'NewPipe OPML Export');
      } else if (Platform.isMacOS ||
          Platform.isLinux ||
          Platform.isWindows) {
        // Desktop: Open save file dialog
        String? savePath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save OPML File',
          fileName: fileName,
          allowedExtensions: ['opml'],
        );

        if (savePath != null) {
          final file = File(savePath);
          await file.writeAsBytes(opmlBytes);
          _showSnackBar('File saved to $savePath');
        }
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
              ElevatedButton.icon(
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('Select .json File'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 16),
                ),
                onPressed: _isLoading ? null : _pickFile,
              ),
              const SizedBox(height: 16),
              Text(_fileName, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 24),
              TextField(
                controller: _baseUrlController,
                decoration: const InputDecoration(
                  labelText: 'Optional: Base RSS URL',
                  hintText:
                      'e.g. https://www.youtube.com/feeds/videos.xml?channel_id=',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                enabled: !_isLoading,
              ),
              const SizedBox(height: 24),
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