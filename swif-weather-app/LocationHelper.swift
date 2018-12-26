//
//  Created by Mehdi.
//  Copyright © 2018 Your Company. All rights reserved.
//  

import Foundation
import CoreLocation
import PromiseKit

class LocationHelper {
    let coder = CLGeocoder()
    
    /**
     * CLLocationManager.requestLocation() returns a promise of the current location.
     * Once the current location is available, your chain sends it to CLGeocoder.reverseGeocode(location:), which also returns a Promise to provide the reverse-coded location.
     */
    func getLocation() -> Promise<CLPlacemark> {
        // return brokenPromise()
        return CLLocationManager.requestLocation().lastValue.then { location in
            return self.coder.reverseGeocode(location: location).firstValue
        }
    }
    
    func searchForPlacemark(text: String) -> Promise<CLPlacemark> {
        return coder.geocode(text).firstValue
    }

}
