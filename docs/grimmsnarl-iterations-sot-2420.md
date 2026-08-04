# SOT-2420 マリィのオーロンゲex 対戦・改善

## 結論

マリィのオーロンゲex 60枚構成を `deck.csv` に採用し、cabt実エンジン上で
`ptcg-agent-matsu`、`ptcg-agent-ume`、`ptcg-agent-gpt` と対戦した。初期対戦後に方策を更新して
再対戦する工程を3回実施した。faultは全12試合で0だった。

| ラウンド | 変更 | 勝敗 | 判断 |
| --- | --- | ---: | --- |
| 初期 | SOT-2128専用方策 | 0勝3敗 | 改善へ |
| 改善1 | Munkidoriより主力への初回エネを優先 | 0勝3敗 | 継続 |
| 改善2 | Impidimp/Munkidori/Poffin/Rare Candy/Poké Padの展開を優先 | 2勝1敗 | 昇格 |
| 改善3 | 主力2エネ後にMunkidoriへ配分 | 0勝3敗 | 棄却 |

第2改善では松・GPTに勝ち、梅に敗れた。第3改善は全敗したため、最後に試した変更を機械的に
採用せず、第2改善を既定方策（strategy version 2）とした。各ラウンドは探索用の3試合なので、
勝率差の統計的確証ではない。今後のconfirmでは同一seed・両席の試合数を増やす。

## 再現方法

`GRIMMSNARL_STRATEGY_VERSION=0..3` を設定して `scripts/ptcg_real_runtime_match.py` を実行する。
未指定時は昇格済みversion 2になる。生の試合結果は
`artifacts/sot-2420-grimmsnarl-iterations/matches.jsonl`、集計は同ディレクトリの
`summary.json` に保存した。
