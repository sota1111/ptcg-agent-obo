# SOT-2128 マリィのオーロンゲex デッキ比較

## 結論

マリィのオーロンゲex候補を60枚で構築し、現行の水単 Mega Abomasnow ex と同じ
エージェントで直接比較した。100試合では候補が25勝、現行が75勝だったため、
`deck.csv` は現行構成を維持する。

候補の勝率は25.0%（Wilson 95% CI 17.5–34.3%）で、現行の75.0%
（65.7–82.5%）と信頼区間が分離した。fault、引き分け、未決着はいずれも0だった。

## 候補デッキ（60枚）

| 枚数 | カード | 役割 |
| ---: | --- | --- |
| 9 | Basic Darkness Energy | 主攻撃用エネルギー |
| 3 / 2 / 3 | Marnie's Impidimp / Morgrem / Grimmsnarl ex | 主力進化ライン |
| 2 / 2 | Snorunt / Froslass | ダメージ補助 |
| 4 | Munkidori | ダメカン移動 |
| 1 | Tatsugiri | サポートへのアクセス |
| 1 | Budew | 序盤の妨害 |
| 1 | Yveltal | サブアタッカー |
| 2 | Rare Candy | 進化加速 |
| 3 | Buddy-Buddy Poffin | たね展開 |
| 1 | Secret Box | ACE SPEC |
| 3 | Night Stretcher | リソース回収 |
| 1 | Energy Switch | エネルギー移動 |
| 4 | Poké Pad | トレーナーズへのアクセス |
| 1 | Air Balloon | いれかえ補助 |
| 4 | Boss's Orders | 相手ベンチ呼び出し |
| 1 | Iris's Fighting Spirit | ドロー |
| 4 | Team Rocket's Petrel | 手札干渉 |
| 4 | Lillie's Determination | 手札更新 |
| 4 | Spikemuth Gym | スタジアム |
| **60** | **合計** | |

カードID版は `decks/candidates/sot-2128_marnies_grimmsnarl_ex.csv` に保存した。
構築元は Limitless の deck list 28345。エンジン未収録の Special Red Card 1枚は、
既存の検証済み変換規則に従って Boss's Orders 1枚へ置換している。

## 比較条件

- エンジン: `ptcg-agent-ume` に同梱された cabt 実エンジン
- 方策: このリポジトリの同一 `main.py`
- 対戦: 候補 対 現行の直接対戦100試合
- seed: 212800–212849（各seedで先後を入れ替えた2試合）
- 平均意思決定回数: 120.44
- 結果: 候補25勝 / 現行75勝 / 引き分け・未決着0 / fault 0

## 判断

候補はメタ上位の実績ある構築だが、現在の `main.py` は水単 Mega Abomasnow ex の
単純な展開・攻撃線に合わせた汎用greedy方策である。進化、ダメカン移動、手札干渉を
組み合わせる候補の強みを同じ方策では十分に引き出せず、今回の直接比較では明確に
現行を下回った。候補は再現可能な検討材料として残すが、提出デッキへの昇格は見送る。
