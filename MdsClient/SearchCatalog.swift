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
    
    // #MARK: - IB outlets

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!

    // #MARK: - IB Actions

    @IBAction func playButtonClicked(sender: UIButton) {
        if let cellContent = sender.superview {
            if let cell = cellContent.superview as? UITableViewCell {
                println("cell found")
                if let indexPath = tableView.indexPathForCell(cell) {
                    /* let record = searchResults[indexPath.row]
                    println("record: \(record)")

                    if record.sources == nil || record.sources!.isEmpty {
                        throwErrorMessage("Отсутствуют ссылки на загрузку файла.", withHandler: nil, inViewController: self)
                        return
                    }

                    let url = record.sources![1].url
                    println("lets play \(url)")

                    var error: NSError?
                    var audioPlayer:AVAudioPlayer?
                    audioPlayer = AVAudioPlayer(contentsOfURL: url,
                        fileTypeHint: AVFileTypeMPEGLayer3,
                        error: &error)

                    if let error = error {
                        println("error: \(error)")
                        return
                    }

                    sender.enabled = false
                    audioPlayer!.prepareToPlay()
                    audioPlayer!.play() */
                }
            }
        }
    }
    
    // #MARK: - ivars
    
    var dataModel: DataModel?
    var lastSearchQuery = ""
    var searchResults = [Record]()
    
    
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

    // #MARK: - helpers

    func getCatalogSearchUrlWithText(text: String) -> NSURL? {
        let escapedText = text.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!
        let urlString = String(format: "http://bumagi.net/api/mds-catalog.php?q=%@", escapedText)        
        let url = NSURL(string: urlString)

        return url
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
    // func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
    //     return indexPath
    // }
    
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
        dataModel!.filterRecordsWithText(searchBar.text)
        tableView.reloadData()
    }

    func positionForBar(bar: UIBarPositioning) -> UIBarPosition {
        return .TopAttached
    }
}

