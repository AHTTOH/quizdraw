import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart' as kakao;
import 'package:flutter/material.dart';

class KakaoShareService {
  /// 방 초대 메시지 공유
  static Future<void> shareRoomInvite({
    required String roomCode,
    required String roomId,
    String? creatorName,
  }) async {
    try {
      // 기본 템플릿 구성
      final template = kakao.FeedTemplate(
        content: kakao.Content(
          title: '🎨 그림퀴즈 게임 초대!',
          description: '${creatorName ?? '친구'}님이 그림퀴즈 게임에 초대했어요!\n방 코드: $roomCode',
          imageUrl: Uri.parse('https://quizdraw.app/images/logo.png'),
          link: kakao.Link(
            webUrl: Uri.parse('https://quizdraw.app/join?r=$roomId'),
            mobileWebUrl: Uri.parse('https://quizdraw.app/join?r=$roomId'),
            androidExecutionParams: {'room_code': roomCode, 'room_id': roomId},
            iosExecutionParams: {'room_code': roomCode, 'room_id': roomId},
          ),
        ),
        buttons: [
          kakao.Button(
            title: '게임 참가하기',
            link: kakao.Link(
              webUrl: Uri.parse('https://quizdraw.app/join?r=$roomId'),
              mobileWebUrl: Uri.parse('https://quizdraw.app/join?r=$roomId'),
              androidExecutionParams: {'room_code': roomCode, 'room_id': roomId},
              iosExecutionParams: {'room_code': roomCode, 'room_id': roomId},
            ),
          ),
        ],
      );

      // 카카오톡으로 공유
      final sharingResult = await kakao.ShareClient.instance.shareDefault(template: template);
      debugPrint('카카오 공유 성공: ${sharingResult.toString()}');
      
    } on kakao.KakaoException catch (error) {
      debugPrint('카카오 공유 실패: ${error.toString()}');
      rethrow;
    }
  }

  /// 라운드 결과 공유
  static Future<void> shareRoundResult({
    required String roomCode,
    required bool isWinner,
    required String answer,
    required int timeTaken,
    String? playerName,
  }) async {
    try {
      final resultText = isWinner 
        ? '🎉 정답을 맞췄어요!' 
        : '😅 아쉽게 틀렸어요';
        
      final template = kakao.FeedTemplate(
        content: kakao.Content(
          title: '$resultText',
          description: '정답: $answer${timeTaken > 0 ? '\n소요시간: ${timeTaken}초' : ''}\n\n나도 그림퀴즈 게임 해보기!',
          imageUrl: Uri.parse('https://quizdraw.app/images/logo.png'),
          link: kakao.Link(
            webUrl: Uri.parse('https://quizdraw.app'),
            mobileWebUrl: Uri.parse('https://quizdraw.app'),
          ),
        ),
        buttons: [
          kakao.Button(
            title: '나도 게임하기',
            link: kakao.Link(
              webUrl: Uri.parse('https://quizdraw.app'),
              mobileWebUrl: Uri.parse('https://quizdraw.app'),
            ),
          ),
        ],
      );

      await kakao.ShareClient.instance.shareDefault(template: template);
      debugPrint('결과 공유 성공');
      
    } on kakao.KakaoException catch (error) {
      debugPrint('결과 공유 실패: ${error.toString()}');
      rethrow;
    }
  }

  /// 카카오톡 설치 여부 확인
  static Future<bool> isKakaoTalkSharingAvailable() async {
    try {
      return await kakao.ShareClient.instance.isKakaoTalkSharingAvailable();
    } catch (error) {
      debugPrint('카카오톡 설치 확인 실패: $error');
      return false;
    }
  }
}
