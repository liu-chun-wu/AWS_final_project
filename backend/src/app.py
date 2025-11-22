from flask import Flask, request, jsonify
import requests
import io
# import boto3  # 本地測試暫時不用
from PIL import Image
from dotenv import load_dotenv
import os
import uuid
from datetime import datetime

load_dotenv()

HUGGING_TOKEN = os.getenv('HUGGINGFACE_TOKEN')
SUNO_TOKEN = os.getenv('SUNO_TOKEN')
# AWS_ACCESS_KEY = os.getenv('AWS_ACCESS_KEY_ID')
# AWS_SECRET_KEY = os.getenv('AWS_SECRET_ACCESS_KEY')
# AWS_REGION = os.getenv('AWS_REGION', 'us-east-1')
# S3_BUCKET = os.getenv('S3_BUCKET_NAME')

HUGGING_URL = "https://router.huggingface.co/hf-inference/models/stabilityai/stable-diffusion-xl-base-1.0"
SUNO_URL = "https://api.sunoapi.org/api/v1/generate"

app = Flask(__name__)

# 初始化 S3 客戶端 (本地測試先註解)
# s3_client = boto3.client(
#     's3',
#     aws_access_key_id=AWS_ACCESS_KEY,
#     aws_secret_access_key=AWS_SECRET_KEY,
#     region_name=AWS_REGION
# )

# 本地儲存目錄
LOCAL_STORAGE = './generated_files'
os.makedirs(f'{LOCAL_STORAGE}/images', exist_ok=True)
os.makedirs(f'{LOCAL_STORAGE}/music', exist_ok=True)

# 儲存進行中的任務
tasks = {}

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy"}), 200

