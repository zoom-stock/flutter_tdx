import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as Math;
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:tdx/src/data.dart';
import 'package:tdx/src/socket_client.dart';

part 'package:tdx/src/_commands.dart';
part 'package:tdx/src/_stream.dart';

enum Category {
  m5, //0
  m15, //1
  m30, //2
  hour, //3
  day, //4
  week, //5
  month, //6
  m1, //7
  _m1, //8
  _d, //9
  season, //10
  year, //11

}
enum Market {
  sz, //0 深圳
  sh //1 上海

}

class TdxQuotesReader {
  static Quote parseForDay(Uint8List bytes, int start) {
    int time = HexUtils.readInt(bytes, start);
    double open = HexUtils.readInt(bytes, start + 4) / 100.0;
    double high = HexUtils.readInt(bytes, start + 8) / 100.0;
    double low = HexUtils.readInt(bytes, start + 12) / 100.0;
    double close = HexUtils.readInt(bytes, start + 16) / 100.0;
    double amt = HexUtils.readInt(bytes, start + 20) / 100.0;
    int vol = HexUtils.readInt(bytes, start + 24);
    Quote quote = new Quote();
    quote.date = GetQuotesCommand.getDateYmd(
        time ~/ 10000, time % 10000 ~/ 100, time % 10000 % 100);
    quote.close = (close);
    quote.open = (open);
    quote.low = (low);
    quote.high = (high);
    quote.vol = (vol);
    quote.amt = (amt);
    return quote;
  }

  static String parseDate(ByteData bdata, int start) {
    int time = bdata.getUint16(start);
    int year = time ~/ 2048 + 2004;
    int month = time % 2048 ~/ 100;
    int date = time % 2048 % 100;
    int minute = bdata.getUint16(start + 2);
    int hour = minute ~/ 60;
    minute %= 60;
    return GetQuotesCommand.getDate(year, month, date, hour, minute);
  }

  static Quote parseForMin(Uint8List bytes, int start) {
    ByteData bdata = new ByteData.view(bytes.buffer);
    String date = parseDate(bdata, start);
    double open = bdata.getFloat32(start + 4);
    double high = bdata.getFloat32(start + 8);
    double low = bdata.getFloat32(start + 12);
    double close = bdata.getFloat32(start + 16);
    double amt = bdata.getFloat32(start + 20);
    int vol = HexUtils.readInt(bytes, start + 24);
    Quote quote = new Quote();
    quote.date = date;
    quote.close = (close);
    quote.open = (open);
    quote.low = (low);
    quote.high = (high);
    quote.vol = (vol);
    quote.amt = (amt);
    return quote;
  }
}

class TdxClient extends SocketClient {
  TdxClient(String host, int port) : super(host: host, port: port);

  @override
  Future onConnectSuccess(Socket socket) async {
    try {
      await _login();
    } catch (e) {
      await close();
    }
  }

  Future<List<IndexQuote>> getIndexQuotes(
      Category category, Market market, String code, int start, int count) {
    return lock.synchronized(() async {
      return new GetIndexQuotesCommand(
              market: market,
              category: category,
              count: count,
              start: start,
              code: code)
          .process(this);
    });
  }

  Future<int> getCount(Market market) {
    return lock.synchronized(() async {
      return new GetCountCommand(
        market: market,
      ).process(this);
    });
  }

  Future<List<Quote>> getQuotes(
      Category category, Market market, String code, int start, int count) {
    return lock.synchronized(() async {
      return new GetQuotesCommand(
              market: market,
              category: category,
              count: count,
              start: start,
              code: code)
          .process(this);
    });
  }

  List<int> _buffer;
  int _packSize;
  int _uncompressSize;

  TdxInputStream _inputStream = new TdxInputStream();

  void onData(Uint8List data) {
    print("receive data ${data.length}");
    //   print("recv data $data");
    if (_buffer == null) {
      _buffer = data;
    } else {
      if (_buffer is Uint8List) {
        List<int> buffer = new List.from(_buffer);
        _buffer = buffer;
      }
      _buffer += data;
    }
    if (_buffer.length < 0x10) {
      return;
    }
    _inputStream.setData(_buffer);
    //开始解析,此时必然有头
    _inputStream.skip(12);
    _packSize = _inputStream.readShort();
    _uncompressSize = _inputStream.readShort();
    //此后应该有packSize大小，也就是说整个包大小为packSize+0x10
    if (_buffer.length < _packSize + 0x10) {
      return;
    }

    //此时已经接受到了完整的包，需要开始解析了
    if (_packSize != _uncompressSize) {
      //解压缩
      ZLibDecoder decoder = new ZLibDecoder();
      List<int> decoded = decoder.convert(_buffer.sublist(0x10));
      _buffer = decoded;
      _inputStream.setData(_buffer);
    }

    _buffer = null;
    onComplete();
  }

  _login() async {
    await writeHex("0c0218930001030003000d0001");
    await writeHex("0c0218940001030003000d0002");
    await writeHex(
        "0c031899000120002000db0fd5d0c9ccd6a4a8af0000008fc22540130000d500c9ccbdf0d7ea00000002");
  }
}

class TdxClientService {
  static TdxClientService _instance;

  TdxClientService._();

  factory TdxClientService() {
    if (_instance == null) {
      _instance = new TdxClientService._();
    }
    return _instance;
  }

  TdxClient _client = new TdxClient("119.147.212.81", 7709);
  Timer _timer;

  Future start() async {
    //从几个ip中选择一下
    _timer = new Timer.periodic(new Duration(milliseconds: 1000), onTimer);
    return _client.connect();
  }

  void onTimer(Timer tier) {}

  Future<List<Quote>> getQuotes(
      {Category category, Market market, String code, int start, int count}) {
    return _client.getQuotes(category, market, code, start, count);
  }

  Future<List<Quote>> getIndexQuotes(
      {Category category, Market market, String code, int start, int count}) {
    return _client.getIndexQuotes(category, market, code, start, count);
  }

  Future<int> getCount(Market market) {
    return _client.getCount(market);
  }

  Future close() async {
    _timer?.cancel();
    await _client?.close();
  }
}

class HexUtils {
  /// convert string to hex bytes
  static List<int> decodeHex(String data) {
    return hex.decode(data);
  }

  /// convert hex bytes to hex string
  static String encodeHex(List<int> data) {
    return hex.encode(data);
  }

  static int readInt(List<int> data, int start) {
    return data[start + 3] << 24 & 0xff000000 |
        data[start + 2] << 16 & 0xff0000 |
        data[start + 1] << 8 & 0xff00 |
        data[start] & 0xff;
  }
}
