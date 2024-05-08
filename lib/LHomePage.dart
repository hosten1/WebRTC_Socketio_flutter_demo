

import 'dart:convert';

import 'package:flutter/material.dart';

import 'network/socket_io_client.dart';

class LApp extends StatelessWidget {
  const LApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LHomePage(title: 'WebRTC Demo'),
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
  int _counter = 0;
  SocketIOClient socketIOClient = SocketIOClient(urlStr:"https://39.97.110.12:443");
  void _incrementCounter() {
    if(!socketIOClient.socket.connected){
      socketIOClient.connect();
      socketIOClient.socket.emit('join', '123456');
      print("_incrementCounter");
    }


    setState(() {
      var person = {
        'type': 'offer',
        'sdp': {
          'type': 'offer',
          'sdp': '123456'
        },

      };

      var json = jsonEncode(person);

      socketIOClient.socket.emit('message', ['123456',person]);

      _counter++;
    });
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
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
