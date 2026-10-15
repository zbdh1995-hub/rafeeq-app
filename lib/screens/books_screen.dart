import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:pdfrx/pdfrx.dart';
import '../core/app_theme.dart';
import '../services/app_state.dart';

class BooksScreen extends StatefulWidget {
  const BooksScreen({super.key});

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  final appState = AppState.instance;
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];

  // البحث التلقائي عن الكتب من Google Books API
  Future<void> _searchGoogleBooks(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    try {
      final url = Uri.parse(
        'https://www.googleapis.com/books/v1/volumes?q=${Uri.encodeComponent(query)}&maxResults=5',
      );
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final items = (data['items'] as List?) ?? [];
        setState(() {
          _searchResults = items.map((item) {
            final info = item['volumeInfo'] ?? {};
            return {
              'title': info['title'] ?? 'كتاب بدون عنوان',
              'authors': ((info['authors'] as List?) ?? ['مؤلف غير معروف']).join('، '),
              'pageCount': (info['pageCount'] as int?) ?? 220,
            };
          }).toList();
        });
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isSearching = false);
    }
  }

  // إضافة كتاب يدوياً أو رفع PDF
  void _showAddBookDialog({String? initialTitle, int? initialPages}) {
    final titleCtrl = TextEditingController(text: initialTitle ?? '');
    final pagesCtrl = TextEditingController(text: (initialPages ?? 250).toString());
    final quotaCtrl = TextEditingController(text: '15');
    String? pickedPdfPath;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.cardDark,
          title: const Text(
            'إضافة كتاب جديد للمكتبة 📖',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'اسم الكتاب'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: pagesCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'إجمالي عدد الصفحات'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: quotaCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'عايز تقرأ كام صفحة في اليوم؟'),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf'],
                    );
                    if (result != null && result.files.single.path != null) {
                      final path = result.files.single.path!;
                      int count = int.tryParse(pagesCtrl.text) ?? 250;
                      try {
                        final doc = await PdfDocument.openFile(path);
                        count = doc.pages.length;
                        await doc.dispose();
                      } catch (_) {}
                      setDialogState(() {
                        pickedPdfPath = path;
                        pagesCtrl.text = count.toString();
                        if (titleCtrl.text.trim().isEmpty) {
                          titleCtrl.text = result.files.single.name.replaceAll('.pdf', '');
                        }
                      });
                    }
                  },
                  icon: const Icon(Icons.upload_file),
                  label: Text(pickedPdfPath == null ? 'رفع ملف PDF للكتاب (اختياري)' : 'تم اختيار ملف PDF ✅'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.trim().isNotEmpty) {
                  setState(() {
                    appState.books.add({
                      'id': DateTime.now().millisecondsSinceEpoch.toString(),
                      'title': titleCtrl.text.trim(),
                      'totalPages': int.tryParse(pagesCtrl.text) ?? 250,
                      'currentPage': 0,
                      'dailyQuota': int.tryParse(quotaCtrl.text) ?? 15,
                      'pdfPath': pickedPdfPath,
                    });
                    _searchResults.clear();
                    _searchCtrl.clear();
                  });
                  appState.saveData();
                  Navigator.pop(ctx);
                }
              },
              child: const Text('إضافة الكتاب'),
            ),
          ],
        ),
      ),
    );
  }

  // تسجيل الصفحة التي وصلت إليها والترحيل التلقائي لليوم التالي
  void _showLogReadingDialog(Map<String, dynamic> book) {
    final int current = book['currentPage'] ?? 0;
    final int quota = book['dailyQuota'] ?? 15;
    final int total = book['totalPages'] ?? 200;
    final int target = (current + quota) > total ? total : (current + quota);

    final pageCtrl = TextEditingController(text: target.toString());
    final quotaCtrl = TextEditingController(text: quota.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text(
          'تسجيل قراءة اليوم والترحيل الذكي 🔄',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'المفروض تقرأ النهارده من صـ ${current + 1} إلى صـ $target.\nلو قرأت أقل أو أكثر، اكتب وصلت لصفحة كام والنظام هيبدأ معاك بكرة من الصفحة اللي بعدها أوتوماتيك!',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pageCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'وصلت لصفحة رقم كام النهارده؟'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: quotaCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'تعديل كمية الصفحات اليومية (الورد اليومي)'),
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
              final int newPage = (int.tryParse(pageCtrl.text) ?? current).clamp(0, total);
              final int newQuota = (int.tryParse(quotaCtrl.text) ?? quota).clamp(1, 500);
              setState(() {
                book['currentPage'] = newPage;
                book['dailyQuota'] = newQuota;
                // تعليم عادة القراءة اليومية كمنجزة تلقائياً
                if (appState.habits.length >= 3) {
                  int todayIdx = (DateTime.now().weekday + 1) % 7;
                  appState.habits[2]['days'][todayIdx] = true;
                }
              });
              appState.saveData();
              Navigator.pop(ctx);
            },
            child: const Text('حفظ وترحيل للغد ✅'),
          ),
        ],
      ),
    );
  }

  // فتح ملف PDF للكتاب صفحة بصفحة
  void _openBookPdfReader(Map<String, dynamic> book) async {
    final path = book['pdfPath'] as String?;
    if (path == null || path.isEmpty) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          book['pdfPath'] = result.files.single.path!;
        });
        appState.saveData();
      } else {
        return;
      }
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _BookPdfViewerPage(book: book),
      ),
    ).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppTheme.primary,
            onPressed: () => _showAddBookDialog(),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'إضافة كتاب / رفع PDF',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. شريط البحث الذكي عن الكتب
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🔍 ابحث عن أي كتاب ليقترح النظام عدد صفحاته ويقسمه لك:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                onSubmitted: _searchGoogleBooks,
                                decoration: InputDecoration(
                                  hintText: 'اكتب اسم الكتاب بالعربي أو الإنجليزي...',
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.05),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                              onPressed: () => _searchGoogleBooks(_searchCtrl.text),
                              child: _isSearching
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('بحث'),
                            ),
                          ],
                        ),
                        if (_searchResults.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ..._searchResults.map(
                            (res) => ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                              leading: const Icon(Icons.book, color: Colors.amberAccent),
                              title: Text(
                                res['title'],
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '${res['authors']} • ${res['pageCount']} صفحة',
                                style: const TextStyle(fontSize: 11, color: Colors.white54),
                              ),
                              trailing: OutlinedButton(
                                onPressed: () => _showAddBookDialog(
                                  initialTitle: res['title'],
                                  initialPages: res['pageCount'],
                                ),
                                child: const Text('إضافة', style: TextStyle(fontSize: 11)),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 2. قائمة كتبي الحالية والورد اليومي
                ...appState.books.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final book = entry.value;
                  final int current = book['currentPage'] ?? 0;
                  final int total = book['totalPages'] ?? 200;
                  final int quota = book['dailyQuota'] ?? 15;
                  final int startPage = current + 1 > total ? total : current + 1;
                  final int endPage = (current + quota) > total ? total : (current + quota);
                  final int remainingPages = (total - current).clamp(0, total);
                  final int daysLeft = (remainingPages / quota).ceil();
                  final double progress = total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accent.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.menu_book, color: AppTheme.accent, size: 22),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            book['title'] ?? '',
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                                          ),
                                          Text(
                                            'قرأت $current من $total صفحة • متبقي $daysLeft أيام',
                                            style: const TextStyle(fontSize: 11, color: Colors.white54),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() => appState.books.removeAt(idx));
                                  appState.saveData();
                                },
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.white10,
                            color: AppTheme.accent,
                            minHeight: 7,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          const SizedBox(height: 12),

                          // صندوق الورد اليومي والترحيل التلقائي
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '🎯 ورد القراءة المطلوب منك اليوم:',
                                        style: TextStyle(fontSize: 11, color: Colors.white70),
                                      ),
                                      Text(
                                        current >= total
                                            ? '🎉 ختمت الكتاب بالكامل! عاش جداً'
                                            : 'من صـ $startPage إلى صـ $endPage ($quota صفحة اليوم)',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.amberAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.accent,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => _showLogReadingDialog(book),
                                  icon: const Icon(Icons.check_circle_outline, size: 18),
                                  label: const Text(
                                    'وصلت لصفحة كام؟',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _openBookPdfReader(book),
                                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                                  label: Text(
                                    book['pdfPath'] != null ? 'فتح الكتاب PDF' : 'ربط ملف PDF',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
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

// قارئ كتاب PDF مدمج يحفظ الصفحة الحالية تلقائياً
class _BookPdfViewerPage extends StatefulWidget {
  final Map<String, dynamic> book;
  const _BookPdfViewerPage({required this.book});

  @override
  State<_BookPdfViewerPage> createState() => _BookPdfViewerPageState();
}

class _BookPdfViewerPageState extends State<_BookPdfViewerPage> {
  PdfDocument? _doc;
  int _page = 1;
  int _total = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final path = widget.book['pdfPath'] as String?;
    if (path != null) {
      final d = await PdfDocument.openFile(path);
      setState(() {
        _doc = d;
        _total = d.pages.length;
        _page = ((widget.book['currentPage'] ?? 0) as int).clamp(1, _total);
        widget.book['totalPages'] = _total;
      });
    }
  }

  void _updatePage(int newPage) {
    setState(() {
      _page = newPage.clamp(1, _total);
      widget.book['currentPage'] = _page;
    });
    AppState.instance.saveData();
  }

  @override
  void dispose() {
    _doc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.book['title']} (صـ $_page / $_total)', style: const TextStyle(fontSize: 14)),
      ),
      body: Column(
        children: [
          Expanded(
            child: _doc == null
                ? const Center(child: CircularProgressIndicator())
                : InteractiveViewer(
                    child: Center(
                      child: PdfPageView(document: _doc, pageNumber: _page),
                    ),
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: AppTheme.cardDark,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _page > 1 ? () => _updatePage(_page - 1) : null,
                  child: const Text('السابقة'),
                ),
                Text('تم الحفظ عند صـ $_page ✅', style: const TextStyle(fontWeight: FontWeight.bold)),
                ElevatedButton(
                  onPressed: _page < _total ? () => _updatePage(_page + 1) : null,
                  child: const Text('التالية'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}