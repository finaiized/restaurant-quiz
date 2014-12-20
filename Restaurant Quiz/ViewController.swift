//
//  ViewController.swift
//  Restaurant Quiz
//
//  Created by Dominic Kuang on 12/16/14.
//  Copyright (c) 2014 Dominic Kuang. All rights reserved.
//

import UIKit
import MapKit

class ViewController: UIViewController, MKMapViewDelegate, NSURLConnectionDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var distanceLabel: UILabel!
    
    // The distance, from the destination, considered to be close enough
    let winningDistance = 100.0
    
    var playing: Bool = false
    
    // The height which the camera must be under
    let maximumEyeLevel: CLLocationDistance = 2000
    
    var current: MKAnnotation?
    var previous: MKAnnotation?
    var overlays: [MKOverlay]
    var destination: Restaurant?
    var restaurants: [Restaurant]
    
    var distanceFormatter: MKDistanceFormatter {
        struct Static {
            static let instance: MKDistanceFormatter = MKDistanceFormatter()
        }
        Static.instance.units = MKDistanceFormatterUnits.Metric
        Static.instance.unitStyle = MKDistanceFormatterUnitStyle.Abbreviated
        
        return Static.instance
    }
    
    var distance: Double = 0.0 {
        didSet {
            distanceLabel.text = "\(distanceFormatter.stringFromDistance(distance))"
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        overlays = []
        restaurants = []
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        mapView.delegate = self
        
        let tapRecognizer = UILongPressGestureRecognizer(target: self, action: "handleMapTouch:")
        tapRecognizer.minimumPressDuration = 0.5
        self.mapView.addGestureRecognizer(tapRecognizer)
    }
    
    /** Returns the directions to point, starting from the most recent pin, if any */
    func directionsToNewPoint(point: MKMapItem) -> MKDirections {
        // First pin dropped
        if current == nil {
            let temp = MKPointAnnotation()
            temp.coordinate = point.placemark.coordinate
            current = temp
        }
        
        let directionRequest = MKDirectionsRequest()
        directionRequest.setSource(mapItemFrom(annotation: current!))
        directionRequest.setDestination(point)
        
        let prev = MKPointAnnotation()
        prev.coordinate = point.placemark.coordinate
        
        return MKDirections(request: directionRequest)
    }
    
    /** Convenience method to convert an annotation to a MKMapItem */
    func mapItemFrom(#annotation: MKAnnotation) -> MKMapItem {
        return MKMapItem(placemark: MKPlacemark(coordinate: annotation.coordinate, addressDictionary: nil))
    }
    
    /** Draw a route. Use as a completion handler. */
    func drawRoute(response: MKDirectionsResponse!, error: NSError!) {
        let route = response.routes[0] as MKRoute
        distance += route.distance
        overlays.append(route.polyline)
        self.mapView.addOverlay(route.polyline, level: MKOverlayLevel.AboveRoads)
    }
    
    
    // MARK: - MKMapViewDelegate
    func mapView(mapView: MKMapView!, rendererForOverlay overlay: MKOverlay!) -> MKOverlayRenderer! {
        if overlay is MKPolyline {
            let polyRenderer = MKPolylineRenderer(overlay: overlay)
            polyRenderer.lineWidth = 3
            polyRenderer.strokeColor = UIColor.redColor().colorWithAlphaComponent(0.6)
            return polyRenderer
        }
        return nil
    }
    
    // MARK: -
    func handleMapTouch(gr: UITapGestureRecognizer) {
        if gr.state == UIGestureRecognizerState.Began && playing {
            let mapCoord = mapView.convertPoint(gr.locationInView(mapView), toCoordinateFromView: mapView)
            mapView.removeAnnotation(previous)
            previous = current
            
            panCameraTo(mapCoord, heading: CLLocationDegrees(arc4random_uniform(360)))
            
            let dir = directionsToNewPoint(MKMapItem(placemark: MKPlacemark(coordinate: mapCoord, addressDictionary: nil)))
            dir.calculateDirectionsWithCompletionHandler(drawRoute)
            
            let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: mapCoord, addressDictionary: nil))
            current = addAnnotation(mapItem)
            
            if distanceBetweenPoints(destination!.coordinate, p2: mapCoord) <= winningDistance {
                endGame()
            }
        }
        
    }
    
    /** Adds an annotation to the map, including the distance to destination */
    func addAnnotation(coord: MKMapItem) -> MKAnnotation {
        let point = MKPointAnnotation()
        point.coordinate = coord.placemark.coordinate
        mapView.addAnnotation(point)
        
        let dist = distanceBetweenPoints(destination!.coordinate, p2: point.coordinate)
        
        if dist >= winningDistance {
            point.title = "\(distanceFormatter.stringFromDistance(dist))"
        } else {
            point.title = "\(destination!.name)"
        }
        return point
    }
    
    /** Get the straight line distance between two points, in metres*/
    func distanceBetweenPoints(p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D) -> CLLocationDistance {
        let dest = CLLocation(latitude: p1.latitude, longitude: p1.longitude)
        let currentPoint = CLLocation(latitude: p2.latitude, longitude: p2.longitude)
        let dist = currentPoint.distanceFromLocation(dest)
        
        return dist
    }
    
    func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView! {
        var annotationView = mapView.dequeueReusableAnnotationViewWithIdentifier("ColourAnnotationView") as? ColourAnnotationView
        
        if annotationView == nil {
            annotationView = ColourAnnotationView(annotation: annotation, reuseIdentifier: "ColourAnnotationView")
            annotationView!.canShowCallout = true
            annotationView!.frame = CGRect(x: 0, y: 0, width: 64, height: 64)
        } else {
            annotationView!.annotation = annotation
        }
        
        let dist = distanceBetweenPoints(annotation.coordinate, p2: destination!.coordinate)
        annotationView!.hue = colourGradientFromDistanceRemaining(dist)
        annotationView!.setNeedsDisplay()
        return annotationView
    }
    
    /** Returns a float representing a colour between red and green, scaling linearly from 0 to 3000 respectively */
    func colourGradientFromDistanceRemaining(distance: CLLocationDistance) -> Float {
        if distance >= 3000 {
            return 0
        }
        return Float(M_PI - (M_PI * distance / 3000))
    }
    
    /** Called when city is selected in DDCityViewController */
    func getRestaurantsInCity(city: DDCity) {
        Yelp.restaurantsFromCity(city, completion: {
            (data: NSData) in
            Restaurant.restaurantsFromYelpJSON(data, forCity: city, completion: {
                (restaurants: [Restaurant]) in
                    self.restaurants = restaurants
                    let rand = Int(arc4random_uniform(UInt32(self.restaurants.count)))
                    self.startNewRound(self.restaurants[rand])
            })
        })
    }
    
    /** Called when category is selected in DDCategoryPickerController */
    func getRestaurantsInCategory(cat: String) {
        var restaurantsInCategory = [Restaurant]()
        for res in self.restaurants {
            for c in res.categories {
                if c == cat {
                    restaurantsInCategory.append(res)
                }
            }
        }
        
        let rand = Int(arc4random_uniform(UInt32(restaurantsInCategory.count)))
        let restaurant = restaurantsInCategory[rand]
        
       self.startNewRound(restaurant)
    }
    
    /** Start a new round of the game */
    func startNewRound(destinationRestaurant: Restaurant) {
        playing = true
        resetMapState()
        destination = destinationRestaurant
        panCameraTo(destinationRestaurant.city)
    }
    
    /** Reset the map and markers to an unplayed state */
    func resetMapState() {
        mapView.removeAnnotations(mapView.annotations)
        current = nil
        previous = nil
        mapView.removeOverlays(overlays)
        overlays = []
        distance = 0
        destination = nil
    }
    
    func endGame() {
        let alert = UIAlertController(title: "Congratulations!", message: "You have won after travelling \(distanceFormatter.stringFromDistance(distance)).", preferredStyle: UIAlertControllerStyle.Alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: {
            (alertAction: UIAlertAction!) in
            self.dismissViewControllerAnimated(true, completion: nil)
        }))
        playing = false
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    /** Animates the camera to the given city */
    func panCameraTo(city: DDCity) {
        let camera = city.cameraFromCity()
        mapView.setCamera(camera, animated: true)
    }
    
    /** Animates the camera to a certain location, setting the height automatically */
    func panCameraTo(loc: CLLocationCoordinate2D, heading: CLLocationDegrees = 0) {
        // Pan to maximumEyeLevel if too zoomed out, otherwise, leave the altitude alone
        let camera = MKMapCamera(lookingAtCenterCoordinate: loc, fromEyeCoordinate: loc, eyeAltitude: min(maximumEyeLevel, mapView.camera.altitude))
        camera.heading = heading
        mapView.setCamera(camera, animated: true)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let id = segue.identifier {
            if id == "Category" {
                let cpvc = segue.destinationViewController as DDCategoryPickerController
                
                var categories = NSMutableSet()
                for r in restaurants {
                    for c in r.categories {
                        categories.addObject(c)
                    }
                }
                
                cpvc.categories = categories.allObjects as [String]
            }
        }
    }
}

