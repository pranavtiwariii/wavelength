import '../discovery/discovery_models.dart';
import '../taste/taste_models.dart';

/// A connection request waiting on you (proposal 4.1).
class ConnectionRequest {
  const ConnectionRequest({
    required this.id,
    required this.user,
    required this.overallScore,
    this.message,
  });

  final String id;
  final PublicUser user;
  final int overallScore;
  final String? message;

  factory ConnectionRequest.fromJson(Map<String, dynamic> json) => ConnectionRequest(
        id: json['id'] as String,
        user: PublicUser.fromJson(json['user'] as Map<String, dynamic>),
        overallScore: json['overallScore'] as int? ?? 0,
        message: json['message'] as String?,
      );
}

/// A Content Drop: something someone shared, tagged by domain.
class Drop {
  const Drop({
    required this.id,
    required this.domain,
    required this.itemKey,
    required this.itemLabel,
    required this.authorId,
    required this.authorName,
    required this.likeCount,
    required this.saveCount,
    required this.likedByMe,
    required this.savedByMe,
    required this.sharedWithMe,
    this.itemSubtitle,
    this.itemImage,
    this.caption,
    this.authorPhotoUrl,
    this.communityName,
    this.communitySlug,
  });

  final String id;
  final TasteDomain domain;
  final String itemKey;
  final String itemLabel;
  final String? itemSubtitle;
  final String? itemImage;
  final String? caption;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String? communityName;
  final String? communitySlug;
  final int likeCount;
  final int saveCount;
  final bool likedByMe;
  final bool savedByMe;

  /// True when this exact item is in your taste profile too.
  final bool sharedWithMe;

  Drop copyWith({int? likeCount, int? saveCount, bool? likedByMe, bool? savedByMe}) => Drop(
        id: id,
        domain: domain,
        itemKey: itemKey,
        itemLabel: itemLabel,
        itemSubtitle: itemSubtitle,
        itemImage: itemImage,
        caption: caption,
        authorId: authorId,
        authorName: authorName,
        authorPhotoUrl: authorPhotoUrl,
        communityName: communityName,
        communitySlug: communitySlug,
        likeCount: likeCount ?? this.likeCount,
        saveCount: saveCount ?? this.saveCount,
        likedByMe: likedByMe ?? this.likedByMe,
        savedByMe: savedByMe ?? this.savedByMe,
        sharedWithMe: sharedWithMe,
      );

  factory Drop.fromJson(Map<String, dynamic> json) {
    final community = json['community'] as Map<String, dynamic>?;
    final author = json['author'] as Map<String, dynamic>? ?? const {};
    return Drop(
      id: json['id'] as String,
      domain: TasteDomain.fromId(json['domain'] as String? ?? 'music'),
      itemKey: json['itemKey'] as String,
      itemLabel: json['itemLabel'] as String,
      itemSubtitle: json['itemSubtitle'] as String?,
      itemImage: json['itemImage'] as String?,
      caption: json['caption'] as String?,
      authorId: author['id'] as String? ?? '',
      authorName: author['name'] as String? ?? 'Someone',
      authorPhotoUrl: author['photoUrl'] as String?,
      communityName: community?['name'] as String?,
      communitySlug: community?['slug'] as String?,
      likeCount: json['likeCount'] as int? ?? 0,
      saveCount: json['saveCount'] as int? ?? 0,
      likedByMe: json['likedByMe'] as bool? ?? false,
      savedByMe: json['savedByMe'] as bool? ?? false,
      sharedWithMe: json['sharedWithMe'] as bool? ?? false,
    );
  }
}

/// A tag-based community.
class Community {
  const Community({
    required this.id,
    required this.slug,
    required this.name,
    required this.tags,
    required this.memberCount,
    required this.joined,
    this.description,
    this.domain,
    this.matchedTags = const [],
  });

  final String id;
  final String slug;
  final String name;
  final String? description;
  final String? domain;
  final List<String> tags;
  final int memberCount;
  final bool joined;

  /// Which of your own taste tags pulled this community into your suggestions.
  final List<String> matchedTags;

  TasteDomain? get tasteDomain =>
      domain == null ? null : TasteDomain.fromId(domain!);

  factory Community.fromJson(Map<String, dynamic> json) => Community(
        id: json['id'] as String,
        slug: json['slug'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        domain: json['domain'] as String?,
        tags: (json['tags'] as List<dynamic>? ?? []).cast<String>(),
        memberCount: json['memberCount'] as int? ?? 0,
        joined: json['joined'] as bool? ?? false,
        matchedTags: (json['matchedTags'] as List<dynamic>? ?? []).cast<String>(),
      );
}

class CommunityDetail {
  const CommunityDetail({
    required this.community,
    required this.members,
    required this.drops,
  });

  final Community community;
  final List<PublicUser> members;
  final List<Drop> drops;

  factory CommunityDetail.fromJson(Map<String, dynamic> json) => CommunityDetail(
        community: Community.fromJson(json['community'] as Map<String, dynamic>),
        members: (json['members'] as List<dynamic>? ?? [])
            .map((e) => PublicUser.fromJson(e as Map<String, dynamic>))
            .toList(),
        drops: (json['drops'] as List<dynamic>? ?? [])
            .map((e) => Drop.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
