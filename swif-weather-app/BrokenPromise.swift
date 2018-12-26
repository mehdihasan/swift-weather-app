//
//  Created by Mehdi.
//  Copyright © 2018 Your Company. All rights reserved.
//  

import Foundation
import PromiseKit

/**
 *
 * This returns a new generic Promise, which is the primary class provided by PromiseKit. Its constructor takes a simple execution block with one parameter, seal, which supports one of three possible outcomes:
 * seal.fulfill: Fulfill the promise when the desired value is ready.
 * seal.reject: Reject the promise with an error, if one occurred.
 * seal.resolve: Resolve the promise with either an error or a value. In a way, `fulfill` and `reject` are prettified helpers around `resolve`.
 */
func brokenPromise<T>(method: String = #function) -> Promise<T> {
    return Promise<T>() { seal in
        let err = NSError(
            domain: "swift-weather-app",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: "'\(method)' not yet implemented."])
        seal.reject(err)
    }
}
