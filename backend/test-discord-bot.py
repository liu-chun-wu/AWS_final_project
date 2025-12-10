"""
Simple Discord Bot for Testing Backend API

This bot allows you to test the AI generation backend through Discord commands.
"""

import discord
from discord.ext import commands
import aiohttp
import os
from pathlib import Path
from dotenv import load_dotenv

# Load environment variables from .env in same directory
env_file = Path(__file__).parent / ".env"
if env_file.exists():
    load_dotenv(env_file)
else:
    load_dotenv()  # Try current directory or parent

# Configuration
DISCORD_TOKEN = os.getenv("DISCORD_TOKEN") or os.getenv("DISCORD_BOT_TOKEN")
API_BASE_URL = os.getenv("API_GATEWAY_URL", "http://localhost:8000")

# Discord bot setup
intents = discord.Intents.default()
intents.message_content = True
bot = commands.Bot(command_prefix="!", intents=intents)


@bot.event
async def on_ready():
    """Called when bot is ready"""
    print(f"[OK] Bot is ready! Logged in as {bot.user}")
    print(f"[API] {API_BASE_URL}")
    print("Commands: !health, !image, !audio, !history, !commands")


@bot.command(name="health")
async def health_check(ctx):
    """Check if the backend is healthy"""
    await ctx.send("🔍 Checking backend health...")

    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(f"{API_BASE_URL}/health", timeout=10) as response:
                if response.status == 200:
                    data = await response.json()
                    await ctx.send(f"✅ Backend is healthy!\n```json\n{data}\n```")
                else:
                    await ctx.send(f"❌ Backend returned status {response.status}")
    except Exception as e:
        await ctx.send(f"❌ Error connecting to backend: {str(e)}")


@bot.command(name="image")
async def generate_image(ctx, *, prompt: str):
    """
    Generate an AI image
    Usage: !image <description>
    Example: !image a beautiful sunset over mountains
    """
    user_id = str(ctx.author.id)
    await ctx.send(f"🎨 Generating image: `{prompt}`\n⏳ This may take 10-30 seconds...")

    try:
        payload = {
            "prompt": prompt,
            "user_id": user_id
        }

        async with aiohttp.ClientSession() as session:
            async with session.post(
                f"{API_BASE_URL}/generate-image",
                json=payload,
                timeout=120
            ) as response:
                data = await response.json()

                if response.status == 200 and data.get("success"):
                    download_url = data.get("download_url")
                    embed = discord.Embed(
                        title="✅ Image Generated!",
                        description=f"**Prompt:** {prompt}",
                        color=discord.Color.green()
                    )
                    embed.set_image(url=download_url)
                    # Truncate URL if too long (Discord 1024 char limit per field)
                    url_display = download_url if len(download_url) < 900 else download_url[:900] + "..."
                    embed.set_footer(text=f"Download: {url_display[:100]}...")
                    await ctx.send(embed=embed)
                else:
                    error = data.get("error", "Unknown error")
                    await ctx.send(f"❌ Failed to generate image:\n```\n{error}\n```")

    except Exception as e:
        await ctx.send(f"❌ Error: {str(e)}")


@bot.command(name="audio")
async def generate_audio(ctx, *, prompt: str):
    """
    Generate AI music
    Usage: !audio <description>
    Example: !audio relaxing piano music
    """
    user_id = str(ctx.author.id)
    await ctx.send(f"🎵 Generating music: `{prompt}`\n⏳ This may take 1-2 minutes...")

    try:
        payload = {
            "prompt": prompt,
            "user_id": user_id
        }

        async with aiohttp.ClientSession() as session:
            async with session.post(
                f"{API_BASE_URL}/generate-audio",
                json=payload,
                timeout=120
            ) as response:
                data = await response.json()

                if response.status == 200 and data.get("success"):
                    task_id = data.get("task_id")
                    download_url = data.get("download_url")

                    embed = discord.Embed(
                        title="✅ Music Generation Started!",
                        description=f"**Prompt:** {prompt}\n**Task ID:** {task_id}",
                        color=discord.Color.blue()
                    )
                    # Truncate URL if too long for Discord embed (1024 char limit per field)
                    url_display = download_url if len(download_url) < 900 else download_url[:900] + "..."

                    embed.add_field(
                        name="Status",
                        value=f"⏳ Processing... [Download when ready]({url_display})",
                        inline=False
                    )
                    embed.set_footer(text="Note: Audio generation is async and may take 1-2 minutes")
                    await ctx.send(embed=embed)
                else:
                    error = data.get("error", "Unknown error")
                    await ctx.send(f"❌ Failed to generate audio:\n```\n{error}\n```")

    except Exception as e:
        await ctx.send(f"❌ Error: {str(e)}")


