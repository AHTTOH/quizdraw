import 'package:flutter/material.dart';
import '../../core/canvas_image_service.dart';

class DrawModal extends StatefulWidget {
  const DrawModal({super.key});

  @override
  State<DrawModal> createState() => _DrawModalState();
}

class _DrawModalState extends State<DrawModal> {
  final List<DrawingPoint?> _points = [];
  final List<DrawingPoint?> _redoPoints = [];
  final GlobalKey _canvasKey = GlobalKey();
  
  Color _selectedColor = Colors.black;
  double _strokeWidth = 3.0;
  bool _isEraser = false;
  
  final List<Color> _colors = [
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.orange,
    Colors.purple,
    Colors.brown,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Text(
                  '그림 그리기',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _points.isNotEmpty ? _undo : null,
                  icon: const Icon(Icons.undo),
                  tooltip: '실행취소',
                ),
                IconButton(
                  onPressed: _redoPoints.isNotEmpty ? _redo : null,
                  icon: const Icon(Icons.redo),
                  tooltip: '다시실행',
                ),
                IconButton(
                  onPressed: _clearCanvas,
                  icon: const Icon(Icons.clear),
                  tooltip: '전체 지우기',
                ),
                IconButton(
                  onPressed: _submitDrawing,
                  icon: const Icon(Icons.check),
                  tooltip: '제출',
                ),
              ],
            ),
          ),
          
          // 도구바
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // 펜/지우개 토글
                ToggleButtons(
                  isSelected: [!_isEraser, _isEraser],
                  onPressed: (index) {
                    setState(() {
                      _isEraser = index == 1;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.edit),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.auto_fix_high),
                    ),
                  ],
                ),
                
                const SizedBox(width: 16),
                
                // 선 굵기 조절
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('선 굵기', style: TextStyle(fontSize: 12)),
                      Slider(
                        value: _strokeWidth,
                        min: 1.0,
                        max: 10.0,
                        divisions: 9,
                        onChanged: (value) {
                          setState(() {
                            _strokeWidth = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // 색상 팔레트
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('색상: ', style: TextStyle(fontSize: 14)),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: _colors.map((color) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedColor = color;
                          });
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedColor == color
                                  ? Colors.black
                                  : Colors.grey,
                              width: _selectedColor == color ? 3 : 1,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          
          // 캔버스
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      _points.add(DrawingPoint(
                        details.localPosition,
                        Paint()
                          ..color = _isEraser ? Colors.white : _selectedColor
                          ..strokeWidth = _strokeWidth
                          ..strokeCap = StrokeCap.round
                          ..strokeJoin = StrokeJoin.round
                          ..blendMode = _isEraser ? BlendMode.clear : BlendMode.srcOver,
                      ));
                    });
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      _points.add(DrawingPoint(
                        details.localPosition,
                        Paint()
                          ..color = _isEraser ? Colors.white : _selectedColor
                          ..strokeWidth = _strokeWidth
                          ..strokeCap = StrokeCap.round
                          ..strokeJoin = StrokeJoin.round
                          ..blendMode = _isEraser ? BlendMode.clear : BlendMode.srcOver,
                      ));
                    });
                  },
                  onPanEnd: (details) {
                    setState(() {
                      _points.add(null);
                      _redoPoints.clear();
                    });
                  },
                  child: RepaintBoundary(
                    key: _canvasKey,
                    child: CustomPaint(
                      painter: DrawingPainter(_points),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _undo() {
    if (_points.isNotEmpty) {
      setState(() {
        final removedPoints = <DrawingPoint?>[];
        while (_points.isNotEmpty && _points.last != null) {
          removedPoints.add(_points.removeLast());
        }
        if (_points.isNotEmpty) {
          removedPoints.add(_points.removeLast());
        }
        _redoPoints.addAll(removedPoints.reversed);
      });
    }
  }

  void _redo() {
    if (_redoPoints.isNotEmpty) {
      setState(() {
        final restoredPoints = <DrawingPoint?>[];
        while (_redoPoints.isNotEmpty && _redoPoints.last != null) {
          restoredPoints.add(_redoPoints.removeLast());
        }
        if (_redoPoints.isNotEmpty) {
          restoredPoints.add(_redoPoints.removeLast());
        }
        _points.addAll(restoredPoints.reversed);
      });
    }
  }

  void _clearCanvas() {
    setState(() {
      _points.clear();
      _redoPoints.clear();
    });
  }

  Future<void> _submitDrawing() async {
    if (_points.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('그림을 그려주세요')),
      );
      return;
    }

    // 로딩 상태 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('그림을 업로드 중...'),
          ],
        ),
      ),
    );

    try {
      // 실제 캔버스 이미지 업로드
      final result = await CanvasImageService.uploadCanvasImage(
        canvasKey: _canvasKey,
        roundId: 'prepare',
      );

      if (mounted) {
        Navigator.pop(context); // 로딩 다이얼로그 닫기
        
        if (result['success'] == true) {
          Navigator.pop(context, {
            'success': true,
            'message': '그림이 제출되었습니다',
            'storage_path': result['storage_path'],
            'public_url': result['public_url'],
            'file_size': result['file_size'],
            'width': result['width'],
            'height': result['height'],
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('업로드 실패: ${result['error']}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 로딩 다이얼로그 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('그림 제출 실패: $e')),
        );
      }
    }
  }
}

class DrawingPoint {
  final Offset offset;
  final Paint paint;

  DrawingPoint(this.offset, this.paint);
}

class DrawingPainter extends CustomPainter {
  final List<DrawingPoint?> points;

  DrawingPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(
          points[i]!.offset,
          points[i + 1]!.offset,
          points[i]!.paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}



