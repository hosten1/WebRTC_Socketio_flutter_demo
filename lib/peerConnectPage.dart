import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webrtc_demo_flutter/depends/flutter-webrtc/lib/flutter_webrtc.dart';
import 'package:webrtc_demo_flutter/network/socket_io_client.dart';

class LPeerConnection extends StatefulWidget {
  LPeerConnection({super.key});

  static const String routeName = '/peerConnection';

  @override
  State<LPeerConnection> createState() => _LPeerConnectionState();
}

class _LPeerConnectionState extends State<LPeerConnection> {
  SocketIOClient? _socketIOClient;

  // _LPeerConnectionState(this._socketIOClient);

  RTCPeerConnection? _peerConnection;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final List<RTCRtpSender> _senders = <RTCRtpSender>[];

  MediaStream? _localStream;
  bool _inCalling = false;
  bool _isTorchOn = false;
  bool _isMuted = false;
  bool _isFrontCamera = false;
  void _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  void _createPeerConnection() async {
    Map<String, dynamic> _iceServers = {
      'iceServers': [
        {'url': 'stun:stun.l.google.com:19302'},
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
    String sdpSemantics = 'unified-plan';
    _peerConnection = await createPeerConnection({
      ..._iceServers,
      ...{'sdpSemantics': sdpSemantics}
    }, _config);
    // _peerConnection.addTrack(track)
    _peerConnection!.onIceCandidate = (candidate) {
      print('lym candidate :${candidate.toString()}');
    };
    _peerConnection?.onAddTrack = (stream, track) {
      _remoteRenderer.srcObject = stream;
      setState(() {});
    };
    _localStream = await _createStream('', false);
    _localRenderer.srcObject = _localStream;
    _inCalling = true;
    setState(() {});
    _localStream!.getTracks().forEach((track) async {
      RTCRtpSender sender =
          await _peerConnection!.addTrack(track, _localStream!);
      _senders.add(sender);
    });

    var offer = await _peerConnection?.createOffer();
    var person = {
      'type': 'offer',
      'sdp': {'type': offer?.type, 'sdp': offer?.sdp},
    };

    var json = jsonEncode(person);

    _socketIOClient?.socket.emit('message', ['123456', person]);
    _peerConnection?.setLocalDescription(offer!);

    print('lym sdp:${offer?.sdp}');
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
    _localRenderer?.dispose();
    _remoteRenderer?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _socketIOClient ??=
        ModalRoute.of(context)?.settings.arguments as SocketIOClient;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Peer Connection'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings),
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
                      child: const Icon(Icons.switch_camera),
                      tooltip: 'Camera',
                      onPressed: _switchCamera(),
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
                _createPeerConnection();
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
      if (WebRTC.platformIsDesktop) {
        // final source = await showDialog<DesktopCapturerSource>(
        //   context: context!,
        //   builder: (context) => ScreenSelectDialog(),
        // );
        // stream = await navigator.mediaDevices.getDisplayMedia(<String, dynamic>{
        //   'video': source == null
        //       ? true
        //       : {
        //     'deviceId': {'exact': source.id},
        //     'mandatory': {'frameRate': 30.0}
        //   }
        // });
      } else {
        stream = await navigator.mediaDevices.getDisplayMedia(mediaConstraints);
      }
    } else {
      stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    }

    // onLocalStream?.call(stream);
    return stream;
  }

  _switchCamera() {
    print("====>_switchCamera1");
    if (_localStream != null) {
      print("====>_switchCamera2");
      Helper.switchCamera(_localStream!.getVideoTracks()[0]);
    }
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

  void _connection() async {}
  void _disconnect() async {
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
    Navigator.pop(context);
  }
}
