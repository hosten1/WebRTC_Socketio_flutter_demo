import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webrtc_demo_flutter/depends/flutter-webrtc/lib/flutter_webrtc.dart';


enum RTCPeerClientIceConnectionState {
  newState,          // 原 RTCPeerClientIceConnectionStateNew
  checking,          // 原 RTCPeerClientIceConnectionStateChecking
  completed,         // 原 RTCPeerClientIceConnectionStateCompleted
  connected,         // 原 RTCPeerClientIceConnectionStateConnected
  failed,            // 原 RTCPeerClientIceConnectionStateFailed
  disconnected,       // 原 RTCPeerClientIceConnectionStateDisconnected
  closed,            // 原 RTCPeerClientIceConnectionStateClosed
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

class PeerConnectionClient {

  /*是否已经调用过setremoteSessionDescription*/
  bool isSetRemoteSDP = false;
  MediaStream? _localStream;
  final Session _session = Session();
  final List<MediaStream> _remoteStreams = <MediaStream>[];
  final List<RTCRtpSender> _senders = <RTCRtpSender>[];
  VideoSource _videoSource = VideoSource.Camera;
  late bool _ifOffer = false;


  Function(MediaStream stream)? onLocalStream;
  Function(Session session, MediaStream stream)? onAddRemoteStream;
  Function(Session session, MediaStream stream)? onRemoveRemoteStream;
  Function(dynamic event)? onPeersUpdate;
  Function(Session session, RTCDataChannel dc, RTCDataChannelMessage data)?
  onDataChannelMessage;
  Function(Session session, RTCDataChannel dc)? onDataChannel;
  //回掉 offer sdp
  Function(String sdp,String type)? onCreateOffer;
  Function(String sdp,String type)? onCreateAnswer;
  // 回调candidate信息
  Function(String candidate,int sdpMLineIndex,String sdpMid)? onIceCandidate;

  Function(RTCPeerClientIceConnectionState state)? onIceConnectionStateChanged;
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
  void createPeerconnection(BuildContext context) async {
    print("lym===> createPeerconnection");
    _createPeerConnection(context);
  }

