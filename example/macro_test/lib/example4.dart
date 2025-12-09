import 'package:macro_kit/macro_kit.dart';

part 'example4.g.dart';

// Github schema example

@dataClassMacro
class UserProfile with UserProfileData {
  @JsonKey(name: 'id')
  final String id;

  @JsonKey(name: 'username')
  final String username;

  @JsonKey(name: 'email')
  final String email;

  @JsonKey(name: 'age')
  final int age;

  @JsonKey(name: 'is_active')
  final bool isActive;

  @JsonKey(name: 'account_balance')
  final double accountBalance;

  @JsonKey(name: 'roles')
  final List<String> roles;

  @JsonKey(name: 'preferences')
  final Map<String, dynamic> preferences;

  @JsonKey(name: 'profile_image_url')
  final Uri? profileImageUrl;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @JsonKey(name: 'last_login')
  final DateTime? lastLogin;

  @JsonKey(name: 'address')
  final Address? address;

  @JsonKey(name: 'tags')
  final List<Tag> tags;

  UserProfile({
    required this.id,
    required this.username,
    required this.email,
    required this.age,
    required this.isActive,
    required this.accountBalance,
    required this.roles,
    required this.preferences,
    required this.profileImageUrl,
    required this.createdAt,
    required this.lastLogin,
    required this.address,
    required this.tags,
  });
}

@dataClassMacro
class Address with AddressData {
  @JsonKey(name: 'street')
  final String street;

  @JsonKey(name: 'city')
  final String city;

  @JsonKey(name: 'country')
  final String country;

  @JsonKey(name: 'postal_code')
  final String postalCode;

  Address({
    required this.street,
    required this.city,
    required this.country,
    required this.postalCode,
  });
}

@dataClassMacro
class Tag with TagData {
  @JsonKey(name: 'id')
  final int id;

  @JsonKey(name: 'label')
  final String label;

  Tag({
    required this.id,
    required this.label,
  });
}

@dataClassMacro
class ApiResponse<T> with ApiResponseData<T> {
  @JsonKey(name: 'status')
  final String status;

  @JsonKey(name: 'code')
  final int code;

  @JsonKey(name: 'message')
  final String? message;

  @JsonKey(name: 'timestamp')
  final DateTime timestamp;

  @JsonKey(name: 'data')
  final T? data;

  ApiResponse({
    required this.status,
    required this.code,
    required this.timestamp,
    this.message,
    this.data,
  });
}

@dataClassMacro
class Paginated<T> with PaginatedData<T> {
  @JsonKey(name: 'items')
  final List<T> items;

  @JsonKey(name: 'total_count')
  final int totalCount;

  @JsonKey(name: 'page')
  final int page;

  @JsonKey(name: 'page_size')
  final int pageSize;

  Paginated({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });
}

@dataClassMacro
class Product with ProductData {
  @JsonKey(name: 'id')
  final String id;

  @JsonKey(name: 'title')
  final String title;

  @JsonKey(name: 'price')
  final double price;

  @JsonKey(name: 'metadata')
  final Map<String, dynamic> metadata;

  @JsonKey(name: 'tags')
  final List<String> tags;

  @JsonKey(name: 'attributes')
  final Map<String, ProductAttribute> attributes;

  Product({
    required this.id,
    required this.title,
    required this.price,
    required this.metadata,
    required this.tags,
    required this.attributes,
  });
}

@dataClassMacro
class ProductAttribute with ProductAttributeData {
  @JsonKey(name: 'label')
  final String label;

  @JsonKey(name: 'value')
  final String value;

  ProductAttribute({
    required this.label,
    required this.value,
  });
}

/// ----------------- Core primitives -----------------

enum Visibility { public, private, internal }

enum IssueState { open, closed }

enum MergeState { merged, notMerged, conflicted }

enum GitObjectType { blob, tree, commit }

/// ----------------- Small reusable models -----------------

@dataClassMacro
class SimpleUser with SimpleUserData {
  @JsonKey(name: 'login')
  final String login;

  @JsonKey(name: 'id')
  final int id;

  @JsonKey(name: 'avatar_url')
  final String avatarUrl;

  @JsonKey(name: 'type')
  final String type;

  const SimpleUser({
    required this.login,
    required this.id,
    required this.avatarUrl,
    required this.type,
  });

  factory SimpleUser.fromJson(Map<String, dynamic> json) {
    return SimpleUser(
      login: json['login'] as String? ?? '',
      id: (json['id'] as num?)?.toInt() ?? 0,
      avatarUrl: json['avatar_url'] as String? ?? '',
      type: json['type'] as String? ?? 'User',
    );
  }
}

@dataClassMacro
class License with LabelData {
  @JsonKey(name: 'key')
  final String key;

