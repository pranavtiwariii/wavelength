import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';

/// Discovery filters (spec 3.4). Held in memory for the session — they're a
/// browsing control, not a saved preference.
class DiscoveryFilters {
  const DiscoveryFilters({
    this.minScore = 0,
    this.ageRange = const RangeValues(18, 60),
  });

  final int minScore;
  final RangeValues ageRange;

  bool get isDefault => minScore == 0 && ageRange.start == 18 && ageRange.end == 60;

  Map<String, dynamic> toQuery() => {
        if (minScore > 0) 'minScore': minScore,
        'minAge': ageRange.start.round(),
        'maxAge': ageRange.end.round(),
      };

  DiscoveryFilters copyWith({int? minScore, RangeValues? ageRange}) => DiscoveryFilters(
        minScore: minScore ?? this.minScore,
        ageRange: ageRange ?? this.ageRange,
      );
}

final discoveryFiltersProvider =
    NotifierProvider<DiscoveryFiltersController, DiscoveryFilters>(
        DiscoveryFiltersController.new);

class DiscoveryFiltersController extends Notifier<DiscoveryFilters> {
  @override
  DiscoveryFilters build() => const DiscoveryFilters();

  void set(DiscoveryFilters next) => state = next;
  void reset() => state = const DiscoveryFilters();
}

/// The sheet behind the sliders icon on Discover.
class FiltersSheet extends ConsumerStatefulWidget {
  const FiltersSheet({super.key});

  @override
  ConsumerState<FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends ConsumerState<FiltersSheet> {
  late DiscoveryFilters _draft = ref.read(discoveryFiltersProvider);

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: palette.ink,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: palette.stroke),
      ),
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 26),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: palette.stroke,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Filters', style: text.titleLarge),
                TextButton(
                  onPressed: () => setState(() => _draft = const DiscoveryFilters()),
                  child: Text('Reset', style: TextStyle(color: palette.muted)),
                ),
              ],
            ),
            const SizedBox(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Minimum match', style: text.titleSmall),
                Text('${_draft.minScore}%',
                    style: text.titleSmall?.copyWith(color: palette.music)),
              ],
            ),
            Slider(
              value: _draft.minScore.toDouble(),
              max: 90,
              divisions: 18,
              activeColor: palette.music,
              inactiveColor: palette.surfaceHigh,
              label: '${_draft.minScore}%',
              onChanged: (v) => setState(() => _draft = _draft.copyWith(minScore: v.round())),
            ),
            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Age', style: text.titleSmall),
                Text(
                  '${_draft.ageRange.start.round()}–${_draft.ageRange.end.round()}',
                  style: text.titleSmall?.copyWith(color: palette.music),
                ),
              ],
            ),
            RangeSlider(
              values: _draft.ageRange,
              min: 18,
              max: 60,
              divisions: 42,
              activeColor: palette.music,
              inactiveColor: palette.surfaceHigh,
              labels: RangeLabels(
                '${_draft.ageRange.start.round()}',
                '${_draft.ageRange.end.round()}',
              ),
              onChanged: (v) => setState(() => _draft = _draft.copyWith(ageRange: v)),
            ),
            const SizedBox(height: 8),
            Text(
              'Who you see is also set by what you’re here for — change that in Settings.',
              style: text.bodySmall?.copyWith(color: palette.faint),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                ref.read(discoveryFiltersProvider.notifier).set(_draft);
                Navigator.of(context).pop(true);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}
