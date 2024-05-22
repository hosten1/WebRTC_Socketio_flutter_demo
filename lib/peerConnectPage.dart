import 'dart:convert';
import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:webrtc_demo_flutter/depends/flutter-webrtc/lib/flutter_webrtc.dart';
import 'package:webrtc_demo_flutter/network/socket_io_client.dart';

import 'package:webrtc_demo_flutter/signaling.dart';

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
     _signaling ??= Signaling(widget.serverAddr,widget.roomID, context)..connect();
     _signaling?.onSignalingStateChange = (SignalingState state) {
       switch (state) {
         case SignalingState.ConnectionClosed:
         case SignalingState.ConnectionError:
         case SignalingState.ConnectionOpen:
           break;
       }
     };

     _signaling?.onCallStateChange = (Session session, CallState state) async {
       switch (state) {
         case CallState.CallStateNew:
           setState(() {
             _inCalling = true;
             _session = session;
           });
           break;
         case CallState.CallStateRinging:
         // bool? accept = await _showAcceptDialog();
           setState(() {
             _inCalling = true;
           });
           break;
         case CallState.CallStateBye:
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
         case CallState.CallStateInvite:
           _waitAccept = true;
           // _showInvateDialog();
           break;
         case CallState.CallStateConnected:
           if (_waitAccept) {
             _waitAccept = false;
             // Navigator.of(context).pop(false);
           }
           setState(() {
             _inCalling = true;
           });

           break;
         case CallState.CallStateRinging:
       }
     };

     _signaling?.onPeersUpdate = ((event) {
       setState(() {
         _selfId = event['self'];
         _peers = event['peers'];
       });
     });

     _signaling?.onLocalStream = ((stream) {
       _localRenderer.srcObject = stream;
       setState(() {});
     });

     _signaling?.onAddRemoteStream = ((_, stream) {
       _remoteRenderer.srcObject = stream;
       setState(() {});
     });

     _signaling?.onRemoveRemoteStream = ((_, stream) {
       _remoteRenderer.srcObject = null;
     });
   }

   _hangUp() {
    print('lym>>>> hungup');
    _signaling?.close();
    Navigator.of(context).pop(true);
   }
   _muteMic() {
     _signaling?.muteMic();
   }

   _switchCamera() {
     _signaling?.switchCamera();
   }
}
