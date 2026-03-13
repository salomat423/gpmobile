class MockData {
  // --- 1. Профиль и Персонализация (ТЗ п.1, 8.1) ---
  static const String userName = 'Александр Иванов';
  static const String userPhone = '+7 777 123 45 67';
  static const String userAvatar = 'https://i.pravatar.cc/150?img=11';

  // --- 2. Персональная статистика (ТЗ п.1.4) ---
  static final Map<String, dynamic> userStats = {
    'totalVisits': 124,          // Общее количество посещений
    'hoursOnCourt': 186,         // Время на кортах (часы)
    'trainingsCount': 48,        // Пройдено тренировок
    'tournamentsCount': 6,       // Участие в турнирах
    'winRate': '68%',            // Процент побед
    'currentPoints': 2450,       // Текущий рейтинг
  };

  // --- 3. Информация об абонементе (ТЗ п.1.5) ---
  static final Map<String, dynamic> subscription = {
    'type': 'Premium Unlimited',
    'endDate': '15.11.2024',
    'remainingVisits': 'Безлимит',
    'status': 'active',          // active (активен), expiring (истекает), expired (истек)
    'price': '45 000 ₸ / мес'
  };

  // --- 4. Информационный блок: Новости и Акции (ТЗ п.1.2) ---
  static final List<Map<String, String>> banners = [
    {
      'type': 'Турнир',
      'title': 'Летний кубок Padel 2024',
      'subtitle': 'Регистрация открыта до 30 июня. Главный приз — 500 000 ₸!',
      'color': '0xFF0F3628',
    },
    {
      'type': 'Акция',
      'title': 'Скидка 20% утром',
      'subtitle': 'Бронируйте корты с 08:00 до 11:00 по будням дешевле.',
      'color': '0xFFD4F826',
    },
    {
      'type': 'Новость',
      'title': 'Обновление меню в баре',
      'subtitle': 'Попробуйте наши новые протеиновые коктейли и смузи.',
      'color': '0xFF1B5E20',
    },
  ];

  // --- 5. Расписание пользователя (ТЗ п.1.6) ---
  static final List<Map<String, dynamic>> myBookings = [
    {
      'court': 'Center Court Padel',
      'date': 'Сегодня, 18:00',
      'duration': '90 мин',
      'type': 'Одиночная игра',
      'status': 'Оплачено',      // Статус подтверждения
      'price': '6000 ₸',
    },
    {
      'court': 'Indoor Arena A',
      'date': '24 Окт, 10:00',
      'duration': '60 мин',
      'type': 'Тренировка с профи',
      'status': 'Ожидает',
      'price': '14 500 ₸',
    },
  ];

  // --- 6. Система бронирования: Корты (ТЗ п.2) ---
  static final List<Map<String, dynamic>> courts = [
    {
      'id': 1,
      'name': 'Center Court Padel',
      'type': 'Panorama',
      'basePrice': '6000 ₸',
      'premiumPrice': '8000 ₸', // Вечернее время
      'image': 'https://images.unsplash.com/photo-1622279457486-62dcc4a431d6?q=80&w=1000&auto=format&fit=crop',
      'status': 'free',         // free, busy, maintenance
      'rating': 4.9,
    },
    {
      'id': 2,
      'name': 'Indoor Arena A',
      'type': 'Hard',
      'basePrice': '4500 ₸',
      'premiumPrice': '6000 ₸',
      'image': 'https://images.unsplash.com/photo-1595435934249-5df7ed86e1c0?q=80&w=1000&auto=format&fit=crop',
      'status': 'busy',
      'rating': 4.7,
    },
    {
      'id': 3,
      'name': 'Clay Classic 3',
      'type': 'Clay',
      'basePrice': '4000 ₸',
      'premiumPrice': '5500 ₸',
      'image': 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?q=80&w=1000&auto=format&fit=crop',
      'status': 'free',
      'rating': 4.8,
    },
  ];

  // --- 7. Каталог тренеров (ТЗ п.4) ---
  static final List<Map<String, dynamic>> coaches = [
    {
      'id': 1,
      'name': 'Иван Петров',
      'level': 'Master Coach',
      'exp': '8 лет опыта',
      'rating': 4.9,
      'reviews': 124,
      'image': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?q=80&w=1000&auto=format&fit=crop',
      'price': '12 000 ₸',
      'specialization': 'Индивидуальные / Профи'
    },
    {
      'id': 2,
      'name': 'Елена Ким',
      'level': 'Senior Coach',
      'exp': '5 лет опыта',
      'rating': 4.8,
      'reviews': 89,
      'image': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=1000&auto=format&fit=crop',
      'price': '10 000 ₸',
      'specialization': 'Дети и новички'
    },
  ];

  // --- 8. Система поиска партнеров: Лобби (ТЗ п.3) ---
  static final List<Map<String, dynamic>> lobbyRooms = [
    {
      'title': 'Спарринг утром',
      'host': 'Александр К.',
      'level': 'Средний',         // Новичок, Средний, Продвинутый, Профи
      'format': 'Одиночный',      // Одиночный / Парный
      'time': 'Завтра, 09:00',
      'status': 'searching',      // searching (набор), waiting (ожидание), full (готов)
      'members': 1,
      'maxMembers': 2,
    },
    {
      'title': 'Парная на интерес',
      'host': 'Мария С.',
      'level': 'Новичок',
      'format': 'Парный',
      'time': 'Сегодня, 20:00',
      'status': 'waiting',
      'members': 3,
      'maxMembers': 4,
    },
  ];

  // --- 9. Рейтинговая система и лиги (ТЗ п.7) ---
  static final List<Map<String, dynamic>> matches = [
    {
      'opponent': 'Дмитрий Волков',
      'score': '6:4, 7:5',
      'result': 'win',
      'date': '15 Окт',
      'change': '+25 pts'
    },
    {
      'opponent': 'Турнир "Осень"',
      'score': '2:6, 4:6',
      'result': 'lose',
      'date': '12 Окт',
      'change': '-15 pts'
    },
  ];

  // --- 10. Друзья и Соц. взаимодействие (ТЗ п.10) ---
  static final List<Map<String, dynamic>> friends = [
    {
      'name': 'Дмитрий Волков',
      'status': 'online',         // online, in_game, offline
      'rank': 'Pro League',
      'avatar': 'https://i.pravatar.cc/150?img=12',
      'points': 3100
    },
    {
      'name': 'Анна Соколова',
      'status': 'in_game',
      'rank': 'Amateur I',
      'avatar': 'https://i.pravatar.cc/150?img=5',
      'points': 1850
    },
  ];

  // --- 11. Система достижений (ТЗ п.11) ---
  static final List<Map<String, dynamic>> achievements = [
    {
      'title': 'Первая победа',
      'category': 'Игровые',
      'icon': '🏆',
      'progress': 1.0,
      'rarity': '85%',
      'isUnlocked': true,
      'date': '12.05.2024'
    },
    {
      'title': 'Марафонец',
      'category': 'Активности',
      'icon': '🏃',
      'progress': 0.7,
      'rarity': '15%',
      'isUnlocked': false,
      'date': null
    },
    {
      'title': 'Популярный игрок',
      'category': 'Социальные',
      'icon': '🤝',
      'progress': 1.0,
      'rarity': '30%',
      'isUnlocked': true,
      'date': '01.09.2024'
    },
  ];

  // --- 12. Финансовая информация (ТЗ п.8.2) ---
  static final List<Map<String, dynamic>> transactions = [
    {'date': '20 Окт', 'amount': '-6 000 ₸', 'type': 'Аренда корта', 'method': 'Visa •• 4455'},
    {'date': '18 Окт', 'amount': '+2 000 ₸', 'type': 'Возврат средств', 'method': 'Баланс'},
    {'date': '15 Окт', 'amount': '-45 000 ₸', 'type': 'Продление абонемента', 'method': 'Kaspi Pay'},
  ];

  // --- 13. Система уведомлений (ТЗ п.13) ---
  static final List<Map<String, dynamic>> notifications = [
    {
      'id': 1,
      'type': 'booking',         // booking, social, achievement, finance, news
      'title': 'Бронь подтверждена',
      'body': 'Ждем вас сегодня в 18:00 на Center Court. Не забудьте форму!',
      'time': '5 мин назад',
      'isRead': false,
      'requiresAction': false
    },
    {
      'id': 2,
      'type': 'social',
      'title': 'Запрос в друзья',
      'body': 'Максим Ли хочет добавить вас в друзья.',
      'time': '2 часа назад',
      'isRead': false,
      'requiresAction': true      // Кнопки "Принять/Отклонить"
    },
    {
      'id': 3,
      'type': 'finance',
      'title': 'Успешная оплата',
      'body': 'Списание 6 000 ₸ за бронирование корта №1.',
      'time': 'Вчера',
      'isRead': true,
      'requiresAction': false
    },
  ];
}