import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:google_generative_ai/google_generative_ai.dart';
import '../core/app_theme.dart';
import '../services/app_state.dart';

class LectureReaderScreen extends StatefulWidget {
  final Map<String, dynamic> subject;
  final Map<String, dynamic> lecture;

  const LectureReaderScreen({
    super.key,
    required this.subject,
    required this.lecture,
  });

  @override
  State<LectureReaderScreen> createState() => _LectureReaderScreenState();
}

class _LectureReaderScreenState extends State<LectureReaderScreen> {
  final appState = AppState.instance;
  PdfDocument? _pdfDoc;
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoadingPdf = true;

  // الصوت والمايكروفون
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isSpeaking = false;
  bool _isListening = false;
  double _speechRate = 0.5; // سرعة طبيعية في فلاتر

  // شات المعلم الذكي
  final List<Map<String, String>> _messages = [];
  final TextEditingController _chatCtrl = TextEditingController();
  bool _isAiLoading = false;

  @override
  void initState() {
    super.initState();
    _initPdf();
    _initVoice();
    _messages.add({
      'role': 'ai',
      'text': 'أهلاً بك! أنا رفيقك الذكي 🤖. اقرأ السلايد براحتك، ولو أي نقطة مش واضحة اضغط "مفهمتش! اشرحلي" أو كلمني بالمايكروفون وهشرحهالك مكس عربي وإنجليزي بالصوت!'
    });
  }

  Future<void> _initPdf() async {
    final path = widget.lecture['pdfPath'] as String?;
    if (path != null && path.isNotEmpty) {
      try {
        final doc = await PdfDocument.openFile(path);
        setState(() {
          _pdfDoc = doc;
          _totalPages = doc.pages.length;
          widget.lecture['totalPages'] = _totalPages;
          _isLoadingPdf = false;
        });
        appState.saveData();
      } catch (e) {
        setState(() {
          _totalPages = widget.lecture['totalPages'] ?? 5;
          _isLoadingPdf = false;
        });
      }
    } else {
      setState(() {
        _totalPages = widget.lecture['totalPages'] ?? 5;
        _isLoadingPdf = false;
      });
    }
  }

  Future<void> _initVoice() async {
    await _tts.setSharedInstance(true);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  // نطق ذكي يفصل العربي عن المصطلحات الإنجليزية عشان مينطقش غلط
  Future<void> _speakSmartBilingual(String text) async {
    await _tts.stop();
    final cleanText = text.replaceAll(RegExp(r'[*#`_~]'), '');
    setState(() => _isSpeaking = true);

    // تقسيم النص لمقاطع عربية وإنجليزية
    final exp = RegExp(r'[A-Za-z0-9][A-Za-z0-9\s\-_.,()/]*[A-Za-z0-9]|[A-Za-z]+');
    int lastIdx = 0;
    final List<Map<String, String>> segments = [];

    for (final match in exp.allMatches(cleanText)) {
      if (match.start > lastIdx) {
        final arPart = cleanText.substring(lastIdx, match.start).trim();
        if (arPart.isNotEmpty) segments.add({'lang': 'ar-EG', 'text': arPart});
      }
      final enPart = match.group(0)!.trim();
      if (enPart.isNotEmpty) segments.add({'lang': 'en-US', 'text': enPart});
      lastIdx = match.end;
    }
    if (lastIdx < cleanText.length) {
      final rem = cleanText.substring(lastIdx).trim();
      if (rem.isNotEmpty) segments.add({'lang': 'ar-EG', 'text': rem});
    }

    await _tts.awaitSpeakCompletion(true);
    for (final seg in segments) {
      if (!_isSpeaking || !mounted) break;
      await _tts.setLanguage(seg['lang']!);
      await _tts.setSpeechRate(_speechRate);
      await _tts.speak(seg['text']!);
    }
    if (mounted) setState(() => _isSpeaking = false);
  }

  Future<void> _stopSpeaking() async {
    await _tts.stop();
    setState(() => _isSpeaking = false);
  }

  // استخراج صورة السلايد الحالية لإرسالها إلى Gemini Vision
  Future<Uint8List?> _captureCurrentSlidePng() async {
    if (_pdfDoc == null) return null;
    try {
      final page = _pdfDoc!.pages[_currentPage - 1];
      final pdfImg = await page.render(
        fullWidth: page.width * 1.5,
        fullHeight: page.height * 1.5,
      );
      if (pdfImg == null) return null;
      final uiImg = await pdfImg.createImage();
      final byteData = await uiImg.toByteData(format: ui.ImageByteFormat.png);
      pdfImg.dispose();
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  // شرح السلايد أو الرد على سؤال الطالب بواسطة Gemini
  Future<void> _askGemini(String userPrompt) async {
    if (userPrompt.trim().isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': userPrompt});
      _isAiLoading = true;
    });

    String reply = '';
    final apiKey = appState.geminiApiKey.trim();

    if (apiKey.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 700));
      reply = 'عشان أشوف صورة السلايد رقم ($_currentPage) وأشرحلك الرسومات والمعادلات اللي فيها بذكاء Gemini، اضغط على أيقونة المفتاح 🔑 في الشاشة الرئيسية وحط مفتاح Gemini API المجاني بتاعك!\n\n'
          '💡 وبشكل عام في **${widget.lecture['title']}** (صفحة $_currentPage): ركز على الـ **Key Concepts** والمصطلحات الإنجليزية الأساسية وقارن بين الـ **Clinical Features** والـ **Mechanism** عشان دي موضع أسئلة MCQ في الامتحان!';
    } else {
      try {
        final model = GenerativeModel(
          model: 'gemini-2.5-flash',
          apiKey: apiKey,
        );

        final slideBytes = await _captureCurrentSlidePng();
        final systemPrompt =
            'أنت معلم جامعي مصري شاطر جداً وودود. اشرح للطالب محتوى هذه السلايد (صفحة $_currentPage من محاضرة ${widget.lecture['title']} في مادة ${widget.subject['name']}) '
            'بأسلوب Mix عربي (عامية مصرية سلسة ومفهومة في النطق) مع الحفاظ على المصطلحات العلمية بالـ English وشرحها ببساطة، واختم بسؤال امتحانات متوقع.\n'
            'سؤال الطالب: $userPrompt';

        final GenerateContentResponse response;
        if (slideBytes != null) {
          response = await model.generateContent([
            Content.multi([
              TextPart(systemPrompt),
              DataPart('image/png', slideBytes),
            ])
          ]);
        } else {
          response = await model.generateContent([Content.text(systemPrompt)]);
        }
        reply = response.text ?? 'لم أتمكن من استخراج الشرح، جرب مرة أخرى.';
      } catch (e) {
        reply = 'حدث خطأ أثناء الاتصال بـ Gemini تأكد من صحة المفتاح أو الاتصال بالإنترنت: $e';
      }
    }

    if (!mounted) return;
    setState(() {
      _messages.add({'role': 'ai', 'text': reply});
      _isAiLoading = false;
    });

    // قراءة الشرح بالصوت تلقائياً
    _speakSmartBilingual(reply);
  }

