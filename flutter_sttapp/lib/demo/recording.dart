import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:googleapis/storage/v1.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:googleapis/storage/v1.dart' as storage;
import 'package:googleapis/speech/v1.dart';

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
    await uploadFileToGCS(); // 파일 업로드
    await result(jsonString); // 결과 처리
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

  Future<StorageApi> readApiKey() async {
    // Read the JSON file from the assets
    jsonString = await rootBundle.loadString('assets/json/apikey_flutter.json');

    // Print the entire JSON content as a string
    print('JSON Content: $jsonString');

    // Parse the service account key JSON string
    Map<String, dynamic> jsonData = json.decode(jsonString);

    // Create GoogleCredentials using the parsed JSON data
    var credentials = ServiceAccountCredentials.fromJson(jsonData);

    // Specify the scopes (Cloud Storage scope in this case)
    var scopes = [storage.StorageApi.devstorageReadWriteScope];

    // Use ServiceAccountCredentials to authenticate
    var client = await clientViaServiceAccount(credentials, scopes);

    // Create Storage API object
    var storageApi = storage.StorageApi(client);

    return storageApi;
  }

  Future<String> uploadFileToGCS() async {
    // 서비스 계정 키 파일의 경로
    var client = await readApiKey();

    // Google Cloud Storage 버킷 이름
    var bucketName = 'speechtotext_app';

    // Read audio file as bytes
    File audioFile = File(_recordingPath);
    List<int> audioData = await audioFile.readAsBytes();

    // Create Stream from byte data
    Stream<List<int>> audioDataStream = Stream.fromIterable([audioData]);

    // Create Media from byte data stream
    var media = storage.Media(audioDataStream, audioData.length, contentType: 'audio/aac');

    String objectName = audioFile.uri.pathSegments.last;
    print('objectName: $objectName');

    storage.Object object = storage.Object();
    object.name = objectName;

    // 업로드할 파일의 Metadata를 설정합니다.
    var metadata = storage.Object(name: objectName);

    // Google Cloud Storage에 파일을 업로드합니다.
    await client.objects.insert(metadata, bucketName, uploadMedia: media);
    print('upload success');

    // 업로드된 파일의 URI를 반환합니다.
    var fileUri = 'gs://$bucketName/$objectName';
    print(fileUri);
    return fileUri;
  }

  Future<String> result(String keyfile) async {
    String recognizedText = '';

    // 서비스 계정 정보 로드
    var credentials = ServiceAccountCredentials.fromJson(json.decode(keyfile));

    // 필요한 스코프 설정 (Cloud Speech-to-Text API 사용 시)
    var scopes = [SpeechApi.cloudPlatformScope];

    // 클라이언트 생성
    var client = await clientViaServiceAccount(credentials, scopes);

    // 오디오 파일의 URI를 가져옵니다.
    var audioUri = await uploadFileToGCS();

    // Google Cloud Speech-to-Text API 요청 생성
    var speech = SpeechApi(client);
    var config = RecognitionConfig(
      encoding: 'LINEAR16',
      sampleRateHertz: 16000,
      languageCode: 'ko-KR',
    );
    var audio = RecognitionAudio(uri: audioUri);
    var request = RecognizeRequest(config: config, audio: audio);

    try {
      // Google Cloud Speech-to-Text API 호출
      var response = await speech.speech.recognize(request);

      if (response.results != null) {
        for (var result in response.results!) {
          if (result.alternatives != null) {
            for (var alternative in result.alternatives!) {
              recognizedText += 'Transcript: ${alternative.transcript}\n';
            }
          }
        }
      } else {
        recognizedText = 'No results found.';
      }

    } catch (e) {
      recognizedText = 'Error: $e';
    }
    setState(() {
      _recognizedText = recognizedText;
    });

    return recognizedText;
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