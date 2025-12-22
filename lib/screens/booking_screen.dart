import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../theme/app_theme.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedDateIndex = 0;
  String _selectedFilter = 'Все';

  late List<Map<String, dynamic>> _userBookings;

  final List<String> _morningSlots = ['07:00', '08:00', '09:00', '10:00', '11:00'];
  final List<String> _daySlots = ['12:00', '13:00', '14:00', '15:00', '16:00', '17:00'];
  final List<String> _eveningSlots = ['18:00', '19:00', '20:00', '21:00', '22:00'];

  final List<DateTime> _dates = List.generate(14, (index) => DateTime.now().add(Duration(days: index)));
  final List<String> _filters = ['Все', 'Hard', 'Clay', 'Panorama', 'Grass'];
  final List<String> _months = ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _userBookings = List.from(MockData.myBookings);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _cancelBooking(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Отменить бронь?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Назад')),
          ElevatedButton(
            onPressed: () {
              setState(() => _userBookings.removeAt(index));
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Да, отменить'),
          ),
        ],
      ),
    );
  }

  void _showTimePicker(Map<String, dynamic> court) {
    String? selectedTime;
    final selectedDate = _dates[_selectedDateIndex];
    // Исправленный ключ цены:
    final String priceValue = (court['basePrice'] ?? court['price'] ?? '0 ₸').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30))
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundImage: NetworkImage(court['image']?.toString() ?? ''),
                      backgroundColor: Colors.grey[200],
                    ),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(court['name']?.toString() ?? 'Корт', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('${court['type']?.toString() ?? ''} • ${selectedDate.day} ${_months[selectedDate.month - 1]}', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 30),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _buildTimeSection('Утро', _morningSlots, selectedTime, (t) => setModalState(() => selectedTime = t)),
                      const SizedBox(height: 20),
                      _buildTimeSection('День', _daySlots, selectedTime, (t) => setModalState(() => selectedTime = t)),
                      const SizedBox(height: 20),
                      _buildTimeSection('Вечер', _eveningSlots, selectedTime, (t) => setModalState(() => selectedTime = t)),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: selectedTime == null ? null : () {
                      setState(() {
                        _userBookings.insert(0, {
                          'court': court['name']?.toString() ?? 'Корт',
                          'date': '${selectedDate.day} ${_months[selectedDate.month - 1].substring(0, 3)}, $selectedTime',
                          'status': 'Оплачено',
                          'price': priceValue
                        });
                      });
                      Navigator.pop(context);
                      _tabController.animateTo(1);
                    },
                    child: Text(selectedTime == null ? 'Выберите время' : 'Забронировать за $priceValue'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSection(String title, List<String> slots, String? selected, Function(String) onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        Wrap(
          spacing: 10, runSpacing: 10,
          children: slots.map((time) {
            final isSelected = time == selected;
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return GestureDetector(
              onTap: () => onSelect(time),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.accentColor : (isDark ? Colors.white10 : Colors.grey[100]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(time, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? AppTheme.primaryColor : (isDark ? Colors.white : Colors.black87))),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = Theme.of(context).brightness == Brightness.dark ? AppTheme.accentColor : AppTheme.primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Бронирование'),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: activeColor,
          indicatorColor: activeColor,
          tabs: const [Tab(text: 'Новая бронь'), Tab(text: 'Мои брони')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildNewBookingTab(), _buildMyBookingsTab()],
      ),
    );
  }

  Widget _buildNewBookingTab() {
    return Column(
      children: [
        _buildDateSelector(),
        _buildFilters(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            itemCount: MockData.courts.length,
            itemBuilder: (context, index) {
              final court = MockData.courts[index];
              if (_selectedFilter != 'Все' && (court['type']?.toString() ?? '') != _selectedFilter) return const SizedBox.shrink();
              return _buildCourtCard(court);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMyBookingsTab() {
    if (_userBookings.isEmpty) return const Center(child: Text('У вас пока нет активных броней', style: TextStyle(color: Colors.grey)));
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _userBookings.length,
      itemBuilder: (context, index) {
        final booking = _userBookings[index];
        final isPaid = (booking['status']?.toString() ?? '') == 'Оплачено';
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.sports_tennis_rounded, color: AppTheme.primaryColor),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(booking['court']?.toString() ?? 'Корт', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(booking['date']?.toString() ?? '', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isPaid ? Colors.green : Colors.orange).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(isPaid ? 'ОПЛАЧЕНО' : 'ОЖИДАЕТ', style: TextStyle(color: isPaid ? Colors.green : Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const Divider(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(booking['price']?.toString() ?? '0 ₸', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.primaryColor)),
                  TextButton(
                    onPressed: () => _cancelBooking(index),
                    child: const Text('Отменить', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDateSelector() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _dates.length,
        itemBuilder: (context, index) {
          final date = _dates[index];
          final isSelected = index == _selectedDateIndex;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return GestureDetector(
            onTap: () => setState(() => _selectedDateIndex = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 65,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? AppTheme.primaryColor : Colors.grey.withOpacity(0.2)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(date.day.toString(), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87))),
                  Text(_months[date.month - 1].substring(0, 3), style: TextStyle(fontSize: 11, color: isSelected ? Colors.white70 : Colors.grey)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: _filters.map((f) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(f),
            selected: _selectedFilter == f,
            onSelected: (s) => setState(() => _selectedFilter = f),
            selectedColor: AppTheme.accentColor,
            showCheckmark: false,
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildCourtCard(Map<String, dynamic> court) {
    bool isAvailable = (court['status']?.toString() ?? '') == 'free';
    final String price = (court['basePrice'] ?? court['price'] ?? '0 ₸').toString();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Image.network(
                court['image']?.toString() ?? '',
                height: 160, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(height: 160, color: Colors.grey[200], child: const Icon(Icons.image_not_supported, color: Colors.grey))
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(court['name']?.toString() ?? 'Корт', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                    Text(price, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.primaryColor)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.layers_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 5),
                    Text(court['type']?.toString() ?? '', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    const Spacer(),
                    if (isAvailable)
                      ElevatedButton(
                          onPressed: () => _showTimePicker(court),
                          style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              minimumSize: const Size(0, 36)
                          ),
                          child: const Text('Выбрать', style: TextStyle(fontSize: 13))
                      )
                    else
                      Text('ЗАНЯТО', style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}