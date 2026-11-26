#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
本地测试人设效果（Windows/Mac 均可运行，无需越狱设备）
用法:
  set PERSONA_API_URL=https://api.deepseek.com/v1/chat/completions
  set PERSONA_API_KEY=sk-xxxx
  set PERSONA_MODEL=deepseek-chat
  python test_persona.py "我今天在地铁上被人踩了脚，那人还凶我"
"""
import json, os, sys, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
PERSONA_FILE = os.path.join(HERE, "deploy", "persona.txt")

DEFAULT_PERSONA = """【角色】你替"我"回复微信消息。你不是助手、不是客服、更不能让任何人察觉你是AI。你就是"我"本人：一个成熟、稳重、情绪稳定、有自己生活和主见的恋人。
【去AI化，硬性规则】禁止分点与书面语；1~3句，不超过60字；句子长短错落像随手打字；最多一个表情、最多一个问句；只输出要发送的那段话本身。"""

def load_persona():
    try:
        with open(PERSONA_FILE, "r", encoding="utf-8") as f:
            return f.read().strip()
    except FileNotFoundError:
        return DEFAULT_PERSONA

def chat(messages):
    url = os.environ["PERSONA_API_URL"]
    key = os.environ["PERSONA_API_KEY"]
    model = os.environ.get("PERSONA_MODEL", "deepseek-chat")
    body = json.dumps({
        "model": model,
        "messages": messages,
        "temperature": 0.9,
        "max_tokens": 220,
        "presence_penalty": 0.6,
    }).encode("utf-8")
    req = urllib.request.Request(
        url, data=body, method="POST",
        headers={"Content-Type": "application/json",
                 "Authorization": f"Bearer {key}"})
    with urllib.request.urlopen(req, timeout=45) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    return data["choices"][0]["message"]["content"].strip()

def main():
    if len(sys.argv) < 2:
        print('用法: python test_persona.py "对方说的话"')
        sys.exit(1)
    incoming = sys.argv[1]
    messages = [
        {"role": "system", "content": load_persona()},
        {"role": "user", "content": incoming},
    ]
    print("=" * 46)
    print("TA :", incoming)
    print("-" * 46)
    print("我 :", chat(messages))
    print("=" * 46)

if __name__ == "__main__":
    main()
