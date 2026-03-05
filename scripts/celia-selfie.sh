#!/bin/bash

# --- Default Values ---
CAPTION="Edited with celia-skill"
API_KEY=$CELIA_SELFIE_API
BACKUP_API_KEY=$GROK_API
PIC_PROMPT=""
CHANNEL=""
TARGET=""
SERVICE="FAL"
REFERENCE_IMAGE=""
VIDEO=""
VIDEO_PROVIDER="FAL"

# --- Dependency Check ---
if ! command -v jq &> /dev/null; then
  echo "Error: jq is required but not installed. Install it with: apt-get install jq"
  exit 1
fi

# --- Help Function ---
usage() {
  echo "Usage: $0 [options]"
  echo
  echo "Required Options:"
  echo "  --api-key, -k <key>         API Key for authentication"
  echo "  --picture, -p <text>        User context string (e.g., 'wearing a cowboy hat')"
  echo "  --channel, -c <channel>     Target channel type"
  echo "  --target, -t <targetid>     Target name ID"
  echo "  --image, -i <url>           Reference image URL"
  echo
  echo "Optional Options:"
  echo "  --backup-api-key, -b <key>  API Key for authentication"
  echo "  --video <text>              Turn image into video"
  echo "  --caption <text>            Caption for the message (default: 'Edited with celia-skill')"
  echo "  --service, -s <MODEL>       AI service provider (default: 'FAL')"
  echo "  --help, -h                  Show this help message"
  echo
  exit 1
}

# --- Argument Parsing ---
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --api-key|-k) API_KEY="$2"; shift ;;
    --backup-api-key|-b) BACKUP_API_KEY="$2"; shift ;;
    --picture|-p) PIC_PROMPT="$2"; shift ;;
    --channel|-c) CHANNEL="$2"; shift ;;
    --target|-t) TARGET="$2"; shift ;;
    --image|-i) REFERENCE_IMAGE="$2"; shift ;;
    --service|-s) SERVICE="$2"; shift ;;
    --caption) CAPTION="$2"; shift ;;
    --video) VIDEO_PROMPT="$2"; shift ;;
    --help|-h) usage ;;
    *) echo "Unknown parameter: $1"; usage ;;
  esac
  shift
done

function OPENCLAW_SEND_MSG {
  local SEND_MSG=$1
  if ! command -v "openclaw" &> /dev/null; then
    node /app/openclaw.mjs message send \
      --channel "$CHANNEL" \
      --target "$TARGET" \
      -m "$SEND_MSG"
  else
    openclaw message send \
      --channel "$CHANNEL" \
      --target "$TARGET" \
      -m "$SEND_MSG"
  fi
}

# --- Validation ---
if [ -z "$API_KEY" ]; then
  echo "Error: --api-key is required."
  exit 1
fi

if [ -z "$PIC_PROMPT" ] || [ -z "$CHANNEL" ] || [ -z "$TARGET" ] || [ -z "$REFERENCE_IMAGE" ]; then
  echo "Error: --picture, --channel, --target and --image are required."
  usage
  exit 1
fi

printf "\n\nEditing reference image with prompt: %s\n" "$PIC_PROMPT"

