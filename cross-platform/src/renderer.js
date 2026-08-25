const api = window.fireplayer;
const audio = document.getElementById('audio');
const appShell = document.querySelector('.app');
const playlistEl = document.getElementById('playlist');
const playlistResizer = document.getElementById('playlistResizer');
const emptyPlaylist = document.getElementById('emptyPlaylist');
const subtitleStage = document.getElementById('subtitleStage');
const englishText = document.getElementById('englishText');
const translationText = document.getElementById('translationText');
const seek = document.getElementById('seek');
const time = document.getElementById('time');
const playPause = document.getElementById('playPause');
const previousTrack = document.getElementById('previousTrack');
const nextTrack = document.getElementById('nextTrack');
const previousSentence = document.getElementById('previousSentence');
const nextSentence = document.getElementById('nextSentence');
const subtitleTrack = document.getElementById('subtitleTrack');
const subtitleMode = document.getElementById('subtitleMode');
const playbackMode = document.getElementById('playbackMode');
const speed = document.getElementById('speed');
const smallerFont = document.getElementById('smallerFont');
const largerFont = document.getElementById('largerFont');
const fontSizeLabel = document.getElementById('fontSize');
const subtitleColor = document.getElementById('subtitleColor');
const volume = document.getElementById('volume');
const clearPlaylist = document.getElementById('clearPlaylist');
const togglePlaylist = document.getElementById('togglePlaylist');
const playlistMenu = document.getElementById('playlistMenu');
const deleteSelected = document.getElementById('deleteSelected');

const modes = ['英文', '双语', '重音骨架', '语流标注', '发音提示'];
const playbackModes = ['顺序播放', '单曲循环', '列表循环'];
const audioExtensions = new Set(['mp3', 'm4a', 'wav', 'aac', 'flac', 'aiff', 'aif', 'caf', 'ogg', 'opus', 'webm']);

let playlist = [];
let selected = new Set();
let currentTrackIndex = -1;
let subtitles = [];
let currentSubtitleIndex = -1;
let subtitleFiles = [];
let registeredSubtitles = [];
let subtitleDisplayMode = localStorage.getItem('FirePlayer.subtitleDisplayMode') || '英文';
let playbackModeValue = localStorage.getItem('FirePlayer.playbackMode') || '顺序播放';
let fontSize = Number(localStorage.getItem('FirePlayer.fontSize') || 54);
let playlistVisible = true;
let subtitleClickTimer = 0;
let isFullscreen = false;
let playlistWidth = Number(localStorage.getItem('FirePlayer.playlistWidth') || 285);
let isResizingPlaylist = false;

function applyPlaylistWidth(width) {
  playlistWidth = Math.min(520, Math.max(190, Math.round(width)));
  document.documentElement.style.setProperty('--playlist-width', `${playlistWidth}px`);
  localStorage.setItem('FirePlayer.playlistWidth', String(playlistWidth));
}

function fileUrl(filePath) {
  const normalized = filePath.replace(/\\/g, '/');
  if (/^[A-Za-z]:\//.test(normalized)) {
    return `file:///${normalized.split('/').map(encodeURIComponent).join('/')}`;
  }
  return `file://${normalized.split('/').map(encodeURIComponent).join('/')}`;
}

function ext(filePath) {
  const name = filePath.split(/[\\/]/).pop() || '';
  const index = name.lastIndexOf('.');
  return index >= 0 ? name.slice(index + 1).toLowerCase() : '';
}

function stem(filePath) {
  const name = filePath.split(/[\\/]/).pop() || filePath;
  const index = name.lastIndexOf('.');
  return index >= 0 ? name.slice(0, index) : name;
}

function normalizedStem(value) {
  return value.normalize('NFC').toLowerCase().replace(/[ _.-]/g, '');
}

