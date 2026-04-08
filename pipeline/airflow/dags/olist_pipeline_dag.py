from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator
from datetime import datetime, timedelta
import boto3
import time
import sys
import os
 
sys.path.insert(0, '/opt/airflow/extract')
 
default_args = {
    'owner': 'airflow',
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}
 
def upload_to_s3():
    import upload_to_s3 as uploader
    uploader.main()
 
def run_glue_job():
    client = boto3.client('glue', region_name='ap-northeast-2')
    
    # Glue 잡 실행
    response = client.start_job_run(JobName='olist-etl-job')
    job_run_id = response['JobRunId']
    print(f"Glue Job started: {job_run_id}")
    
    # 완료될 때까지 대기
    while True:
        status = client.get_job_run(
            JobName='olist-etl-job',
            RunId=job_run_id
        )
        state = status['JobRun']['JobRunState']
        print(f"Glue Job state: {state}")
        
        if state == 'SUCCEEDED':
            print("Glue Job 완료!")
            break
        elif state in ['FAILED', 'ERROR', 'TIMEOUT']:
            raise Exception(f"Glue Job 실패: {state}")
        
        time.sleep(30)
 
with DAG(
    dag_id='olist_pipeline',
    default_args=default_args,
    description='Olist AWS 데이터 파이프라인',
    schedule_interval='@daily',
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=['olist', 'aws'],
) as dag:
 
    task_upload_s3 = PythonOperator(
        task_id='upload_to_s3',
        python_callable=upload_to_s3,
    )
 
    task_run_glue = PythonOperator(
        task_id='run_glue_job',
        python_callable=run_glue_job,
    )
 
    task_run_dbt = BashOperator(
        task_id='run_dbt',
        bash_command='cd /opt/airflow/dbt && dbt run --profiles-dir /home/airflow/.dbt --profile olist_pipeline',
    )
 
    task_upload_s3 >> task_run_glue >> task_run_dbt