import 'dart:convert';
import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:webrtc_demo_flutter/LHomePage.dart';
import 'package:webrtc_demo_flutter/depends/flutter-webrtc/lib/flutter_webrtc.dart';
import 'package:webrtc_demo_flutter/network/socket_io_client.dart';

import 'package:webrtc_demo_flutter/depends/flutter-webrtc/lib/src/native/media_stream_impl.dart';

class LPeerConnection extends StatefulWidget {
  LPeerConnection({super.key});

  static const String routeName = '/peerConnection';

  @override
  State<LPeerConnection> createState() => _LPeerConnectionState();
}

class _LPeerConnectionState extends State<LPeerConnection> {
  SocketIOClient? _socketIOClient;
  String _roomID = "123456";

  // _LPeerConnectionState(this._socketIOClient);

  RTCPeerConnection? _peerConnection;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  List<MediaStream> _remoteStreams = <MediaStream>[];
  List<RTCRtpSender> _senders = <RTCRtpSender>[];

  MediaStream? _localStream;
  bool _inCalling = false;

  bool _isTorchOn = false;
  bool _isMuted = false;
  bool _isFrontCamera = false;
  bool _isOffer = false;
  String _ownerId = "";
  MediaStream? _remoteStream;
  void _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  void _createPeerConnection(BuildContext context) async {
    if(_peerConnection != null){
      print("===> lym _peerConnection already ");
      return;
    }
    Map<String, dynamic> _iceServers = {
      'iceServers': [
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
    // String sdpSemantics = 'unified-plan';
    String sdpSemantics = 'plan-b';
    _localStream =
    await _createStream('video', false, context: context);

    _peerConnection = await createPeerConnection({
      ..._iceServers,
      ...{'sdpSemantics': sdpSemantics}
    }, _config);
    _peerConnection!.onIceCandidate = (candidate) {
      // print('lym candidate :${candidate.toString()}');
      var person = {
        'roomId': _roomID,
        'id': _ownerId,
        'type': 2,
        'candidate': candidate.toMap(),
      };
      _socketIOClient?.socket.emit('message', person);
    };
    switch (sdpSemantics) {
      case 'plan-b':
        _peerConnection?.onAddStream = (MediaStream stream) {
          _remoteRenderer.srcObject = stream;
          setState(() {});
          _remoteStreams.add(stream);
        };
        await _peerConnection!.addStream(_localStream!);
        break;
      case 'unified-plan':
      // Unified-Plan
      // _peerConnection?.onAddStream = (MediaStream stream) {
      //       //   _remoteRenderer.srcObject = stream;
      //       // };
      //       // _peerConnection?.onAddTrack = (stream,track) {
      //       //   _remoteRenderer.srcObject = stream;
      //       // };
        _peerConnection?.onTrack = (event) {
          if (event.track.kind == 'video') {
            if(event.streams.isNotEmpty){
              _remoteRenderer.srcObject = event.streams[0];
              setState(() {});
            }else{

              // _remoteStream ??= MediaStreamNative(event.track.label!, event.track.id!);
              // _remoteStream?.addTrack(event.track);
              // _remoteRenderer.srcObject = _remoteStream;
            }


          }
        };
        _localStream!.getTracks().forEach((track) async {
          _senders.add(await _peerConnection!.addTrack(track, _localStream!));
        });
        break;
    }
    _peerConnection?.onRemoveStream = (stream) {
      _remoteRenderer.srcObject = null;
      _remoteStreams.removeWhere((it) {
        return (it.id == stream.id);
      });
    };
    _localRenderer.srcObject = _localStream;
    _inCalling = true;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();

    _initRenderers();
  }

  @override
  void deactivate() {
    super.deactivate();
    _disconnect();
  }

  @override
  Widget build(BuildContext context) {
    _initSignal(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Peer Connection'),
        actions: const <Widget>[
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: null,
            tooltip: 'setup',
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _inCalling
          ? SizedBox(
              width: 240.0,
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    FloatingActionButton(
                      tooltip: 'Camera',
                      onPressed: _switchCamera(),
                      child: const Icon(Icons.switch_camera),
                    ),
                    // FloatingActionButton(
                    //   child: const Icon(Icons.desktop_mac),
                    //   tooltip: 'Screen Sharing',
                    //   onPressed: () => selectScreenSourceDialog(context),
                    // ),
                    FloatingActionButton(
                      onPressed: () {
                        _disconnect();
                      },
                      tooltip: 'Hangup',
                      child: Icon(Icons.call_end),
                      backgroundColor: Colors.pink,
                    ),
                    FloatingActionButton(
                      child: const Icon(Icons.mic_off),
                      tooltip: 'Mute Mic',
                      onPressed: _muteMic(),
                    )
                  ]))
          : FloatingActionButton(
              onPressed: () {
                _connection();
              },
              tooltip: 'join',
              child: Icon(Icons.join_inner),
              backgroundColor: Colors.pink,
            ),
      body: OrientationBuilder(builder: (context, orientation) {
        return Container(
          child: Stack(children: <Widget>[
            Positioned(
                left: 0.0,
                right: 0.0,
                top: 0.0,
                bottom: 0.0,
                child: Container(
                  margin: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  decoration: BoxDecoration(color: Colors.black54),
                  child: RTCVideoView(_remoteRenderer),
                )),
            Positioned(
              left: 20.0,
              top: 20.0,
              child: Container(
                width: orientation == Orientation.portrait ? 180.0 : 240.0,
                height: orientation == Orientation.portrait ? 240.0 : 180.0,
                decoration: BoxDecoration(color: Colors.black54),
                child: RTCVideoView(_localRenderer, mirror: true),
              ),
            ),
          ]),
        );
      }),
    );
  }

  void _createOffer() async {
    var offer = await _peerConnection?.createOffer();
    var person = {
      'roomId': _roomID,
      'id': _ownerId,
      'type': 0,
      'sdp': {'type': offer?.type, 'sdp': offer?.sdp},
    };

    var json = jsonEncode(person);

    _socketIOClient?.socket.emit('message', person);
    _peerConnection?.setLocalDescription(_fixSdp(offer!));

    print('lym offer sdp:${offer?.sdp}');
  }

  void _createAnswer() async {
    var answer = await _peerConnection?.createAnswer();
    print('lym >>>>> _createAnswer');
    var person = {
      'roomId': _roomID,
      'id': _ownerId,
      'type': 1,
      'sdp': {'type': answer?.type, 'sdp': answer?.sdp},
    };

    var json = jsonEncode(person);

    _socketIOClient?.socket.emit('message', person);
    _peerConnection?.setLocalDescription(_fixSdp(answer!));

    print('lym answer sdp:${answer?.sdp}');
  }

  void _setRemoteSdp(RTCSessionDescription sdp) async {
    await _peerConnection?.setRemoteDescription(sdp);
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

    // onLocalStream?.call(stream);
    return stream;
  }

  _switchCamera() {
    // print("====>_switchCamera1");
    // if (_localStream != null) {
    //   print("====>_switchCamera2");
    //   Helper.switchCamera(_localStream!.getVideoTracks()[0]);
    // }
  }

  //  _switchToScreenSharing(MediaStream stream) {
  //   if (_localStream != null) {
  //     _senders.forEach((sender) {
  //       if (sender.track!.kind == 'video') {
  //         sender.replaceTrack(stream.getVideoTracks()[0]);
  //       }
  //     });
  //     onLocalStream?.call(stream);
  //     _videoSource = VideoSource.Screen;
  //   }
  // }

  _muteMic() {
    if (_localStream != null) {
      bool enabled = _localStream!.getAudioTracks()[0].enabled;
      _localStream!.getAudioTracks()[0].enabled = !enabled;
    }
  }

  void _connection() async {
    _socketIOClient?.socket.emitWithAck("join", _roomID, ack: (data) {
      print(data);
    });
  }

  void _disconnect() async {
    if (_socketIOClient != null) {
      _socketIOClient?.socket
          .emitWithAck("leave", {'roomId':_roomID, 'id':_ownerId}, ack: (data) {});
    }
    if (_localStream != null) {
      _localStream!.getTracks().forEach((element) async {
        await element.stop();
      });
      await _localStream!.dispose();
      _localStream = null;
    }
    if (_peerConnection != null) {
      await _peerConnection!.close();
      _peerConnection = null;
      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;
    }
    _senders.clear();
    Navigator.pop(context);
  }

  _initSignal(BuildContext context) {
    if (_socketIOClient != null) {
      print("lym _initSignal 已经初始化了");
      return;
    }
    LServerData data =
        ModalRoute.of(context)?.settings.arguments as LServerData;
    _socketIOClient = data.socketIOClient;
    _roomID = data.roomId;
    print("lym >>>>> _initSignal:${_roomID}");
    _socketIOClient?.socket.on('joined', (data) {
      print("lym >>>>> joined:${data}");
      // const {room, id} = data;
      final String id = data["id"] as String;
      final String room = data["roomId"] as String;
      _createPeerConnection(context);
      _ownerId = id;
    });
    _socketIOClient?.socket.on('otherJoined', (data) {
      print("lym >>>>> otherJoined:${data}");
      final String id = data["id"] as String;
      if (_ownerId == id) {
        return;
      }
      final String room = data["roomId"] as String;
      print("other joined id:$id ownerid:${_ownerId} room:${room}");
      // outputArea.scrollTop = outputArea.scrollHeight;//窗口总是显示最后的内容
      // outputArea.value = outputArea.value + 'otherJoined' + id + '\r';

      // 初始化为webrtc 相关 这里只要对方一加入就 启动webrtc
      _isOffer = true;
      _createOffer();
    });
    _socketIOClient?.socket.on('leaved', (data) {
      print("lym >>>>> leaved:${data}");
      final String id = data["id"] as String;
      if (_ownerId == id) {
        return;
      }
      final String room = data["roomId"] as String;

      // outputArea.scrollTop = outputArea.scrollHeight;//窗口总是显示最后的内容
      // outputArea.value = outputArea.value + 'otherJoined' + id + '\r';

      // 初始化为webrtc 相关 这里只要对方一加入就 启动webrtc
      _isOffer = false;
      _disconnect();
      _socketIOClient?.disconnect();
    });

    _socketIOClient?.socket.on('message', (data) {
      print("lym >>>>> message:${data}");
      final String id = data["id"] as String;
      if (_ownerId == id) {
        return;
      }

      final int type = data["type"] as int;
      switch (type) {
        case 0: // offer
          _isOffer = true;
          _setRemoteSdp(
              RTCSessionDescription(data['sdp']['sdp'], data['sdp']['type']));
          _createAnswer();
          break;
        case 1: // answer
          _isOffer = false;
          _setRemoteSdp(
              RTCSessionDescription(data['sdp']['sdp'], data['sdp']['type']));
          break;
        case 2: // candidate
          _peerConnection
              ?.addCandidate(RTCIceCandidate(
                  data['candidate']['candidate'],
                  data['candidate']['sdpMid'],
                  data['candidate']['sdpMLineIndex']))
              .then((value) => () {})
              .onError((error, stackTrace) => () {
                    print('lym error:$error');
                  });
          break;
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
}
