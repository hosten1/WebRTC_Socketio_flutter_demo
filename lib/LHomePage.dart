import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webrtc_demo_flutter/peerConnectPage.dart';

class LServerData {
  final String roomId;
  final String? serverAddr;

  LServerData({required this.roomId,this.serverAddr});

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'serverAddr': serverAddr,
    };
  }

  factory LServerData.fromMap(Map<String, dynamic> map) {
    return LServerData(
      roomId: map['roomId'] ?? '',
      serverAddr: map['serverAddr'] ?? '',
    );
  }
}//class LServerData 

class LApp extends StatelessWidget {
  const LApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      routes: <String, WidgetBuilder>{
        '/': (context) => const  LHomePage(title: 'WebRTC Demo'),
      },
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: const Color(0xFF303030),
        scaffoldBackgroundColor: const Color(0xFFebebeb),
        cardColor: const Color(0xFF393a3f),
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
  late String serverAddr;
  late String roomId ;


  @override
  void dispose() {
    _roomController.dispose();
    _serverAddrController.dispose();
    super.dispose();
  }

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
            // ElevatedButton(
            //   onPressed: () {
            //     // 获取输入的文本
            //     print("按钮被点击了....");
            //     String inputText = _serverAddrController.text;
            //     if (inputText.isNotEmpty) {
            //       if (inputText.startsWith('https://') || inputText.startsWith('http://')) {
            //         // 输入文本不为空且以 "https://" 或 "http://" 开头
            //         print('Valid URL: $inputText');
            //         inputText = inputText;
            //       } else {
            //         // 输入文本不为空但不是以 "https://" 或 "http://" 开头
            //         print('Invalid URL: $inputText');
            //         inputText = "https://$inputText";
            //       }
            //       serverAddr = inputText;
            //     } else {
            //       // 输入文本为空
            //       print('Input text is empty.');
            //     }
            //     print('Input Text: $inputText');
            //   },
            //   child: const Text("连接房间"),
            // ),
            ElevatedButton(
                onPressed: (){
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
                        serverAddr = inputText;
                  } else {
                        // 输入文本为空
                        print('Input text is empty.');
                  }
                  String inputText1 = _roomController.text;
                  print('Input Text: $inputText1');
                  roomId = inputText1;
                  if(inputText1.isNotEmpty){
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => LPeerConnection(roomID: roomId, serverAddr: serverAddr)),
                    );
                  }
                },
                child: const Text("确定信息")
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
