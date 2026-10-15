import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/app_theme.dart';
import '../services/app_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final appState = AppState.instance;
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: appState.dailyNote);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickScheduleImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        appState.scheduleImagePath = picked.path;
      });
      appState.saveData();
    }
  }

  void _showAddScheduleDialog() {
    String selectedDay = 'السبت';
    final subjectCtrl = TextEditingController();
    final timeCtrl = TextEditingController();
    final days = ['السبت', 'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.cardDark,
          title: const Text('إضافة موعد في الجدول 📅', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedDay,
                dropdownColor: AppTheme.cardDark,
                decoration: const InputDecoration(labelText: 'اليوم'),
                items: days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                onChanged: (v) => setDialogState(() => selectedDay = v!),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: subjectCtrl,
                decoration: const InputDecoration(labelText: 'اسم المادة / المحاضرة / السكشن'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: timeCtrl,
                decoration: const InputDecoration(labelText: 'الموعد (مثال: 09:00 ص - 11:00 ص)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                if (subjectCtrl.text.trim().isNotEmpty) {
                  setState(() {
                    appState.timetable.add({
                      'id': DateTime.now().millisecondsSinceEpoch.toString(),
                      'day': selectedDay,
                      'subject': subjectCtrl.text.trim(),
                      'time': timeCtrl.text.trim().isEmpty ? 'غير محدد' : timeCtrl.text.trim(),
                    });
                  });
                  appState.saveData();
                  Navigator.pop(ctx);
                }
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final completedPrayers = appState.prayers.values.where((v) => v).length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. بوصلة اليوم الذكية (المفروض يتذاكر النهارده + ساعات المذاكرة + القراءة)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primary.withValues(alpha: 0.25),
                      const Color(0xFF9333EA).withValues(alpha: 0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.bolt, color: Colors.amberAccent),
                            SizedBox(width: 6),
                            Text('المطلوب منك النهارده باختصار', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '⏱️ ${appState.studyHours.toStringAsFixed(1)} س مذاكرة',
                            style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildSummaryRow(Icons.school, 'المفروض يتذاكر النهارده:', appState.todayStudyRecommendation, Colors.indigoAccent),
                    const SizedBox(height: 10),
                    _buildSummaryRow(Icons.menu_book, 'ورد القراءة اليومي:', appState.todayReadingRecommendation, AppTheme.accent),
                    const SizedBox(height: 10),
                    _buildSummaryRow(
                      Icons.schedule,
                      'خطة يومك:',
                      'صحيان ${appState.wakeTime} | لعب ${appState.playHours.toStringAsFixed(1)} س | نوم ${appState.sleepTime}',
                      Colors.amberAccent,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 2. الصلوات الخمس
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Text('🕌', style: TextStyle(fontSize: 20)),
                              SizedBox(width: 8),
                              Text('الصلوات الخمس اليوم', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Text(
                            '$completedPrayers / 5 مكتمل',
                            style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: appState.prayers.entries.map((entry) {
                          final isDone = entry.value;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => appState.togglePrayer(entry.key),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: isDone
                                      ? AppTheme.accent.withValues(alpha: 0.2)
                                      : Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isDone ? AppTheme.accent : Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      isDone ? Icons.check_circle : Icons.circle_outlined,
                                      color: isDone ? AppTheme.accent : Colors.white38,
                                      size: 22,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      entry.key,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isDone ? Colors.white : Colors.white60,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // 3. تظبيط اليوم (أصحى امتى، أنام امتى، عدد ساعات المذاكرة واللعب، وهبدأ يومي إزاي)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.tune, color: AppTheme.primary),
                          SizedBox(width: 8),
                          Text('تظبيط يومي ومواعيدي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _noteController,
                        onChanged: (val) {
                          appState.dailyNote = val;
                          appState.saveData();
                        },
                        decoration: InputDecoration(
                          labelText: 'هبدأ يومي إزاي؟ / أهم هدف النهارده',
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.04),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTimeButton(
                              label: '☀️ بصحى الساعة',
                              value: appState.wakeTime,
                              onTap: () async {
                                final t = await showTimePicker(
                                  context: context,
                                  initialTime: const TimeOfDay(hour: 7, minute: 30),
                                );
                                if (t != null) {
                                  setState(() => appState.wakeTime = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
                                  appState.saveData();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildTimeButton(
                              label: '😴 بنام الساعة',
                              value: appState.sleepTime,
                              onTap: () async {
                                final t = await showTimePicker(
                                  context: context,
                                  initialTime: const TimeOfDay(hour: 23, minute: 30),
                                );
                                if (t != null) {
                                  setState(() => appState.sleepTime = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
                                  appState.saveData();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('📚 عدد ساعات المذاكرة اليوم:', style: TextStyle(fontSize: 13)),
                          Text('${appState.studyHours.toStringAsFixed(1)} ساعات', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                        ],
                      ),
                      Slider(
                        value: appState.studyHours,
                        min: 1,
                        max: 12,
                        divisions: 22,
                        activeColor: AppTheme.primary,
                        onChanged: (v) {
                          setState(() => appState.studyHours = v);
                          appState.saveData();
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('🎮 وقت اللعب والترفيه اليوم:', style: TextStyle(fontSize: 13)),
                          Text('${appState.playHours.toStringAsFixed(1)} ساعات', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accent)),
                        ],
                      ),
                      Slider(
                        value: appState.playHours,
                        min: 0.5,
                        max: 6,
                        divisions: 11,
                        activeColor: AppTheme.accent,
                        onChanged: (v) {
                          setState(() => appState.playHours = v);
                          appState.saveData();
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // 4. الجدول الدراسي (رفع صورة الجدول + مواعيد المواد)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.calendar_month, color: Colors.amberAccent),
                              SizedBox(width: 8),
                              Text('جدولي الدراسي ومواعيدي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'رفع صورة الجدول',
                                onPressed: _pickScheduleImage,
                                icon: const Icon(Icons.image_outlined, color: Colors.amberAccent),
                              ),
                              IconButton(
                                tooltip: 'إضافة موعد جديد',
                                onPressed: _showAddScheduleDialog,
                                icon: const Icon(Icons.add_circle, color: AppTheme.primary),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (appState.scheduleImagePath != null && File(appState.scheduleImagePath!).existsSync()) ...[
                        const SizedBox(height: 8),
                        Stack(
                          alignment: Alignment.topLeft,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.file(
                                File(appState.scheduleImagePath!),
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() => appState.scheduleImagePath = null);
                                appState.saveData();
                              },
                              icon: const CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.redAccent,
                                child: Icon(Icons.close, size: 16, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (appState.timetable.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('لا توجد مواعيد مضافة بعد. اضغط (+) لإضافة مواعيدك أو ارفع صورة جدولك.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        )
                      else
                        ...appState.timetable.map((item) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primary.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(item['day'] ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigoAccent)),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(item['subject'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                              Text(item['time'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                    onPressed: () {
                                      setState(() => appState.timetable.removeWhere((e) => e['id'] == item['id']));
                                      appState.saveData();
                                    },
                                  ),
                                ],
                              ),
                            )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.white60)),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeButton({required String label, required String value, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}