@bot.command(name="history")
async def get_history(ctx):
    """
    Get your generation history
    Usage: !history
    """
    user_id = str(ctx.author.id)
    await ctx.send(f"📜 Fetching your history...")

    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(
                f"{API_BASE_URL}/history",
                params={"user_id": user_id},
                timeout=10
            ) as response:
                data = await response.json()

                if response.status == 200 and data.get("success"):
                    records = data.get("records", [])

                    if not records:
                        await ctx.send("📭 You have no generation history yet!")
                        return

                    embed = discord.Embed(
                        title="📜 Your Generation History",
                        description=f"Total records: {len(records)}",
                        color=discord.Color.purple()
                    )

                    # Show last 5 records
                    for i, record in enumerate(records[:5], 1):
                        record_type = record.get("type", "unknown")
                        prompt = record.get("prompt", "No prompt")
                        file_url = record.get("file_url", "")

                        emoji = "🎨" if record_type == "image" else "🎵"
                        embed.add_field(
                            name=f"{emoji} Record {i} - {record_type.title()}",
                            value=f"**Prompt:** {prompt[:100]}...\n[Download]({file_url})",
                            inline=False
                        )

                    if len(records) > 5:
                        embed.set_footer(text=f"Showing 5 of {len(records)} records")

                    await ctx.send(embed=embed)
                else:
                    error = data.get("error", "Unknown error")
                    await ctx.send(f"❌ Failed to fetch history:\n```\n{error}\n```")

    except Exception as e:
        await ctx.send(f"❌ Error: {str(e)}")


@bot.command(name="ping")
async def ping(ctx):
    """Check bot latency"""
    latency = round(bot.latency * 1000)
    await ctx.send(f"🏓 Pong! Latency: {latency}ms")


@bot.command(name="commands")
async def show_commands(ctx):
    """Show available commands"""
    embed = discord.Embed(
        title="🤖 AI Generation Bot Commands",
        description="Test the AI generation backend through Discord!",
        color=discord.Color.blue()
    )

    embed.add_field(
        name="!health",
        value="Check if backend is healthy",
        inline=False
    )
    embed.add_field(
        name="!image <description>",
        value="Generate an AI image\nExample: `!image a cat on a piano`",
        inline=False
    )
    embed.add_field(
        name="!audio <description>",
        value="Generate AI music\nExample: `!audio relaxing piano music`",
        inline=False
    )
    embed.add_field(
        name="!history",
        value="View your generation history",
        inline=False
    )
    embed.add_field(
        name="!ping",
        value="Check bot latency",
        inline=False
    )

    embed.set_footer(text=f"API URL: {API_BASE_URL}")
    await ctx.send(embed=embed)


if __name__ == "__main__":
    import sys
    import io

    # Fix Windows console encoding
    if sys.platform == 'win32':
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

    if not DISCORD_TOKEN:
        print("Error: DISCORD_TOKEN not found in .env file")
        print("Please add your Discord bot token to the .env file:")
        print("DISCORD_TOKEN=your_discord_bot_token_here")
        exit(1)

    print("Starting Discord bot...")
    print(f"Backend API: {API_BASE_URL}")
    bot.run(DISCORD_TOKEN)