  // فتح المايكروفون للتحدث مع Gemini
  Future<void> _toggleMic() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        localeId: 'ar_EG',
        onResult: (result) {
          setState(() {
            _chatCtrl.text = result.recognizedWords;
          });
          if (result.finalResult && _chatCtrl.text.trim().isNotEmpty) {
            setState(() => _isListening = false);
            final q = _chatCtrl.text.trim();
            _chatCtrl.clear();
            _askGemini(q);
          }
        },
      );
    }
  }

  void _setPageStatus(String status) {
    final Map<String, dynamic> statuses =
        Map<String, dynamic>.from(widget.lecture['pageStatuses'] ?? {});
    statuses['$_currentPage'] = status;
    setState(() {
      widget.lecture['pageStatuses'] = statuses;
    });
    appState.saveData();

    if (status == 'hard') {
      _openAiTutorSheet(
        autoQuestion: 'أنا مش فاهم السلايد رقم $_currentPage خالص، اشرحهالي بالتفصيل وبسط الـ Terms اللي فيها.',
      );
    } else if (status == 'good' && _currentPage < _totalPages) {
      setState(() => _currentPage++);
    }
  }

  void _openAiTutorSheet({String? autoQuestion}) {
    if (autoQuestion != null) {
      _askGemini(autoQuestion);
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.72,
              child: Column(
                children: [
                  // رأس نافذة المعلم الذكي
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome, color: Colors.amberAccent),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('المعلم الذكي الناطق (Gemini)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                Text('يرى سلايد رقم $_currentPage ويشرح بالصوت', style: const TextStyle(fontSize: 11, color: Colors.white54)),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            if (_isSpeaking)
                              IconButton(
                                tooltip: 'إيقاف الصوت',
                                onPressed: () {
                                  _stopSpeaking();
                                  setSheetState(() {});
                                },
                                icon: const Icon(Icons.stop_circle, color: Colors.redAccent),
                              ),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // أزرار سريعة
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ActionChip(
                            label: const Text('🔊 اشرحلي السلايد دي مكس عربي/إنجليزي', style: TextStyle(fontSize: 11)),
                            onPressed: () async {
                              await _askGemini('اشرحلي كل نقطة في السلايد رقم $_currentPage بالتفصيل الممل بأسلوب مكس عربي وإنجليزي.');
                              setSheetState(() {});
                            },
                          ),
                          const SizedBox(width: 8),
                          ActionChip(
                            label: const Text('🎯 أسئلة MCQ متوقعة على الصفحة', style: TextStyle(fontSize: 11)),
                            onPressed: () async {
                              await _askGemini('طلع لي 3 أسئلة امتحانات MCQ من السلايد رقم $_currentPage بالإجابات والشرح.');
                              setSheetState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // رسائل الشات
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(14),
                      itemCount: _messages.length + (_isAiLoading ? 1 : 0),
                      itemBuilder: (context, idx) {
                        if (idx == _messages.length) {
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child: Row(
                              children: [
                                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                                SizedBox(width: 10),
                                Text('جاري قراءة السلايد وتحضير الشرح الصوتي...', style: TextStyle(fontSize: 12, color: Colors.white60)),
                              ],
                            ),
                          );
                        }
                        final msg = _messages[idx];
                        final isUser = msg['role'] == 'user';
                        return Align(
                          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? AppTheme.primary.withValues(alpha: 0.25)
                                  : Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(msg['text'] ?? '', style: const TextStyle(fontSize: 13, height: 1.5)),
                                if (!isUser) ...[
                                  const SizedBox(height: 6),
                                  InkWell(
                                    onTap: () => _speakSmartBilingual(msg['text'] ?? ''),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.volume_up, size: 15, color: Colors.amberAccent),
                                        SizedBox(width: 4),
                                        Text('استماع للشرح بالصوت', style: TextStyle(fontSize: 11, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // شريط الكتابة والمايكروفون
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.bgDark,
                      border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () async {
                            await _toggleMic();
                            setSheetState(() {});
                          },
                          icon: CircleAvatar(
                            backgroundColor: _isListening ? Colors.redAccent : Colors.white.withValues(alpha: 0.1),
                            child: Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _chatCtrl,
                            decoration: InputDecoration(
                              hintText: 'اسأل في السلايد أو اضغط المايكروفون 🎙️...',
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.05),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () async {
                            final q = _chatCtrl.text.trim();
                            _chatCtrl.clear();
                            setSheetState(() {});
                            await _askGemini(q);
                            setSheetState(() {});
                          },
                          icon: const CircleAvatar(
                            backgroundColor: AppTheme.primary,
                            child: Icon(Icons.send, color: Colors.white, size: 18),
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

  @override
  void dispose() {
    _tts.stop();
    _speech.stop();
    _pdfDoc?.dispose();
    _chatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statuses = Map<String, dynamic>.from(widget.lecture['pageStatuses'] ?? {});
    final currentStatus = statuses['$_currentPage'];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.lecture['title'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            Text('${widget.subject['name']} • صفحة $_currentPage من $_totalPages', style: const TextStyle(fontSize: 11, color: Colors.white54)),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _openAiTutorSheet(),
            icon: const Icon(Icons.record_voice_over, color: Colors.amberAccent, size: 18),
            label: const Text('المعلم الناطق', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. عارض السلايد الحقيقية (PDF Slide Image)
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 12),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: _isLoadingPdf
                    ? const Center(child: CircularProgressIndicator())
                    : (_pdfDoc != null)
                        ? InteractiveViewer(
                            minScale: 1.0,
                            maxScale: 4.0,
                            child: Center(
                              child: PdfPageView(
                                document: _pdfDoc,
                                pageNumber: _currentPage,
                              ),
                            ),
                          )
                        : Container(
                            color: AppTheme.cardDark,
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.picture_as_pdf, size: 64, color: Colors.indigoAccent),
                                  const SizedBox(height: 12),
                                  Text(
                                    'سلايد رقم $_currentPage من محاضرة:\n${widget.lecture['title']}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'هذه محاضرة تجريبية. عند رفع ملف PDF لمحاضرتك ستظهر هنا صورة السلايد الأصلية بكامل رسوماتها ومعادلاتها مع إمكانية التكبير Zoom.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12, color: Colors.white54),
                                  ),
                                ],
                              ),
                            ),
                          ),
              ),
            ),
          ),

          // 2. أزرار تقييم الفهم للصفحة الحالية
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatusBtn(
                    label: '🟢 فهمتها تماماً',
                    isSelected: currentStatus == 'good',
                    color: AppTheme.accent,
                    onTap: () => _setPageStatus('good'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatusBtn(
                    label: '🟡 لسه شوية',
                    isSelected: currentStatus == 'review',
                    color: AppTheme.warning,
                    onTap: () => _setPageStatus('review'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatusBtn(
                    label: '🔴 مفهمتش! اشرحلي',
                    isSelected: currentStatus == 'hard',
                    color: AppTheme.danger,
                    onTap: () => _setPageStatus('hard'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 3. شريط الصفحة السابقة والصفحة التالية
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                  icon: const Icon(Icons.arrow_back_ios, size: 14),
                  label: const Text('الصفحة السابقة'),
                ),
                Text(
                  'صفحة $_currentPage / $_totalPages',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
                ElevatedButton.icon(
                  onPressed: _currentPage < _totalPages ? () => setState(() => _currentPage++) : null,
                  icon: const Icon(Icons.arrow_forward_ios, size: 14),
                  label: const Text('الصفحة التالية'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBtn({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.28) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : Colors.white.withValues(alpha: 0.12), width: isSelected ? 1.8 : 1),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }
}