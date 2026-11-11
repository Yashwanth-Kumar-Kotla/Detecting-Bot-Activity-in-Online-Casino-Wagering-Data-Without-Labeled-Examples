# Data inventory

Obtain the Drive files separately from the project owner. Ingestion registers views over the local files, so leave them in place after setup or rerun ingestion after moving them.

| File | Grain | Main fields |
|---|---|---|
| `patron_wagers_all.parquet` | One account's aggregated wagers on a game hand | `member` identifies the account. `date`, `game`, `tableNO`, `shoe_ref`, and `shoe_hand` describe the hand. `min_time_stamp` is the first wager timestamp in the aggregate. |
| `baccarat_hand_scores.parquet` | One score record per game, date, table, shoe reference and hand | `bank_beta` and `plyr_beta` are supplied scores. The project checks score behavior before interpreting them as expected returns. |
| `rebate_summary.csv` | One row per account with a recorded claim | `avg_rebate_pcnt` is a claim-weighted rate. Its units and coverage need confirmation. |

In the wager file, `bet` is turnover, `wl` is actual house win, and `theo` is expected house win. These amounts use a common RMB basis. `boxes` counts distinct underlying bet codes and `prop_bet` is side-bet turnover. A round may have many accounts. Some calendar-date hand keys can refer to more than one physical hand, so the coordination audit also uses timestamp separation.

The dataset has no verified bot labels. Public notebook outputs contain aggregate results.
