//
//  Editor.swift
//
//
//  Created by Quentin Eude on 10/03/2021.
//
import Combine

#if os(iOS)
  import UIKit
#elseif os(macOS)
  import AppKit
#endif

struct EditedText: Equatable {
  let string: String
  let editedRange: NSRange
}

public class Storage: NSTextStorage {
  public var theme: Theme? {
    didSet {
      self.beginEditing()
      self.applyStyles()
      self.endEditing()
    }
  }
  public var markdowner: (String, Int) -> [MarkdownNode] = { _,_  in [] }
  public var applyMarkdown: (MarkdownNode) -> [NSAttributedString.Key: Any] = { _ in [:] }
  public var applyBody: () -> [NSAttributedString.Key: Any] = { [:] }
  public var hideMarkdownSymbols: Bool = false
  var cancellables = Set<AnyCancellable>()
  let subj = PassthroughSubject<EditedText, Never>()

  var backingStore = NSTextStorage()

  override public var string: String {
    return backingStore.string
  }

  override public init() {
    super.init()
  }

  override public init(attributedString attrStr: NSAttributedString) {
    super.init(attributedString: attrStr)
    backingStore.setAttributedString(attrStr)
  }

  required public init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  required public init(itemProviderData data: Data, typeIdentifier: String) throws {
    fatalError("init(itemProviderData:typeIdentifier:) has not been implemented")
  }

  #if os(macOS)
    required public init?(pasteboardPropertyList propertyList: Any, ofType type: String) {
      fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }

    required public init?(
      pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType
    ) {
      fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
  #endif

  override public func attributes(
    at location: Int, longestEffectiveRange range: NSRangePointer?, in rangeLimit: NSRange
  ) -> [NSAttributedString.Key: Any] {
    return backingStore.attributes(at: location, longestEffectiveRange: range, in: rangeLimit)
  }

  override public func replaceCharacters(in range: NSRange, with str: String) {
    self.beginEditing()
    backingStore.replaceCharacters(in: range, with: str)
    let len = (str as NSString).length
    let change = len - range.length
    self.edited([.editedCharacters], range: range, changeInLength: change)
    self.endEditing()
  }

  public override func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
    self.beginEditing()
    backingStore.setAttributes(attrs, range: range)
    self.edited(.editedAttributes, range: range, changeInLength: 0)
    self.endEditing()
  }

  public override func attributes(at location: Int, effectiveRange range: NSRangePointer?)
    -> [NSAttributedString.Key: Any] {
    return backingStore.attributes(at: location, effectiveRange: range)
  }

  func applyStyles(editedRange: NSRange? = nil) {
    let paragraphNSRange = self.string.paragraph(for: editedRange)
    let paragraphRange = Range(paragraphNSRange, in: self.string)
    let paragraph: String
    if let paragraphRange = paragraphRange {
      paragraph = String(self.string[paragraphRange])
    } else {
      paragraph = self.string
    }
    let md = markdowner(paragraph, paragraphNSRange.lowerBound)
    
    // Begin batch editing to prevent flickering
    beginEditing()
    
    setAttributes(applyBody(), range: paragraphNSRange)
    
    md.forEach { markdownNode in
      // Apply normal markdown styling to the entire range
      addAttributes(applyMarkdown(markdownNode), range: markdownNode.range)
      
      // If hideMarkdownSymbols is enabled, hide symbol ranges
      if hideMarkdownSymbols, let theme = theme {
        let symbolRanges = Theme.getSymbolRanges(for: markdownNode, in: self.string)
        for symbolRange in symbolRanges {
          var hiddenAttributes: [NSAttributedString.Key: Any] = [:]
          
          // Use a very small font size to minimize space usage
          #if os(iOS)
          hiddenAttributes[.font] = UIFont.systemFont(ofSize: 0.1)
          #else
          hiddenAttributes[.font] = NSFont.systemFont(ofSize: 0.1)
          #endif
          
          // Make the color match the background to hide the tiny text
          hiddenAttributes[.foregroundColor] = theme.backgroundColor
          
          // Remove any existing background color to avoid visual artifacts
          hiddenAttributes[.backgroundColor] = theme.backgroundColor
          
          addAttributes(hiddenAttributes, range: symbolRange)
        }
      }
    }
    
    // End batch editing to apply all changes at once
    endEditing()
  }
}
