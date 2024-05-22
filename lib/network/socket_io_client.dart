import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
// import 'package:http/http.dart' as http;
// import 'package:crypto/crypto.dart'; // 仅在需要校验证书时使用
import 'dart:io';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        // 接受所有证书，包括自签名证书
        return true;
      };
  }
}

class SocketIOClient {
  final String _urlStr;
  final IO.Socket socket;

  SocketIOClient({required String urlStr})
      : _urlStr = urlStr,
        socket =
            IO.io(urlStr /*'https://39.97.110.12:443'*/, <String, dynamic>{
          'transports': ['websocket'],
        }){

  }

  Future<void> connect() async {
    try {
      await _connect();
    } on Exception catch (e) {
      // 处理连接过程中的异常
      print('Connect error: $e');
    }
  }

  void disconnect() {
    socket.dispose();
  }

  void sendMessage(String method, String message) {
    sendMessageAck(method, message, ack: (data) {
      print('Received ack: $data');
    });
  }

  void sendMessageAck(String method, String message,
      {Function? ack, bool binary = false}) {
    socket.emitWithAck(method, message, ack: ack, binary: binary);
  }

  Future<bool> _connect() async {


    socket.connect();
    return true;
  }
}
