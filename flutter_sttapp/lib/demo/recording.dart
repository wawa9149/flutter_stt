import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
//import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'package:logger/logger.dart';

//import 'dart:html' as html;

class Recording extends StatefulWidget {
  const Recording({super.key});

  @override
  State<Recording> createState() => _RecordingState();
}

class _RecordingState extends State<Recording> {
  late FlutterSoundPlayer _player; // 플레이어
  late FlutterSoundRecorder _recorder; // 녹음기
  bool _isRecording = false; // 녹음 중인지 여부
  late String _recordingPath; // 녹음 파일 경로
  String? _recognizedText; // 인식된 텍스트
  var logger = Logger();
  var magoSttApi = MagoSttApi('http://saturn.mago52.com:9003/speech2text'); // API 객체

  // 초기화
  @override
  void initState() {
    super.initState();
    _player = FlutterSoundPlayer();
    _recorder = FlutterSoundRecorder();
    _recordingPath = '';
    //requestMicrophonePermission();
  }

  // 녹음 시작
  void Start() async {
    // 파일 이름 생성
    // 녹음 시작
    _startRecording(generateFileName());
  }

  // void requestMicrophonePermission() async {
  //   // 마이크 권한을 요청합니다.
  //   var permissionStatus = await html.window.navigator.permissions?.request({'name': 'microphone'});
  //
  //   if (permissionStatus?.state == 'granted') {
  //     print('마이크 권한이 허용되었습니다.');
  //   } else {
  //     print('마이크 권한이 거부되었습니다.');
  //   }
  // }

  // 녹음 중지
  void Reqest() async {
    // 녹음 중지
    await _stopRecording();
    // 음성 인식 요청
    await uploadAndProcessAudio();
  }

  String generateFileName() {
    // 파일 이름 랜덤 생성
    // Returns
    // String formattedV4
    String v4 = '${const Uuid().v4()}.wav'; // 랜덤 UUID 생성
    String formattedV4 = v4.replaceAll('-', ''); // 하이픈 제거
    return formattedV4;
  }

  // 녹음 시작
  Future<void> _startRecording(String fileName) async {
    // 외부 저장소 디렉터리 가져오기
    Directory? directory = await getExternalStorageDirectory();
    // 파일 경로 생성
    String filePath = '${directory?.path}/$fileName';
    // 녹음기 초기화
    await _recorder.openRecorder();
    // 녹음 시작
    await _recorder.startRecorder(
      toFile: filePath,
      codec: Codec.pcm16WAV,
    );
    // 상태 업데이트
    setState(() {
      _isRecording = true;
      _recordingPath = filePath;
    });
  }

  // 녹음 중지
  Future<void> _stopRecording() async {
    // 녹음 중지
    await _recorder.stopRecorder();
    // 녹음기 닫기
    await _recorder.closeRecorder();
    // 상태 업데이트
    setState(() {
      _isRecording = false;
    });
  }

  // 녹음 재생
  Future<void> _playRecording() async {
    // 플레이어 초기화
    await _player.openPlayer();
    // 녹음 재생
    await _player.startPlayer(
      fromURI: _recordingPath,
      codec: Codec.aacADTS,
    );
  }

  // 종료
  @override
  void dispose() {
    // 플레이어와 녹음기 닫기
    _player.closePlayer();
    _recorder.closeRecorder();
    //
    super.dispose();
  }

  // 음성 인식 요청
  Future<void> uploadAndProcessAudio() async {
    // 음성 파일 업로드
    try {
      // 파일 업로드
      String? id = await magoSttApi.upload(_recordingPath);
      //print('Uploaded with ID: $id');

      // upload에서 받아온 id를 넣어줌
      String? message = await magoSttApi.batch(id!);
      //print('Batch Process: $message');

      // 결과 가져오기
      String? result = await magoSttApi.getResult(id);
      //print('Result: $result');

      setState(() {
        // if (message != null) {
        //   _recognizedText = message;
        // } else if (result == "") {
        //   _recognizedText = result;
        // }
        _recognizedText = result;
      });
    } catch (e) {
      //print('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const SizedBox(
              height: 50,
            ),
            Center(
              child: _recognizedText != null
                  ? Text(_recognizedText!)
                  : Container(),
            ),
            _isRecording
                ? ElevatedButton(
              onPressed: Reqest,
              child: const Text('Stop Recording'),
            )
                : ElevatedButton(
              onPressed: Start,
              child: const Text('Start Recording'),
            ),
            const SizedBox(height: 20),
            _recordingPath.isNotEmpty
                ? ElevatedButton(
              onPressed: _playRecording,
              child: const Text('Play Recording'),
            )
                : Container(),
          ],
        ),
      ),
    );
  }
}

