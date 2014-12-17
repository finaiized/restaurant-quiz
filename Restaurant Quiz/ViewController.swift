//
//  ViewController.swift
//  Restaurant Quiz
//
//  Created by Dominic Kuang on 12/16/14.
//  Copyright (c) 2014 Dominic Kuang. All rights reserved.
//

import UIKit
import MapKit

class ViewController: UIViewController, MKMapViewDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var distanceLabel: UILabel!
    
    var current: MKAnnotation?
    var previous: MKAnnotation?
    var overlays: [MKOverlay]
    var destination: MKPointAnnotation
    
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
        destination = MKPointAnnotation()
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        mapView.delegate = self
        
        let ladner = CLLocationCoordinate2D(latitude: 49.081241, longitude: -123.083793)
        let ladnerPlaceMark = MKPlacemark(coordinate: ladner, addressDictionary: nil)
        let ladnerMapItem = MKMapItem(placemark: ladnerPlaceMark)
        let van = CLLocationCoordinate2D(latitude: 49.266638, longitude: -123.249275)
        let vanPlaceMark = MKPlacemark(coordinate: van, addressDictionary: nil)
        let vanMapItem = MKMapItem(placemark: vanPlaceMark)
        
        destination.coordinate = van
        
        let region = MKCoordinateRegionMakeWithDistance(ladner, 1000, 1000)
        mapView.region = region
        
        let tapRecognizer = UILongPressGestureRecognizer(target: self, action: "handleMapTouch:")
        tapRecognizer.minimumPressDuration = 0.5
        self.mapView.addGestureRecognizer(tapRecognizer)
    }
    
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
    
    func mapItemFrom(#annotation: MKAnnotation) -> MKMapItem {
        return MKMapItem(placemark: MKPlacemark(coordinate: annotation.coordinate, addressDictionary: nil))
    }
    
    /** Draw a route. Use as a completion handler. */
    func drawRoute(response: MKDirectionsResponse!, error: NSError!) {
        let route = response.routes[0] as MKRoute
        distance += route.distance
        self.mapView.addOverlay(route.polyline, level: MKOverlayLevel.AboveRoads)
    }
    
    
    // MARK: - MKMapView
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
        if gr.state == UIGestureRecognizerState.Began {
            let mapCoord = mapView.convertPoint(gr.locationInView(mapView), toCoordinateFromView: mapView)
            mapView.removeAnnotation(previous)
            previous = current
            let dir = directionsToNewPoint(MKMapItem(placemark: MKPlacemark(coordinate: mapCoord, addressDictionary: nil)))
            dir.calculateDirectionsWithCompletionHandler(drawRoute)
            current = addAnnotation(mapCoord)
        }
        
    }
    
    func addAnnotation(coord: CLLocationCoordinate2D) -> MKAnnotation {
        let point = MKPointAnnotation()
        point.coordinate = coord
        mapView.addAnnotation(point)
        
        let dist = distanceBetweenPoints(destination.coordinate, p2: point.coordinate)
        
        point.title = "\(distanceFormatter.stringFromDistance(dist))"
        return point
    }
    
    /** Get the straight line distance between two points, in metres*/
    func distanceBetweenPoints(p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D) -> CLLocationDistance {
        let dest = CLLocation(latitude: p1.latitude, longitude: p1.longitude)
        let currentPoint = CLLocation(latitude: p2.latitude, longitude: p2.longitude)
        let dist = currentPoint.distanceFromLocation(dest)
        
        return dist
    }
    
    @IBOutlet weak var some: UIImageView!
    func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView! {
        var annotationView = mapView.dequeueReusableAnnotationViewWithIdentifier("ColourAnnotationView") as? ColourAnnotationView
        
        if annotationView == nil {
            annotationView = ColourAnnotationView(annotation: annotation, reuseIdentifier: "ColourAnnotationView")
            annotationView!.canShowCallout = true
            annotationView!.frame = CGRect(x: 0, y: 0, width: 64, height: 64)
        } else {
            annotationView!.annotation = annotation
        }
        
        let dist = distanceBetweenPoints(annotation.coordinate, p2: destination.coordinate)
        annotationView!.hue = colourGradientFromDistanceRemaining(dist)
        annotationView!.setNeedsDisplay()
        return annotationView
    }
    
    func colourGradientFromDistanceRemaining(distance: CLLocationDistance) -> Float {
        if distance >= 3000 {
            return 0
        }
        return Float(M_PI - (M_PI * distance / 3000))
    }
    
}