@app.route('/generate-image', methods=['POST'])
def generate_image():
    """生成圖片並儲存到本地"""
    try:
        data = request.json
        prompt = data.get('prompt')
        
        if not prompt:
            return jsonify({"success": False, "error": "缺少 prompt"}), 400
        
        # 呼叫 Hugging Face API
        headers = {"Authorization": f"Bearer {HUGGING_TOKEN}"}
        payload = {"inputs": prompt}
        
        response = requests.post(HUGGING_URL, headers=headers, json=payload, timeout=60)
        
        if response.status_code != 200:
            return jsonify({
                "success": False,
                "error": f"Hugging Face API 錯誤: {response.status_code}",
                "details": response.text
            }), 500
        
        # 檢查回傳的 Content-Type
        content_type = response.headers.get('Content-Type', '')
        
        # 如果回傳 JSON，表示有錯誤（例如模型載入中）
        if 'application/json' in content_type:
            error_data = response.json()
            return jsonify({
                "success": False,
                "error": "Hugging Face 回傳錯誤",
                "details": error_data
            }), 500
        
        # 確認是圖片格式
        if 'image' not in content_type:
            return jsonify({
                "success": False,
                "error": f"非預期的回傳格式: {content_type}"
            }), 500
        
        # 處理圖片
        try:
            image = Image.open(io.BytesIO(response.content))
        except Exception as e:
            return jsonify({
                "success": False,
                "error": f"圖片解析失敗: {str(e)}"
            }), 500


        # 處理圖片
        #image = Image.open(io.BytesIO(response.content))
        
        # 儲存到本地
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"{timestamp}_{uuid.uuid4().hex[:8]}.png"
        local_path = f"{LOCAL_STORAGE}/images/{filename}"
        image.save(local_path, format="PNG")
        
        # 本地 URL (供 Discord Bot 訪問)
        local_url = f"http://localhost:5000/files/images/{filename}"
        
        # === S3 上傳 (本地測試先註解) ===
        # image_bytes = io.BytesIO()
        # image.save(image_bytes, format="PNG")
        # image_bytes.seek(0)
        # 
        # s3_key = f"images/{timestamp}_{uuid.uuid4().hex[:8]}.png"
        # s3_client.upload_fileobj(
        #     image_bytes,
        #     S3_BUCKET,
        #     s3_key,
        #     ExtraArgs={'ContentType': 'image/png'}
        # )
        # s3_url = f"https://{S3_BUCKET}.s3.{AWS_REGION}.amazonaws.com/{s3_key}"
        # === S3 上傳結束 ===
        
        return jsonify({
            "success": True,
            "local_url": local_url,
            "local_path": local_path,
            # "s3_url": s3_url,  # 將來啟用
            "prompt": prompt
        })
        
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/generate-audio', methods=['POST'])
def generate_audio():
    """提交音樂生成任務（非同步）"""
    try:
        data = request.json
        prompt = data.get('prompt')
        discord_channel_id = data.get('discord_channel_id')
        discord_user_id = data.get('discord_user_id')
        
        if not prompt:
            return jsonify({"success": False, "error": "缺少 prompt"}), 400
        
        # 生成任務 ID
        task_id = str(uuid.uuid4())
        
        # 準備 Suno API 請求
        payload = {
            "prompt": prompt,
            "style": "古典",
            "title": "AI Generated Music",
            "customMode": True,
            "instrumental": True,
            "model": "V3_5",
            "callBackUrl": f"{request.host_url}audio-callback"
        }
        
        headers = {
            "Authorization": f"Bearer {SUNO_TOKEN}",
            "Content-Type": "application/json"
        }
        
        # 發送到 Suno API
        response = requests.post(SUNO_URL, json=payload, headers=headers, timeout=10)
        
        if response.status_code != 200:
            return jsonify({
                "success": False,
                "error": f"Suno API 錯誤: {response.status_code}"
            }), 500
        
        suno_data = response.json()
        
        # 儲存任務資訊
        tasks[task_id] = {
            "prompt": prompt,
            "discord_channel_id": discord_channel_id,
            "discord_user_id": discord_user_id,
            "suno_response": suno_data,
            "status": "processing",
            "created_at": datetime.now().isoformat()
        }
        
        return jsonify({
            "success": True,
            "task_id": task_id,
            "message": "音樂生成中，完成後會通知您"
        })
        
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/audio-callback', methods=['POST'])
def audio_callback():
    """接收 Suno 的 callback"""
    try:
        data = request.json
        audio_url = data.get('audio_url')
        
        if not audio_url:
            return jsonify({"success": False, "error": "缺少 audio_url"}), 400
        
        # 找到對應的任務
        task_id = None
        for tid, task in tasks.items():
            if task.get('status') == 'processing':
                task_id = tid
                break
        
        if not task_id:
            return jsonify({"success": False, "error": "找不到對應任務"}), 404
        
        task = tasks[task_id]
        
        # 下載音樂檔案
        audio_resp = requests.get(audio_url, timeout=60)
        
        # 儲存到本地
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"{timestamp}_{uuid.uuid4().hex[:8]}.mp3"
        local_path = f"{LOCAL_STORAGE}/music/{filename}"
        
        with open(local_path, 'wb') as f:
            f.write(audio_resp.content)
        
        local_url = f"http://localhost:5000/files/music/{filename}"
        
        # === S3 上傳 (本地測試先註解) ===
        # audio_bytes = io.BytesIO(audio_resp.content)
        # s3_key = f"music/{timestamp}_{uuid.uuid4().hex[:8]}.mp3"
        # s3_client.upload_fileobj(
        #     audio_bytes,
        #     S3_BUCKET,
        #     s3_key,
        #     ExtraArgs={'ContentType': 'audio/mpeg'}
        # )
        # s3_url = f"https://{S3_BUCKET}.s3.{AWS_REGION}.amazonaws.com/{s3_key}"
        # === S3 上傳結束 ===
        
        # 更新任務狀態
        task['status'] = 'completed'
        task['audio_url'] = audio_url
        task['local_url'] = local_url
        task['local_path'] = local_path
        # task['s3_url'] = s3_url  # 將來啟用
        
        # TODO: 通知 Discord Bot
        notify_discord_bot(task)
        
        return jsonify({"success": True, "local_url": local_url})
        
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/files/<file_type>/<filename>', methods=['GET'])
def serve_file(file_type, filename):
    """提供本地檔案訪問"""
    from flask import send_from_directory
    directory = f"{LOCAL_STORAGE}/{file_type}"
    return send_from_directory(directory, filename)

@app.route('/task-status/<task_id>', methods=['GET'])
def task_status(task_id):
    """查詢任務狀態"""
    task = tasks.get(task_id)
    if not task:
        return jsonify({"success": False, "error": "任務不存在"}), 404
    
    return jsonify({"success": True, "task": task})

def notify_discord_bot(task):
    """通知 Discord Bot 音樂已完成"""
    try:
        print(f"✅ 音樂生成完成!")
        print(f"📁 本地路徑: {task['local_path']}")
        print(f"🔗 本地 URL: {task['local_url']}")
        print(f"💬 Channel ID: {task['discord_channel_id']}")
        print(f"👤 User ID: {task['discord_user_id']}")
        
        # 可以在這裡實作通知機制
        # 例如: Discord Webhook, Redis Queue, 或讓 Bot 輪詢
        
    except Exception as e:
        print(f"❌ 通知 Discord Bot 失敗: {e}")

if __name__ == '__main__':
    print("🚀 Flask 伺服器啟動中...")
    print(f"📁 本地儲存目錄: {LOCAL_STORAGE}")
    app.run(host='0.0.0.0', port=5000, debug=True)