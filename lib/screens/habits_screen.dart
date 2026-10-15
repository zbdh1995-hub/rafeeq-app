import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/app_theme.dart';
import '../services/app_state.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  final appState = AppState.instance;
  final List<String> _weekDays = ['سبت', 'أحد', 'اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة'];

  void _addHabitDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text(
          'إضافة عادة يومية جديدة ✨',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'مثال: شرب 3 لتر مياه / تمرين'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                setState(() {
                  appState.habits.add({
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'title': ctrl.text.trim(),
                    'days': [false, false, false, false, false, false, false],
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        // حساب عدد الأهداف المنجزة في كل يوم من أيام الأسبوع للرسم البياني
        final List<int> dailyCounts = List.filled(7, 0);
        int totalChecked = 0;
        for (var h in appState.habits) {
          final days = List<bool>.from(h['days']);
          for (int i = 0; i < 7; i++) {
            if (days[i]) {
              dailyCounts[i]++;
              totalChecked++;
            }
          }
        }
        final int maxPossible = (appState.habits.length * 7).clamp(1, 999);
        final int overallPercent = ((totalChecked / maxPossible) * 100).round();

        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppTheme.primary,
            onPressed: _addHabitDialog,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'إضافة عادة جديدة',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. كارت الرسم البياني الأسبوعي لسلسلة الالتزام
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '📊 مؤشر الإنجاز الأسبوعي للعادات',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.accent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$overallPercent% مكتمل',
                                style: const TextStyle(
                                  color: AppTheme.accent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 170,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: (appState.habits.length + 1).toDouble(),
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (val, meta) {
                                      final idx = val.toInt();
                                      if (idx < 0 || idx >= _weekDays.length) return const SizedBox();
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          _weekDays[idx],
                                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              barGroups: List.generate(7, (i) {
                                return BarChartGroupData(
                                  x: i,
                                  barRods: [
                                    BarChartRodData(
                                      toY: dailyCounts[i].toDouble(),
                                      color: dailyCounts[i] > 0 ? AppTheme.accent : Colors.white12,
                                      width: 18,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 2. جدول العادات الأسبوعي (إضافة / حذف / تعليم)
                ...appState.habits.asMap().entries.map((entry) {
                  final hIdx = entry.key;
                  final habit = entry.value;
                  final days = List<bool>.from(habit['days']);
                  final doneCount = days.where((d) => d).length;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  habit['title'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                              Text(
                                '🔥 $doneCount / 7 أيام',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.orangeAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() => appState.habits.removeAt(hIdx));
                                  appState.saveData();
                                },
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(7, (dIdx) {
                              final isChecked = days[dIdx];
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    habit['days'][dIdx] = !isChecked;
                                  });
                                  appState.saveData();
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: 40,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isChecked
                                        ? AppTheme.accent.withValues(alpha: 0.25)
                                        : Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isChecked ? AppTheme.accent : Colors.white12,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        _weekDays[dIdx],
                                        style: const TextStyle(fontSize: 10, color: Colors.white60),
                                      ),
                                      const SizedBox(height: 4),
                                      Icon(
                                        isChecked ? Icons.check_circle : Icons.circle_outlined,
                                        size: 18,
                                        color: isChecked ? AppTheme.accent : Colors.white30,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}