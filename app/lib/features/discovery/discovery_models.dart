import '../taste/taste_models.dart';

class PublicUser {
  const PublicUser({
    required this.id,
    this.name,
    this.age,
    this.city,
    this.bio,
    this.photoUrl,
  });

  final String id;
  final String? name;
  final int? age;
  final String? city;
  final String? bio;
  final String? photoUrl;

  String get displayName => name ?? 'Someone';

  factory PublicUser.fromJson(Map<String, dynamic> json) => PublicUser(
        id: json['id'] as String,
        name: json['name'] as String?,
        age: json['age'] as int?,
        city: json['city'] as String?,
        bio: json['bio'] as String?,
        photoUrl: json['photoUrl'] as String?,
      );
}

class Highlight {
  const Highlight({required this.domain, required this.label, this.heldBy});

  final TasteDomain domain;
  final String label;

  /// Divergences only: which user actually holds this item.
  final String? heldBy;

  factory Highlight.fromJson(Map<String, dynamic> json) => Highlight(
        domain: TasteDomain.fromId(json['domain'] as String? ?? 'music'),
        label: json['label'] as String,
        heldBy: json['heldBy'] as String?,
      );
}

/// Axis name -> 0..1, as computed server-side from real data (spec 4.1).
typedef TasteDna = Map<String, double>;

TasteDna _dnaFromJson(Map<String, dynamic>? json) {
  if (json == null) return const {};
  return {
    for (final entry in json.entries) entry.key: (entry.value as num).toDouble(),
  };
}

class CompatibilityCard {
  const CompatibilityCard({
    required this.user,
    required this.overallScore,
    required this.music,
    required this.movie,
    required this.book,
    required this.shared,
    required this.divergences,
    required this.tasteDna,
    required this.yourTasteDna,
  });

  final PublicUser user;
  final int overallScore;
  final int? music;
  final int? movie;
  final int? book;
  final List<Highlight> shared;
  final List<Highlight> divergences;
  final TasteDna tasteDna;
  final TasteDna yourTasteDna;

  int? scoreFor(TasteDomain domain) => switch (domain) {
        TasteDomain.music => music,
        TasteDomain.movie => movie,
        TasteDomain.book => book,
      };

  List<Highlight> sharedIn(TasteDomain domain) =>
      shared.where((h) => h.domain == domain).toList();

  factory CompatibilityCard.fromJson(Map<String, dynamic> json) => CompatibilityCard(
        user: PublicUser.fromJson(json['user'] as Map<String, dynamic>),
        overallScore: json['overallScore'] as int? ?? 0,
        music: json['music'] as int?,
        movie: json['movie'] as int?,
        book: json['book'] as int?,
        shared: (json['sharedHighlights'] as List<dynamic>? ?? [])
            .map((e) => Highlight.fromJson(e as Map<String, dynamic>))
            .toList(),
        divergences: (json['divergenceHighlights'] as List<dynamic>? ?? [])
            .map((e) => Highlight.fromJson(e as Map<String, dynamic>))
            .toList(),
        tasteDna: _dnaFromJson(json['tasteDna'] as Map<String, dynamic>?),
        yourTasteDna: _dnaFromJson(json['yourTasteDna'] as Map<String, dynamic>?),
      );
}

class MatchSummary {
  const MatchSummary({
    required this.matchId,
    required this.user,
    required this.overallScore,
    this.lastMessage,
    this.lastMessageAt,
    this.unread = false,
  });

  final String matchId;
  final PublicUser user;
  final int overallScore;
  final String? lastMessage;
  final String? lastMessageAt;
  final bool unread;

  factory MatchSummary.fromJson(Map<String, dynamic> json) => MatchSummary(
        matchId: json['matchId'] as String,
        user: PublicUser.fromJson(json['user'] as Map<String, dynamic>),
        overallScore: json['overallScore'] as int? ?? 0,
        lastMessage: json['lastMessage'] as String?,
        lastMessageAt: json['lastMessageAt'] as String?,
        unread: json['unread'] as bool? ?? false,
      );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.content,
    required this.sentAt,
    required this.mine,
  });

  final String id;
  final String content;
  final String sentAt;
  final bool mine;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        content: json['content'] as String,
        sentAt: json['sentAt'] as String,
        mine: json['mine'] as bool? ?? false,
      );
}
