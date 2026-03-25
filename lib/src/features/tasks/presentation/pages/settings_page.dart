import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:flutter/services.dart';

import '../../data/task_backup_service.dart';
import '../../data/task_sync_service.dart';
import '../../domain/task_models.dart';
import '../widgets/card_layout.dart';
import '../widgets/edit_project_type_sheet.dart';
import '../widgets/item_icon_picker_sheet.dart';
import '../widgets/item_color_picker_sheet.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.exportData,
    required this.exportPlainText,
    required this.onImportData,
    required this.projectTypes,
    required this.onProjectTypesChanged,
    required this.colorLabels,
    required this.onColorLabelsChanged,
    required this.hideCompletedProjectItems,
    required this.onHideCompletedProjectItemsChanged,
    required this.automaticBackupsEnabled,
    required this.onAutomaticBackupsEnabledChanged,
    required this.listAutomaticBackups,
    required this.onRestoreAutomaticBackup,
    required this.cloudAccountState,
    required this.onManageCloudAccount,
    required this.onSignOutCloudAccount,
    required this.onUploadCloudBoard,
    required this.onRestoreCloudBoard,
    required this.cardLayoutPreset,
    required this.onCardLayoutPresetChanged,
  });

  final String Function() exportData;
  final String Function() exportPlainText;
  final Future<String?> Function(String) onImportData;
  final List<ProjectTypeConfig> projectTypes;
  final ValueChanged<List<ProjectTypeConfig>> onProjectTypesChanged;
  final Map<int, String> colorLabels;
  final void Function(Map<int, String> colorLabels) onColorLabelsChanged;
  final bool hideCompletedProjectItems;
  final ValueChanged<bool> onHideCompletedProjectItemsChanged;
  final bool automaticBackupsEnabled;
  final Future<String?> Function(bool enabled) onAutomaticBackupsEnabledChanged;
  final Future<List<TaskBackupEntry>> Function() listAutomaticBackups;
  final Future<String?> Function(String backupId) onRestoreAutomaticBackup;
  final TaskSyncAccountState cloudAccountState;
  final Future<TaskSyncAccountState> Function() onManageCloudAccount;
  final Future<TaskSyncAccountState> Function() onSignOutCloudAccount;
  final Future<String?> Function() onUploadCloudBoard;
  final Future<String?> Function() onRestoreCloudBoard;
  final CardLayoutPreset cardLayoutPreset;
  final ValueChanged<CardLayoutPreset> onCardLayoutPresetChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final List<ProjectTypeConfig> _projectTypes = widget.projectTypes
      .map((ProjectTypeConfig type) => type.clone())
      .toList();
  late final Map<int, String> _colorLabels = Map<int, String>.from(
    widget.colorLabels,
  );
  late bool _hideCompletedProjectItems = widget.hideCompletedProjectItems;
  late bool _automaticBackupsEnabled = widget.automaticBackupsEnabled;
  late TaskSyncAccountState _cloudAccountState = widget.cloudAccountState;
  late CardLayoutPreset _cardLayoutPreset = widget.cardLayoutPreset;

  bool get _isAndroidDevice =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool get _supportsFolderSave => !kIsWeb && !_isAndroidDevice;

  Future<void> _saveJsonFileOnAndroid(
    BuildContext context,
    String exportJson,
  ) async {
    await _saveTextFileOnAndroid(
      context: context,
      contents: exportJson,
      mimeType: 'application/json',
      prefix: 'mind-export',
      extension: 'json',
      successMessage: 'JSON export saved.',
      unsupportedMessage: 'JSON file export is only available on Android.',
      failureMessage: 'Could not export JSON file. Please try again.',
    );
  }

  Future<void> _savePlainTextFileOnAndroid(
    BuildContext context,
    String exportText,
  ) async {
    await _saveTextFileOnAndroid(
      context: context,
      contents: exportText,
      mimeType: 'text/plain',
      prefix: 'mind-export',
      extension: 'txt',
      successMessage: 'Text export saved.',
      unsupportedMessage: 'Text file export is only available on Android.',
      failureMessage: 'Could not export text file. Please try again.',
    );
  }

  String _timestampedFileName({
    required String prefix,
    required String extension,
  }) {
    final String sanitizedTimestamp =
        DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    return '$prefix-$sanitizedTimestamp.$extension';
  }

  Future<void> _saveTextFileOnAndroid({
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
      final String suggestedName = _timestampedFileName(
        prefix: prefix,
        extension: extension,
      );
      final String? savedPath = await FlutterFileDialog.saveFile(
        params: SaveFileDialogParams(
          data: Uint8List.fromList(utf8.encode(contents)),
          fileName: suggestedName,
          mimeTypesFilter: <String>[mimeType],
        ),
      );
      if (savedPath == null) {
        return;
      }

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
    } on PlatformException {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage)),
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

  Future<void> _saveJsonToFolder(
    BuildContext context,
    String exportJson,
  ) async {
    if (_isAndroidDevice) {
      await _saveJsonFileOnAndroid(context, exportJson);
      return;
    }

    try {
      final String suggestedName = _timestampedFileName(
        prefix: 'mind-export',
        extension: 'json',
      );
      final FileSaveLocation? saveLocation = await getSaveLocation(
        suggestedName: suggestedName,
        confirmButtonText: 'Save',
      );
      if (saveLocation == null || saveLocation.path.isEmpty) {
        return;
      }

      final XFile exportFile = XFile.fromData(
        Uint8List.fromList(utf8.encode(exportJson)),
        mimeType: 'application/json',
        name: suggestedName,
      );
      final String outputPath = saveLocation.path;
      await exportFile.saveTo(outputPath);

      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('JSON export saved to $outputPath')),
      );
    } on MissingPluginException {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saving to a folder is not available on this device.'),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save JSON export: $error')),
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
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double maxPreviewHeight = constraints.maxHeight.isFinite
                    ? constraints.maxHeight * 0.5
                    : MediaQuery.of(bottomSheetContext).size.height * 0.5;
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          'JSON Export',
                          style:
                              Theme.of(bottomSheetContext).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: maxPreviewHeight,
                          ),
                          child: SingleChildScrollView(
                            child: SelectableText(exportJson),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: exportJson),
                            );
                            if (!context.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Export JSON copied to clipboard.'),
                              ),
                            );
                            Navigator.of(bottomSheetContext).pop();
                          },
                          icon: const Icon(Icons.copy_outlined),
                          label: const Text('Copy JSON'),
                        ),
                        if (_supportsFolderSave) ...<Widget>[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _saveJsonToFolder(context, exportJson),
                            icon: const Icon(Icons.folder_open_outlined),
                            label: const Text('Save JSON File'),
                          ),
                        ],
                        if (_isAndroidDevice) ...<Widget>[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _saveJsonFileOnAndroid(context, exportJson),
                            icon: const Icon(Icons.download_outlined),
                            label: const Text('Save JSON File (Android)'),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
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
                    onPressed: () =>
                        _savePlainTextFileOnAndroid(context, exportText),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Save TXT File (Android)'),
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

  String _projectTypeSummary(ProjectTypeConfig type) {
    final List<String> labels = <String>[];
    if (type.layoutKind == ProjectLayoutKind.peopleContainer) {
      labels.add('people');
    }
    if (type.showsJournalEntries) {
      labels.add('journal');
    }
    if (type.showsIdeas) {
      labels.add('ideas');
    }
    if (type.showsPlanningTasks) {
      labels.add('tasks');
    }
    if (labels.isEmpty) {
      labels.add('blank');
    }
    return labels.join(' + ');
  }

  Future<void> _editProjectType(ProjectTypeConfig type) async {
    final ProjectTypeConfig? updatedType =
        await showModalBottomSheet<ProjectTypeConfig>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditProjectTypeSheet(projectType: type),
    );
    if (updatedType == null) {
      return;
    }

    setState(() {
      final int index = _projectTypes.indexWhere(
        (ProjectTypeConfig entry) => entry.id == updatedType.id,
      );
      if (index >= 0) {
        _projectTypes[index] = updatedType;
      }
    });
    widget.onProjectTypesChanged(
      _projectTypes.map((ProjectTypeConfig type) => type.clone()).toList(),
    );
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

  Future<void> _editCardLayoutPreset() async {
    final CardLayoutPreset? selectedPreset =
        await showModalBottomSheet<CardLayoutPreset>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              const ListTile(
                title: Text(
                  'Card size',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text('Adjust padding and title size for cards'),
              ),
              const Divider(height: 1),
              for (final CardLayoutPreset preset in CardLayoutPreset.values)
                ListTile(
                  title: Text(cardLayoutPresetLabel(preset)),
                  trailing: preset == _cardLayoutPreset
                      ? const Icon(Icons.check)
                      : null,
                  selected: preset == _cardLayoutPreset,
                  onTap: () => Navigator.of(context).pop(preset),
                ),
            ],
          ),
        );
      },
    );

    if (selectedPreset == null) {
      return;
    }

    setState(() {
      _cardLayoutPreset = selectedPreset;
    });
    widget.onCardLayoutPresetChanged(selectedPreset);
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

  Future<void> _toggleAutomaticBackups(bool enabled) async {
    final String? errorMessage =
        await widget.onAutomaticBackupsEnabledChanged(enabled);
    if (!mounted) {
      return;
    }

    if (errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
      return;
    }

    setState(() {
      _automaticBackupsEnabled = enabled;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled
              ? 'Automatic backups enabled.'
              : 'Automatic backups disabled.',
        ),
      ),
    );
  }

  Future<void> _manageCloudAccount() async {
    final TaskSyncAccountState accountState =
        await widget.onManageCloudAccount();
    if (!mounted) {
      return;
    }

    setState(() {
      _cloudAccountState = accountState;
    });
  }

  Future<void> _signOutCloudAccount() async {
    final TaskSyncAccountState accountState =
        await widget.onSignOutCloudAccount();
    if (!mounted) {
      return;
    }

    setState(() {
      _cloudAccountState = accountState;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signed out of cloud account.')),
    );
  }

  Future<bool> _confirmCloudRestore() async {
    final bool? shouldRestore = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Restore cloud board'),
          content: const Text(
            'Restore the latest cloud snapshot? This replaces the current local board state.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );
    return shouldRestore ?? false;
  }

  Future<void> _uploadCloudBoard() async {
    final String? message = await widget.onUploadCloudBoard();
    if (!mounted || message == null) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _restoreCloudBoard() async {
    final bool shouldRestore = await _confirmCloudRestore();
    if (!mounted || !shouldRestore) {
      return;
    }

    final String? message = await widget.onRestoreCloudBoard();
    if (!mounted || message == null) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _backupTimeLabel(BuildContext context, DateTime savedAt) {
    final MaterialLocalizations localizations = MaterialLocalizations.of(
      context,
    );
    return '${localizations.formatFullDate(savedAt)} at '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(savedAt))}';
  }

  Future<bool> _confirmAutomaticBackupRestore(TaskBackupEntry backup) async {
    final bool? shouldRestore = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Restore backup'),
          content: Text(
            'Restore "${backup.fileName}"? This replaces the current board state.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );
    return shouldRestore ?? false;
  }

  Future<void> _restoreAutomaticBackup() async {
    final List<TaskBackupEntry> backups = await widget.listAutomaticBackups();
    if (!mounted) {
      return;
    }

    if (backups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No automatic backups are available yet.')),
      );
      return;
    }

    final TaskBackupEntry? selectedBackup =
        await showModalBottomSheet<TaskBackupEntry>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              const ListTile(
                title: Text(
                  'Restore Automatic Backup',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text('Choose a recent local JSON snapshot'),
              ),
              const Divider(height: 1),
              for (final TaskBackupEntry backup in backups)
                ListTile(
                  leading: const Icon(Icons.history_outlined),
                  title: Text(_backupTimeLabel(context, backup.savedAt)),
                  subtitle: Text(backup.fileName),
                  onTap: () => Navigator.of(context).pop(backup),
                ),
            ],
          ),
        );
      },
    );

    if (!mounted || selectedBackup == null) {
      return;
    }

    final bool shouldRestore =
        await _confirmAutomaticBackupRestore(selectedBackup);
    if (!mounted || !shouldRestore) {
      return;
    }

    final String? errorMessage =
        await widget.onRestoreAutomaticBackup(selectedBackup.id);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          errorMessage ??
              'Automatic backup restored. Current data was replaced.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: <Widget>[
          if (!_cloudAccountState.isConfigured) ...<Widget>[
            const ListTile(
              leading: Icon(Icons.cloud_off_outlined),
              title: Text('Cloud account unavailable'),
              subtitle: Text(
                'Launch with SUPABASE_URL and SUPABASE_ANON_KEY to enable '
                'account setup.',
              ),
            ),
            const Divider(height: 1),
          ] else if (_cloudAccountState.isSignedIn) ...<Widget>[
            ListTile(
              leading: const Icon(Icons.cloud_done_outlined),
              title: const Text('Cloud account connected'),
              subtitle: Text(
                _cloudAccountState.email == null
                    ? 'Signed in. Upload the current board or restore the latest cloud snapshot.'
                    : 'Signed in as ${_cloudAccountState.email}. Upload the current board or restore the latest cloud snapshot.',
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.cloud_upload_outlined),
              title: const Text('Upload board to cloud'),
              subtitle: const Text(
                'Save the current local board snapshot to your account',
              ),
              onTap: _uploadCloudBoard,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.cloud_download_outlined),
              title: const Text('Restore board from cloud'),
              subtitle: const Text(
                'Replace the local board with the latest saved cloud snapshot',
              ),
              onTap: _restoreCloudBoard,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout_outlined),
              title: const Text('Sign out of cloud account'),
              subtitle: const Text('Keep using the app locally on this device'),
              onTap: _signOutCloudAccount,
            ),
            const Divider(height: 1),
          ] else ...<Widget>[
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text('Set up cloud account'),
              subtitle: const Text(
                'Create an account or sign in with email and password',
              ),
              onTap: _manageCloudAccount,
            ),
            const Divider(height: 1),
          ],
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: const Text('Export data as JSON'),
            subtitle: const Text(
              'Copy JSON or save a file on Android',
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
          SwitchListTile(
            secondary: const Icon(Icons.backup_outlined),
            title: const Text('Automatic JSON backups'),
            subtitle: const Text(
              'Keep up to 20 recent local snapshots and update them automatically',
            ),
            value: _automaticBackupsEnabled,
            onChanged: _toggleAutomaticBackups,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.restore_outlined),
            title: const Text('Restore from automatic backup'),
            subtitle: const Text(
              'Choose one of the recent local snapshots and replace current data',
            ),
            onTap: _restoreAutomaticBackup,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.text_snippet_outlined),
            title: const Text('Export projects and tasks as text'),
            subtitle: const Text(
              'Copy nested content or save a TXT file on Android',
            ),
            onTap: () =>
                _showPlainTextExport(context, widget.exportPlainText()),
          ),
          const Divider(height: 1),
          const ListTile(
            title: Text('Project types'),
            subtitle: Text(
              'Configure the icon and whether each type shows journal, ideas, and tasks',
            ),
          ),
          for (final ProjectTypeConfig type in _projectTypes)
            ListTile(
              leading: Icon(
                iconDataForKey(type.iconKey) ?? Icons.label_outline,
              ),
              title: Text(type.name),
              subtitle: Text(_projectTypeSummary(type)),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _editProjectType(type),
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
          ListTile(
            leading: const Icon(Icons.view_agenda_outlined),
            title: const Text('Card size'),
            subtitle: Text(cardLayoutPresetLabel(_cardLayoutPreset)),
            trailing: const Icon(Icons.chevron_right_outlined),
            onTap: _editCardLayoutPreset,
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
