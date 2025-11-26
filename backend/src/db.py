import os
import uuid
import datetime
import boto3
from boto3.dynamodb.conditions import Key
from dotenv import load_dotenv

# 載入環境變數
load_dotenv()
AWS_REGION = os.getenv("AWS_DEFAULT_REGION", "us-east-1")
TABLE_NAME = os.getenv("DYNAMODB_TABLE", "UserRecords")

# 建立 DynamoDB 資源
dynamodb = boto3.resource("dynamodb", region_name=AWS_REGION)
table = dynamodb.Table(TABLE_NAME)

def insert_record(user_id: str, prompt: str, file_url: str, record_type: str = "image", status: str = "success", extra_meta: dict = None):
    """
    新增一筆紀錄到 DynamoDB
    """
    record_id = str(uuid.uuid4())
    created_at = datetime.datetime.utcnow().isoformat()

    item = {
        "user_id": user_id,
        "record_id": record_id,
        "prompt": prompt,
        "file_url": file_url,
        "created_at": created_at,
        "type": record_type,
        "status": status,
    }

    if extra_meta:
        item["extra_meta"] = extra_meta

    table.put_item(Item=item)
    return item

def get_history(user_id: str):
    
    # 查詢某個使用者的所有紀錄
    resp = table.query(
        KeyConditionExpression=Key("user_id").eq(user_id)
    )
    items = resp.get("Items", [])

    # 只回傳記錄中的 prompt 跟 url
    simple_items = [
        {
            "prompt": item.get("prompt"),
            "file_url": item.get("file_url"),
            "type": item.get("type")
        }
        for item in items
    ]
    return simple_items


def get_record(user_id: str, record_id: str):
    
    # 查詢單筆紀錄
    resp = table.get_item(
        Key={
            "user_id": user_id,
            "record_id": record_id
        }
    )
    return resp.get("Item")