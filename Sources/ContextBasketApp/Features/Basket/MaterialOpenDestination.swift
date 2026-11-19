import Foundation

enum MaterialOpenDestination: Equatable {
    case inApp, sourceFile(URL), website(URL)

    static func resolve(_ item: Material) throws -> MaterialOpenDestination {
        switch item.content {
        case .reference(let url, _):
            guard url.isFileURL, FileManager.default.fileExists(atPath: url.path) else { throw MaterialOpenError.missingSource }
            return .sourceFile(url)
        case .link(let text):
            guard let url = DropReader.webURL(text) else { throw MaterialOpenError.invalidLink }
            return .website(url)
        case .pending, .text, .copy:
            return .inApp
        }
    }
}

enum MaterialOpenError: LocalizedError {
    case missingSource, invalidLink
    var errorDescription: String? {
        switch self {
        case .missingSource: return "找不到源文件，请重新添加原文件地址。"
        case .invalidLink: return "这个网址无法打开，请检查链接。"
        }
    }
}
