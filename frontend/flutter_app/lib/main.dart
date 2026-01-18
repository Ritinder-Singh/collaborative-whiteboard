import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collaborative_whiteboard/data/services/auth_service.dart';
import 'package:collaborative_whiteboard/data/services/board_service.dart';
import 'package:collaborative_whiteboard/features/auth/screens/login_screen.dart';
import 'package:collaborative_whiteboard/features/auth/screens/register_screen.dart';
import 'package:collaborative_whiteboard/features/dashboard/screens/dashboard_screen.dart';
import 'package:collaborative_whiteboard/features/canvas/screens/canvas_screen.dart';

// Server URL - change this for production
const String serverUrl = 'http://localhost:8000';

// Providers for services
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(baseUrl: serverUrl);
});

final boardServiceProvider = Provider<BoardService>((ref) {
  final authService = ref.watch(authServiceProvider);
  return BoardService(baseUrl: serverUrl, authService: authService);
});

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: CollaborativeWhiteboardApp(),
    ),
  );
}

class CollaborativeWhiteboardApp extends ConsumerStatefulWidget {
  const CollaborativeWhiteboardApp({super.key});

  @override
  ConsumerState<CollaborativeWhiteboardApp> createState() =>
      _CollaborativeWhiteboardAppState();
}

class _CollaborativeWhiteboardAppState
    extends ConsumerState<CollaborativeWhiteboardApp> {
  bool _isInitialized = false;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _initAuth();
  }

  Future<void> _initAuth() async {
    final authService = ref.read(authServiceProvider);
    await authService.init();
    setState(() {
      _isInitialized = true;
      _isAuthenticated = authService.isAuthenticated;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Collaborative Whiteboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark, // Default to dark for canvas
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_isAuthenticated) {
      return const AppNavigator();
    }

    return AuthNavigator(
      onAuthSuccess: () {
        setState(() => _isAuthenticated = true);
      },
    );
  }
}

/// Navigator for authentication flow
class AuthNavigator extends ConsumerStatefulWidget {
  final VoidCallback onAuthSuccess;

  const AuthNavigator({super.key, required this.onAuthSuccess});

  @override
  ConsumerState<AuthNavigator> createState() => _AuthNavigatorState();
}

class _AuthNavigatorState extends ConsumerState<AuthNavigator> {
  bool _showRegister = false;

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);

    if (_showRegister) {
      return RegisterScreen(
        authService: authService,
        onRegisterSuccess: widget.onAuthSuccess,
        onNavigateToLogin: () => setState(() => _showRegister = false),
      );
    }

    return LoginScreen(
      authService: authService,
      onLoginSuccess: widget.onAuthSuccess,
      onNavigateToRegister: () => setState(() => _showRegister = true),
    );
  }
}

/// Main app navigator after authentication
class AppNavigator extends ConsumerStatefulWidget {
  const AppNavigator({super.key});

  @override
  ConsumerState<AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends ConsumerState<AppNavigator> {
  String? _currentBoardId;

  void _openBoard(String boardId) {
    setState(() => _currentBoardId = boardId);
  }

  void _closeBoard() {
    setState(() => _currentBoardId = null);
  }

  void _logout() async {
    final authService = ref.read(authServiceProvider);
    await authService.logout();
    // Force app rebuild by navigating to login
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const CollaborativeWhiteboardApp(),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final boardService = ref.watch(boardServiceProvider);

    if (_currentBoardId != null) {
      return WillPopScope(
        onWillPop: () async {
          _closeBoard();
          return false;
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _closeBoard,
            ),
            title: const Text('Whiteboard'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  // TODO: Board settings
                },
              ),
            ],
          ),
          body: const CanvasScreen(),
        ),
      );
    }

    return DashboardScreen(
      authService: authService,
      boardService: boardService,
      onOpenBoard: _openBoard,
      onLogout: _logout,
    );
  }
}
