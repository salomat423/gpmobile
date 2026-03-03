import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/di/app_scope.dart';
import '../core/config/app_config.dart';
import '../theme/app_theme.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late Future<List<Map<String, dynamic>>> _courtsFuture;
  late Future<List<Map<String, dynamic>>> _bookingsFuture;
  late Future<List<Map<String, dynamic>>> _membershipsFuture;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _reloadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _reloadAll() {
    _courtsFuture = AppScope.instance.bookingRepository.courts();
    _bookingsFuture = AppScope.instance.bookingRepository.myBookings();
    _membershipsFuture = AppScope.instance.membershipRepository.myMemberships();
  }

  Future<void> _openCourtSheet(Map<String, dynamic> court) async {
    final courtId = (court['id'] as num?)?.toInt();
    if (courtId == null) return;

    final name = (court['name'] ?? 'Корт').toString();
    final courtType = (court['court_type'] ?? '').toString();
    final price = (court['price_per_hour'] ?? '—').toString();
    final description = (court['description'] ?? '').toString();
    final imageUrl = court['image']?.toString() ?? court['image_url']?.toString();
    final isActive = court['is_active'] == true;

    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay(hour: DateTime.now().hour + 1, minute: 0);
    int duration = 60;
    int? selectedCoachId;
    String paymentMethod = 'KASPI';
    String promoCode = '';

    Future<List<Map<String, dynamic>>> loadCoaches() {
      final slot = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      ).toUtc();
      return AppScope.instance.bookingRepository.availableCoaches(
        dateTimeIso: slot.toIso8601String(),
        duration: duration,
      );
    }

    Future<List<Map<String, dynamic>>> coachesFuture = loadCoaches();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return DraggableScrollableSheet(
            initialChildSize: 0.88,
            maxChildSize: 0.92,
            minChildSize: 0.5,
            builder: (ctx, scrollCtrl) => Container(
              decoration: BoxDecoration(
                color: Theme.of(ctx).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: ListView(
                controller: scrollCtrl,
                padding: EdgeInsets.zero,
                children: [
                  // --- Photo ---
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    child: SizedBox(
                      height: 220,
                      width: double.infinity,
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl.startsWith('http') ? imageUrl : '${AppConfig.baseUrl}$imageUrl',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _courtPlaceholder(isDark),
                            )
                          : _courtPlaceholder(isDark),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isActive ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isActive ? 'Доступен' : 'Недоступен',
                                style: TextStyle(color: isActive ? Colors.green : Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (courtType.isNotEmpty)
                          Text(courtType, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(description, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                        ],
                        const SizedBox(height: 8),
                        Text('$price тг/час', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.primaryColor)),

                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 12),
                        const Text('Выберите дату и время', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: _datePickerTile(
                                context: ctx,
                                icon: Icons.calendar_today_rounded,
                                label: _formatDate(selectedDate),
                                onTap: () => _showModernDatePicker(
                                  ctx,
                                  selectedDate,
                                  (d) => setSheetState(() {
                                    selectedDate = d;
                                    selectedCoachId = null;
                                    coachesFuture = loadCoaches();
                                  }),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _datePickerTile(
                                context: ctx,
                                icon: Icons.schedule_rounded,
                                label: '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                                onTap: () => _showModernTimePicker(
                                  ctx,
                                  selectedTime,
                                  (t) => setSheetState(() {
                                    selectedTime = t;
                                    selectedCoachId = null;
                                    coachesFuture = loadCoaches();
                                  }),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text('Длительность', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('60 мин'),
                              selected: duration == 60,
                              onSelected: (_) => setSheetState(() {
                                duration = 60;
                                selectedCoachId = null;
                                coachesFuture = loadCoaches();
                              }),
                            ),
                            ChoiceChip(
                              label: const Text('90 мин'),
                              selected: duration == 90,
                              onSelected: (_) => setSheetState(() {
                                duration = 90;
                                selectedCoachId = null;
                                coachesFuture = loadCoaches();
                              }),
                            ),
                            ChoiceChip(
                              label: const Text('120 мин'),
                              selected: duration == 120,
                              onSelected: (_) => setSheetState(() {
                                duration = 120;
                                selectedCoachId = null;
                                coachesFuture = loadCoaches();
                              }),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: coachesFuture,
                          builder: (ctx, snap) {
                            if (snap.connectionState == ConnectionState.waiting) {
                              return const LinearProgressIndicator();
                            }
                            if (snap.hasError) {
                              return const Text(
                                'Не удалось загрузить тренеров для этого слота',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              );
                            }
                            final coaches = snap.data ?? const [];
                            if (coaches.isEmpty) {
                              return const Text(
                                'Свободных тренеров нет (можно бронировать без тренера)',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              );
                            }
                            return DropdownButtonFormField<int>(
                              initialValue: selectedCoachId,
                              decoration: InputDecoration(
                                labelText: 'Тренер (опционально)',
                                filled: true,
                                fillColor: Colors.grey.withValues(alpha: 0.08),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              items: coaches.map((c) {
                                final id = (c['id'] as num?)?.toInt();
                                if (id == null) return null;
                                final name = (c['full_name'] ?? c['username'] ?? 'Тренер').toString();
                                final price = (c['coach_price'] ?? '').toString();
                                final label = price.isEmpty || price == '0.00' ? name : '$name • $price тг';
                                return DropdownMenuItem<int>(
                                  value: id,
                                  child: Text(label),
                                );
                              }).whereType<DropdownMenuItem<int>>().toList(),
                              onChanged: (v) => setSheetState(() => selectedCoachId = v),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                textCapitalization: TextCapitalization.characters,
                                onChanged: (v) => promoCode = v,
                                decoration: InputDecoration(
                                  labelText: 'Промокод (опционально)',
                                  filled: true,
                                  fillColor: Colors.grey.withValues(alpha: 0.08),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () async {
                                final code = promoCode.trim();
                                if (code.isEmpty) return;
                                try {
                                  final result = await AppScope.instance.secondaryRepository.validatePromo(code);
                                  if (!ctx.mounted) return;
                                  final valid = result['valid'] == true;
                                  final message = valid
                                      ? 'Промокод активен: ${result['title'] ?? code}'
                                      : (result['error'] ?? 'Промокод недействителен').toString();
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(message),
                                      backgroundColor: valid ? Colors.green : Colors.redAccent,
                                    ),
                                  );
                                } catch (e) {
                                  if (!ctx.mounted) return;
                                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString())));
                                }
                              },
                              child: const Text('Проверить'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: paymentMethod,
                          decoration: InputDecoration(
                            labelText: 'Способ оплаты',
                            filled: true,
                            fillColor: Colors.grey.withValues(alpha: 0.08),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'KASPI', child: Text('Kaspi')),
                            DropdownMenuItem(value: 'CARD', child: Text('Карта')),
                            DropdownMenuItem(value: 'CASH', child: Text('Наличные')),
                          ],
                          onChanged: (v) { if (v != null) setSheetState(() => paymentMethod = v); },
                        ),

                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: isActive
                                ? () => _bookCourt(
                                      ctx,
                                      courtId,
                                      selectedDate,
                                      selectedTime,
                                      duration,
                                      paymentMethod,
                                      coachId: selectedCoachId,
                                      promoCode: promoCode.trim(),
                                    )
                                : null,
                            child: const Text('Забронировать', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _bookCourt(
    BuildContext ctx,
    int courtId,
    DateTime date,
    TimeOfDay time,
    int duration,
    String paymentMethod, {
    int? coachId,
    String? promoCode,
  }) async {
    final start = DateTime(date.year, date.month, date.day, time.hour, time.minute).toUtc();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(ctx);
    final payload = <String, dynamic>{
      'court': courtId,
      'start_time': start.toIso8601String(),
      'duration': duration,
      'payment_method': paymentMethod,
    };
    if (coachId != null) payload['coach'] = coachId;
    final promo = (promoCode ?? '').trim();
    if (promo.isNotEmpty) payload['promo_code'] = promo;
    try {
      final availability = await AppScope.instance.bookingRepository.checkAvailability(
        courtId: courtId,
        dateIso: _dateOnlyIso(date),
      );
      if ((availability['is_holiday'] == true)) {
        final reason = (availability['reason'] ?? 'Корт недоступен в выбранную дату').toString();
        throw Exception(reason);
      }
      final busySlots = (availability['busy_slots'] as List?) ?? const [];
      if (_isRequestedSlotBusy(time: time, duration: duration, busySlots: busySlots)) {
        throw Exception('Этот временной слот уже занят. Выберите другое время.');
      }

      final previewPayload = <String, dynamic>{
        'court_id': courtId,
        'start_time': payload['start_time'],
        'duration': duration,
      };
      if (coachId != null) previewPayload['coach_id'] = coachId;
      final preview = await AppScope.instance.bookingRepository.pricePreview(previewPayload);
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Подтвердить бронь'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Сумма: ${preview['total'] ?? '-'} тг'),
              if (preview['discount'] != null) Text('Скидка: ${preview['discount']}'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
            ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Подтвердить')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      final result = await AppScope.instance.bookingRepository.createBooking(payload);
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Бронь создана #${result['id'] ?? ''}')),
      );
      setState(_reloadAll);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  String _dateOnlyIso(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  bool _isRequestedSlotBusy({
    required TimeOfDay time,
    required int duration,
    required List busySlots,
  }) {
    final selectedStart = time.hour * 60 + time.minute;
    final selectedEnd = selectedStart + duration;
    for (final raw in busySlots) {
      if (raw is! Map) continue;
      final slot = Map<String, dynamic>.from(raw);
      final start = _parseSlotMinutes((slot['start'] ?? '').toString());
      final end = _parseSlotMinutes((slot['end'] ?? '').toString());
      if (start == null || end == null) continue;
      if (selectedStart < end && selectedEnd > start) return true;
    }
    return false;
  }

  int? _parseSlotMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  Future<void> _cancelBooking(Map<String, dynamic> booking) async {
    final id = (booking['id'] as num?)?.toInt();
    if (id == null) return;
    try {
      await AppScope.instance.bookingRepository.cancelBooking(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Бронирование отменено')));
      setState(_reloadAll);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _freezeOrUnfreeze(Map<String, dynamic> item) async {
    final id = (item['id'] as num?)?.toInt();
    if (id == null) return;
    final frozen = item['is_frozen'] == true;
    try {
      if (frozen) {
        await AppScope.instance.membershipRepository.unfreeze(id);
      } else {
        await AppScope.instance.membershipRepository.freeze(id);
      }
      if (!mounted) return;
      setState(_reloadAll);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? AppTheme.accentColor : AppTheme.primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Бронирование'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: activeColor,
          indicatorColor: activeColor,
          tabs: const [
            Tab(text: 'Корты'),
            Tab(text: 'Мои брони'),
            Tab(text: 'Абонементы'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildCourtsGrid(),
          _buildMyBookings(),
          _buildMemberships(),
        ],
      ),
    );
  }

  Widget _buildCourtsGrid() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _courtsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return _errorWidget(snapshot.error, () => setState(_reloadAll));
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return const Center(child: Text('Кортов не найдено', style: TextStyle(color: Colors.grey)));
        }
        return RefreshIndicator(
          onRefresh: () async => setState(_reloadAll),
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.78,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) => _buildCourtCard(items[i]),
          ),
        );
      },
    );
  }

  Widget _buildCourtCard(Map<String, dynamic> court) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = (court['name'] ?? 'Корт').toString();
    final courtType = (court['court_type'] ?? '').toString();
    final price = (court['price_per_hour'] ?? '—').toString();
    final imageUrl = court['image']?.toString() ?? court['image_url']?.toString();
    final isActive = court['is_active'] == true;

    return GestureDetector(
      onTap: () => _openCourtSheet(court),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: SizedBox(
                width: double.infinity,
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl.startsWith('http') ? imageUrl : '${AppConfig.baseUrl}$imageUrl',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _courtPlaceholder(isDark),
                      )
                    : _courtPlaceholder(isDark),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (courtType.isNotEmpty) Text(courtType, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$price тг', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.primaryColor)),
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(color: isActive ? Colors.green : Colors.red, shape: BoxShape.circle),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyBookings() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _bookingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return _errorWidget(snapshot.error, () => setState(_reloadAll));
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event_busy, size: 56, color: Colors.grey.withValues(alpha: 0.4)),
                const SizedBox(height: 8),
                const Text('Нет активных бронирований', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => setState(_reloadAll),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final b = items[i];
              final courtName = (b['court_name'] ?? b['court'] ?? '-').toString();
              final startTime = (b['start_time'] ?? '').toString();
              final status = (b['status'] ?? '').toString();
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4, height: 44,
                      decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(courtName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(startTime, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          Text(status, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _cancelBooking(b),
                      child: const Text('Отмена', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMemberships() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _membershipsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return _errorWidget(snapshot.error, () => setState(_reloadAll));
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return Center(
            child: ElevatedButton(
              onPressed: () async {
                final types = await AppScope.instance.membershipRepository.types();
                if (types.isEmpty || !mounted) return;
                final firstType = (types.first['id'] as num?)?.toInt();
                if (firstType == null) return;
                await AppScope.instance.membershipRepository.buy(firstType);
                if (!mounted) return;
                setState(_reloadAll);
              },
              child: const Text('Купить первый доступный абонемент'),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => setState(_reloadAll),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final m = items[i];
              final frozen = m['is_frozen'] == true;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((m['membership_type_name'] ?? m['type_name'] ?? 'Абонемент').toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('До: ${m['end_date'] ?? '-'}  •  Часы: ${m['hours_remaining'] ?? '-'}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _freezeOrUnfreeze(m),
                      child: Text(frozen ? 'Разморозить' : 'Заморозить'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _errorWidget(Object? e, VoidCallback retry) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Ошибка загрузки'),
          const SizedBox(height: 8),
          Text(e.toString(), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: retry, child: const Text('Повторить')),
        ],
      ),
    );
  }
}

Widget _courtPlaceholder(bool isDark) {
  return Container(
    color: isDark ? Colors.grey[800] : Colors.grey[200],
    child: Center(
      child: Icon(Icons.sports_tennis, size: 40, color: isDark ? Colors.white38 : Colors.grey[400]),
    ),
  );
}

Widget _datePickerTile({
  required BuildContext context,
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
          Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Colors.grey.withValues(alpha: 0.6)),
        ],
      ),
    ),
  );
}

String _formatDate(DateTime d) {
  const months = ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

void _showModernDatePicker(BuildContext ctx, DateTime current, ValueChanged<DateTime> onPicked) {
  DateTime temp = current;
  showModalBottomSheet(
    context: ctx,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => Container(
      height: 320,
      decoration: BoxDecoration(
        color: Theme.of(sheetCtx).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Выберите дату', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                TextButton(
                  onPressed: () { onPicked(temp); Navigator.pop(sheetCtx); },
                  child: const Text('Готово', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          ),
          Expanded(
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: current,
              minimumDate: DateTime.now().subtract(const Duration(days: 1)),
              maximumDate: DateTime.now().add(const Duration(days: 60)),
              onDateTimeChanged: (d) => temp = d,
            ),
          ),
        ],
      ),
    ),
  );
}

void _showModernTimePicker(BuildContext ctx, TimeOfDay current, ValueChanged<TimeOfDay> onPicked) {
  DateTime temp = DateTime(2025, 1, 1, current.hour, current.minute);
  showModalBottomSheet(
    context: ctx,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => Container(
      height: 320,
      decoration: BoxDecoration(
        color: Theme.of(sheetCtx).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Выберите время', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                TextButton(
                  onPressed: () { onPicked(TimeOfDay(hour: temp.hour, minute: temp.minute)); Navigator.pop(sheetCtx); },
                  child: const Text('Готово', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          ),
          Expanded(
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              initialDateTime: temp,
              use24hFormat: true,
              minuteInterval: 15,
              onDateTimeChanged: (d) => temp = d,
            ),
          ),
        ],
      ),
    ),
  );
}
