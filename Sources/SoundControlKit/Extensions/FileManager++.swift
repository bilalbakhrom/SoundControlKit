//
//  FileManager++.swift
//
//
//  Created by Bilal Bakhrom on 2023-11-19.
//

import Foundation

extension FileManager {
    var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func urlInDocumentsDirectory(named: String) -> URL {
        return documentsDirectory.appendingPathComponent(named)
    }
}
