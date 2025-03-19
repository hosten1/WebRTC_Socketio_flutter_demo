import 'dart:convert';
import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:webrtc_demo_flutter/depends/flutter-webrtc/lib/flutter_webrtc.dart';
import 'package:webrtc_demo_flutter/network/socket_io_client.dart';

import 'package:webrtc_demo_flutter/signaling.dart';

import 'package:webrtc_demo_flutter/peerConnectionClient.dart';

class LPeerConnection extends StatefulWidget {
  const LPeerConnection({super.key,required this.roomID,required this.serverAddr});
  final String roomID ;
  final String serverAddr;

  static const String routeName = '/peerConnection';

  @override
  State<LPeerConnection> createState() => _LPeerConnectionState();
}

class _LPeerConnectionState extends State<LPeerConnection> {

   Signaling? _signaling;
   PeerConnectionClient _peerConnectionClient = PeerConnectionClient();
    List<dynamic> _peers = [];
    String? _selfId;

    SocketIOClient? _socketIOClient;

  bool _inCalling = false;
  Session? _session;
  DesktopCapturerSource? selected_source_;
  bool _waitAccept = false;

  RTCPeerConnection? _peerConnection;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  List<MediaStream> _remoteStreams = <MediaStream>[];
  List<RTCRtpSender> _senders = <RTCRtpSender>[];

  MediaStream? _localStream;

  String _ownerId = "";
  MediaStream? _remoteStream;


  @override
  void initState() {
    super.initState();

    _initRenderers();
    _connect(context);
  }

  @override
  void deactivate() {
    super.deactivate();
    _signaling?.close();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
  }

  @override
  Widget build(BuildContext context) {

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
                      heroTag: 'Camera',
                      tooltip: 'Camera',
                      onPressed: _switchCamera,
                      child: const Icon(Icons.switch_camera),
                    ),
                    // FloatingActionButton(
                    //   child: const Icon(Icons.desktop_mac),
                    //   tooltip: 'Screen Sharing',
                    //   onPressed: () => selectScreenSourceDialog(context),
                    // ),
                    FloatingActionButton(
                      heroTag: 'hangup',
                      onPressed: _hangUp,
                      tooltip: 'Hangup',
                      child: Icon(Icons.call_end),
                      backgroundColor: Colors.pink,
                    ),
                    FloatingActionButton(
                      heroTag: 'Mute Mic',
                      child: const Icon(Icons.mic),
                      tooltip: 'Mute Mic',
                      onPressed: _muteMic,
                    )
                  ]))
          : FloatingActionButton(
              heroTag: 'join',
              onPressed: () {
                _signaling?.join();
              },
              tooltip: 'join',
              backgroundColor: Colors.pink,
              child: const Icon(Icons.join_full),
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
   void _initRenderers() async {
     await _localRenderer.initialize();
     await _remoteRenderer.initialize();
   }
   void _connect(BuildContext context) async {
     // 1. 初始化socketio
     _signaling ??= Signaling(widget.serverAddr,widget.roomID, context)..connect();
     // 2. 监听信令和服务连接的状态
     _signaling?.onSignalingStateChange = (SignalingState state) {
       switch (state) {
         case SignalingState.ConnectionClosed:
         case SignalingState.ConnectionError:
           break;
         case SignalingState.ConnectionOpen:
           _peerConnectionClient?.createPeerconnection(context);
           break;
       }
     };
    // 3. 监听信令消息
     _signaling?.onCallStateChange = (CallState state) async {
       switch (state) {
         case CallState.CallStateNew:
           {
             setState(() {
               _inCalling = true;
               // _session = session;
             });
             break;
           }
         case CallState.CallStateRinging:
           {
             // bool? accept = await _showAcceptDialog();
             setState(() {
               _inCalling = true;
             });
             break;
           }
         case CallState.CallStateBye:
           {
             if (_waitAccept) {
               print('peer reject');
             }
             setState(() {
               _localRenderer.srcObject = null;
               _remoteRenderer.srcObject = null;
               _inCalling = false;
               _session = null;
             });
             _signaling?.close();
             _waitAccept = false;
             Navigator.of(context).pop(true);
             break;
           }
         case CallState.CallStateInvite:
           {
             _waitAccept = true;
             _peerConnectionClient?.createOffer();

             // _showInvateDialog();
             break;
           }
         case CallState.CallStateConnected:
           {
             if (_waitAccept) {
               _waitAccept = false;
               // Navigator.of(context).pop(false);
             }
             setState(() {
               _inCalling = true;
             });

             break;
           }
       }
     };
     // 4. 收到offer消息
     _signaling?.onCallOfferSdpMsg = ((String sdp,String type) {
       //输出 sdp 信息
       print('lym onCallOfferSdpMsg type: $type  _peerConnectionClient: $_peerConnectionClient ');
        _peerConnectionClient.receiveOfferSdp(sdp, type);
       print('lym onCallOfferSdpMsg type: $type  _peerConnectionClient: $_peerConnectionClient  end');
     });
     // 5. 收到answer消息
     _signaling?.onCallAnswerSdpMsg = ((String sdp,String type) {
       print('lym onCallAnswerSdpMsg type: $type  _peerConnectionClient: $_peerConnectionClient');
       _peerConnectionClient.receiveAnswerSdp(sdp, type);

     });
     // 5. 收到ice消息
     _signaling?.onCallCandidateMsg = ((String candidate,int sdpMLineIndex,String sdpMid) {
       _peerConnectionClient.receiveCandidate(candidate, sdpMLineIndex, sdpMid);
     });
     // 6. 本地视频显示到界面
     _peerConnectionClient.onLocalStream = ((stream) {
       _localRenderer.srcObject = stream;
       setState(() {});
     });
     // 7. 远端视频显示到界面
     _peerConnectionClient.onAddRemoteStream = ((_, stream) {
       _remoteRenderer.srcObject = stream;
       setState(() {});
     });
    // 8. 远端视频移除
     _peerConnectionClient.onRemoveRemoteStream = ((_, stream) {
       _remoteRenderer.srcObject = null;
     });
     // 9. 返回WebRTC的offer消息，通过服务发送给对端
     _peerConnectionClient.onCreateOffer = ((String sdp,String type){
       _signaling?.send('message', {'type': 0,
         'sdp': {
           'sdp': sdp,
           'type': type,
         }
       });
     });
     // 10. 返回WebRTC的answer消息，通过服务发送给对端
     _peerConnectionClient.onCreateAnswer = ((String sdp,String type){
       _signaling?.send('message', {'type': 1,
         'sdp': {
           'sdp': sdp,
           'type': type,
         }
       });
     });
     // 11. 返回WebRTC的ice消息，通过服务发送给对端
     _peerConnectionClient.onIceCandidate = ((String candidate,int sdpMLineIndex,String sdpMid){
         _signaling?.send('message', {'type': 2,
         'candidate': {
             'candidate': candidate,
             'sdpMLineIndex': sdpMLineIndex,
             'sdpMid': sdpMid,
         }
         });
     });


   }


   _hangUp() {
    print('lym>>>> hungup');
    _peerConnectionClient.closePeerConnection();
    _signaling?.close();
    Navigator.of(context).pop(true);
   }
   _muteMic() {
     _peerConnectionClient.muteMic();
   }

   _switchCamera() {
     _peerConnectionClient.switchCamera();
   }
}
