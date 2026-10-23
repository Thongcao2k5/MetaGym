enum FlowRole { member, coach }

class FlowAction {
  const FlowAction(
    this.title,
    this.method,
    this.path, {
    this.sampleBody,
    this.sampleQuery,
  });

  final String title;
  final String method;
  final String path;
  final String? sampleBody;
  final String? sampleQuery;

  Iterable<String> get pathParameters =>
      RegExp(r':([A-Za-z][A-Za-z0-9]*)')
          .allMatches(path)
          .map((match) => match.group(1)!);

  String resolvePath(Map<String, String> values) {
    var resolved = path;
    for (final name in pathParameters) {
      final value = values[name]?.trim() ?? '';
      if (value.isEmpty || value.contains('/')) {
        throw FormatException('Hãy nhập $name hợp lệ.');
      }
      resolved = resolved.replaceFirst(':$name', Uri.encodeComponent(value));
    }
    return resolved;
  }
}

class FlowGroup {
  const FlowGroup(this.title, this.actions);

  final String title;
  final List<FlowAction> actions;
}
