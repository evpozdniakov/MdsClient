//
//  ViewController.swift
//  MdsClient
//
//  Created by Evgeniy Pozdnyakov on 2015-03-15.
//  Copyright (c) 2015 Evgeniy Pozdnyakov. All rights reserved.
//

import UIKit
import AVFoundation

class SearchCatalog: UIViewController {
    
    struct CellId {
        static let recordCell = "RecordCell"
    }
    
    // #MARK: - ivars
    
    var dataModel: DataModel?
    var lastSearchQuery = ""
    var searchResults = [Record]()
    
    // #MARK: - IB outlets

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!

    // #MARK: - IB Actions

    @IBAction func playButtonClicked(sender: UIButton) {
        assert(dataModel != nil)

        if let cellContent = sender.superview {
            if let cell = cellContent.superview as? UITableViewCell {
                // println("cell found")
                if let indexPath = tableView.indexPathForCell(cell) {
                    if let records = dataModel!.filteredRecords {
                        let record = records[indexPath.row]
                        println("record: \(record)")
                        record.getFirstPlayableTrack() { track in
                            if let track = track {
                                println("got playable track: \(track)")
                                println("url: \(track.url)")
                            }
                            else {
                                println("there are nor tracks")
                            }
                        }
                    }
                    else {
                        // #FIXME: there are no records
                    }
                }
                else {
                    // #FIXME: indexPath for cell not found
                }
            }
            else {
                // #FIXME: sender superview is not a cell
            }
        }
        else {
            // #FIXME: sender doesn't have superview
        }
    }    
    
    // #MARK: - UIViewController methods

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        assert(dataModel != nil)

        setTableViewMargings()
        searchBar.becomeFirstResponder()

        // ask dataModel to load records
        dataModel!.loadRecords()
    }

    // #MARK: - redraw

    func setTableViewMargings() {
        tableView.contentInset = UIEdgeInsets(top: 66, left: 0, bottom: 49, right: 0)
    }

}

// #MARK: - UITableViewDataSource

extension SearchCatalog: UITableViewDataSource {
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        assert(dataModel != nil)

        if let records = dataModel!.filteredRecords {
            return records.count
        }

        return 0
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        return getRecordCellForTableView(tableView, atIndexPath: indexPath)
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let height: CGFloat = 88

        return height
    }


    func getRecordCellForTableView(tableView: UITableView, atIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        assert(dataModel != nil)

        let cellId = CellId.recordCell
        let cell = tableView.dequeueReusableCellWithIdentifier(cellId) as! UITableViewCell

        if let records = dataModel!.filteredRecords {
            let record = records[indexPath.row]

            if let authorLbl = cell.viewWithTag(100) as? UILabel {
                authorLbl.text = record.author
            }

            if let titleLbl = cell.viewWithTag(200) as? UILabel {
                titleLbl.text = record.title
            }            
        }

        return cell
    }
}

// #MARK: - UITableViewDelegate

extension SearchCatalog: UITableViewDelegate {
    func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
        searchBar.resignFirstResponder()

        return nil
    }
    
    /*func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let height: CGFloat = (searchQueryHasNoResults && indexPath.row == 0) ? 88 : 44

        return height
    }*/
}


// #MARK: - UISearchBarDelegate

extension SearchCatalog: UISearchBarDelegate {
    func searchBarSearchButtonClicked(searchBar: UISearchBar) {
        assert(dataModel != nil)
        // println("search button clicked, search string: '\(searchBar.text)'")
        searchBar.resignFirstResponder()
        dataModel!.filterRecordsWhichContainText(searchBar.text)
        tableView.reloadData()
    }

    func positionForBar(bar: UIBarPositioning) -> UIBarPosition {
        return .TopAttached
    }
}

