import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';
import 'dart:io';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 가로모드로 고정
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const AppleGameApp());
}

class AppleGameApp extends StatelessWidget {
  const AppleGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Apple Game',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const AppleGameScreen(),
    );
  }
}

class Apple {
  final int number;
  final int row;
  final int col;
  bool isSelected;

  Apple({
    required this.number,
    required this.row,
    required this.col,
    this.isSelected = false,
  });
}

class AppleGameScreen extends StatefulWidget {
  const AppleGameScreen({super.key});

  @override
  State<AppleGameScreen> createState() => _AppleGameScreenState();
}

class _AppleGameScreenState extends State<AppleGameScreen> {
  int rows = 10; // 화면 크기에 따라 동적으로 계산될 행 수
  int cols = 20; // 화면 크기에 따라 동적으로 계산될 열 수
  static const double appleSize = 25.0; // 사과 크기
  static const double padding = 5.0; // 화면 여백
  static const double uiElementsHeight = 10.0; // UI 요소들이 차지하는 높이

  List<List<Apple>> apples = [];
  Offset? dragStart;
  Offset? dragEnd;
  bool isDragging = false;

  // 설정 관련 변수들
  int timeLimitMinutes = 5; // 제한시간 (분) - 기본 5분
  List<String> gameResults = []; // 게임 결과 저장
  String exportPath = '/storage/emulated/0'; // CSV 내보내기 경로

  // 타이머 관련 변수들
  Timer? gameTimer;
  int remainingSeconds = 0;
  bool isGameStarted = false;

  // 점수 관련 변수
  int score = 0; // 제거한 사과 개수

  @override
  void initState() {
    super.initState();
    _loadSettings(); // 저장된 설정 불러오기
    // startNewGame은 build에서 화면 크기를 계산한 후 호출됩니다.
  }

  void calculateGridSize(BuildContext context) {
    // 화면 크기 가져오기
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    // UI 요소들을 고려한 사용 가능한 영역 계산
    final availableWidth = screenWidth - (padding * 2); // 좌우 여백
    final availableHeight = screenHeight - uiElementsHeight; // 상하 UI 요소 공간

    // 사과가 들어갈 수 있는 최대 행과 열 계산
    final maxCols = (availableWidth / appleSize).floor();
    final maxRows = (availableHeight / appleSize).floor();

    // 최소값 보장 (너무 작은 화면에서도 게임이 가능하도록)
    cols = maxCols > 5 ? maxCols : 5;
    rows = maxRows > 3 ? maxRows : 3;

    cols = 17;
    rows = 10;

    // 최대값 제한 (너무 많은 사과로 인한 성능 문제 방지)
    if (cols > 25) cols = 25;
    if (rows > 15) rows = 15;
  }

  void initializeApples() {
    final random = math.Random();
    apples = List.generate(rows, (row) {
      return List.generate(cols, (col) {
        return Apple(
          number: random.nextInt(9) + 1, // 1-9 사이의 랜덤 숫자
          row: row,
          col: col,
        );
      });
    });
  }

