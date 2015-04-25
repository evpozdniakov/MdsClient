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
    var player: RemoteMp3Player?

    // #MARK: - IB outlets

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!

    // #MARK: - IB Actions

    @IBAction func playBtnClicked(sender: UIButton) {
        startOrResumePlaybackOfRecordAssociatedWithButton(sender)
    }

    @IBAction func pauseBtnClicked(sender: UIButton) {
        pausePlaybackOfRecordAssociatedWithButton(sender)
    }

    // #MARK: - UIViewController methods

    override func viewDidLoad() {
        super.viewDidLoad()

        assert(dataModel != nil)

        setTableViewMargings()
        searchBar.becomeFirstResponder()

        player = RemoteMp3Player()
        player!.delegate = self

        // ask dataModel to load records
        dataModel!.loadRecords()
    }

    // #MARK: - redraw

    func setTableViewMargings() {
        // assert(isMainThread())

        tableView.contentInset = UIEdgeInsets(top: 66, left: 0, bottom: 49, right: 0)
    }

    func redrawRecordsAtIndexPaths(indexPaths: [NSIndexPath]) {
        if !isMainThread() {
            dispatch_async(dispatch_get_main_queue()) {
                self.redrawRecordsAtIndexPaths(indexPaths)
            }
            return
        }

        tableView.beginUpdates()
        tableView.reloadRowsAtIndexPaths(indexPaths, withRowAnimation: .None)
        tableView.endUpdates()
    }

    // #MARK: - playback
    func startOrResumePlaybackOfRecordAssociatedWithButton(playBtn: UIButton) {
        assert(dataModel != nil)
        assert(player != nil)

        if let cell = getCellContainingButton(playBtn),
            record = getRecordAssociatedWithCell(cell),
            indexPath = tableView.indexPathForCell(cell) {

            let previousRecord = dataModel!.playingRecord
            var indexPathsToRedraw = [NSIndexPath]()

            indexPathsToRedraw.append(indexPath)

            if record == previousRecord {
                // resume playback
                player!.resumePlayback()
            }
            else {
                if previousRecord != nil {
                    // stop playing previous record
                    player!.stop()

                    if let index = dataModel!.playingRecordIndex {
                        // store previous record cell indexPath
                        indexPathsToRedraw.append(NSIndexPath(forRow: index, inSection: 0))
                    }
                }

                // start playing record
                dataModel!.playingRecord = record
                record.getFirstPlayableTrack() { track in
                    if let track = track {
                        self.player!.startPlayback(url: track.url)
                    }
                    else {
                        // no tracks found
                        throwErrorMessage("Файл mp3 не найден на сервере.", inViewController: self) {
                            self.redrawRecordsAtIndexPaths([indexPath])
                        }
                    }
                }
            }

            // redraw
            println("redraw table after CLICK")
            redrawRecordsAtIndexPaths(indexPathsToRedraw)
        }
    }

    func pausePlaybackOfRecordAssociatedWithButton(pauseBtn: UIButton) {
        if let cell = getCellContainingButton(pauseBtn),
            record = getRecordAssociatedWithCell(cell),
            indexPath = tableView.indexPathForCell(cell),
            player = player,
            dataModel = dataModel {
                assert(record == dataModel.playingRecord)

                player.pausePlayback()
                // #FIXME: send show hide buttons as closure when action takes effect
                // put activityIndicator meanwhile
                // tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .None)
        }
    }

    // #MARK: miscellaneous

    func isMainThread() -> Bool {
        return NSThread.currentThread().isMainThread
    }

    func getCellContainingButton(btn: UIButton) -> UITableViewCell? {
        assert(dataModel != nil)

        if let dataModel = dataModel,
            filteredRecords = dataModel.filteredRecords,
            cellContent = btn.superview,
            buttonsWrapper = cellContent.superview,
            cell = buttonsWrapper.superview as? UITableViewCell {
                return cell
        }

        return nil
    }

    func getRecordAssociatedWithCell(cell: UITableViewCell) -> Record? {
        assert(dataModel != nil)
        assert(dataModel!.filteredRecords != nil)
        assert(dataModel!.filteredRecords!.count > 0)

        if let dataModel = dataModel,
            filteredRecords = dataModel.filteredRecords,
            indexPath = tableView.indexPathForCell(cell) {
                let recordIndex = indexPath.row

                // #FIXME: replace assert by throwErrorWithCode
                assert(recordIndex < filteredRecords.count)

                return filteredRecords[recordIndex]
        }

        return nil
    }
}

// #MARK: - RemoteMp3PlayerDelegate

extension SearchCatalog: RemoteMp3PlayerDelegate {
    func remoteMp3Player(player: RemoteMp3Player, statusChanged playbackStatus: MyAVPlayerStatus) {
        assert(dataModel != nil)

        println("================ remoteMp3Player status changed: \(playbackStatus.rawValue)")
        if let playingRecordIndex = dataModel!.playingRecordIndex {
            let indexPath = NSIndexPath(forRow: playingRecordIndex, inSection: 0)

            redrawRecordsAtIndexPaths([indexPath])
        }
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
        assert(player != nil)

        let cellId = CellId.recordCell
        let cell = tableView.dequeueReusableCellWithIdentifier(cellId) as! UITableViewCell

        if let dataModel = dataModel,
            filteredRecords = dataModel.filteredRecords {

            assert(indexPath.row < filteredRecords.count)

            let record = filteredRecords[indexPath.row]

            if let authorLbl = cell.viewWithTag(100) as? UILabel {
                authorLbl.text = record.author
            }

            if let titleLbl = cell.viewWithTag(200) as? UILabel {
                titleLbl.text = record.title
            }

            if let playBtn = cell.viewWithTag(300) as? UIButton,
                pauseBtn = cell.viewWithTag(400) as? UIButton,
                activityIndicator = cell.viewWithTag(500) as? UIActivityIndicatorView {

                let isNowPlayingRecord = (dataModel.playingRecord === record)

                if record.hasNoTracks {
                    if !playBtn.hidden { playBtn.hidden = true }
                    if !pauseBtn.hidden { pauseBtn.hidden = true }
                    if activityIndicator.isAnimating() { activityIndicator.stopAnimating() }
                }
                else if dataModel.playingRecord === record {
                    let playbackStatus = player!.playbackStatus
                    println("REDRAW CELL of playing record (index: \(indexPath.row), status: \(playbackStatus.rawValue))")
                    switch playbackStatus {
                    case .Playing, .Seeking:
                        if !playBtn.hidden { playBtn.hidden = true }
                        if pauseBtn.hidden { pauseBtn.hidden = false }
                        if activityIndicator.isAnimating() { activityIndicator.stopAnimating() }
                    case .Paused:
                        if playBtn.hidden { playBtn.hidden = false }
                        if !pauseBtn.hidden { pauseBtn.hidden = true }
                        if activityIndicator.isAnimating() { activityIndicator.stopAnimating() }
                    default:
                        if !playBtn.hidden { playBtn.hidden = true }
                        if !pauseBtn.hidden { pauseBtn.hidden = true }
                        if !activityIndicator.isAnimating() { activityIndicator.startAnimating() }
                    }
                }
                else {
                    if playBtn.hidden { playBtn.hidden = false }
                    if !pauseBtn.hidden { pauseBtn.hidden = true }
                    if activityIndicator.isAnimating() { activityIndicator.stopAnimating() }
                }
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
