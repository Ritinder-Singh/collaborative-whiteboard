import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:collaborative_whiteboard/data/services/auth_service.dart';
import 'package:collaborative_whiteboard/data/services/board_service.dart';

/// Dashboard screen showing user's boards
class DashboardScreen extends ConsumerStatefulWidget {
  final AuthService authService;
  final BoardService boardService;
  final Function(String boardId) onOpenBoard;
  final VoidCallback onLogout;

  const DashboardScreen({
    super.key,
    required this.authService,
    required this.boardService,
    required this.onOpenBoard,
    required this.onLogout,
  });

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Board> _myBoards = [];
  List<Board> _publicBoards = [];
  bool _isLoadingMy = true;
  bool _isLoadingPublic = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBoards();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBoards() async {
    await Future.wait([
      _loadMyBoards(),
      _loadPublicBoards(),
    ]);
  }

  Future<void> _loadMyBoards() async {
    setState(() {
      _isLoadingMy = true;
      _error = null;
    });

    try {
      final response = await widget.boardService.listMyBoards();
      setState(() {
        _myBoards = response.boards;
        _isLoadingMy = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMy = false;
        _error = 'Failed to load boards';
      });
    }
  }

  Future<void> _loadPublicBoards() async {
    setState(() {
      _isLoadingPublic = true;
    });

    try {
      final response = await widget.boardService.listBoards();
      setState(() {
        _publicBoards = response.boards;
        _isLoadingPublic = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingPublic = false;
      });
    }
  }

  Future<void> _createBoard() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _CreateBoardDialog(),
    );

    if (name == null) return;

    try {
      final board = await widget.boardService.createBoard(name: name);
      widget.onOpenBoard(board.id);
    } on BoardException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  Future<void> _deleteBoard(Board board) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Board'),
        content: Text('Are you sure you want to delete "${board.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await widget.boardService.deleteBoard(board.id);
      await _loadMyBoards();
    } on BoardException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  void _showUserMenu() {
    final user = widget.authService.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: CircleAvatar(
                child: Text(user.displayName[0].toUpperCase()),
              ),
              title: Text(user.displayName),
              subtitle: Text(user.email ?? 'Anonymous user'),
            ),
            const Divider(),
            if (user.isAnonymous)
              ListTile(
                leading: const Icon(Icons.person_add),
                title: const Text('Create Account'),
                subtitle: const Text('Save your boards permanently'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Navigate to convert account screen
                },
              ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign Out'),
              onTap: () {
                Navigator.pop(context);
                widget.onLogout();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authService.currentUser;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Whiteboards'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBoards,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.primaryContainer,
              child: Text(
                user?.displayName[0].toUpperCase() ?? '?',
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            onPressed: _showUserMenu,
            tooltip: 'Account',
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'My Boards'),
            Tab(text: 'Public Boards'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // My boards tab
          _buildBoardGrid(
            boards: _myBoards,
            isLoading: _isLoadingMy,
            emptyMessage: 'No boards yet.\nTap + to create one!',
            showDelete: true,
          ),
          // Public boards tab
          _buildBoardGrid(
            boards: _publicBoards,
            isLoading: _isLoadingPublic,
            emptyMessage: 'No public boards available.',
            showDelete: false,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createBoard,
        icon: const Icon(Icons.add),
        label: const Text('New Board'),
      ),
    );
  }

  Widget _buildBoardGrid({
    required List<Board> boards,
    required bool isLoading,
    required String emptyMessage,
    required bool showDelete,
  }) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(_error!),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadBoards,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (boards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.dashboard_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBoards,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 300,
          childAspectRatio: 1.2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: boards.length,
        itemBuilder: (context, index) {
          final board = boards[index];
          return _BoardCard(
            board: board,
            onTap: () => widget.onOpenBoard(board.id),
            onDelete: showDelete && board.role == 'owner'
                ? () => _deleteBoard(board)
                : null,
          );
        },
      ),
    );
  }
}

class _BoardCard extends StatelessWidget {
  final Board board;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _BoardCard({
    required this.board,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat.yMMMd();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail area
            Expanded(
              child: Container(
                width: double.infinity,
                color: colorScheme.surfaceContainerHighest,
                child: board.thumbnailUrl != null
                    ? Image.network(
                        board.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(context),
                      )
                    : _buildPlaceholder(context),
              ),
            ),
            // Info area
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          board.name,
                          style: Theme.of(context).textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (board.isLocked)
                        Icon(
                          Icons.lock,
                          size: 16,
                          color: colorScheme.outline,
                        ),
                      if (!board.isPublic)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.visibility_off,
                            size: 16,
                            color: colorScheme.outline,
                          ),
                        ),
                      if (onDelete != null)
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          iconSize: 20,
                          onSelected: (value) {
                            if (value == 'delete') onDelete?.call();
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, size: 20),
                                  SizedBox(width: 8),
                                  Text('Delete'),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Updated ${dateFormat.format(board.updatedAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Center(
      child: Icon(
        Icons.brush,
        size: 48,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }
}

class _CreateBoardDialog extends StatefulWidget {
  @override
  State<_CreateBoardDialog> createState() => _CreateBoardDialogState();
}

class _CreateBoardDialogState extends State<_CreateBoardDialog> {
  final _controller = TextEditingController(text: 'Untitled Board');
  bool _isPublic = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Board'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Board Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Public Board'),
            subtitle: const Text('Anyone can view and edit'),
            value: _isPublic,
            onChanged: (value) => setState(() => _isPublic = value),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _controller.text.trim();
            if (name.isNotEmpty) {
              Navigator.pop(context, name);
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
