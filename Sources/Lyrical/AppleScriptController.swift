//
// Copyright (©) Akshay Hegde
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//
//  AppleScriptController.swift
//  Lyrical
//
//  Created by Akshay Hegde on 7/29/14.
//  Copyright (c) Akshay Hegde. All rights reserved.
//

import Foundation

typealias SongInfo = (
  title: String, artist: String, album: String,
  lyrics: String, ratings: Int32, volume: Int32, finish: String?
)

/// Executes the AppleScript code based on the request type.
struct AppleScriptController {

  // MARK: - Computed Properties

  /// Returns Music app's current state: playing, paused or stopped.
  var playerState: String {
    let fetchRequest = fetch(forRequestType: .playerState)

    // Assume Music app is stopped if the script failed.
    guard let event = fetchRequest, let value = event.stringValue else {
      return "stopped"
    }

    return value
  }

  // MARK: - Script Execution

  /// Executes the AppleScript source code.
  /// - Parameter source: the AppleScript source code to execute.
  /// - Returns: the result of executing the AppleScript code.
  private func execute(script: String) -> NSAppleEventDescriptor? {
    var errors: NSDictionary?
    let event = NSAppleScript(source: script)?.executeAndReturnError(&errors)

    return event
  }

  // MARK: - Fetch Requests

  /// Fetches song information of the current track
  /// - Returns: the song information of the current track.
  func fetchSongInfo() -> SongInfo {
    let descriptor = fetch(forRequestType: .songInfo)

    let volume = fetch(forRequestType: .volume)?.int32Value ?? 0
    let noSong = NSLocalizedString("No Song Playing", comment: "No Song Playing")
    let noArtist = NSLocalizedString("Artist", comment: "Artist")
    let noAlbum = NSLocalizedString("Album", comment: "Album")

    if let descriptor = descriptor {
      let title = descriptor.atIndex(1)?.stringValue
      let artist = descriptor.atIndex(2)?.stringValue
      let album = descriptor.atIndex(3)?.stringValue
      let lyrics = descriptor.atIndex(4)?.stringValue
      let ratings = descriptor.atIndex(5)?.int32Value
      let finish = descriptor.atIndex(6)?.stringValue

      if let title = title {
        if let lyrics = lyrics {
          return (title, artist!, album!, lyrics, ratings!, volume, finish)
        }
        return (title, artist!, album!, "", 0, volume, finish)
      }
    }
    return SongInfo(noSong, noArtist, noAlbum, "", 0, volume, nil)
  }

  /// Fetches song information for the specified request.
  /// - Parameter request: the type of fetch request being made.
  /// - Returns: The result of executing the request, or nil if an error occurs
  func fetch(forRequestType request: FetchRequestType) -> NSAppleEventDescriptor? {
    let script = "tell app \"\(MusicPlayer.app)\" to \(request.rawValue)"
    return execute(script: script)
  }

  // MARK: - Playback Control

  /// Controls the Music app playback.
  /// - Parameter control: the playback type to control.
  func controlPlayback(forRequest request: PlaybackRequest) {
    let script = "tell app \"\(MusicPlayer.app)\" to \(request.rawValue)"
    _ = execute(script: script)
  }
}
