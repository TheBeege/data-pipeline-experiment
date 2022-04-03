# Data Pipeline Experiment

This repository fetches from Twitter, stores to MariaDB, and runs a Jupyter notebook to look through the data. Everything is run via Docker Compose.

## Set up
1. Run `docker-compose up`.
2. Go to `http://localhost:10000/lab` and enter the token shown in the Jupyter container output.
3. In the Jupyter lab, open the Jupyter notebook and follow any README instructions.

## Updating Data
The data pipeline is in the `flows` directory. We're using [Prefect](https://www.prefect.io/) for data pipelining. You can edit the pipeline flow in `main.py`.
