素朴な自作言語Ruccolaのコンパイラをセルフホストした  
https://qiita.com/sonota88/items/1e683276541cf1b87b76

---

```sh
  # テスト
rake test
```

---

第1世代: Ruby版 v3 コンパイラ

```sh
  # コンパイル
../rclc ../examples/fibonacci.rcl > fibonacci.exe.txt

  # 実行ファイルを VM で実行
../rclvm fibonacci.exe.txt

  # コンパイル＋実行
../rclrun ../examples/fibonacci.rcl
```

第2世代: Pric版 v3 コンパイラ

```sh
mkdir -p exe

  # 第2世代コンパイラでライフゲームをコンパイル
./rclc ../examples/game_of_life.rcl > exe/game_of_life.exe.txt

  # VM で実行
VERBOSE=1 SKIP=1000 ../rclvm exe/game_of_life.exe.txt

  # コンパイル＋実行
VERBOSE=1 SKIP=1000 ./rclrun ../examples/game_of_life.rcl
```

```sh
  # (1) 第1世代コンパイラで第2世代コンパイラをコンパイル
  # (2) (1) で生成された実行ファイル（第2世代コンパイラ）で第2世代コンパイラ自身をコンパイル

  # 上記 (1), (2) の出力（実行ファイル）が一致することを確認:
./test_selfhost.sh
  # （作者の環境だと 9.2 分程度）

  # Crystal版のVMで確認:
FASTVM=1 ./test_selfhost.sh
  # （作者の環境だと 25.3 秒程度）
```


# Memory layout

```
0--9    unused
10--19  global variables
20--    heap/stack
```
