import 'package:graphs/graphs.dart';

void main() {
  final graph = {
    'app': {'db'},
    'db': <String>{},
  };

  final sorted = topologicalSort(graph.keys, (node) => graph[node]!);
  print('Type: ${sorted.runtimeType}');
  print('Result: $sorted');
}
