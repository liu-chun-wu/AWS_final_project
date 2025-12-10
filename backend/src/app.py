"""
AI Generation Backend API
Provides endpoints for image and audio generation using HuggingFace and Suno APIs.

Refactored to use application factory pattern for compatibility with
AWS Lambda Web Adapter and Jeffery template infrastructure.
"""

from flask import Flask, request, jsonify
from dotenv import load_dotenv
import os, io, uuid, datetime
import requests
from PIL import Image
import boto3
from src.db import insert_record, get_history
import json
from urllib.parse import quote_plus


def create_app(config=None):
    """
    Application factory pattern for Flask.

    This function creates and configures a Flask application instance.
    Required by Jeffery template's Dockerfile CMD: gunicorn ... src.app:create_app()

    Args:
        config: Optional configuration dictionary to override defaults

    Returns:
        Configured Flask application instance
    """
    app = Flask(__name__)

    # Load environment variables from .env file
    load_dotenv()

    # Apply custom configuration if provided
    if config:
        app.config.update(config)

    # Initialize AWS clients in app context (not as globals)
    app.s3 = boto3.client("s3")

    # Load API credentials and configuration from environment
    app.huggingface_token = os.getenv("HUGGINGFACE_TOKEN")
    app.suno_token = os.getenv("SUNO_TOKEN")
    app.s3_bucket_name = os.getenv("S3_BUCKET_NAME")
    app.huggingface_url = "https://router.huggingface.co/hf-inference/models/stabilityai/stable-diffusion-xl-base-1.0"
    app.suno_url = "https://api.sunoapi.org/api/v1/generate"

    # Register all application routes
    register_routes(app)

    return app


