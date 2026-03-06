import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.exportData,
  });

  final String Function() exportData;

  bool get _isAndroidDevice =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _exportJsonFile(BuildContext context, String exportJson) async {
    try {
      final String sanitizedTimestamp =
          DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');

      final XFile exportFile = XFile.fromData(
        Uint8List.fromList(utf8.encode(exportJson)),
        mimeType: 'application/json',
        name: 'mind-export-$sanitizedTimestamp.json',
      );

      await Share.shareXFiles(
        <XFile>[exportFile],
        text: 'Mind data export (JSON)',
        subject: 'Mind data export',
      );

      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose where to save or share your JSON export.'),
        ),
      );
    } on MissingPluginException {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('JSON file export is only available on Android.'),
        ),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not export JSON file. Please try again.'),
        ),
      );
    }
  }

  Future<void> _showJsonExport(
    BuildContext context,
    String exportJson,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.of(bottomSheetContext).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'JSON Export',
                  style: Theme.of(bottomSheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight:
                        MediaQuery.of(bottomSheetContext).size.height * 0.6,
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(exportJson),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: exportJson));
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Export JSON copied to clipboard.'),
                      ),
                    );
                    Navigator.of(bottomSheetContext).pop();
                  },
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy JSON'),
                ),
                if (_isAndroidDevice) ...<Widget>[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _exportJsonFile(context, exportJson),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Export JSON File (Android)'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: const Text('Export data as JSON'),
            subtitle: const Text(
              'Copy JSON or export a file on Android',
            ),
            onTap: () => _showJsonExport(context, exportData()),
          ),
        ],
      ),
    );
  }
}
