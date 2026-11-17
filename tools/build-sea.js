// Compila DocxViewer como UN SOLO .exe (Node SEA + bundle de esbuild).
// Uso: node tools/build-sea.js
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const ROOT = path.resolve(__dirname, '..');
const BUILD = path.join(ROOT, 'build');
const OUT = path.join(BUILD, 'sea');
const EXE = path.join(OUT, 'DocxViewer.exe');

function log(msg) { console.log('  ' + msg); }

fs.mkdirSync(OUT, { recursive: true });

/* 1. bundle de app.js + word-extractor */
log('empaquetando app.js...');
require('esbuild').buildSync({
  entryPoints: [path.join(ROOT, 'app.js')],
  bundle: true,
  platform: 'node',
  format: 'cjs',
  target: 'node20',
  external: ['node:sea'],
  outfile: path.join(BUILD, 'sea-main.js'),
  logLevel: 'warning',
});

/* 2. configuracion SEA (con los archivos web dentro del exe) */
const config = {
  main: 'build/sea-main.js',
  output: 'build/sea-prep.blob',
  disableExperimentalSEAWarning: true,
  useSnapshot: false,
  useCodeCache: true,
  assets: {
    'index.html': 'public/index.html',
    'docx-preview.js': 'public/docx-preview.js',
    'jszip.min.js': 'public/jszip.min.js',
    'mammoth.browser.min.js': 'public/mammoth.browser.min.js',
    'favicon.ico': 'public/favicon.ico',
  },
};
fs.writeFileSync(path.join(BUILD, 'sea-config.json'), JSON.stringify(config, null, 2));

log('generando blob SEA...');
execFileSync(process.execPath, ['--experimental-sea-config', path.join(BUILD, 'sea-config.json')], {
  cwd: ROOT,
  stdio: 'inherit',
});

/* 3. copiar node.exe */
log('copiando node.exe...');
fs.copyFileSync(process.execPath, EXE);

/* 4. subsistema GUI (sin ventana de consola) */
log('ajustando subsistema a GUI...');
const fd = fs.openSync(EXE, 'r+');
const head = Buffer.alloc(0x200);
fs.readSync(fd, head, 0, head.length, 0);
const peOff = head.readUInt32LE(0x3c);
const subsystemOff = peOff + 0x5c;
const sub = Buffer.alloc(2);
fs.readSync(fd, sub, 0, 2, subsystemOff);
sub.writeUInt16LE(2, 0); // IMAGE_SUBSYSTEM_WINDOWS_GUI
fs.writeSync(fd, sub, 0, 2, subsystemOff);
fs.closeSync(fd);

/* 5. icono propio (se genera si no existe) */
const icoPath = path.join(ROOT, 'DocxViewer.ico');
const favPath = path.join(ROOT, 'public', 'favicon.ico');
if (!fs.existsSync(icoPath) || !fs.existsSync(favPath)) {
  log('generando iconos...');
  execFileSync('powershell', [
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', path.join(ROOT, 'tools', 'gen-icon.ps1'),
  ], { stdio: 'inherit' });
}

const csc = 'C:\\Windows\\Microsoft.NET\\Framework64\\v4.0.30319\\csc.exe';
const setIconExe = path.join(BUILD, 'SetIcon.exe');
if (fs.existsSync(csc)) {
  log('compilando SetIcon...');
  execFileSync(csc, ['/nologo', '/target:exe', '/out:' + setIconExe, path.join(ROOT, 'tools', 'SetIcon.cs')], {
    stdio: 'inherit',
  });
  log('aplicando icono...');
  execFileSync(setIconExe, [EXE, path.join(ROOT, 'DocxViewer.ico')], { stdio: 'inherit' });
} else {
  log('aviso: no se encontro csc.exe; el exe usara el icono de Node');
}

/* 6. inyectar el blob */
log('inyectando el blob (postject)...');
execFileSync(process.execPath, [
  path.join(ROOT, 'node_modules', 'postject', 'dist', 'cli.js'),
  EXE,
  'NODE_SEA_BLOB',
  path.join(BUILD, 'sea-prep.blob'),
  '--sentinel-fuse',
  'NODE_SEA_FUSE_fce680ab2cc467b6e072b8b5df1996b2',
], { stdio: 'inherit' });

const sizeMb = (fs.statSync(EXE).size / (1024 * 1024)).toFixed(1);
console.log('listo: ' + EXE + ' (' + sizeMb + ' MB)');
