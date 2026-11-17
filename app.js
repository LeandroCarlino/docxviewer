'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const ROOT = __dirname;
const PUBLIC = path.join(ROOT, 'public');

// Cuando la app va empaquetada en un unico .exe (Node SEA), los archivos web
// viajan dentro del ejecutable y se leen con node:sea en vez del disco.
let seaApi = null;
try {
  seaApi = require('node:sea');
} catch (_) {
  seaApi = null;
}
const PACKAGED = !!(seaApi && seaApi.isSea());

const STATIC_FILES = {
  'index.html': 'text/html; charset=utf-8',
  'docx-preview.js': 'text/javascript; charset=utf-8',
  'jszip.min.js': 'text/javascript; charset=utf-8',
  'mammoth.browser.min.js': 'text/javascript; charset=utf-8',
  'favicon.ico': 'image/x-icon',
};

function readStatic(name) {
  if (PACKAGED) {
    try {
      return Buffer.from(seaApi.getAsset(name));
    } catch (_) {
      return null;
    }
  }
  try {
    return fs.readFileSync(path.join(PUBLIC, name));
  } catch (_) {
    return null;
  }
}

// Extractor de .doc antiguos (Word 97-2003). Si falta node_modules, la app
// sigue abriendo .docx y avisa solo al intentar leer un .doc.
let WordExtractor = null;
try {
  WordExtractor = require('word-extractor');
} catch (_) {
  WordExtractor = null;
}
const docExtractor = WordExtractor ? new WordExtractor() : null;
const MAX_DOC_BYTES = 80 * 1024 * 1024;

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.png': 'image/png',
};

// En un .exe empaquetado (SEA) el primer argumento util puede estar en argv[1]
// o en argv[2] segun la version de Node; se prueban ambos.
function firstFileArg() {
  const candidates = [];
  const arg1 = process.argv[1];
  if (arg1 && !/\.exe$/i.test(arg1)) candidates.push(arg1);
  candidates.push.apply(candidates, process.argv.slice(2));
  for (const c of candidates) {
    if (!c) continue;
    if (!/\.(docx?|docm)$/i.test(String(c).trim())) continue;
    const resolved = resolveDoc(c);
    if (resolved) return resolved;
  }
  return null;
}

function resolveDoc(arg) {
  if (!arg) return null;
  let p = String(arg).trim().replace(/^"|"$/g, '').trim();
  if (!p) return null;
  if (!path.isAbsolute(p)) p = path.resolve(process.cwd(), p);
  try {
    if (fs.statSync(p).isFile()) return p;
  } catch (_) {}
  return null;
}

const docPath = firstFileArg();

// .docx es un ZIP ("PK\x03\x04"); los .doc viejos son OLE2 (D0 CF 11 E0).
function detectKind(p) {
  if (!p) return null;
  try {
    const fd = fs.openSync(p, 'r');
    const buf = Buffer.alloc(8);
    fs.readSync(fd, buf, 0, 8, 0);
    fs.closeSync(fd);
    if (buf[0] === 0x50 && buf[1] === 0x4b && buf[2] === 0x03 && buf[3] === 0x04) return 'docx';
    if (buf[0] === 0xd0 && buf[1] === 0xcf && buf[2] === 0x11 && buf[3] === 0xe0) return 'legacy-doc';
    return 'unknown';
  } catch (_) {
    return 'unknown';
  }
}

const started = Date.now();
let lastPing = 0;
let seenPing = false;
let shuttingDown = false;

function send(res, code, body, headers) {
  res.writeHead(code, Object.assign({ 'Cache-Control': 'no-store' }, headers));
  res.end(body);
}

function sendJson(res, code, obj) {
  send(res, code, JSON.stringify(obj), { 'Content-Type': 'application/json; charset=utf-8' });
}

