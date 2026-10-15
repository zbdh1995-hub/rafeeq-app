import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../services/app_state.dart';
import 'home_screen.dart';
import 'subjects_screen.dart';
import 'books_screen.dart';
import 'habits_screen.dart';

class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _currentIndex = 0;

  // الصفحات الأربعة الكاملة للتطبيق
  final List<Widget> _pages = const [
    HomeScreen(),
    SubjectsScreen(),
    BooksScreen(),
    HabitsScreen(),
  ];

  // نافذة إدخال مفتاح Gemini API
  void _showGeminiKeyDialog() {
    final ctrl = TextEditingController(text: AppState.instance.geminiApiKey);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Row(
          children: [
            Icon(Icons.key, color: Colors.amberAccent),
            SizedBox(width: 8),
            Text(
              'إعداد مفتاح Gemini AI',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ضع مفتاح Gemini API المجاني الخاص بك لتفعيل الشرح الذكي للصور والسلايدات بالصوت:',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: InputDecoration(
                hintText: 'AIzaSy...',
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              AppState.instance.geminiApiKey = ctrl.text.trim();
              AppState.instance.saveData();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم حفظ مفتاح Gemini بنجاح! ✅')),
              );
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, Color(0xFF9333EA)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'رَفيق AI',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                Text(
                  'نظام حياتي ودراستي الذكي',
                  style: TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'مفتاح Gemini AI',
            onPressed: _showGeminiKeyDialog,
            icon: const Icon(
              Icons.vpn_key_outlined,
              color: Colors.amberAccent,
              size: 20,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Text(
                  '🔥 نشط',
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppTheme.cardDark,
        indicatorColor: AppTheme.primary.withValues(alpha: 0.25),
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.wb_sunny_outlined),
            selectedIcon: Icon(Icons.wb_sunny, color: AppTheme.primary),
            label: 'يومي والصلوات',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school, color: AppTheme.primary),
            label: 'موادي ومحاضراتي',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book, color: AppTheme.primary),
            label: 'كتبي وقراءتي',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart, color: AppTheme.primary),
            label: 'العادات والتقدم',
          ),
        ],
      ),
    );
  }
}