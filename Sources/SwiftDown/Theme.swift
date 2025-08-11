//
//  Theme.swift
//
//
//  Created by Quentin Eude on 10/03/2021.
//

#if os(iOS)
  import UIKit
#elseif os(macOS)
  import AppKit
#endif

public struct Theme {
  // MARK: - BuildIn
  public enum BuiltIn: String {
    case defaultDark = "default-dark"
    case defaultLight = "default-light"

    public func theme() -> Theme {
      return Theme(self.rawValue)
    }
  }

  var backgroundColor: UniversalColor = UniversalColor.clear
  var tintColor: UniversalColor = UniversalColor.blue
  var cursorColor: UniversalColor = UniversalColor.blue
  var styles: [MarkdownNode.MarkdownType: Style] = [:]

  public init(_ name: String) {
    self.init()
    let bundle = Bundle.module

    guard let path = bundle.path(forResource: "Themes/\(name)", ofType: "json") else {
      print("[SwiftDown] Unable to load your theme file.")
      assertionFailure()
      return
    }

    self.init(themePath: path)
  }

  public init(themePath: String) {
    self.init()
    if let data = convertFile(themePath) {
      configure(data)
    }
  }

  public init() {
    MarkdownNode.MarkdownType.allCases.forEach { type in
      styles[type] = Style()
    }
  }

  mutating func configure(_ data: [String: AnyObject]) {
    data.forEach { key, value in
      switch ConfigProperty.from(rawValue: key) {
      case .editor:
        if let editorStyles = value as? [String: String] {
          configureEditor(editorStyles)
        }
      case .styles:
        if let styles = value as? [String: AnyObject] {
          configureStyles(styles)
        }
      case .unknown:
        break
      }
    }
  }

  mutating private func configureStyles(_ attributes: [String: AnyObject]) {
    attributes.forEach { key, value in
      if let value = value as? [String: AnyObject],
        let style = configureStyle(value as [String: AnyObject]),
        let mdType = MarkdownNode.MarkdownType.from(string: key) {
        styles[mdType] = Style(attributes: style)
      }
    }
  }

  mutating private func configureStyle(_ attributes: [String: AnyObject]) -> [NSAttributedString
    .Key: Any]? {
    var stringAttributes: [NSAttributedString.Key: Any] = [:]
    var fontSize: CGFloat = 15
    var font: UniversalFont? = UniversalFont.systemFont(ofSize: fontSize)
    var fontTraits = ""
    attributes.forEach { key, value in
      switch StyleConfigProperty.from(rawValue: key) {
      case .color:
        if let color = value as? String {
          stringAttributes[NSAttributedString.Key.foregroundColor] = UniversalColor(
            hexString: color)
        }
      case .font:
        if let fontName = value as? String, fontName != "System" {
          font = UniversalFont(name: fontName, size: fontSize) ?? font
        }
      case .size:
        if let size = value as? CGFloat {
          fontSize = size
        }
      case .traits:
        if let traits = value as? String {
          fontTraits = traits
        }
      case .unknown:
        break
      }
    }
    font = font?.with(traits: fontTraits, size: fontSize)
    stringAttributes[NSAttributedString.Key.font] = font
    return stringAttributes
  }

  mutating private func configureEditor(_ attributes: [String: String]) {
    attributes.forEach { key, value in
      switch EditorConfigProperty.from(rawValue: key) {
      case .backgroundColor:
        backgroundColor = UniversalColor(hexString: value)
      case .tintColor:
        tintColor = UniversalColor(hexString: value)
      case .cursorColor:
        cursorColor = UniversalColor(hexString: value)
      case .unknown:
        break
      }
    }
  }

  private func convertFile(_ path: String) -> [String: AnyObject]? {
    do {
      let json = try String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
      if let data = json.data(using: .utf8) {
        do {
          return try JSONSerialization.jsonObject(with: data, options: []) as? [String: AnyObject]
        } catch let error as NSError {
          print(error)
        }
      }
    } catch let error as NSError {
      print(error)
    }

    return nil
  }

  // MARK: - Static methods
  static func applyMarkdown(markdown: MarkdownNode, with theme: Theme, hideSymbols: Bool = false) -> [NSAttributedString.Key:
    Any] {
    guard let attributes = theme.styles[markdown.type]?.attributes else { return [:] }
    return attributes
  }
  
