import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const PathfinderApp());
}

class PathfinderApp extends StatelessWidget {
  const PathfinderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pathfinder Maze Studio',
      theme: ThemeData.dark(useMaterial3: true),
      home: const PathfinderScreen(),
    );
  }
}

enum CellType { empty, wall, start, target, visited, path }

class PathfinderScreen extends StatefulWidget {
  const PathfinderScreen({super.key});

  @override
  State<PathfinderScreen> createState() => _PathfinderScreenState();
}

class _PathfinderScreenState extends State<PathfinderScreen> {
  static const int rows = 20;
  static const int cols = 15;

  late List<List<CellType>> _grid;
  Point<int> _start = const Point(2, 2);
  Point<int> _target = const Point(17, 12);

  bool _isRunning = false;
  bool _useAStar = true;
  int _visitedCount = 0;
  int _pathLength = 0;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initGrid(generateWalls: true);
  }

  void _initGrid({bool generateWalls = false}) {
    _grid = List.generate(
      rows,
      (r) => List.generate(cols, (c) {
        if (r == _start.x && c == _start.y) return CellType.start;
        if (r == _target.x && c == _target.y) return CellType.target;
        if (generateWalls && _random.nextDouble() < 0.26) {
          return CellType.wall;
        }
        return CellType.empty;
      }),
    );
    _visitedCount = 0;
    _pathLength = 0;
  }

  void _clearSearchOnly() {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (_grid[r][c] == CellType.visited || _grid[r][c] == CellType.path) {
          _grid[r][c] = CellType.empty;
        }
      }
    }
    _grid[_start.x][_start.y] = CellType.start;
    _grid[_target.x][_target.y] = CellType.target;
    _visitedCount = 0;
    _pathLength = 0;
  }

  void _toggleWall(int r, int c) {
    if (_isRunning) return;
    if ((r == _start.x && c == _start.y) ||
        (r == _target.x && c == _target.y)) {
      return;
    }
    setState(() {
      _clearSearchOnly();
      _grid[r][c] = _grid[r][c] == CellType.wall
          ? CellType.empty
          : CellType.wall;
    });
  }

  Future<void> _runPathfinder() async {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      _clearSearchOnly();
    });

    final parent = <Point<int>, Point<int>?>{};
    final gScore = <Point<int>, int>{_start: 0};
    final openList = <Point<int>>[_start];
    final closedSet = <Point<int>>{};
    parent[_start] = null;

    int heuristic(Point<int> p) {
      if (!_useAStar) return 0;
      return (p.x - _target.x).abs() + (p.y - _target.y).abs();
    }

    bool found = false;

    while (openList.isNotEmpty && _isRunning) {
      openList.sort((a, b) {
        final fa = (gScore[a] ?? 999999) + heuristic(a);
        final fb = (gScore[b] ?? 999999) + heuristic(b);
        return fa.compareTo(fb);
      });

      final current = openList.removeAt(0);
      if (closedSet.contains(current)) continue;
      closedSet.add(current);

      if (current == _target) {
        found = true;
        break;
      }

      if (current != _start) {
        setState(() {
          _grid[current.x][current.y] = CellType.visited;
          _visitedCount++;
        });
        await Future.delayed(const Duration(milliseconds: 14));
      }

      const dirs = [Point(-1, 0), Point(1, 0), Point(0, -1), Point(0, 1)];

      for (final d in dirs) {
        final nr = current.x + d.x;
        final nc = current.y + d.y;
        if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
        if (_grid[nr][nc] == CellType.wall) continue;

        final neighbor = Point(nr, nc);
        if (closedSet.contains(neighbor)) continue;

        final tentativeG = (gScore[current] ?? 0) + 1;
        if (tentativeG < (gScore[neighbor] ?? 999999)) {
          parent[neighbor] = current;
          gScore[neighbor] = tentativeG;
          if (!openList.contains(neighbor)) {
            openList.add(neighbor);
          }
        }
      }
    }

    if (found && _isRunning) {
      final path = Queue<Point<int>>();
      Point<int>? curr = parent[_target];
      while (curr != null && curr != _start) {
        path.addFirst(curr);
        curr = parent[curr];
      }

      for (final step in path) {
        if (!mounted || !_isRunning) break;
        setState(() {
          _grid[step.x][step.y] = CellType.path;
          _pathLength++;
        });
        await Future.delayed(const Duration(milliseconds: 28));
      }
    } else if (!found && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No path possible! Clear some walls and retry.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    if (mounted) {
      setState(() => _isRunning = false);
    }
  }

  Color _cellColor(CellType type) {
    switch (type) {
      case CellType.start:
        return Colors.greenAccent;
      case CellType.target:
        return Colors.pinkAccent;
      case CellType.wall:
        return const Color(0xFF2B354D);
      case CellType.visited:
        return Colors.cyanAccent.withValues(alpha: 0.28);
      case CellType.path:
        return Colors.amberAccent;
      case CellType.empty:
        return const Color(0xFF111624);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070A12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Pathfinder Maze Studio',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _isRunning
                ? null
                : () => setState(() => _initGrid(generateWalls: true)),
            icon: const Icon(Icons.casino_outlined),
            tooltip: 'Random Maze',
          ),
          IconButton(
            onPressed: _isRunning
                ? null
                : () => setState(() => _initGrid(generateWalls: false)),
            icon: const Icon(Icons.layers_clear),
            tooltip: 'Clear All Walls',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('A* Heuristic'),
                      selected: _useAStar,
                      onSelected: _isRunning
                          ? null
                          : (_) => setState(() => _useAStar = true),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('BFS Wave'),
                      selected: !_useAStar,
                      onSelected: _isRunning
                          ? null
                          : (_) => setState(() => _useAStar = false),
                    ),
                  ],
                ),
                Text(
                  'Visited: $_visitedCount • Path: $_pathLength',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.amberAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C101C),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: List.generate(rows, (r) {
                    return Expanded(
                      child: Row(
                        children: List.generate(cols, (c) {
                          final type = _grid[r][c];
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => _toggleWall(r, c),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                margin: const EdgeInsets.all(1.2),
                                decoration: BoxDecoration(
                                  color: _cellColor(type),
                                  borderRadius: BorderRadius.circular(3.5),
                                ),
                                child: type == CellType.start
                                    ? const Center(
                                        child: Icon(
                                          Icons.play_arrow,
                                          size: 12,
                                          color: Colors.black,
                                        ),
                                      )
                                    : (type == CellType.target
                                          ? const Center(
                                              child: Icon(
                                                Icons.flag,
                                                size: 11,
                                                color: Colors.black,
                                              ),
                                            )
                                          : null),
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isRunning ? null : _runPathfinder,
                icon: const Icon(Icons.route),
                label: Text(
                  _isRunning ? 'Scanning Maze...' : 'Find Shortest Path',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.amberAccent.shade700,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
