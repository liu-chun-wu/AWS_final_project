# 開啟環境
```
docker run -it --rm -v "C:\Users\Neo Yeh\Desktop\雲端實務\FinalProject\backend\src:/app" discord-bot
```
# S3 設定
1. 建立 bucket
```
aws s3api create-bucket \
  --bucket testusage1124 \
  --region ap-northeast-1 \
```
2. 關掉 Block all public access (因為要允許外部存取)
```
aws s3api put-public-access-block \
  --bucket testusage1124 \
  --public-access-block-configuration \
  BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false
```
3. 設定 Bucket Policy (唯讀)
```
aws s3api put-bucket-policy \
  --bucket testusage1124 \
  --policy file://bucket-policy.json
```
4. 建立資料夾 Images & Audios
```
aws s3api put-object \
  --bucket testusage1124 \
  --key Images/

aws s3api put-object \
  --bucket testusage1124 \
  --key Audios/
```

# DynamoDB 設定
```
aws dynamodb create-table \
  --table-name UserRecords \
  --attribute-definitions \
      AttributeName=user_id,AttributeType=S \
      AttributeName=record_id,AttributeType=S \
  --key-schema \
      AttributeName=user_id,KeyType=HASH \
      AttributeName=record_id,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```
# API Gateway 設定
1. 建立 API
![alt text](image.png)
2. 建立 Resource
- audio-callback
![alt text](image-1.png)
- generate-audio
![alt text](image-2.png)
- generate-image
![alt text](image-3.png)
- history
![alt text](image-4.png)
3. 建立 method
- audio-callback, generate-audio, generate-image
![alt text](image-6.png)
- history
![alt text](image-5.png)