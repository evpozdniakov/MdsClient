//
//  RemoteMp3Player.swift
//  MdsClient
//
//  Created by Evgeniy Pozdnyakov on 2015-04-17.
//  Copyright (c) 2015 Evgeniy Pozdnyakov. All rights reserved.
//

import Foundation
import AVFoundation

@objc enum MyAVPlayerStatus : Int {
    case Unknown
    case Starting
    case Playing
    case Paused
    case TimeChanging
    case Seeking
}

@objc protocol RemoteMp3PlayerDelegate {
    func remoteMp3Player(player: RemoteMp3Player, statusChanged playbackStatus: MyAVPlayerStatus)

    optional func remoteMp3Player(player: RemoteMp3Player, trackDurationDetected trackDurationMls: Int)

    optional func remoteMp3Player(player: RemoteMp3Player, currentTimeChanged currentTimeMls: Int)

    optional func remoteMp3Player(player: RemoteMp3Player, raisedErrorWithCode code: Int)
}

/**
Able to play remote mp3 in foreground and background.
For playing while in the background class will register audio session,
but you have to configure application capabilities:
https://developer.apple.com/library/ios/qa/qa1668/_index.html
(Playing media while in the background using AV Foundation on iOS)

Usage:

    // create player
    player = RemoteMp3Player()

    // open remote mp3 and start KVO
    player.startPlayback(#url: NSURL)
    player.pause()
    player.resume()
    player.setVolume(value: Float)

    // close connection with mp3 and stop KVO
    player.stop()

    // set delegate and use RemoteMp3PlayerDelegate methods
    player.delegate = self
    func remoteMp3Player(player: RemoteMp3Player, statusChanged playbackStatus: MyAVPlayerStatus)

*/
class RemoteMp3Player: NSObject {
    enum PlaybackAction : Int {
        case None
        case Play
        case Pause
        case Resume
    }

    enum PlaybackError: Int {
        case None
        case UnexpectedStatusOnStart
        case UnexpectedStatusOnPause
        case PausedAtIsNil
        case PlaybackNotPaused
        case UnexpectedStatusOnResume
        case UnexpectedVolume
        case TimerIsNilWhilePlaying
        case TimerNotNilWhilePaused
        case TimerNotNilWhileTimeChanging
        case TimerNotNilWhileSeeking
        case TrackDurationIsNil
        case UnexpectedStatusOnCompleteSeeking
        case PlayerItemIsNil
    }

    var playbackStatus: MyAVPlayerStatus = .Unknown
    var player = AVPlayer()
    var playerItem: AVPlayerItem?
    let playerItemKeysToObserve = ["status"]
    var trackDuration: CMTime?
    var trackDurationMls: Int?
    var pausedAt: CMTime?
    var reportCurrentTimeTimer: NSTimer?
    // #TODO: configure from view
    let redrawTimeSliderInterval = 1.0 // seconds
    var lastPlaybackAction: PlaybackAction = .None
    var delegate: RemoteMp3PlayerDelegate?

    override init() {
        super.init()

        registerAudioSession()
    }

    deinit {
        if playbackStatus == .Playing {
            player.pause()
        }

        stopKeyPathsObserving()
    }

    // #MARK: - playback

