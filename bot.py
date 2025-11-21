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
async def create_photo(ctx, *, msg):
    async with ctx.typing():  # 取代 ctx.trigger_typing()
        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(
                    f"{FLASK_API_URL}/generate-image",
                    json={"prompt": msg},
                    timeout=aiohttp.ClientTimeout(total=60)
                ) as response:

                    if response.status != 200:
                        error_text = await response.text()
                        await ctx.send(f"❌ 錯誤: {response.status}\n{error_text}")
                        return

                    data = await response.json()

            if data.get('success'):
                local_url = data.get('local_url')
                local_path = data.get('local_path')

                async with aiohttp.ClientSession() as session:
                    async with session.get(local_url) as img_response:
                        if img_response.status == 200:
                            img_data = await img_response.read()

                            await ctx.send(
                                f"🎨 **已根據 `{msg}` 生成圖片！**\n📁 本地路徑: {local_path}",
                                file=discord.File(
                                    fp=io.BytesIO(img_data),
                                    filename="result.png"
                                )
                            )
                        else:
                            await ctx.send(f"❌ 無法下載圖片: {img_response.status}")
            else:
                await ctx.send(f"❌ 生成失敗: {data.get('error')}")

        except aiohttp.ClientError as e:
            await ctx.send(f"❌ 網路錯誤: {str(e)}")
        except Exception as e:
            await ctx.send(f"❌ 發生錯誤: {str(e)}")


@bot.command()
async def create_audio(ctx, *, msg):
    await ctx.trigger_typing()
    
    try:
        # 使用異步 HTTP 請求
        async with aiohttp.ClientSession() as session:
            async with session.post(
                f"{FLASK_API_URL}/generate-audio",
                json={
                    "prompt": msg,
                    "discord_channel_id": str(ctx.channel.id),
                    "discord_user_id": str(ctx.author.id)
                },
                timeout=aiohttp.ClientTimeout(total=10)
            ) as response:
                
                if response.status != 200:
                    error_text = await response.text()
                    await ctx.send(f"❌ 錯誤: {response.status}\n{error_text}")
                    return
                
                data = await response.json()
        
        if data.get('success'):
            await ctx.send(
                f"⏳ **正在生成音樂...**\n"
                f"📝 任務 ID: `{data.get('task_id')}`\n"
                f"🎵 提示: `{msg}`\n"
                f"完成後會自動通知您！"
            )
        else:
            await ctx.send(f"❌ 提交失敗: {data.get('error')}")
            
    except Exception as e:
        await ctx.send(f"❌ 發生錯誤: {str(e)}")

bot.run(DC_token, log_handler=handler, log_level=logging.DEBUG)