from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.docker.operators.docker import DockerOperator
from docker.types import Mount
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

    response = client.start_job_run(JobName='olist-etl-job')
    job_run_id = response['JobRunId']
    print(f"Glue Job started: {job_run_id}")

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

    task_run_dbt = DockerOperator(
        task_id='run_dbt',
        image='ghcr.io/dbt-labs/dbt-redshift:1.9.0',
        command='run --profiles-dir /root/.dbt --project-dir /dbt',
        mounts=[
            Mount(
                source='C:/olist-aws-pipeline/transform/olist_pipeline',
                target='/dbt',
                type='bind'
            ),
            Mount(
                source='C:/olist-aws-pipeline/infra/docker/dbt_profiles.yml',
                target='/root/.dbt/profiles.yml',
                type='bind'
            ),
        ],
        environment={
            'AWS_ACCESS_KEY_ID': os.environ.get('AWS_ACCESS_KEY_ID'),
            'AWS_SECRET_ACCESS_KEY': os.environ.get('AWS_SECRET_ACCESS_KEY'),
        },
        docker_url='tcp://host.docker.internal:2375',
        auto_remove='success',
        mount_tmp_dir=False,
    )

    task_upload_s3 >> task_run_glue >> task_run_dbt