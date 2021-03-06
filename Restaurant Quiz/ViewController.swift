//
//  ViewController.swift
//  Restaurant Quiz
//
//  Created by Dominic Kuang on 12/16/14.
//  Copyright (c) 2014 Dominic Kuang. All rights reserved.
//

import UIKit
import MapKit

class ViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var scoreLabel: UILabel!
    @IBOutlet weak var restaurantLabel: UILabel!
    @IBOutlet weak var infoView: UIView!
    @IBOutlet weak var infoViewBottomConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var scoreDescriptionLabel: UILabel!
    @IBOutlet weak var distanceDescriptionLabel: UILabel!
    @IBOutlet weak var restaurantDescriptionLabel: UILabel!
    @IBOutlet weak var infoViewHeight: NSLayoutConstraint!
    
    // MARK: - Properties
    
    // The distance, from the destination, considered to be close enough
    let winningDistance = 100.0
    
    var playing: Bool = false
    
    // The height which the camera must be under
    let maximumEyeLevel: CLLocationDistance = 2000
    
    var current: MKAnnotation?
    var previous: MKAnnotation?
    var overlays: [MKOverlay]
    var destination: Restaurant?
    
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
    var attempts: Int = 0
    
    var score: Int {
        didSet {
            scoreLabel.text = "\(score)"
        }
    }
    
    let maxScore = 2000
    
    var timer: NSTimer?
    
    var fullyRendered = false
    
    // MARK: - Lifecycle Methods
    required init(coder aDecoder: NSCoder) {
        overlays = []
        score = maxScore
        super.init(coder: aDecoder)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "setupDynamicText", name: UIContentSizeCategoryDidChangeNotification, object: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        mapView.delegate = self
        
        let tapRecognizer = UILongPressGestureRecognizer(target: self, action: "handleMapTouch:")
        tapRecognizer.minimumPressDuration = 0.5
        self.mapView.addGestureRecognizer(tapRecognizer)
        self.mapView.showsPointsOfInterest = false
        self.navigationController?.navigationBar.tintColor = UIColor(red: 0.204, green: 0.667, blue: 0.863, alpha: 1)
        
        // Call this once so we can set the bottom constraint before view appears
        setupDynamicText()
        infoViewBottomConstraint.constant = -infoViewHeight.constant
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(true)
        setupDynamicText()
    }
    
    override func viewDidLayoutSubviews() {
        let shadowPath = UIBezierPath(rect: infoView.bounds)
        infoView.layer.masksToBounds = false
        infoView.layer.shadowColor = UIColor.blackColor().CGColor
        infoView.layer.shadowOffset = CGSizeMake(0, 0.5)
        infoView.layer.shadowOpacity = 0.5
        infoView.layer.shadowPath = shadowPath.CGPath
    }
    
    /** Add support for dynamic text on all UI elements, including related constraints */
    func setupDynamicText() {
        let caption2 = UIFont.preferredFontForTextStyle(UIFontTextStyleCaption2)
        let headline = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
        
        scoreLabel.font = headline
        distanceLabel.font = headline
        restaurantLabel.font = headline
        
        scoreDescriptionLabel.font = caption2
        distanceDescriptionLabel.font = caption2
        restaurantDescriptionLabel.font = caption2
        
        // TODO: Make this static?
        var infoViewHeights: [NSString: CGFloat] = [UIContentSizeCategoryExtraSmall: 40,
            UIContentSizeCategorySmall: 40, UIContentSizeCategoryMedium: 40,
            UIContentSizeCategoryLarge: 44, UIContentSizeCategoryExtraLarge: 50,
            UIContentSizeCategoryExtraExtraLarge: 56, UIContentSizeCategoryExtraExtraExtraLarge: 56]
        let userPref = UIApplication.sharedApplication().preferredContentSizeCategory
        if let height = infoViewHeights[userPref] {
            infoViewHeight.constant = infoViewHeights[userPref]!
        }
    }
    
    // MARK: - Game Methods
    
    /** Start a new round of the game */
    func startNewRound(destinationRestaurant: Restaurant) {
        playing = true
        resetGameState()
        destination = destinationRestaurant
        panCameraTo(destinationRestaurant.city)
        restaurantLabel.text = destination!.name
        popUpInfoView()
        if fullyRendered {
            startTimer()
        }
    }
    
    func startTimer() {
        timer = NSTimer(timeInterval: 1.5, target: self, selector: "tickScore:", userInfo: nil, repeats: true)
        NSRunLoop.mainRunLoop().addTimer(timer!, forMode: NSRunLoopCommonModes)
    }
    
    func tickScore(timer: NSTimer) {
        score = Int(Float(score) * 0.99)
    }
    
    /** Show the info view with an animation */
    func popUpInfoView() {
        infoViewBottomConstraint.constant = 0
        infoView.setNeedsUpdateConstraints()
        UIView.animateWithDuration(0.8, delay: 0, options: .CurveEaseOut, animations: {
            [unowned self] in
            self.infoView.layoutIfNeeded()
            }, completion: nil)
    }
    
    func endGame() {
        let alert = UIAlertController(title: "Congratulations!", message: "You have won after travelling \(distanceFormatter.stringFromDistance(distance)).", preferredStyle: UIAlertControllerStyle.Alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: {
            (alertAction: UIAlertAction!) in
            self.dismissViewControllerAnimated(true, completion: nil)
        }))
        playing = false
        self.presentViewController(alert, animated: true, completion: nil)
        mapView.removeAnnotations(mapView.annotations)
        addAnnotation(destination!)
        ScoreTracker.sharedInstance.addScore(score, attempts: attempts)
        timer?.invalidate()
        timer = nil
    }
    
    
    /** Reset the map and markers to an unplayed state */
    func resetGameState() {
        mapView.removeAnnotations(mapView.annotations)
        current = nil
        previous = nil
        mapView.removeOverlays(overlays)
        overlays = []
        distance = 0
        destination = nil
        score = maxScore
        attempts = 0
        timer?.invalidate()
    }
    
    // MARK: - Routing Methods
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
    
    /** Draw a route. Use as a completion handler. */
    func drawRoute(response: MKDirectionsResponse!, error: NSError!) {
        let route = response.routes[0] as MKRoute
        distance += route.distance
        overlays.append(route.polyline)
        self.mapView.addOverlay(route.polyline, level: MKOverlayLevel.AboveRoads)
    }
    
    
    /** Get the straight line distance between two points, in metres*/
    func distanceBetweenPoints(p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D) -> CLLocationDistance {
        let dest = CLLocation(latitude: p1.latitude, longitude: p1.longitude)
        let currentPoint = CLLocation(latitude: p2.latitude, longitude: p2.longitude)
        let dist = currentPoint.distanceFromLocation(dest)
        
        return dist
    }
    
    /** Returns a float representing a colour between red and green, scaling linearly from 0 to 3000 respectively */
    func colourGradientFromDistanceRemaining(distance: CLLocationDistance) -> Float {
        if distance >= 3000 {
            return 0
        }
        return Float(2.19 - (2.19 * distance / 3000))
    }
    
    /** Convenience method to convert an annotation to a MKMapItem */
    func mapItemFrom(#annotation: MKAnnotation) -> MKMapItem {
        return MKMapItem(placemark: MKPlacemark(coordinate: annotation.coordinate, addressDictionary: nil))
    }
    
    // MARK: - Gesture Recognizer
    func handleMapTouch(gr: UITapGestureRecognizer) {
        if gr.state == UIGestureRecognizerState.Began && playing {
            let mapCoord = mapView.convertPoint(gr.locationInView(mapView), toCoordinateFromView: mapView)
            mapView.removeAnnotation(previous)
            previous = current
            
            panCameraTo(mapCoord, heading: CLLocationDegrees(arc4random_uniform(360)))
            
            let dir = directionsToNewPoint(MKMapItem(placemark: MKPlacemark(coordinate: mapCoord, addressDictionary: nil)))
            dir.calculateDirectionsWithCompletionHandler(drawRoute)
            attempts++
            
            if distanceBetweenPoints(destination!.coordinate, p2: mapCoord) >= winningDistance {
                let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: mapCoord, addressDictionary: nil))
                current = addAnnotation(mapItem)
            } else {
                endGame()
            }
        }
        
    }
    
    
    
    // MARK: - MapView Helpers
    
    /** Animates the camera to the given city */
    func panCameraTo(city: City) {
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
    
    
    /** Adds an annotation to the map, including the distance to destination */
    func addAnnotation(coord: MKMapItem) -> MKAnnotation {
        let point = MKPointAnnotation()
        point.coordinate = coord.placemark.coordinate
        mapView.addAnnotation(point)
        
        let dist = distanceBetweenPoints(destination!.coordinate, p2: point.coordinate)
        
        point.title = "\(distanceFormatter.stringFromDistance(dist))"
        return point
    }
    
    /** Adds an annotation at the restaurant, including its name */
    func addAnnotation(restaurant: Restaurant) -> MKAnnotation {
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: restaurant.coordinate, addressDictionary: nil))
        let point = addAnnotation(mapItem) as MKPointAnnotation
        point.title = restaurant.name
        return point
    }
}

// MARK: - MKMapViewDelegate
extension ViewController: MKMapViewDelegate {
    func mapView(mapView: MKMapView!, rendererForOverlay overlay: MKOverlay!) -> MKOverlayRenderer! {
        if overlay is MKPolyline {
            let polyRenderer = MKPolylineRenderer(overlay: overlay)
            polyRenderer.lineWidth = 3
            polyRenderer.strokeColor = UIColor.redColor().colorWithAlphaComponent(0.6)
            return polyRenderer
        }
        return nil
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
    
    func mapViewWillStartLoadingMap(mapView: MKMapView!) {
        self.fullyRendered = false
    }
    
    func mapViewDidFinishRenderingMap(mapView: MKMapView!, fullyRendered: Bool) {
        if playing && timer? == nil {
            self.fullyRendered = true
            startTimer()
        }
    }
}