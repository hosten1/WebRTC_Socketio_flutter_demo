import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webrtc_demo_flutter/peerConnectPage.dart';

import 'network/socket_io_client.dart';

class LServerData {
  final String roomId;
  final String? serverAddr;
  final SocketIOClient? socketIOClient; 

  LServerData({required this.roomId,this.serverAddr, this.socketIOClient});

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'serverAddr': serverAddr,
      'socketIOClient': this.socketIOClient,
    };
  }

  factory LServerData.fromMap(Map<String, dynamic> map) {
    return LServerData(
      roomId: map['roomId'] ?? '',
      serverAddr: map['serverAddr'] ?? '',
      socketIOClient: map['socketIOClient'] ?? '',
    );
  }
}//class LServerData 

class LApp extends StatelessWidget {
  const LApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      routes: {
        '/': (context) => const  LHomePage(title: 'WebRTC Demo'),
        LPeerConnection.routeName: (context) =>  LPeerConnection(),
      },
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      // home: const LHomePage(title: 'WebRTC Demo'),
    );
  }
}

class LHomePage extends StatefulWidget {
  const LHomePage({super.key, required this.title});

  final String title;

  @override
  State<LHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<LHomePage> {
  final TextEditingController _roomController = TextEditingController(text: "123456");

 final TextEditingController _serverAddrController = TextEditingController(text: "39.97.110.12:443");


  @override
  void dispose() {
    _roomController.dispose();
    _serverAddrController.dispose();
    _socketIOClient.disconnect();
    super.dispose();
  }

  late SocketIOClient _socketIOClient ;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _buildList(),
        ),
      ),

    );
  }

  List<Widget> _buildList() {
    return <Widget>[
      _buildTextFiled("服务器地址", _serverAddrController),
      _buildTextFiled("房间号", _roomController),
      SizedBox(
        width: 300,
        height: 90,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround ,
          children: [
            ElevatedButton(
              onPressed: () {
                // 获取输入的文本
                print("按钮被点击了....");
                String inputText = _serverAddrController.text;
                if (inputText.isNotEmpty) {
                  if (inputText.startsWith('https://') || inputText.startsWith('http://')) {
                    // 输入文本不为空且以 "https://" 或 "http://" 开头
                    print('Valid URL: $inputText');
                    inputText = inputText;
                  } else {
                    // 输入文本不为空但不是以 "https://" 或 "http://" 开头
                    print('Invalid URL: $inputText');
                    inputText = "https://$inputText";
                  }
                } else {
                  // 输入文本为空
                  print('Input text is empty.');
                }
                print('Input Text: $inputText');

                _socketIOClient = SocketIOClient(urlStr: inputText);
                if (!_socketIOClient.socket.connected) {
                  _socketIOClient.connect();

                }
              },
              child: const Text("连接房间"),
            ),
            ElevatedButton(
                onPressed: (){
                  String inputText1 = _roomController.text;
                  print('Input Text: $inputText1');
                  if(inputText1.isNotEmpty){
                    // _socketIOClient.socket.emit('join', inputText1);
                    Navigator.pushNamed(context, LPeerConnection.routeName, arguments: LServerData(roomId: inputText1,socketIOClient: _socketIOClient));
                  }
                },
                child: const Text("加入房间")
            )
          ],
        ),
      ),
    ];
  }
  Widget _buildTextFiled( String labelText,TextEditingController controller) {
    return SizedBox(
      width: 300,
      height: 80,
      child: TextField(
        controller: controller,
        decoration:  InputDecoration(
          hintText: labelText, // 设置提示文本
          labelText: labelText, // 设置标签文本
          border: const OutlineInputBorder(), // 设置边框样式
        ),
      ),
    );
  }
}
