-- Whisper Dictate: Push-to-talk dictation using `§`
-- Press and hold `§` to start recording, press again to stop and transcribe

local recording = false
local recTask = nil

local DATA_DIR = os.getenv("HOME") .. "/.whisper-dictate"
local AUDIO_RAW = DATA_DIR .. "/audio-raw.wav"
local AUDIO_FILE = DATA_DIR .. "/audio.wav"
local LOG_FILE = DATA_DIR .. "/whisper-dictate.log"
local SERVER_URL = "http://127.0.0.1:9876/inference"

local LANGUAGE = "auto"
local LANGUAGES = { "auto", "en", "nl" }

-- Ensure data directory exists
os.execute("mkdir -p " .. DATA_DIR)

local function log(msg)
	local f = io.open(LOG_FILE, "a")
	if f then
		f:write(string.format("[whisper-dictate] %s %s\n", os.date("%H:%M:%S"), msg))
		f:close()
	end
	print("[whisper-dictate]", msg)
end

local function toggleLanguage()
	for i, lang in ipairs(LANGUAGES) do
		if lang == LANGUAGE then
			LANGUAGE = LANGUAGES[(i % #LANGUAGES) + 1]
			break
		end
	end
	hs.alert.show("Language: " .. LANGUAGE)
	log("Language set to: " .. LANGUAGE)
end

-- Sound effects
local stopSound = hs.sound.getByName("Purr")

local function startRecording()
	if recording then
		return
	end
	recording = true

	log("Starting recording...")

	-- Remove old files
	os.remove(AUDIO_RAW)
	os.remove(AUDIO_FILE)

	-- Start recording with sox
	recTask = hs.task.new("/opt/homebrew/bin/rec", nil, { "-q", "-c", "1", "-b", "16", AUDIO_RAW })
	recTask:start()

	log("Recording started (PID: " .. tostring(recTask:pid()) .. ")")
end

local function stopRecording()
	if not recording then
		return
	end
	recording = false

	if stopSound then
		stopSound:play()
	end
	log("Stopping recording...")

	-- Stop recording
	if recTask then
		recTask:terminate()
		recTask = nil
	end

	-- Small delay for file to be written
	hs.timer.usleep(100000)

	log("Recording stopped, processing...")

	-- Process audio file
	local processScript = string.format(
		[[
export PATH="/opt/homebrew/bin:$PATH"
AUDIO_RAW="%s"
AUDIO_FILE="%s"
SERVER_URL="%s"
LOG_FILE="%s"
LANGUAGE="%s"

log_msg() { echo "[whisper-dictate] $(date '+%%H:%%M:%%S') $*" >> "$LOG_FILE"; }

if [ ! -f "$AUDIO_RAW" ]; then
    log_msg "No audio file found"
    exit 1
fi

raw_levels=$(sox "$AUDIO_RAW" -n stat 2>&1 | grep "Maximum amplitude" || echo "unknown")
log_msg "Raw audio: $raw_levels"

sox "$AUDIO_RAW" -r 16000 "$AUDIO_FILE" norm

duration=$(soxi -D "$AUDIO_FILE" 2>/dev/null || echo "0")
if [ $(echo "$duration < 0.3" | bc -l) -eq 1 ]; then
    log_msg "Recording too short ($duration s)"
    exit 0
fi
log_msg "Audio duration: ${duration}s"

log_msg "Sending to whisper-server..."
LANG_PARAM=""
if [ "$LANGUAGE" != "auto" ]; then
    LANG_PARAM="-F language=${LANGUAGE}"
fi

response=$(curl -s -f -X POST -F "file=@${AUDIO_FILE}" -F "response_format=text" $LANG_PARAM "$SERVER_URL" 2>&1)

if [ $? -ne 0 ]; then
    log_msg "Whisper server error: $response"
    exit 1
fi

echo "$response"
]],
		AUDIO_RAW,
		AUDIO_FILE,
		SERVER_URL,
		LOG_FILE,
		LANGUAGE
	)

	hs.task
		.new("/bin/bash", function(exitCode, stdOut, stdErr)
			if exitCode == 0 and stdOut and #stdOut > 0 then
				local text = stdOut:gsub("^%s+", ""):gsub("%s+$", "")
				if text ~= "" and text ~= "[BLANK_AUDIO]" then
					-- Save current clipboard
					local oldClipboard = hs.pasteboard.getContents()
					-- Paste transcription
					hs.pasteboard.setContents(text)
					hs.eventtap.keyStroke({ "cmd" }, "v")
					-- Restore clipboard after short delay
					hs.timer.doAfter(0.5, function()
						if oldClipboard then
							hs.pasteboard.setContents(oldClipboard)
						end
					end)
				else
					log("Empty transcription, skipping")
				end
			else
				log("Processing failed: " .. (stdErr or "unknown error"))
			end
		end, { "-c", processScript })
		:start()
end

-- § key detection (key code 10) - push-to-talk, opt+§ for enter
dictationTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp }, function(event)
	local keyCode = event:getKeyCode()

	-- § is key code 10
	if keyCode == 10 then
		local eventType = event:getType()
		local flags = event:getFlags()

		-- opt+§ triggers enter
		if flags.alt then
			if eventType == hs.eventtap.event.types.keyDown then
				hs.eventtap.keyStroke({}, "return")
			end
			return true
		end

		-- ctrl+§ toggles language
		if flags.ctrl then
			if eventType == hs.eventtap.event.types.keyDown then
				toggleLanguage()
			end
			return true
		end

		-- Plain § for dictation
		if eventType == hs.eventtap.event.types.keyDown and not recording then
			startRecording()
		elseif eventType == hs.eventtap.event.types.keyUp and recording then
			stopRecording()
		end
		return true
	end

	return false
end)

dictationTap:start()

log("Whisper Dictate loaded - hold § to dictate")
