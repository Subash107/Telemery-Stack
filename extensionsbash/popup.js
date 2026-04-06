const HOST_NAME = "com.bbp.url_checker";
const DEFAULT_URLS = ["https://example.com", "https://example.org"];
const DEFAULT_PROXY_URL = "http://192.168.1.6:8082";

const form = document.getElementById("url-form");
const url1Input = document.getElementById("url-1");
const url2Input = document.getElementById("url-2");
const proxyInput = document.getElementById("proxy-url");
const runButton = document.getElementById("run-button");
const output = document.getElementById("output");
const statusPill = document.getElementById("status-pill");

initializeForm();

form.addEventListener("submit", async (event) => {
  event.preventDefault();

  const urls = [url1Input.value.trim(), url2Input.value.trim()];
  const proxyUrl = proxyInput.value.trim();
  const invalidUrl = urls.find((url) => !isValidUrl(url));

  if (invalidUrl) {
    setStatus("error", "Invalid");
    output.textContent = `This does not look like a valid URL: ${invalidUrl}`;
    return;
  }

  if (!isValidUrl(proxyUrl)) {
    setStatus("error", "Invalid");
    output.textContent = `This does not look like a valid proxy URL: ${proxyUrl}`;
    return;
  }

  persistSettings(urls, proxyUrl);
  setBusyState(true);
  setStatus("running", "Running");
  output.textContent = `Calling the native host through ${proxyUrl}...`;

  try {
    const response = await sendNativeMessage({
      action: "check_urls",
      urls,
      proxyUrl,
    });

    if (!response) {
      throw new Error("The native host did not return any data.");
    }

    if (response.ok) {
      setStatus("success", "Success");
    } else {
      setStatus("error", "Error");
    }

    output.textContent = formatResponse(response);
  } catch (error) {
    setStatus("error", "Error");
    output.textContent = [
      error.message,
      "",
      "If the native host is not installed yet:",
      "1. Load this folder as an unpacked extension.",
      "2. Copy the extension ID from chrome://extensions or edge://extensions.",
      "3. Run register-native-host.ps1 with that ID.",
    ].join("\n");
  } finally {
    setBusyState(false);
  }
});

function initializeForm() {
  const saved = loadSettings();
  url1Input.value = saved.urls[0];
  url2Input.value = saved.urls[1];
  proxyInput.value = saved.proxyUrl;
}

function loadSettings() {
  try {
    const raw = localStorage.getItem("savedSettings");
    if (!raw) {
      return {
        urls: DEFAULT_URLS,
        proxyUrl: DEFAULT_PROXY_URL,
      };
    }

    const parsed = JSON.parse(raw);
    if (
      parsed &&
      Array.isArray(parsed.urls) &&
      parsed.urls.length === 2 &&
      parsed.urls.every((value) => typeof value === "string") &&
      typeof parsed.proxyUrl === "string"
    ) {
      if (
        parsed.proxyUrl === "http://192.168.1.16:8080" ||
        parsed.proxyUrl === "http://192.168.1.6:8080"
      ) {
        parsed.proxyUrl = DEFAULT_PROXY_URL;
      }

      return parsed;
    }
  } catch (error) {
    console.warn("Unable to restore saved settings.", error);
  }

  return {
    urls: DEFAULT_URLS,
    proxyUrl: DEFAULT_PROXY_URL,
  };
}

function persistSettings(urls, proxyUrl) {
  localStorage.setItem(
    "savedSettings",
    JSON.stringify({
      urls,
      proxyUrl,
    })
  );
}

function isValidUrl(value) {
  try {
    const url = new URL(value);
    return url.protocol === "http:" || url.protocol === "https:";
  } catch {
    return false;
  }
}

function sendNativeMessage(message) {
  return new Promise((resolve, reject) => {
    chrome.runtime.sendNativeMessage(HOST_NAME, message, (response) => {
      if (chrome.runtime.lastError) {
        reject(new Error(chrome.runtime.lastError.message));
        return;
      }

      resolve(response);
    });
  });
}

function setBusyState(isBusy) {
  runButton.disabled = isBusy;
  runButton.textContent = isBusy ? "Running..." : "Run Python Script";
}

function setStatus(kind, label) {
  statusPill.className = `pill ${kind}`;
  statusPill.textContent = label;
}

function formatResponse(response) {
  const lines = [];

  if (response.error) {
    lines.push(`Error: ${response.error}`);
  }

  if (Array.isArray(response.results) && response.results.length > 0) {
    lines.push(...response.results);
  }

  if (typeof response.exitCode === "number") {
    lines.push(`Exit code: ${response.exitCode}`);
  }

  if (Array.isArray(response.results) && response.results.length === 0 && !response.error) {
    lines.push("The script ran but did not return any output.");
  }

  return lines.join("\n");
}
