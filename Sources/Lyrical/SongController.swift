//
// Copyright (©) Akshay Hegde
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//
//  SongViewController.swift
//  Lyrical
//
//  Created by Akshay Hegde on 7/22/14.
//  Copyright (c) Akshay Hegde. All rights reserved.
//
import AppKit

/// Controls Music app playback and fetches song information.
struct SongController {

  // MARK: - Stored Properties
  private let scriptController = AppleScriptController()

  // MARK: - Computed Properties

  /// Music app's current player state. (read-only)
  var playerState: String { scriptController.playerState }

  /// Is Music app currently stopped (i.e. not playing or paused on a song) (read-only)
  var isStopped: Bool { playerState == "stopped" }

  /// Is Music app actively playing a song (i.e. not paused) (read-only)
  var isPlaying: Bool { playerState == "playing" }

  /// Is Music app paused on a Song? (read-only)
  var isPaused: Bool { playerState == "paused" }

  /// Is Music app currently running? (read-only)
  var isRunning: Bool {
    guard let event = scriptController.fetch(forRequestType: .running),
      let value = event.stringValue
    else {
      return false
    }
    return value == "true"
  }

  /// The Song's title (read-only)
  var title: String? { scriptController.fetch(forRequestType: .title)?.stringValue }

  /// The current Song artwork (read-only)
  var songArtwork: NSImage {
    guard let artwork = scriptController.fetch(forRequestType: .artwork),
      let artworkImage = NSImage(data: artwork.data)
    else {
      return NSImage(named: "empty_artwork.png")!
    }
    return artworkImage
  }

  var isLoved: Bool {
    scriptController.fetch(forRequestType: .loved)?.booleanValue ?? false
  }

  var isDisliked: Bool {
    scriptController.fetch(forRequestType: .disliked)?.booleanValue ?? false
  }

  /// The current song's lyrics (read-only)
  var songLyrics: String {
    scriptController.fetch(forRequestType: .lyrics)?.stringValue ?? ""
  }

  /// Elapsed time of the currently playing track. (read-only)
  var playerPosition: Float {
    let playerPos = scriptController.fetch(forRequestType: .playerPosition)?.stringValue
    if let playerPos = playerPos, let position = Float(playerPos) {
      return position
    }
    return 0.0
  }

  /// The total duration of the current song. (read-only)
  var duration: String {
    scriptController.fetch(forRequestType: .duration)?.stringValue ?? ""
  }

  /// The total duration of the current song in HH:MM:SS format (read-only)
  var durationTimeStamp: String {
    scriptController.fetch(forRequestType: .durationTimeStamp)?.stringValue ?? ""
  }

  /// The song information of the current playing track. (read-only)
  var songInfo: SongInfo {
    scriptController.fetchSongInfo()
  }

  /// Returns the current Music app Volume. (read-only)
  var currentVolume: Int32 {
    scriptController.fetch(forRequestType: .volume)?.int32Value ?? 0
  }

  /// The time remaining of the current song in HH:MM:SS format (read-only)
  var timeRemaining: String {
    let len = scriptController.fetch(forRequestType: .duration)?.stringValue

    guard let songLength = len as NSString? else {
      return "-0:00"
    }

    let elapsed = playerPosition
    let remainingSeconds = Int(songLength.floatValue - elapsed)
    return "-" + formatTime(withSeconds: remainingSeconds)
  }

  /// Music app's player position in HH:MM:SS format
  var playerPositionTimeStamp: String {
    let playerPos = scriptController.fetch(forRequestType: .playerPosition)
    guard let position = playerPos, let seconds = position.stringValue as NSString? else {
      return ""
    }

    return formatTime(withSeconds: Int(seconds.floatValue))
  }

  // MARK: - Methods

  /// Sets the current Song rating.
  /// - Parameter rating: the song rating to set
  func set(songRating rating: Int) {
    scriptController.controlPlayback(forRequest: .setRating(rating))
  }

  /// Sets the current Song loved value.
  /// - Parameter isLoved: Whether or not to set the current long's loved value
  func set(isLoved loved: Bool) {
    scriptController.controlPlayback(forRequest: .setLoved(loved))
  }

  /// Sets the current Song disliked value.
  /// - Parameter isLoved: Whether or not to set the current long's disliked value
  func set(isDisliked disliked: Bool) {
    scriptController.controlPlayback(forRequest: .setDisliked(disliked))
  }

  /// Sets the Music app sound volume.
  /// Parameter volume: the sound volume to set from 0 to 100.
  func set(soundVolume volume: Int) {
    scriptController.controlPlayback(forRequest: .setVolume(volume))
  }

  /// Tells Music app to play the current Song.
  /// - Parameter control: the type of playback request
  func playback(_ request: PlaybackRequest) {
    scriptController.controlPlayback(forRequest: request)
  }

  /// Converts time in seconds to HH:MM:SS format.
  /// - Parameter totalSeconds: the total time in seconds to convert to HH:MM:SS format
  /// - Returns: the total time in HH:MM:SS format
  private func formatTime(withSeconds seconds: Int) -> String {
    let t_seconds = seconds % 60
    let minutes = (seconds / 60) % 60
    let hours = seconds / 3600
    let strHours = hours > 9 ? "\(hours)" : "0" + "\(hours)"
    let strMinutes = minutes > 9 ? "\(minutes)" : "0" + "\(minutes)"
    let strSeconds = t_seconds > 9 ? "\(t_seconds)" : "0" + "\(t_seconds)"

    if hours > 0 {
      return "\(strHours):\(strMinutes):\(strSeconds)"
    }
    return "\(strMinutes):\(strSeconds)"
  }
}
