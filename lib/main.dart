import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jank Tracking Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const CompareListDemoPage(),
    );
  }
}

enum DemoMode { notOptimized, optimized }

class CompareListDemoPage extends StatefulWidget {
  const CompareListDemoPage({super.key});

  @override
  State<CompareListDemoPage> createState() => _CompareListDemoPageState();
}

class _CompareListDemoPageState extends State<CompareListDemoPage> {
  final List<int> _items = List<int>.generate(1500, (i) => i);
  final FrameStatsTracker _tracker = FrameStatsTracker(targetFps: 60);
  final ScrollController _notOptimizedController = ScrollController();
  final ScrollController _optimizedController = ScrollController();

  DemoMode _mode = DemoMode.notOptimized;
  double _workMultiplier = 3.5;
  double _notOptimizedScrollOffset = 0;
  int _lastScrollCost = 0;
  bool _useCompute = true;
  bool _isComputing = false;
  List<int>? _scoresFromCompute;

  @override
  void initState() {
    super.initState();
    _tracker.start();

    _notOptimizedController.addListener(() {
      // NOT OPTIMIZED baseline: calling setState every scroll tick rebuilds the screen repeatedly.
      setState(() {
        _notOptimizedScrollOffset = _notOptimizedController.offset;
        _lastScrollCost = _expensiveScrollWork();
      });
    });

    // OPTIMIZED from baseline: avoid setState in scroll listener.
    _optimizedController.addListener(() {
      // Intentionally no setState here.
      _optimizedController.offset;
    });

    // OPTIMIZED from baseline: precompute scores off the UI thread via compute().
    _prepareScoresWithCompute();
  }

  @override
  void dispose() {
    _notOptimizedController.dispose();
    _optimizedController.dispose();
    _tracker.dispose();
    super.dispose();
  }

  int _expensiveCpuWork(int index) {
    return _calculateExpensiveScore(index, _workMultiplier);
  }

  int _expensiveScrollWork() {
    final int loops = (14000 * _workMultiplier).round();
    double value = 1;
    for (int i = 0; i < loops; i++) {
      value = math.sqrt(value + i) + math.cos(i * 0.002);
    }
    return (value * 100).round().abs();
  }

  Future<void> _prepareScoresWithCompute() async {
    if (_isComputing) return;
    setState(() => _isComputing = true);
    final List<int> values = await compute<ScoreJobInput, List<int>>(
      _generateScoresInBackground,
      ScoreJobInput(items: _items, workMultiplier: _workMultiplier),
    );
    if (!mounted) return;
    setState(() {
      _scoresFromCompute = _useCompute ? values : null;
      _isComputing = false;
    });
  }

