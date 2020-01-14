part of 'client.dart';

abstract class TxdCommand<T> {
  Future<T> process(TdxClient client);
}

abstract class BaseCommand<T> implements TxdCommand<T> {
  @override
  Future<T> process(TdxClient client) async {
    TdxOutputStream out = new TdxOutputStream();
    doOutput(out);
    await client.write(out.toByteArray());
    return doInput(client._inputStream);
  }

  void doOutput(TdxOutputStream out);

  T doInput(TdxInputStream stream);
}

abstract class ListCommand<T> extends BaseCommand<List<T>> {
  @override
  List<T> doInput(TdxInputStream stream) {
    int count = stream.readShort();
    List<T> result = <T>[];
    for (int i = 0; i < count; ++i) {
      result.add(readItem(stream));
    }
    return result;
  }

  T readItem(TdxInputStream stream);
}

class GetCountCommand extends BaseCommand<int> {
  Market market;

  GetCountCommand({this.market});

  @override
  int doInput(TdxInputStream stream) {
    return stream.readShort();
  }

  @override
  void doOutput(TdxOutputStream out) {
    out.writeHexString("0c0c186c0001080008004e04");
    out.writeShort(market.index);
    out.writeHexString("75c73301");
  }
}

class GetIndexQuotesCommand extends GetQuotesCommand<IndexQuote> {
  GetIndexQuotesCommand(
      {Market market, int count, int start, Category category, String code})
      : super(
            market: market,
            count: count,
            start: start,
            category: category,
            code: code);

  @override
  Quote createQuote() {
    return new IndexQuote();
  }

  @override
  IndexQuote readItem(TdxInputStream stream) {
    IndexQuote quote = super.readItem(stream);
    int upCouont = stream.readShort();
    int downCount = stream.readShort();
    quote.upCount = upCouont;
    quote.downCount = downCount;
    return quote;
  }
}

class GetQuotesCommand<T extends Quote> extends ListCommand<T> {
  Market market;
  Category category;
  String code;
  int count;
  int start;

  GetQuotesCommand(
      {this.market, this.count, this.start, this.category, this.code}) {
    if (count > 800) {
      count = 800;
    }
  }

  double preDiffBase = 0;

  @override
  void doOutput(TdxOutputStream outputStream) {
    outputStream.writeShort(0x10c);
    outputStream.writeInt(0x01016408);
    outputStream.writeShort(0x1c);
    outputStream.writeShort(0x1c);
    outputStream.writeShort(0x052d);

    outputStream.writeShort(market.index);
    outputStream.writeAscii(code);
    outputStream.writeShort(category.index);
    outputStream.writeShort(1);
    outputStream.writeShort(start);
    outputStream.writeShort(count);

    outputStream.writeInt(0);
    outputStream.writeInt(0);
    outputStream.writeShort(0);
  }

  static String readDate(TdxInputStream inputStream, int category) {
    int year;
    int month;
    int hour;
    int minute;
    int day;
    if (category < 4 || category == 7 || category == 8) {
      int zipday = inputStream.readShort();
      int tminutes = inputStream.readShort();
      year = (zipday >> 11) + 2004;
      month = ((zipday % 2048) ~/ 100);
      day = (zipday % 2048) % 100;

      hour = (tminutes ~/ 60);
      minute = tminutes % 60;
      return getDate(year, month, day, hour, minute);
    } else {
      int zipday = inputStream.readInt();
      year = (zipday ~/ 10000);
      month = ((zipday % 10000) ~/ 100);
      day = zipday % 100;
      return getDateYmd(year, month, day);
    }
  }

  static String getDateYmd(int year, int month, int date) {
    return "${toFixed(year)}${toFixed(month)}${toFixed(date)}";
  }

  static String getDate(int year, int month, int date, int hour, int minute) {
    return "${toFixed(year)}${toFixed(month)}${toFixed(date)}${toFixed(hour)}${toFixed(minute)}";
  }

  static String toFixed(int num) {
    if (num < 10) {
      return "0$num";
    }
    return "$num";
  }

  static double getPrice(double base, double diff) {
    return (base + diff) / 1000;
  }

  Quote createQuote() {
    return new Quote();
  }

  @override
  T readItem(TdxInputStream stream) {
    String date = readDate(stream, category.index);
    double priceOpenDiff = stream.getPrice();
    double priceCloseDiff = stream.getPrice();
    double priceHighDiff = stream.getPrice();
    double priceLowDiff = stream.getPrice();

    int volRow = stream.readInt();
    int vol = getVolumn(volRow).toInt();
    int dbvolRow = stream.readInt();
    double amt = getVolumn(dbvolRow);

    double open = getPrice(priceOpenDiff, preDiffBase);
    priceOpenDiff = priceOpenDiff + preDiffBase;

    double close = getPrice(priceOpenDiff, priceCloseDiff);
    double high = getPrice(priceOpenDiff, priceHighDiff);
    double low = getPrice(priceOpenDiff, priceLowDiff);

    preDiffBase = priceOpenDiff + priceCloseDiff;
    T quote = createQuote();

    quote.date = (date);
    quote.close = (close);
    quote.open = (open);
    quote.high = (high);
    quote.low = (low);
    quote.vol = (vol);
    quote.amt = (amt);
//    quote.upCount = upCouont;
//    quote.downCount = downCount;
    return quote;
  }

  static double getVolumn(int ivol) {
    int logpoint = ivol >> (8 * 3);
    int hleax = (ivol >> (8 * 2)) & 0xff;
    int lheax = (ivol >> 8) & 0xff;
    int lleax = ivol & 0xff;

    int dwEcx = logpoint * 2 - 0x7f;
    int dwEdx = logpoint * 2 - 0x86;
    int dwEsi = logpoint * 2 - 0x8e;
    int dwEax = logpoint * 2 - 0x96;

    int tmpEax;
    if (dwEcx < 0) {
      tmpEax = -dwEcx;
    } else {
      tmpEax = dwEcx;
    }

    double dblXmm6 = 0.0;
    dblXmm6 = Math.pow(2.0, tmpEax);
    if (dwEcx < 0) {
      dblXmm6 = 1.0 / dblXmm6;
    }

    double dblXmm4 = 0;
    double tmpdblXmm3;
    if (hleax > 0x80) {
      tmpdblXmm3 = 0.0;
      int dwtmpeax = dwEdx + 1;
      tmpdblXmm3 = Math.pow(2.0, dwtmpeax);
      double dblXmm0 = Math.pow(2.0, dwEdx) * 128.0;
      dblXmm0 += (hleax & 0x7f) * tmpdblXmm3;
      dblXmm4 = dblXmm0;
    } else {
      double dblXmm0 = 0.0;
      if (dwEdx >= 0) {
        dblXmm0 = Math.pow(2.0, dwEdx) * hleax;
      } else {
        dblXmm0 = (1 / Math.pow(2.0, dwEdx)) * hleax;
        dblXmm4 = dblXmm0;
      }
    }

    double dblXmm3 = Math.pow(2.0, dwEsi) * lheax;
    double dblXmm1 = Math.pow(2.0, dwEax) * lleax;
    if ((hleax & 0x80) != 0) {
      dblXmm3 *= 2.0;
      dblXmm1 *= 2.0;
    }

    double dblRet = dblXmm6 + dblXmm4 + dblXmm3 + dblXmm1;
    return dblRet;
  }
}
