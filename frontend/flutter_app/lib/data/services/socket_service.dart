import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:collaborative_whiteboard/data/models/stroke.dart';

/// Connection status for the socket
enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Socket service for real-time communication with the backend.
class SocketService {
  io.Socket? _socket;
  String? _currentBoardId;
  String? _userId;
  String? _displayName;

  // Stream controllers for events
  final _connectionStatusController = StreamController<ConnectionStatus>.broadcast();
  final _strokeStartController = StreamController<Map<String, dynamic>>.broadcast();
  final _strokeUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  final _strokeEndController = StreamController<Map<String, dynamic>>.broadcast();
  final _boardStateController = StreamController<Map<String, dynamic>>.broadcast();
  final _userJoinedController = StreamController<Map<String, dynamic>>.broadcast();
  final _userLeftController = StreamController<Map<String, dynamic>>.broadcast();
  final _userCountController = StreamController<int>.broadcast();
  final _cursorUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  final _boardClearedController = StreamController<void>.broadcast();
  final _objectAddedController = StreamController<Map<String, dynamic>>.broadcast();
  final _objectUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _objectDeletedController = StreamController<Map<String, dynamic>>.broadcast();

  // Public streams
  Stream<ConnectionStatus> get connectionStatus => _connectionStatusController.stream;
  Stream<Map<String, dynamic>> get onStrokeStart => _strokeStartController.stream;
  Stream<Map<String, dynamic>> get onStrokeUpdate => _strokeUpdateController.stream;
  Stream<Map<String, dynamic>> get onStrokeEnd => _strokeEndController.stream;
  Stream<Map<String, dynamic>> get onBoardState => _boardStateController.stream;
  Stream<Map<String, dynamic>> get onUserJoined => _userJoinedController.stream;
  Stream<Map<String, dynamic>> get onUserLeft => _userLeftController.stream;
  Stream<int> get onUserCount => _userCountController.stream;
  Stream<Map<String, dynamic>> get onCursorUpdate => _cursorUpdateController.stream;
  Stream<void> get onBoardCleared => _boardClearedController.stream;
  Stream<Map<String, dynamic>> get onObjectAdded => _objectAddedController.stream;
  Stream<Map<String, dynamic>> get onObjectUpdated => _objectUpdatedController.stream;
  Stream<Map<String, dynamic>> get onObjectDeleted => _objectDeletedController.stream;

  bool get isConnected => _socket?.connected ?? false;
  String? get currentBoardId => _currentBoardId;

  /// Connect to the Socket.io server
  Future<void> connect({
    required String serverUrl,
    String? userId,
    String? displayName,
  }) async {
    _userId = userId;
    _displayName = displayName;

    _connectionStatusController.add(ConnectionStatus.connecting);

    _socket = io.io(
      serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(1000)
          .build(),
    );

    _setupEventHandlers();
    _socket!.connect();
  }

  void _setupEventHandlers() {
    final socket = _socket;
    if (socket == null) return;

    // Connection events
    socket.onConnect((_) {
      debugPrint('Socket connected');
      _connectionStatusController.add(ConnectionStatus.connected);
    });

    socket.onDisconnect((_) {
      debugPrint('Socket disconnected');
      _connectionStatusController.add(ConnectionStatus.disconnected);
    });

    socket.onConnectError((error) {
      debugPrint('Socket connection error: $error');
      _connectionStatusController.add(ConnectionStatus.error);
    });

    socket.onReconnecting((_) {
      debugPrint('Socket reconnecting...');
      _connectionStatusController.add(ConnectionStatus.reconnecting);
    });

    socket.onReconnect((_) {
      debugPrint('Socket reconnected');
      _connectionStatusController.add(ConnectionStatus.connected);
      // Rejoin board if we were in one
      if (_currentBoardId != null) {
        joinBoard(_currentBoardId!, displayName: _displayName);
      }
    });

    // Board events
    socket.on('board_state', (data) {
      debugPrint('Received board state');
      _boardStateController.add(Map<String, dynamic>.from(data));
    });

    socket.on('user_joined', (data) {
      debugPrint('User joined: ${data['display_name']}');
      _userJoinedController.add(Map<String, dynamic>.from(data));
    });

    socket.on('user_left', (data) {
      debugPrint('User left: ${data['sid']}');
      _userLeftController.add(Map<String, dynamic>.from(data));
    });

    socket.on('user_count', (data) {
      _userCountController.add(data['count'] as int);
    });

    // Stroke events
    socket.on('stroke_start', (data) {
      _strokeStartController.add(Map<String, dynamic>.from(data));
    });

    socket.on('stroke_update', (data) {
      _strokeUpdateController.add(Map<String, dynamic>.from(data));
    });

    socket.on('stroke_end', (data) {
      _strokeEndController.add(Map<String, dynamic>.from(data));
    });

    // Cursor events
    socket.on('cursor_update', (data) {
      _cursorUpdateController.add(Map<String, dynamic>.from(data));
    });

    // Board cleared
    socket.on('board_cleared', (data) {
      debugPrint('Board cleared');
      _boardClearedController.add(null);
    });

    // Object events
    socket.on('object_added', (data) {
      _objectAddedController.add(Map<String, dynamic>.from(data));
    });

    socket.on('object_updated', (data) {
      _objectUpdatedController.add(Map<String, dynamic>.from(data));
    });

    socket.on('object_deleted', (data) {
      _objectDeletedController.add(Map<String, dynamic>.from(data));
    });
  }

