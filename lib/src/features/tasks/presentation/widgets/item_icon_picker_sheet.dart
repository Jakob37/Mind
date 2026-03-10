import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ItemIconChoice {
  const ItemIconChoice({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final IconData icon;
}

const String kMindAppIconKey = 'brain';

const List<ItemIconChoice> kItemIconChoices = <ItemIconChoice>[
  ItemIconChoice(
    key: 'brain',
    label: 'Brain',
    icon: FontAwesomeIcons.brain,
  ),
  ItemIconChoice(
    key: 'lightbulb',
    label: 'Lightbulb',
    icon: FontAwesomeIcons.lightbulb,
  ),
  ItemIconChoice(
    key: 'list-check',
    label: 'Checklist',
    icon: FontAwesomeIcons.listCheck,
  ),
  ItemIconChoice(
    key: 'seedling',
    label: 'Seedling',
    icon: FontAwesomeIcons.seedling,
  ),
  ItemIconChoice(
    key: 'bolt',
    label: 'Bolt',
    icon: FontAwesomeIcons.bolt,
  ),
  ItemIconChoice(
    key: 'book-open',
    label: 'Book',
    icon: FontAwesomeIcons.bookOpen,
  ),
  ItemIconChoice(
    key: 'heart',
    label: 'Heart',
    icon: FontAwesomeIcons.heart,
  ),
  ItemIconChoice(
    key: 'sun',
    label: 'Sun',
    icon: FontAwesomeIcons.sun,
  ),
  ItemIconChoice(
    key: 'moon',
    label: 'Moon',
    icon: FontAwesomeIcons.moon,
  ),
  ItemIconChoice(
    key: 'star',
    label: 'Star',
    icon: FontAwesomeIcons.star,
  ),
  ItemIconChoice(
    key: 'folder-open',
    label: 'Folder',
    icon: FontAwesomeIcons.folderOpen,
  ),
  ItemIconChoice(
    key: 'rocket',
    label: 'Rocket',
    icon: FontAwesomeIcons.rocket,
  ),
];

IconData? iconDataForKey(String? key) {
  if (key == null || key.isEmpty) {
    return null;
  }

  for (final ItemIconChoice choice in kItemIconChoices) {
    if (choice.key == key) {
      return choice.icon;
    }
  }
  return null;
}

String? iconLabelForKey(String? key) {
  if (key == null || key.isEmpty) {
    return null;
  }

  for (final ItemIconChoice choice in kItemIconChoices) {
    if (choice.key == key) {
      return choice.label;
    }
  }
  return null;
}

class ItemIconPickerSheet extends StatelessWidget {
  const ItemIconPickerSheet({
    super.key,
    required this.currentIconKey,
  });

  final String? currentIconKey;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: <Widget>[
          const ListTile(
            title: Text(
              'Choose icon',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.block_outlined),
            title: const Text('No icon'),
            trailing: currentIconKey == null
                ? const Icon(Icons.check_outlined)
                : null,
            onTap: () => Navigator.of(context).pop<String?>(null),
          ),
          for (final ItemIconChoice choice in kItemIconChoices)
            ListTile(
              leading: FaIcon(choice.icon),
              title: Text(choice.label),
              trailing: currentIconKey == choice.key
                  ? const Icon(Icons.check_outlined)
                  : null,
              onTap: () => Navigator.of(context).pop<String?>(choice.key),
            ),
        ],
      ),
    );
  }
}