  Future<void> _toggleCompute(bool enabled) async {
    setState(() {
      _useCompute = enabled;
      if (!enabled) {
        // Turning off compute simulates non-precomputed behavior for both lists.
        _scoresFromCompute = null;
      }
    });

    if (enabled && _scoresFromCompute == null) {
      await _prepareScoresWithCompute();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool optimized = _mode == DemoMode.optimized;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Not Optimized vs Optimized List'),
        actions: [
          IconButton(
            tooltip: 'Reset frame stats',
            onPressed: _tracker.reset,
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: Column(
        children: [
          ListenableBuilder(
            listenable: _tracker,
            builder: (context, _) {
              final int missed = _tracker.missedFrames;
              final int total = _tracker.totalFrames;
              final double pct = total == 0 ? 0 : (missed / total) * 100;
              return Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Tracked frames: $total | Missed 60fps budget: $missed (${pct.toStringAsFixed(1)}%) | '
                  'Avg build+raster: ${_tracker.averageFrameMs.toStringAsFixed(1)}ms',
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SegmentedButton<DemoMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: DemoMode.notOptimized,
                      label: Text('Not Optimized'),
                    ),
                    ButtonSegment(
                      value: DemoMode.optimized,
                      label: Text('Optimized'),
                    ),
                  ],
                  selected: <DemoMode>{_mode},
                  onSelectionChanged: (selection) {
                    final DemoMode newMode = selection.first;
                    if (newMode == _mode) return;
                    setState(() => _mode = newMode);
                    _tracker.reset();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Jank intensity for baseline list'),
                  subtitle: Slider(
                    min: 0.8,
                    max: 8,
                    divisions: 36,
                    value: _workMultiplier,
                    label: _workMultiplier.toStringAsFixed(1),
                    onChanged: (value) => setState(() => _workMultiplier = value),
                    onChangeEnd: (_) {
                      if (_useCompute) {
                        _prepareScoresWithCompute();
                      }
                    },
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Use compute() precomputed data (both lists)'),
                  subtitle: Text(
                    _isComputing
                        ? 'Precomputing in background isolate...'
                        : _useCompute
                        ? 'Enabled: rows consume cached scores from compute().'
                        : 'Disabled: rows compute score during build.',
                  ),
                  value: _useCompute,
                  onChanged: _toggleCompute,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(
              optimized
                  ? 'Optimized list is derived from the baseline by: no scroll setState, resized image decode, '
                        'and precomputed score via compute().'
                  : 'Baseline list intentionally janks: setState on scroll tick, oversized image decode, '
                        'sync CPU work in itemBuilder.',
            ),
          ),
          if (!optimized)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Text(
                'Current scroll offset (rebuilt every tick): '
                '${_notOptimizedScrollOffset.toStringAsFixed(1)}',
              ),
            ),
          if (!optimized)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Scroll-tick CPU cost (jank signal): $_lastScrollCost'),
            ),
          const Divider(height: 1),
          Expanded(
            child: _buildList(optimized: optimized),
          ),
        ],
      ),
    );
  }

  Widget _buildList({required bool optimized}) {
    return ListView.builder(
      key: ValueKey<String>(optimized ? 'optimized-list' : 'not-optimized-list'),
      controller: optimized ? _optimizedController : _notOptimizedController,
      itemCount: _items.length,
      // OPTIMIZED from baseline: this avoids expensive full-height measuring of long lists.
      shrinkWrap: !optimized,
      // OPTIMIZED from baseline: provide fixed extent hints for the viewport.
      itemExtent: optimized ? 210 : null,
      // OPTIMIZED from baseline: prebuild nearby items with explicit cache extent policy.
      scrollCacheExtent: optimized ? const ScrollCacheExtent.pixels(800) : null,
      // NOT OPTIMIZED baseline: disabling repaint boundaries increases repaint cost while scrolling.
      addRepaintBoundaries: optimized,
      itemBuilder: (context, index) {
        final bool usePrecomputed = _useCompute && _scoresFromCompute != null;
        final bool waitingForCompute = _useCompute && _scoresFromCompute == null && _isComputing;

        if (optimized && waitingForCompute) {
          // Keep optimized mode non-blocking while isolate computes data.
          return _buildCard(
            optimized: true,
            index: index,
            scoreLabel: 'Preparing compute() result...',
          );
        }

        final int score = usePrecomputed
            // OPTIMIZED from baseline: consume scores precomputed via compute().
            ? _scoresFromCompute![index]
            // NOT OPTIMIZED baseline: execute expensive CPU work in itemBuilder.
            : optimized
            ? _expensiveCpuWork(index)
            : (_expensiveCpuWork(index) + _expensiveCpuWork(index + 17));

        final Widget card = _buildCard(
          optimized: optimized,
          index: index,
          scoreLabel: usePrecomputed ? 'Precomputed score: $score' : 'Expensive score: $score',
        );

        return optimized
            // OPTIMIZED from baseline: isolate list item repaints.
            ? RepaintBoundary(child: card)
            : card;
      },
    );
  }

  Widget _buildCard({
    required bool optimized,
    required int index,
    required String scoreLabel,
  }) {
    final String imageUrl = optimized
        ? 'https://picsum.photos/id/${index % 1000}/1280/720'
        : 'https://picsum.photos/id/${index % 1000}/4000/3000';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: optimized ? Colors.green.shade50 : Colors.deepPurple.shade50,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              blurRadius: 18,
              spreadRadius: 2,
              color: Color(0x22000000),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(
              imageUrl,
              width: double.infinity,
              height: 120,
              fit: BoxFit.cover,
              // OPTIMIZED from baseline: decode image near display size.
              cacheWidth: optimized ? MediaQuery.sizeOf(context).width.round() : null,
              cacheHeight: optimized ? 120 : null,
              filterQuality: optimized ? FilterQuality.low : FilterQuality.high,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 120,
                  color: Colors.grey.shade300,
                  alignment: Alignment.center,
                  child: const Text('Image failed to load'),
                );
              },
            ),
            ListTile(
              dense: optimized,
              title: Text('Item #$index'),
              subtitle: Text(scoreLabel),
              trailing: Icon(
                optimized ? Icons.check_circle_outline : Icons.warning_amber_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

@immutable
class ScoreJobInput {
  const ScoreJobInput({required this.items, required this.workMultiplier});

  final List<int> items;
  final double workMultiplier;
}

int _calculateExpensiveScore(int index, double workMultiplier) {
  final int loops = (8500 * workMultiplier).round() + (index % 7) * 1600;
  double value = index + 1;
  for (int i = 0; i < loops; i++) {
    value = math.sqrt(value * 1.001 + i) + math.sin(i * 0.001);
  }
  return (value * 1000).round().abs();
}

List<int> _generateScoresInBackground(ScoreJobInput input) {
  return input.items
      .map((int index) => _calculateExpensiveScore(index, input.workMultiplier))
      .toList(growable: false);
}

class FrameStatsTracker extends ChangeNotifier {
  FrameStatsTracker({required this.targetFps})
    : _budgetMicros = (1000000 / targetFps).round();

  final int targetFps;
  final int _budgetMicros;
  final List<int> _recentFrameMicros = <int>[];

  int totalFrames = 0;
  int missedFrames = 0;

  void start() {
    WidgetsBinding.instance.addTimingsCallback(_onFrameTimings);
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    for (final FrameTiming timing in timings) {
      totalFrames++;
      final int costMicros =
          timing.buildDuration.inMicroseconds + timing.rasterDuration.inMicroseconds;
      _recentFrameMicros.add(costMicros);
      if (_recentFrameMicros.length > 180) {
        _recentFrameMicros.removeAt(0);
      }
      if (costMicros > _budgetMicros) {
        missedFrames++;
      }
    }
    notifyListeners();
  }

  double get averageFrameMs {
    if (_recentFrameMicros.isEmpty) return 0;
    final int sum = _recentFrameMicros.fold<int>(0, (acc, v) => acc + v);
    return (sum / _recentFrameMicros.length) / 1000;
  }

  void reset() {
    totalFrames = 0;
    missedFrames = 0;
    _recentFrameMicros.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeTimingsCallback(_onFrameTimings);
    super.dispose();
  }
}

