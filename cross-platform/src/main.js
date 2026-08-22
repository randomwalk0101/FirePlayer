const { app, BrowserWindow, dialog, ipcMain, Menu } = require('electron');
const path = require('path');
const fs = require('fs');

const audioExtensions = new Set(['.mp3', '.m4a', '.wav', '.aac', '.flac', '.aiff', '.aif', '.caf', '.ogg', '.opus', '.webm']);

let mainWindow;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1240,
    height: 760,
    minWidth: 980,
    minHeight: 620,
    title: 'FirePlayer',
    backgroundColor: '#101010',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  mainWindow.loadFile(path.join(__dirname, 'index.html'));
}

function listAudioFiles(folderPath) {
  return fs.readdirSync(folderPath, { withFileTypes: true })
    .filter((entry) => entry.isFile() && audioExtensions.has(path.extname(entry.name).toLowerCase()))
    .map((entry) => path.join(folderPath, entry.name))
    .sort((a, b) => path.basename(a).localeCompare(path.basename(b), undefined, { numeric: true }));
}

async function openAudioFiles() {
  const result = await dialog.showOpenDialog(mainWindow, {
    title: '加入音频文件',
    properties: ['openFile', 'multiSelections'],
    filters: [{ name: 'Audio', extensions: Array.from(audioExtensions).map((ext) => ext.slice(1)) }]
  });
  if (result.canceled) return [];
  return result.filePaths;
}

async function openFolders() {
  const result = await dialog.showOpenDialog(mainWindow, {
    title: '加入文件夹',
    properties: ['openDirectory', 'multiSelections']
  });
  if (result.canceled) return [];
  return result.filePaths.flatMap(listAudioFiles);
}

async function openSubtitles() {
  const result = await dialog.showOpenDialog(mainWindow, {
    title: '加入 SRT 字幕',
    properties: ['openFile', 'multiSelections'],
    filters: [{ name: 'SRT Subtitles', extensions: ['srt'] }]
  });
  if (result.canceled) return [];
  return result.filePaths;
}

function buildMenu() {
  const template = [
    {
      label: '文件',
      submenu: [
        { label: '加入音频文件...', accelerator: 'CmdOrCtrl+O', click: async () => mainWindow.webContents.send('files:add-audio', await openAudioFiles()) },
        { label: '加入文件夹...', accelerator: 'CmdOrCtrl+Shift+F', click: async () => mainWindow.webContents.send('files:add-audio', await openFolders()) },
        { label: '加入 SRT 字幕...', accelerator: 'CmdOrCtrl+Shift+S', click: async () => mainWindow.webContents.send('files:add-subtitles', await openSubtitles()) },
        { type: 'separator' },
        { label: '清空清单', accelerator: 'CmdOrCtrl+Shift+K', click: () => mainWindow.webContents.send('playlist:clear') },
        { type: 'separator' },
        { role: 'quit', label: '退出 FirePlayer' }
      ]
    }
  ];
  Menu.setApplicationMenu(Menu.buildFromTemplate(template));
}

ipcMain.handle('dialog:open-audio', openAudioFiles);
ipcMain.handle('dialog:open-folders', openFolders);
ipcMain.handle('dialog:open-subtitles', openSubtitles);
ipcMain.handle('file:read-text', async (_event, filePath) => fs.readFileSync(filePath, 'utf8'));
ipcMain.handle('path:basename', async (_event, filePath) => path.basename(filePath));
ipcMain.handle('path:dirname', async (_event, filePath) => path.dirname(filePath));
ipcMain.handle('path:list-srt', async (_event, folderPath) => {
  return fs.readdirSync(folderPath, { withFileTypes: true })
    .filter((entry) => entry.isFile() && path.extname(entry.name).toLowerCase() === '.srt')
    .map((entry) => path.join(folderPath, entry.name));
});
ipcMain.handle('window:toggle-fullscreen', async () => {
  if (!mainWindow) return false;
  mainWindow.setFullScreen(!mainWindow.isFullScreen());
  return mainWindow.isFullScreen();
});

app.whenReady().then(() => {
  createWindow();
  buildMenu();
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
