
# 通达信客户端FLUTTER版本

目前仅支持基本行情查询，之后有时间再搞出扩展和交易接口

## 功能列表

#### 基本行情

    + [x] 查询交易品种
    + [x] 查询板块信息
    + [x] 查询k线


 ```
 import 'package:tdx/tdx.dart';


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
 ```