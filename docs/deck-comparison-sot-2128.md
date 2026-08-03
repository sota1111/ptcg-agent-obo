# SOT-2128 マリィのオーロンゲex デッキ比較

## 結論

マリィのオーロンゲex候補向けに、進化・Munkidoriのダメカン移動・悪エネルギー配分を
扱う専用方策を実装し、従来方策の水単 Mega Abomasnow ex と直接比較した。同一の50
seedを先後入替した100試合では専用方策＋候補が33勝、水単が67勝だったため、
提出用 `deck.csv` は現行構成を維持する。

専用方策の候補勝率は33.0%（Wilson 95% CI 24.6–42.7%）。同一seedで候補を従来方策に
戻した対照群は22.0%（15.0–31.1%）だったため、専用方策による改善は+11ポイントだった。
ただし水単にはなお負け越している。両条件ともfault、引き分け、未決着は0だった。

## 専用方策

`main.py` は60枚のデッキ内容からマリィのオーロンゲex候補を識別し、その場合だけ次を
適用する。水単を含む他デッキでは従来の汎用方策を維持する。

- Marnie's Impidimp → Morgrem → Grimmsnarl ex の順で、成立している進化を優先する。
- ダメージを移せるときだけMunkidoriのAdrena-Brainを優先し、移動元は自軍の被ダメージ、
  移動先は相手の残りHPが最少のポケモンとする。
- 最初の悪エネルギーをMunkidoriに配って能力を有効化し、その後は主力進化ラインへ
  エネルギーを集中する。
- 自分が後攻席でも対象陣営を誤認しないよう、`yourIndex`で自軍・相手を判定する。

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
- 方策: 候補は専用方策、現行水単は従来方策（同一 `main.py` がデッキ内容で切替）
- 対戦: 専用方策＋候補 対 従来方策＋現行水単の直接対戦100試合
- seed: 212850–212899（各seedで先後を入れ替えた2試合）
- 平均意思決定回数: 127.48
- 結果: 専用方策＋候補33勝 / 従来方策＋水単67勝 / 引き分け・未決着0 / fault 0
- 対照: 従来方策＋候補22勝 / 従来方策＋水単78勝 / fault 0
- 生ログ: `artifacts/sot-2128-grimmsnarl-policy/`

## 判断

専用方策は同一seedの対照群より11勝多く、複雑な進化とダメカン移動を明示的に扱う効果を
確認できた。一方、水単との差は34勝あり、提出デッキを置き換える基準には達していない。
専用方策と候補は再現可能な検討材料として残すが、提出デッキへの昇格は見送る。
