import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class Recording extends StatefulWidget {
  const Recording({super.key});

  @override
  State<Recording> createState() => _RecordingState();
}

class _RecordingState extends State<Recording> {
  late FlutterSoundPlayer _player;
  late FlutterSoundRecorder _recorder;
  bool _isRecording = false;
  late String _recordingPath;
  var uuid = Uuid();
  late String jsonString;
  String? _recognizedText;
  var magoSttApi = MagoSttApi('http://saturn.mago52.com:9003/speech2text');

  @override
  void initState() {
    super.initState();
    _player = FlutterSoundPlayer();
    _recorder = FlutterSoundRecorder();
    _recordingPath = '';

  }

  void Start() async {
    String fileName = generateFileName();
    _startRecording(fileName);
  }

  void Reqest() async {
    await _stopRecording(); // 녹음 중지
    await uploadAndProcessAudio();
  }

  String generateFileName() {
    // 파일 이름 랜덤 생성
    // Returns
    // String uuid
    String v4 = '${uuid.v4()}.wav';
    String formattedV4 = v4.replaceAll('-', '');
    return formattedV4;
  }

  Future<void> _startRecording(String fileName) async {
    Directory? directory = await getExternalStorageDirectory();
    String filePath = '${directory?.path}/$fileName';
    await _recorder.openRecorder();
    await _recorder.startRecorder(
      toFile: filePath,
      codec: Codec.pcm16WAV,
    );

    setState(() {
      _isRecording = true;
      _recordingPath = filePath;
    });
  }

  Future<void> _stopRecording() async {
    await _recorder.stopRecorder();
    await _recorder.closeRecorder();
    setState(() {
      _isRecording = false;
    });
    _isRecording = true;
  }

  Future<void> _playRecording() async {
    await _player.openPlayer();
    await _player.startPlayer(
      fromURI: _recordingPath,
      codec: Codec.aacADTS,
    );
  }

  @override
  void dispose() {
    _player.closePlayer();
    _recorder.closeRecorder();
    super.dispose();
  }

  void StartOrStop() {
    if (_isRecording) {
      // 녹음 중인 경우 녹음 중지
      _stopRecording();
    } else {
      // 녹음 중이 아닌 경우 녹음 시작
      Start();
    }
  }

  Future<String?> uploadAndProcessAudio() async {
    try {
      String? id = await magoSttApi.upload(_recordingPath);
      print('Uploaded with ID: $id');

      String? message = await magoSttApi.batch(id!);
      print('Batch Process: $message');

      String? result = await magoSttApi.getResult(id);
      print('Result: $result');

      return result;
    } catch (e) {
      print('Error: $e');
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
              height: 20,
            ),
            if (_recognizedText != null)
              Text(_recognizedText!)
            else
              Container(),
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

class MagoSttApi {
  String apiUrl;
  String resultType = 'json';

  MagoSttApi(this.apiUrl);

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

    if (response.statusCode == 200) {
      // 성공적으로 업로드되었을 때의 처리
      print('Upload successful');

      // 응답 데이터를 String으로 변환
      var responseBody = await response.stream.bytesToString();

      // 응답 바디 출력
      print(responseBody);

      String? id = getResultFromJson(responseBody, 'upload');
      print(id);
      return id;
    } else {
      // 업로드 실패 시의 처리
      print('Upload failed with status: ${response.statusCode}');
    }
  }

  Future<String?> batch(String id) async {
    // JSON 데이터 생성
    String jsonBody = '{"lang": "ko"}';

    // var request = await http.MultipartRequest('POST', Uri.parse('${apiUrl}/batch/$id'))
    //   ..headers['accept'] = 'application/json'
    //   ..headers['Content-Type'] = 'application/json'
    // ));

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
      print(responseBody);
      String? message = getResultFromJson(responseBody, 'batch');
      print(message);
      return message; // getResult에서

    } else {
      throw Exception('API 요청 실패: ${request.statusCode}');
    }
  }

  Future<String> getResult(String id) async {
    Completer<String> completer = Completer<String>();
    final List<String> result = [""]; // 단일 변수로 선언

    // 주기적인 작업 스케줄링 (초기 지연 0초, 2초마다 반복)
    Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        var response = await http.get(
            Uri.parse('$apiUrl/result/$id?result_type=$resultType'),
            headers: {'accept': 'application/json'}
        );
        if (response.statusCode == 200) {
          var responseBody = utf8.decode(response.bodyBytes);
          print(responseBody);
          result[0] = getResultFromJson(responseBody, 'result')!; // 결과 저장
          print('Task completed with result: ${result[0]}');
          // 만약 원하는 조건을 만족하면 작업 종료
          if (result[0] != null) {
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

  // Future<String?> requestResult(http.Request request) async {
  //   var client = http.Client();
  //   String? jsonResult;
  //
  //   try {
  //     var response = await client.send(request);
  //
  //     if (response.statusCode == 200) {
  //       var responseBody = await response.stream.bytesToString();
  //       print(responseBody);
  //       jsonResult = getResultFromJson(responseBody);
  //     } else {
  //       print("API 요청 실패: ${response.statusCode}");
  //     }
  //   } finally {
  //     client.close();
  //   }
  //
  //   return jsonResult;
  // }

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
      // "results" 객체 가져오기
      Map<String, dynamic> resultsObject = contentsObject['results'];
      // "text" 필드의 값을 가져오기
      String text = resultsObject['utterances'][0]['text'];
      return text;
    }
    return null;
  }
}
