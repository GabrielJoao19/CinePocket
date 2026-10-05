import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'navigation/route_names.dart';
import 'navigation/tab_routes.dart';
import 'screens/login_screen.dart';
import 'screens/settings_screen.dart';
import 'theme.dart';

void main() {
  runApp(const CinePocketApp());
}

/// Aplicativo principal com mapeamento centralizado de rotas nomeadas.
class CinePocketApp extends StatelessWidget {
  const CinePocketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CinePocket',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // Rota inicial da aplicação
      initialRoute: RouteNames.home,
      // 1. Mapeamento centralizado de rotas no MaterialApp
      routes: {
        RouteNames.login: (context) => const LoginScreen(),
        RouteNames.home: (context) => const MainShell(),
        RouteNames.settings: (context) {
          // 4. Recebimento de argumentos em rota nomeada
          final args = ModalRoute.of(context)?.settings.arguments;
          final currentName = args is String ? args : 'João Gabriel';
          return SettingsScreen(currentName: currentName);
        },
      },
    );
  }
}

/// Casca principal: orquestra Drawer + BottomNavigationBar com Navigators independentes por aba.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  String _userName = 'João Gabriel';
  final String _userEmail = 'joao.gabriel@email.com';

  /// Chave de Navigator para cada uma das 3 abas principais.
  /// Isso garante histórico de navegação independente por aba!
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  Widget _buildTabNavigator(int tabIndex) {
    return Navigator(
      key: _navigatorKeys[tabIndex],
      initialRoute: RouteNames.tabRoot,
      onGenerateRoute: (settings) => TabRoutes.generate(settings, tabIndex),
    );
  }

  /// 2. Drawer com pelo menos 3 itens:
  ///  - Configurações (com push e retorno de resultado)
  ///  - Sobre (modal de diálogo)
  ///  - Logout (com pushReplacement para /login)
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              color: AppColors.background,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: AppColors.yellow,
              child: Text(
                _userName.isNotEmpty ? _userName[0].toUpperCase() : 'C',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            accountName: Text(
              _userName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            accountEmail: Text(
              _userEmail,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.settings, color: AppColors.yellow),
            title: const Text('Configurações'),
            subtitle: const Text('Editar perfil e preferências',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            onTap: () async {
              Navigator.pop(context); // fecha o drawer
              // 2 e 5. Push com argumentos e recebimento de resultado via pop
              final result = await Navigator.of(context).pushNamed<String>(
                RouteNames.settings,
                arguments: _userName,
              );
              if (result != null && mounted) {
                setState(() => _userName = result);
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(
                    content: Text('Nome atualizado para "$result"'),
                    behavior: SnackBarBehavior.floating,
                  ));
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline, color: AppColors.yellow),
            title: const Text('Sobre'),
            subtitle: const Text('Informações da aplicação',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            onTap: () {
              Navigator.pop(context); // fecha o drawer
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.movie_creation, color: AppColors.yellow),
                      SizedBox(width: 8),
                      Text('Sobre o CinePocket'),
                    ],
                  ),
                  content: const Text(
                    'CinePocket v1.0.0\n\n'
                    'Catálogo e avaliação interativa de filmes.\n\n'
                    'Desenvolvido com Flutter demonstrando navegação avançada '
                    '(Drawer + BottomNavigationBar com múltiplos Navigators '
                    'e preservação de estado da pilha em cada aba).',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Fechar'),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(color: AppColors.border),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Logout',
                style: TextStyle(color: Colors.redAccent)),
            subtitle: const Text('Sair para tela de autenticação',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            onTap: () {
              Navigator.pop(context); // fecha o drawer
              // 2. Logout usando pushReplacement para tela de login
              Navigator.of(context).pushReplacementNamed(RouteNames.login);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 6. Botão de voltar do sistema operacional respeitando o histórico local de cada aba
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // 1º Se o Drawer estiver aberto, fecha o Drawer
        if (shellScaffoldKey.currentState?.isDrawerOpen ?? false) {
          shellScaffoldKey.currentState?.closeDrawer();
          return;
        }

        // 2º Se a aba ativa possuir rotas empilhadas, faz pop no Navigator da aba
        final currentNav = _navigatorKeys[_currentIndex].currentState;
        if (currentNav != null && currentNav.canPop()) {
          currentNav.pop();
          return;
        }

        // 3º Se estiver em outra aba (Busca ou Favoritos), volta para a aba Início
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return;
        }

        // 4º Se já estiver na raiz da primeira aba, sai do aplicativo
        SystemNavigator.pop();
      },
      child: Scaffold(
        key: shellScaffoldKey,
        drawer: _buildDrawer(context),
        // 3. IndexedStack preserva a pilha e estado de cada aba ao alternar
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildTabNavigator(0),
            _buildTabNavigator(1),
            _buildTabNavigator(2),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) {
              if (i == _currentIndex) {
                // Tocar na mesma aba desempilha até a raiz daquela aba
                _navigatorKeys[i].currentState?.popUntil((r) => r.isFirst);
              } else {
                setState(() => _currentIndex = i);
              }
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Início',
              ),
              NavigationDestination(
                icon: Icon(Icons.search),
                label: 'Buscar',
              ),
              NavigationDestination(
                icon: Icon(Icons.favorite_border),
                selectedIcon: Icon(Icons.favorite),
                label: 'Favoritos',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
