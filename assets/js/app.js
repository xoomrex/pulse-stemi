// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/stemi"
import topbar from "../vendor/topbar"

// ============================================
// Pulse Alert Sound System
// Uses Web Audio API — no external MP3 needed
// ============================================
let audioCtx = null;

function getAudioContext() {
  if (!audioCtx) {
    audioCtx = new (window.AudioContext || window.webkitAudioContext)();
  }
  return audioCtx;
}

// Play a medical-style beep alert (two-tone)
function playAlertSound() {
  try {
    const ctx = getAudioContext();
    if (ctx.state === 'suspended') {
      ctx.resume();
    }

    const now = ctx.currentTime;

    // First beep (higher)
    const osc1 = ctx.createOscillator();
    const gain1 = ctx.createGain();
    osc1.type = 'sine';
    osc1.frequency.value = 880;
    gain1.gain.setValueAtTime(0, now);
    gain1.gain.linearRampToValueAtTime(0.3, now + 0.02);
    gain1.gain.linearRampToValueAtTime(0, now + 0.15);
    osc1.connect(gain1);
    gain1.connect(ctx.destination);
    osc1.start(now);
    osc1.stop(now + 0.15);

    // Second beep (slightly lower, delayed)
    const osc2 = ctx.createOscillator();
    const gain2 = ctx.createGain();
    osc2.type = 'sine';
    osc2.frequency.value = 660;
    gain2.gain.setValueAtTime(0, now + 0.2);
    gain2.gain.linearRampToValueAtTime(0.25, now + 0.22);
    gain2.gain.linearRampToValueAtTime(0, now + 0.4);
    osc2.connect(gain2);
    gain2.connect(ctx.destination);
    osc2.start(now + 0.2);
    osc2.stop(now + 0.4);

    // Third beep (confirmation tone)
    const osc3 = ctx.createOscillator();
    const gain3 = ctx.createGain();
    osc3.type = 'sine';
    osc3.frequency.value = 1046;
    gain3.gain.setValueAtTime(0, now + 0.45);
    gain3.gain.linearRampToValueAtTime(0.2, now + 0.47);
    gain3.gain.linearRampToValueAtTime(0, now + 0.65);
    osc3.connect(gain3);
    gain3.connect(ctx.destination);
    osc3.start(now + 0.45);
    osc3.stop(now + 0.65);

  } catch (e) {
    console.log('Audio not available:', e);
  }
}

// Enable audio context on first user interaction (required by browsers)
let audioEnabled = false;
function enableAudio() {
  if (!audioEnabled) {
    audioEnabled = true;
    try {
      const ctx = getAudioContext();
      if (ctx.state === 'suspended') {
        ctx.resume();
      }
    } catch (e) {}
  }
}

document.addEventListener('click', enableAudio, { once: true });
document.addEventListener('touchstart', enableAudio, { once: true });

// Expose globally for LiveView hooks
window.playAlertSound = playAlertSound;

// ============================================
// Custom LiveView Hooks
// ============================================

// Compress an image file using Canvas API
// Returns a Promise that resolves to a compressed File
function compressImage(file, maxDim = 1280, quality = 0.70) {
  return new Promise((resolve) => {
    // If not an image, return as-is
    if (!file.type.startsWith('image/')) {
      resolve(file);
      return;
    }

    const reader = new FileReader();
    reader.onload = (e) => {
      const img = new Image();
      img.onload = () => {
        // Calculate new dimensions
        let w = img.width;
        let h = img.height;
        if (w > maxDim || h > maxDim) {
          if (w > h) {
            h = Math.round(h * maxDim / w);
            w = maxDim;
          } else {
            w = Math.round(w * maxDim / h);
            h = maxDim;
          }
        }

        // Draw to canvas
        const canvas = document.createElement('canvas');
        canvas.width = w;
        canvas.height = h;
        const ctx = canvas.getContext('2d');
        ctx.drawImage(img, 0, 0, w, h);

        // Export as JPEG blob
        canvas.toBlob((blob) => {
          if (blob) {
            // Create a new File with the same name but .jpg extension
            const name = file.name.replace(/\.[^.]+$/, '.jpg');
            const compressed = new File([blob], name, { type: 'image/jpeg', lastModified: Date.now() });
            console.log(`Image compressed: ${(file.size/1024).toFixed(0)}KB → ${(compressed.size/1024).toFixed(0)}KB`);
            resolve(compressed);
          } else {
            resolve(file);
          }
        }, 'image/jpeg', quality);
      };
      img.onerror = () => resolve(file);
      img.src = e.target.result;
    };
    reader.onerror = () => resolve(file);
    reader.readAsDataURL(file);
  });
}

