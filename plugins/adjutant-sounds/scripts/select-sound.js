ObjC.import("Foundation");

function readStandardInput() {
  const data = $.NSFileHandle.fileHandleWithStandardInput.readDataToEndOfFile;
  return ObjC.unwrap(
    $.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding)
  );
}

function readTextFile(path) {
  if (!path) {
    return "";
  }

  const contents = $.NSString.stringWithContentsOfFileEncodingError(
    path,
    $.NSUTF8StringEncoding,
    null
  );

  return contents ? ObjC.unwrap(contents) : "";
}

function lastAssistantMessageFromTranscript(path) {
  const transcript = readTextFile(path);
  let lastMessage = "";

  transcript.split(/\r?\n/).forEach((line) => {
    if (!line.trim()) {
      return;
    }

    try {
      const item = JSON.parse(line);
      const payload = item && item.type === "response_item" ? item.payload : null;
      if (!payload || payload.type !== "message" || payload.role !== "assistant") {
        return;
      }

      const text = (payload.content || [])
        .map((part) => (part && typeof part.text === "string" ? part.text : ""))
        .join("");

      if (text) {
        lastMessage = text;
      }
    } catch (_) {
      // Ignore incomplete or non-JSON transcript lines.
    }
  });

  return lastMessage;
}

function run() {
  let payload = {};

  try {
    payload = JSON.parse(readStandardInput() || "{}");
  } catch (_) {
    payload = {};
  }

  const lastMessage =
    typeof payload.last_assistant_message === "string"
      ? payload.last_assistant_message
      : "";
  const transcriptMessage = lastAssistantMessageFromTranscript(
    typeof payload.transcript_path === "string" ? payload.transcript_path : ""
  );

  if ((lastMessage + "\n" + transcriptMessage).includes("<proposed_plan>")) {
    return "plan.wav";
  }

  return Math.random() < 0.5 ? "addon.wav" : "upgrade.wav";
}