# --- Logic: API Request ---
if [ "$SERVICE" == "FAL" ]; then
  JSON_PAYLOAD=$(jq -n \
    --arg prompt "$PIC_PROMPT" \
    --arg image "$REFERENCE_IMAGE" \
    '{image_urls: [$image], prompt: $prompt, image_size: {width: 1080, height: 1920}, num_images: 1, output_format: "png"}')
  # Call API
  RESPONSE=$(curl -s -X POST "https://fal.run/fal-ai/bytedance/seedream/v4.5/edit" \
    -H "Authorization: Key $API_KEY" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD")
elif [ "$SERVICE" == "HUOSHANYUN" ]; then
  JSON_PAYLOAD=$(jq -n \
    --arg prompt "$PIC_PROMPT" \
    --arg image "$REFERENCE_IMAGE" \
    '{model: "doubao-seedream-4-5-251128", image: $image, prompt: $prompt, sequential_image_generation: "disabled", response_format: "url", size: "1440x2560", stream: false, watermark: true}')
  # Call API
  RESPONSE=$(curl -s -X POST "https://ark.cn-beijing.volces.com/api/v3/images/generations" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD")
fi

printf "\n\nRaw Response: %s\n" "$RESPONSE"
# --- Logic: Extract URL ---
IMAGE_URL=$(echo "$RESPONSE" | jq -r '.. | .url? // empty' | head -1)

if [ -z "$IMAGE_URL" ] || [[ ! "$IMAGE_URL" =~ \.png$ ]]; then
  printf "\n\nSwitch model\n"
  JSON_PAYLOAD=$(jq -n \
    --arg prompt "$PIC_PROMPT" \
    --arg image "$REFERENCE_IMAGE" \
    '{model: "grok-imagine-image", prompt: $prompt, image: {url: $image, type: "image_url"}}')
  # Call API
  RESPONSE=$(curl -s -X POST "https://api.x.ai/v1/images/edits" \
    -H "Authorization: Bearer $BACKUP_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD")
  printf "\n\nResponse: %s\n" "$RESPONSE"
  IMAGE_URL=$(echo "$RESPONSE" | jq -r '.. | .url? // empty' | head -1)
fi

printf "\n\nIMAGE_URL: %s\n" "$IMAGE_URL"

# --- Error Handling ---
if [ -z "$IMAGE_URL" ]; then
  printf "\n\nError with Raw Response: %s\n" "$RESPONSE"
  OPENCLAW_SEND_MSG "Error generating image. Raw response: $RESPONSE"
  exit 1
else
  OPENCLAW_SEND_MSG "Image on the way. MEDIA: $IMAGE_URL"
fi

printf "\n\nVIDEO_PROMPT: %s\n" "$VIDEO_PROMPT"

if [[ -n "$IMAGE_URL" && -n "$VIDEO_PROMPT" ]]; then
  VIDEO_PROMPT_ESC=$(echo "$PIC_PROMPT" | grep "mirror")

  if [ ! -z "$VIDEO_PROMPT_ESC" ]; then
    VIDEO_PROMPT_EDIT="Speak chinese. Put down the phone. Walk away from mirror. $VIDEO_PROMPT"
  else
    VIDEO_PROMPT_EDIT="Speak chinese. $VIDEO_PROMPT"
  fi

  printf "\n\nVIDEO_PROMPT_EDIT: %s\n" "$VIDEO_PROMPT_EDIT"

  if [ "$VIDEO_PROVIDER" == "XAI" ]; then
    JSON_PAYLOAD=$(jq -n \
      --arg prompt "$VIDEO_PROMPT_EDIT" \
      --arg image "$IMAGE_URL" \
      '{model: "grok-imagine-video", prompt: $prompt, duration: 15, image: {url: $image}}')
    RESPONSE=$(curl -s -X POST "https://api.x.ai/v1/videos/generations" \
      -H "Authorization: Bearer $BACKUP_API_KEY" \
      -H "Content-Type: application/json" \
      -d "$JSON_PAYLOAD")
    VIDEO_ID=$(echo "$RESPONSE" | jq -r '.request_id')
    VIDEO_ID_URL="https://api.x.ai/v1/videos/$VIDEO_ID"
    VIDEO_ID_URL_HEADER="Authorization: Bearer $BACKUP_API_KEY"

  elif [ "$VIDEO_PROVIDER" == "FAL" ]; then
    JSON_PAYLOAD=$(jq -n \
      --arg prompt "$VIDEO_PROMPT_EDIT" \
      --arg image "$IMAGE_URL" \
      '{prompt: $prompt, duration: 15, image_url: $image, video_output_type: "mp4", video_quality: "high"}')
    RESPONSE=$(curl -s -X POST "https://queue.fal.run/fal-ai/kling-video/o3/standard/image-to-video" \
      -H "Authorization: Key $API_KEY" \
      -H "Content-Type: application/json" \
      -d "$JSON_PAYLOAD")
    VIDEO_ID=$(echo "$RESPONSE" | jq -r '.request_id')
    VIDEO_ID_URL="https://queue.fal.run/fal-ai/kling-video/requests/$VIDEO_ID"
    VIDEO_ID_URL_HEADER="Authorization: Key $API_KEY"
  fi


  printf "\n\nVideo Response: %s\n" "$RESPONSE"
  printf "\n\nVIDEO_ID: %s\n" "$VIDEO_ID"

  i=0
  while [ $i -le 120 ]; do
    # Make the API call and capture the response
    VIDEO_RESPONSE=$(curl -s -X GET "$VIDEO_ID_URL" \
        -H "$VIDEO_ID_URL_HEADER")

    # Check if the response contains a url field
    VIDEO_URL=$(echo "$VIDEO_RESPONSE" | jq -r '.. | .url? // empty' | head -1)
    printf "\n\nCurrent Status: %s\n" "$VIDEO_RESPONSE"

    if [ -n "$VIDEO_URL" ]; then
      break
    fi
    i=$((i+1))
    sleep 5
  done
  printf "\n\nVIDEO_URL: %s\n" "$VIDEO_URL"
fi

# --- Error Handling ---
if [[ -n "$VIDEO_PROMPT" ]]; then
  if [ -z "$VIDEO_URL" ]; then
    printf "\n\nError with Raw Response: %s\n" "$VIDEO_RESPONSE"
    OPENCLAW_SEND_MSG "Error generating video. Raw response: $VIDEO_RESPONSE"
    exit 1
  else
    OPENCLAW_SEND_MSG "Video on the way. MEDIA: $VIDEO_URL"
  fi
fi

printf "\n\nStatus: Done!\n\n"
