import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:googleapis/storage/v1.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:googleapis/storage/v1.dart' as storage;
import 'package:googleapis/speech/v1.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title:'Speech To Text'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late FlutterSoundPlayer _player;
  late FlutterSoundRecorder _recorder;
  bool _isRecording = false;
  late String _recordingPath;
  var uuid = Uuid();
  late String jsonString;

  @override
  void initState() {
    super.initState();
    _player = FlutterSoundPlayer();
    _recorder = FlutterSoundRecorder();
    _recordingPath = '';
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
    try {
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
      // ignore: empty_catches
    } catch (e) {}
  }

  Future<void> _stopRecording() async {
    await _recorder.stopRecorder();
    await _recorder.closeRecorder();
    setState(() {
      _isRecording = false;
    });
    _isRecording = true;
    print(_recordingPath);
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

  Future<StorageApi> readApiKey() async {
    print('1');
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

  // Future<void> uploadFileToGCS() async {
  //   print('upload your file');
  //   // 서비스 계정 키 파일의 경로
  //   var client = await readApiKey();
  //
  //   // Google Cloud Storage 버킷 이름
  //   var bucketName = 'speechtotext_app';
  //
  //   // Read audio file as bytes
  //   File audioFile = File(_recordingPath);
  //   List<int> audioData = await audioFile.readAsBytes();
  //
  //   // Create Stream from byte data
  //   Stream<List<int>> audioDataStream = Stream.fromIterable([audioData]);
  //
  //   // Create Media from byte data stream
  //   var media = storage.Media(audioDataStream, audioData.length, contentType: 'audio/aac');
  //
  //   String objectName = audioFile.uri.pathSegments.last;
  //   print('objectName: $objectName');
  //
  //   storage.Object object = storage.Object();
  //   object.name = objectName;
  //
  //   // 업로드할 파일의 Metadata를 설정합니다.
  //   var metadata = storage.Object(name: objectName);
  //
  //   // Google Cloud Storage에 파일을 업로드합니다.
  //   await client.objects.insert(metadata, bucketName, uploadMedia: media);
  //   print('upload success');
  // }

  Future<String> uploadFileToGCS() async {
    print('upload your file');
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

  Future<void> result(String keyfile) async {
    print('2');
    // 서비스 계정 정보 로드
    var credentials = ServiceAccountCredentials.fromJson(json.decode(keyfile));

    // 필요한 스코프 설정 (Cloud Speech-to-Text API 사용 시)
    var scopes = [SpeechApi.cloudPlatformScope];

    // 클라이언트 생성
    var client = await clientViaServiceAccount(credentials, scopes);
    print('3');

    // 오디오 파일의 URI를 가져옵니다.
    var audioUri = await uploadFileToGCS();

    //await Future.delayed(Duration(seconds: 5));

    // Google Cloud Speech-to-Text API 요청 생성
    var speech = SpeechApi(client);
    var config = RecognitionConfig(
      encoding: 'LINEAR16',
      sampleRateHertz: 16000,
      languageCode: 'ko-KR',
    );
    var audio = RecognitionAudio(uri: audioUri);
    var request = RecognizeRequest(config: config, audio: audio);
    print('4');

    try {
      print('5');
      // Google Cloud Speech-to-Text API 호출
      var response = await speech.speech.recognize(request);

      if (response.results != null) {
        print('6');
        for (var result in response.results!) {
          print('7');
          if (result.alternatives != null) {
            print('8');
            for (var alternative in result.alternatives!) {
              print('Transcript: ${alternative.transcript}');
            }
          }
        }
      } else {
        // response.results가 null인 경우 처리
        print('No results found.');
      }

    } catch (e) {
      print('Error: $e');
    }
  }

  void Start() async {

    print('start');
    //_requestExternalStoragePermission();
    String fileName = generateFileName();
    _startRecording(fileName);
  }

  void Reqest() async {
    print('request');
    await _stopRecording(); // 녹음 중지
    await uploadFileToGCS(); // 파일 업로드
    await result(jsonString); // 결과 처리
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Recorder'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
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
            const SizedBox(
              height: 20,
            ),
            const Text("녹음 내용")
          ],
        ),
      ),
    );
  }
}