  static func getSymbolRanges(for markdown: MarkdownNode, in text: String) -> [NSRange] {
    let range = markdown.range
    guard range.location + range.length <= text.count else { return [] }
    
    let start = text.index(text.startIndex, offsetBy: range.location)
    let end = text.index(start, offsetBy: range.length)
    let nodeText = String(text[start..<end])
    
    var symbolRanges: [NSRange] = []
    let baseLocation = range.location
    
    switch markdown.type {
    case .bold:
      // **text** - hide the ** at start and end
      if nodeText.hasPrefix("**") {
        symbolRanges.append(NSRange(location: baseLocation, length: 2))
      }
      if nodeText.hasSuffix("**") && nodeText.count >= 4 {
        symbolRanges.append(NSRange(location: baseLocation + nodeText.count - 2, length: 2))
      }
      
    case .italic:
      // *text* - hide the * at start and end  
      if nodeText.hasPrefix("*") && !nodeText.hasPrefix("**") {
        symbolRanges.append(NSRange(location: baseLocation, length: 1))
      }
      if nodeText.hasSuffix("*") && !nodeText.hasSuffix("**") && nodeText.count >= 2 {
        symbolRanges.append(NSRange(location: baseLocation + nodeText.count - 1, length: 1))
      }
      
    case .header1, .header2, .header3, .header4, .header5, .header6:
      // # text, ## text, etc. - hide the # symbols and following space
      let headerLevel = markdown.headingLevel
      if nodeText.hasPrefix(String(repeating: "#", count: headerLevel)) {
        let symbolCount = headerLevel + (nodeText.dropFirst(headerLevel).hasPrefix(" ") ? 1 : 0)
        symbolRanges.append(NSRange(location: baseLocation, length: symbolCount))
      }
      
    case .code:
      // `code` - hide the ` at start and end
      if nodeText.hasPrefix("`") {
        symbolRanges.append(NSRange(location: baseLocation, length: 1))
      }
      if nodeText.hasSuffix("`") && nodeText.count >= 2 {
        symbolRanges.append(NSRange(location: baseLocation + nodeText.count - 1, length: 1))
      }
      
    case .link:
      // [text](url) - hide the []() symbols
      if let openBracket = nodeText.firstIndex(of: "[") {
        let openPos = nodeText.distance(from: nodeText.startIndex, to: openBracket)
        symbolRanges.append(NSRange(location: baseLocation + openPos, length: 1))
      }
      if let closeBracket = nodeText.firstIndex(of: "]") {
        let closePos = nodeText.distance(from: nodeText.startIndex, to: closeBracket)
        symbolRanges.append(NSRange(location: baseLocation + closePos, length: 1))
      }
      if let openParen = nodeText.firstIndex(of: "(") {
        let openPos = nodeText.distance(from: nodeText.startIndex, to: openParen)
        symbolRanges.append(NSRange(location: baseLocation + openPos, length: 1))
      }
      if let closeParen = nodeText.lastIndex(of: ")") {
        let closePos = nodeText.distance(from: nodeText.startIndex, to: closeParen)
        symbolRanges.append(NSRange(location: baseLocation + closePos, length: 1))
      }
      
    case .image:
      // ![text](url) - hide the ![]() symbols
      if nodeText.hasPrefix("!") {
        symbolRanges.append(NSRange(location: baseLocation, length: 1))
      }
      if let openBracket = nodeText.firstIndex(of: "[") {
        let openPos = nodeText.distance(from: nodeText.startIndex, to: openBracket)
        symbolRanges.append(NSRange(location: baseLocation + openPos, length: 1))
      }
      if let closeBracket = nodeText.firstIndex(of: "]") {
        let closePos = nodeText.distance(from: nodeText.startIndex, to: closeBracket)
        symbolRanges.append(NSRange(location: baseLocation + closePos, length: 1))
      }
      if let openParen = nodeText.firstIndex(of: "(") {
        let openPos = nodeText.distance(from: nodeText.startIndex, to: openParen)
        symbolRanges.append(NSRange(location: baseLocation + openPos, length: 1))
      }
      if let closeParen = nodeText.lastIndex(of: ")") {
        let closePos = nodeText.distance(from: nodeText.startIndex, to: closeParen)
        symbolRanges.append(NSRange(location: baseLocation + closePos, length: 1))
      }
      
    case .quote:
      // > text - hide the > and following space
      if nodeText.hasPrefix(">") {
        let symbolCount = 1 + (nodeText.dropFirst(1).hasPrefix(" ") ? 1 : 0)
        symbolRanges.append(NSRange(location: baseLocation, length: symbolCount))
      }
      
    default:
      break
    }
    
    return symbolRanges
  }

  static func applyBody(with theme: Theme) -> [NSAttributedString.Key: Any] {
    guard let attributes = theme.styles[MarkdownNode.MarkdownType.body]?.attributes else {
      return [:]
    }
    return attributes
  }
}
