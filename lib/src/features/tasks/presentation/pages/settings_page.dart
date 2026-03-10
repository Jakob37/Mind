import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../widgets/item_color_picker_sheet.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.exportData,
    required this.exportPlainText,
    required this.onImportData,
    required this.colorLabels,
    required this.onColorLabelsChanged,
    required this.hideCompletedProjectItems,
    required this.onHideCompletedProjectItemsChanged,
  });

  final String Function() exportData;
  final String Function() exportPlainText;
  final Future<String?> Function(String) onImportData;
  final Map<int, String> colorLabels;
  final void Function(Map<int, String> colorLabels) onColorLabelsChanged;
  final bool hideCompletedProjectItems;
  final ValueChanged<bool> onHideCompletedProjectItemsChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final Map<int, String> _colorLabels = Map<int, String>.from(
    widget.colorLabels,
  );
  late bool _hideCompletedProjectItems = widget.hideCompletedProjectItems;

  bool get _isAndroidDevice =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _exportJsonFile(BuildContext context, String exportJson) async {
    await _exportTextFile(
      context: context,
      contents: exportJson,
      mimeType: 'application/json',
      prefix: 'mind-export',
      extension: 'json',
      successMessage: 'Choose where to save or share your JSON export.',
      unsupportedMessage: 'JSON file export is only available on Android.',
      failureMessage: 'Could not export JSON file. Please try again.',
    );
  }

  Future<void> _exportPlainTextFile(
      BuildContext context, String exportText) async {
    await _exportTextFile(
      context: context,
      contents: exportText,
      mimeType: 'text/plain',
      prefix: 'mind-export',
      extension: 'txt',
      successMessage: 'Choose where to save or share your text export.',
      unsupportedMessage: 'Text file export is only available on Android.',
      failureMessage: 'Could not export text file. Please try again.',
    );
  }

  Future<void> _exportTextFile({
    required BuildContext context,
    required String contents,
    required String mimeType,
    required String prefix,
    required String extension,
    required String successMessage,
    required String unsupportedMessage,
    required String failureMessage,
  }) async {
    try {
      final String sanitizedTimestamp =
          DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');

      final XFile exportFile = XFile.fromData(
        Uint8List.fromList(utf8.encode(contents)),
        mimeType: mimeType,
        name: '$prefix-$sanitizedTimestamp.$extension',
      );

      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[exportFile],
          text: 'Mind data export',
          subject: 'Mind data export',
        ),
      );

      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } on MissingPluginException {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(unsupportedMessage)),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage)),
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

  Future<void> _showPlainTextExport(
    BuildContext context,
    String exportText,
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
                  'Text Export',
                  style: Theme.of(bottomSheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight:
                        MediaQuery.of(bottomSheetContext).size.height * 0.6,
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(exportText),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: exportText));
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Export text copied to clipboard.'),
                      ),
                    );
                    Navigator.of(bottomSheetContext).pop();
                  },
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy Text'),
                ),
                if (_isAndroidDevice) ...<Widget>[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _exportPlainTextFile(context, exportText),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Export TXT File (Android)'),
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

  Future<void> _showJsonImport(BuildContext context) async {
    const XTypeGroup jsonTypeGroup = XTypeGroup(
      label: 'JSON',
      extensions: <String>['json'],
      mimeTypes: <String>['application/json', 'text/json'],
    );

    try {
      final XFile? file = await openFile(
        acceptedTypeGroups: <XTypeGroup>[jsonTypeGroup],
        confirmButtonText: 'Import',
      );
      if (file == null) {
        return;
      }

      if (!context.mounted) {
        return;
      }

      final bool shouldImport = await _confirmJsonImport(context, file.name);
      if (!shouldImport) {
        return;
      }

      final String importJson = await file.readAsString();
      final String? errorMessage = await widget.onImportData(importJson);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage ?? 'JSON import complete. Current data was replaced.',
          ),
        ),
      );
    } on MissingPluginException {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File import is not available on this device.'),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not import JSON file: $error'),
        ),
      );
    }
  }

  Future<bool> _confirmJsonImport(
    BuildContext context,
    String fileName,
  ) async {
    final bool? shouldImport = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Import JSON'),
          content: Text(
            'Import "$fileName"? This replaces the current board state.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Import'),
            ),
          ],
        );
      },
    );
    return shouldImport ?? false;
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
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('Import data from JSON'),
            subtitle: const Text(
              'Choose a previous JSON export file and replace current data',
            ),
            onTap: () => _showJsonImport(context),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.text_snippet_outlined),
            title: const Text('Export projects and tasks as text'),
            subtitle: const Text(
              'Copy nested content or export a TXT file on Android',
            ),
            onTap: () =>
                _showPlainTextExport(context, widget.exportPlainText()),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.check_box_outlined),
            title: const Text('Hide completed project checklist items'),
            subtitle: const Text(
              'Completed nested planning items are collapsed from project views',
            ),
            value: _hideCompletedProjectItems,
            onChanged: (bool value) {
              setState(() {
                _hideCompletedProjectItems = value;
              });
              widget.onHideCompletedProjectItemsChanged(value);
            },
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