function formatTime(value) {
  if (!Number.isFinite(value) || value < 0) return '00:00';
  const total = Math.floor(value);
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  return h > 0
    ? `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`
    : `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

function parseSrt(content) {
  return content.replace(/\r\n?/g, '\n').split(/\n\s*\n/g).flatMap((block, fallbackIndex) => {
    const lines = block.split('\n').map((line) => line.trim()).filter(Boolean);
    if (lines.length < 2) return [];
    let cursor = /^\d+$/.test(lines[0]) ? 1 : 0;
    const parts = (lines[cursor] || '').split('-->');
    if (parts.length !== 2) return [];
    const start = parseSrtTime(parts[0]);
    const end = parseSrtTime(parts[1]);
    cursor += 1;
    const text = lines.slice(cursor).join('\n').replace(/<[^>]+>/g, '').trim();
    if (!Number.isFinite(start) || !Number.isFinite(end) || !text) return [];
    return [{ index: Number(lines[0]) || fallbackIndex + 1, start, end, text }];
  }).sort((a, b) => a.start - b.start);
}

function parseSrtTime(raw) {
  const match = raw.trim().replace(',', '.').match(/^(\d+):(\d+):(\d+(?:\.\d+)?)/);
  if (!match) return NaN;
  return Number(match[1]) * 3600 + Number(match[2]) * 60 + Number(match[3]);
}

function containsCjk(text) {
  return /[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\u3040-\u30ff\uac00-\ud7af]/u.test(text);
}

function splitBilingual(text) {
  const lines = text.replace(/\\N/g, '\n').split(/\n/g).map((line) => line.trim()).filter(Boolean);
  const english = [];
  const translated = [];
  for (const line of lines) {
    if (containsCjk(line)) translated.push(line);
    else english.push(line);
  }
  if (!english.length) return { english: lines.join('\n'), translation: '' };
  return { english: english.join('\n'), translation: translated.join('\n') };
}

function subtitleKind(filePath) {
  const name = stem(filePath).toLowerCase();
  if (name.includes('.phonetic.en') || name.includes('+phonetic') || name.includes('发音提示') || name.includes('学习型发音')) return '学习型发音';
  if (name.includes('.stress.en') || name.includes('+stress') || name.includes('重音骨架')) return '重音骨架';
  if (name.includes('.flow.en') || name.includes('+flow') || name.includes('语流标注')) return '语流标注';
  if (name.includes('.bi') || name.includes('+bi') || name.includes('bilingual') || name.includes('双语') || name.includes('中英')) return '中英双语';
  if (name.includes('.zh') || name.includes('+zh') || name.includes('zh-cn') || name.includes('简体') || name.includes('中文')) return '简体中文';
  if (name.includes('.en') || name.includes('+en') || name.includes('english') || name.includes('英文')) return '英文';
  return '默认字幕';
}

function subtitleSortKey(filePath, audioPath) {
  const subtitleStem = stem(filePath);
  const audioStem = stem(audioPath);
  if (subtitleStem.localeCompare(audioStem, undefined, { sensitivity: 'accent' }) === 0) return `0${subtitleStem}`;
  const order = { '英文': 1, '中英双语': 2, '重音骨架': 3, '语流标注': 4, '学习型发音': 5, '简体中文': 6 };
  return `${order[subtitleKind(filePath)] || 9}${subtitleStem}`;
}

async function basename(filePath) {
  return api.basename(filePath);
}

async function addAudio(paths) {
  const audioPaths = paths.filter((item) => audioExtensions.has(ext(item)));
  for (const item of audioPaths) {
    if (!playlist.includes(item)) playlist.push(item);
  }
  if (currentTrackIndex === -1 && playlist.length) await loadTrack(0, false);
  renderPlaylist();
}

async function addSubtitles(paths) {
  for (const item of paths.filter((entry) => ext(entry) === 'srt')) {
    if (!registeredSubtitles.includes(item)) registeredSubtitles.push(item);
  }
  if (currentTrackIndex >= 0) await loadSubtitlesFor(playlist[currentTrackIndex]);
}

async function discoverSubtitleVariants(audioPath) {
  const folder = await api.dirname(audioPath);
  const nearby = await api.listSrt(folder).catch(() => []);
  const pool = [...registeredSubtitles, ...nearby].filter((item, index, arr) => arr.indexOf(item) === index);
  const audioStem = stem(audioPath);
  const normalizedAudio = normalizedStem(audioStem);
  return pool.filter((item) => {
    const subtitleStem = stem(item);
    const normalizedSubtitle = normalizedStem(subtitleStem);
    if (normalizedSubtitle === normalizedAudio) return true;
    if (!normalizedSubtitle.startsWith(normalizedAudio)) return false;
    const suffix = subtitleStem.toLowerCase().slice(audioStem.length);
    return !suffix || /^[.+_\-（(]/.test(suffix);
  }).sort((a, b) => subtitleSortKey(a, audioPath).localeCompare(subtitleSortKey(b, audioPath)));
}

function preferredSubtitle(files, audioPath) {
  const audioStem = stem(audioPath).toLowerCase();
  const exact = files.find((item) => stem(item).toLowerCase() === audioStem);
  if (exact) return exact;
  const preferredKind = { '双语': '中英双语', '重音骨架': '重音骨架', '语流标注': '语流标注', '发音提示': '学习型发音' }[subtitleDisplayMode];
  if (preferredKind) {
    const match = files.find((item) => subtitleKind(item) === preferredKind);
    if (match) return match;
  }
  return files.find((item) => subtitleKind(item) === '英文') || files[0];
}

async function loadSubtitlesFor(audioPath) {
  subtitleFiles = await discoverSubtitleVariants(audioPath);
  subtitleTrack.innerHTML = '';
  if (!subtitleFiles.length) {
    subtitleTrack.disabled = true;
    subtitleTrack.append(new Option('字幕版本：无', ''));
    subtitles = [];
    currentSubtitleIndex = -1;
    setSubtitleDisplay('没有找到匹配字幕\n\n支持：文件名.srt、文件名.en.srt、文件名.bi.srt、文件名.zh.srt 等');
    return;
  }
  subtitleTrack.disabled = false;
  for (const file of subtitleFiles) {
    subtitleTrack.append(new Option(`${subtitleKind(file)} · ${await basename(file)}`, file));
  }
  await loadSubtitleFile(preferredSubtitle(subtitleFiles, audioPath));
}

async function loadSubtitleFile(filePath) {
  if (!filePath) return;
  subtitleTrack.value = filePath;
  const content = await api.readText(filePath);
  subtitles = parseSrt(content);
  currentSubtitleIndex = -1;
  updateSubtitle(true);
}

async function loadTrack(index, autoplay) {
  if (index < 0 || index >= playlist.length) return;
  currentTrackIndex = index;
  selected = new Set([index]);
  audio.src = fileUrl(playlist[index]);
  await loadSubtitlesFor(playlist[index]);
  renderPlaylist();
  if (autoplay) await audio.play();
  updateButtons();
}

function renderPlaylist() {
  playlistEl.innerHTML = '';
  emptyPlaylist.classList.toggle('hidden', playlist.length > 0);
  playlist.forEach((filePath, index) => {
    const row = document.createElement('div');
    row.className = 'track';
    row.dataset.index = String(index);
    if (selected.has(index)) row.classList.add('selected');
    if (index === currentTrackIndex) row.classList.add('playing');
    row.textContent = `♫  ${filePath.split(/[\\/]/).pop()}`;
    row.title = filePath;
    row.addEventListener('click', (event) => selectPlaylistRow(event, index));
    row.addEventListener('dblclick', async (event) => {
      event.preventDefault();
      event.stopPropagation();
      await loadTrack(index, true);
    });
    playlistEl.append(row);
  });
}

function updateButtons() {
  playPause.textContent = audio.paused ? '▶ 播放' : 'Ⅱ 暂停';
  subtitleMode.textContent = `字幕：${subtitleDisplayMode}`;
  playbackMode.textContent = playbackModeValue;
  fontSizeLabel.textContent = `字号 ${fontSize}`;
  document.documentElement.style.setProperty('--subtitle-size', `${fontSize}px`);
  document.documentElement.style.setProperty('--translation-size', `${Math.max(18, Math.round(fontSize * 0.58))}px`);
  englishText.style.fontSize = `${fontSize}px`;
  translationText.style.fontSize = `${Math.max(18, Math.round(fontSize * 0.58))}px`;
  document.documentElement.style.setProperty('--accent', subtitleColor.value);
}

function setSubtitleDisplay(text) {
  const parts = splitBilingual(text);
  englishText.textContent = parts.english;
  translationText.textContent = subtitleDisplayMode === '双语' ? parts.translation : '';
  if (subtitleDisplayMode === '重音骨架') translationText.textContent = '重音骨架模式：跨平台版先显示原句，完整标注可继续增强';
  if (subtitleDisplayMode === '语流标注') translationText.textContent = '语流标注模式：跨平台版先显示原句，完整标注可继续增强';
  if (subtitleDisplayMode === '发音提示') translationText.textContent = '发音提示模式：跨平台版先显示原句，完整标注可继续增强';
}

function updateSubtitle(force = false) {
  if (!subtitles.length) return;
  const t = audio.currentTime || 0;
  let found = subtitles.findLastIndex((item) => item.start <= t && t <= item.end);
  if (found < 0) found = subtitles.findLastIndex((item) => item.start <= t);
  if (found < 0) found = 0;
  if (!force && found === currentSubtitleIndex) return;
  currentSubtitleIndex = found;
  setSubtitleDisplay(subtitles[found].text);
}

function deleteSelectedTracks() {
  const rows = [...selected].filter((row) => row >= 0 && row < playlist.length).sort((a, b) => b - a);
  if (!rows.length) return;
  const deletingCurrent = selected.has(currentTrackIndex);
  const wasPlaying = !audio.paused;
  const firstRemoved = Math.min(...rows);
  const removedBeforeCurrent = rows.filter((row) => row < currentTrackIndex).length;
  for (const row of rows) playlist.splice(row, 1);
  selected.clear();
  if (!playlist.length) {
    currentTrackIndex = -1;
    audio.removeAttribute('src');
    subtitles = [];
    subtitleFiles = [];
    setSubtitleDisplay('打开音频后，将在这里显示当前字幕');
  } else if (deletingCurrent) {
    loadTrack(Math.min(firstRemoved, playlist.length - 1), wasPlaying);
  } else {
    currentTrackIndex -= removedBeforeCurrent;
    selected.add(currentTrackIndex);
  }
  renderPlaylist();
  updateButtons();
}

function closeContextMenu() {
  playlistMenu.classList.remove('open');
}

function selectPlaylistRow(event, index) {
  if (event.shiftKey && selected.size) {
    const anchor = [...selected].at(-1);
    selected = new Set(Array.from({ length: Math.abs(index - anchor) + 1 }, (_, i) => Math.min(index, anchor) + i));
  } else if (event.ctrlKey || event.metaKey) {
    selected.has(index) ? selected.delete(index) : selected.add(index);
  } else {
    selected = new Set([index]);
  }
  renderPlaylist();
}

playlistEl.addEventListener('contextmenu', (event) => {
  const row = event.target.closest('.track');
  if (!row) return;
  event.preventDefault();
  const index = Number(row.dataset.index);
  if (!selected.has(index)) selected = new Set([index]);
  renderPlaylist();
  deleteSelected.textContent = selected.size > 1 ? `删除所选 ${selected.size} 项` : '删除所选项目';
  playlistMenu.style.left = `${event.clientX}px`;
  playlistMenu.style.top = `${event.clientY}px`;
  playlistMenu.classList.add('open');
});

document.addEventListener('click', closeContextMenu);
deleteSelected.addEventListener('click', deleteSelectedTracks);
clearPlaylist.addEventListener('click', () => {
  playlist = [];
  selected.clear();
  currentTrackIndex = -1;
  audio.removeAttribute('src');
  setSubtitleDisplay('打开音频后，将在这里显示当前字幕');
  renderPlaylist();
  updateButtons();
});

subtitleStage.addEventListener('click', () => {
  window.clearTimeout(subtitleClickTimer);
  subtitleClickTimer = window.setTimeout(() => {
    if (!audio.src) return;
    audio.paused ? audio.play() : audio.pause();
  }, 220);
});
subtitleStage.addEventListener('dblclick', () => {
  window.clearTimeout(subtitleClickTimer);
  api.toggleFullscreen();
});
playPause.addEventListener('click', () => {
  if (!audio.src) return;
  audio.paused ? audio.play() : audio.pause();
});
previousTrack.addEventListener('click', () => playlist.length && loadTrack(currentTrackIndex > 0 ? currentTrackIndex - 1 : playlist.length - 1, true));
nextTrack.addEventListener('click', () => playlist.length && loadTrack(currentTrackIndex + 1 < playlist.length ? currentTrackIndex + 1 : 0, true));
previousSentence.addEventListener('click', () => {
  if (!subtitles.length) return;
  currentSubtitleIndex = Math.max(0, currentSubtitleIndex - 1);
  audio.currentTime = subtitles[currentSubtitleIndex].start + 0.01;
  updateSubtitle(true);
});
nextSentence.addEventListener('click', () => {
  if (!subtitles.length) return;
  currentSubtitleIndex = Math.min(subtitles.length - 1, Math.max(0, currentSubtitleIndex + 1));
  audio.currentTime = subtitles[currentSubtitleIndex].start + 0.01;
  updateSubtitle(true);
});

subtitleTrack.addEventListener('change', () => loadSubtitleFile(subtitleTrack.value));
subtitleMode.addEventListener('click', () => {
  subtitleDisplayMode = modes[(modes.indexOf(subtitleDisplayMode) + 1) % modes.length];
  localStorage.setItem('FirePlayer.subtitleDisplayMode', subtitleDisplayMode);
  if (subtitles[currentSubtitleIndex]) setSubtitleDisplay(subtitles[currentSubtitleIndex].text);
  updateButtons();
});
playbackMode.addEventListener('click', () => {
  playbackModeValue = playbackModes[(playbackModes.indexOf(playbackModeValue) + 1) % playbackModes.length];
  localStorage.setItem('FirePlayer.playbackMode', playbackModeValue);
  updateButtons();
});
speed.addEventListener('change', () => { audio.playbackRate = Number(speed.value.replace('×', '')); });
smallerFont.addEventListener('click', () => { fontSize = Math.max(24, fontSize - 4); localStorage.setItem('FirePlayer.fontSize', String(fontSize)); updateButtons(); });
largerFont.addEventListener('click', () => { fontSize = Math.min(110, fontSize + 4); localStorage.setItem('FirePlayer.fontSize', String(fontSize)); updateButtons(); });
subtitleColor.addEventListener('input', updateButtons);
volume.addEventListener('input', () => { audio.volume = Number(volume.value); });
togglePlaylist.addEventListener('click', () => {
  playlistVisible = !playlistVisible;
  appShell.classList.toggle('playlist-hidden', !playlistVisible && !isFullscreen);
  togglePlaylist.textContent = playlistVisible ? '隐藏清单' : '显示清单';
});

function setFullscreenState(nextValue) {
  isFullscreen = nextValue;
  appShell.classList.toggle('fullscreen', isFullscreen);
  appShell.classList.toggle('playlist-hidden', !playlistVisible && !isFullscreen);
  updateButtons();
}

playlistResizer.addEventListener('pointerdown', (event) => {
  if (isFullscreen || !playlistVisible) return;
  isResizingPlaylist = true;
  appShell.classList.add('resizing');
  playlistResizer.setPointerCapture(event.pointerId);
  event.preventDefault();
});

playlistResizer.addEventListener('pointermove', (event) => {
  if (!isResizingPlaylist) return;
  applyPlaylistWidth(event.clientX);
});

function stopPlaylistResize(event) {
  if (!isResizingPlaylist) return;
  isResizingPlaylist = false;
  appShell.classList.remove('resizing');
  if (event?.pointerId != null && playlistResizer.hasPointerCapture(event.pointerId)) {
    playlistResizer.releasePointerCapture(event.pointerId);
  }
}

playlistResizer.addEventListener('pointerup', stopPlaylistResize);
playlistResizer.addEventListener('pointercancel', stopPlaylistResize);

document.addEventListener('keydown', (event) => {
  const target = event.target;
  const isEditing = target && (
    target.tagName === 'INPUT' ||
    target.tagName === 'SELECT' ||
    target.tagName === 'TEXTAREA' ||
    target.isContentEditable
  );
  if (isEditing) return;

  if (event.code === 'Space') {
    event.preventDefault();
    if (audio.src) audio.paused ? audio.play() : audio.pause();
    return;
  }
  if (event.key.toLowerCase() === 'f' && !event.ctrlKey && !event.metaKey && !event.altKey) {
    event.preventDefault();
    api.toggleFullscreen();
    return;
  }
  if (event.key === 'Escape') {
    api.exitFullscreen();
    return;
  }
  if (event.key === 'ArrowLeft') {
    event.preventDefault();
    if (event.ctrlKey || event.metaKey) {
      if (playlist.length) loadTrack(currentTrackIndex > 0 ? currentTrackIndex - 1 : playlist.length - 1, true);
    } else {
      previousSentence.click();
    }
    return;
  }
  if (event.key === 'ArrowRight') {
    event.preventDefault();
    if (event.ctrlKey || event.metaKey) {
      if (playlist.length) loadTrack(currentTrackIndex + 1 < playlist.length ? currentTrackIndex + 1 : 0, true);
    } else {
      nextSentence.click();
    }
  }
});

seek.addEventListener('input', () => {
  audio.currentTime = Number(seek.value);
  updateSubtitle(true);
});

audio.addEventListener('play', updateButtons);
audio.addEventListener('pause', updateButtons);
audio.addEventListener('loadedmetadata', () => {
  seek.max = String(audio.duration || 1);
  time.textContent = `${formatTime(audio.currentTime)} / ${formatTime(audio.duration)}`;
});
audio.addEventListener('timeupdate', () => {
  seek.value = String(audio.currentTime || 0);
  time.textContent = `${formatTime(audio.currentTime)} / ${formatTime(audio.duration)}`;
  updateSubtitle();
});
audio.addEventListener('ended', () => {
  if (playbackModeValue === '单曲循环') {
    audio.currentTime = 0;
    audio.play();
  } else if (playbackModeValue === '列表循环' || currentTrackIndex + 1 < playlist.length) {
    loadTrack(currentTrackIndex + 1 < playlist.length ? currentTrackIndex + 1 : 0, true);
  } else {
    audio.currentTime = 0;
    updateButtons();
  }
});

api.onAddAudio(addAudio);
api.onAddSubtitles(addSubtitles);
api.onClearPlaylist(() => clearPlaylist.click());
api.onFullscreenChanged(setFullscreenState);

applyPlaylistWidth(playlistWidth);
updateButtons();
renderPlaylist();
