import boto3
import os
from pathlib import Path

# S3 클라이언트 생성
s3 = boto3.client('s3', region_name='ap-northeast-2')

# 버킷 이름
BUCKET_NAME = 'olist-pipeline-data-lake-589159458581'

# 로컬 데이터 경로
DATA_DIR = Path(__file__).parent.parent / 'data' / 'raw'

def upload_csv_to_s3():
    csv_files = list(DATA_DIR.glob('*.csv'))
    
    if not csv_files:
        print("CSV 파일이 없어요!")
        return

    for file_path in csv_files:
        s3_key = f'raw/csv/{file_path.name}'
        
        print(f'업로드 중: {file_path.name} → s3://{BUCKET_NAME}/{s3_key}')
        
        s3.upload_file(
            str(file_path),
            BUCKET_NAME,
            s3_key
        )
        
        print(f'완료: {file_path.name}')

    print(f'\n총 {len(csv_files)}개 파일 업로드 완료!')

if __name__ == '__main__':
    upload_csv_to_s3()