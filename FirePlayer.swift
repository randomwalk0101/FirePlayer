import AppKit
import AVFoundation
import UniformTypeIdentifiers

struct SubtitleItem {
    let index: Int
    let start: TimeInterval
    let end: TimeInterval
    let text: String
}

final class SRTParser {
    static func parse(_ content: String) -> [SubtitleItem] {
        let normalized = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let blocks = normalized.components(separatedBy: "\n\n")
        var result: [SubtitleItem] = []

        for block in blocks {
            let lines = block.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            guard lines.count >= 2 else { continue }

            var cursor = 0
            let parsedIndex = Int(lines[0])
            let index = parsedIndex ?? (result.count + 1)
            if parsedIndex != nil { cursor = 1 }
            guard cursor < lines.count else { continue }

            let timeParts = lines[cursor].components(separatedBy: "-->")
            cursor += 1
            guard timeParts.count == 2,
                  let start = parseTime(timeParts[0]),
                  let end = parseTime(timeParts[1]),
                  cursor < lines.count else { continue }

            let text = lines[cursor...].joined(separator: "\n")
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            result.append(SubtitleItem(index: index, start: start, end: end, text: text))
        }
        return result.sorted { $0.start < $1.start }
    }

    private static func parseTime(_ raw: String) -> TimeInterval? {
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        let parts = clean.split(separator: ":")
        guard parts.count == 3,
              let h = Double(parts[0]),
              let m = Double(parts[1]),
              let s = Double(parts[2]) else { return nil }
        return h * 3600 + m * 60 + s
    }
}


final class CenteredSubtitleView: NSView {
    var englishText: String = "" { didSet { needsDisplay = true } }
    var translationText: String = "" { didSet { needsDisplay = true } }
    var showsTranslation: Bool = false { didSet { needsDisplay = true } }
    var showsStressSkeleton: Bool = false { didSet { needsDisplay = true } }
    var showsFlowAnnotation: Bool = false { didSet { needsDisplay = true } }
    var showsPhoneticGuide: Bool = false { didSet { needsDisplay = true } }
    var textColor: NSColor = NSColor(calibratedRed: 1.0, green: 0.91, blue: 0.36, alpha: 1) { didSet { needsDisplay = true } }
    var font: NSFont = NSFont.systemFont(ofSize: 54, weight: .bold) { didSet { needsDisplay = true } }
    var clickHandler: (() -> Void)?
    var doubleClickHandler: (() -> Void)?

    override var isFlipped: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if event.clickCount == 2 {
            doubleClickHandler?()
        } else if event.clickCount == 1 {
            clickHandler?()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !englishText.isEmpty || !translationText.isEmpty else { return }

        let horizontalPadding: CGFloat = 34
        let availableWidth = max(1, bounds.width - horizontalPadding * 2)
        let english = englishText.isEmpty ? translationText : englishText

        let englishParagraph = NSMutableParagraphStyle()
        englishParagraph.alignment = .center
        englishParagraph.lineBreakMode = .byWordWrapping
        englishParagraph.lineSpacing = max(2, font.pointSize * 0.08)

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.9)
        shadow.shadowBlurRadius = 3
        shadow.shadowOffset = NSSize(width: 0, height: 2)

