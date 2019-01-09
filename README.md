# feedfollow
気象庁のいろいろのデータフィードを追うプログラム集

Ruby と tarwriter https://github.com/etoyoda/tarwriter が必要です。

## syndl.rb - WIS GISC Tokyo Portal からのダウンロード

WIS GISC Tokyo Portal http://www.wis-jma.go.jp/ では、
RSS の代わりにプレーンテキストのファイルリストを追うようになっています。
それ専用のダウンローダーです。

## feedstore.rb - 気象庁防災情報XMLの逐次ダウンロード

気象庁防災情報XMLを民間提供する方法のひとつとして、
気象庁ホームページから Atom Feed で提供されているものを逐次ダウンロードします。