  @JsonKey(name: 'name')
  final String name;

  @JsonKey(name: 'spdx_id')
  final String? spdxId;

  const License({
    required this.key,
    required this.name,
    this.spdxId,
  });

  factory License.fromJson(Map<String, dynamic> json) {
    return License(
      key: json['key'] as String? ?? '',
      name: json['name'] as String? ?? '',
      spdxId: json['spdx_id'] as String?,
    );
  }
}

@dataClassMacro
class Permissions with PermissionsData {
  @JsonKey(name: 'admin')
  final bool admin;

  @JsonKey(name: 'push')
  final bool push;

  @JsonKey(name: 'pull')
  final bool pull;

  const Permissions({
    required this.admin,
    required this.push,
    required this.pull,
  });

  factory Permissions.fromJson(Map<String, dynamic> json) {
    return Permissions(
      admin: json['admin'] as bool? ?? false,
      push: json['push'] as bool? ?? false,
      pull: json['pull'] as bool? ?? false,
    );
  }
}

/// ----------------- Repository & related -----------------

@dataClassMacro
class Repository with RepositoryData {
  @JsonKey(name: 'id')
  final int id;

  @JsonKey(name: 'node_id')
  final String nodeId;

  @JsonKey(name: 'name')
  final String name;

  @JsonKey(name: 'full_name')
  final String fullName;

  @JsonKey(name: 'owner')
  final SimpleUser owner;

  @JsonKey(name: 'private')
  final bool isPrivate;

  @JsonKey(name: 'html_url')
  final String htmlUrl;

  @JsonKey(name: 'description')
  final String? description;

  @JsonKey(name: 'fork')
  final bool fork;

  @JsonKey(name: 'url')
  final String url;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  @JsonKey(name: 'pushed_at')
  final DateTime? pushedAt;

  @JsonKey(name: 'stargazers_count')
  final int stargazersCount;

  @JsonKey(name: 'watchers_count')
  final int watchersCount;

  @JsonKey(name: 'language')
  final String? language;

  @JsonKey(name: 'forks_count')
  final int forksCount;

  @JsonKey(name: 'open_issues_count')
  final int openIssuesCount;

  @JsonKey(name: 'license')
  final License? license;

  @JsonKey(name: 'permissions')
  final Permissions? permissions;

  @JsonKey(name: 'visibility')
  final Visibility visibility;

  const Repository({
    required this.id,
    required this.nodeId,
    required this.name,
    required this.fullName,
    required this.owner,
    required this.isPrivate,
    required this.htmlUrl,
    this.description,
    required this.fork,
    required this.url,
    required this.createdAt,
    required this.updatedAt,
    this.pushedAt,
    required this.stargazersCount,
    required this.watchersCount,
    this.language,
    required this.forksCount,
    required this.openIssuesCount,
    this.license,
    this.permissions,
    required this.visibility,
  });
}

/// ----------------- Issues & Comments -----------------

@dataClassMacro
class Label with LabelData {
  @JsonKey(name: 'id')
  final int id;

  @JsonKey(name: 'name')
  final String name;

  @JsonKey(name: 'color')
  final String color;

  @JsonKey(name: 'description')
  final String? description;

  const Label({
    required this.id,
    required this.name,
    required this.color,
    this.description,
  });
}

@dataClassMacro
class Comment with CommentData {
  @JsonKey(name: 'id')
  final int id;

  @JsonKey(name: 'user')
  final SimpleUser user;

  @JsonKey(name: 'body')
  final String body;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  const Comment({
    required this.id,
    required this.user,
    required this.body,
    required this.createdAt,
    this.updatedAt,
  });
}

@dataClassMacro
class Issue with IssueData {
  @JsonKey(name: 'id')
  final int id;

  @JsonKey(name: 'number')
  final int number;

  @JsonKey(name: 'title')
  final String title;

  @JsonKey(name: 'user')
  final SimpleUser user;

  @JsonKey(name: 'state')
  final IssueState state;

  @JsonKey(name: 'labels')
  final List<Label> labels;

  @JsonKey(name: 'assignees')
  final List<SimpleUser> assignees;

  @JsonKey(name: 'comments')
  final int commentsCount;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  @JsonKey(name: 'closed_at')
  final DateTime? closedAt;

  @JsonKey(name: 'body')
  final String? body;

  const Issue({
    required this.id,
    required this.number,
    required this.title,
    required this.user,
    required this.state,
    required this.labels,
    required this.assignees,
    required this.commentsCount,
    required this.createdAt,
    this.updatedAt,
    this.closedAt,
    this.body,
  });
}

/// ----------------- Pull Requests -----------------

