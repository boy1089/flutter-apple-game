import 'package:flutter/material.dart';
import 'dart:math' as math;

void main() {
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
  static const int rows = 17;
  static const int cols = 8; // 열 수를 줄여서 화면에 맞춤
  static const double appleSize = 22.0;

  List<List<Apple>> apples = [];
  Offset? dragStart;
  Offset? dragEnd;
  bool isDragging = false;

  @override
  void initState() {
    super.initState();
    initializeApples();
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

          final appleX = col * appleSize + appleSize / 2;
          final appleY = row * appleSize + appleSize / 2;

          if (appleX >= minX &&
              appleX <= maxX &&
              appleY >= minY &&
              appleY <= maxY) {
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
      });

      // 성공 효과음이나 애니메이션을 여기에 추가할 수 있습니다
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${selectedApples.length}개의 사과가 제거되었습니다! 합계: $sum'),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.green,
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('Apple Game (선택된 합: ${getSelectedSum()})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                initializeApples();
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
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
                            margin: const EdgeInsets.all(0.5),
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
                                        color: Colors.yellow.withOpacity(0.5),
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
                                  fontSize: 12,
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
                            border: Border.all(color: Colors.blue, width: 2),
                          ),
                        ),
                      ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