        let englishAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: englishParagraph,
            .shadow: shadow
        ]
        let flowResult = showsFlowAnnotation ? makeFlowAnnotation(english, paragraph: englishParagraph, shadow: shadow) : nil
        let phoneticResult = showsPhoneticGuide ? makeLearningPhoneticGuide(english, paragraph: englishParagraph, shadow: shadow) : nil
        let englishAttributed: NSAttributedString
        if let phoneticResult = phoneticResult {
            englishAttributed = phoneticResult.main
        } else if let flowResult = flowResult {
            englishAttributed = flowResult.main
        } else if showsStressSkeleton {
            englishAttributed = makeStressSkeletonAttributedString(english, paragraph: englishParagraph, shadow: shadow)
        } else {
            englishAttributed = NSAttributedString(string: english, attributes: englishAttrs)
        }
        let englishMeasured = englishAttributed.boundingRect(
            with: NSSize(width: availableWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )

        var translationHeight: CGFloat = 0
        var translationAttrs: [NSAttributedString.Key: Any] = [:]
        let translationGap = max(12, font.pointSize * 0.22)
        let auxiliaryText: String
        if showsPhoneticGuide {
            auxiliaryText = phoneticResult?.notes ?? ""
        } else if showsFlowAnnotation {
            auxiliaryText = flowResult?.notes ?? ""
        } else if showsTranslation && !translationText.isEmpty && translationText != english {
            auxiliaryText = translationText
        } else {
            auxiliaryText = ""
        }
        if !auxiliaryText.isEmpty {
            let translationParagraph = NSMutableParagraphStyle()
            translationParagraph.alignment = .center
            translationParagraph.lineBreakMode = .byWordWrapping
            translationParagraph.lineSpacing = max(1, font.pointSize * 0.04)
            translationAttrs = [
                .font: NSFont.systemFont(ofSize: max(18, font.pointSize * ((showsFlowAnnotation || showsPhoneticGuide) ? 0.38 : 0.58)), weight: (showsFlowAnnotation || showsPhoneticGuide) ? .regular : .medium),
                .foregroundColor: NSColor.white.withAlphaComponent((showsFlowAnnotation || showsPhoneticGuide) ? 0.72 : 0.92),
                .paragraphStyle: translationParagraph,
                .shadow: shadow
            ]
            translationHeight = (auxiliaryText as NSString).boundingRect(
                with: NSSize(width: availableWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: translationAttrs
            ).height
        }

        let totalHeight = min(bounds.height, englishMeasured.height + (translationHeight > 0 ? translationGap + translationHeight : 0))
        var y = max(0, (bounds.height - totalHeight) / 2)
        let englishHeight = min(englishMeasured.height, bounds.height)
        let englishRect = NSRect(x: horizontalPadding, y: y, width: availableWidth, height: englishHeight)
        englishAttributed.draw(with: englishRect, options: [.usesLineFragmentOrigin, .usesFontLeading])

        if translationHeight > 0 {
            y += englishHeight + translationGap
            let translationRect = NSRect(x: horizontalPadding, y: y, width: availableWidth, height: min(translationHeight, max(0, bounds.height - y)))
            (auxiliaryText as NSString).draw(with: translationRect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: translationAttrs)
        }
    }

    private struct PhoneticGuideResult {
        let main: NSAttributedString
        let notes: String
    }

    /// 学习型发音提示：不是 IPA，也不声称逐字还原真实音频。
    /// 它把常见美式口语缩约、弱读和跨词同化写成更接近“耳朵听到”的拼写。
    private func makeLearningPhoneticGuide(_ text: String, paragraph: NSParagraphStyle, shadow: NSShadow) -> PhoneticGuideResult {
        var spoken = text
        let phraseRules: [(String, String, String)] = [
            (#"(?i)\bwhat\s+do\s+you\b"#, "whaddaya", "what do you → whaddaya"),
            (#"(?i)\bwhat\s+did\s+you\b"#, "whadja", "what did you → whadja"),
            (#"(?i)\bdid\s+you\b"#, "didja", "did you → didja"),
            (#"(?i)\bdon't\s+you\b"#, "doncha", "don't you → doncha"),
            (#"(?i)\bcan't\s+you\b"#, "cancha", "can't you → cancha"),
            (#"(?i)\bwould\s+you\b"#, "wouldja", "would you → wouldja"),
            (#"(?i)\bcould\s+you\b"#, "couldja", "could you → couldja"),
            (#"(?i)\bwon't\s+you\b"#, "woncha", "won't you → woncha"),
            (#"(?i)\bwant\s+to\b"#, "wanna", "want to → wanna"),
            (#"(?i)\bgoing\s+to\b"#, "gonna", "going to → gonna"),
            (#"(?i)\bgot\s+to\b"#, "gotta", "got to → gotta"),
            (#"(?i)\bhave\s+to\b"#, "hafta", "have to → hafta"),
            (#"(?i)\bhas\s+to\b"#, "hasta", "has to → hasta"),
            (#"(?i)\bused\s+to\b"#, "useta", "used to → useta"),
            (#"(?i)\blet\s+me\b"#, "lemme", "let me → lemme"),
            (#"(?i)\bgive\s+me\b"#, "gimme", "give me → gimme"),
            (#"(?i)\btell\s+them\b"#, "tell 'em", "them → 'em"),
            (#"(?i)\bkind\s+of\b"#, "kinda", "kind of → kinda"),
            (#"(?i)\bsort\s+of\b"#, "sorta", "sort of → sorta"),
            (#"(?i)\bout\s+of\b"#, "outta", "out of → outta"),
            (#"(?i)\ba\s+lot\s+of\b"#, "a lotta", "a lot of → a lotta"),
            (#"(?i)\bgive\s+you\b"#, "givya", "give you → givya"),
            (#"(?i)\bget\s+you\b"#, "getcha", "get you → getcha"),
            (#"(?i)\bgot\s+you\b"#, "gotcha", "got you → gotcha")
        ]
        var notes: [String] = []
        for (pattern, replacement, note) in phraseRules {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(spoken.startIndex..<spoken.endIndex, in: spoken)
            if regex.firstMatch(in: spoken, range: range) != nil {
                spoken = regex.stringByReplacingMatches(in: spoken, range: range, withTemplate: replacement)
                notes.append(note)
            }
        }

        let weakWordRules: [(String, String, String)] = [
            (#"(?i)\band\b"#, "'n", "and → 'n / ən"),
            (#"(?i)\bto\b"#, "tə", "to → tə"),
            (#"(?i)\bfor\b"#, "fər", "for → fər"),
            (#"(?i)\bof\b"#, "əv", "of → əv"),
            (#"(?i)\bthe\b"#, "thə", "the → thə"),
            (#"(?i)\bcan\b"#, "kən", "can → kən")
        ]
        for (pattern, replacement, note) in weakWordRules {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(spoken.startIndex..<spoken.endIndex, in: spoken)
            if regex.firstMatch(in: spoken, range: range) != nil {
                spoken = regex.stringByReplacingMatches(in: spoken, range: range, withTemplate: replacement)
                if !notes.contains(note) { notes.append(note) }
            }
        }

        // 常见美式闪音的学习型拼写：只标出很高概率的词，不做过度改写。
        let flapRules: [(String, String, String)] = [
            (#"(?i)\bwater\b"#, "wadder", "water：t 常读作闪音 [ɾ]"),
            (#"(?i)\bbetter\b"#, "bedder", "better：t 常读作闪音 [ɾ]"),
            (#"(?i)\bcity\b"#, "cidy", "city：t 常读作闪音 [ɾ]"),
            (#"(?i)\bpretty\b"#, "priddy", "pretty：t 常读作闪音 [ɾ]"),
            (#"(?i)\bget\s+it\b"#, "geddit", "get it → geddit（闪音/连读）")
        ]
        for (pattern, replacement, note) in flapRules {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(spoken.startIndex..<spoken.endIndex, in: spoken)
            if regex.firstMatch(in: spoken, range: range) != nil {
                spoken = regex.stringByReplacingMatches(in: spoken, range: range, withTemplate: replacement)
                notes.append(note)
            }
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: font.pointSize, weight: .bold),
            .foregroundColor: textColor,
            .paragraphStyle: paragraph,
            .shadow: shadow
        ]
        let explanation = notes.isEmpty
            ? "本句没有套用高置信度学习型改写；请以原音频为准。"
            : notes.prefix(6).joined(separator: "；")
        return PhoneticGuideResult(
            main: NSAttributedString(string: spoken, attributes: attrs),
            notes: "原文：\(text)    ·    \(explanation)    ·    学习型近似拼写，不是 IPA，也不是音频实测"
        )
    }

    private struct FlowAnnotationResult {
        let main: NSAttributedString
        let notes: String
    }

    private func makeFlowAnnotation(_ text: String, paragraph: NSParagraphStyle, shadow: NSShadow) -> FlowAnnotationResult {
        let weakForms: [String: String] = [
            "a":"ə", "an":"ən", "the":"ðə", "and":"ən(d)", "to":"tə", "of":"əv",
            "for":"fər", "from":"frəm", "at":"ət", "as":"əz", "than":"ðən",
            "can":"kən", "could":"kəd", "would":"wəd", "should":"ʃəd",
            "have":"əv", "has":"əz", "had":"əd", "was":"wəz", "were":"wər",
            "is":"ɪz", "are":"ər", "your":"jər", "you":"jə", "them":"ðəm", "him":"ɪm", "her":"ər"
        ]
        let weakWords = Set(weakForms.keys)
        let wordRegex = try! NSRegularExpression(pattern: #"[A-Za-z]+(?:['’][A-Za-z]+)?"#)
        let ns = text as NSString
        let matches = wordRegex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        let result = NSMutableAttributedString(string: "")
        var cursor = 0
        var weakNotes: [String] = []
        var linkNotes: [String] = []
        var flapNotes: [String] = []
        var elisionNotes: [String] = []

        func firstLetter(_ value: String) -> Character? { value.lowercased().first(where: { $0.isLetter }) }
        func lastLetter(_ value: String) -> Character? { value.lowercased().reversed().first(where: { $0.isLetter }) }
        func isVowel(_ c: Character?) -> Bool { c.map { "aeiou".contains($0) } ?? false }

        let words: [(text:String, range:NSRange)] = matches.map { (ns.substring(with: $0.range), $0.range) }
        for i in words.indices {
            let item = words[i]
            if item.range.location > cursor {
                let gapRange = NSRange(location: cursor, length: item.range.location - cursor)
                var gap = ns.substring(with: gapRange)
                if i > 0, gap.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   !isVowel(lastLetter(words[i-1].text)), isVowel(firstLetter(item.text)) {
                    gap = "‿"
                    let pair = "\(words[i-1].text)‿\(item.text)"
                    if !linkNotes.contains(pair) { linkNotes.append(pair) }
                }
                result.append(NSAttributedString(string: gap, attributes: [
                    .font: NSFont.systemFont(ofSize: font.pointSize * 0.78),
                    .foregroundColor: NSColor.white.withAlphaComponent(0.55),
                    .paragraphStyle: paragraph, .shadow: shadow
                ]))
            }
            let word = item.text
            let normalized = word.lowercased().replacingOccurrences(of: "’", with: "'")
            let isWeak = weakWords.contains(normalized)
            if isWeak, let form = weakForms[normalized] {
                let note = "\(word)→/\(form)/"
                if !weakNotes.contains(note) { weakNotes.append(note) }
            }
            let attrs: [NSAttributedString.Key: Any] = isWeak ? [
                .font: NSFont.systemFont(ofSize: font.pointSize * 0.76, weight: .regular),
                .foregroundColor: NSColor.white.withAlphaComponent(0.48),
                .paragraphStyle: paragraph, .shadow: shadow
            ] : [
                .font: NSFont.systemFont(ofSize: font.pointSize * 1.06, weight: .heavy),
                .foregroundColor: textColor, .paragraphStyle: paragraph, .shadow: shadow, .kern: 0.25
            ]
            result.append(NSAttributedString(string: word, attributes: attrs))
            cursor = item.range.location + item.range.length

            let lower = normalized
            if lower.range(of: #"[aeiou][td][aeiou]"#, options: .regularExpression) != nil ||
               ["water","better","city","pretty","little","meeting","getting"].contains(lower) {
                let note = "\(word)：/t,d/→[ɾ]（可能）"
                if !flapNotes.contains(note) { flapNotes.append(note) }
            }
            if i + 1 < words.count {
                let next = words[i+1].text.lowercased()
                if (lower.hasSuffix("t") || lower.hasSuffix("d")) &&
                   !isVowel(next.first) {
                    let marked = String(word.dropLast()) + "(" + String(word.suffix(1)) + ") " + words[i+1].text
                    if !elisionNotes.contains(marked) { elisionNotes.append(marked) }
                }
            }
        }
        if cursor < ns.length {
            result.append(NSAttributedString(string: ns.substring(from: cursor), attributes: [
                .font: NSFont.systemFont(ofSize: font.pointSize * 0.78),
                .foregroundColor: NSColor.white.withAlphaComponent(0.55),
                .paragraphStyle: paragraph, .shadow: shadow
            ]))
        }
        var sections: [String] = []
        if !linkNotes.isEmpty { sections.append("连读：" + linkNotes.prefix(4).joined(separator: "；")) }
        if !weakNotes.isEmpty { sections.append("弱读：" + weakNotes.prefix(5).joined(separator: "；")) }
        if !flapNotes.isEmpty { sections.append("闪音：" + flapNotes.prefix(3).joined(separator: "；")) }
        if !elisionNotes.isEmpty { sections.append("吞音：" + elisionNotes.prefix(3).joined(separator: "；") + "（可能）") }
        if sections.isEmpty { sections.append("本句未检测到明显语流现象（规则预测）") }
        return FlowAnnotationResult(main: result, notes: sections.joined(separator: "    ") + "    · 规则预测")
    }

    private func makeStressSkeletonAttributedString(_ text: String, paragraph: NSParagraphStyle, shadow: NSShadow) -> NSAttributedString {
        let result = NSMutableAttributedString(string: "")
        let weakWords: Set<String> = [
            "a", "an", "the", "and", "or", "but", "so", "for", "nor", "yet",
            "to", "of", "in", "on", "at", "by", "from", "with", "as", "into", "onto", "over", "under",
            "i", "you", "he", "she", "it", "we", "they", "me", "him", "her", "us", "them",
            "my", "your", "his", "its", "our", "their", "this", "that", "these", "those",
            "am", "is", "are", "was", "were", "be", "been", "being",
            "do", "does", "did", "have", "has", "had", "can", "could", "will", "would", "shall", "should", "may", "might", "must"
        ]
        let tokenPattern = #"[A-Za-z]+(?:['’][A-Za-z]+)?|[^A-Za-z]+"#
        guard let regex = try? NSRegularExpression(pattern: tokenPattern) else {
            return NSAttributedString(string: text, attributes: [
                .font: font, .foregroundColor: textColor, .paragraphStyle: paragraph, .shadow: shadow
            ])
        }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        for match in matches {
            let token = nsText.substring(with: match.range)
            let normalized = token.lowercased().trimmingCharacters(in: .punctuationCharacters)
            let isWord = token.rangeOfCharacter(from: .letters) != nil
            let isWeak = isWord && weakWords.contains(normalized)
            let attrs: [NSAttributedString.Key: Any]
            if isWord && !isWeak {
                attrs = [
                    .font: NSFont.systemFont(ofSize: font.pointSize * 1.08, weight: .heavy),
                    .foregroundColor: textColor,
                    .paragraphStyle: paragraph,
                    .shadow: shadow,
                    .kern: 0.3
                ]
            } else {
                attrs = [
                    .font: NSFont.systemFont(ofSize: font.pointSize * 0.78, weight: .regular),
                    .foregroundColor: NSColor.white.withAlphaComponent(0.48),
                    .paragraphStyle: paragraph,
                    .shadow: shadow
                ]
            }
            result.append(NSAttributedString(string: token, attributes: attrs))
        }
        return result
    }

}

enum SubtitleDisplayMode: String {
    case english = "英文"
    case bilingual = "双语"
    case stress = "重音骨架"
    case flow = "语流标注"
    case phonetic = "发音提示"
}

enum PlaybackMode: String {
    case sequential = "顺序播放"
    case repeatOne = "单曲循环"
    case repeatAll = "列表循环"
}

final class PlayerViewController: NSViewController, AVAudioPlayerDelegate, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate {
    private var player: AVAudioPlayer?
    private var playlist: [URL] = []
    private var currentTrackIndex = -1
    private var subtitles: [SubtitleItem] = []
    private var currentSubtitleIndex = -1
    private var timer: Timer?
    private var subtitleURL: URL?
    private var registeredSubtitleURLs: [URL] = []
    private var availableSubtitleURLs: [URL] = []
    private var playlistWidthConstraint: NSLayoutConstraint!
    private var transportCenterConstraint: NSLayoutConstraint!
    private var sentenceCenterConstraint: NSLayoutConstraint!
    private var settingsCenterConstraint: NSLayoutConstraint!
    private var subtitleBottomToControlsConstraint: NSLayoutConstraint!
    private var subtitleBottomToWindowConstraint: NSLayoutConstraint!
    private var controlsAutoHideTimer: Timer?
    private var activityEventMonitor: Any?
    private var controlsAreVisible = true
    private var isUpdatingPlaylistSelectionFromContextMenu = false
    private weak var sentenceControlsStack: NSStackView?
    private weak var settingsControlsStack: NSStackView?
    private var isPlaylistVisible = true
    private var subtitleDisplayMode: SubtitleDisplayMode = .english
    private var playbackMode: PlaybackMode = .sequential

    private let playlistContainer = NSView()
    private let controlsContainer = NSView()
    private let playlistTitle = NSTextField(labelWithString: "播放清单")
    private let clearPlaylistButton = NSButton(title: "清空清单", target: nil, action: nil)
    private let tableView = NSTableView()
    private let playlistContextMenu = NSMenu()
    private let deletePlaylistItemsMenuItem = NSMenuItem(title: "删除所选项目", action: #selector(deleteSelectedPlaylistItems), keyEquivalent: "")
    private let scrollView = NSScrollView()
    private let emptyPlaylistLabel = NSTextField(wrappingLabelWithString: "尚未添加音频\n\n点击上方“打开音频…”\n可一次选择多个文件")

    private let nowPlayingLabel = NSTextField(labelWithString: "尚未打开音频")
    private let subtitleStatusLabel = NSTextField(labelWithString: "未加载字幕")
    private let subtitleLabel = CenteredSubtitleView()
    private let timeLabel = NSTextField(labelWithString: "00:00 / 00:00")
    private let slider = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let playButton = NSButton(title: "▶  播放", target: nil, action: nil)
    private let previousTrackButton = NSButton(title: "⏮  上一首", target: nil, action: nil)
    private let nextTrackButton = NSButton(title: "下一首  ⏭", target: nil, action: nil)
    private let previousSentenceButton = NSButton(title: "← 上一句", target: nil, action: nil)
    private let nextSentenceButton = NSButton(title: "下一句 →", target: nil, action: nil)
    private let speedPopup = NSPopUpButton()
    private let fontSizeLabel = NSTextField(labelWithString: "字号 54")
    private let volumeSlider = NSSlider(value: 1, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let togglePlaylistButton = NSButton(title: "隐藏清单", target: nil, action: nil)
    private let subtitleModeButton = NSButton(title: "字幕：英文", target: nil, action: nil)
    private let subtitleTrackPopup = NSPopUpButton()
    private let playbackModeButton = NSButton(title: "顺序播放", target: nil, action: nil)

    private var fontSize: CGFloat = 54 {
        didSet {
            fontSize = min(max(fontSize, 24), 110)
            subtitleLabel.font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
            fontSizeLabel.stringValue = "字号 \(Int(fontSize))"
            UserDefaults.standard.set(Double(fontSize), forKey: "FirePlayer.fontSize")
        }
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 1240, height: 760))
        view.appearance = NSAppearance(named: .darkAqua)
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(calibratedWhite: 0.065, alpha: 1).cgColor
        buildUI()
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        let saved = UserDefaults.standard.double(forKey: "FirePlayer.fontSize")
        fontSize = saved > 0 ? CGFloat(saved) : 54
        if let raw = UserDefaults.standard.string(forKey: "FirePlayer.subtitleDisplayMode"), let mode = SubtitleDisplayMode(rawValue: raw) {
            subtitleDisplayMode = mode
        }
        if let raw = UserDefaults.standard.string(forKey: "FirePlayer.playbackMode"), let mode = PlaybackMode(rawValue: raw) {
            playbackMode = mode
        }
        refreshModeButtons()

        view.window?.acceptsMouseMovedEvents = true
        installActivityMonitorIfNeeded()
        showControlsAndScheduleHide()
    }

    private func buildUI() {
        playlistContainer.wantsLayer = true
        playlistContainer.layer?.backgroundColor = NSColor(calibratedWhite: 0.095, alpha: 1).cgColor
        playlistContainer.layer?.borderColor = NSColor.separatorColor.cgColor
        playlistContainer.layer?.borderWidth = 1

        playlistTitle.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        playlistTitle.textColor = .labelColor

        clearPlaylistButton.target = self
        clearPlaylistButton.action = #selector(clearPlaylist)
        clearPlaylistButton.bezelStyle = .rounded
        clearPlaylistButton.controlSize = .small
        clearPlaylistButton.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        clearPlaylistButton.toolTip = "移除播放清单中的全部音频"

        emptyPlaylistLabel.alignment = .center
        emptyPlaylistLabel.textColor = .secondaryLabelColor
        emptyPlaylistLabel.font = NSFont.systemFont(ofSize: 14)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("track"))
        column.title = ""
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 48
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .regular
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.doubleAction = #selector(doubleClickPlaylist)
        tableView.allowsMultipleSelection = true

        deletePlaylistItemsMenuItem.target = self
        playlistContextMenu.delegate = self
        playlistContextMenu.addItem(deletePlaylistItemsMenuItem)
        tableView.menu = playlistContextMenu

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        nowPlayingLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        nowPlayingLabel.textColor = .labelColor
        nowPlayingLabel.lineBreakMode = .byTruncatingMiddle

        subtitleStatusLabel.font = NSFont.systemFont(ofSize: 13)
        subtitleStatusLabel.textColor = .secondaryLabelColor
        subtitleStatusLabel.alignment = .right

        setSubtitleDisplay(fullText: "打开音频后，将在这里显示当前字幕")
        subtitleLabel.clickHandler = { [weak self] in self?.togglePlay() }
        subtitleLabel.doubleClickHandler = { [weak self] in self?.view.window?.toggleFullScreen(nil) }

        timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        timeLabel.textColor = .secondaryLabelColor
        timeLabel.alignment = .right

        slider.target = self
        slider.action = #selector(seekChanged(_:))
        slider.isContinuous = true

        volumeSlider.target = self
        volumeSlider.action = #selector(volumeChanged(_:))
        volumeSlider.isContinuous = true
        volumeSlider.toolTip = "音量"

        playButton.target = self
        playButton.action = #selector(togglePlay)
        playButton.keyEquivalent = " "
        styleMainButton(playButton)

        previousTrackButton.target = self
        previousTrackButton.action = #selector(previousTrack)
        styleMainButton(previousTrackButton)

        nextTrackButton.target = self
        nextTrackButton.action = #selector(nextTrack)
        styleMainButton(nextTrackButton)

        previousSentenceButton.target = self
        previousSentenceButton.action = #selector(previousSubtitle)
        previousSentenceButton.bezelStyle = .rounded

        nextSentenceButton.target = self
        nextSentenceButton.action = #selector(nextSubtitle)
        nextSentenceButton.bezelStyle = .rounded

        togglePlaylistButton.target = self
        togglePlaylistButton.action = #selector(togglePlaylist)
        togglePlaylistButton.bezelStyle = .rounded

        subtitleModeButton.target = self
        subtitleModeButton.action = #selector(toggleSubtitleMode)
        subtitleModeButton.bezelStyle = .rounded
        subtitleModeButton.toolTip = "在英文、双语、重音骨架、语流标注和发音提示之间切换"

        subtitleTrackPopup.target = self
        subtitleTrackPopup.action = #selector(subtitleTrackChanged)
        subtitleTrackPopup.toolTip = "切换当前音频对应的不同字幕文件"
        subtitleTrackPopup.addItem(withTitle: "字幕版本：无")
        subtitleTrackPopup.isEnabled = false

        playbackModeButton.target = self
        playbackModeButton.action = #selector(cyclePlaybackMode)
        playbackModeButton.bezelStyle = .rounded
        playbackModeButton.toolTip = "切换顺序播放、单曲循环和列表循环"

        speedPopup.addItems(withTitles: ["0.75×", "0.8×", "0.9×", "1.0×", "1.1×", "1.2×", "1.25×", "1.5×", "1.75×", "2.0×"])
        speedPopup.selectItem(withTitle: "1.0×")
        speedPopup.target = self
        speedPopup.action = #selector(speedChanged)

        let smallerButton = makeButton("A−", action: #selector(smallerFont))
        let largerButton = makeButton("A+", action: #selector(largerFont))
        let colorButton = makeButton("字幕颜色", action: #selector(chooseColor))

        let transportControls = NSStackView(views: [previousTrackButton, playButton, nextTrackButton])
        transportControls.orientation = .horizontal
        transportControls.spacing = 12
        transportControls.alignment = .centerY

        // 底部控制区采用两行布局，避免窗口变窄时控件溢出屏幕。
        let sentenceControls = NSStackView(views: [togglePlaylistButton, previousSentenceButton, nextSentenceButton, subtitleTrackPopup, subtitleModeButton, playbackModeButton])
        sentenceControls.orientation = .horizontal
        sentenceControls.spacing = 8
        sentenceControls.alignment = .centerY
        sentenceControls.distribution = .gravityAreas

        let volumeIcon = NSTextField(labelWithString: "🔊")
        let settingsControls = NSStackView(views: [speedPopup, smallerButton, fontSizeLabel, largerButton, colorButton, volumeIcon, volumeSlider])
        settingsControls.orientation = .horizontal
        settingsControls.spacing = 8
        settingsControls.alignment = .centerY
        settingsControls.distribution = .gravityAreas

        sentenceControlsStack = sentenceControls
        settingsControlsStack = settingsControls

        controlsContainer.translatesAutoresizingMaskIntoConstraints = false

        [playlistContainer, subtitleLabel, controlsContainer].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        [slider, timeLabel, transportControls, sentenceControls, settingsControls].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            controlsContainer.addSubview($0)
        }
        [playlistTitle, clearPlaylistButton, scrollView, emptyPlaylistLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            playlistContainer.addSubview($0)
        }

        playlistWidthConstraint = playlistContainer.widthAnchor.constraint(equalToConstant: 285)
        transportCenterConstraint = transportControls.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 142.5)
        sentenceCenterConstraint = sentenceControls.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 142.5)
        settingsCenterConstraint = settingsControls.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 142.5)

        subtitleBottomToControlsConstraint = subtitleLabel.bottomAnchor.constraint(equalTo: controlsContainer.topAnchor, constant: -8)
        subtitleBottomToWindowConstraint = subtitleLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8)
        subtitleBottomToWindowConstraint.isActive = false

        NSLayoutConstraint.activate([
            playlistContainer.topAnchor.constraint(equalTo: view.topAnchor),
            playlistContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playlistContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            playlistWidthConstraint,

            playlistTitle.topAnchor.constraint(equalTo: playlistContainer.topAnchor, constant: 20),
            playlistTitle.leadingAnchor.constraint(equalTo: playlistContainer.leadingAnchor, constant: 18),
            clearPlaylistButton.trailingAnchor.constraint(equalTo: playlistContainer.trailingAnchor, constant: -14),
            clearPlaylistButton.centerYAnchor.constraint(equalTo: playlistTitle.centerYAnchor),
            clearPlaylistButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 76),
            playlistTitle.trailingAnchor.constraint(lessThanOrEqualTo: clearPlaylistButton.leadingAnchor, constant: -10),

            scrollView.topAnchor.constraint(equalTo: playlistTitle.bottomAnchor, constant: 14),
            scrollView.leadingAnchor.constraint(equalTo: playlistContainer.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: playlistContainer.trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: playlistContainer.bottomAnchor, constant: -16),

            emptyPlaylistLabel.centerXAnchor.constraint(equalTo: playlistContainer.centerXAnchor),
            emptyPlaylistLabel.centerYAnchor.constraint(equalTo: playlistContainer.centerYAnchor),
            emptyPlaylistLabel.leadingAnchor.constraint(greaterThanOrEqualTo: playlistContainer.leadingAnchor, constant: 20),
            emptyPlaylistLabel.trailingAnchor.constraint(lessThanOrEqualTo: playlistContainer.trailingAnchor, constant: -20),

            controlsContainer.leadingAnchor.constraint(equalTo: playlistContainer.trailingAnchor),
            controlsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controlsContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            controlsContainer.heightAnchor.constraint(equalToConstant: 166),

            slider.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor, constant: 28),
            slider.trailingAnchor.constraint(equalTo: timeLabel.leadingAnchor, constant: -12),
            slider.topAnchor.constraint(equalTo: controlsContainer.topAnchor, constant: 8),

            timeLabel.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor, constant: -26),
            timeLabel.centerYAnchor.constraint(equalTo: slider.centerYAnchor),
            timeLabel.widthAnchor.constraint(equalToConstant: 135),

            transportControls.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: 8),
            sentenceControls.topAnchor.constraint(equalTo: transportControls.bottomAnchor, constant: 7),
            settingsControls.topAnchor.constraint(equalTo: sentenceControls.bottomAnchor, constant: 6),
            settingsControls.bottomAnchor.constraint(lessThanOrEqualTo: controlsContainer.bottomAnchor, constant: -8),
            sentenceControls.leadingAnchor.constraint(greaterThanOrEqualTo: controlsContainer.leadingAnchor, constant: 10),
            sentenceControls.trailingAnchor.constraint(lessThanOrEqualTo: controlsContainer.trailingAnchor, constant: -10),
            settingsControls.leadingAnchor.constraint(greaterThanOrEqualTo: controlsContainer.leadingAnchor, constant: 10),
            settingsControls.trailingAnchor.constraint(lessThanOrEqualTo: controlsContainer.trailingAnchor, constant: -10),
            transportCenterConstraint,
            sentenceCenterConstraint,
            settingsCenterConstraint,

            subtitleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: playlistContainer.trailingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            subtitleBottomToControlsConstraint,

            playButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 125),
            previousTrackButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 115),
            nextTrackButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 115),
            volumeSlider.widthAnchor.constraint(greaterThanOrEqualToConstant: 72),
            volumeSlider.widthAnchor.constraint(lessThanOrEqualToConstant: 120)
        ])
    }

    private func installActivityMonitorIfNeeded() {
        guard activityEventMonitor == nil else { return }
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel, .keyDown]
        activityEventMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            if let strongSelf = self {
                if event.window === strongSelf.view.window || event.type == .keyDown {
                    strongSelf.showControlsAndScheduleHide()
                }
                if event.type == .keyDown, event.window === strongSelf.view.window, strongSelf.handleKeyboardShortcut(event) {
                    return nil
                }
            }
            return event
        }
    }

    private func handleKeyboardShortcut(_ event: NSEvent) -> Bool {
        guard !isTypingInEditableControl(event) else { return false }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hasCommandOrControl = modifiers.contains(.command) || modifiers.contains(.control)

        if event.keyCode == 49 {
            togglePlay()
            return true
        }
        if event.keyCode == 3, modifiers.subtracting([.shift, .capsLock]).isEmpty {
            view.window?.toggleFullScreen(nil)
            return true
        }
        if event.keyCode == 53 {
            if view.window?.styleMask.contains(.fullScreen) == true {
                view.window?.toggleFullScreen(nil)
                return true
            }
            return false
        }
        if event.keyCode == 123 {
            if hasCommandOrControl {
                previousTrack()
            } else {
                previousSubtitle()
            }
            return true
        }
        if event.keyCode == 124 {
            if hasCommandOrControl {
                nextTrack()
            } else {
                nextSubtitle()
            }
            return true
        }
        return false
    }

    private func isTypingInEditableControl(_ event: NSEvent) -> Bool {
        guard let responder = event.window?.firstResponder else { return false }
        if responder is NSTextView { return true }
        if let control = responder as? NSControl, control.currentEditor() != nil { return true }
        return false
    }

    private func showControlsAndScheduleHide() {
        controlsAutoHideTimer?.invalidate()
        showControls(animated: true)

        guard let currentPlayer = player, currentPlayer.isPlaying else { return }
        controlsAutoHideTimer = Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(autoHideControls), userInfo: nil, repeats: false)
    }

    @objc private func autoHideControls() {
        guard let currentPlayer = player, currentPlayer.isPlaying else { return }
        hideControls(animated: true)
    }

    private func showControls(animated: Bool) {
        guard !controlsAreVisible else { return }
        controlsAreVisible = true
        controlsContainer.isHidden = false
        subtitleBottomToWindowConstraint.isActive = false
        subtitleBottomToControlsConstraint.isActive = true

        let changes = {
            self.controlsContainer.animator().alphaValue = 1
            self.view.layoutSubtreeIfNeeded()
        }
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                changes()
            }
        } else {
            controlsContainer.alphaValue = 1
            view.layoutSubtreeIfNeeded()
        }
    }

    private func hideControls(animated: Bool) {
        guard controlsAreVisible else { return }
        controlsAreVisible = false
        subtitleBottomToControlsConstraint.isActive = false
        subtitleBottomToWindowConstraint.isActive = true

        let completion = {
            if !self.controlsAreVisible { self.controlsContainer.isHidden = true }
        }
        if animated {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                self.controlsContainer.animator().alphaValue = 0
                self.view.layoutSubtreeIfNeeded()
            }, completionHandler: completion)
        } else {
            controlsContainer.alphaValue = 0
            controlsContainer.isHidden = true
            view.layoutSubtreeIfNeeded()
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        updateResponsiveControls()
    }

    /// 根据右侧播放区域宽度自动调整底部控件，保证任何窗口尺寸下都不会越界。
    private func updateResponsiveControls() {
        let available = max(0, view.bounds.width - (isPlaylistVisible ? playlistWidthConstraint.constant : 0))
        let compact = available < 900
        let veryCompact = available < 720

        sentenceControlsStack?.spacing = veryCompact ? 3 : (compact ? 5 : 8)
        settingsControlsStack?.spacing = veryCompact ? 3 : (compact ? 5 : 8)

        let controlSize: NSControl.ControlSize = veryCompact ? .mini : (compact ? .small : .regular)
        let buttons = [togglePlaylistButton, previousSentenceButton, nextSentenceButton,
                       subtitleModeButton, playbackModeButton]
        buttons.forEach {
            $0.controlSize = controlSize
            $0.font = NSFont.systemFont(ofSize: veryCompact ? 10 : (compact ? 11 : 13))
        }
        subtitleTrackPopup.controlSize = controlSize
        speedPopup.controlSize = controlSize

        // 窄窗口下使用更短标题，功能保持不变。
        if veryCompact {
            togglePlaylistButton.title = isPlaylistVisible ? "收起" : "清单"
            previousSentenceButton.title = "←句"
            nextSentenceButton.title = "句→"
            playbackModeButton.title = playbackMode == .repeatOne ? "单曲↻" : (playbackMode == .repeatAll ? "列表↻" : "顺序")
        } else {
            togglePlaylistButton.title = isPlaylistVisible ? "隐藏清单" : "显示清单"
            previousSentenceButton.title = "← 上一句"
            nextSentenceButton.title = "下一句 →"
            playbackModeButton.title = playbackMode.rawValue
        }
    }

    private func prominentButton(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .texturedRounded
        button.controlSize = .large
        button.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        return button
    }

    private func makeButton(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        return button
    }

    private func styleMainButton(_ button: NSButton) {
        button.bezelStyle = .texturedRounded
        button.controlSize = .large
        button.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
    }

    @objc func openAudio() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = audioTypes()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.message = "可一次选择一个或多个音频文件"
        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }
        addToPlaylist(panel.urls)
    }

    @objc func openFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.message = "可选择一个或多个文件夹，自动加入其中的音频并配对 SRT"
        panel.prompt = "加入文件夹"
        guard panel.runModal() == .OK else { return }
        var audioURLs: [URL] = []
        for folder in panel.urls {
            let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
            audioURLs.append(contentsOf: files.filter { isAudioURL($0) })
            registerSubtitles(files.filter { $0.pathExtension.lowercased() == "srt" })
        }
        addToPlaylist(audioURLs.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending })
    }

    @objc func openSubtitle() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .text, .data]
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        if currentTrackIndex >= 0 { panel.directoryURL = playlist[currentTrackIndex].deletingLastPathComponent() }
        panel.message = "可一次选择一个或多个 SRT，程序会按文件名自动配对"
        panel.prompt = "加入字幕"
        guard panel.runModal() == .OK else { return }
        let srts = panel.urls.filter { $0.pathExtension.lowercased() == "srt" }
        guard !srts.isEmpty else {
            showAlert(title: "没有选择 SRT", message: "请选择扩展名为 .srt 的字幕文件。")
            return
        }
        registerSubtitles(srts)
        if currentTrackIndex >= 0 { loadSubtitles(for: playlist[currentTrackIndex]); updateUI(forceSubtitle: true) }
    }

    private func audioTypes() -> [UTType] {
        ["mp3", "m4a", "wav", "aac", "flac", "aiff", "aif", "caf"].compactMap { UTType(filenameExtension: $0) }
    }

    private func isAudioURL(_ url: URL) -> Bool {
        ["mp3", "m4a", "wav", "aac", "flac", "aiff", "aif", "caf"].contains(url.pathExtension.lowercased())
    }

    private func registerSubtitles(_ urls: [URL]) {
        for url in urls where url.pathExtension.lowercased() == "srt" {
            if !registeredSubtitleURLs.contains(url) { registeredSubtitleURLs.append(url) }
        }
    }

    private func addToPlaylist(_ urls: [URL]) {
        let audioURLs = urls.filter { isAudioURL($0) }
        for url in audioURLs where !playlist.contains(url) { playlist.append(url) }
        tableView.reloadData()
        emptyPlaylistLabel.isHidden = !playlist.isEmpty
        if currentTrackIndex == -1, !playlist.isEmpty { loadTrack(at: 0, autoplay: false) }
    }

    @objc func clearPlaylist() {
        player?.stop()
        timer?.invalidate()
        saveCurrentPosition()
        playlist.removeAll()
        currentTrackIndex = -1
        subtitles.removeAll()
        currentSubtitleIndex = -1
        subtitleURL = nil
        registeredSubtitleURLs.removeAll()
        availableSubtitleURLs.removeAll()
        refreshSubtitleTrackPopup(selected: nil)
        tableView.reloadData()
        emptyPlaylistLabel.isHidden = false
        nowPlayingLabel.stringValue = "尚未打开音频"
        subtitleStatusLabel.stringValue = "未加载字幕"
        setSubtitleDisplay(fullText: "打开音频后，将在这里显示当前字幕")
        slider.doubleValue = 0
        slider.maxValue = 1
        timeLabel.stringValue = "00:00 / 00:00"
        playButton.title = "▶  播放"
    }

    @objc private func doubleClickPlaylist() {
        let row = tableView.clickedRow
        guard playlist.indices.contains(row) else { return }
        loadTrack(at: row, autoplay: true)
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard menu === playlistContextMenu else { return }
        let clickedRow = tableView.clickedRow
        if playlist.indices.contains(clickedRow), !tableView.selectedRowIndexes.contains(clickedRow) {
            isUpdatingPlaylistSelectionFromContextMenu = true
            tableView.selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
            isUpdatingPlaylistSelectionFromContextMenu = false
        }
        let selectedCount = tableView.selectedRowIndexes.count
        deletePlaylistItemsMenuItem.title = selectedCount > 1 ? "删除所选 \(selectedCount) 项" : "删除所选项目"
        deletePlaylistItemsMenuItem.isEnabled = selectedCount > 0
    }

    @objc private func deleteSelectedPlaylistItems() {
        let selectedRows = tableView.selectedRowIndexes.filter { playlist.indices.contains($0) }
        guard !selectedRows.isEmpty else { return }

        let deletingCurrentTrack = selectedRows.contains(currentTrackIndex)
        let wasPlaying = player?.isPlaying ?? false
        if deletingCurrentTrack {
            player?.stop()
            timer?.invalidate()
            saveCurrentPosition()
        }

        for row in selectedRows.sorted(by: >) {
            playlist.remove(at: row)
        }

        tableView.reloadData()
        emptyPlaylistLabel.isHidden = !playlist.isEmpty

        if playlist.isEmpty {
            currentTrackIndex = -1
            player = nil
            subtitles.removeAll()
            currentSubtitleIndex = -1
            subtitleURL = nil
            availableSubtitleURLs.removeAll()
            refreshSubtitleTrackPopup(selected: nil)
            nowPlayingLabel.stringValue = "尚未打开音频"
            subtitleStatusLabel.stringValue = "未加载字幕"
            setSubtitleDisplay(fullText: "打开音频后，将在这里显示当前字幕")
            slider.doubleValue = 0
            slider.maxValue = 1
            timeLabel.stringValue = "00:00 / 00:00"
            playButton.title = "▶  播放"
            return
        }

        let removedBeforeCurrent = selectedRows.filter { $0 < currentTrackIndex }.count
        if deletingCurrentTrack {
            let nextIndex = min(selectedRows.min() ?? 0, playlist.count - 1)
            loadTrack(at: nextIndex, autoplay: wasPlaying)
        } else {
            currentTrackIndex -= removedBeforeCurrent
            if playlist.indices.contains(currentTrackIndex) {
                tableView.selectRowIndexes(IndexSet(integer: currentTrackIndex), byExtendingSelection: false)
                tableView.scrollRowToVisible(currentTrackIndex)
            }
        }
    }

    private func loadTrack(at index: Int, autoplay: Bool) {
        guard playlist.indices.contains(index) else { return }
        saveCurrentPosition()
        player?.stop()
        timer?.invalidate()

        let url = playlist[index]
        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.enableRate = true
            newPlayer.delegate = self
            newPlayer.prepareToPlay()
            newPlayer.volume = Float(volumeSlider.doubleValue)
            if let text = speedPopup.selectedItem?.title.replacingOccurrences(of: "×", with: ""), let rate = Float(text) {
                newPlayer.rate = rate
            }
            player = newPlayer
            currentTrackIndex = index
            tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
            tableView.scrollRowToVisible(index)
            nowPlayingLabel.stringValue = "♫  \(url.lastPathComponent)"
            slider.maxValue = newPlayer.duration
            slider.doubleValue = 0
            loadSubtitles(for: url)
            restorePosition(for: url)
            updateUI()
            if autoplay {
                newPlayer.play()
                playButton.title = "Ⅱ  暂停"
                startTimer()
            } else {
                playButton.title = "▶  播放"
            }
        } catch {
            showAlert(title: "无法播放", message: error.localizedDescription)
        }
    }

    private func loadSubtitles(for audioURL: URL) {
        subtitles.removeAll()
        currentSubtitleIndex = -1
        subtitleURL = nil

        availableSubtitleURLs = discoverSubtitleVariants(for: audioURL)
        guard !availableSubtitleURLs.isEmpty else {
            refreshSubtitleTrackPopup(selected: nil)
            subtitleStatusLabel.stringValue = "未找到匹配的 SRT，可手动加入"
            setSubtitleDisplay(fullText: "没有找到匹配字幕\n\n支持：文件名.srt、文件名.en.srt、文件名.bi.srt、文件名.zh.srt 等")
            return
        }

        let preferred = preferredSubtitle(from: availableSubtitleURLs, for: audioURL)
        refreshSubtitleTrackPopup(selected: preferred)
        loadSubtitleFile(preferred)
    }

    private func discoverSubtitleVariants(for audioURL: URL) -> [URL] {
        let folder = audioURL.deletingLastPathComponent()
        let audioStem = audioURL.deletingPathExtension().lastPathComponent
        let normalizedAudio = normalizedStem(audioStem)
        var pool = registeredSubtitleURLs
        if let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for url in files where url.pathExtension.lowercased() == "srt" && !pool.contains(url) { pool.append(url) }
        }

        let matches = pool.filter { url in
            let rawStem = url.deletingPathExtension().lastPathComponent
            let normalizedSubtitle = normalizedStem(rawStem)
            if normalizedSubtitle == normalizedAudio { return true }
            guard normalizedSubtitle.hasPrefix(normalizedAudio) else { return false }
            let rawLower = rawStem.lowercased()
            let audioLower = audioStem.lowercased()
            guard rawLower.hasPrefix(audioLower) else { return true }
            let suffix = String(rawLower.dropFirst(audioLower.count))
            return suffix.isEmpty || suffix.first.map { ".+_-（(".contains($0) } == true
        }
        return matches.sorted { subtitleSortKey($0, audioURL: audioURL) < subtitleSortKey($1, audioURL: audioURL) }
    }

    private func preferredSubtitle(from urls: [URL], for audioURL: URL) -> URL {
        let audioStem = audioURL.deletingPathExtension().lastPathComponent
        if let exact = urls.first(where: { $0.deletingPathExtension().lastPathComponent.compare(audioStem, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            return exact
        }
        if subtitleDisplayMode == .bilingual, let bilingual = urls.first(where: { subtitleKind(for: $0) == "中英双语" }) { return bilingual }
        if subtitleDisplayMode == .stress, let stress = urls.first(where: { subtitleKind(for: $0) == "重音骨架" }) { return stress }
        if subtitleDisplayMode == .flow, let flow = urls.first(where: { subtitleKind(for: $0) == "语流标注" }) { return flow }
        if subtitleDisplayMode == .phonetic, let phonetic = urls.first(where: { subtitleKind(for: $0) == "学习型发音" }) { return phonetic }
        if let english = urls.first(where: { subtitleKind(for: $0) == "英文" }) { return english }
        return urls[0]
    }

    private func subtitleSortKey(_ url: URL, audioURL: URL) -> String {
        let stem = url.deletingPathExtension().lastPathComponent
        let audioStem = audioURL.deletingPathExtension().lastPathComponent
        if stem.compare(audioStem, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame { return "0" }
        switch subtitleKind(for: url) {
        case "英文": return "1" + stem
        case "中英双语": return "2" + stem
        case "重音骨架": return "3" + stem
        case "语流标注": return "4" + stem
        case "学习型发音": return "5" + stem
        case "简体中文": return "6" + stem
        case "GPT润色": return "7" + stem
        case "雅思标注": return "8" + stem
        case "生词版": return "9" + stem
        default: return "9" + stem
        }
    }

    private func subtitleKind(for url: URL) -> String {
        let name = url.deletingPathExtension().lastPathComponent.lowercased()
        if name.contains(".phonetic.en") || name.contains("+phonetic") || name.contains("发音提示") || name.contains("学习型发音") { return "学习型发音" }
        if name.contains(".stress.en") || name.contains("+stress") || name.contains("重音骨架") { return "重音骨架" }
        if name.contains(".flow.en") || name.contains("+flow") || name.contains("语流标注") { return "语流标注" }
        if name.contains(".bi") || name.contains("+bi") || name.contains("bilingual") || name.contains("双语") || name.contains("中英") { return "中英双语" }
        if name.contains(".zh") || name.contains("+zh") || name.contains("zh-cn") || name.contains("简体") || name.contains("中文") { return "简体中文" }
        if name.contains(".gpt") || name.contains("+gpt") || name.contains("润色") || name.contains("校对") { return "GPT润色" }
        if name.contains(".ielts") || name.contains("+ielts") || name.contains("雅思") { return "雅思标注" }
        if name.contains(".words") || name.contains("+words") || name.contains("生词") || name.contains("词汇") { return "生词版" }
        if name.contains(".en") || name.contains("+en") || name.contains("english") || name.contains("英文") { return "英文" }
        return "默认字幕"
    }

    private func subtitleDisplayName(for url: URL) -> String {
        "\(subtitleKind(for: url)) · \(url.lastPathComponent)"
    }

    private func refreshSubtitleTrackPopup(selected: URL?) {
        subtitleTrackPopup.removeAllItems()
        guard !availableSubtitleURLs.isEmpty else {
            subtitleTrackPopup.addItem(withTitle: "字幕版本：无")
            subtitleTrackPopup.isEnabled = false
            return
        }
        subtitleTrackPopup.isEnabled = true
        for url in availableSubtitleURLs { subtitleTrackPopup.addItem(withTitle: subtitleDisplayName(for: url)) }
        if let selected = selected, let index = availableSubtitleURLs.firstIndex(of: selected) {
            subtitleTrackPopup.selectItem(at: index)
        } else {
            subtitleTrackPopup.selectItem(at: 0)
        }
    }

    @objc private func subtitleTrackChanged() {
        let index = subtitleTrackPopup.indexOfSelectedItem
        guard availableSubtitleURLs.indices.contains(index) else { return }
        let wasPlaying = player?.isPlaying ?? false
        let currentTime = player?.currentTime ?? 0
        loadSubtitleFile(availableSubtitleURLs[index])
        player?.currentTime = currentTime
        updateSubtitle(at: currentTime, force: true)
        if wasPlaying { player?.play() }
    }

    @objc func togglePlaylist() {
        isPlaylistVisible.toggle()
        playlistContainer.isHidden = !isPlaylistVisible
        playlistWidthConstraint.constant = isPlaylistVisible ? 285 : 0
        transportCenterConstraint.constant = isPlaylistVisible ? 142.5 : 0
        sentenceCenterConstraint.constant = isPlaylistVisible ? 142.5 : 0
        settingsCenterConstraint.constant = isPlaylistVisible ? 142.5 : 0
        togglePlaylistButton.title = isPlaylistVisible ? "隐藏清单" : "显示清单"
        updateResponsiveControls()
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
    }

    private func normalizedStem(_ value: String) -> String {
        value.precomposedStringWithCanonicalMapping
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ".", with: "")
    }

    private func commonPrefixLength(_ lhs: String, _ rhs: String) -> Int {
        var count = 0
        for (a, b) in zip(lhs, rhs) {
            guard a == b else { break }
            count += 1
        }
        return count
    }

    private func loadSubtitleFile(_ url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let encodings: [String.Encoding] = [.utf8, .utf16, .unicode, .windowsCP1252]
            guard let content = encodings.compactMap({ String(data: data, encoding: $0) }).first else {
                throw NSError(domain: "FirePlayer", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法识别字幕编码"])
            }
            let parsed = SRTParser.parse(content)
            guard !parsed.isEmpty else {
                throw NSError(domain: "FirePlayer", code: 2, userInfo: [NSLocalizedDescriptionKey: "SRT 中没有解析到有效字幕"])
            }
            subtitles = parsed
            subtitleURL = url
            currentSubtitleIndex = -1
            if let index = availableSubtitleURLs.firstIndex(of: url) { subtitleTrackPopup.selectItem(at: index) }
            subtitleStatusLabel.stringValue = "字幕：\(url.lastPathComponent)"
            updateSubtitle(at: player?.currentTime ?? 0, force: true)
        } catch {
            subtitleStatusLabel.stringValue = "字幕读取失败"
            setSubtitleDisplay(fullText: "字幕读取失败：\(error.localizedDescription)")
        }
    }

    @objc private func togglePlay() {
        guard let player = player else { return }
        if player.isPlaying {
            player.pause()
            controlsAutoHideTimer?.invalidate()
            showControls(animated: true)
            playButton.title = "▶  播放"
            timer?.invalidate()
            saveCurrentPosition()
        } else {
            if player.currentTime >= player.duration - 0.1 { player.currentTime = 0 }
            player.play()
            playButton.title = "Ⅱ  暂停"
            startTimer()
            showControlsAndScheduleHide()
        }
    }

    @objc private func previousTrack() {
        guard !playlist.isEmpty else { return }
        let target = currentTrackIndex > 0 ? currentTrackIndex - 1 : playlist.count - 1
        loadTrack(at: target, autoplay: true)
    }

    @objc private func nextTrack() {
        guard !playlist.isEmpty else { return }
        let target = currentTrackIndex + 1 < playlist.count ? currentTrackIndex + 1 : 0
        loadTrack(at: target, autoplay: true)
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in self?.updateUI() }
        if let timer = timer { RunLoop.main.add(timer, forMode: .common) }
    }

    @objc private func seekChanged(_ sender: NSSlider) {
        player?.currentTime = sender.doubleValue
        updateUI(forceSubtitle: true)
    }

    @objc private func volumeChanged(_ sender: NSSlider) { player?.volume = Float(sender.doubleValue) }

    @objc private func speedChanged() {
        guard let text = speedPopup.selectedItem?.title.replacingOccurrences(of: "×", with: ""), let rate = Float(text) else { return }
        player?.rate = rate
    }

    @objc private func previousSubtitle() {
        guard !subtitles.isEmpty else { return }
        let target = max(0, currentSubtitleIndex - 1)
        jumpToSubtitle(target)
    }

    @objc private func nextSubtitle() {
        guard !subtitles.isEmpty else { return }
        let target = min(subtitles.count - 1, max(0, currentSubtitleIndex + 1))
        jumpToSubtitle(target)
    }

    private func jumpToSubtitle(_ index: Int) {
        guard subtitles.indices.contains(index) else { return }
        player?.currentTime = subtitles[index].start + 0.01
        currentSubtitleIndex = -1
        updateUI(forceSubtitle: true)
    }

    @objc private func smallerFont() { fontSize -= 4 }
    @objc private func largerFont() { fontSize += 4 }

    @objc private func chooseColor() {
        let panel = NSColorPanel.shared
        panel.color = subtitleLabel.textColor
        panel.setTarget(self)
        panel.setAction(#selector(colorChanged(_:)))
        panel.orderFront(nil)
    }

    @objc private func colorChanged(_ sender: NSColorPanel) { subtitleLabel.textColor = sender.color }

    private func updateUI(forceSubtitle: Bool = false) {
        guard let player = player else { return }
        slider.doubleValue = player.currentTime
        timeLabel.stringValue = "\(formatTime(player.currentTime)) / \(formatTime(player.duration))"
        updateSubtitle(at: player.currentTime, force: forceSubtitle)
        if !player.isPlaying && player.currentTime >= player.duration - 0.05 {
            playButton.title = "▶  播放"
            timer?.invalidate()
        }
    }

    private func updateSubtitle(at time: TimeInterval, force: Bool = false) {
        guard !subtitles.isEmpty else { return }
        let found = subtitles.lastIndex(where: { $0.start <= time && time <= $0.end })
            ?? subtitles.lastIndex(where: { $0.start <= time })
            ?? 0
        guard force || found != currentSubtitleIndex else { return }
        currentSubtitleIndex = found
        // 只显示当前一句，不再同时显示上一句和下一句，避免黄色、白色字幕看起来重复。
        setSubtitleDisplay(fullText: subtitles[found].text)
    }

    @objc private func toggleSubtitleMode() {
        switch subtitleDisplayMode {
        case .english: subtitleDisplayMode = .bilingual
        case .bilingual: subtitleDisplayMode = .stress
        case .stress: subtitleDisplayMode = .flow
        case .flow: subtitleDisplayMode = .phonetic
        case .phonetic: subtitleDisplayMode = .english
        }
        UserDefaults.standard.set(subtitleDisplayMode.rawValue, forKey: "FirePlayer.subtitleDisplayMode")
        refreshModeButtons()
        if subtitles.indices.contains(currentSubtitleIndex) {
            setSubtitleDisplay(fullText: subtitles[currentSubtitleIndex].text)
        }
    }

    @objc private func cyclePlaybackMode() {
        switch playbackMode {
        case .sequential: playbackMode = .repeatOne
        case .repeatOne: playbackMode = .repeatAll
        case .repeatAll: playbackMode = .sequential
        }
        UserDefaults.standard.set(playbackMode.rawValue, forKey: "FirePlayer.playbackMode")
        refreshModeButtons()
    }

    private func refreshModeButtons() {
        subtitleModeButton.title = "字幕：\(subtitleDisplayMode.rawValue)"
        switch playbackMode {
        case .sequential: playbackModeButton.title = "顺序播放"
        case .repeatOne: playbackModeButton.title = "单曲循环 1"
        case .repeatAll: playbackModeButton.title = "列表循环 ↻"
        }
    }

    private func setSubtitleDisplay(fullText: String) {
        let parts = splitBilingualSubtitle(fullText)
        subtitleLabel.englishText = parts.english
        subtitleLabel.translationText = parts.translation
        subtitleLabel.showsTranslation = subtitleDisplayMode == .bilingual
        subtitleLabel.showsStressSkeleton = subtitleDisplayMode == .stress
        subtitleLabel.showsFlowAnnotation = subtitleDisplayMode == .flow
        subtitleLabel.showsPhoneticGuide = subtitleDisplayMode == .phonetic
    }

    private func splitBilingualSubtitle(_ text: String) -> (english: String, translation: String) {
        let lines = text
            .replacingOccurrences(of: "\\N", with: "\n")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return ("", "") }

        var englishLines: [String] = []
        var translatedLines: [String] = []
        for line in lines {
            if containsCJK(line) {
                translatedLines.append(line)
            } else {
                englishLines.append(line)
            }
        }

        if englishLines.isEmpty {
            return (lines.joined(separator: "\n"), "")
        }
        return (englishLines.joined(separator: "\n"), translatedLines.joined(separator: "\n"))
    }

    private func containsCJK(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF,
                 0x3040...0x30FF, 0xAC00...0xD7AF:
                return true
            default:
                return false
            }
        }
    }

    private func formatTime(_ value: TimeInterval) -> String {
        guard value.isFinite && value >= 0 else { return "00:00" }
        let total = Int(value)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%02d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    private func saveCurrentPosition() {
        guard currentTrackIndex >= 0, playlist.indices.contains(currentTrackIndex), let player = player else { return }
        UserDefaults.standard.set(player.currentTime, forKey: "FirePlayer.position.\(playlist[currentTrackIndex].path)")
    }

    private func restorePosition(for url: URL) {
        let saved = UserDefaults.standard.double(forKey: "FirePlayer.position.\(url.path)")
        if saved > 0, let duration = player?.duration, saved < duration - 2 { player?.currentTime = saved }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        timer?.invalidate()
        switch playbackMode {
        case .repeatOne:
            player.currentTime = 0
            currentSubtitleIndex = -1
            player.play()
            playButton.title = "Ⅱ  暂停"
            startTimer()
        case .repeatAll:
            guard !playlist.isEmpty else { return }
            let next = currentTrackIndex + 1 < playlist.count ? currentTrackIndex + 1 : 0
            loadTrack(at: next, autoplay: true)
        case .sequential:
            if currentTrackIndex + 1 < playlist.count {
                loadTrack(at: currentTrackIndex + 1, autoplay: true)
            } else {
                player.currentTime = 0
                playButton.title = "▶  播放"
                updateUI(forceSubtitle: true)
            }
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int { playlist.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard playlist.indices.contains(row) else { return nil }
        let identifier = NSUserInterfaceItemIdentifier("TrackCell")
        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = identifier
            let text = NSTextField(labelWithString: "")
            text.translatesAutoresizingMaskIntoConstraints = false
            text.lineBreakMode = .byTruncatingMiddle
            text.font = NSFont.systemFont(ofSize: 14, weight: .medium)
            cell.textField = text
            cell.addSubview(text)
            NSLayoutConstraint.activate([
                text.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 10),
                text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                text.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }
        cell.textField?.stringValue = "♫  \(playlist[row].lastPathComponent)"
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !isUpdatingPlaylistSelectionFromContextMenu else { return }
        guard tableView.selectedRowIndexes.count == 1 else { return }
        let row = tableView.selectedRow
        guard playlist.indices.contains(row), row != currentTrackIndex else { return }
        loadTrack(at: row, autoplay: false)
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    deinit {
        saveCurrentPosition()
        timer?.invalidate()
        controlsAutoHideTimer?.invalidate()
        if let monitor = activityEventMonitor { NSEvent.removeMonitor(monitor) }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var controller: PlayerViewController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = PlayerViewController()
        buildMenus()

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1240, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: .darkAqua)
        window.title = "FirePlayer"
        window.minSize = NSSize(width: 980, height: 620)
        window.center()
        window.contentViewController = controller
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildMenus() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "退出 FirePlayer", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let fileItem = NSMenuItem()
        mainMenu.addItem(fileItem)
        let fileMenu = NSMenu(title: "文件")
        let openAudio = NSMenuItem(title: "加入音频文件…", action: #selector(PlayerViewController.openAudio), keyEquivalent: "o")
        openAudio.target = controller
        fileMenu.addItem(openAudio)
        let openFolder = NSMenuItem(title: "加入文件夹…", action: #selector(PlayerViewController.openFolder), keyEquivalent: "f")
        openFolder.keyEquivalentModifierMask = [.command, .shift]
        openFolder.target = controller
        fileMenu.addItem(openFolder)
        let openSubtitle = NSMenuItem(title: "加入 SRT 字幕…", action: #selector(PlayerViewController.openSubtitle), keyEquivalent: "s")
        openSubtitle.keyEquivalentModifierMask = [.command, .shift]
        openSubtitle.target = controller
        fileMenu.addItem(openSubtitle)
        fileMenu.addItem(.separator())
        let clearList = NSMenuItem(title: "清空清单", action: #selector(PlayerViewController.clearPlaylist), keyEquivalent: "k")
        clearList.keyEquivalentModifierMask = [.command, .shift]
        clearList.target = controller
        fileMenu.addItem(clearList)
        fileMenu.addItem(.separator())
        let toggleList = NSMenuItem(title: "显示／隐藏播放清单", action: #selector(PlayerViewController.togglePlaylist), keyEquivalent: "l")
        toggleList.keyEquivalentModifierMask = [.command, .option]
        toggleList.target = controller
        fileMenu.addItem(toggleList)
        fileItem.submenu = fileMenu
        NSApp.mainMenu = mainMenu
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
