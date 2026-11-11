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
