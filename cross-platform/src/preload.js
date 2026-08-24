const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('fireplayer', {
  openAudio: () => ipcRenderer.invoke('dialog:open-audio'),
  openFolders: () => ipcRenderer.invoke('dialog:open-folders'),
  openSubtitles: () => ipcRenderer.invoke('dialog:open-subtitles'),
  readText: (filePath) => ipcRenderer.invoke('file:read-text', filePath),
  basename: (filePath) => ipcRenderer.invoke('path:basename', filePath),
  dirname: (filePath) => ipcRenderer.invoke('path:dirname', filePath),
  listSrt: (folderPath) => ipcRenderer.invoke('path:list-srt', folderPath),
  toggleFullscreen: () => ipcRenderer.invoke('window:toggle-fullscreen'),
  exitFullscreen: () => ipcRenderer.invoke('window:exit-fullscreen'),
  onFullscreenChanged: (callback) => ipcRenderer.on('window:fullscreen-changed', (_event, isFullscreen) => callback(isFullscreen)),
  onAddAudio: (callback) => ipcRenderer.on('files:add-audio', (_event, paths) => callback(paths)),
  onAddSubtitles: (callback) => ipcRenderer.on('files:add-subtitles', (_event, paths) => callback(paths)),
  onClearPlaylist: (callback) => ipcRenderer.on('playlist:clear', callback)
});