const Hooks = {
  ...colocatedHooks,

  // Flash alert hook — plays sound when flash appears
  FlashAlert: {
    mounted() {
      playAlertSound();
    }
  },

  // Image upload hook — compresses images before upload using Canvas API
  ImageCompress: {
    mounted() {
      this.setupInput();
    },
    updated() {
      this.setupInput();
    },
    setupInput() {
      const input = this.el.querySelector('input[type="file"]');
      if (!input || input._compressAttached) return;
      input._compressAttached = true;

      // Set accept to image/* so mobile shows camera + gallery options
      input.setAttribute('accept', 'image/*');
      input.setAttribute('capture', 'environment');

      // Intercept file selection and compress before LiveView upload
      input.addEventListener('change', (e) => {
        const file = e.target.files[0];
        if (!file || !file.type.startsWith('image/')) return;

        // Compress the image
        this.compressImage(file, (compressedFile) => {
          // Create a new FileList with the compressed file
          const dt = new DataTransfer();
          dt.items.add(compressedFile);
          input.files = dt.files;

          // Dispatch input event so LiveView picks up the new file
          input.dispatchEvent(new Event('input', { bubbles: true }));
        });

        // Prevent the original event from propagating
        e.stopImmediatePropagation();
      }, { capture: true });
    },

    compressImage(file, callback) {
      const maxWidth = 1200;
      const maxHeight = 1200;
      const quality = 0.6; // 60% JPEG quality

      const reader = new FileReader();
      reader.onload = (e) => {
        const img = new Image();
        img.onload = () => {
          // Calculate new dimensions
          let width = img.width;
          let height = img.height;

          if (width > maxWidth || height > maxHeight) {
            const ratio = Math.min(maxWidth / width, maxHeight / height);
            width = Math.round(width * ratio);
            height = Math.round(height * ratio);
          }

          // Draw on canvas
          const canvas = document.createElement('canvas');
          canvas.width = width;
          canvas.height = height;
          const ctx = canvas.getContext('2d');
          ctx.drawImage(img, 0, 0, width, height);

          // Convert to compressed JPEG blob
          canvas.toBlob((blob) => {
            const compressedFile = new File([blob], file.name.replace(/\.\w+$/, '.jpg'), {
              type: 'image/jpeg',
              lastModified: Date.now()
            });
            console.log(`Image compressed: ${(file.size/1024).toFixed(0)}KB → ${(compressedFile.size/1024).toFixed(0)}KB`);
            callback(compressedFile);
          }, 'image/jpeg', quality);
        };
        img.src = e.target.result;
      };
      reader.readAsDataURL(file);
    }
  }
};
// Install screen — report the current URL to the LiveView so it can show it for the phone visit.
Hooks.ReportUrl = {
  mounted() {
    this.pushEvent("set_url", { url: window.location.origin + "/" });
  }
};

