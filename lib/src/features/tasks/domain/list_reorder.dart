int reorderInsertionIndex({
  required int targetIndex,
  required int destinationLength,
  int? sourceIndexInSameList,
}) {
  int insertionIndex = targetIndex;
  if (sourceIndexInSameList != null && sourceIndexInSameList < insertionIndex) {
    insertionIndex -= 1;
  }
  return insertionIndex.clamp(0, destinationLength);
}

bool moveItemWithinList<T>(
  List<T> items, {
  required int sourceIndex,
  required int targetIndex,
}) {
  if (sourceIndex < 0 || sourceIndex >= items.length) {
    return false;
  }

  final T movedItem = items.removeAt(sourceIndex);
  final int insertionIndex = reorderInsertionIndex(
    targetIndex: targetIndex,
    destinationLength: items.length,
    sourceIndexInSameList: sourceIndex,
  );
  items.insert(insertionIndex, movedItem);
  return true;
}

bool moveItemToBoundary<T>(
  List<T> items, {
  required int sourceIndex,
  required bool toTop,
}) {
  if (sourceIndex < 0 || sourceIndex >= items.length) {
    return false;
  }

  final T movedItem = items.removeAt(sourceIndex);
  if (toTop) {
    items.insert(0, movedItem);
  } else {
    items.add(movedItem);
  }
  return true;
}
