//
// Copyright (©) Akshay Hegde
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//
//  Utils.swift
//  Lyrical
//  Description: Contains all Utility value types that are used in the "Lyrical" target
//  Created by Akshay Hegde on 11/16/14.
//  Copyright (c) Akshay Hegde. All rights reserved.
//
import Foundation

/// Describes the Playback request type
enum PlaybackRequest {
  /// Play track
  case play

  /// Pause track
  case pause

  /// Go back to the previous track in the list
  case previousTrack

  /// Skip to the next track in the list
  case nextTrack

  /// Set Music app player position to the given position
  case setPlayerPosition(Int)

  /// Set the rating of Song to the given rating level
  case setRating(Int)

  /// Set the loved rating of Song to the given boolean value
  case setLoved(Bool)

  /// Set the disliked rating of Song to the given boolean value
  case setDisliked(Bool)

  /// Set Music app's sound volume to the given volume level
  case setVolume(Int)

  /// Returns the raw value associated with this `PlaybackRequest`
  var rawValue: String {
    switch self {
    case .play:
      return "play"
    case .pause:
      return "pause"
    case .previousTrack:
      return "previous track"
    case .nextTrack:
      return "next track"
    case .setPlayerPosition(let position):
      return "set player position to \(position)"
    case .setRating(let rating):
      return "set rating of current track to \(rating)"
    case .setLoved(let loved):
      return "set loved of current track to \(loved)"
    case .setDisliked(let disliked):
      return "set disliked of current track to \(disliked)"
    case .setVolume(let volume):
      return "set sound volume to \(volume)"
    }
  }
}

/// Describes the Fetch Request type to execute AppleScript code.
enum FetchRequestType: String {
  /// The Song's title
  case title = "get name of current track"

  /// The Song's Album Artwork
  case artwork = "tell artwork 1 of the current track to raw data"

  /// The Song's Lyrics
  case lyrics = "get lyrics of current track"

  /// The current Music app's player position in the Song.
  case playerPosition = "player position"

  /// Get rating of the Song.
  case rating = "get rating"

  // Get current loved value of the Song.
  case loved = "get loved of current track"

  // Get current dislike value of the Song.
  case disliked = "get disliked of current track"

  /// Get Music app volume level.
  case volume = "get sound volume"

  /// The Song's duration
  case duration = "get duration of current track"

  /// The Song's duration in HH:MM:SS format
  case durationTimeStamp = "get time of current track"

  /// Music app player state (running, paused or stopped)
  case playerState = "get player state as string"

  /// Is Music app currently running?
  case running = "running"

  /// Get basic song information of the current track
  case songInfo = "get (name, artist, album, lyrics, rating, finish) of current track"
}

/// Describes the Last.fm API request types.
enum APIMethod: String {
  /// Last.fm token used to make authenticated API calls.
  case authToken = "auth.gettoken"

  /// Last.fm session token.
  case session = "auth.getsession"

  /// Sending a 'Now Playing' status update to Last.fm
  case nowPlaying = "track.updateNowPlaying"

  /// Request to add the song to the user's Last.fm library
  case scrobble = "track.scrobble"

  /// Request to love the current playing track with Last.fm
  case love = "track.love"

  /// Request to unlove the current playing track with Last.fm
  case unlove = "track.unlove"

  /// Fetch the scrobble count for the logged in user.
  case scrobbleCount = "user.getInfo"

  /// Returns the HTTP method type of the Last API method.
  var httpMethod: String {
    switch self {
    case .authToken, .session, .scrobbleCount: return "GET"
    case _: return "POST"
    }
  }
}

/// Stores variables to control the main Lyrical application behavior
struct LyricalOptions {
  static let firstRunFinished = "FirstRunFinished"
  static let suppressQuitAlert = "SuppressQuitAlert"
}

/// Constants that describe the entire Lyrical Suite
struct LyricalSuite {
  static let group = "enter-your-own"
}

/// Stores the various Widget options for the LyricalToday target
struct WidgetOptions {
  /// Stores Lyrics Options, including font sizes
  struct Lyrics {
    static let alignment = "LyricsAlignment"
    static let expanded = "LyricsExpanded"
    static let fontSizeOption = "FontSizeOption"
    enum FontSize: Float {
      case small = 12.0
      case medium = 14.0
      case large = 16.0
    }
  }
  static let showRemaining = "ShowRemaining"
}

/// Stores the keys for various Last.fm Scrobbling items
struct Scrobbling {
  /// The session key associated with the current LastFM session for the authenticated user
  static let session = "sessionKey"
  /// The authenticated LastFM User key
  static let user = "userName"
  /// Whether or not the authenticated user has enabled Scrobbling to Last.fm
  static let enabled = "ScrobblingEnabled"
}
