const { app, BrowserWindow, shell } = require('electron');
const path = require('path');
const http = require('http');

const SWARM_PORT = process.env.LUCILLE_PORT || 8403;
const SWARM_URL = `http://127.0.0.1:${SWARM_PORT}`;
const ICON_PATH = path.join(__dirname, 'icon.png');

let mainWindow = null;

function checkServerReady(cb) {
  const req = http.get(SWARM_URL, (res) => {
    cb(res.statusCode >= 200 && res.statusCode < 400);
  });
  req.on('error', () => cb(false));
  req.setTimeout(1000, () => {
    req.destroy();
    cb(false);
  });
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1280,
    height: 800,
    minWidth: 800,
    minHeight: 600,
    title: `SWARM OS v${app.getVersion()} — Lucille & Dr. Boltz`,
    backgroundColor: '#070908',
    icon: ICON_PATH,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      sandbox: true,
    },
    autoHideMenuBar: true,
  });

  // Open external links in default system browser
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    if (!url.startsWith(`http://127.0.0.1:${SWARM_PORT}`) && !url.startsWith('http://localhost:')) {
      shell.openExternal(url);
      return { action: 'deny' };
    }
    return { action: 'allow' };
  });

  function tryLoad() {
    checkServerReady((ready) => {
      if (ready) {
        mainWindow.loadURL(SWARM_URL);
      } else {
        mainWindow.loadURL(`data:text/html;charset=utf-8,${encodeURIComponent(`
          <!doctype html>
          <html>
          <head>
            <title>SWARM OS Connecting...</title>
            <style>
              body {
                background: #070908;
                color: #ff7a29;
                font-family: monospace;
                display: flex;
                flex-direction: column;
                align-items: center;
                justify-content: center;
                height: 100vh;
                margin: 0;
              }
              h1 { font-size: 1.8rem; margin-bottom: 0.5rem; }
              p { color: #9aa39c; }
              .spinner {
                width: 40px; height: 40px;
                border: 3px solid rgba(255,122,41,0.2);
                border-top: 3px solid #ff7a29;
                border-radius: 50%;
                animation: spin 1s linear infinite;
                margin-top: 1rem;
              }
              @keyframes spin { 100% { transform: rotate(360deg); } }
            </style>
          </head>
          <body>
            <h1>SWARM OS</h1>
            <p>Connecting to Lucille Assistant on port ${SWARM_PORT}...</p>
            <div class="spinner"></div>
            <script>
              setInterval(() => {
                fetch('${SWARM_URL}').then(r => {
                  if (r.ok) window.location.href = '${SWARM_URL}';
                }).catch(() => {});
              }, 1500);
            </script>
          </body>
          </html>
        `)}`);
      }
    });
  }

  tryLoad();

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

app.whenReady().then(() => {
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
