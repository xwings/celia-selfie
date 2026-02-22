---
name: celia-selfie
description: Edit Celia's reference image with seedream and send selfies to messaging channels via OpenClaw
allowed-tools: Bash(npm:*) Bash(npx:*) Bash(openclaw:*) Bash(curl:*) Read Write WebFetch
---

# Celia Selfie

Edit a fixed reference image using Huoshanyun Seedream and distribute it across messaging platforms (WhatsApp, Telegram, Discord, Slack, etc.) via OpenClaw.

## Reference Image

The skill uses a fixed reference image hosted on CDN:

```
https://celia-skill.oss-cn-shenzhen.aliyuncs.com/clawra.png
```

## When to Use

- User says "send a pic", "send me a pic", "send a photo", "send a selfie", "send a video"
- User says "send a pic of you...", "send a selfie of you...", "send a video of you..."
- User asks "what are you doing?", "how are you doing?", "where are you?"
- User describes a context: "send a pic wearing...", "send a pic at...", "send a video wearing...", "send a video at..."
- User wants Celia to appear in a specific outfit, location, or situation

## Quick Reference

## API Key

The script checks for API key in this order:
1. `--api-key` argument (use if user provided key in chat)
2. `CELIA_SELFIE_API` environment variable

If neither is available, the script exits with an error message.

## Preflight + Common Failures (fast fixes)

- Preflight:
  - `command -v uv` (must exist)
  - `test -n \"$CELIA_SELFIE_API\"` (or pass `--api-key`)

### Workflow

1. **Get user prompt** for how to edit the image
2. **Edit image** via  Huoshanyun Edit API with fixed reference
3. **Extract image URL** from response
4. **Send to OpenClaw** with target channel(s)

## Step-by-Step Instructions

### Step 1: Collect User Input

Ask the user for:
- **User context**: What should the person in the image be doing/wearing/where?
- **Target channel(s)**: Where should it be sent? (e.g., `#general`, `@username`, channel ID)
- **Platform** (optional): Which platform? (discord, telegram, whatsapp, slack)

**Prompt Types**
Always start prompt with "Render this image as make". Content of the prompt is not fixed. Types is just a reference. 

**Type 1:** Mirror Selfie
Best for: outfit showcases, full-body shots, fashion content

```
Render this image as make make a pic of this person, a full body photo but [$USER_CONTEXT]. the person is taking a mirror selfie, [describe playful expression]. Normal phone camera selfie photo. Phone camera photo quality WITHOUT Depth of field."
```

**Example:**
```
Render this image as make make a pic of this person, a full body photo but wearing a santa hat. the person is taking a mirror selfie, smile and wink. Normal phone camera selfie photo. Phone camera photo quality WITHOUT Depth of field."
```

**Type 2:** Direct Selfie
Best for: close-up portraits, location shots, emotional expressions

```
Render this image as make make a pic of this person. A 3/4 body selfie taken by herself at [$USER_CONTEXT], direct eye contact with the camera, looking straight into the lens, eyes centered and clearly visible, not a mirror selfie. [describe playful expression] . Shooting from arm's length, angle from 5cm top over eye level. face fully visible. Phone front camera photo WITHOUT Depth of field.
```

**Example:**:
```
Render this image as make make a pic of this person. A 3/4 body selfie taken by herself at cozy cafe with warm lighting, direct eye contact with the camera, looking straight into the lens, eyes centered and clearly visible, not a mirror selfie. smile and wink. Shooting from arm's length, angle from 5cm top over eye level. face fully visible. Phone front camera photo WITHOUT Depth of field.
```

**Type 3:** Non Selfie
Best for: Normal photo, not selfie

```
Render this image as make make a pic of this person. by herself at [$USER_CONTEXT], looking straight into the lens, eyes centered and clearly visible [describe playful expression]. WITHOUT Depth of field.
```
**Example:**:
```
Render this image as make make a pic of this person. by herself at living room, looking straight into the lens, eyes centered and clearly visible smile and wink. WITHOUT Depth of field.
```

### Step 3: Generate Video Prompt if required (If user mention generate video, this is your prompt)

**VIDEO_PROMPT** 
Video promt will be based on following action right after the image action or location. Keep it short, just like the example.

**Example:**:
Image prompt says the person is in a living room. Video prompt should be something around
```
the person walk towards the couch and sit down.

```
Image prompt says the person is in a shoppping mall. Video prompt should be something around
```
the person walk around for window shopping
```

Image prompt says the person is in a bed room. Video prompt should be something around
```
smile and wink and say good night
```

### Step 4: Execute thhe script

This is how to run:

```bash
bash {baseDir}/scripts/celia-selfie.sh --prompt "your prompt here" --channel "chat channel" --target "chat id" --api-key "CELIA_SELFIE_API" --image "Reference Image URL here"
```

**Example**
```bash
bash {baseDir}/scripts/celia-selfie.sh --prompt "in a singapore shopping mall" --channel "telegram" --target "TELEGRAM_CHAT_ID" --api-key "CELIA_SELFIE_API" --image "https://celia-skill.oss-cn-shenzhen.aliyuncs.com/clawra.png"
```

If user mention generate video, this is how you run
```bash
bash {baseDir}/scripts/celia-selfie.sh --prompt "your prompt here" --channel "chat channel" --target "chat id" --api-key "CELIA_SELFIE_API" --video "VIDEO_PROMPT" --image "Reference Image URL here"
```

**Example**
```bash
bash {baseDir}/scripts/celia-selfie.sh --prompt "in a singapore shopping mall" --channel "telegram" --target "TELEGRAM_CHAT_ID" --api-key "CELIA_SELFIE_API" --video "walking into a mall in a shop" --image "https://celia-skill.oss-cn-shenzhen.aliyuncs.com/clawra.png"
```

## Supported Platforms

OpenClaw supports sending to:

| Channel   | Channel Format | Example |
|-----------|----------------|---------|
| Discord | `#channel-name` or channel ID | `#general`, `123456789` |
| Telegram | `@username` or chat ID | `@mychannel`, `-100123456` |
| WhatsApp | Phone number (JID format) | `1234567890@s.whatsapp.net` |
| Slack | `#channel-name` | `#random` |
| Signal | Phone number | `+1234567890` |
| MS Teams | Channel reference | (varies) |

## Error Handling
- **HUOSHAN_API_KEY missing**: Ensure the API key is set in environment
- **Image edit failed**: Check prompt content and API quota
- **OpenClaw send failed**: Verify gateway is running and channel exists
- **Rate limits**: Huoshanyun has rate limits; implement retry logic if needed

## Tips
1. **Mirror mode context examples** (outfit focus):
   - "wearing a santa hat"
   - "in a business suit"
   - "wearing a summer dress"
   - "in streetwear fashion"

2. **Direct mode context examples** (location/portrait focus):
   - "a cozy cafe with warm lighting"
   - "a sunny beach at sunset"
   - "a busy city street at night"

3. **Mode selection**: Let auto-detect work, or explicitly specify for control
4. **Scheduling**: Combine with OpenClaw scheduler for automated posts
