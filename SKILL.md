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

- User says "send a pic", "send me a pic", "send a photo", "send a selfie"
- User says "send a pic of you...", "send a selfie of you..."
- User asks "what are you doing?", "how are you doing?", "where are you?"
- User describes a context: "send a pic wearing...", "send a pic at..."
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
- **Mode** (optional): `mirror` or `direct` selfie style
- **Target channel(s)**: Where should it be sent? (e.g., `#general`, `@username`, channel ID)
- **Platform** (optional): Which platform? (discord, telegram, whatsapp, slack)

## Prompt Modes

### Mode 1: Mirror Selfie (default)
Best for: outfit showcases, full-body shots, fashion content

```
make a pic of this person, but [user's context]. the person is taking a mirror selfie
```

**Example**: "wearing a santa hat"
```
make a pic of this person, but wearing a santa hat. the person is taking a mirror selfie
```

### Mode 2: Direct Selfie
Best for: close-up portraits, location shots, emotional expressions

```
a close-up selfie taken by herself at [user's context], direct eye contact with the camera, looking straight into the lens, eyes centered and clearly visible, not a mirror selfie, phone held at arm's length, face fully visible
```

**Example**: "a cozy cafe with warm lighting"
```
a close-up selfie taken by herself at a cozy cafe with warm lighting, direct eye contact with the camera, looking straight into the lens, eyes centered and clearly visible, not a mirror selfie, phone held at arm's length, face fully visible
```

### Mode Selection Logic

| Keywords in Request | Auto-Select Mode |
|---------------------|------------------|
| outfit, wearing, clothes, dress, suit, fashion | `mirror` |
| cafe, restaurant, beach, park, city, location | `direct` |
| close-up, portrait, face, eyes, smile | `direct` |
| full-body, mirror, reflection | `mirror` |

### Step 2: Execute thhe script

This is how to run:

```bash
bash {baseDir}/scripts/celia-selfie.sh --context "your prompt here" --channel "chat id" --mode "Prompt modes" --api-key "CELIA_SELFIE_API" --image "Reference Image URL here"
```

**Example**
```bash
bash {baseDir}/scripts/celia-selfie.sh --context "in a singapore shopping mall" --channel "TELEGRAM_CHAT_ID" --mode "mirror" --api-key "CELIA_SELFIE_API" --image "https://celia-skill.oss-cn-shenzhen.aliyuncs.com/clawra.png"
```

## Supported Platforms

OpenClaw supports sending to:

| Platform | Channel Format | Example |
|----------|----------------|---------|
| Discord | `#channel-name` or channel ID | `#general`, `123456789` |
| Telegram | `@username` or chat ID | `@mychannel`, `-100123456` |
| WhatsApp | Phone number (JID format) | `1234567890@s.whatsapp.net` |
| Slack | `#channel-name` | `#random` |
| Signal | Phone number | `+1234567890` |
| MS Teams | Channel reference | (varies) |

## Grok Imagine Edit Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `image_url` | string | required | URL of image to edit (fixed in this skill) |
| `prompt` | string | required | Edit instruction |
| `num_images` | 1-4 | 1 | Number of images to generate |
| `output_format` | enum | "jpeg" | jpeg, png, webp |

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
   - "a peaceful park in autumn"

3. **Mode selection**: Let auto-detect work, or explicitly specify for control
4. **Batch sending**: Edit once, send to multiple channels
5. **Scheduling**: Combine with OpenClaw scheduler for automated posts
