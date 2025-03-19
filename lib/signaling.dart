import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webrtc_demo_flutter/depends/socket.io-client-dart/lib/socket_io_client.dart';
import 'network/socket_io_client.dart';

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

enum SignalingState {
  ConnectionOpen,
  ConnectionClosed,
  ConnectionError,
}
enum CallState {
  CallStateNew,
  CallStateRinging,
  CallStateInvite,
  CallStateConnected,
  CallStateBye,
}


class Signaling {

  Signaling(this._serverAddr,this._roomId, this._context);

  SocketIOClient? _socketIOClient;

  final BuildContext? _context;
  final _roomId;
  final _serverAddr;

  String _selfId = '';

  Function(SignalingState state)? onSignalingStateChange;
  Function(CallState state)? onCallStateChange;
  Function(String sdp,String type)? onCallOfferSdpMsg;
  Function(String sdp,String type)? onCallAnswerSdpMsg;
  Function(String candidate,int sdpMLineIndex,String sdpMid)? onCallCandidateMsg;

  close() async {
    await _cleanSessions();
    _socketIOClient?.disconnect();

  }


  void join() async {
    _socketIOClient?.socket.emitWithAck("join", _roomId, ack: (data) {
      print(data);
    });
  }
  Future<void> connect() async {

    _initSignal(_context!);
  }





  _initSignal(BuildContext context) async{
    if (_socketIOClient != null) {
      print("lym _initSignal 已经初始化了");
      return;
    }
    _socketIOClient = SocketIOClient(urlStr: _serverAddr);
    if (!_socketIOClient!.socket.connected) {
      _socketIOClient?.connect();
    }
    print("lym >>>>> _initSignal:${_roomId}");
    _socketIOClient?.socket.onConnect((_) async {
      onSignalingStateChange?.call(SignalingState.ConnectionOpen);
    });
    _socketIOClient?.socket.onDisconnect((_) async {
      onSignalingStateChange?.call(SignalingState.ConnectionClosed);
    });
    _socketIOClient?.socket.onError((data) async {
      print('Error: $data');
      onSignalingStateChange?.call(SignalingState.ConnectionError);
    });

    _socketIOClient?.socket.on('connect_error', (data) {
      print('lym >>>> Connect error: $data');
    });

    _socketIOClient?.socket.on('connect_timeout', (data) {
      print('lym >>>> Connect timeout: $data');
    });
    _socketIOClient?.socket.on('joined', (data) {
      print("lym >>>>> joined:${data}");
      // const {room, id} = data;
      final String id = data["id"] as String;
      final String room = data["roomId"] as String;
      onCallStateChange?.call( CallState.CallStateNew);

      _selfId = id;
    });
    _socketIOClient?.socket.on('otherJoined', (data) {
      print("lym >>>>> otherJoined:${data}");
      final String id = data["id"] as String;
      if (_selfId == id) {
        return;
      }
      final String room = data["roomId"] as String;
      print("lym >>>>> otherJoined id:$id ownerid:${_selfId} room:${room}");
      onCallStateChange?.call(CallState.CallStateInvite);
      // outputArea.scrollTop = outputArea.scrollHeight;//窗口总是显示最后的内容
      // outputArea.value = outputArea.value + 'otherJoined' + id + '\r';

      // 初始化为webrtc 相关 这里只要对方一加入就 启动webrtc
    });
    _socketIOClient?.socket.on('leaved', (data) {
      print("lym >>>>> leaved:${data}");
      final String id = data["id"] as String;
      if (_selfId == id) {
        return;
      }
      final String room = data["roomId"] as String;
      onCallStateChange?.call(CallState.CallStateBye);
      // outputArea.scrollTop = outputArea.scrollHeight;//窗口总是显示最后的内容
      // outputArea.value = outputArea.value + 'otherJoined' + id + '\r';

      // 初始化为webrtc 相关 这里只要对方一加入就 启动webrtc

    });

    _socketIOClient?.socket.on('message', (data) async {
      final String id = data["id"] as String;
      if (_selfId == id) {
        // 输出错误信息  表示和自己的id 相同的消息不处
        print("lym >>>>> err message:_selfId is ${_selfId}");
        return;
      }

      final int type = data["type"] as int;
      switch (type) {
        case 0:
          { // offer
            print("lym >>>>> message offer:${data}");

            // onCallStateChange?.call(CallState.CallStateNew);
            onCallStateChange?.call(CallState.CallStateRinging);
            onCallOfferSdpMsg?.call(data['sdp']['sdp'],data['sdp']['type']);

            break;
          }
        case 1: // answer
          print("lym >>>>> message answer:${data}");

          onCallStateChange?.call(CallState.CallStateConnected);
          onCallAnswerSdpMsg?.call(data['sdp']['sdp'],data['sdp']['type']);
          break;
        case 2:
          { // candidate
            onCallCandidateMsg?.call(data['candidate']['candidate'],data['candidate']['sdpMLineIndex'],data['candidate']['sdpMid']);
            break;
          }
        default:
          print('lym message:$data');
      }
    });
  }


  send(event, data) {
    var person = {
      'roomId': _roomId,
      'id': _selfId,
    };
    person.addAll(data);
    _socketIOClient?.socket.emit('message', person);
  }

  Future<void> _cleanSessions() async {
    if (_socketIOClient != null) {
      _socketIOClient?.socket
          .emitWithAck("leave", {'roomId':_roomId, 'id':_selfId}, ack: (data) {});
    }
  }

  // void _closeSessionByPeerId(String peerId) {
  //   var session;
  //   _sessions.removeWhere((String key, Session sess) {
  //     var ids = key.split('-');
  //     session = sess;
  //     return peerId == ids[0] || peerId == ids[1];
  //   });
  //   if (session != null) {
  //     _closeSession(session);
  //     // onCallStateChange?.call(session, CallState.CallStateBye);
  //   }
  // }
  //
  // Future<void> _closeSession(Session session) async {
  //   _localStream?.getTracks().forEach((element) async {
  //     await element.stop();
  //   });
  //   await _localStream?.dispose();
  //   _localStream = null;
  //
  //   await session.pc?.close();
  //   await session.dc?.close();
  //   _senders.clear();
  //   _videoSource = VideoSource.Camera;
  // }
}// Signaling end