//
//  Network.swift
//  PoloLifestyleMagazine
//
//  Created by MacbookM3 on 12/02/25.
//

import Foundation
import Network

func isInternetAvailable() -> Bool {
    let monitor = NWPathMonitor()
    let queue = DispatchQueue.global(qos: .background)
    var isConnected = false
    
    monitor.pathUpdateHandler = { path in
        isConnected = path.status == .satisfied
    }
    
    monitor.start(queue: queue)
    
    // Small delay to allow status update
    sleep(1)
    
    monitor.cancel()
    return isConnected
}
