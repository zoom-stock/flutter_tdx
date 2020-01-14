import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:synchronized/synchronized.dart';

abstract class SocketClient {
  Socket _socket;
  Lock _lock = new Lock(reentrant: true);
  String host;
  int port;
  Completer _completer;

  SocketClient({this.host, this.port});

  Lock get lock => _lock;

  Future connect() {
    assert(_socket == null);
    return _lock.synchronized(() async {
      _socket = await Socket.connect(host, port);
      print("Connect to host $host success");
      _socket.listen(onData, onDone: _onDone, onError: _onError);
      await onConnectSuccess(_socket);
    });
  }

  void onData(Uint8List data);

  Future close() async {
    return _lock.synchronized(() async {
      if (_socket != null) {
        await _socket.close();
        _socket = null;
      }
    });
  }

  _onError(e) {
    if (_completer != null) {
      if (!_completer.isCompleted) {
        _completer.completeError(e);
        _completer = null;
      }
    }
  }

  void _onDone() async {
    print("======================socket is done,try to reconnect");
    _socket = null;
    try {
      await connect();
    } catch (e) {}
  }

  void onComplete() {
    if (_completer != null) {
      if (!_completer.isCompleted) {
        _completer.complete();
        _completer = null;
      }
    }
  }

  Future onConnectSuccess(Socket socket);

  Future writeHex(String command) {
    return write(hex.decode(command));
  }

  Future write(List<int> command) async {
    if (_socket == null) {
      try {
        await connect();
      } catch (e) {
        throw new Exception("Socket 未连接");
      }
    }
    _completer = new Completer();
    _socket.add(command);
    print("write data to tdx ${command.length}");
    return _completer.future;
  }
}
