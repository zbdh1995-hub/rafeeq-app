import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfrx/pdfrx.dart';
import '../core/app_theme.dart';
import '../services/app_state.dart';
import 'lecture_reader_screen.dart';

class SubjectsScreen extends StatefulWidget {
  const SubjectsScreen({super.key});

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen> {
  final appState = AppState.instance;

  void _addSubjectDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text('إضافة مادة دراسية جديدة 🎓', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'مثال: Oral Surgery / Orthodontics'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                setState(() {
                  appState.subjects.add({
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'name': ctrl.text.trim(),
                    'lectures': [],
                  });
                });
                appState.saveData();
                Navigator.pop(ctx);
              }
            },
            child: const Text('إضافة المادة'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadLecturePdf(Map<String, dynamic> subject) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final fileName = result.files.single.name.replaceAll('.pdf', '');
      int pagesCount = 10;

      try {
        final doc = await PdfDocument.openFile(path);
        pagesCount = doc.pages.length;
        await doc.dispose();
      } catch (_) {}

      setState(() {
        (subject['lectures'] as List).add({
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'title': fileName,
          'pdfPath': path,
          'totalPages': pagesCount,
          'pageStatuses': <String, String>{},
        });
      });
      appState.saveData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppTheme.primary,
            onPressed: _addSubjectDialog,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('إضافة مادة جديدة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          body: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: appState.subjects.length,
            itemBuilder: (context, idx) {
              final sub = appState.subjects[idx];
              final lectures = sub['lectures'] as List;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // رأس المادة (اسم المادة + زر رفع PDF + زر حذف المادة)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.folder_special, color: Colors.indigoAccent, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(sub['name'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                                      Text('${lectures.length} محاضرات مرفوعة', style: const TextStyle(fontSize: 11, color: Colors.white54)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onPressed: () => _uploadLecturePdf(sub),
                            icon: const Icon(Icons.upload_file, size: 16),
                            label: const Text('رفع PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() => appState.subjects.removeAt(idx));
                              appState.saveData();
                            },
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      if (lectures.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'لا توجد محاضرات في هذه المادة بعد. اضغط "رفع PDF" لإضافة محاضراتك وفتحها صفحة بصفحة.',
                            style: TextStyle(fontSize: 12, color: Colors.white54),
                          ),
                        )
                      else
                        ...lectures.asMap().entries.map((entry) {
                          final lIdx = entry.key;
                          final lec = entry.value as Map<String, dynamic>;
                          final int totalPages = lec['totalPages'] ?? 1;
                          final statuses = Map<String, dynamic>.from(lec['pageStatuses'] ?? {});
                          final int goodPages = statuses.values.where((v) => v == 'good').length;
                          final int hardPages = statuses.values.where((v) => v == 'hard' || v == 'review').length;
                          final double progress = totalPages > 0 ? (goodPages / totalPages) : 0;

                          return InkWell(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LectureReaderScreen(subject: sub, lecture: lec),
                                ),
                              );
                              setState(() {});
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 20),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                lec['title'] ?? '',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '${(progress * 100).round()}% مكتمل',
                                        style: const TextStyle(fontSize: 11, color: AppTheme.accent, fontWeight: FontWeight.bold),
                                      ),
                                      IconButton(
                                        onPressed: () {
                                          setState(() => lectures.removeAt(lIdx));
                                          appState.saveData();
                                        },
                                        icon: const Icon(Icons.close, size: 16, color: Colors.white38),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: Colors.white10,
                                    color: AppTheme.accent,
                                    minHeight: 6,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('📄 $totalPages صفحات (فهمت: $goodPages)', style: const TextStyle(fontSize: 11, color: Colors.white60)),
                                      if (hardPages > 0)
                                        Text('⚠️ $hardPages صفحات تحتاج مراجعة/شرح', style: const TextStyle(fontSize: 11, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
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
          ),
        );
      },
    );
  }
}