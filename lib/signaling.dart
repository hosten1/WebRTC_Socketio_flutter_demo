import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webrtc_demo_flutter/depends/socket.io-client-dart/lib/socket_io_client.dart';
import 'network/socket_io_client.dart';
import 'package:webrtc_demo_flutter/depends/flutter-webrtc/lib/flutter_webrtc.dart';


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
enum VideoSource {
  Camera,
  Screen,
}

class Session {
  RTCPeerConnection? pc;
  RTCDataChannel? dc;
  List<RTCIceCandidate> remoteCandidates = [];
}

class Signaling {

  Signaling(this._serverAddr,this._roomId, this._context);

  SocketIOClient? _socketIOClient;

  final BuildContext? _context;
  final _roomId;
  final _serverAddr;
  var _turnCredential;

  String _selfId = '';
  /*是否已经调用过setremoteSessionDescription*/
  bool isSetRemoteSDP = false;
  MediaStream? _localStream;
  final Session _session = Session();
  final List<MediaStream> _remoteStreams = <MediaStream>[];
  final List<RTCRtpSender> _senders = <RTCRtpSender>[];
  VideoSource _videoSource = VideoSource.Camera;
  Function(SignalingState state)? onSignalingStateChange;
  Function(Session session, CallState state)? onCallStateChange;
  Function(MediaStream stream)? onLocalStream;
  Function(Session session, MediaStream stream)? onAddRemoteStream;
  Function(Session session, MediaStream stream)? onRemoveRemoteStream;
  Function(dynamic event)? onPeersUpdate;
  Function(Session session, RTCDataChannel dc, RTCDataChannelMessage data)?
  onDataChannelMessage;
  Function(Session session, RTCDataChannel dc)? onDataChannel;
/*unified-plan plan-b*/
  String get sdpSemantics => 'plan-b';

  final Map<String, dynamic> _iceServers = {
      'iceServers':
      [
        {
          'urls': 'turn:39.97.110.12:3478',
          'username': "lym",
          'credential': "123456"
        },
      ]
  };