// ============================================
// EMS Live Location Tracker Hook
// Shares GPS position from EMS user's phone
// ============================================
Hooks.EmsTracker = {
  mounted() {
    this.watchId = null;
    this.handleEvent("start_tracking", ({case_id}) => {
      if (!navigator.geolocation) {
        console.warn("Geolocation not supported");
        return;
      }
      // Ask for permission and start watching
      this.watchId = navigator.geolocation.watchPosition(
        (pos) => {
          this.pushEvent("ems_location_update", {
            case_id: case_id,
            lat: pos.coords.latitude,
            lng: pos.coords.longitude
          });
        },
        (err) => console.warn("GPS error:", err.message),
        { enableHighAccuracy: true, maximumAge: 5000, timeout: 10000 }
      );
      console.log("📍 EMS tracking started for case:", case_id);
    });

    this.handleEvent("stop_tracking", () => {
      if (this.watchId !== null) {
        navigator.geolocation.clearWatch(this.watchId);
        this.watchId = null;
        console.log("📍 EMS tracking stopped");
      }
    });
  },
  destroyed() {
    if (this.watchId !== null) {
      navigator.geolocation.clearWatch(this.watchId);
    }
  }
};

// ============================================
// EMS Map Viewer Hook (Leaflet.js)
// Shows ambulance position on a map
// ============================================
Hooks.EmsMap = {
  mounted() {
    this.map = null;
    this.marker = null;
    this.loaded = false;

    this.handleEvent("show_ems_map", ({lat, lng, label}) => {
      // Dynamically load Leaflet CSS + JS if not loaded
      if (!this.loaded) {
        const link = document.createElement('link');
        link.rel = 'stylesheet';
        link.href = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css';
        document.head.appendChild(link);

        const script = document.createElement('script');
        script.src = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js';
        script.onload = () => {
          this.loaded = true;
          this._initMap(lat, lng, label);
        };
        document.head.appendChild(script);
      } else {
        this._initMap(lat, lng, label);
      }
    });

    this.handleEvent("update_ems_position", ({lat, lng}) => {
      if (this.marker && this.map) {
        this.marker.setLatLng([lat, lng]);
        this.map.panTo([lat, lng]);
      }
    });

    this.handleEvent("hide_ems_map", () => {
      if (this.map) {
        this.map.remove();
        this.map = null;
        this.marker = null;
      }
    });
  },
  _initMap(lat, lng, label) {
    const container = document.getElementById('ems-map-container');
    if (!container) return;
    container.style.height = '300px';
    container.innerHTML = '';

    this.map = L.map(container).setView([lat, lng], 14);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© OpenStreetMap'
    }).addTo(this.map);

    // Ambulance icon
    const ambulanceIcon = L.divIcon({
      html: '<div style="font-size:28px;text-align:center;">🚑</div>',
      iconSize: [36, 36],
      iconAnchor: [18, 18],
      className: ''
    });

    this.marker = L.marker([lat, lng], {icon: ambulanceIcon}).addTo(this.map);
    this.marker.bindPopup(label || 'EMS Ambulance').openPopup();

    // Fix map rendering
    setTimeout(() => this.map.invalidateSize(), 200);
  },
  destroyed() {
    if (this.map) {
      this.map.remove();
      this.map = null;
    }
  }
};

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks,
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#ef4444"}, shadowColor: "rgba(239, 68, 68, 0.2)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// Listen for custom alert events from server
window.addEventListener("phx:play-alert", () => {
  playAlertSound();
});

// ============================================
// PWA — Service worker + install prompt
// ============================================
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/sw.js", { scope: "/" }).catch((err) => {
      console.log("SW registration failed:", err);
    });
  });
}

// Live elapsed-time ticker — finds `.case-elapsed[data-elapsed-since]` and updates it every 30s.
function formatElapsed(iso) {
  const then = new Date(iso).getTime();
  if (!then) return "";
  const mins = Math.floor((Date.now() - then) / 60000);
  if (mins < 1) return "Just now";
  if (mins < 60) return `${mins}m ago`;
  if (mins < 1440) return `${Math.floor(mins / 60)}h ago`;
  return `${Math.floor(mins / 1440)}d ago`;
}
function tickElapsed() {
  document.querySelectorAll(".case-elapsed[data-elapsed-since]").forEach((el) => {
    el.textContent = formatElapsed(el.dataset.elapsedSince);
  });
}
setInterval(tickElapsed, 30000);
window.addEventListener("phx:page-loading-stop", () => setTimeout(tickElapsed, 50));

