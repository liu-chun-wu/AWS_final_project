from flask import Flask, request, jsonify, send_from_directory
from dotenv import load_dotenv
import os, io, uuid, datetime
import sqlite3
import requests
from PIL import Image
from db import init_db, insert_record
init_db()
load_dotenv()
HuggingFace_Token = os.getenv("HUGGINGFACE_TOKEN")
Suno_Token = os.getenv("SUNO_TOKEN")
HuggingFace_URL = "https://router.huggingface.co/hf-inference/models/stabilityai/stable-diffusion-xl-base-1.0"
app = Flask(__name__)

# 本地儲存目錄
LOCAL_STORAGE = './generated_files'
os.makedirs(f'{LOCAL_STORAGE}/images', exist_ok=True)
os.makedirs(f'{LOCAL_STORAGE}/audios', exist_ok=True)

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

        # 儲存到本地
        timestamp = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
        filename = f"{timestamp}_{uuid.uuid4().hex[:8]}.png"
        local_path = f"{LOCAL_STORAGE}/images/{filename}"
        image.save(local_path, format="PNG")

        # 本地 URL
        local_url = f"http://localhost:5000/generated_files/images/{filename}"

        # 寫入 SQLite
        insert_record(user_id, prompt, local_url)

        return jsonify({
            "success": True,
            "local_url": local_url,
            "reply": f"Flask 收到圖片prompt: {prompt}"
        })

    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/generate-audio', methods=['POST'])
def generate_audio():
    try:
        data = request.json
        prompt = data.get("prompt", "沒有收到圖片prompt")
        
        filename = "ta.txt"
        # 模擬生成圖片，先回傳本地 txt URL
        # local_url = f"http://localhost:5000/generated_files/test.txt"
        local_url = f"http://localhost:5000/generated_files/audios/{filename}"

        return jsonify({
            "success": True,
            "local_url": local_url,
            "reply": f"Flask 收到音樂prompt: {prompt}"
        })
    
    except Exception as e:
        return jsonify({"success":False, "error":str(e)}),500
# 呼叫索取生成結果(圖片/音樂)
@app.route('/generated_files/<file_type>/<filename>', methods=['GET'])
def serve_file(file_type, filename):
    """
    file_type: 'images' 或 'audios'
    filename: 檔案名稱
    """
    # 驗證子資料夾
    if file_type not in ["images", "audios"]:
        return jsonify({"success": False, "error": "不支援的檔案類型"}), 400

    directory = os.path.join(LOCAL_STORAGE, file_type)
    return send_from_directory(directory, filename)

@app.route("/history", methods=["GET"])
def history():
    try:
        user_id = request.args.get("user_id")  # 從 URL query 取得 user_id
        conn = sqlite3.connect("bot_records.db")
        c = conn.cursor()

        if user_id:
            c.execute("SELECT id, user_id, timestamp, prompt, file_url FROM records WHERE user_id=? ORDER BY id DESC", (user_id,))
        else:
            c.execute("SELECT id, user_id, timestamp, prompt, file_url FROM records ORDER BY id DESC")

        rows = c.fetchall()
        conn.close()

        return jsonify({
            "success": True,
            "records": [
                {"id": r[0], "user_id": r[1], "timestamp": r[2], "prompt": r[3], "file_url": r[4]}
                for r in rows
            ]
        })
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500




if __name__ == '__main__':
    print("🚀 Flask 伺服器啟動中...")
    app.run(host='0.0.0.0', port=5000, debug=True)
