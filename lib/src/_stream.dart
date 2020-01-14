part of 'client.dart';

class TdxOutputStream {
  List<int> _data;

  TdxOutputStream() : _data = [];

  void writeInt(int i) {
    write(i & 0xff);
    write((i >> 8) & 0xff);
    write((i >> 16) & 0xff);
    write((i >> 24) & 0xff);
  }

  void write(int i) {
    _data.add(i);
  }

  void writeAscii(String str) {
    Uint8List list = ascii.encode(str);
    _data.addAll(list);
  }

  void writeFloat(double value) {
    writeInt((value * 1000).round());
  }

  void writeShort(int i) {
    write(i & 0xff);
    write((i >> 8) & 0xff);
  }

  void clear() {
    _data.clear();
  }

  List<int> toByteArray() {
    return _data;
  }

  void writeHexString(String str) {
    _data.addAll(hex.decode(str));
  }
}

class TdxInputStream {
  List<int> _data;
  int _pos;
  int _count;

  TdxInputStream();

  bool get hasData => _pos < _count;

  void setData(List<int> data) {
    this._data = data;
    this._pos = 0;
    this._count = data.length;
  }

  int readShort() {
    int first = read();
    int second = read();
    return (first & 0xff) | ((second << 8) & 0xff00);
  }

  int read() {
    return (_pos < _count) ? (_data[_pos++] & 0xff) : -1;
  }

  void skip(int n) {
    _pos += n;
  }

  int readInt() {
    int a0 = read();
    int a1 = read();
    int a2 = read();
    int a3 = read();

    return (a0 & 0xff) |
        ((a1 << 8) & 0xff00) |
        ((a2 << 16) & 0xff0000) |
        ((a3 << 24) & 0xff000000);
  }

  double getPrice() {
    int posByte = 6;
    int bdata = readByte();
    int intdata = bdata & 0x3f;
    bool sign;
    if ((bdata & 0x40) != 0) {
      sign = true;
    } else {
      sign = false;
    }
    if ((bdata & 0x80) != 0) {
      while (true) {
        bdata = readByte();
        intdata += (bdata & 0x7f) << posByte;
        posByte += 7;

        if ((bdata & 0x80) != 0) {
          continue;
        }
        break;
      }
    }

    if (sign) {
      intdata = -intdata;
    }
    return intdata.toDouble();
  }

  int readByte() {
    return read();
  }
}
