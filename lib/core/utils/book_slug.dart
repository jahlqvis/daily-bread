String bookSlug(String name) {
  final lower = name.toLowerCase();
  final sanitized = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  final collapsed = sanitized.replaceAll(RegExp(r'_+'), '_');
  final trimmed = collapsed.replaceAll(RegExp(r'^_+|_+$'), '');
  return trimmed.isEmpty ? 'book' : trimmed;
}