  void _createPeerConnection(BuildContext context) async {
    if(_session.pc != null){
      print("===> lym _peerConnection already ");
      return;
    }
    _localStream =
    await _createStream('video', false, context: context);

    RTCPeerConnection peerConnection = await createPeerConnection({
      ..._iceServers,
      ...{'sdpSemantics': sdpSemantics}
    }, _config);
    peerConnection.onIceCandidate = (candidate) {
      // print('lym candidate :${candidate.toString()}');
      onIceCandidate?.call(candidate.candidate ?? "", candidate.sdpMLineIndex ?? 0,candidate.sdpMid ?? "");

    };
    peerConnection.onIceConnectionState = (state) {
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
          onIceConnectionStateChanged?.call(RTCPeerClientIceConnectionState.connected);
          currentConnectionType();
          break;
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          onIceConnectionStateChanged?.call(RTCPeerClientIceConnectionState.failed);
          break;
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          onIceConnectionStateChanged?.call(RTCPeerClientIceConnectionState.disconnected);

          break;
        case RTCIceConnectionState.RTCIceConnectionStateClosed:
          onIceConnectionStateChanged?.call(RTCPeerClientIceConnectionState.closed);

        case RTCIceConnectionState.RTCIceConnectionStateNew:
          onIceConnectionStateChanged?.call(RTCPeerClientIceConnectionState.newState);

      // TODO: Handle this case.
        case RTCIceConnectionState.RTCIceConnectionStateChecking:
          onIceConnectionStateChanged?.call(RTCPeerClientIceConnectionState.checking);

      // TODO: Handle this case.
        case RTCIceConnectionState.RTCIceConnectionStateCompleted:
          onIceConnectionStateChanged?.call(RTCPeerClientIceConnectionState.completed);

      // TODO: Handle this case.
        case RTCIceConnectionState.RTCIceConnectionStateCount:
          // onIceConnectionStateChanged?.call(RTCPeerClientIceConnectionState.count);

      // TODO: Handle this case.
      }

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

  Future<void> closePeerConnection() async {
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

  void createOffer() async {
    print("lym===> createOffer");
    _ifOffer = true;
    var offer = await _session.pc?.createOffer();
    var data = {
      'type': 0,
      'sdp': {'type': offer?.type, 'sdp': offer?.sdp},
    };

    var json = jsonEncode(data);
    //如果offer 不是空就回掉
    if (offer != null) {
      onCreateOffer?.call(offer.sdp ?? "", offer.type ?? "");
    }
    _session.pc?.setLocalDescription(_fixSdpH264ToBaseLine(offer!));

    print('lym offer sdp:${offer?.sdp}');
  }
  void receiveOfferSdp(String sdp ,String type) async {
    print('lym receiveOfferSdp _ifOffer:$_ifOffer');
    if(_ifOffer == true){
      print('lym  receiveOfferSdp error current is  offer state');
      return;
    }
    _ifOffer = false;
    print('lym receiveOfferSdp type:$type');
    await _session.pc?.setRemoteDescription(RTCSessionDescription(sdp, type));
    isSetRemoteSDP = true;
    if (_session.remoteCandidates.isNotEmpty) {
      _session.remoteCandidates.forEach((candidate) async {
        await _session.pc?.addCandidate(candidate);
      });
      _session.remoteCandidates.clear();
    }
    _createAnswer(_session);
  }


  /// 收到远端的sdp 设置给WebRTC
  void receiveAnswerSdp(String sdp ,String type) async {
    if(_ifOffer != true){
      print('lym  receiveAnswerSdp error current is not  offer state');
      return;
    }
    print('lym receiveAnswerSdp sdp:${type}');
    await _session.pc?.setRemoteDescription(RTCSessionDescription(sdp, type));
    isSetRemoteSDP = true;
  }
  //收到远端的candidate信息
  void receiveCandidate(String candidateIn,int sdpMLineIndexIn,String sdpMidIn) async {
    print('lym receiveCandidate sdpMidIn:$sdpMidIn');
    RTCIceCandidate candidate = RTCIceCandidate(candidateIn,sdpMidIn,sdpMLineIndexIn as int?);
    if (_session.pc != null || isSetRemoteSDP) {
      await _session.pc?.addCandidate(candidate);
    } else {
      _session.remoteCandidates.add(candidate);
    }
    if (_session.pc != null) {
      await _session.pc?.addCandidate(candidate);
    } else {
      _session.remoteCandidates.add(candidate);
    }
  }

  void _createAnswer(Session session ) async {
    var answer = await session.pc?.createAnswer();
    print('lym >>>>> _createAnswer');
    var data = {
      'type': 1,
      'sdp': {'type': answer?.type, 'sdp': answer?.sdp},
    };

    var json = jsonEncode(data);
    //如果answer不是空就回调
    if (answer != null) {
      onCreateAnswer?.call(answer.sdp ?? "", answer.type ?? "");
    }
    _session.pc?.setLocalDescription(_fixSdpH264ToBaseLine(answer!));

    print('lym answer sdp:${answer?.sdp}');
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

  Future<void> currentConnectionType() async {
    final stats = await _session.pc?.getStats();
    String? selectedType;
    //打印统计信息

    stats?.forEach((report) {
      print('lym report.values:${report.values}');
      if (report.type == 'transport') {

        final pairId = report.values['selectedCandidatePairId'];
        for (var pairReport in stats) {
          if (pairReport.id == pairId && pairReport.type == 'candidate-pair') {
            final localId = pairReport.values['localCandidateId'];
            for (var localReport in stats) {
              if (localReport.id == localId &&
                  localReport.type == 'local-candidate') {
                selectedType = localReport.values['candidateType'];
              }
            }
          }
        }
      }
    });

    if (selectedType == 'relay') {
      print('lym 最终连接方式: 服务器中转');
    } else {
      print('lym 最终连接方式: P2P 打洞');
    }
  }

  /*将H264设置成baseline*/
  RTCSessionDescription _fixSdpH264ToBaseLine(RTCSessionDescription s) {
    var sdp = s.sdp;
    s.sdp =
        sdp!.replaceAll('profile-level-id=640c1f', 'profile-level-id=42e032');
    return s;
  }
}