  /// Join a whiteboard
  void joinBoard(String boardId, {String? displayName}) {
    _currentBoardId = boardId;
    _displayName = displayName ?? _displayName ?? 'Anonymous';

    _socket?.emit('join_board', {
      'board_id': boardId,
      'user_id': _userId,
      'display_name': _displayName,
    });
  }

  /// Leave the current board
  void leaveBoard() {
    if (_currentBoardId != null) {
      _socket?.emit('leave_board', {'board_id': _currentBoardId});
      _currentBoardId = null;
    }
  }

  /// Start a new stroke
  void emitStrokeStart({
    required String strokeId,
    required String tool,
    required String color,
    required double size,
    String layerId = 'default',
  }) {
    _socket?.emit('stroke_start', {
      'stroke_id': strokeId,
      'tool': tool,
      'color': color,
      'size': size,
      'layer_id': layerId,
    });
  }

  /// Update stroke with new points
  void emitStrokeUpdate({
    required String strokeId,
    required List<StrokePoint> points,
  }) {
    _socket?.emit('stroke_update', {
      'stroke_id': strokeId,
      'points': points.map((p) => p.toJson()).toList(),
    });
  }

  /// End a stroke
  void emitStrokeEnd({required String strokeId}) {
    _socket?.emit('stroke_end', {'stroke_id': strokeId});
  }

  /// Update cursor position
  void emitCursorMove({required double x, required double y}) {
    _socket?.emit('cursor_move', {'x': x, 'y': y});
  }

  /// Clear the board
  void emitClearBoard() {
    _socket?.emit('clear_board', {});
  }

  /// Add an object (shape, text, etc.)
  void emitObjectAdd({
    required String objectId,
    required String type,
    required Map<String, dynamic> properties,
    String layerId = 'default',
  }) {
    _socket?.emit('object_add', {
      'object_id': objectId,
      'type': type,
      'properties': properties,
      'layer_id': layerId,
    });
  }

  /// Update an object
  void emitObjectUpdate({
    required String objectId,
    required Map<String, dynamic> properties,
  }) {
    _socket?.emit('object_update', {
      'object_id': objectId,
      'properties': properties,
    });
  }

  /// Delete an object
  void emitObjectDelete({required String objectId}) {
    _socket?.emit('object_delete', {'object_id': objectId});
  }

  /// Disconnect from the server
  void disconnect() {
    leaveBoard();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  /// Dispose of all resources
  void dispose() {
    disconnect();
    _connectionStatusController.close();
    _strokeStartController.close();
    _strokeUpdateController.close();
    _strokeEndController.close();
    _boardStateController.close();
    _userJoinedController.close();
    _userLeftController.close();
    _userCountController.close();
    _cursorUpdateController.close();
    _boardClearedController.close();
    _objectAddedController.close();
    _objectUpdatedController.close();
    _objectDeletedController.close();
  }
}