// Install prompt — Android/Chrome fires `beforeinstallprompt`; iOS needs custom instructions.
let deferredInstallPrompt = null;
const INSTALL_DISMISSED_KEY = "pulse-install-dismissed";

function isiOS() {
  return /iphone|ipad|ipod/i.test(navigator.userAgent) && !window.MSStream;
}
function isStandalone() {
  return window.matchMedia("(display-mode: standalone)").matches || window.navigator.standalone === true;
}

function showInstallBanner(mode) {
  if (isStandalone()) return;
  if (localStorage.getItem(INSTALL_DISMISSED_KEY)) return;
  if (document.getElementById("pulse-install-banner")) return;

  const banner = document.createElement("div");
  banner.id = "pulse-install-banner";
  banner.className = "pulse-install-banner";
  banner.innerHTML = mode === "ios"
    ? `<div class="pulse-install-banner__icon">📱</div>
       <div class="pulse-install-banner__body">
         <div class="pulse-install-banner__title">Install Pulse on your phone</div>
         <div class="pulse-install-banner__hint">Tap <strong>Share</strong> → <strong>Add to Home Screen</strong></div>
       </div>
       <button class="pulse-install-banner__close" aria-label="Dismiss">✕</button>`
    : `<div class="pulse-install-banner__icon">📱</div>
       <div class="pulse-install-banner__body">
         <div class="pulse-install-banner__title">Install Pulse on your phone</div>
         <div class="pulse-install-banner__hint">Get instant alerts without opening the browser.</div>
       </div>
       <button class="pulse-install-banner__action">Install</button>
       <button class="pulse-install-banner__close" aria-label="Dismiss">✕</button>`;

  document.body.appendChild(banner);
  requestAnimationFrame(() => banner.classList.add("is-visible"));

  banner.querySelector(".pulse-install-banner__close")?.addEventListener("click", () => {
    localStorage.setItem(INSTALL_DISMISSED_KEY, "1");
    banner.classList.remove("is-visible");
    setTimeout(() => banner.remove(), 400);
  });

  banner.querySelector(".pulse-install-banner__action")?.addEventListener("click", async () => {
    if (!deferredInstallPrompt) return;
    deferredInstallPrompt.prompt();
    const choice = await deferredInstallPrompt.userChoice;
    deferredInstallPrompt = null;
    if (choice.outcome === "accepted" || choice.outcome === "dismissed") {
      banner.classList.remove("is-visible");
      setTimeout(() => banner.remove(), 400);
    }
  });
}

window.addEventListener("beforeinstallprompt", (e) => {
  e.preventDefault();
  deferredInstallPrompt = e;
  showInstallBanner("android");
});

window.addEventListener("appinstalled", () => {
  deferredInstallPrompt = null;
  document.getElementById("pulse-install-banner")?.remove();
});

// On iOS we never get `beforeinstallprompt`, so show the manual instructions
// the first time the user opens the site outside of standalone mode.
window.addEventListener("load", () => {
  if (isiOS() && !isStandalone()) {
    // Slight delay so it doesn't fight with the login screen on first paint.
    setTimeout(() => showInstallBanner("ios"), 2500);
  }
});

// Also play sound on any flash message (case updates trigger flashes)
window.addEventListener("phx:page-loading-stop", () => {
  // Small delay to let DOM update
  setTimeout(() => {
    const flash = document.querySelector('[id="flash-group"] > div:not([hidden])');
    if (flash && flash.textContent.trim().length > 0) {
      playAlertSound();
    }
  }, 100);
});

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}
