#if os(iOS)
//
//  HighlightedTextEditor.UIKit.swift
//
//
//  Created by Kyle Nazario on 5/26/21.
//

import SwiftUI
import UIKit

public struct HighlightedTextEditor: UIViewRepresentable, HighlightingTextEditor {
    public struct Internals {
        public let textView: SystemTextView
        public let scrollView: SystemScrollView?
    }

    @Binding var text: String {
        didSet {
            onTextChange?(text)
        }
    }

    let highlightRules: [HighlightRule]

    private(set) var onEditingChanged: OnEditingChangedCallback?
    private(set) var onCommit: OnCommitCallback?
    private(set) var onTextChange: OnTextChangeCallback?
    private(set) var onSelectionChange: OnSelectionChangeCallback?
    private(set) var introspect: IntrospectCallback?

    public init(
        text: Binding<String>,
        highlightRules: [HighlightRule]
    ) {
        _text = text
        self.highlightRules = highlightRules
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        updateTextViewModifiers(textView)
        runIntrospect(textView)

        return textView
    }

    public func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.isScrollEnabled = false
        context.coordinator.updatingUIView = true

        let highlightedText = HighlightedTextEditor.getHighlightedText(
            text: text,
            highlightRules: highlightRules
        )

        if let range = uiView.markedTextNSRange {
            uiView.setAttributedMarkedText(highlightedText, selectedRange: range)
        } else {
            uiView.attributedText = highlightedText
        }
        updateTextViewModifiers(uiView)
        runIntrospect(uiView)
        uiView.isScrollEnabled = true
        if let selectedTextRange = context.coordinator.selectedTextRange,
           let text = uiView.text,
           selectedTextRange.start < text.endIndex,
           selectedTextRange.end <= text.endIndex {
            
            // Convert Swift String.Index to UITextInput's text position
            if let startPosition = uiView.position(from: uiView.beginningOfDocument, offset: text.distance(from: text.startIndex, to: selectedTextRange.start)),
               let endPosition = uiView.position(from: uiView.beginningOfDocument, offset: text.distance(from: text.startIndex, to: selectedTextRange.end)) {
        
                // Check again to be safe
                if let newSelectedRange = uiView.textRange(from: startPosition, to: endPosition) {
                    uiView.selectedTextRange = newSelectedRange
                }
            }
        } else {
            // Handle the case where the range is invalid.
            // This could be a print statement for debugging, or you could set the cursor to the end of the text.
            print("Invalid selectedTextRange, cannot restore selection.")
            if let newPosition = uiView.position(from: uiView.endOfDocument, offset: 0) {
                uiView.selectedTextRange = uiView.textRange(from: newPosition, to: newPosition)
            }
        }
        context.coordinator.updatingUIView = false
    }

    private func runIntrospect(_ textView: UITextView) {
        guard let introspect = introspect else { return }
        let internals = Internals(textView: textView, scrollView: nil)
        introspect(internals)
    }

    private func updateTextViewModifiers(_ textView: UITextView) {
        // BUGFIX #19: https://stackoverflow.com/questions/60537039/change-prompt-color-for-uitextfield-on-mac-catalyst
        let textInputTraits = textView.value(forKey: "textInputTraits") as? NSObject
        textInputTraits?.setValue(textView.tintColor, forKey: "insertionPointColor")
    }

    public final class Coordinator: NSObject, UITextViewDelegate {
        var parent: HighlightedTextEditor
        var selectedTextRange: UITextRange?
        var updatingUIView = false

        init(_ markdownEditorView: HighlightedTextEditor) {
            self.parent = markdownEditorView
        }

        public func textViewDidChange(_ textView: UITextView) {
            // For Multistage Text Input
            guard textView.markedTextRange == nil else { return }

            parent.text = textView.text
            selectedTextRange = textView.selectedTextRange
        }

        public func textViewDidChangeSelection(_ textView: UITextView) {
            guard let onSelectionChange = parent.onSelectionChange,
                  !updatingUIView
            else { return }
            selectedTextRange = textView.selectedTextRange
            onSelectionChange([textView.selectedRange])
        }

        public func textViewDidBeginEditing(_ textView: UITextView) {
            parent.onEditingChanged?()
        }

        public func textViewDidEndEditing(_ textView: UITextView) {
            parent.onCommit?()
        }
    }
}

public extension HighlightedTextEditor {
    func introspect(callback: @escaping IntrospectCallback) -> Self {
        var new = self
        new.introspect = callback
        return new
    }

    func onSelectionChange(_ callback: @escaping (_ selectedRange: NSRange) -> Void) -> Self {
        var new = self
        new.onSelectionChange = { ranges in
            guard let range = ranges.first else { return }
            callback(range)
        }
        return new
    }

    func onCommit(_ callback: @escaping OnCommitCallback) -> Self {
        var new = self
        new.onCommit = callback
        return new
    }

    func onEditingChanged(_ callback: @escaping OnEditingChangedCallback) -> Self {
        var new = self
        new.onEditingChanged = callback
        return new
    }

    func onTextChange(_ callback: @escaping OnTextChangeCallback) -> Self {
        var new = self
        new.onTextChange = callback
        return new
    }
}
#endif