def register_routes(app):
    """
    Register all application routes.

    Routes are defined within this function to access the app context
    and use app.s3, app.huggingface_token, etc.
    """

    @app.route('/health', methods=['GET'])
    def health():
        """
        Health check endpoint - required by Jeffery template for monitoring.

        Returns:
            JSON response with status and service name
        """
        return jsonify({
            "status": "ok",
            "service": "production-backend"
        }), 200

    @app.route('/generate-image', methods=['POST'])
    def generate_image():
        """
        Generate AI image using HuggingFace Stable Diffusion XL.

        Request JSON:
            {
                "prompt": str - Text description of image to generate
                "user_id": str - Discord user ID or identifier
            }

        Returns:
            JSON response with success status, download URL, and message
        """
        try:
            data = request.json
            prompt = data.get("prompt")
            user_id = data.get("user_id", "unknown")

            if not prompt:
                return jsonify({"success": False, "error": "缺少 prompt"}), 400

            # Call HuggingFace API
            headers = {"Authorization": f"Bearer {app.huggingface_token}"}
            payload = {"inputs": prompt}

            response = requests.post(app.huggingface_url, headers=headers, json=payload, timeout=60)

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

            # Parse image to verify it's valid
            try:
                image = Image.open(io.BytesIO(response.content))
            except Exception as e:
                return jsonify({
                    "success": False,
                    "error": f"圖片解析失敗: {str(e)}"
                }), 500

            # Upload to S3
            timestamp = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
            filename = f"{timestamp}_{uuid.uuid4().hex[:8]}.png"
            s3_key = f"Images/{filename}"

            try:
                app.s3.put_object(
                    Bucket=app.s3_bucket_name,
                    Key=s3_key,
                    Body=response.content,
                    ContentType="image/png"
                )
            except Exception as e:
                return jsonify({
                    "success": False,
                    "error": f"上傳 S3 失敗: {str(e)}"
                }), 500

            public_url = f"https://{app.s3_bucket_name}.s3.amazonaws.com/{s3_key}"

            # Save record to DynamoDB (optional - don't fail if DynamoDB unavailable)
            try:
                result = insert_record(
                    user_id=user_id,
                    prompt=prompt,
                    file_url=public_url,
                    record_type="image",
                    status="success"
                )
            except Exception as e:
                # Log error but don't fail the whole request
                print(f"⚠️ DynamoDB insert failed (non-fatal): {str(e)}")

            # Generate presigned URL for download
            try:
                presigned_url = app.s3.generate_presigned_url(
                    ClientMethod="get_object",
                    Params={
                        "Bucket": app.s3_bucket_name,
                        "Key": s3_key
                    },
                    ExpiresIn=3600  # Valid for 1 hour
                )
            except Exception as e:
                return jsonify({
                    "success": False,
                    "error": f"產生下載網址失敗: {str(e)}"
                }), 500

            return jsonify({
                "success": True,
                "download_url": presigned_url,
                "reply": f"Flask 收到圖片prompt: {prompt}"
            }), 200

        except Exception as e:
            return jsonify({
                "success": False,
                "error": str(e)
            }), 500

    @app.route('/generate-audio', methods=['POST'])
    def generate_audio():
        """
        Generate AI music using Suno API (async processing).

        Request JSON:
            {
                "prompt": str - Text description of music to generate
                "user_id": str - Discord user ID or identifier
            }

        Returns:
            JSON response with success status, task_id, and message.
            Actual audio URL will be provided via callback webhook.
        """
        try:
            print("=== /generate-audio 被呼叫 ===")

            data = request.json
            print("收到的 JSON:", data)

            user_id = data.get('user_id', 'unknown')
            prompt = data.get('prompt')

            if not prompt:
                print("❌ 缺少 prompt")
                return jsonify({"success": False, "error": "缺少 prompt"}), 400

            # Pre-generate S3 key for callback
            timestamp = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
            filename = f"{timestamp}_{uuid.uuid4().hex[:8]}.mp3"
            s3_key = f"Audios/{filename}"

            encoded_prompt = quote_plus(prompt)
            encoded_user_id = quote_plus(str(user_id))
            encoded_s3_key = quote_plus(s3_key)

            # Construct callback URL (Suno will call this when audio is ready)
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
                "Authorization": f"Bearer {app.suno_token}",
                "Content-Type": "application/json"
            }

            print("正在呼叫 Suno API...")
            response = requests.post(app.suno_url, json=payload, headers=headers, timeout=60)

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

            # Check if Suno returned an error
            if suno_resp.get("code") != 200 or suno_resp.get("data") is None:
                error_msg = suno_resp.get("msg", "Unknown Suno API error")
                print(f"❌ Suno API 錯誤: {error_msg}")
                return jsonify({
                    "success": False,
                    "error": f"Suno API 錯誤: {error_msg}"
                }), 500

            # Extract task ID from Suno response (format may vary)
            suno_data = suno_resp.get("data") or {}
            suno_request_id = (
                suno_resp.get("id")
                or suno_resp.get("requestId")
                or suno_data.get("taskId")
            )

            # Pre-generate presigned URL for future download
            presigned_url = app.s3.generate_presigned_url(
                ClientMethod="get_object",
                Params={
                    "Bucket": app.s3_bucket_name,
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

            # Return immediately with task ID (audio processing is async)
            return jsonify({
                "download_url": presigned_url,
                "success": True,
                "task_id": suno_request_id,
                "message": "音樂生成中"
            }), 200

        except Exception as e:
            print("❌ Flask 在 /generate-audio 發生錯誤:", e)
            return jsonify({"success": False, "error": str(e)}), 500

    @app.route('/audio-callback', methods=['POST'])
    def audio_callback():
        """
        Webhook endpoint for Suno API async audio generation results.

        Called by Suno API when audio generation is complete.
        Downloads the audio file from Suno and uploads to S3.

        Query parameters:
            user_id: User identifier
            prompt: Original prompt text
            s3_key: Pre-generated S3 key for file storage

        Returns:
            JSON response with success status and download URL
        """
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

                # Download audio file from Suno
                mp3 = requests.get(audio_url).content

                # Get S3 key from query parameters
                s3_key = request.args.get("s3_key")

                # Upload to S3
                try:
                    app.s3.put_object(
                        Bucket=app.s3_bucket_name,
                        Key=s3_key,
                        Body=mp3,
                        ContentType="audio/mpeg"
                    )
                except Exception as e:
                    return jsonify({
                        "success": False,
                        "error": f"上傳 S3 失敗: {str(e)}"
                    }), 500

                user_id = request.args.get("user_id", "no user id")
                prompt = request.args.get("prompt", "no prompt")

                public_url = f"https://{app.s3_bucket_name}.s3.amazonaws.com/{s3_key}"

                # Save record to DynamoDB
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
                    }), 500

                # Generate presigned URL for download
                try:
                    presigned_url = app.s3.generate_presigned_url(
                        ClientMethod="get_object",
                        Params={
                            "Bucket": app.s3_bucket_name,
                            "Key": s3_key
                        },
                        ExpiresIn=3600
                    )
                except Exception as e:
                    return jsonify({
                        "success": False,
                        "error": f"產生下載網址失敗: {str(e)}"
                    }), 500

                return jsonify({
                    "success": True,
                    "download_url": presigned_url,
                    "reply": "Flask 收到音樂prompt"
                }), 200

        except Exception as e:
            print("callback error:", e)
            return jsonify({"error": str(e)}), 500

    @app.route("/history", methods=["GET"])
    def history():
        """
        Retrieve user's generation history from DynamoDB.

        Query parameters:
            user_id: User identifier to fetch history for

        Returns:
            JSON response with success status and array of records
        """
        try:
            user_id = request.args.get("user_id")

            records = get_history(user_id)

            return jsonify({
                "success": True,
                "records": records
            }), 200

        except Exception as e:
            return jsonify({"success": False, "error": str(e)}), 500


# Entry point for local development
if __name__ == '__main__':
    # For local development only
    # In production, gunicorn is used (see Dockerfile)
    print("🚀 Flask 伺服器啟動中...")
    app = create_app()
    app.run(host='0.0.0.0', port=8000, debug=True)