  void startNewGame() {
    // 이전 게임이 진행 중이었다면 결과 저장
    if (isGameStarted &&
        (score > 0 || remainingSeconds < timeLimitMinutes * 60)) {
      _saveGameResult();
    }

    setState(() {
      initializeApples();
      remainingSeconds = timeLimitMinutes * 60; // 분을 초로 변환
      isGameStarted = true;
      score = 0; // 점수 초기화
    });

    // 기존 타이머가 있다면 취소
    gameTimer?.cancel();

    // 새 타이머 시작
    gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (remainingSeconds > 0) {
          remainingSeconds--;
        } else {
          timer.cancel();
          isGameStarted = false;
          _saveGameResult(); // 게임 종료 시 결과 저장
          _showGameOverDialog();
        }
      });
    });
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('⏰ 시간 종료!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('제한시간이 끝났습니다.'),
              const SizedBox(height: 10),
              Text('점수: ${score}개'),
              Text('남은 사과: ${_getRemainingApplesCount()}개'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                startNewGame(); // 새 게임 시작
              },
              child: const Text('새 게임'),
            ),
          ],
        );
      },
    );
  }

  int _getRemainingApplesCount() {
    int count = 0;
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        if (apples[row][col].number != 0) {
          count++;
        }
      }
    }
    return count;
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    super.dispose();
  }

  // 설정 불러오기 메서드
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      // 저장된 제한시간 설정 불러오기 (기본값: 5분)
      timeLimitMinutes = prefs.getInt('timer_limit_minutes') ?? 5;

      // 저장된 내보내기 경로 불러오기 (기본값: /storage/emulated/0)
      exportPath = prefs.getString('export_path') ?? '/storage/emulated/0';
    });
  }

  // 설정 저장 메서드
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // 제한시간 설정 저장
    await prefs.setInt('timer_limit_minutes', timeLimitMinutes);

    // 내보내기 경로 저장
    await prefs.setString('export_path', exportPath);
  }

  // 게임 결과 저장 메서드
  Future<void> _saveGameResult() async {
    final prefs = await SharedPreferences.getInstance();
    final DateTime now = DateTime.now();

    // 게임 결과 데이터 생성
    final Map<String, dynamic> gameResult = {
      'datetime': now.toIso8601String(),
      'score': score,
      'timerSetting': timeLimitMinutes,
    };

    // 기존 결과들 가져오기
    List<String> savedResults = prefs.getStringList('game_results') ?? [];

    // 새 결과 추가
    savedResults.add(jsonEncode(gameResult));

    // 최대 100개 결과만 보관 (너무 많아지지 않도록)
    if (savedResults.length > 100) {
      savedResults = savedResults.sublist(savedResults.length - 100);
    }

    // 저장
    await prefs.setStringList('game_results', savedResults);
  }

  // 저장된 게임 결과들 가져오기
  Future<List<Map<String, dynamic>>> _getSavedResults() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedResults = prefs.getStringList('game_results') ?? [];

    return savedResults.map((result) {
      return Map<String, dynamic>.from(jsonDecode(result));
    }).toList();
  }

  // 게임 기록 다이얼로그 표시
  void _showGameHistoryDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: SizedBox(
            width: double.maxFinite,
            height: 200,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _getSavedResults(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('저장된 게임 기록이 없습니다.'));
                }

                final results = snapshot.data!.reversed.toList(); // 최신 순으로 정렬

                return ListView.builder(
                  itemCount: results.length,
                  itemExtent: 20, // 각 항목의 높이 고정
                  itemBuilder: (context, index) {
                    final result = results[index];
                    final DateTime gameTime = DateTime.parse(
                      result['datetime'],
                    );
                    final String formattedTime =
                        '${gameTime.year}-${gameTime.month.toString().padLeft(2, '0')}-${gameTime.day.toString().padLeft(2, '0')} '
                        '${gameTime.hour.toString().padLeft(2, '0')}:${gameTime.minute.toString().padLeft(2, '0')}';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        vertical: 1,
                        horizontal: 8,
                      ),
                      child: Text(
                        '${formattedTime}, ${result['timerSetting']}분, 점수: ${result['score']}개',
                        style: TextStyle(fontSize: 8),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void updateSelection(Offset start, Offset end) {
    // 드래그 영역에 포함된 사과들 선택
    final minX = math.min(start.dx, end.dx);
    final maxX = math.max(start.dx, end.dx);
    final minY = math.min(start.dy, end.dy);
    final maxY = math.max(start.dy, end.dy);

    setState(() {
      // 모든 사과 선택 해제
      for (int row = 0; row < rows; row++) {
        for (int col = 0; col < cols; col++) {
          apples[row][col].isSelected = false;
        }
      }

      // 드래그 영역 내의 사과들 선택
      for (int row = 0; row < rows; row++) {
        for (int col = 0; col < cols; col++) {
          // 숫자가 0인 사과는 선택할 수 없음
          if (apples[row][col].number == 0) continue;

          // 사과의 경계 좌표 계산
          final appleLeft = col * appleSize;
          final appleRight = appleLeft + appleSize;
          final appleTop = row * appleSize;
          final appleBottom = appleTop + appleSize;

          // 드래그 영역과 사과 영역이 겹치는지 확인
          if (appleRight > minX &&
              appleLeft < maxX &&
              appleBottom > minY &&
              appleTop < maxY) {
            apples[row][col].isSelected = true;
          }
        }
      }
    });
  }

  void checkAndRemoveApples() {
    // 선택된 사과들의 합 계산
    int sum = 0;
    List<Apple> selectedApples = [];

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        if (apples[row][col].isSelected) {
          selectedApples.add(apples[row][col]);
          sum += apples[row][col].number;
        }
      }
    }

    // 합이 10이면 선택된 사과들 제거
    if (sum == 10 && selectedApples.isNotEmpty) {
      setState(() {
        for (Apple apple in selectedApples) {
          // 사과를 제거하는 대신 숫자를 0으로 설정하여 보이지 않게 함
          apples[apple.row][apple.col] = Apple(
            number: 0, // 0은 화면에 표시되지 않음
            row: apple.row,
            col: apple.col,
            isSelected: false,
          );
        }
        // 제거한 사과 개수만큼 점수 증가
        score += selectedApples.length;
      });
    }
  }

  int getSelectedSum() {
    int sum = 0;
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        if (apples[row][col].isSelected) {
          sum += apples[row][col].number;
        }
      }
    }
    return sum;
  }

  void _showSettingsDialog(BuildContext context) {
    int tempTimeLimitMinutes = timeLimitMinutes; // 임시 변수
    String tempExportPath = exportPath; // 임시 경로 변수
    final TextEditingController pathController = TextEditingController(
      text: exportPath,
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              actionsPadding: EdgeInsets.zero,
              contentPadding: const EdgeInsets.all(8),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 제한시간 설정
                  Row(
                    children: [
                      const Text('제한시간: ', style: TextStyle(fontSize: 10)),
                      Expanded(
                        child: Slider(
                          value: tempTimeLimitMinutes.toDouble(),
                          min: 1,
                          max: 10,
                          divisions: 9,
                          label: '${tempTimeLimitMinutes}분',
                          onChanged: (double value) {
                            setState(() {
                              tempTimeLimitMinutes = value.toInt();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${tempTimeLimitMinutes}분',
                    style: const TextStyle(fontSize: 10),
                  ),

                  TextField(
                    controller: pathController,
                    style: const TextStyle(fontSize: 8),

                    decoration: const InputDecoration(
                      hintText: '예: /storage/emulated/0/Download',
                      hintStyle: TextStyle(fontSize: 8),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),

                    onChanged: (value) {
                      tempExportPath = value;
                    },
                  ),

                  // Export 버튼
                  ElevatedButton.icon(
                    onPressed: _exportResults,
                    icon: const Icon(Icons.download, size: 12),
                    label: const Text('결과 내보내기', style: TextStyle(fontSize: 8)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      minimumSize: const Size(80, 24),
                    ),
                  ),
                  // 게임 기록 보기 버튼
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showGameHistoryDialog();
                    },
                    icon: const Icon(Icons.history, size: 12),
                    label: const Text(
                      '게임 기록 보기',
                      style: TextStyle(fontSize: 8),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      minimumSize: const Size(80, 24),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('취소', style: TextStyle(fontSize: 10)),
                ),
                TextButton(
                  onPressed: () {
                    // 변경사항 저장
                    this.setState(() {
                      timeLimitMinutes = tempTimeLimitMinutes;
                      exportPath = tempExportPath;
                    });
                    _saveSettings(); // 설정을 SharedPreferences에 저장
                    Navigator.of(context).pop();
                    // 시간 설정이 변경되면 새 게임 시작
                    startNewGame();
                  },
                  child: const Text('저장', style: TextStyle(fontSize: 10)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _exportResults() async {
    // 저장된 게임 결과들 가져오기
    final results = await _getSavedResults();

    if (results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('내보낼 게임 기록이 없습니다'),
          backgroundColor: Colors.orange,
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    try {
      // CSV 형식으로 데이터 생성
      String csvData = 'datetime,score,timer_setting\n'; // CSV 헤더

      // 각 게임 결과를 CSV 행으로 추가
      for (final result in results.reversed) {
        // 최신 순으로 정렬
        final DateTime gameTime = DateTime.parse(result['datetime']);
        final String formattedTime =
            '${gameTime.year}-${gameTime.month.toString().padLeft(2, '0')}-${gameTime.day.toString().padLeft(2, '0')} '
            '${gameTime.hour.toString().padLeft(2, '0')}:${gameTime.minute.toString().padLeft(2, '0')}';

        csvData +=
            '"$formattedTime",${result['score']},${result['timerSetting']}\n';
      }

      // 통계 정보 추가
      final totalGames = results.length;
      final totalScore = results.fold<int>(
        0,
        (sum, result) => sum + (result['score'] as int),
      );
      final avgScore = totalGames > 0
          ? (totalScore / totalGames).toStringAsFixed(1)
          : '0';
      final maxScore = results.fold<int>(
        0,
        (max, result) =>
            (result['score'] as int) > max ? (result['score'] as int) : max,
      );

      csvData += '\nStatistics\n';
      csvData += 'total_games,total_score,avg_score,max_score\n';
      csvData += '$totalGames,$totalScore,$avgScore,$maxScore\n';

      // 파일명 생성
      final DateTime now = DateTime.now();
      final String timestamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final String fileName = 'apple_game_results_$timestamp.csv';

      // 저장 경로 결정
      Directory directory;
      String savePath;

      directory = Directory(exportPath);
      savePath = '${directory.path}/$fileName';

      final file = File(savePath);
      await file.writeAsString(csvData);

      // 성공 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${totalGames}개의 게임 기록이 CSV 파일로 저장되었습니다\n파일: $fileName\n경로: ${directory.path}',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      // 에러 처리
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('파일 저장 중 오류가 발생했습니다: $e\n기본 경로를 확인하거나 올바른 경로를 입력해주세요'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }

    Navigator.of(context).pop(); // 설정 다이얼로그 닫기
  }

  @override
  Widget build(BuildContext context) {
    // 화면 크기에 따른 그리드 크기 계산 (한 번만 실행)
    if (apples.isEmpty) {
      calculateGridSize(context);
      startNewGame();
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // 게임 영역 (전체 화면)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: GestureDetector(
                  onPanStart: (details) {
                    dragStart = details.localPosition;
                    dragEnd = details.localPosition;
                    isDragging = true;
                  },
                  onPanUpdate: (details) {
                    if (isDragging) {
                      dragEnd = details.localPosition;
                      if (dragStart != null) {
                        updateSelection(dragStart!, dragEnd!);
                      }
                    }
                  },
                  onPanEnd: (details) {
                    isDragging = false;
                    // 드래그가 끝나면 합계 확인
                    checkAndRemoveApples();
                    setState(() {
                      dragStart = null;
                      dragEnd = null;
                    });
                  },
                  child: Container(
                    width: cols * appleSize,
                    height: rows * appleSize,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.transparent, // 투명 배경으로 전체 영역 드래그 가능
                    ),
                    child: Stack(
                      children: [
                        // 사과 그리드
                        ...List.generate(rows, (row) {
                          return List.generate(cols, (col) {
                            final apple = apples[row][col];
                            // 숫자가 0인 사과는 표시하지 않음
                            if (apple.number == 0) {
                              return const SizedBox.shrink();
                            }
                            return Positioned(
                              left: col * appleSize,
                              top: row * appleSize,
                              child: Container(
                                width: appleSize,
                                height: appleSize,
                                margin: const EdgeInsets.all(2.0),
                                decoration: BoxDecoration(
                                  color: apple.isSelected
                                      ? Colors.red.withOpacity(0.9)
                                      : Colors.red.withOpacity(0.7),
                                  border: Border.all(
                                    color: apple.isSelected
                                        ? Colors.yellow
                                        : Colors.red.shade700,
                                    width: apple.isSelected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    appleSize / 2,
                                  ),
                                  boxShadow: apple.isSelected
                                      ? [
                                          BoxShadow(
                                            color: Colors.yellow.withOpacity(
                                              0.5,
                                            ),
                                            blurRadius: 2,
                                            spreadRadius: 0.5,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    '${apple.number}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                      shadows: [
                                        Shadow(
                                          offset: Offset(0.5, 0.5),
                                          blurRadius: 1,
                                          color: Colors.black54,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          });
                        }).expand((element) => element).toList(),

                        // 드래그 선택 사각형
                        if (isDragging && dragStart != null && dragEnd != null)
                          Positioned(
                            left: math.min(dragStart!.dx, dragEnd!.dx),
                            top: math.min(dragStart!.dy, dragEnd!.dy),
                            child: Container(
                              width: (dragEnd!.dx - dragStart!.dx).abs(),
                              height: (dragEnd!.dy - dragStart!.dy).abs(),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.3),
                                border: Border.all(
                                  color: Colors.blue,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // 왼쪽 위 새게임 버튼
            Positioned(
              top: 16,
              left: 8,
              child: FloatingActionButton.small(
                onPressed: () {
                  startNewGame();
                },
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                child: const Icon(Icons.refresh),
              ),
            ),
            // 중앙 상단 타이머 표시
            Positioned(
              top: 65,
              left: 8,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: remainingSeconds <= 30
                        ? Colors.red.withOpacity(0.9)
                        : remainingSeconds <= 60
                        ? Colors.orange.withOpacity(0.9)
                        : Colors.blue.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer, color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(remainingSeconds),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 점수 표시 (타이머 아래)
            Positioned(
              top: 90,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      '점수: $score',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 오른쪽 위 설정 버튼
            Positioned(
              top: 16,
              right: 8,
              child: FloatingActionButton.small(
                onPressed: () {
                  _showSettingsDialog(context);
                },
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                child: const Icon(Icons.settings),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
