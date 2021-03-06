//
//  CityViewController.swift
//  Restaurant Quiz
//
//  Created by Dominic Kuang on 12/17/14.
//  Copyright (c) 2014 Dominic Kuang. All rights reserved.
//

import UIKit

class CityPickerController: UITableViewController {
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        tableView.selectRowAtIndexPath(NSIndexPath(forRow: 0, inSection: 0), animated: false, scrollPosition: UITableViewScrollPosition.None)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let cpc = segue.destinationViewController as? CategoryPickerController {
            var indexPath = self.tableView.indexPathForSelectedRow()
            if indexPath == nil {
                indexPath = NSIndexPath(forRow: 0, inSection: 0)
            }
            
            let selectedCity = City.allValues[indexPath!.row]
            cpc.city = selectedCity
        }
    }
    
}

// MARK: - Table view data source
extension CityPickerController: UITableViewDataSource {
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return City.allValues.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("UITableViewCell", forIndexPath: indexPath) as UITableViewCell
        
        cell.textLabel?.text = City.allValues[indexPath.row].rawValue
        return cell
    }
    
}
