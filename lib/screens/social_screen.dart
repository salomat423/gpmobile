import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/mock_data.dart';
import 'chat_screen.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Локальные списки для управления состоянием в реальном времени
  late List<Map<String, dynamic>> _lobbyRooms;
  List<Map<String, dynamic>> _myActiveGames = [];

  @override
  void initState() {
    super.initState();
    // Инициализируем контроллер на 3 вкладки
    _tabController = TabController(length: 3, vsync: this);

    // Загружаем начальные данные из имитационных данных
    _lobbyRooms = List.from(MockData.lobbyRooms);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- 1. ЛОГИКА СОЗДАНИЯ ЛОББИ ---
  void _showCreateLobbySheet() {
    final TextEditingController titleController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20, right: 20, top: 20
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Открыть новое лобби',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: titleController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Название вашей игры...',
                filled: true,
                fillColor: Colors.grey.withOpacity(0.1),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  if (titleController.text.isNotEmpty) {
                    setState(() {
                      _myActiveGames.insert(0, {
                        'title': titleController.text,
                        'host': 'Вы (Организатор)',
                        'level': 'Любой уровень',
                        'time': 'Сегодня, сейчас',
                        'members': 1,
                        'maxMembers': 4,
                        'isHost': true, // Флаг создателя
                      });
                    });
                    Navigator.pop(context);
                    _tabController.animateTo(2); // Переход во вкладку "Мои игры"
                  }
                },
                child: const Text('Открыть лобби'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. ЛОГИКА ПРИСОЕДИНЕНИЯ К ИГРЕ ---
  void _joinGame(Map<String, dynamic> room) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Присоединиться?'),
        content: Text('Вы хотите записаться на игру "${room['title']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                // Удаляем из общего списка Лобби
                _lobbyRooms.remove(room);
                // Добавляем в список активных игр пользователя
                _myActiveGames.add({
                  ...room,
                  'members': room['members'] + 1,
                  'isHost': false, // Пользователь не является создателем
                });
              });
              Navigator.pop(context);
              _tabController.animateTo(2); // Переход в раздел своих игр

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Вы успешно присоединились к игре!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Да'),
          ),
        ],
      ),
    );
  }

  // --- 3. ЛОГИКА ОТМЕНЫ ИЛИ ВЫХОДА ИЗ ЛОББИ ---
  void _leaveOrDeleteGame(Map<String, dynamic> room) {
    setState(() {
      _myActiveGames.remove(room);
      // Если это было чужое лобби, оно возвращается в общий список для других
      if (room['isHost'] != true) {
        _lobbyRooms.add({
          ...room,
          'members': room['members'] - 1,
        });
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(room['isHost'] == true ? 'Лобби удалено' : 'Вы покинули лобби'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeColor = isDark ? AppTheme.accentColor : AppTheme.primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Сообщество'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: activeColor,
          unselectedLabelColor: isDark ? Colors.white60 : Colors.grey,
          indicatorColor: activeColor,
          tabs: const [
            Tab(text: 'Лобби'),
            Tab(text: 'Друзья'),
            Tab(text: 'Мои игры'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLobbyTab(isDark, theme),
          _buildFriendsTab(isDark),
          _buildMyGamesTab(isDark, theme),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateLobbySheet,
        backgroundColor: activeColor,
        icon: Icon(Icons.add, color: isDark ? AppTheme.primaryColor : Colors.white),
        label: Text('Создать',
            style: TextStyle(color: isDark ? AppTheme.primaryColor : Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // --- ВКЛАДКА 1: ОБЩЕЕ ЛОББИ ---
  Widget _buildLobbyTab(bool isDark, ThemeData theme) {
    if (_lobbyRooms.isEmpty) {
      return const Center(
          child: Text('Свободных лобби пока нет', style: TextStyle(color: Colors.grey))
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _lobbyRooms.length,
      itemBuilder: (context, index) => _buildGameCard(_lobbyRooms[index], isDark, theme, isLobbyTab: true),
    );
  }

  // --- ВКЛАДКА 2: ДРУЗЬЯ ---
  Widget _buildFriendsTab(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: MockData.friends.length,
      itemBuilder: (context, index) {
        final friend = MockData.friends[index];
        Color statusColor = friend['status'] == 'online' ? Colors.green : (friend['status'] == 'in_game' ? Colors.orange : Colors.grey);
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundImage: NetworkImage(friend['avatar']),
              ),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: 14, height: 14,
                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5)),
                ),
              )
            ],
          ),
          title: Text(friend['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(friend['rank'], style: const TextStyle(fontSize: 12)),
          trailing: IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.grey),
            onPressed: () {
              // Переход в чат с выбранным другом
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ChatScreen(friend: friend)),
              );
            },
          ),
        );
      },
    );
  }

  // --- ВКЛАДКА 3: МОИ ИГРЫ (ЗАРЕГИСТРИРОВАННЫЕ И СОБСТВЕННЫЕ) ---
  Widget _buildMyGamesTab(bool isDark, ThemeData theme) {
    if (_myActiveGames.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sports_tennis_rounded, size: 64, color: Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text('У вас нет активных игр', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _myActiveGames.length,
      itemBuilder: (context, index) => _buildGameCard(_myActiveGames[index], isDark, theme, isLobbyTab: false),
    );
  }

  // УНИВЕРСАЛЬНЫЙ ВИДЖЕТ КАРТОЧКИ ИГРЫ
  Widget _buildGameCard(Map<String, dynamic> room, bool isDark, ThemeData theme, {required bool isLobbyTab}) {
    final bool isHost = room['isHost'] ?? false;
    final Color activeColor = isDark ? AppTheme.accentColor : AppTheme.primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        // Подсвечиваем рамкой, если пользователь организатор
        border: isHost ? Border.all(color: AppTheme.accentColor.withOpacity(0.5), width: 2) : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Метка организатора в разделе "Мои игры"
          if (isHost && !isLobbyTab)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, color: AppTheme.accentColor, size: 16),
                  const SizedBox(width: 6),
                  Text('ВЫ ОТКРЫЛИ ЭТО ЛОББИ',
                      style: TextStyle(
                          color: isDark ? AppTheme.accentColor : Colors.green[700],
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 0.5
                      )),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(room['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: activeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(room['time'], style: TextStyle(color: activeColor, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Text('${room['host']} • ${room['level']}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Игроки: ${room['members']}/${room['maxMembers']}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              if (isLobbyTab)
                ElevatedButton(
                  onPressed: () => _joinGame(room),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    minimumSize: const Size(0, 36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Вступить', style: TextStyle(fontSize: 13)),
                )
              else
                TextButton(
                  onPressed: () => _leaveOrDeleteGame(room),
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                  child: Text(isHost ? 'Удалить лобби' : 'Покинуть',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                )
            ],
          )
        ],
      ),
    );
  }
}