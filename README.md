# mnn - BitBankで自動売買するプログラム「えむぬん」


## はじめに
__無保証__ です。

未完成です。作りながら更新していきます。まだ、 __今は残高を表示するだけ__ です。

### これは何？
このプログラムは、[BitBank](https://bitbank.cc/)で、暗号通貨を売買して利益を出そうとするプログラムです。

もともと、[b5](https://github.com/momoandbanana22/b5)というプログラムを作ったのですが、これを元に作り直しているものがこのmnnです。


### 名前の由来
わたくし「桃芭蕉実」は「桃猫」などと呼ばれているのですが、わたくしの分身的な意味で「__桃猫猫__」という名前をこのプログラムにつけました。日本語読みでももねこねこですが、中国語読みで「__タオマオマオ__」と読めるそうで、音のリズムもよく可愛らしいので、この名前にしました。

プログラムのファイル名は桃猫猫をアルファベットにして __mnn__ で、こちらの読み方は「__えむぬん__」って読んでください。

なお、名前の考察にあたっては、Twitter上で下記の方々にアイデア・ご協力いただきました。ありがとうございます。

名付け協力：「まんぷく 乂 柳生 銭兵衛」さん（Twitter:@skmplife)、「ユーシン@リップラー」さん（Twitter:@phantom_smf)


## 利益を出す仕組み
（説明文中、[ ]で囲っている値は、設定ファイルに記述することで、変更可能です。）

暗号通貨を買います。買った値段の[1.0005]倍の価格で売ります。この動きを繰り返すだけの簡単な仕組みです。

## 使い方
apikey.yamlにbitbankのAPIキーを設定して、mnn.rbを実行してください

## 注意事項
無保証です。

## 最後に
無保証です。