@dataClassMacro
class PullRequest with PullRequestData {
  @JsonKey(name: 'id')
  final int id;

  @JsonKey(name: 'number')
  final int number;

  @JsonKey(name: 'title')
  final String title;

  @JsonKey(name: 'user')
  final SimpleUser user;

  @JsonKey(name: 'body')
  final String? body;

  @JsonKey(name: 'state')
  final IssueState state;

  @JsonKey(name: 'merged')
  final bool merged;

  @JsonKey(name: 'mergeable_state')
  final MergeState mergeState;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  @JsonKey(name: 'closed_at')
  final DateTime? closedAt;

  @JsonKey(name: 'merged_at')
  final DateTime? mergedAt;

  @JsonKey(name: 'head')
  final BranchRef head;

  @JsonKey(name: 'base')
  final BranchRef base;

  const PullRequest({
    required this.id,
    required this.number,
    required this.title,
    required this.user,
    this.body,
    required this.state,
    required this.merged,
    required this.mergeState,
    required this.createdAt,
    this.updatedAt,
    this.closedAt,
    this.mergedAt,
    required this.head,
    required this.base,
  });
}

@dataClassMacro
class BranchRef with BranchRefData {
  @JsonKey(name: 'label')
  final String label;

  @JsonKey(name: 'ref')
  final String ref;

  @JsonKey(name: 'sha')
  final String sha;

  @JsonKey(name: 'user')
  final SimpleUser user;

  @JsonKey(name: 'repo')
  final Repository repo;

  BranchRef({
    required this.label,
    required this.ref,
    required this.sha,
    required this.user,
    required this.repo,
  });
}

/// ----------------- Git objects (commit/tree/blob) -----------------

@dataClassMacro
class GitCommit with GitCommitData {
  @JsonKey(name: 'sha')
  final String sha;

  @JsonKey(name: 'message')
  final String message;

  @JsonKey(name: 'author')
  final CommitUser author;

  @JsonKey(name: 'committer')
  final CommitUser committer;

  @JsonKey(name: 'parents')
  final List<String> parents;

  @JsonKey(name: 'tree_sha')
  final String treeSha;

  const GitCommit({
    required this.sha,
    required this.message,
    required this.author,
    required this.committer,
    required this.parents,
    required this.treeSha,
  });
}

@dataClassMacro
class CommitUser with CommentData {
  @JsonKey(name: 'name')
  final String name;

  @JsonKey(name: 'email')
  final String email;

  @JsonKey(name: 'date')
  final DateTime date;

  CommitUser({
    required this.name,
    required this.email,
    required this.date,
  });
}

@dataClassMacro
class GitTree with GitTreeData {
  @JsonKey(name: 'sha')
  final String sha;

  @JsonKey(name: 'url')
  final String url;

  @JsonKey(name: 'tree')
  final List<TreeEntry> tree;

  const GitTree({
    required this.sha,
    required this.url,
    required this.tree,
  });
}

@dataClassMacro
class TreeEntry with TreeEntryData {
  @JsonKey(name: 'path')
  final String path;

  @JsonKey(name: 'mode')
  final String mode;

  @JsonKey(name: 'type')
  final GitObjectType type;

  @JsonKey(name: 'sha')
  final String sha;

  @JsonKey(name: 'size')
  final int? size;

  TreeEntry({
    required this.path,
    required this.mode,
    required this.type,
    required this.sha,
    this.size,
  });
}

@dataClassMacro
class GitBlob with GitBlobData {
  @JsonKey(name: 'sha')
  final String sha;

  @JsonKey(name: 'size')
  final int size;

  @JsonKey(name: 'encoding')
  final String encoding;

  @JsonKey(name: 'content')
  final String content; // base64 content

  const GitBlob({
    required this.sha,
    required this.size,
    required this.encoding,
    required this.content,
  });
}

/// ----------------- Examssmmplsse composite response -----------------

@dataClassMacro
class RepoFull with RepoFullData {
  @JsonKey(name: 'repository')
  final Repository repository;

  @JsonKey(name: 'readme')
  final GitBlob? readme;

  @JsonKey(name: 'latest_commit')
  final GitCommit? latestCommit;

  @JsonKey(name: 'issues', fromJson: issuesFromJson, toJson: issuesToJson)
  final Paginated<Issue>? issues;

  static Paginated<Issue>? issuesFromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return PaginatedData.fromJson(json, (v) => IssueData.fromJson(v as Map<String, dynamic>));
  }

  static Map<String, dynamic>? issuesToJson(Paginated<Issue>? issues) {
    return issues?.toJson((e) => e.toJson());
  }

  RepoFull({
    required this.repository,
    this.readme,
    this.latestCommit,
    this.issues,
  });
}