const server = http.createServer((req, res) => {
  let url;
  try {
    url = new URL(req.url, 'http://127.0.0.1');
  } catch (_) {
    return send(res, 400, 'Bad request');
  }
  const pathname = decodeURIComponent(url.pathname);

  if (pathname === '/ping') {
    lastPing = Date.now();
    seenPing = true;
    return send(res, 200, 'ok', { 'Content-Type': 'text/plain' });
  }

  if (pathname === '/api/extract' && req.method === 'POST') {
    if (!docExtractor) {
      return sendJson(res, 500, {
        error: 'Falta el modulo word-extractor. Ejecuta "npm install" en la carpeta de DocxViewer.',
      });
    }

    const chunks = [];
    let size = 0;
    let tooBig = false;

    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > MAX_DOC_BYTES) {
        tooBig = true;
        return;
      }
      chunks.push(chunk);
    });

    req.on('end', () => {
      if (tooBig) return sendJson(res, 413, { error: 'El archivo es demasiado grande.' });
      const buf = Buffer.concat(chunks);
      docExtractor
        .extract(buf)
        .then((doc) => sendJson(res, 200, { text: doc.getBody() }))
        .catch((err) => {
          console.error('extract:', err && err.message ? err.message : err);
          sendJson(res, 200, { error: 'No se pudo leer el contenido del documento.' });
        });
    });

    req.on('error', () => sendJson(res, 400, { error: 'Error al recibir el archivo.' }));
    return;
  }

  if (pathname === '/api/info') {
    let name = null;
    let size = 0;
    let kind = null;
    let ext = null;
    if (docPath) {
      name = path.basename(docPath);
      ext = path.extname(docPath).toLowerCase();
      kind = detectKind(docPath);
      try { size = fs.statSync(docPath).size; } catch (_) {}
    }
    return send(res, 200, JSON.stringify({ name, size, kind, ext }), {
      'Content-Type': 'application/json; charset=utf-8',
    });
  }

  if (pathname === '/document.docx') {
    if (!docPath) return send(res, 404, 'Sin documento');
    res.writeHead(200, {
      'Content-Type': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'Content-Length': fs.statSync(docPath).size,
      'Cache-Control': 'no-store',
    });
    return fs.createReadStream(docPath).pipe(res);
  }

  const rel = pathname === '/' ? 'index.html' : pathname.replace(/^\/+/, '');
  if (!Object.prototype.hasOwnProperty.call(STATIC_FILES, rel)) {
    return send(res, 404, 'No encontrado');
  }
  const data = readStatic(rel);
  if (!data) return send(res, 404, 'No encontrado');
  send(res, 200, data, { 'Content-Type': STATIC_FILES[rel] });
});

function findBrowser() {
  const candidates = [
    path.join(process.env['ProgramFiles(x86)'] || 'C:\\Program Files (x86)', 'Microsoft\\Edge\\Application\\msedge.exe'),
    path.join(process.env.ProgramFiles || 'C:\\Program Files', 'Microsoft\\Edge\\Application\\msedge.exe'),
    path.join(process.env.LOCALAPPDATA || '', 'Microsoft\\Edge\\Application\\msedge.exe'),
    path.join(process.env.ProgramFiles || 'C:\\Program Files', 'Google\\Chrome\\Application\\chrome.exe'),
    path.join(process.env['ProgramFiles(x86)'] || 'C:\\Program Files (x86)', 'Google\\Chrome\\Application\\chrome.exe'),
  ];
  for (const p of candidates) {
    try {
      if (p && fs.statSync(p).isFile()) return p;
    } catch (_) {}
  }
  return null;
}

function shutdown() {
  if (shuttingDown) return;
  shuttingDown = true;
  try { server.close(); } catch (_) {}
  setTimeout(() => process.exit(0), 100);
}

server.listen(0, '127.0.0.1', () => {
  const port = server.address().port;
  const target = `http://127.0.0.1:${port}/`;

  // modo de prueba: no abrir ventana, solo dejar la URL en un archivo
  if (process.env.DOCXVIEWER_NO_OPEN) {
    try {
      fs.writeFileSync(path.join(ROOT, 'build', 'last-url.txt'), target);
    } catch (_) {}
    return;
  }

  const browser = findBrowser();
  if (browser) {
    const child = spawn(browser, [`--app=${target}`, '--window-size=1100,860'], {
      detached: true,
      stdio: 'ignore',
    });
    child.unref();
  } else {
    spawn('cmd', ['/c', 'start', '""', target], { detached: true, stdio: 'ignore' }).unref();
  }
});

// Cierra el servidor cuando la ventana del documento se cierra.
// Margen amplio porque Chromium frena los temporizadores en ventanas ocultas.
setInterval(() => {
  const now = Date.now();
  if (seenPing) {
    if (now - lastPing > 150000) shutdown();
  } else if (now - started > 180000) {
    shutdown();
  }
}, 5000);

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
