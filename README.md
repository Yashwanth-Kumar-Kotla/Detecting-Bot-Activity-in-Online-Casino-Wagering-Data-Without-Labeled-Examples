# Detecting coordinated play in casino wager data

This course project asks what patterns an analyst can investigate when wager records come without confirmed bot labels. The source files are shared separately through Google Drive.

## Setup

1. Download the three source files into a local folder. See the [data inventory](ingestion/data_dictionary.md).
2. Create a Python environment and run the commands below from the repository root.

```sh
python -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
python ingestion/ingest.py "/path/to/drive-downloads"
```

The catalog is written to `private/wagers.duckdb`. It points to the downloaded files in place. Keep the raw files and generated databases out of Git.

## Exploratory analysis

Start JupyterLab from the repository root with `python -m jupyterlab`. Open the notebooks in order and use **Restart Kernel and Run All Cells**. The saved outputs let you read them without access to the data.

1. [Coverage and data quality](eda/01_coverage.ipynb) checks the observation window, missing fields, and volume by game.
2. [Account behavior](eda/02_account_behavior.ipynb) compares activity and house win rates across account-volume bands.

## Coordination audit

3. [Mirrored wagers](coordination_audit/01_mirrored_wagers.ipynb) tests whether repeated opposite-side bets at similar stakes exceed what the accounts' side preferences would predict.
4. [Scores and rebates](coordination_audit/02_scores_and_rebates.ipynb) checks the observed rebate rates and looks for changes in the Banker score at the start of recording.

The checked-in run found **182 retained links across 192 accounts in 36 groups**. Tier A links were opposite on a median of 100% of shared rounds, versus about 51% expected from side preferences. Mirrored pair turnover had a 1.35% house win rate.

An earlier historical run reported 199 accounts in 40 groups. The notebooks here include an explicit table key, exclude duplicate account-round matches and average the timing comparison in both directions. Use the saved run for the results produced by this repository. The groups are candidates for coordination review. Whether the accounts used software remains open.

The coordination notebook scans the full wager file and can use several gigabytes of temporary space under `private/`.
