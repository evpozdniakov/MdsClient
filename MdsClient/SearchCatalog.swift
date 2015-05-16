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


        // setTableViewMargings()
        searchBar.becomeFirstResponder()

        player = RemoteMp3Player()
        player!.delegate = self

        loadMdsRecordsOnce()
        toggleDisablePlaylistTab()
    }

    // #MARK: - redraw

    /**
        Set table view margins to avoid top space taken by search and bottom place taken by tabs.

        Usage:

            setTableViewMargings()
    */
    func setTableViewMargings() {
        assert(appIsMainThread())

        tableView.contentInset = UIEdgeInsets(top: 66, left: 0, bottom: 49, right: 0)
    }

    /**
        Asks table view to redraw some cells.

        **Warning:** Switches to main thread, which might be required.

        Usage:

            redrawRecordsAtIndexPaths(indexPaths)

        :param: indexPaths: [NSIndexPath]
    */
    func redrawRecordsAtIndexPaths(indexPaths: [NSIndexPath]) {
        appMainThread() {
            self.tableView.beginUpdates()
            self.tableView.reloadRowsAtIndexPaths(indexPaths, withRowAnimation: .None)
            self.tableView.endUpdates()
        }
    }

    /**
        Will enable playlist tab if it has records, disable otherwise.
    */
    func toggleDisablePlaylistTab() {

        if let tabBarCtlr = parentViewController as? UITabBarController,
            items = tabBarCtlr.tabBar.items as? [UITabBarItem] {

            items[1].enabled = DataModel.playlist.count > 0
        }
    }

    // #MARK: - playback

    /**
        Finds record associated to clicked cell. Starts or resume playing the record.
        Stops playing previously played record in case.
        Stores playing record into DataModel.playingRecord

        Usage:

            startOrResumePlaybackOfRecordAssociatedWithButton(playBtn)

        :param: playBtn: UIButton
    */
    func startOrResumePlaybackOfRecordAssociatedWithButton(playBtn: UIButton) {
        assert(player != nil)

        if let cell = getCellContainingButton(playBtn),
            record = getRecordAssociatedWithCell(cell),
            indexPath = tableView.indexPathForCell(cell) {

            let previousRecord = DataModel.playingRecord
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

                    if let index = previousRecord!.filteredRecordsIndex {
                        // store previous record cell indexPath
                        indexPathsToRedraw.append(NSIndexPath(forRow: index, inSection: 0))
                    }
                }

                // start playing record
                DataModel.playingRecord = record

                record.getFirstPlayableTrack(
                    success: { track in
                        self.player!.startPlayback(url: track.url)
                    },
                    fail: { error in
                        // #TODO: find all error message texts and move them to enum
                        let msg = "Unable to download audio file of the record \"\(record.title)\""
                        appDisplayError(msg, inViewController: self) {
                            self.redrawRecordsAtIndexPaths([indexPath])
                        }
                    })
            }

            // redraw
            // println("redraw table after CLICK")
            redrawRecordsAtIndexPaths(indexPathsToRedraw)
        }
    }

    /**
        Puts playback on pause.

        Usage:

            pausePlaybackOfRecordAssociatedWithButton(pauseBtn)

        :param: pauseBtn: UIButton
    */
    func pausePlaybackOfRecordAssociatedWithButton(pauseBtn: UIButton) {
        assert(player != nil)

        if let cell = getCellContainingButton(pauseBtn),
            record = getRecordAssociatedWithCell(cell),
            indexPath = tableView.indexPathForCell(cell) {

            assert(record == DataModel.playingRecord)

            player!.pausePlayback()
        }
    }

    // #MARK: miscellaneous

    /**
        Downloads MDS catalog (records). Blocks UI before start, unblocks when done.
        In case of error displays the error message. Asks user if app should retry.

        **Warning:** Suppose to be run only once.

        Usage:

            loadMdsRecordsOnce()
    */
    private func loadMdsRecordsOnce() {
        if DataModel.allRecords.count == 0 {
            // #TODO: block UI
            DataModel.downloadCatalog(
                success: {
                    // #TODO: (do not forget switch to main thread!) unblock UI
                },
                fail: { error in
                    appMainThread() {
                        let msg = "Unable to download MDS catalog. The error is \(error.domain)-\(error.code). Application will retry to download catalog. Make sure you have access to the Internet."

                        appDisplayError(msg, inViewController: self, withHandler: self.loadMdsRecordsOnce)
                    }
                })
        }
    }

    /**
        Finds and returns table view cell by button it contains.

        Usage:

            getCellContainingButton(btn)

        :param: btn: UIButton

        :returns: UITableViewCell?
    */
    func getCellContainingButton(btn: UIButton) -> UITableViewCell? {
        if let cellContent = btn.superview,
            buttonsWrapper = cellContent.superview,
            cell = buttonsWrapper.superview as? UITableViewCell {
                return cell
        }

        return nil
    }

    /**
        Finds record associated by table cell.

        Usage:

            getRecordAssociatedWithCell(cell)

        :param: cell: UITablveViewCell

        :returns: Record?
    */
    func getRecordAssociatedWithCell(cell: UITableViewCell) -> Record? {
        assert(DataModel.filteredRecords.count > 0)

        if let indexPath = tableView.indexPathForCell(cell) {
            let recordIndex = indexPath.row

            if recordIndex < DataModel.filteredRecords.count {
                return DataModel.filteredRecords[recordIndex]
            }
        }

        // if for the record wasn't found for some reason, reload table data
        tableView.reloadData()

        return nil
    }
}

