import 'package:flutter/material.dart';

class ColorSelection {
  const ColorSelection(this.colorValue);

  final int? colorValue;
}

class ItemColorChoice {
  const ItemColorChoice({
    required this.defaultLabel,
    required this.colorValue,
  });

  final String defaultLabel;
  final int colorValue;
}

const List<ItemColorChoice> kItemColorChoices = <ItemColorChoice>[
  ItemColorChoice(defaultLabel: 'Coral', colorValue: 0xFFFFCDD2),
  ItemColorChoice(defaultLabel: 'Orange', colorValue: 0xFFFFE0B2),
  ItemColorChoice(defaultLabel: 'Yellow', colorValue: 0xFFFFF9C4),
  ItemColorChoice(defaultLabel: 'Mint', colorValue: 0xFFC8E6C9),
  ItemColorChoice(defaultLabel: 'Sky', colorValue: 0xFFB3E5FC),
  ItemColorChoice(defaultLabel: 'Lavender', colorValue: 0xFFE1BEE7),
  ItemColorChoice(defaultLabel: 'Stone', colorValue: 0xFFCFD8DC),
];

class ItemColorPickerSheet extends StatelessWidget {
  const ItemColorPickerSheet({
    super.key,
    required this.currentColorValue,
    this.customLabels = const <int, String>{},
  });

  final int? currentColorValue;
  final Map<int, String> customLabels;

  String _displayLabel(ItemColorChoice choice) {
    final String? customLabel = customLabels[choice.colorValue]?.trim();
    if (customLabel == null || customLabel.isEmpty) {
      return choice.defaultLabel;
    }
    return customLabel;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: <Widget>[
          const ListTile(
            title: Text(
              'Select color',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          ListTile(
            leading: Icon(
              Icons.block_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            title: const Text('Default color'),
            trailing:
                currentColorValue == null ? const Icon(Icons.check) : null,
            onTap: () => Navigator.of(context).pop(const ColorSelection(null)),
          ),
          const Divider(height: 1),
          for (final ItemColorChoice choice in kItemColorChoices)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Color(choice.colorValue),
              ),
              title: Text(_displayLabel(choice)),
              trailing: currentColorValue == choice.colorValue
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(context).pop(
                ColorSelection(choice.colorValue),
              ),
            ),
        ],
      ),
    );
  }
}
