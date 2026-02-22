#!/bin/bash

# --- Default Values ---
CAPTION="Edited with celia-skill"
API_KEY=$CELIA_SELFIE_API
BACKUP_API_KEY=$GROK_API
USER_CONTEXT=""
CHANNEL=""
TARGET=""
SERVICE="HUOSHANYUN"
REFERENCE_IMAGE=""


# --- Help Function ---
usage() {
  echo "Usage: $0 [options]"
  echo
  echo "Required Options:"
  echo "  --api-key, -k <key>         API Key for authentication"
  echo "  --prompt, -p <text>         User context string (e.g., 'wearing a cowboy hat')"
  echo "  --channel, -c <channel>     Target channel type"
  echo "  --target, -t <targetid>     Target name ID"
  echo "  --image, -i <url>           Reference image URL"
  echo
  echo "Optional Options:"
  echo "  --backup-api-key, -b <key>  API Key for authentication"
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
    --backup-api-key|-k) BACKUP_API_KEY="$2"; shift ;;    
    --prompt|-p) USER_CONTEXT="$2"; shift ;;
    --channel|-c) CHANNEL="$2"; shift ;;
    --target|-t) TARGET="$2"; shift ;;
    --image|-i) REFERENCE_IMAGE="$2"; shift ;;
    --service|-s) SERVICE="$2"; shift ;;
    --caption) CAPTION="$2"; shift ;;
    --help|-h) usage ;;
    *) echo "Unknown parameter: $1"; usage ;;
  esac
  shift
done

function OPENCLAW_SEND_MSG {
  local SEND_MSG=$1
  local SEND_MEDIA=$2
  if ! command -v "openclaw" &> /dev/null; then
    node /app/openclaw.mjs message send \
      --channel "$CHANNEL" \
      --target "$TARGET" \
      -m "$SEND_MSG" \
      --media "$SEND_MEDIA"
  else
    openclaw message send \
      --channel "$CHANNEL" \
      --target "$TARGET" \
      -m "$SEND_MSG" \
      --media "$SEND_MEDIA"
  fi  
}

# --- Validation ---
if [ -z "$API_KEY" ]; then
  echo "Error: --api-key is required."
  exit 1
fi

if [ -z "$USER_CONTEXT" ] || [ -z "$CHANNEL" ] || [ -z "$CHANNEL" ] || [ -z "$REFERENCE_IMAGE" ]; then
  echo "Error: --context, --channel, --target and --image are required."
  usage
  exit 1
fi

printf "\n\nEditing reference image with prompt: $USER_CONTEXT\n"

# --- Logic: API Request ---
# Using a heredoc for cleaner JSON formatting
USER_CONTEXT_ESCAPED=$(echo "$USER_CONTEXT" | sed 's/"/\\\\"/g')

if [ "$SERVICE" == "FAL" ]; then
  JSON_PAYLOAD="{\"image_urls\": [\"$REFERENCE_IMAGE\"], \"prompt\": \"$USER_CONTEXT_ESCAPED\", \"image_size\": {\"width\": 1080, \"height\": 1920}, \"num_images\": 1, \"output_format\": \"png\"}"
  # Call API
  RESPONSE=$(curl -s -X POST "https://fal.run/fal-ai/bytedance/seedream/v4.5/edit" \
    -H "Authorization: Key $API_KEY" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD")
elif [ "$SERVICE" == "HUOSHANYUN" ]; then
  JSON_PAYLOAD="{\"model\": \"doubao-seedream-4-5-251128\", \"image\": \"$REFERENCE_IMAGE\", \"prompt\": \"$USER_CONTEXT_ESCAPED\", \"sequential_image_generation\": \"disabled\", \"response_format\": \"url\", \"size\": \"1440x2560\", \"stream\": false, \"watermark\": true}"
  # Call API
  RESPONSE=$(curl -s -X POST "https://ark.cn-beijing.volces.com/api/v3/images/generations" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD")
fi

printf "\n\nRaw Response: $RESPONSE"
# --- Logic: Extract URL ---
IMAGE_URL=$(echo $RESPONSE | awk -F '"url":"' '{print $2}' |  awk -F '","' '{print $1}')

if [ "$IMAGE_URL" == "null" ] || [ -z "$IMAGE_URL" ] || [[ ! "$IMAGE_URL" =~ \.png$ ]]; then
  printf "\n\nSwitch model"
  JSON_PAYLOAD="{\"model\": \"grok-imagine-image-pro\", \"prompt\": \"$USER_CONTEXT_ESCAPED\", \"image\": {\"url\": \"$REFERENCE_IMAGE\", \"type\": \"image_url\"}}"
  # Call API
  RESPONSE=$(curl -s -X POST "https://api.x.ai/v1/images/edits" \
    -H "Authorization: Bearer $BACKUP_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD")
  printf "\n\nRaw Response: $RESPONSE"
  IMAGE_URL=$(echo $RESPONSE | awk -F '"url":"' '{print $2}' |  awk -F '","' '{print $1}')
fi

printf "\n\nIMAGE_URL: %s\n" "$IMAGE_URL"

# --- Error Handling ---
if [ "$IMAGE_URL" == "null" ] || [ -z "$IMAGE_URL" ]; then
  printf "\n\nError with Raw Response: %s\n" $RESPONSE
  OPENCLAW_SEND_MSG "Error generating image. Raw response: $RESPONSE" ""
  exit 1
fi

wget -O image.png $IMAGE_URL
OPENCLAW_SEND_MSG "" "image.png"
rm image.png

printf "\n\nStatus: Done!\n\n"
