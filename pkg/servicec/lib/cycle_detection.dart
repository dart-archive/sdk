// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.cycle_detection;

import 'node.dart' show
    MemberNode,
    FieldNode,
    SimpleType,
    StructNode,
    TypeNode,
    UnionNode;

import 'errors.dart' show
    CompilerError;

class GraphNode {
  GraphNodeState state = GraphNodeState.UNVISITED;
  StructNode struct;

  GraphNode(this.struct);

  bool get isNotVisited => GraphNodeState.UNVISITED == state;

  bool operator ==(GraphNode other) {
    return struct == other.struct;
  }
  int get hashCode => struct.hashCode;

  String toString() => "Node[${struct.identifier.value}, ${state.toString()}]";
}

enum GraphNodeState {
  VISITED,
  VISITING,
  UNVISITED
}

class StructGraph {
  Set<GraphNode> nodes;
  Map<GraphNode, Set<GraphNode>> neighbours;

  StructGraph()
    : nodes = new Set<GraphNode>(),
      neighbours = new Map<GraphNode, Set<GraphNode>>();

  void add(StructNode struct) {
    for (MemberNode member in struct.members) {
      if (member is FieldNode) {
        addStructField(struct, member);
      } else {
        UnionNode union = member;
        union.fields.forEach((field) => addStructField(struct, field));
      }
    }
  }

  // Helper function.
  void addStructField(StructNode struct, FieldNode field) {
    TypeNode type = field.type;
    if (type != null && type.isStruct()) {
      SimpleType simpleType = type;
      addLink(struct, simpleType.resolved);
    }
  }

  void addLink(StructNode from, StructNode to) {
    GraphNode fromNode = addNodeIfNew(from);
    GraphNode toNode = addNodeIfNew(to);
    neighbours[fromNode].add(toNode);
  }

  GraphNode addNodeIfNew(StructNode node) {
    GraphNode result = nodes.firstWhere(
        (graphNode) => graphNode.struct == node,
        orElse: () => null);
    if (null == result) {
      result = new GraphNode(node);
      nodes.add(result);
      neighbours[result] = new Set<GraphNode>();
    }
    return result;
  }

  // 1) 0 -> 0 is a trivial cycle
  // 2) 0 -> 1 -> 0 is (probably) the most common cycle in real code
  // 3) 0 -> 1 -> 2 -> 1 is a cycle reachable from 0, but not containing 0
  // 4) 0 -> 1 -> 0 + 1 -> 2 -> 1 are two cycles reachable from 0
  // 5) 0 -> 1 -> 0 + 1 -> 2 -> 0 are two cycles reachable from 0
  List<CompilerError> findCycles() {
    List<CompilerError> errors = <CompilerError>[];
    List<GraphNode> stack = new List<GraphNode>();
    stack.addAll(nodes);
    while (stack.isNotEmpty) {
      GraphNode node = stack.last;
      switch (node.state) {
        case GraphNodeState.UNVISITED:
          node.state = GraphNodeState.VISITING;
          for (GraphNode neighbour in neighbours[node]) {
            switch (neighbour.state) {
              case GraphNodeState.UNVISITED:
                // The `neighbour` hasn't been seen yet - add to stack.
                stack.add(neighbour);
                break;
              case GraphNodeState.VISITING:
                // The `neighbour` is in the current route from the root to the
                // `node` - there is a cycle.
                errors.add(CompilerError.cyclicStruct);
                break;
              case GraphNodeState.VISITED:
                // The `neighbour` has already been searched - ignore.
                break;
            }
          }
          break;
        case GraphNodeState.VISITING:
          node.state = GraphNodeState.VISITED;
          stack.removeLast();
          break;
        case GraphNodeState.VISITED:
          // In this case the graph is a DAG.
          stack.removeLast();
          break;
      }
    }
    return errors;
  }
}
