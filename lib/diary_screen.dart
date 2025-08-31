import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class DiaryEntry {
  final String id;
  final String title;
  final String content;
  final int stress; // 1~5
  final int state; // 1~5
  final int mood; // 1~5
  final DateTime createdAt;
  final DateTime updatedAt;

  DiaryEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.stress,
    required this.state,
    required this.mood,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'stress': stress,
      'state': state,
      'mood': mood,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      stress: json['stress'] ?? 3, // 기본값 3
      state: json['state'] ?? 3, // 기본값 3
      mood: json['mood'] ?? 3, // 기본값 3
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}

class DiaryScreen extends StatefulWidget {
  final bool showEditorImmediately;

  const DiaryScreen({super.key, this.showEditorImmediately = false});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  List<DiaryEntry> diaryEntries = [];
  final TextEditingController _contentController = TextEditingController();
  bool isEditing = false;
  String? editingId;

  // 척도 변수들
  int stress = 3; // 1~5, 기본값 3
  int state = 3; // 1~5, 기본값 3
  int mood = 3; // 1~5, 기본값 3

  @override
  void initState() {
    super.initState();
    _loadDiaryEntries();

    // 바로 편집기를 열어야 하는 경우
    if (widget.showEditorImmediately) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showDiaryEditor();
      });
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadDiaryEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> savedEntries =
        prefs.getStringList('diary_entries') ?? [];

    setState(() {
      diaryEntries = savedEntries.map((entry) {
        return DiaryEntry.fromJson(jsonDecode(entry));
      }).toList();

      // 최신 순으로 정렬
      diaryEntries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    });
  }

  Future<void> _saveDiaryEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> entriesJson = diaryEntries.map((entry) {
      return jsonEncode(entry.toJson());
    }).toList();

    await prefs.setStringList('diary_entries', entriesJson);
  }

  void _showDiaryEditor({DiaryEntry? entry}) {
    if (entry != null) {
      _contentController.text = entry.content;
      stress = entry.stress;
      state = entry.state;
      mood = entry.mood;
      isEditing = true;
      editingId = entry.id;
    } else {
      _contentController.clear();
      stress = 3;
      state = 3;
      mood = 3;
      isEditing = false;
      editingId = null;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              contentPadding: const EdgeInsets.all(16.0),
              content: SizedBox(
                width: double.maxFinite,
                height: 450,
                child: Column(
                  children: [
                    // 스트레스 척도 - 컴팩트하게
                    Row(
                      children: [
                        const SizedBox(
                          width: 50,
                          child: Text(
                            '스트레스',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        ...List.generate(5, (index) {
                          final value = index + 1;
                          return Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Radio<int>(
                                  value: value,
                                  groupValue: stress,
                                  onChanged: (int? newValue) {
                                    setDialogState(() {
                                      stress = newValue!;
                                    });
                                  },
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                                Text(
                                  value.toString(),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                    // 상태 척도 - 컴팩트하게
                    Row(
                      children: [
                        const SizedBox(
                          width: 50,
                          child: Text(
                            '상태',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        ...List.generate(5, (index) {
                          final value = index + 1;
                          return Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Radio<int>(
                                  value: value,
                                  groupValue: state,
                                  onChanged: (int? newValue) {
                                    setDialogState(() {
                                      state = newValue!;
                                    });
                                  },
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                                Text(
                                  value.toString(),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                    // 기분 척도 - 컴팩트하게
                    Row(
                      children: [
                        const SizedBox(
                          width: 50,
                          child: Text(
                            '기분',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        ...List.generate(5, (index) {
                          final value = index + 1;
                          return Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Radio<int>(
                                  value: value,
                                  groupValue: mood,
                                  onChanged: (int? newValue) {
                                    setDialogState(() {
                                      mood = newValue!;
                                    });
                                  },
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                                Text(
                                  value.toString(),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 내용 입력
                    Expanded(
                      child: TextField(
                        controller: _contentController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: const InputDecoration(
                          labelText: '내용',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () {
                    _saveDiaryEntry();
                    Navigator.of(context).pop();
                  },
                  child: Text(isEditing ? '수정' : '저장'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _saveDiaryEntry() {
    final now = DateTime.now();

    if (isEditing && editingId != null) {
      // 기존 일기 수정
      final index = diaryEntries.indexWhere((entry) => entry.id == editingId);
      if (index != -1) {
        setState(() {
          diaryEntries[index] = DiaryEntry(
            id: editingId!,
            title: _generateTitle(diaryEntries[index].createdAt), // 원래 작성 시간 유지
            content: _contentController.text.trim(),
            stress: stress,
            state: state,
            mood: mood,
            createdAt: diaryEntries[index].createdAt,
            updatedAt: now,
          );
          diaryEntries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        });
      }
    } else {
      // 새 일기 추가
      final newEntry = DiaryEntry(
        id: now.millisecondsSinceEpoch.toString(),
        title: _generateTitle(now),
        content: _contentController.text.trim(),
        stress: stress,
        state: state,
        mood: mood,
        createdAt: now,
        updatedAt: now,
      );

      setState(() {
        diaryEntries.insert(0, newEntry);
      });
    }

    _saveDiaryEntries();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isEditing ? '일기가 수정되었습니다.' : '일기가 저장되었습니다.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _deleteDiaryEntry(String id) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('일기 삭제'),
          content: const Text('정말로 이 일기를 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  diaryEntries.removeWhere((entry) => entry.id == id);
                });
                _saveDiaryEntries();
                Navigator.of(context).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('일기가 삭제되었습니다.'),
                    backgroundColor: Colors.red,
                  ),
                );
              },
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportDiaryEntries() async {
    if (diaryEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('내보낼 일기가 없습니다.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // JSON 형태로 데이터 준비
      final exportData = {
        'export_date': DateTime.now().toIso8601String(),
        'total_entries': diaryEntries.length,
        'entries': diaryEntries.map((entry) => entry.toJson()).toList(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      // 모바일에서는 클립보드에 복사
      await _copyToClipboard(jsonString);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('일기 ${diaryEntries.length}개의 데이터가 클립보드에 복사되었습니다.'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: '데이터 보기',
            onPressed: () => _shareJsonData(jsonString),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('내보내기 실패: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _copyToClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (e) {
      // 클립보드 복사 실패시 무시
    }
  }

  void _shareJsonData(String jsonData) {
    // 간단한 공유 기능 - 실제로는 share_plus 패키지를 사용하는 것이 좋습니다
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일기 데이터'),
        content: SingleChildScrollView(
          child: Text(
            jsonData.length > 500
                ? '${jsonData.substring(0, 500)}...'
                : jsonData,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  // 날짜를 기반으로 제목 생성
  String _generateTitle(DateTime date) {
    return '${date.year}년 ${date.month}월 ${date.day}일 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📝 일기'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: _exportDiaryEntries,
            icon: const Icon(Icons.file_download),
            tooltip: '일기 내보내기',
          ),
          IconButton(
            onPressed: () => _showDiaryEditor(),
            icon: const Icon(Icons.add),
            tooltip: '새 일기 작성',
          ),
        ],
      ),
      body: diaryEntries.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.book_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    '아직 작성된 일기가 없습니다.\n오른쪽 상단의 + 버튼을 눌러 새 일기를 작성해보세요!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: diaryEntries.length,
              itemBuilder: (context, index) {
                final entry = diaryEntries[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(
                      entry.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        // 척도 표시
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '스트레스 ${entry.stress}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '상태 ${entry.state}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '기분 ${entry.mood}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          entry.content.length > 100
                              ? '${entry.content.substring(0, 100)}...'
                              : entry.content,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '작성: ${_formatDate(entry.createdAt)}${entry.createdAt != entry.updatedAt ? '\n수정: ${_formatDate(entry.updatedAt)}' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showDiaryEditor(entry: entry);
                        } else if (value == 'delete') {
                          _deleteDiaryEntry(entry.id);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 16),
                              SizedBox(width: 8),
                              Text('수정'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 16, color: Colors.red),
                              SizedBox(width: 8),
                              Text('삭제', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _showDiaryEditor(entry: entry),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDiaryEditor(),
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add),
      ),
    );
  }
}
