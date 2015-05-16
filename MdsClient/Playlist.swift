//
//  Playlist.swift
//  MdsClient
//
//  Created by Evgeniy Pozdnyakov on 2015-04-30.
//  Copyright (c) 2015 Evgeniy Pozdnyakov. All rights reserved.
//

import UIKit

class Playlist: UIViewController {
    // #MARK: - ivars

    var cellReloadTimer: NSTimer?
    var storedLocallyList: [Record]?
    var hasNoPlayableTrackList: [Record]?
    var player: RemoteMp3Player?

    @IBOutlet weak var playlistTable: UITableView!

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

        player = RemoteMp3Player()
        player!.delegate = self
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        // println("playlist will appear")
        storedLocallyList = [Record]()
        hasNoPlayableTrackList = [Record]()
        for record in DataModel.playlist {
            if record.isStoredLocally {
                storedLocallyList!.append(record)
            }
            else if record.hasNoPlayableTrack {
                hasNoPlayableTrackList!.append(record)
            }
        }

        // #TODO: do not reload if data hasn't changed
        playlistTable.reloadData()


        runCellReloadTimer()
    }

    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)

        // println("playlist did disappear")
        stopCellReloadTimer()
        storedLocallyList = nil
        hasNoPlayableTrackList = nil
    }

    // #MARK: - run/stop cell reloader

    /**
        Creates timer which runs table cell reloading.
        Timer stored in ivar cellReloadTimer.

        Usage:

            runCellReloadTimer()
    */
    func runCellReloadTimer() {
        assert(cellReloadTimer == nil)

        let i = NSTimeInterval(0.25)
        cellReloadTimer = NSTimer.scheduledTimerWithTimeInterval(i, target: self, selector: Selector("reloadDownloadingRecordCells"), userInfo: nil, repeats: true)
        // println("schedule timer")
    }

    /**
        Stops timer which runs table cell reloading.
        There are two places where it can be triggered from:
        - view controller did disappear
        - all the files downloaded & stored locally

        Usage:

            stopCellReloadTimer()
    */
    func stopCellReloadTimer() {
        if let cellReloadTimer = cellReloadTimer {
            cellReloadTimer.invalidate()
            self.cellReloadTimer = nil
            // println("invalidate timer")
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

        println("call startOrResumePlaybackOfRecordAssociatedWithButton")

        if let cell = getCellContainingButton(playBtn),
            record = getRecordAssociatedWithCell(cell),
            indexPath = playlistTable.indexPathForCell(cell) {

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

                    if let index = previousRecord!.playlistIndex {
                        // store previous record cell indexPath
                        indexPathsToRedraw.append(NSIndexPath(forRow: index, inSection: 0))
                    }
                }

                assert(record.localURL != nil)

                // start playing record
                DataModel.playingRecord = record
                player!.startPlayback(url: record.localURL!)
            }

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
            indexPath = playlistTable.indexPathForCell(cell) {

            assert(record == DataModel.playingRecord)

            player!.pausePlayback()
        }
    }

    // #MARK: - redraw

    /**
        Creates [NSIndexPath] for playlist records not stored locally yet, then passes it to redrawRecordsAtIndexPaths().
        If array count is zero, will call stopCellReloadTimer().

        Usage:

            reloadDownloadingRecordCells(indexPaths)
    */
    func reloadDownloadingRecordCells() {
        assert(storedLocallyList != nil)
        assert(hasNoPlayableTrackList != nil)

        var indexPaths = [NSIndexPath]()

        for (i, record) in enumerate(DataModel.playlist) {
            if record.isDownloading {
                indexPaths.append(NSIndexPath(forRow: i, inSection: 0))
            }
            else if record.hasNoPlayableTrack && find(hasNoPlayableTrackList!, record) == nil {
                // reload one last time
                // println("-----------reload last one time row: \(i)")
                indexPaths.append(NSIndexPath(forRow: i, inSection: 0))
                hasNoPlayableTrackList!.append(record)
            }
            else if record.isStoredLocally && find(storedLocallyList!, record) == nil {
                // reload one last time
                // println("-----------reload last one time row: \(i)")
                indexPaths.append(NSIndexPath(forRow: i, inSection: 0))
                storedLocallyList!.append(record)
            }
        }

        redrawRecordsAtIndexPaths(indexPaths)

        if storedLocallyList!.count + hasNoPlayableTrackList!.count == DataModel.playlist.count {
            // println("-------------stopCellReloadTimer")
            stopCellReloadTimer()
        }
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
            self.playlistTable.beginUpdates()
            self.playlistTable.reloadRowsAtIndexPaths(indexPaths, withRowAnimation: .None)
            self.playlistTable.endUpdates()
        }
    }

    // #MARK: miscellaneous

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
        assert(DataModel.playlist.count > 0)

        if let indexPath = playlistTable.indexPathForCell(cell) {
            let recordIndex = indexPath.row

            if recordIndex < DataModel.playlist.count {
                return DataModel.playlist[recordIndex]
            }
        }

        // if for the record wasn't found for some reason, reload table data
        playlistTable.reloadData()

        return nil
    }
}

