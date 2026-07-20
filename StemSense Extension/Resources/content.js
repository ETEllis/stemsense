(() => {
  "use strict";

  if (globalThis.__stemSkipInstalled) return;
  globalThis.__stemSkipInstalled = true;

  const DEFAULT_INTERVAL = 10;
  let lastInstall = 0;

  function activeVideo() {
    const videos = Array.from(document.querySelectorAll("video"));
    return videos.find((video) => !video.paused && video.readyState >= 2)
      || videos.find((video) => video.readyState >= 1)
      || null;
  }

  function showFeedback(delta) {
    let toast = document.getElementById("stemsense-feedback");
    if (!toast) {
      toast = document.createElement("div");
      toast.id = "stemsense-feedback";
      toast.setAttribute("role", "status");
      document.documentElement.appendChild(toast);
    }
    toast.textContent = delta > 0 ? `+${delta}s` : `${delta}s`;
    toast.classList.remove("stemsense-show");
    void toast.offsetWidth;
    toast.classList.add("stemsense-show");
  }

  function seekBy(delta) {
    const video = activeVideo();
    if (!video || !Number.isFinite(video.duration)) return false;
    const destination = Math.max(0, Math.min(video.duration, video.currentTime + delta));
    if (typeof video.fastSeek === "function") {
      try {
        video.fastSeek(destination);
      } catch (_) {
        video.currentTime = destination;
      }
    } else {
      video.currentTime = destination;
    }
    showFeedback(delta);
    return true;
  }

  function installMediaHandlers() {
    if (!("mediaSession" in navigator)) return;
    lastInstall = Date.now();
    const handlers = {
      nexttrack: () => seekBy(DEFAULT_INTERVAL),
      previoustrack: () => seekBy(-DEFAULT_INTERVAL),
      seekforward: (details) => seekBy(details.seekOffset || DEFAULT_INTERVAL),
      seekbackward: (details) => seekBy(-(details.seekOffset || DEFAULT_INTERVAL))
    };
    for (const [action, handler] of Object.entries(handlers)) {
      try {
        navigator.mediaSession.setActionHandler(action, handler);
      } catch (_) {
        // Older Safari versions may expose Media Session without every action.
      }
    }
  }

  function refreshSoon() {
    window.setTimeout(installMediaHandlers, 50);
    window.setTimeout(installMediaHandlers, 500);
  }

  document.addEventListener("play", refreshSoon, true);
  document.addEventListener("loadedmetadata", refreshSoon, true);
  document.addEventListener("yt-navigate-finish", refreshSoon, true);
  document.addEventListener("visibilitychange", () => {
    if (!document.hidden) refreshSoon();
  });

  // YouTube is a single-page app and may re-register its own media actions.
  // Reassert only the four navigation actions; play/pause remains untouched.
  window.setInterval(() => {
    if (Date.now() - lastInstall >= 1500 && activeVideo()) installMediaHandlers();
  }, 1600);

  refreshSoon();
})();
