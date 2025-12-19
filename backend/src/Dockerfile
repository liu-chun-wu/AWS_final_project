FROM python:3.12-slim

# 環境基本設定
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# 工作目錄
WORKDIR /app

# 安裝依賴
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 複製程式碼
COPY app.py db.py ./

# 如果你還有其他 Python 檔要用到，也一併 COPY
# COPY bot.py ./

# Flask 預設在 5000
EXPOSE 5000

# 啟動指令（簡單用 python app.py）
CMD ["python", "app.py"]
