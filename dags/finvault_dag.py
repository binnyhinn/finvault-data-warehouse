import os
from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.bash import BashOperator

HOME = os.environ.get("FINVAULT_HOME", "/opt/finvault")

default_args = {"retries": 2, "retry_delay": timedelta(minutes=2)}

with DAG("finvault_daily", start_date=datetime(2026, 7, 1), schedule="@daily",
         catchup=False, default_args=default_args, tags=["finvault"]) as dag:

    bronze = BashOperator(task_id="bronze_load",
                          bash_command=f"cd {HOME} && python ingestion/load_bronze.py")
    pipeline = BashOperator(task_id="silver_gold_dbt_recon",
                            bash_command=f"cd {HOME} && python ingestion/run_pipeline.py")
    bronze >> pipeline
