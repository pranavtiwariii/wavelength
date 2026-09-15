import 'package:flutter/material.dart';

import '../../core/theme.dart';

enum TasteDomain {
  music('music', 'Music', 'artists', Icons.graphic_eq, MateColors.music),
  movie('movie', 'Movies', 'films', Icons.movie_outlined, MateColors.movie),
  book('book', 'Books', 'books', Icons.menu_book_outlined, MateColors.book);

  const TasteDomain(this.id, this.label, this.noun, this.icon, this.color);

  final String id;
  final String label;

  /// Used in copy: "Add 5 artists", "3 films added".
  final String noun;
  final IconData icon;
  final Color color;

  static TasteDomain fromId(String id) =>
      TasteDomain.values.firstWhere((d) => d.id == id, orElse: () => TasteDomain.music);
}

class TasteItem {
  const TasteItem({
    required this.key,
    required this.label,
    this.subtitle,
    this.imageUrl,
  });

  final String key;
  final String label;
  final String? subtitle;
  final String? imageUrl;

  factory TasteItem.fromJson(Map<String, dynamic> json) => TasteItem(
        key: json['key'] as String,
        label: json['label'] as String,
        subtitle: json['subtitle'] as String?,
        imageUrl: json['imageUrl'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        if (subtitle != null) 'subtitle': subtitle,
        if (imageUrl != null) 'imageUrl': imageUrl,
      };
}

class DomainTaste {
  const DomainTaste({
    required this.items,
    required this.available,
    required this.providerName,
    required this.target,
    this.unavailableReason,
  });

  final List<TasteItem> items;

  /// False when the server has no provider configured for this domain - the UI
  /// says so rather than opening a search that can only fail.
  final bool available;
  final String providerName;
  final int target;
  final String? unavailableReason;

  bool get isComplete => items.length >= target;
  double get progress => (items.length / target).clamp(0.0, 1.0);

  factory DomainTaste.fromJson(Map<String, dynamic> json) => DomainTaste(
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => TasteItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        available: json['available'] as bool? ?? false,
        providerName: json['providerName'] as String? ?? '',
        target: json['target'] as int? ?? 5,
        unavailableReason: json['unavailableReason'] as String?,
      );
}

class TasteProfile {
  const TasteProfile({required this.completeness, required this.domains});

  final int completeness;
  final Map<TasteDomain, DomainTaste> domains;

  DomainTaste operator [](TasteDomain domain) =>
      domains[domain] ??
      const DomainTaste(items: [], available: false, providerName: '', target: 5);

  factory TasteProfile.fromJson(Map<String, dynamic> json) {
    final raw = json['domains'] as Map<String, dynamic>? ?? {};
    return TasteProfile(
      completeness: json['completeness'] as int? ?? 0,
      domains: {
        for (final domain in TasteDomain.values)
          if (raw[domain.id] != null)
            domain: DomainTaste.fromJson(raw[domain.id] as Map<String, dynamic>),
      },
    );
  }
}
