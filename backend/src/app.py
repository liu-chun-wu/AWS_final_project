from flask import Flask, request, jsonify, send_from_directory
from dotenv import load_dotenv
import os, io, uuid, datetime
import requests
from PIL import Image
import awsgi
import boto3
from db import insert_record, get_history
import json
from urllib.parse import quote_plus

load_dotenv()
HuggingFace_Token = os.getenv("HUGGINGFACE_TOKEN")
Suno_Token = os.getenv("SUNO_TOKEN")
S3_BUCKET_NAME = os.getenv("S3_BUCKET_NAME")
HuggingFace_URL = "https://router.huggingface.co/hf-inference/models/stabilityai/stable-diffusion-xl-base-1.0"
SUNO_URL = "https://api.sunoapi.org/api/v1/generate"

app = Flask(__name__)
s3 = boto3.client("s3")  # 建立 s3 client

@app.route("/generate-image", methods=["POST"])
def generate_image():
    try:
        data = request.json
        prompt = data.get("prompt", "沒有收到圖片prompt")
        user_id = data.get("user_id", "unknown")

        if not prompt:
            return jsonify({"success": False, "error": "缺少 prompt"}), 400

        headers = {"Authorization": f"Bearer {HuggingFace_Token}"}
        payload = {"inputs": prompt}

        response = requests.post(HuggingFace_URL, headers=headers, json=payload, timeout=60)

        if response.status_code != 200:
            return jsonify({
                "success": False,
                "error": f"Hugging Face API 錯誤: {response.status_code}",
                "details": response.text
            }), 500

        content_type = response.headers.get('Content-Type', '')

        if 'application/json' in content_type:
            error_data = response.json()
            return jsonify({
                "success": False,
                "error": "Hugging Face 回傳錯誤",
                "details": error_data
            }), 500

        if 'image' not in content_type:
            return jsonify({
                "success": False,
                "error": f"非預期的回傳格式: {content_type}"
            }), 500
            
        # 嘗試解析圖片
        try:
            image = Image.open(io.BytesIO(response.content))
        except Exception as e:
            return jsonify({
                "success": False,
                "error": f"圖片解析失敗: {str(e)}"
            }), 500

        # 存到 S3
        timestamp = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
        filename = f"{timestamp}_{uuid.uuid4().hex[:8]}.png"
        s3_key = f"Images/{filename}"

        try:
            s3.put_object(
                Bucket=S3_BUCKET_NAME,
                Key=s3_key,
                Body=response.content,      # 直接用原始 bytes
                ContentType="image/png"
            )
        except Exception as e:
            return jsonify({
                "success": False,
                "error": f"上傳 S3 失敗: {str(e)}"
            }), 500

        public_url=f"https://{S3_BUCKET_NAME}.s3.amazonaws.com/{s3_key}"
        local_url=f"s3://{S3_BUCKET_NAME}/{s3_key}"
        # 存進 DynamoDB
        try:
            result = insert_record(
                user_id=user_id,
                prompt=prompt,
                file_url=public_url,
                record_type="image",
                status="success"
            )  
        except Exception as e:
            return jsonify({
                "statusCode": 500,
                "body": json.dumps({
                    "message": "❌ 插入失敗",
                    "error": str(e)
                })
            })

        # 提供可存取的 url
        try:
            presigned_url = s3.generate_presigned_url(
                ClientMethod="get_object",
                Params={
                    "Bucket": S3_BUCKET_NAME,
                    "Key": s3_key
                },
                ExpiresIn=3600  # 有效時間秒數
            )
        except Exception as e:
            return jsonify({
                "success": False,
                "error": f"產生下載網址失敗: {str(e)}"
            }), 500

        return jsonify({
            "success": True,
            "download_url": presigned_url,   # 👈 這是 S3 presigned URL
            "reply": f"Flask 收到圖片prompt: {prompt}"
        })


    except Exception as e:
        return jsonify({
            "success": False, 
            "error": str(e)
        }), 500

