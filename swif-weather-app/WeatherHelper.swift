//
//  Created by Mehdi.
//  Copyright © 2018 Your Company. All rights reserved.
//  

import Foundation
import PromiseKit

private let appID = "put-your-api-key-here"

class WeatherHelper {
    
    struct WeatherInfo: Codable {
        let main: Temperature
        let weather: [Weather]
        var name: String = "Error: invalid jsonDictionary! Verify your appID is correct"
    }
    
    struct Weather: Codable {
        let icon: String
        let description: String
    }
    
    struct Temperature: Codable {
        let temp: Double
    }
    
    func getWeatherTheOldFashionedWay(coordinate: CLLocationCoordinate2D, completion: @escaping (WeatherInfo?, Error?) -> Void) {
        let urlString = "https://api.openweathermap.org/data/2.5/weather?lat=\(coordinate.latitude)&lon=\(coordinate.longitude)&appid=\(appID)"
        
        guard let url = URL(string: urlString) else {
            preconditionFailure("Failed creating API URL - Make sure you set your OpenWeather API Key")
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data,
                let result = try? JSONDecoder().decode(WeatherInfo.self, from: data) else {
                    completion(nil, error)
                    return
            }
            
            completion(result, nil)
            }.resume()
    }
    
    /**
     * PromiseKit provides a new overload of URLSession.dataTask(_:with:) that returns a specialized Promise representing a URL request. Note that the data promise automatically starts its underlying data task.
     * Next, PromiseKit’s compactMap is chained to decode the data as a WeatherInfo object and return it from the closure. compactMap takes care of wrapping this result in a Promise for you, so you can keep chaining additional promise-related methods.
     */
    func getWeather(
        atLatitude latitude: Double,
        longitude: Double
        ) -> Promise<WeatherInfo> {
        let urlString = "https://api.openweathermap.org/data/2.5/weather?lat=" +
        "\(latitude)&lon=\(longitude)&appid=\(appID)"
        let url = URL(string: urlString)!
        
        return firstly {
            URLSession.shared.dataTask(.promise, with: url)
            }.compactMap {
                return try JSONDecoder().decode(WeatherInfo.self, from: $0.data)
        }
    }
    
    /**
     * *********** RECOVER closure
     */
    func getIcon(named iconName: String) -> Promise<UIImage> {
        return Promise<UIImage> {
            // try to get the weather icon from file location first
            getFile(named: iconName, completion: $0.resolve)
            }
            .recover { _ in
                // if not possible from file then from network
                self.getIconFromNetwork(named: iconName)
        }
    }
    
    /**
     * Here, you build a UIImage from the loaded Data on a background queue by supplying a DispatchQueue via the on parameter to then(on:execute:). PromiseKit then performs the then block on provided queue.
     */
    func getIconFromNetwork(named iconName: String) -> Promise<UIImage> {
        let urlString = "https://openweathermap.org/img/w/\(iconName).png"
        let url = URL(string: urlString)!
        
        return firstly {
            URLSession.shared.dataTask(.promise, with: url)
            }
            .then(on: DispatchQueue.global(qos: .background)) { urlResponse in
                return Promise {
                    // after download save as file
                    self.saveFile(named: iconName, data: urlResponse.data, completion: $0.resolve)
                    }
                    .then(on: DispatchQueue.global(qos: .background)) {
                        return Promise.value(UIImage(data: urlResponse.data)!)
                }
        }
    }


    private func saveFile(named: String, data: Data, completion: @escaping (Error?) -> Void) {
        guard let path = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent(named+".png") else { return }
        
        DispatchQueue.global(qos: .background).async {
            do {
                try data.write(to: path)
                print("Saved image to: " + path.absoluteString)
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }
    
    private func getFile(named: String, completion: @escaping (UIImage?, Error?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            if let path = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent(named+".png"),
                let data = try? Data(contentsOf: path),
                let image = UIImage(data: data) {
                DispatchQueue.main.async { completion(image, nil) }
            } else {
                let error = NSError(domain: "swift-weather-app",
                                    code: 0,
                                    userInfo: [NSLocalizedDescriptionKey: "Image file '\(named)' not found."])
                DispatchQueue.main.async { completion(nil, error) }
            }
        }
    }
}
