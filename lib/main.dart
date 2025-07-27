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
  static const int rows = 10;
  static const int cols = 17;
  static const double appleSize = 40.0;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Apple Game'),
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
      body: Center(
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
                setState(() {
                  dragStart = null;
                  dragEnd = null;
                });
              },
              child: Container(
                width: cols * appleSize,
                height: rows * appleSize,
                child: Stack(
                  children: [
                    // 사과 그리드
                    ...List.generate(rows, (row) {
                      return List.generate(cols, (col) {
                        final apple = apples[row][col];
                        return Positioned(
                          left: col * appleSize,
                          top: row * appleSize,
                          child: Container(
                            width: appleSize,
                            height: appleSize,
                            margin: const EdgeInsets.all(1),
                            decoration: BoxDecoration(
                              color: apple.isSelected
                                  ? Colors.red.withOpacity(0.9)
                                  : Colors.red.withOpacity(0.7),
                              border: Border.all(
                                color: apple.isSelected
                                    ? Colors.yellow
                                    : Colors.red.shade700,
                                width: apple.isSelected ? 3 : 1,
                              ),
                              borderRadius: BorderRadius.circular(
                                appleSize / 2,
                              ),
                              boxShadow: apple.isSelected
                                  ? [
                                      BoxShadow(
                                        color: Colors.yellow.withOpacity(0.5),
                                        blurRadius: 4,
                                        spreadRadius: 1,
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
                                  fontSize: 16,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(1, 1),
                                      blurRadius: 2,
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
    );
  }
}