// Path: flutter_sttapp/lib/demo/mago_stt_api.dart
class MagoSttApi {
  String apiUrl;
  String resultType = 'json';

  // 생성자
  MagoSttApi(this.apiUrl);

  // 음성 파일 업로드
  Future<String?> upload(String file) async {
    // 파일 경로
    File audioFile = File(file);
    // 파일을 바이트 배열로 읽기
    List<int> audioData = await audioFile.readAsBytes();

    // HTTP 요청 생성
    var request = http.MultipartRequest('POST', Uri.parse('$apiUrl/upload'))
      ..headers['accept'] = 'application/json'
      ..files.add(http.MultipartFile.fromBytes(
        'speech',
        audioData,
        filename: audioFile.path.split('/').last, // 파일 이름 설정
        contentType: MediaType('audio', 'wav'), // 적절한 파일 형식으로 대체하세요
      ));

    // 요청 실행 및 응답 처리
    var response = await request.send();

    // 응답 확인
    if (response.statusCode == 200) {
      // 성공적으로 업로드되었을 때의 처리
      //print('Upload successful');

      // 응답 데이터를 String으로 변환
      var responseBody = await response.stream.bytesToString();
      //print(responseBody);

      String? id = getResultFromJson(responseBody, 'upload');
      //print(id);
      return id;
    } else {
      // 업로드 실패 시의 처리
      //print('Upload failed with status: ${response.statusCode}');
    }
    return null;
  }

  // 음성 인식 요청
  Future<String?> batch(String id) async {
    // JSON 데이터 생성
    String jsonBody = '{"lang": "ko"}';
    // 요청 생성
    var request = await http.post(
      Uri.parse('$apiUrl/batch/$id'),
      headers: {
        'accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonBody,
    );

    // 응답 확인
    if (request.statusCode == 200) {
      var responseBody = request.body;
      //print(responseBody);
      String? message = getResultFromJson(responseBody, 'batch');
      //print(message);
      return message;
    } else {
      throw Exception('API 요청 실패: ${request.statusCode}');
    }
  }

  // 결과 가져오기
  Future<String> getResult(String id) async {
    // 작업 완료까지 대기하기 위한 Completer
    Completer<String> completer = Completer<String>();
    // 결과를 저장할 변수
    final List<String> result = [""];

    // 주기적인 작업 스케줄링 (초기 지연 0초, 0.3초마다 반복)
    Timer.periodic(const Duration(milliseconds: 300), (timer) async {
      try {
        // 요청 생성
        var response = await http.get(
            Uri.parse('$apiUrl/result/$id?result_type=$resultType'),
            headers: {'accept': 'application/json'}
        );
        // 응답 확인
        if (response.statusCode == 200) {
          // 응답 데이터를 String으로 변환, 한글 처리
          var responseBody = utf8.decode(response.bodyBytes);
          //print(responseBody);

          // 결과 가져오기
          result[0] = getResultFromJson(responseBody, 'result')!;
          //print('Task completed with result: ${result[0]}');

          // 결과가 있으면 작업 종료
          if (result[0] != "") {
            timer.cancel(); // 작업 종료
            completer.complete(result[0]); // 작업이 완료된 결과를 반환
          }
        } else {
          throw Exception('API 요청 실패: ${response.statusCode}');
        }
      } catch (e) {
        completer.completeError(e); // 에러가 발생한 경우 에러를 반환
      }
    });

    // 작업이 완료되기 전까지 대기하지 않고 바로 반환
    return completer.future;
  }

  String? getResultFromJson(String jsonResponse, String status) {
    // JSON 문자열을 Map으로 변환
    Map<String, dynamic> jsonObject = json.decode(jsonResponse);

    if(status == 'upload'){
        Map<String, dynamic> contentsObject = jsonObject['contents'];
        String id = contentsObject['id'];
        return id;
    }
    else if(status == 'batch'){
        String message = jsonObject['message'];
        return message;
    }
    else if(status == 'result'){
      //"contents" 객체 가져오기
      Map<String, dynamic> contentsObject = jsonObject['contents'];
      // check key in contentsObject
      if(contentsObject.containsKey('results') == false){
        return "";
      }
      // "results" 객체 가져오기
      Map<String, dynamic> resultsObject = contentsObject['results'];
      // check key in contentsObject
      if(resultsObject.containsKey('utterances') == false){
        return "";
      }
      // "text" 필드의 값을 가져오기
      String text = resultsObject['utterances'][0]['text'];
      return text;
    }
    return null;
  }
}
