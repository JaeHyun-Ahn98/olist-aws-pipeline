import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql import functions as F

# Glue 초기화
args = getResolvedOptions(sys.argv, ['JOB_NAME'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# 설정
S3_BUCKET = 's3://olist-pipeline-data-lake-589159458581'
REDSHIFT_URL = 'jdbc:redshift://olist-pipeline-cluster.cqoy5kvivf3e.ap-northeast-2.redshift.amazonaws.com:5439/olistdb'
REDSHIFT_USER = 'admin'
REDSHIFT_PASSWORD = 'Admin1234!'
TEMP_DIR = f'{S3_BUCKET}/temp/'

def load_csv(path):
    return spark.read.option('header', 'true').option('inferSchema', 'true').csv(path)

def write_to_redshift(df, table_name):
    df.write \
        .format('jdbc') \
        .option('url', REDSHIFT_URL) \
        .option('dbtable', table_name) \
        .option('user', REDSHIFT_USER) \
        .option('password', REDSHIFT_PASSWORD) \
        .option('driver', 'com.amazon.redshift.jdbc42.Driver') \
        .mode('overwrite') \
        .save()
    print(f'✅ {table_name} 적재 완료')

# 1. orders
orders = load_csv(f'{S3_BUCKET}/raw/csv/olist_orders_dataset.csv')
write_to_redshift(orders, 'raw_orders')

# 2. customers
customers = load_csv(f'{S3_BUCKET}/raw/csv/olist_customers_dataset.csv')
write_to_redshift(customers, 'raw_customers')

# 3. order_items
order_items = load_csv(f'{S3_BUCKET}/raw/csv/olist_order_items_dataset.csv')
write_to_redshift(order_items, 'raw_order_items')

# 4. order_payments
order_payments = load_csv(f'{S3_BUCKET}/raw/csv/olist_order_payments_dataset.csv')
write_to_redshift(order_payments, 'raw_order_payments')

# 5. order_reviews
order_reviews = load_csv(f'{S3_BUCKET}/raw/csv/olist_order_reviews_dataset.csv')
write_to_redshift(order_reviews, 'raw_order_reviews')

# 6. products
products = load_csv(f'{S3_BUCKET}/raw/csv/olist_products_dataset.csv')
write_to_redshift(products, 'raw_products')

# 7. sellers
sellers = load_csv(f'{S3_BUCKET}/raw/csv/olist_sellers_dataset.csv')
write_to_redshift(sellers, 'raw_sellers')

# 8. geolocation
geolocation = load_csv(f'{S3_BUCKET}/raw/csv/olist_geolocation_dataset.csv')
write_to_redshift(geolocation, 'raw_geolocation')

# 9. category translation
category = load_csv(f'{S3_BUCKET}/raw/csv/product_category_name_translation.csv')
write_to_redshift(category, 'raw_category_translation')

job.commit()
print('🎉 전체 ETL 완료!')