import discord
from discord.ext import commands
import logging
from dotenv import load_dotenv
import os
import io
import aiohttp
import requests

load_dotenv()
DC_token = os.getenv('DISCORD_TOKEN')
FLASK_API_URL = os.getenv('FLASK_API_URL', 'http://localhost:5000')

handler = logging.FileHandler(filename='discord.log', encoding='utf-8', mode='w')
intent = discord.Intents.default()
intent.message_content = True
intent.members = True

bot = commands.Bot(command_prefix='/', intents=intent)

@bot.event
async def on_ready():
    print(f"We are ready to go in, {bot.user.name}")

@bot.command()
async def hello(ctx):
    await ctx.send(f"Hello {ctx.author.mention}!")


@bot.command()
async def create_photo(ctx, *, prompt: str = "未輸入prompt"):
    try:
        payload = {"prompt": prompt, "user_id": str(ctx.author.id)}
        response = requests.post("http://localhost:5000/generate-image", json=payload, timeout=60)
        data = response.json()

        if not data.get("success"):
            err = data.get("error") or "未知錯誤"
            details = data.get("details")
            msg = f"❌ Flask 回傳錯誤: {err}"
            if details:
                msg += f"\n📝 詳細: {details}"
            await ctx.send(msg)
            return

        file_url = data.get("local_url")
        if not file_url:
            await ctx.send("❌ Flask 沒有回傳檔案 URL")
            return

        file_resp = requests.get(file_url)
        if file_resp.status_code == 200:
            with io.BytesIO(file_resp.content) as f:
                await ctx.send(file=discord.File(f, filename="generated.png"))
        else:
            await ctx.send("❌ 下載圖片失敗")

    except Exception as e:
        await ctx.send(f"❌ 呼叫 Flask 失敗: {e}")


# /create_audio 指令
@bot.command()
async def create_audio(ctx,*,prompt: str="未輸入prompt"):
    # await ctx.send("這是生成音樂的功能")
    try:
        payload = {"prompt": prompt}
        response = requests.post("http://localhost:5000/generate-audio", json=payload, timeout=10)
        data = response.json()
        
        if not data.get("success"):
            await ctx.send(f"❌ Flask 回傳錯誤: {data.get('reply', '未知錯誤')}")
            return

        # 2️⃣ 取得 local_url
        file_url = data.get("local_url")
        if not file_url:
            await ctx.send("❌ Flask 沒有回傳檔案 URL")
            return
        
        # 3️⃣ 從 URL 下載檔案內容
        file_resp = requests.get(file_url)
        file_content = file_resp.text  # 文字檔使用 text
        
        # 4️⃣ 將內容回 Discord
        await ctx.send(f"✅ 從 Flask 取得檔案內容:\n{file_content}")

    except Exception as e:
        await ctx.send(f"❌ 呼叫 Flask 失敗: {e}")

@bot.command()
async def history(ctx):
    try:
        # 自動帶入 Discord 使用者 ID
        response = requests.get(f"{FLASK_API_URL}/history?user_id={ctx.author.id}", timeout=10)
        data = response.json()

        if not data.get("success"):
            await ctx.send(f"❌ Flask 回傳錯誤: {data.get('error', '未知錯誤')}")
            return

        records = data.get("records", [])
        if not records:
            await ctx.send(f"📭 使用者 {ctx.author.id} 沒有任何紀錄。")
            return

        # 組合輸出
        msg_lines = [f"{r['id']}. {r['prompt']} → {r['file_url']}" for r in records]
        msg = "\n".join(msg_lines)

        # 分段輸出避免超過 Discord 限制
        if len(msg) > 1900:
            chunks = [msg[i:i+1900] for i in range(0, len(msg), 1900)]
            for chunk in chunks:
                await ctx.send(f"📜 你的紀錄:\n{chunk}")
        else:
            await ctx.send(f"📜 你的紀錄:\n{msg}")

    except Exception as e:
        await ctx.send(f"❌ 查詢 DB 失敗: {e}")



bot.run(DC_token, log_handler=handler, log_level=logging.DEBUG)