// #MARK: - RemoteMp3PlayerDelegate

extension Playlist: RemoteMp3PlayerDelegate {
    func remoteMp3Player(player: RemoteMp3Player, statusChanged playbackStatus: MyAVPlayerStatus) {

        // println("================ remoteMp3Player status changed: \(playbackStatus.rawValue)")
        if let playingRecord = DataModel.playingRecord,
            index = playingRecord.playlistIndex {

            let indexPath = NSIndexPath(forRow: index, inSection: 0)

            redrawRecordsAtIndexPaths([indexPath])
        }
    }

    func remoteMp3Player(player: RemoteMp3Player, raisedError error: NSError, withMessage message: String) {
        appLogError(error, withMessage: message)
    }
}

// #MARK: - UITableViewDataSource

extension Playlist: UITableViewDataSource {
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        return DataModel.playlist.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCellWithIdentifier("RecordCell") as! UITableViewCell
        let recordIndex = indexPath.row

        assert(recordIndex < DataModel.playlist.count)

        let record = DataModel.playlist[indexPath.row]

        // println("row: \(indexPath.row)")

        if let authorLbl = cell.viewWithTag(100) as? UILabel,
            titleLbl = cell.viewWithTag(200) as? UILabel,
            playBtn = cell.viewWithTag(300) as? UIButton,
            pauseBtn = cell.viewWithTag(400) as? UIButton,
            activityIndicator = cell.viewWithTag(500) as? UIActivityIndicatorView,
            progressLbl = cell.viewWithTag(600) as? UILabel {

            authorLbl.text = record.author
            titleLbl.text = record.title

            playBtn.hidden = true
            pauseBtn.hidden = true
            progressLbl.hidden = true
            activityIndicator.stopAnimating()

            if record.hasNoPlayableTrack {
                // println("caseAAA")
                progressLbl.text = "!"
                progressLbl.hidden = false
            }
            else if record.isDownloading {
                // println("caseBBBB")
                let progressPercent = lroundf(record.downloadingProgress! * 100)
                progressLbl.text = "\(progressPercent)%"
                progressLbl.hidden = false
            }
            else if record.isStoredLocally {
                // println("caseCCCC")
                if DataModel.playingRecord === record {
                    let playbackStatus = player!.playbackStatus
                    // println("-------- REDRAW CELL of playing record (index: \(indexPath.row), status: \(playbackStatus.rawValue))")

                    switch playbackStatus {
                    case .Playing, .Seeking:
                        pauseBtn.hidden = false
                    case .Paused:
                        playBtn.hidden = false
                    default:
                        activityIndicator.startAnimating()
                    }
                }
                else {
                    playBtn.hidden = false
                }
            }
            else {
                // println("caseDDD")
                activityIndicator.startAnimating()
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

extension Playlist: UITableViewDelegate {
}