    func startPlayback(#url: NSURL) {
        if playbackStatus != .Unknown {
            throwErrorWithCode(.UnexpectedStatusOnStart)
            return
        }

        lastPlaybackAction = .Play

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            self.playerItem = AVPlayerItem(URL: url)
            self.player = AVPlayer(playerItem:self.playerItem)
            self.player.play()
            self.startKeyPathsObserving()
            self.playbackStatus = .Starting
            self.delegate?.remoteMp3Player(self, statusChanged: self.playbackStatus)
        }
    }

    func stop() {
        if playbackStatus == .Playing {
            player.pause()
        }

        stopKeyPathsObserving()

        playerItem = nil
        trackDuration = nil
        trackDurationMls = nil
        pausedAt = nil

        lastPlaybackAction = .None
        playbackStatus = .Unknown

        delegate?.remoteMp3Player(self, statusChanged: playbackStatus)
    }

    func pausePlayback() {
        if playbackStatus == .Paused {
            throwErrorWithCode(.UnexpectedStatusOnPause)
            return
        }

        lastPlaybackAction = .Pause

        pausedAt = player.currentTime()
        player.pause()
        reportCurrentTimeTimer?.invalidate()
        reportCurrentTimeTimer = nil
        playbackStatus = .Paused
        delegate?.remoteMp3Player(self, statusChanged: playbackStatus)
    }

    func resumePlayback() {
        if playbackStatus != .Paused && playbackStatus != .TimeChanging {
            throwErrorWithCode(.UnexpectedStatusOnResume)
            return
        }

        if player.rate > 0 {
            throwErrorWithCode(.PlaybackNotPaused)
            return
        }

        if pausedAt == nil {
            throwErrorWithCode(.PausedAtIsNil)
            return
        }

        lastPlaybackAction = .Resume
        player.play()

        if let pausedAt = pausedAt {
            playbackStatus = .Playing
            delegate?.remoteMp3Player(self, statusChanged: playbackStatus)
            playbackStatus = .Seeking
            delegate?.remoteMp3Player(self, statusChanged: playbackStatus)
            player.seekToTime(pausedAt, completionHandler: seekToTimeCallback)
        }
    }

    func setVolumeTo(value: Float) {
        if value < 0 || value > 1 {
            throwErrorWithCode(.UnexpectedVolume)
            return
        }

        player.volume = value
    }

    func startSeeking() {
        switch (playbackStatus) {
            case .Playing:
                if reportCurrentTimeTimer == nil {
                    throwErrorWithCode(.TimerIsNilWhilePlaying)
                    return
                }
            case .Paused:
                if reportCurrentTimeTimer != nil {
                    throwErrorWithCode(.TimerNotNilWhilePaused)
                    return
                }
            case .TimeChanging:
                if reportCurrentTimeTimer != nil {
                    throwErrorWithCode(.TimerNotNilWhileTimeChanging)
                    return
                }
            case .Seeking:
                if reportCurrentTimeTimer != nil {
                    throwErrorWithCode(.TimerNotNilWhileSeeking)
                    return
                }
            default: break
        }

        reportCurrentTimeTimer?.invalidate()
        reportCurrentTimeTimer = nil
        playbackStatus = .TimeChanging
    }

    func completeSeeking(position: Float) {
        if playbackStatus != .TimeChanging {
            throwErrorWithCode(.UnexpectedStatusOnCompleteSeeking)
            return
        }

        if trackDuration == nil {
            throwErrorWithCode(.TrackDurationIsNil)
            return
        }

        if let trackDuration = trackDuration {
            let value = Float(trackDuration.value) * position
            let seekTo = CMTimeMake(Int64(value), trackDuration.timescale)

            if lastPlaybackAction == .Pause {
                pausedAt = seekTo
            }
            else {
                playbackStatus = .Seeking
                delegate?.remoteMp3Player(self, statusChanged: playbackStatus)
                player.seekToTime(seekTo, completionHandler: seekToTimeCallback)
            }

        }
    }

    func seekToTimeCallback(success: Bool) {
        if success && playbackStatus == .Seeking {
            if player.rate == 0 {
                player.play()
            }
            configureReportCurrentTimeTimer()
            playbackStatus = .Playing
            delegate?.remoteMp3Player(self, statusChanged: playbackStatus)
        }
    }

    func configureReportCurrentTimeTimer() {
        if reportCurrentTimeTimer == nil {
            reportCurrentTimeTimer = NSTimer.scheduledTimerWithTimeInterval(redrawTimeSliderInterval, target: self, selector: Selector("reportCurrentTime"), userInfo: nil, repeats: true)
        }
    }

    // #MARK: - KVO

    func startKeyPathsObserving() {
        for keyPath in playerItemKeysToObserve {
            playerItem?.addObserver(self, forKeyPath: keyPath, options: .New, context: nil)
        }
    }

    func stopKeyPathsObserving() {
        for keyPath in playerItemKeysToObserve {
            playerItem?.removeObserver(self, forKeyPath: keyPath)
        }
    }

    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if playerItem == nil {
            throwErrorWithCode(.PlayerItemIsNil)
            return
        }

        if let playerItem = object as? AVPlayerItem {
            if keyPath == "status" && playerItem.status == .ReadyToPlay {
                trackDuration = playerItem.duration
                trackDurationMls = mlsFromCMTime(trackDuration)

                if let trackDurationMls = trackDurationMls {
                    delegate?.remoteMp3Player?(self, trackDurationDetected: trackDurationMls)
                }

                playbackStatus = .Playing
                configureReportCurrentTimeTimer()
                delegate?.remoteMp3Player(self, statusChanged: playbackStatus)
            }
        }
    }

    // #MARK: - miscellaneous

    func mlsFromCMTime(time: CMTime?) -> Int? {
        if let time = time {
            return lroundf(Float(CMTimeGetSeconds(time)) * 1000)
        }

        return nil
    }

    func reportCurrentTime() {
        if let playerItem = playerItem, trackDurationMls = trackDurationMls {
            let currentTime = playerItem.currentTime()

            if let currentTimeMls = mlsFromCMTime(currentTime) {
                delegate?.remoteMp3Player?(self, currentTimeChanged: currentTimeMls)
            }
        }
    }

    func registerAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        var error: NSError?

        if audioSession.setCategory(AVAudioSessionCategoryPlayback, error: &error) && audioSession.setActive(true, error: &error) {
            // all fine
        }
        else if let error = error {
            println("registering audio session error: \(error)")
        }
        else {
            println("registering audio session unknown error")
        }
    }

    func throwErrorWithCode(error: PlaybackError) {
        let code = error.rawValue
        let msg = "Error with code \(code) raised in RemoteMp3Player"

        println(msg)
        delegate?.remoteMp3Player?(self, raisedErrorWithCode: code)
    }
}