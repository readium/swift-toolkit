import Foundation

struct OPDSCatalog: Identifiable {
    var id: URL { url }
    
    let title: String
    let url: URL
    
    var toDictionary: [String: String] {
        [
            "title": title,
            "url": url.absoluteString
        ]
    }
}

extension OPDSCatalog {
    init?(dictionary: [String: String]) {
        guard
            let title = dictionary["title"],
            let url = URL(string: dictionary["url"] ?? "")
        else { return nil }
        
        self.title = title
        self.url = url
    }
}
