import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../widgets/item_color_picker_sheet.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.exportData,
    required this.colorLabels,
    required this.onColorLabelsChanged,
  });

  final String Function() exportData;
  final Map<int, String> colorLabels;
  final void Function(Map<int, String> colorLabels) onColorLabelsChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final Map<int, String> _colorLabels = Map<int, String>.from(
    widget.colorLabels,
  );

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

  Future<void> _editColorLabel(ItemColorChoice choice) async {
    String pendingLabel = _colorLabels[choice.colorValue] ?? '';

    final String? submittedLabel = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Label for ${choice.defaultLabel}'),
          content: TextFormField(
            initialValue: pendingLabel,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Custom label',
              hintText: 'Enter a label',
            ),
            onChanged: (String value) => pendingLabel = value,
            onFieldSubmitted: (String value) =>
                Navigator.of(dialogContext).pop(value),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(''),
              child: const Text('Clear'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(pendingLabel),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (submittedLabel == null) {
      return;
    }

    final String normalizedLabel = submittedLabel.trim();
    setState(() {
      if (normalizedLabel.isEmpty) {
        _colorLabels.remove(choice.colorValue);
      } else {
        _colorLabels[choice.colorValue] = normalizedLabel;
      }
    });
    widget.onColorLabelsChanged(Map<int, String>.from(_colorLabels));
  }

  String _displayLabel(ItemColorChoice choice) {
    final String? customLabel = _colorLabels[choice.colorValue];
    if (customLabel == null || customLabel.isEmpty) {
      return 'Uses default name in picker';
    }
    return 'Shown as "$customLabel" in picker';
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
            onTap: () => _showJsonExport(context, widget.exportData()),
          ),
          const Divider(height: 1),
          const ListTile(
            title: Text('Color labels'),
            subtitle: Text(
              'Assign custom names shown in color selection menus',
            ),
          ),
          for (final ItemColorChoice choice in kItemColorChoices)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Color(choice.colorValue),
              ),
              title: Text(choice.defaultLabel),
              subtitle: Text(_displayLabel(choice)),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _editColorLabel(choice),
            ),
          if (_colorLabels.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.restart_alt_outlined),
              title: const Text('Reset all color labels'),
              onTap: () {
                setState(_colorLabels.clear);
                widget.onColorLabelsChanged(const <int, String>{});
              },
            ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Tip: leave a label empty to use the default color name.',
            ),
          ),
        ],
      ),
    );
  }
}
