import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  static final AppState instance = AppState._internal();
  AppState._internal();

  // 1. تظبيط اليوم
  String wakeTime = "07:30";
  String sleepTime = "23:30";
  double studyHours = 4.0;
  double playHours = 2.0;
  String dailyNote = "مراجعة محاضرة الـ Ortho وتلخيص النقاط المهمة";
  String? scheduleImagePath;

  // 2. الصلوات الخمس
  Map<String, bool> prayers = {
    'الفجر': false,
    'الظهر': false,
    'العصر': false,
    'المغرب': false,
    'العشاء': false,
  };

  // 3. الجدول الدراسي الأسبوعي
  List<Map<String, String>> timetable = [
    {'id': '1', 'day': 'الثلاثاء', 'subject': 'Fixed 5 (سكشن)', 'time': '09:00 ص - 11:00 ص'},
    {'id': '2', 'day': 'الأربعاء', 'subject': 'Endo 4 (محاضرة)', 'time': '08:00 ص - 09:00 ص'},
  ];

  // 4. المواد الدراسية والمحاضرات
  List<Map<String, dynamic>> subjects = [
    {
      'id': 'sub1',
      'name': 'Orthodontics 1',
      'lectures': [
        {
          'id': 'lec1',
          'title': 'Pubertal Growth Spurt & Mandibular Growth',
          'pdfPath': null,
          'totalPages': 5,
          'pageStatuses': {'1': 'good', '2': 'review', '3': 'hard'}, // good, review, hard
        }
      ]
    },
    {
      'id': 'sub2',
      'name': 'Endodontics 4',
      'lectures': []
    },
    {
      'id': 'sub3',
      'name': 'Fixed Prosthodontics 5',
      'lectures': []
    },
  ];

  // 5. الكتب والورد اليومي
  List<Map<String, dynamic>> books = [
    {
      'id': 'b1',
      'title': 'العادات الذرية (Atomic Habits)',
      'totalPages': 300,
      'currentPage': 40,
      'dailyQuota': 15,
      'pdfPath': null,
    }
  ];

  // 6. العادات الأسبوعية (السبت = 0 ... الجمعة = 6)
  List<Map<String, dynamic>> habits = [
    {'id': 'h1', 'title': 'الصلوات الخمس في وقتها 🕌', 'days': [true, true, false, false, false, false, false]},
    {'id': 'h2', 'title': 'مذاكرة محاضرات اليوم 🎓', 'days': [true, false, false, false, false, false, false]},
    {'id': 'h3', 'title': 'قراءة الورد اليومي 📖', 'days': [true, true, false, false, false, false, false]},
  ];

  String geminiApiKey = "";

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    wakeTime = prefs.getString('wakeTime') ?? wakeTime;
    sleepTime = prefs.getString('sleepTime') ?? sleepTime;
    studyHours = prefs.getDouble('studyHours') ?? studyHours;
    playHours = prefs.getDouble('playHours') ?? playHours;
    dailyNote = prefs.getString('dailyNote') ?? dailyNote;
    scheduleImagePath = prefs.getString('scheduleImagePath');
    geminiApiKey = prefs.getString('geminiApiKey') ?? "";

    if (prefs.containsKey('prayers')) {
      prayers = Map<String, bool>.from(jsonDecode(prefs.getString('prayers')!));
    }
    if (prefs.containsKey('timetable')) {
      timetable = List<Map<String, String>>.from(
        (jsonDecode(prefs.getString('timetable')!) as List).map((e) => Map<String, String>.from(e)),
      );
    }
    if (prefs.containsKey('subjects')) {
      subjects = List<Map<String, dynamic>>.from(jsonDecode(prefs.getString('subjects')!));
    }
    if (prefs.containsKey('books')) {
      books = List<Map<String, dynamic>>.from(jsonDecode(prefs.getString('books')!));
    }
    if (prefs.containsKey('habits')) {
      habits = List<Map<String, dynamic>>.from(jsonDecode(prefs.getString('habits')!));
    }
    notifyListeners();
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wakeTime', wakeTime);
    await prefs.setString('sleepTime', sleepTime);
    await prefs.setDouble('studyHours', studyHours);
    await prefs.setDouble('playHours', playHours);
    await prefs.setString('dailyNote', dailyNote);
    if (scheduleImagePath != null) {
      await prefs.setString('scheduleImagePath', scheduleImagePath!);
    }
    await prefs.setString('geminiApiKey', geminiApiKey);
    await prefs.setString('prayers', jsonEncode(prayers));
    await prefs.setString('timetable', jsonEncode(timetable));
    await prefs.setString('subjects', jsonEncode(subjects));
    await prefs.setString('books', jsonEncode(books));
    await prefs.setString('habits', jsonEncode(habits));
    notifyListeners();
  }

  // استخراج أهم محاضرة مطلوبة للمذاكرة اليوم تلقائياً
  String get todayStudyRecommendation {
    for (var sub in subjects) {
      final lecs = sub['lectures'] as List;
      for (var lec in lecs) {
        final statuses = Map<String, dynamic>.from(lec['pageStatuses'] ?? {});
        final hardPages = statuses.entries.where((e) => e.value == 'hard' || e.value == 'review').length;
        if (hardPages > 0) {
          return "${sub['name']}: ${lec['title']} ($hardPages صفحات تحتاج مراجعة)";
        }
      }
      if (lecs.isNotEmpty) {
        return "${sub['name']}: ${lecs.first['title']}";
      }
    }
    return "أضف محاضراتك في قسم موادي ليحدد النظام خطتك";
  }

  // استخراج ورد القراءة اليومي تلقائياً
  String get todayReadingRecommendation {
    if (books.isEmpty) return "أضف كتاباً في قسم كتبي لتبدأ القراءة";
    final b = books.first;
    final int current = b['currentPage'] ?? 0;
    final int quota = b['dailyQuota'] ?? 15;
    final int total = b['totalPages'] ?? 200;
    final int target = (current + quota) > total ? total : (current + quota);
    return "${b['title']}: من صـ ${current + 1} إلى صـ $target ($quota صفحة)";
  }

  void togglePrayer(String name) {
    prayers[name] = !(prayers[name] ?? false);
    // إذا اكتملت الـ 5 صلوات، نعلّم صح تلقائياً في جدول العادات!
    if (prayers.values.every((v) => v == true) && habits.isNotEmpty) {
      int todayIdx = (DateTime.now().weekday + 1) % 7;
      habits[0]['days'][todayIdx] = true;
    }
    saveData();
  }
}