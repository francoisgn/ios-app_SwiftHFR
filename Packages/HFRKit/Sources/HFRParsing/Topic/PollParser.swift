import Foundation
import HFRModels
import SwiftSoup

/// Reads the poll of a topic page (HFR-PROTOCOL §3.1 "Poll vote", E10).
///
/// Only the **voting form** is handled: it is the one state proven by captures (`R32a` logged out, `R32b` logged in,
/// not voted). Closed polls, polls already voted in and result bars wait for capture R33 (see `docs/lots/LOT-026-poll-parser.md`);
/// a poll block in any of those shapes is refused with a typed error instead of being guessed.
///
/// The block is `<div class="sondage">` inside `<form method="post" action="/user/vote.php?config=hfr.inc">`;
/// legacy took the first element whose class is exactly `sondage` (`ObjCTopicPageWorker.m:159-162`) and parsed it with regexes
/// (`PollData.swift:104-250`).
public enum PollParser {
    /// The voting poll of a topic page or of a `div.sondage` fragment; nil when the page has no `div.sondage`.
    ///
    /// - `question`: text of the `s2` element (`<b class="s2">`), whitespace collapsed.
    /// - options: one per `<li>` holding a radio input and a `<label>`, `id` = 1-based position, required to equal the radio
    ///   `value` (captured values are 1...N in order), `fieldName` = the input's `name` (`reponse`).
    /// - `hiddenFields`: every `<input type="hidden">` **inside** the block, as legacy (`hash_check` is empty when logged out). The form
    ///   also carries a first `hash_check` outside the block, with the same value.
    /// - `footer` is nil and `maxChoices` 1: no captured poll shows a footer or a multi-choice hint.
    /// - Throws: `missingElement` when the block has no question or no answer row (results, closed or voted polls: pending R33),
    ///   `invalidValue` when an answer input is not a radio button (multi-choice polls: pending capture) or its `value`
    ///   is not its position.
    public static func poll(in html: String) throws(ParsingError) -> Poll? {
        let document = try HTMLDocumentLoader.document(from: html)
        guard let block = document.firstDescendant(matching: .classToken("sondage")) else { return nil }
        let question = try block.requiredDescendant(matching: .classToken("s2"))
        let options = try options(in: block)
        return Poll(
            question: cleanedText(of: question),
            footer: nil,
            maxChoices: 1,
            kind: .votable(options: options, hiddenFields: hiddenFields(in: block))
        )
    }

    // MARK: - Implementation

    /// Answer rows: `<li><input type="radio" value="N" id="sondN" name="reponse"><label for="sondN">text</label></li>`.
    private static func options(in block: Element) throws(ParsingError) -> [PollOption] {
        var options: [PollOption] = []
        for row in descendants(tagged: "li", in: block) {
            guard let input = descendants(tagged: "input", in: row).first else { continue }
            guard (try? input.attr("type"))?.lowercased() == "radio" else { throw .invalidValue(field: "poll answer input type") }
            let name = try input.requiredAttribute("name")
            guard let label = descendants(tagged: "label", in: row).first else { throw .missingElement("label in poll answer") }
            // The server receives the radio `value`, so it must be the position the model advertises as `id`.
            let position = options.count + 1
            guard let value = try? input.attr("value"), HFRURL.positiveInteger(value) == position else {
                throw .invalidValue(field: "poll answer value")
            }
            options.append(PollOption(id: position, text: cleanedText(of: label), fieldName: name))
        }
        guard !options.isEmpty else { throw .missingElement("li input in poll block") }
        return options
    }

    /// `name` to `value` of the hidden inputs of the block; a repeated name keeps the last value, as legacy.
    private static func hiddenFields(in block: Element) -> [String: String] {
        var fields: [String: String] = [:]
        for input in descendants(tagged: "input", in: block) where (try? input.attr("type"))?.lowercased() == "hidden" {
            guard let name = try? input.attr("name"), !name.isEmpty else { continue }
            fields[name] = (try? input.attr("value")) ?? ""
        }
        return fields
    }

    private static func descendants(tagged tag: String, in element: Element) -> [Element] {
        ((try? element.getElementsByTag(tag))?.array() ?? []).filter { $0 !== element }
    }

    /// Visible text with non-breaking spaces turned into spaces and runs of whitespace collapsed (legacy `cleanedPollText`).
    private static func cleanedText(of element: Element) -> String {
        let text = ((try? element.text()) ?? "").replacing("\u{00A0}", with: " ")
        return text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