@app.route('/generate-audio', methods=['POST'])
def generate_audio():
    try:
        print("=== /generate-audio 被呼叫 ===")

        data = request.json
        print("收到的 JSON:", data)

        user_id = data.get('user_id', 'unknown')
        prompt = data.get('prompt')
        # 回傳網址(先訂好)
        timestamp = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
        filename = f"{timestamp}_{uuid.uuid4().hex[:8]}.mp3"
        s3_key = f"Audios/{filename}"

        encoded_prompt = quote_plus(prompt)
        encoded_user_id = quote_plus(str(user_id))
        encoded_s3_key = quote_plus(s3_key)
        
        if not prompt:
            print("❌ 缺少 prompt")
            return jsonify({"success": False, "error": "缺少 prompt"}), 400

        base_callback = "https://xpapysqd2i.execute-api.us-east-1.amazonaws.com/prod/audio-callback"    
        callback_url = f"{base_callback}?user_id={encoded_user_id}&prompt={encoded_prompt}&s3_key={encoded_s3_key}"
        payload = {
            "prompt": prompt,
            "style": "古典",
            "title": "AI Generated Music",
            "customMode": True,
            "instrumental": True,
            "model": "V3_5",
            "callBackUrl": callback_url
        }

        print("Suno payload:", payload)

        headers = {
            "Authorization": f"Bearer {Suno_Token}",
            "Content-Type": "application/json"
        }

        print("正在呼叫 Suno API...")
        response = requests.post(SUNO_URL, json=payload, headers=headers, timeout=60)

        print("Suno 回應狀態:", response.status_code)
        print("Suno 回應內容:", response.text)

        if response.status_code != 200:
            return jsonify({
                "success": False,
                "error": f"Suno API 錯誤: {response.status_code}",
                "details": response.text
            }), 500

        suno_resp = response.json()
        print("解析後 Suno JSON:", suno_resp)

        # ⭐ 抓 taskId（Suno 回傳格式有時不同）
        suno_request_id = (
            suno_resp.get("id")
            or suno_resp.get("requestId")
            or suno_resp.get("data", {}).get("taskId")
        )

        presigned_url = s3.generate_presigned_url(
                ClientMethod="get_object",
                Params={
                    "Bucket": S3_BUCKET_NAME,
                    "Key": s3_key
                },
                ExpiresIn=3600
            )

        if not suno_request_id:
            print("❌ Suno 沒有回傳 taskId")
            return jsonify({
                "success": False,
                "error": "Suno 未回傳 taskId"
            }), 500       

        # 回傳給 Discord bot，可以用來顯示“開始生成中”
        return jsonify({
            "download_url": presigned_url,
            "success": True,
            "task_id": suno_request_id,
            "message": "音樂生成中"
        })

    except Exception as e:
        print("❌ Flask 在 /generate-audio 發生錯誤:", e)
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/audio-callback', methods=['POST'])
def audio_callback():
    print("⭐ 進到 audio_callback")
    try:
        print("=== 收到 Suno callback ===")
        data = request.json
        suno_items = data["data"]["data"]

        for item in suno_items:
            audio_url = item.get("source_audio_url")
            music_id = item["id"]

            if not audio_url:
                print("❌ 沒有 audio_url")
                return jsonify({
                    "success": False,
                    "error": "Suno 沒有回傳 audio_url"
                }), 500

            # 下載音檔
            mp3 = requests.get(audio_url).content

            # 使用建立好的 s3_key
            s3_key = request.args.get("s3_key")

            try:
                s3.put_object(
                    Bucket=S3_BUCKET_NAME,
                    Key=s3_key,
                    Body=mp3,      # 直接用原始 bytes
                    ContentType="audio/mpeg"
                )
            except Exception as e:
                return jsonify({
                    "success": False,
                    "error": f"上傳 S3 失敗: {str(e)}"
                }), 500

            user_id = request.args.get("user_id", "no user id")
            prompt = request.args.get("prompt", "no prompt")
            
            public_url=f"https://{S3_BUCKET_NAME}.s3.amazonaws.com/{s3_key}"
            local_url=f"s3://{S3_BUCKET_NAME}/{s3_key}"

            # 存進 DynamoDB
            try:
                result = insert_record(
                    user_id=user_id,
                    prompt=prompt,
                    file_url=public_url,
                    record_type="audio",
                    status="success"
                )  
            except Exception as e:
                return jsonify({
                    "statusCode": 500,
                    "body": json.dumps({
                        "message": "❌ 插入失敗",
                        "error": str(e)
                    })
                })
            # 提供可存取的 url
            try:
                presigned_url = s3.generate_presigned_url(
                    ClientMethod="get_object",
                    Params={
                        "Bucket": S3_BUCKET_NAME,
                        "Key": s3_key
                    },
                    ExpiresIn=3600  # 有效時間秒數
                )
            except Exception as e:
                return jsonify({
                    "success": False,
                    "error": f"產生下載網址失敗: {str(e)}"
                }), 500

            return jsonify({
                "success": True,
                "download_url": presigned_url,   # 👈 這是 S3 presigned URL
                "reply": "Flask 收到音樂prompt"
            })

    except Exception as e:
        print("callback error:", e)
        return jsonify({"error": str(e)}), 500

@app.route("/history", methods=["GET"])
def history():
    try:
        user_id = request.args.get("user_id")  # 從 URL query 取得 user_id

        records = get_history(user_id)

        return jsonify({
            "success": True,
            "records": records   # 形式：[{ "prompt": "...", "file_url": "..." }, ...]
        })
        
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

if __name__ == '__main__':
    print("🚀 Flask 伺服器啟動中...")
    app.run(host='0.0.0.0', port=5000, debug=True)