import 'package:flutter_test/flutter_test.dart';
import 'package:sorted_out/src/features/tasks/domain/list_reorder.dart';

void main() {
  group('reorderInsertionIndex', () {
    test('adjusts downward when moving within the same list', () {
      expect(
        reorderInsertionIndex(
          targetIndex: 3,
          destinationLength: 4,
          sourceIndexInSameList: 1,
        ),
        2,
      );
    });

    test('clamps to the destination bounds', () {
      expect(
        reorderInsertionIndex(
          targetIndex: 99,
          destinationLength: 2,
        ),
        2,
      );
    });
  });

  group('moveItemWithinList', () {
    test('moves an item to a later position', () {
      final List<String> items = <String>['a', 'b', 'c', 'd'];

      final bool didMove = moveItemWithinList(
        items,
        sourceIndex: 1,
        targetIndex: 4,
      );

      expect(didMove, isTrue);
      expect(items, <String>['a', 'c', 'd', 'b']);
    });

    test('moves an item to an earlier position', () {
      final List<String> items = <String>['a', 'b', 'c', 'd'];

      final bool didMove = moveItemWithinList(
        items,
        sourceIndex: 3,
        targetIndex: 1,
      );

      expect(didMove, isTrue);
      expect(items, <String>['a', 'd', 'b', 'c']);
    });
  });

  group('moveItemToBoundary', () {
    test('moves an item to the top', () {
      final List<String> items = <String>['a', 'b', 'c'];

      final bool didMove = moveItemToBoundary(
        items,
        sourceIndex: 2,
        toTop: true,
      );

      expect(didMove, isTrue);
      expect(items, <String>['c', 'a', 'b']);
    });

    test('moves an item to the bottom', () {
      final List<String> items = <String>['a', 'b', 'c'];

      final bool didMove = moveItemToBoundary(
        items,
        sourceIndex: 0,
        toTop: false,
      );

      expect(didMove, isTrue);
      expect(items, <String>['b', 'c', 'a']);
    });
  });
}
