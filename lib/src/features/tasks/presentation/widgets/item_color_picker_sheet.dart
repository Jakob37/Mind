import 'package:flutter/material.dart';

class ColorSelection {
  const ColorSelection(this.colorValue);

  final int? colorValue;
}

class _ColorChoice {
  const _ColorChoice({
    required this.label,
    required this.colorValue,
  });

  final String label;
  final int colorValue;
}

const List<_ColorChoice> _colorChoices = <_ColorChoice>[
  _ColorChoice(label: 'Coral', colorValue: 0xFFFFCDD2),
  _ColorChoice(label: 'Orange', colorValue: 0xFFFFE0B2),
  _ColorChoice(label: 'Yellow', colorValue: 0xFFFFF9C4),
  _ColorChoice(label: 'Mint', colorValue: 0xFFC8E6C9),
  _ColorChoice(label: 'Sky', colorValue: 0xFFB3E5FC),
  _ColorChoice(label: 'Lavender', colorValue: 0xFFE1BEE7),
  _ColorChoice(label: 'Stone', colorValue: 0xFFCFD8DC),
];

class ItemColorPickerSheet extends StatelessWidget {
  const ItemColorPickerSheet({
    super.key,
    required this.currentColorValue,
  });

  final int? currentColorValue;

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
          for (final _ColorChoice choice in _colorChoices)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Color(choice.colorValue),
              ),
              title: Text(choice.label),
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
