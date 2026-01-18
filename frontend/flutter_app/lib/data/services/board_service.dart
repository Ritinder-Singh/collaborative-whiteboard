import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:collaborative_whiteboard/data/services/auth_service.dart';

/// Board model
class Board {
  final String id;
  final String name;
  final String? ownerId;
  final bool isLocked;
  final bool isPublic;
  final String? thumbnailUrl;
  final Map<String, dynamic> settings;
  final Map<String, dynamic>? canvasData;
  final String? role;
  final DateTime createdAt;
  final DateTime updatedAt;

  Board({
    required this.id,
    required this.name,
    this.ownerId,
    required this.isLocked,
    required this.isPublic,
    this.thumbnailUrl,
    required this.settings,
    this.canvasData,
    this.role,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Board.fromJson(Map<String, dynamic> json) => Board(
        id: json['id'] as String,
        name: json['name'] as String,
        ownerId: json['owner_id'] as String?,
        isLocked: json['is_locked'] as bool? ?? false,
        isPublic: json['is_public'] as bool? ?? true,
        thumbnailUrl: json['thumbnail_url'] as String?,
        settings: json['settings'] as Map<String, dynamic>? ?? {},
        canvasData: json['canvas_data'] as Map<String, dynamic>?,
        role: json['role'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'owner_id': ownerId,
        'is_locked': isLocked,
        'is_public': isPublic,
        'thumbnail_url': thumbnailUrl,
        'settings': settings,
        'canvas_data': canvasData,
        'role': role,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  bool get canEdit =>
      role == 'owner' || role == 'editor' || (isPublic && !isLocked);
}

/// Board list response
class BoardListResponse {
  final List<Board> boards;
  final int total;
  final int page;
  final int pageSize;

  BoardListResponse({
    required this.boards,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory BoardListResponse.fromJson(Map<String, dynamic> json) =>
      BoardListResponse(
        boards: (json['boards'] as List<dynamic>)
            .map((b) => Board.fromJson(b as Map<String, dynamic>))
            .toList(),
        total: json['total'] as int,
        page: json['page'] as int,
        pageSize: json['page_size'] as int,
      );
}

/// Board member model
class BoardMember {
  final String oderId;
  final String displayName;
  final String role;
  final DateTime joinedAt;

  BoardMember({
    required this.oderId,
    required this.displayName,
    required this.role,
    required this.joinedAt,
  });

  factory BoardMember.fromJson(Map<String, dynamic> json) => BoardMember(
        oderId: json['user_id'] as String,
        displayName: json['display_name'] as String,
        role: json['role'] as String,
        joinedAt: DateTime.parse(json['joined_at'] as String),
      );
}

/// Board version model
class BoardVersion {
  final String id;
  final int versionNumber;
  final String? createdBy;
  final DateTime createdAt;

  BoardVersion({
    required this.id,
    required this.versionNumber,
    this.createdBy,
    required this.createdAt,
  });

  factory BoardVersion.fromJson(Map<String, dynamic> json) => BoardVersion(
        id: json['id'] as String,
        versionNumber: json['version_number'] as int,
        createdBy: json['created_by'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

/// Board service for board management
class BoardService {
  final String baseUrl;
  final AuthService authService;

  BoardService({
    required this.baseUrl,
    required this.authService,
  });

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (authService.accessToken != null)
          'Authorization': 'Bearer ${authService.accessToken}',
      };

  /// List all accessible boards
  Future<BoardListResponse> listBoards({int page = 1, int pageSize = 20}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/boards?page=$page&page_size=$pageSize'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw BoardException('Failed to load boards');
    }

    return BoardListResponse.fromJson(jsonDecode(response.body));
  }

  /// List boards owned by current user
  Future<BoardListResponse> listMyBoards({int page = 1, int pageSize = 20}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/boards/my?page=$page&page_size=$pageSize'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw BoardException('Failed to load boards');
    }

    return BoardListResponse.fromJson(jsonDecode(response.body));
  }

  /// Create a new board
  Future<Board> createBoard({
    String name = 'Untitled Board',
    bool isPublic = true,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/boards'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'is_public': isPublic,
      }),
    );

    if (response.statusCode != 201) {
      final error = jsonDecode(response.body);
      throw BoardException(error['detail'] ?? 'Failed to create board');
    }

    return Board.fromJson(jsonDecode(response.body));
  }

  /// Get a board by ID
  Future<Board> getBoard(String boardId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/boards/$boardId'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      if (response.statusCode == 404) {
        throw BoardException('Board not found');
      }
      if (response.statusCode == 403) {
        throw BoardException('Access denied');
      }
      throw BoardException('Failed to load board');
    }

    return Board.fromJson(jsonDecode(response.body));
  }

  /// Update board settings
  Future<Board> updateBoard(
    String boardId, {
    String? name,
    bool? isPublic,
    bool? isLocked,
    Map<String, dynamic>? settings,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (isPublic != null) body['is_public'] = isPublic;
    if (isLocked != null) body['is_locked'] = isLocked;
    if (settings != null) body['settings'] = settings;

    final response = await http.patch(
      Uri.parse('$baseUrl/api/boards/$boardId'),
      headers: _headers,
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw BoardException(error['detail'] ?? 'Failed to update board');
    }

    return Board.fromJson(jsonDecode(response.body));
  }

  /// Save canvas data (auto-save)
  Future<Board> saveCanvas(
    String boardId,
    Map<String, dynamic> canvasData, {
    bool createVersion = false,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/boards/$boardId/canvas'),
      headers: _headers,
      body: jsonEncode({
        'canvas_data': canvasData,
        'create_version': createVersion,
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw BoardException(error['detail'] ?? 'Failed to save canvas');
    }

    return Board.fromJson(jsonDecode(response.body));
  }

  /// Delete a board
  Future<void> deleteBoard(String boardId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/boards/$boardId'),
      headers: _headers,
    );

    if (response.statusCode != 204) {
      final error = jsonDecode(response.body);
      throw BoardException(error['detail'] ?? 'Failed to delete board');
    }
  }

  /// List board members
  Future<List<BoardMember>> listMembers(String boardId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/boards/$boardId/members'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw BoardException('Failed to load members');
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((m) => BoardMember.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  /// Add a member to a board
  Future<BoardMember> addMember(
    String boardId,
    String oderId, {
    String role = 'editor',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/boards/$boardId/members'),
      headers: _headers,
      body: jsonEncode({
        'user_id': oderId,
        'role': role,
      }),
    );

    if (response.statusCode != 201) {
      final error = jsonDecode(response.body);
      throw BoardException(error['detail'] ?? 'Failed to add member');
    }

    return BoardMember.fromJson(jsonDecode(response.body));
  }

  /// Remove a member from a board
  Future<void> removeMember(String boardId, String oderId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/boards/$boardId/members/$oderId'),
      headers: _headers,
    );

    if (response.statusCode != 204) {
      final error = jsonDecode(response.body);
      throw BoardException(error['detail'] ?? 'Failed to remove member');
    }
  }

  /// List board versions
  Future<List<BoardVersion>> listVersions(String boardId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/boards/$boardId/versions'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      throw BoardException('Failed to load versions');
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((v) => BoardVersion.fromJson(v as Map<String, dynamic>))
        .toList();
  }

  /// Restore a board version
  Future<Board> restoreVersion(String boardId, String versionId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/boards/$boardId/versions/$versionId/restore'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw BoardException(error['detail'] ?? 'Failed to restore version');
    }

    return Board.fromJson(jsonDecode(response.body));
  }
}

/// Board exception
class BoardException implements Exception {
  final String message;
  BoardException(this.message);

  @override
  String toString() => message;
}
