class IndexQuote extends Quote {
  int upCount;
  int downCount;
}

class Quote extends Data {
  String toString() {
    return "$date $open-$close";
  }

  double amt;
  double low;
  double high;
  double open;
  double close;
  int vol;

  Quote(
      {this.low,
      this.high,
      this.vol,
      this.open,
      this.close,
      this.amt,
      String date})
      : super(date: date);

  bool isUp() {
    return close >= open;
  }

  static Quote mapper(v) {
    return Quote(
        low: v['low'],
        high: v['high'],
        open: v['open'],
        close: v['close'],
        date: v['date'],
        vol: v['vol'],
        amt: v['amt']);
  }

  static double getRate(Quote f, Quote l) {
    return (l.close - f.close) / f.close;
  }
}

class Data {
  String date;

  Data({this.date});
}