// #MARK: - RemoteMp3PlayerDelegate

extension SearchCatalog: RemoteMp3PlayerDelegate {
    func remoteMp3Player(player: RemoteMp3Player, statusChanged playbackStatus: MyAVPlayerStatus) {

        // println("================ remoteMp3Player status changed: \(playbackStatus.rawValue)")
        if let playingRecord = DataModel.playingRecord,
            index = playingRecord.filteredRecordsIndex {

            let indexPath = NSIndexPath(forRow: index, inSection: 0)

            redrawRecordsAtIndexPaths([indexPath])
        }
    }

    func remoteMp3Player(player: RemoteMp3Player, raisedError error: NSError, withMessage message: String) {
        appLogError(error, withMessage: message)
    }
}

// #MARK: - UITableViewDataSource

extension SearchCatalog: UITableViewDataSource {
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        return DataModel.filteredRecords.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        assert(appIsMainThread())
        assert(player != nil)

        let cellId = CellId.recordCell
        let cell = tableView.dequeueReusableCellWithIdentifier(cellId) as! UITableViewCell
        let recordIndex = indexPath.row

        assert(recordIndex < DataModel.filteredRecords.count)

        let record = DataModel.filteredRecords[indexPath.row]

        if let index = find(DataModel.playlist, record) {
            // #TODO: create struct with colors
            cell.backgroundColor = UIColor(red: 250/255.0, green: 239/255.0, blue: 219/255.0, alpha: 1)
        }
        else {
            cell.backgroundColor = UIColor.whiteColor()
        }

        if let authorLbl = cell.viewWithTag(100) as? UILabel {
            authorLbl.text = record.author
        }

        if let titleLbl = cell.viewWithTag(200) as? UILabel {
            titleLbl.text = record.title
        }

        if let playBtn = cell.viewWithTag(300) as? UIButton,
            pauseBtn = cell.viewWithTag(400) as? UIButton,
            activityIndicator = cell.viewWithTag(500) as? UIActivityIndicatorView {

            let isNowPlayingRecord = (DataModel.playingRecord === record)

            if record.hasNoPlayableTrack {
                if !playBtn.hidden { playBtn.hidden = true }
                if !pauseBtn.hidden { pauseBtn.hidden = true }
                if activityIndicator.isAnimating() { activityIndicator.stopAnimating() }
            }
            else if DataModel.playingRecord === record {
                let playbackStatus = player!.playbackStatus
                // println("-------- REDRAW CELL of playing record (index: \(indexPath.row), status: \(playbackStatus.rawValue))")
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

        return cell
    }

    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let height: CGFloat = 88

        return height
    }
}

// #MARK: - UITableViewDelegate

extension SearchCatalog: UITableViewDelegate {
    func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {

        if searchBar.isFirstResponder() {
            // #TODO: make keyboard disappear even if we touch screen
            searchBar.resignFirstResponder()
            return nil
        }

        let recordIndex = indexPath.row

        assert(recordIndex < DataModel.filteredRecords.count)

        let record = DataModel.filteredRecords[recordIndex]

        if DataModel.playlistContainsRecord(record) {
            DataModel.playlistRemoveRecord(record)
        }
        else {
            DataModel.playlistAddRecord(record)
        }

        redrawRecordsAtIndexPaths([indexPath])
        toggleDisablePlaylistTab()

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
        // println("search button clicked, search string: '\(searchBar.text)'")
        searchBar.resignFirstResponder()
        DataModel.filterRecordsWhichContainText(searchBar.text)
        tableView.reloadData()
    }

    func positionForBar(bar: UIBarPositioning) -> UIBarPosition {
        return .TopAttached
    }
}
