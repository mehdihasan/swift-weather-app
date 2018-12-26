//
//  Created by Mehdi.
//  Copyright © 2018 Your Company. All rights reserved.
//  

import UIKit
import PromiseKit
import CoreLocation

private let errorColor = UIColor(red: 0.96, green: 0.667, blue: 0.690, alpha: 1)
private let oneHour: TimeInterval = 3600 // Seconds per hour
private let randomCities = [("Tokyo", "JP", 35.683333, 139.683333),
                            ("Jakarta", "ID", -6.2, 106.816667),
                            ("Delhi", "IN", 28.61, 77.23),
                            ("Manila", "PH", 14.58, 121),
                            ("São Paulo", "BR", -23.55, -46.633333)]

class ViewController: UIViewController {

    @IBOutlet private var placeLabel: UILabel!
    @IBOutlet private var tempLabel: UILabel!
    @IBOutlet private var iconImageView: UIImageView!
    @IBOutlet private var conditionLabel: UILabel!
    @IBOutlet private var randomWeatherButton: UIButton!
    
    let weatherAPI = WeatherHelper()
    let locationHelper = LocationHelper()
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateWithCurrentLocation()
    }
    
    /**
     * DONE: uisng helper class to work with Core Location. You’ll implement it in a moment. The result of getLocation() is a promise to get a placemark for the current location.
     * CATCH: This catch block demonstrates how to handle different errors within a single catch block. Here, you use a simple switch to provide a different message when the user hasn’t granted location privileges versus other types of errors.
     */
    private func updateWithCurrentLocation() {
        // handleMockLocation()
        locationHelper.getLocation()
            .done { [weak self] placemark in
                self?.handleLocation(placemark: placemark)
            }
            .catch { [weak self] error in
                guard let self = self else { return }
                
                self.tempLabel.text = "--"
                self.placeLabel.text = "--"
                
                switch error {
                case is CLError where (error as? CLError)?.code == .denied:
                    self.conditionLabel.text = "Enable Location Permissions in Settings"
                    self.conditionLabel.textColor = UIColor.white
                default:
                    self.conditionLabel.text = error.localizedDescription
                    self.conditionLabel.textColor = errorColor
                }
        }
        
        // To do the update every hour, it was made recursive onupdateWithCurrentLocation().
        after(seconds: oneHour).done { [weak self] in
            self?.updateWithCurrentLocation()
        }
    }
    
    private func handleMockLocation() {
        let coordinate = CLLocationCoordinate2DMake(37.966667, 23.716667)
        handleLocation(city: "Athens", state: "Greece", coordinate: coordinate)
    }
    
    private func handleLocation(placemark: CLPlacemark) {
        handleLocation(city: placemark.locality,
                       state: placemark.administrativeArea,
                       coordinate: placemark.location!.coordinate)
    }
    
    /**
     * Completion handling is now broken into multiple easy-to-read closures
     * then block to return a Promise instead of Void. This means that, when the getWeather promise completes, you return a new promise. getIcon method to create a new promise to get the icon.
     * done closure to the chain, which will execute on the main queue when the getIcon promise completes.
     * catch block: handle all the errors in one spot. For example, in a complicated workflow like a user login, a single retry error dialog can display if any step fails.
     * by default, PromiseKit executes these closures on the main thread, so there’s no chance of accidentally updating the UI on a background thread. This PromiseKit compose the promises in a single chain, which is easy to read and maintain. Each then/done block has its own context, keeping logic and state from bleeding into each other. A column of blocks is easier to read without an ever-deepening indent.
     */
    private func handleLocation(
        city: String?,
        state: String?,
        coordinate: CLLocationCoordinate2D
        ) {
        if let city = city,
            let state = state {
            self.placeLabel.text = "\(city), \(state)"
        }
        
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        weatherAPI.getWeather(
            atLatitude: coordinate.latitude,
            longitude: coordinate.longitude)
            .then { [weak self] weatherInfo -> Promise<UIImage> in
                guard let self = self else { return brokenPromise() }
                
                self.updateUI(with: weatherInfo)
                
                return self.weatherAPI.getIcon(named: weatherInfo.weather.first!.icon)
            }
            .done(on: DispatchQueue.main) { icon in
                self.iconImageView.image = icon
            }
            .catch { error in
                self.tempLabel.text = "--"
                self.conditionLabel.text = error.localizedDescription
                self.conditionLabel.textColor = errorColor
            }.finally {
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
        }
    }
    
    private func updateUI(with weatherInfo: WeatherHelper.WeatherInfo) {
        let tempMeasurement = Measurement(value: weatherInfo.main.temp, unit: UnitTemperature.kelvin)
        let formatter = MeasurementFormatter()
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .none
        formatter.numberFormatter = numberFormatter
        let tempStr = formatter.string(from: tempMeasurement)
        self.tempLabel.text = tempStr
        self.placeLabel.text = weatherInfo.name
        self.conditionLabel.text = weatherInfo.weather.first?.description ?? "empty"
        self.conditionLabel.textColor = UIColor.white
    }
    
    @IBAction func showRandomWeather(_ sender: AnyObject) {
        randomWeatherButton.isEnabled = false
        
        let weatherPromises = randomCities.map {
            weatherAPI.getWeather(atLatitude: $0.2, longitude: $0.3)
        }
        
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        
        race(weatherPromises)
            .then { [weak self] weatherInfo -> Promise<UIImage> in
                guard let self = self else { return brokenPromise() }
                
                self.placeLabel.text = weatherInfo.name
                self.updateUI(with: weatherInfo)
                return self.weatherAPI.getIcon(named: weatherInfo.weather.first!.icon)
            }
            .done { icon in
                self.iconImageView.image = icon
            }
            .catch { error in
                self.tempLabel.text = "--"
                self.conditionLabel.text = error.localizedDescription
                self.conditionLabel.textColor = errorColor
            }
            .finally {
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                self.randomWeatherButton.isEnabled = true
        }
    }

}

// MARK: - UITextFieldDelegate
extension ViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        guard let text = textField.text else { return false }
        
        locationHelper.searchForPlacemark(text: text)
            .done { placemark in
                self.handleLocation(placemark: placemark)
            }
            .catch { _ in }
        
        return true
    }
}