  final Map<String, dynamic> _config = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ]
  };

  final Map<String, dynamic> _dcConstraints = {
    'mandatory': {
      'OfferToReceiveAudio': false,
      'OfferToReceiveVideo': false,
    },
    'optional': [],
  };

  close() async {
    await _cleanSessions();
    _socketIOClient?.disconnect();

  }

  void switchCamera() {
    if (_localStream != null) {
      if (_videoSource != VideoSource.Camera) {
        for (var sender in _senders) {
          if (sender.track!.kind == 'video') {
            sender.replaceTrack(_localStream!.getVideoTracks()[0]);
          }
        }
        _videoSource = VideoSource.Camera;
        onLocalStream?.call(_localStream!);
      } else {
        Helper.switchCamera(_localStream!.getVideoTracks()[0]);
      }
    }
  }

  void switchToScreenSharing(MediaStream stream) {
    if (_localStream != null && _videoSource != VideoSource.Screen) {
      _senders.forEach((sender) {
        if (sender.track!.kind == 'video') {
          sender.replaceTrack(stream.getVideoTracks()[0]);
        }
      });
      onLocalStream?.call(stream);
      _videoSource = VideoSource.Screen;
    }
  }

  void muteMic() {
    if (_localStream != null) {
      bool enabled = _localStream!.getAudioTracks()[0].enabled;
      _localStream!.getAudioTracks()[0].enabled = !enabled;
    }
  }
  Future<void> connect() async {

    _initSignal(_context!);
  }
  void join() async {
    _socketIOClient?.socket.emitWithAck("join", _roomId, ack: (data) {
      print(data);
    });
  }
  void _createPeerConnection(BuildContext context) async {
    if(_session.pc != null){
      print("===> lym _peerConnection already ");
      return;
    }
    // Map<String, dynamic> _iceServers = {
    //   'iceServers': [
    //     {
    //       'urls': 'turn:39.97.110.12:3478',
    //       'username': "lym",
    //       'credential': "123456"
    //     },
    //   ]
    // };
    _localStream =
    await _createStream('video', false, context: context);

    RTCPeerConnection peerConnection = await createPeerConnection({
      ..._iceServers,
      ...{'sdpSemantics': sdpSemantics}
    }, _config);
    peerConnection.onIceCandidate = (candidate) {
      // print('lym candidate :${candidate.toString()}');
      _send('message', {'type': 2,
          'candidate': candidate.toMap()});

    };
    switch (sdpSemantics) {
      case 'plan-b':
        peerConnection.onAddStream = (MediaStream stream) {
          onAddRemoteStream?.call(_session, stream);
          _remoteStreams.add(stream);
        };
        await peerConnection!.addStream(_localStream!);
        break;
      case 'unified-plan':
      // Unified-Plan
      // _peerConnection?.onAddStream = (MediaStream stream) {
      //       //   _remoteRenderer.srcObject = stream;
      //       // };
      //       // _peerConnection?.onAddTrack = (stream,track) {
      //       //   _remoteRenderer.srcObject = stream;
      //       // };
        peerConnection.onTrack = (event) {
          if (event.track.kind == 'video') {
            if(event.streams.isNotEmpty){
              onAddRemoteStream?.call(_session, event.streams[0]);
            }else{
              print('lym onAddTrack event.streams.isNotEmpty');
            }


          }
        };
        _localStream!.getTracks().forEach((track) async {
          _senders.add(await peerConnection.addTrack(track, _localStream!));
        });
        break;
    }
    peerConnection.onRemoveStream = (stream) {
      onRemoveRemoteStream?.call(_session, stream);
      _remoteStreams.removeWhere((it) {
        return (it.id == stream.id);
      });
    };
    peerConnection.onDataChannel = (channel) {
      // _addDataChannel(newSession, channel);
    };
     _session.pc = peerConnection;
  }
  void _createOffer() async {
    var offer = await _session.pc?.createOffer();
    var data = {
      'type': 0,
      'sdp': {'type': offer?.type, 'sdp': offer?.sdp},
    };

    var json = jsonEncode(data);

    _send('message', data);
    _session.pc?.setLocalDescription(_fixSdp(offer!));

    print('lym offer sdp:${offer?.sdp}');
  }

  void _createAnswer() async {
    var answer = await _session.pc?.createAnswer();
    print('lym >>>>> _createAnswer');
    var data = {
      'type': 1,
      'sdp': {'type': answer?.type, 'sdp': answer?.sdp},
    };

    var json = jsonEncode(data);

    _send('message', data);
    _session.pc?.setLocalDescription(_fixSdp(answer!));

    print('lym answer sdp:${answer?.sdp}');
  }

  void _setRemoteSdp(RTCSessionDescription sdp) async {
    print('lym _setRemoteSdp sdp:${sdp.sdp}');
    await _session.pc?.setRemoteDescription(sdp);
  }

  Future<MediaStream> _createStream(String media, bool userScreen,
      {BuildContext? context}) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': userScreen ? false : true,
      'video': userScreen
          ? true
          : {
        'mandatory': {
          'minWidth':
          '640', // Provide your own width, height and frame rate here
          'minHeight': '480',
          'minFrameRate': '30',
        },
        'facingMode': 'user',
        'optional': [],
      }
    };
    late MediaStream stream;
    if (userScreen) {
      // if (WebRTC.platformIsDesktop) {
      //   final source = await showDialog<DesktopCapturerSource>(
      //     context: context!,
      //     builder: (context) => ScreenSelectDialog(),
      //   );
      //   stream = await navigator.mediaDevices.getDisplayMedia(<String, dynamic>{
      //     'video': source == null
      //         ? true
      //         : {
      //       'deviceId': {'exact': source.id},
      //       'mandatory': {'frameRate': 30.0}
      //     }
      //   });
      // } else {
      //   stream = await navigator.mediaDevices.getDisplayMedia(mediaConstraints);
      // }
    } else {
      stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    }

    onLocalStream?.call(stream);
    return stream;
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
      print('Connect error: $data');
    });

    _socketIOClient?.socket.on('connect_timeout', (data) {
      print('Connect timeout: $data');
    });
    _socketIOClient?.socket.on('joined', (data) {
      print("lym >>>>> joined:${data}");
      // const {room, id} = data;
      final String id = data["id"] as String;
      final String room = data["roomId"] as String;
      _createPeerConnection(context);
      onCallStateChange?.call(_session, CallState.CallStateNew);

      _selfId = id;
    });
    _socketIOClient?.socket.on('otherJoined', (data) {
      print("lym >>>>> otherJoined:${data}");
      final String id = data["id"] as String;
      if (_selfId == id) {
        return;
      }
      final String room = data["roomId"] as String;
      print("other joined id:$id ownerid:${_selfId} room:${room}");
      onCallStateChange?.call(_session, CallState.CallStateInvite);
      // outputArea.scrollTop = outputArea.scrollHeight;//窗口总是显示最后的内容
      // outputArea.value = outputArea.value + 'otherJoined' + id + '\r';

      // 初始化为webrtc 相关 这里只要对方一加入就 启动webrtc
      _createOffer();
    });
    _socketIOClient?.socket.on('leaved', (data) {
      print("lym >>>>> leaved:${data}");
      final String id = data["id"] as String;
      if (_selfId == id) {
        return;
      }
      final String room = data["roomId"] as String;
      onCallStateChange?.call(_session, CallState.CallStateBye);
      // outputArea.scrollTop = outputArea.scrollHeight;//窗口总是显示最后的内容
      // outputArea.value = outputArea.value + 'otherJoined' + id + '\r';

      // 初始化为webrtc 相关 这里只要对方一加入就 启动webrtc

    });

    _socketIOClient?.socket.on('message', (data) async {
      print("lym >>>>> message:${data}");
      final String id = data["id"] as String;
      if (_selfId == id) {
        return;
      }

      final int type = data["type"] as int;
      switch (type) {
        case 0:
          { // offer
            _setRemoteSdp(
                RTCSessionDescription(data['sdp']['sdp'], data['sdp']['type']));
            isSetRemoteSDP = true;
            if (_session.remoteCandidates.isNotEmpty) {
              _session.remoteCandidates.forEach((candidate) async {
                await _session.pc?.addCandidate(candidate);
              });
              _session.remoteCandidates.clear();
            }
            onCallStateChange?.call(_session, CallState.CallStateNew);
            onCallStateChange?.call(_session, CallState.CallStateRinging);
            _createAnswer();

            break;
          }
        case 1: // answer
          _setRemoteSdp(
              RTCSessionDescription(data['sdp']['sdp'], data['sdp']['type']));
          isSetRemoteSDP = true;
          onCallStateChange?.call(_session, CallState.CallStateConnected);
          break;
        case 2:
          { // candidate
            RTCIceCandidate candidate = RTCIceCandidate(
                data['candidate']['candidate'],
                data['candidate']['sdpMid'],
                data['candidate']['sdpMLineIndex']);
            if (_session.pc != null || isSetRemoteSDP) {
              await _session.pc?.addCandidate(candidate);
            } else {
              _session.remoteCandidates.add(candidate);
            }
            break;
          }
        default:
          print('lym message:$data');
      }
    });
  }

  /*将H264设置成baseline*/
  RTCSessionDescription _fixSdp(RTCSessionDescription s) {
    var sdp = s.sdp;
    s.sdp =
        sdp!.replaceAll('profile-level-id=640c1f', 'profile-level-id=42e032');
    return s;
  }
  _send(event, data) {
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
    if (_localStream != null) {
      _localStream!.getTracks().forEach((element) async {
        await element.stop();
      });
      await _localStream!.dispose();
      _localStream = null;
    }
    if (_session.pc != null) {
      await _session.pc!.close();
      _session.pc = null;

    }
    _senders.clear();
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