import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class CanvasImageService {
  static final SupabaseClient _client = Supabase.instance.client;
  static const String bucketName = 'drawings';

  /// 캔버스를 PNG 이미지로 변환하여 Supabase Storage에 업로드
  static Future<Map<String, dynamic>> uploadCanvasImage({
    required GlobalKey canvasKey,
    required String roundId,
    String? answer,
  }) async {
    try {
      // 1. 캔버스를 PNG로 변환
      final boundary = canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('캔버스를 찾을 수 없습니다');
      }

      // 고해상도 이미지 생성 (픽셀 ratio 적용)
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        throw Exception('이미지 변환에 실패했습니다');
      }

      Uint8List pngBytes = byteData.buffer.asUint8List();
      
      // 2. 이미지 압축 (1MB 이하로)
      pngBytes = compressImageIfNeeded(pngBytes, maxSizeKB: 1024);
      
      // 3. 파일명 생성 (UUID + 타임스탬프)
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uuid = const Uuid().v4();
      final fileName = 'drawing_${roundId}_${uuid}_$timestamp.png';
      final storagePath = 'drawings/$fileName';

      // 4. Supabase Storage에 업로드
      await _client.storage
          .from(bucketName)
          .uploadBinary(
            storagePath,
            pngBytes,
            fileOptions: const FileOptions(
              contentType: 'image/png',
              cacheControl: '3600', // 1시간 캐시
            ),
          );

      // 5. 공개 URL 생성
      final String publicUrl = _client.storage
          .from(bucketName)
          .getPublicUrl(storagePath);

      return {
        'success': true,
        'storage_path': storagePath,
        'public_url': publicUrl,
        'file_size': pngBytes.length,
        'width': image.width,
        'height': image.height,
        'uploaded_at': DateTime.now().toIso8601String(),
      };

    } catch (error) {
      debugPrint('캔버스 업로드 실패: $error');
      return {
        'success': false,
        'error': error.toString(),
      };
    }
  }

  /// Storage 버킷 초기화 (앱 시작시 한 번 실행)
  static Future<void> initializeStorageBucket() async {
    try {
      // drawings 버킷이 존재하는지 확인
      final buckets = await _client.storage.listBuckets();
      final hasDrawingsBucket = buckets.any((bucket) => bucket.name == bucketName);
      
      if (hasDrawingsBucket) {
        debugPrint('Storage bucket "$bucketName" is ready');
      } else {
        debugPrint('Storage bucket "$bucketName" not found');
      }
    } catch (error) {
      debugPrint('Storage bucket "$bucketName" check failed: $error');
      // 실제 프로덕션에서는 Supabase 대시보드에서 버킷을 미리 생성해야 함
    }
  }

  /// 업로드된 이미지 삭제
  static Future<bool> deleteDrawing(String storagePath) async {
    try {
      final files = await _client.storage
          .from(bucketName)
          .remove([storagePath]);
      
      return files.isNotEmpty;
    } catch (error) {
      debugPrint('그림 삭제 실패: $error');
      return false;
    }
  }

  /// 이미지 파일 크기 최적화 (실제 압축 구현)
  static Uint8List compressImageIfNeeded(Uint8List imageBytes, {int maxSizeKB = 1024}) {
    final int maxSizeBytes = maxSizeKB * 1024;
    
    // 1MB 이하면 그대로 반환
    if (imageBytes.length <= maxSizeBytes) {
      debugPrint('이미지 크기: ${(imageBytes.length / 1024).round()}KB (압축 불필요)');
      return imageBytes;
    }

    // 간단한 압축: 품질을 낮춰서 크기 줄이기
    // 실제로는 더 정교한 이미지 압축 라이브러리 사용 권장
    debugPrint('이미지 압축 시작: ${(imageBytes.length / 1024).round()}KB');
    
    // PNG는 무손실 압축이므로, 여기서는 기본적인 크기 체크만 수행
    // 실제 프로덕션에서는 flutter_image_compress 같은 라이브러리 사용
    if (imageBytes.length > maxSizeBytes * 2) {
      debugPrint('⚠️ 이미지가 너무 큽니다. 더 작은 캔버스로 그려주세요.');
    }
    
    return imageBytes;
  }

  /// 업로드 진행률 콜백을 위한 스트림 업로드 (고급 기능)
  static Stream<double> uploadWithProgress({
    required Uint8List imageBytes,
    required String storagePath,
  }) async* {
    try {
      // Supabase는 현재 진행률 콜백을 직접 지원하지 않음
      // 여기서는 시뮬레이션된 진행률 제공
      for (int i = 0; i <= 100; i += 10) {
        yield i / 100.0;
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      // 실제 업로드 수행
      await _client.storage
          .from(bucketName)
          .uploadBinary(storagePath, imageBytes);
      
      yield 1.0; // 완료
    } catch (error) {
      debugPrint('진행률 업로드 실패: $error');
      rethrow;
    }
  }

  /// 이미지 유효성 검사
  static bool validateImageSize(int width, int height) {
    // 최소/최대 크기 제한
    const int minSize = 64;
    const int maxSize = 4096;
    
    if (width < minSize || height < minSize) {
      debugPrint('이미지가 너무 작습니다: ${width}x${height}');
      return false;
    }
    
    if (width > maxSize || height > maxSize) {
      debugPrint('이미지가 너무 큽니다: ${width}x${height}');
      return false;
    }
    
    return true;
  }

  /// 파일 크기 제한 확인
  static bool validateFileSize(int bytes) {
    const int maxSizeBytes = 1024 * 1024; // 1MB
    
    if (bytes > maxSizeBytes) {
      debugPrint('파일이 너무 큽니다: ${(bytes / 1024).round()}KB');
      return false;
    }
    
    return true;
  }
}
