import 'package:flutter_test/flutter_test.dart';

import 'package:tdx/tdx.dart';

void main() {
  test('获取产品数量', () async {
    TdxClientService clientService = new TdxClientService();
    await clientService.start();
    int count0 = await clientService.getCount(Market.sh);
    print("获取到的数量为$count0");
    int count1 = await clientService.getCount(Market.sz);
    print("获取到的数量为$count1");

    List<Quote> quotes = await clientService.getQuotes(category: Category.day,
    market: Market.sz,code: "000001",count: 100,start: 1);

    print("获取到的k线熟练为${quotes.length}");
    expect(quotes.length, 100);



    List<Quote> indexQuotes = await clientService.getIndexQuotes(category: Category.day,
        market: Market.sh,code: "000001",count: 100,start: 1);

    print("获取到的k线熟练为${indexQuotes.length}");
    expect(indexQuotes.length, 100);

  });
}
