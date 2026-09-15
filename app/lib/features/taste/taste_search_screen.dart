import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme.dart';
import '../../widgets/page_shell.dart';
import 'taste_controller.dart';
import 'taste_models.dart';

/// Search-and-add for one taste domain. Shows what's already on the list up
/// top so adding feels cumulative rather than like a blind search box.
class TasteSearchScreen extends ConsumerStatefulWidget {
  const TasteSearchScreen({super.key, required this.domain});

  final TasteDomain domain;

  @override
  ConsumerState<TasteSearchScreen> createState() => _TasteSearchScreenState();
}

class _TasteSearchScreenState extends ConsumerState<TasteSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<TasteItem> _results = const [];
  bool _searching = false;
  String? _error;

  /// Keys currently being added, so a tapped row can show a spinner without
  /// blocking the rest of the list.
  final _pending = <String>{};

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _results = const [];
        _searching = false;
        _error = null;
      });
      return;
    }
    // Debounce so we don't hammer the upstream API on every keystroke.
    _debounce = Timer(const Duration(milliseconds: 350), () => _runSearch(value.trim()));
  }

  Future<void> _runSearch(String query) async {
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results =
          await ref.read(tasteRepositoryProvider).search(widget.domain, query);
      if (!mounted || _controller.text.trim() != query) return;
      setState(() => _results = results);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _add(TasteItem item) async {
    setState(() => _pending.add(item.key));
    try {
      await ref.read(tasteControllerProvider.notifier).add(widget.domain, item);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _pending.remove(item.key));
    }
  }

  Future<void> _remove(String key) async {
    try {
      await ref.read(tasteControllerProvider.notifier).remove(widget.domain, key);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final domain = widget.domain;
    final text = Theme.of(context).textTheme;
    final taste = ref.watch(tasteControllerProvider).value?[domain];
    final chosenKeys = {for (final i in taste?.items ?? <TasteItem>[]) i.key};

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(domain.label, style: text.titleMedium),
      ),
      body: SafeArea(
        child: PageShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (taste != null && !taste.available)
                _UnavailableNotice(reason: taste.unavailableReason)
              else ...[
                TextField(
                  controller: _controller,
                  autofocus: true,
                  onChanged: _onQueryChanged,
                  decoration: InputDecoration(
                    hintText: 'Search ${domain.noun}…',
                    prefixIcon: const Icon(Icons.search_rounded, color: WaveColors.muted, size: 20),
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: WaveColors.muted),
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (taste != null && taste.items.isNotEmpty) ...[
                _ChosenList(
                  domain: domain,
                  items: taste.items,
                  onRemove: _remove,
                ),
                const SizedBox(height: 6),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!,
                      style: text.bodySmall?.copyWith(color: WaveColors.danger)),
                ),
              Expanded(
                child: _results.isEmpty
                    ? _EmptyState(domain: domain, hasQuery: _controller.text.trim().length >= 2,
                        searching: _searching, available: taste?.available ?? true)
                    : ListView.separated(
                        padding: const EdgeInsets.only(top: 4, bottom: 28),
                        itemCount: _results.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final item = _results[index];
                          return _ResultRow(
                            item: item,
                            domain: domain,
                            added: chosenKeys.contains(item.key),
                            busy: _pending.contains(item.key),
                            onAdd: () => _add(item),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChosenList extends StatelessWidget {
  const _ChosenList({required this.domain, required this.items, required this.onRemove});

  final TasteDomain domain;
  final List<TasteItem> items;
  final Future<void> Function(String key) onRemove;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final item in items)
          Chip(
            label: Text(item.label, style: const TextStyle(fontSize: 13)),
            backgroundColor: domain.color.withValues(alpha: 0.13),
            side: BorderSide(color: domain.color.withValues(alpha: 0.35)),
            deleteIcon: const Icon(Icons.close_rounded, size: 15),
            onDeleted: () => onRemove(item.key),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.item,
    required this.domain,
    required this.added,
    required this.busy,
    required this.onAdd,
  });

  final TasteItem item;
  final TasteDomain domain;
  final bool added;
  final bool busy;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Material(
      color: WaveColors.surface,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: added || busy ? null : onAdd,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          child: Row(
            children: [
              _Thumb(item: item, domain: domain),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                    if (item.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(item.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(color: WaveColors.muted)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (busy)
                const SizedBox(
                  height: 17,
                  width: 17,
                  child: CircularProgressIndicator(strokeWidth: 2, color: WaveColors.muted),
                )
              else
                Icon(
                  added ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                  size: 21,
                  color: added ? domain.color : WaveColors.muted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.item, required this.domain});

  final TasteItem item;
  final TasteDomain domain;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      height: 42,
      width: 42,
      decoration: BoxDecoration(
        color: domain.color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(domain.icon, size: 18, color: domain.color),
    );

    if (item.imageUrl == null) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: Image.network(
        item.imageUrl!,
        height: 42,
        width: 42,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

class _UnavailableNotice extends StatelessWidget {
  const _UnavailableNotice({this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: WaveColors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: WaveColors.movie.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.key_off_rounded, color: WaveColors.movie, size: 20),
          const SizedBox(height: 11),
          Text('Not connected yet', style: text.titleSmall),
          const SizedBox(height: 6),
          Text(
            reason ?? 'This source needs to be configured on the server.',
            style: text.bodySmall?.copyWith(color: WaveColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.domain,
    required this.hasQuery,
    required this.searching,
    required this.available,
  });

  final TasteDomain domain;
  final bool hasQuery;
  final bool searching;
  final bool available;

  @override
  Widget build(BuildContext context) {
    if (!available) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;

    final String message;
    if (searching) {
      message = 'Searching…';
    } else if (hasQuery) {
      message = 'Nothing matched that.';
    } else {
      message = switch (domain) {
        TasteDomain.music => 'Search for a band or artist you love.',
        TasteDomain.movie => 'Search for a film you\'d rewatch tomorrow.',
        TasteDomain.book => 'Search for a book you press on people.',
      };
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 60),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: WaveColors.muted),
        ),
      ),
    );
  }
}
