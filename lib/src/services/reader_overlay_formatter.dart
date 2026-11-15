/// Template substitutions are display-only; never mutate the source anchor.
/// Unknown variables remain visible rather than silently vanishing.
class ReaderOverlayFormatter {
  const ReaderOverlayFormatter._();

  static String render(
    String template, {
    required String book,
    required String chapter,
    required int page,
    required int pages,
    required int absoluteOffset,
    required int totalChars,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final progress = totalChars <= 0
        ? '0.0'
        : ((absoluteOffset * 100 / totalChars).clamp(0, 100)).toStringAsFixed(1);
    final map = <String, String>{
      '{book}': book,
      '{chapter}': chapter,
      '{page}': page.toString(),
      '{pages}': pages.toString(),
      '{progress}': progress,
      '{time}': two(clock.hour) + ':' + two(clock.minute),
    };
    var result = template;
    for (final entry in map.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }
}
