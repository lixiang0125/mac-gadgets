import Foundation

enum JSONServiceError: LocalizedError, LocalizedMessageProviding {
    case emptyInput
    case cannotEncode

    var localizationKey: String {
        switch self {
        case .emptyInput: "error.json.emptyInput"
        case .cannotEncode: "error.json.cannotEncode"
        }
    }

    var errorDescription: String? { localizationKey }
}

enum JSONService {
    static func format(_ text: String, sortedKeys: Bool = false) throws -> String {
        guard let inputData = text.data(using: .utf8), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw JSONServiceError.emptyInput
        }

        let object = try JSONSerialization.jsonObject(with: inputData, options: [.fragmentsAllowed])
        var options: JSONSerialization.WritingOptions = [
            .prettyPrinted,
            .withoutEscapingSlashes,
            .fragmentsAllowed
        ]
        if sortedKeys { options.insert(.sortedKeys) }

        let outputData = try JSONSerialization.data(withJSONObject: object, options: options)
        guard let output = String(data: outputData, encoding: .utf8) else {
            throw JSONServiceError.cannotEncode
        }
        return output
    }
}

enum JSONDiffLineKind: String {
    case unchanged
    case added
    case removed
    case modified
}

struct JSONDiffRow: Identifiable, Equatable {
    let id: Int
    let leftLineNumber: Int?
    let leftText: String?
    let rightLineNumber: Int?
    let rightText: String?
    let kind: JSONDiffLineKind
}

struct JSONDiffResult {
    let rows: [JSONDiffRow]
    let addedCount: Int
    let removedCount: Int
    let modifiedCount: Int

    var isIdentical: Bool {
        addedCount == 0 && removedCount == 0 && modifiedCount == 0
    }
}

enum JSONDiffService {
    private static let maximumMatrixCells = 4_000_000

    static func compare(left: String, right: String) -> JSONDiffResult {
        let leftLines = lines(in: left)
        let rightLines = lines(in: right)

        guard leftLines.count * rightLines.count <= maximumMatrixCells else {
            return positionalCompare(leftLines: leftLines, rightLines: rightLines)
        }

        let columnCount = rightLines.count + 1
        var matrix = Array(repeating: 0, count: (leftLines.count + 1) * columnCount)

        if !leftLines.isEmpty && !rightLines.isEmpty {
            for leftIndex in stride(from: leftLines.count - 1, through: 0, by: -1) {
                for rightIndex in stride(from: rightLines.count - 1, through: 0, by: -1) {
                    let index = leftIndex * columnCount + rightIndex
                    if leftLines[leftIndex] == rightLines[rightIndex] {
                        matrix[index] = matrix[(leftIndex + 1) * columnCount + rightIndex + 1] + 1
                    } else {
                        matrix[index] = max(
                            matrix[(leftIndex + 1) * columnCount + rightIndex],
                            matrix[leftIndex * columnCount + rightIndex + 1]
                        )
                    }
                }
            }
        }

        var rows: [JSONDiffRow] = []
        var leftIndex = 0
        var rightIndex = 0
        var addedCount = 0
        var removedCount = 0
        var modifiedCount = 0

        func appendRow(
            leftNumber: Int?,
            leftText: String?,
            rightNumber: Int?,
            rightText: String?,
            kind: JSONDiffLineKind
        ) {
            rows.append(JSONDiffRow(
                id: rows.count,
                leftLineNumber: leftNumber,
                leftText: leftText,
                rightLineNumber: rightNumber,
                rightText: rightText,
                kind: kind
            ))
        }

        while leftIndex < leftLines.count || rightIndex < rightLines.count {
            if leftIndex < leftLines.count,
               rightIndex < rightLines.count,
               leftLines[leftIndex] == rightLines[rightIndex] {
                appendRow(
                    leftNumber: leftIndex + 1,
                    leftText: leftLines[leftIndex],
                    rightNumber: rightIndex + 1,
                    rightText: rightLines[rightIndex],
                    kind: .unchanged
                )
                leftIndex += 1
                rightIndex += 1
                continue
            }

            var removed: [(number: Int, text: String)] = []
            var added: [(number: Int, text: String)] = []

            while leftIndex < leftLines.count || rightIndex < rightLines.count {
                if leftIndex < leftLines.count,
                   rightIndex < rightLines.count,
                   leftLines[leftIndex] == rightLines[rightIndex] {
                    break
                }

                if rightIndex >= rightLines.count {
                    removed.append((leftIndex + 1, leftLines[leftIndex]))
                    leftIndex += 1
                } else if leftIndex >= leftLines.count {
                    added.append((rightIndex + 1, rightLines[rightIndex]))
                    rightIndex += 1
                } else {
                    let skipLeft = matrix[(leftIndex + 1) * columnCount + rightIndex]
                    let skipRight = matrix[leftIndex * columnCount + rightIndex + 1]
                    if skipLeft >= skipRight {
                        removed.append((leftIndex + 1, leftLines[leftIndex]))
                        leftIndex += 1
                    } else {
                        added.append((rightIndex + 1, rightLines[rightIndex]))
                        rightIndex += 1
                    }
                }
            }

            let pairedCount = max(removed.count, added.count)
            for index in 0..<pairedCount {
                let oldLine = removed.indices.contains(index) ? removed[index] : nil
                let newLine = added.indices.contains(index) ? added[index] : nil
                let kind: JSONDiffLineKind
                if oldLine != nil && newLine != nil {
                    kind = .modified
                    modifiedCount += 1
                } else if oldLine != nil {
                    kind = .removed
                    removedCount += 1
                } else {
                    kind = .added
                    addedCount += 1
                }
                appendRow(
                    leftNumber: oldLine?.number,
                    leftText: oldLine?.text,
                    rightNumber: newLine?.number,
                    rightText: newLine?.text,
                    kind: kind
                )
            }
        }

        return JSONDiffResult(
            rows: rows,
            addedCount: addedCount,
            removedCount: removedCount,
            modifiedCount: modifiedCount
        )
    }

    private static func lines(in string: String) -> [String] {
        string.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    private static func positionalCompare(leftLines: [String], rightLines: [String]) -> JSONDiffResult {
        let rowCount = max(leftLines.count, rightLines.count)
        var rows: [JSONDiffRow] = []
        var added = 0
        var removed = 0
        var modified = 0

        for index in 0..<rowCount {
            let left = leftLines.indices.contains(index) ? leftLines[index] : nil
            let right = rightLines.indices.contains(index) ? rightLines[index] : nil
            let kind: JSONDiffLineKind
            if left == right {
                kind = .unchanged
            } else if left == nil {
                kind = .added
                added += 1
            } else if right == nil {
                kind = .removed
                removed += 1
            } else {
                kind = .modified
                modified += 1
            }
            rows.append(JSONDiffRow(
                id: index,
                leftLineNumber: left == nil ? nil : index + 1,
                leftText: left,
                rightLineNumber: right == nil ? nil : index + 1,
                rightText: right,
                kind: kind
            ))
        }

        return JSONDiffResult(rows: rows, addedCount: added, removedCount: removed, modifiedCount: modified)
    }
}
