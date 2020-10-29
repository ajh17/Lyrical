//
// Copyright (©) Akshay Hegde
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//
//  AppController.swift
//  Lyrical
//
//  Abstract: Acts as Lyrical's Application Delegate.
//  Created by Akshay Hegde on 7/22/14.
//  Copyright (c) Akshay Hegde. All rights reserved.
//

import Cocoa

extension NSMenuItem {
  /// Returns true if the current state of `self` is NSOnState, otherwise returns false
  var isOnState: Bool { state == .on }
}

enum AEPermissionStatus {
  case permitted
  case notPermitted
  case notApplicable
}

final class AppController: NSObject, NSApplicationDelegate {

  // MARK: Outlets
  @IBOutlet var statusMenu: NSMenu?
  @IBOutlet weak var rateBarItem: NSMenuItem?
  @IBOutlet weak var loveMenuItem: NSMenuItem?
  @IBOutlet weak var dislikeMenuItem: NSMenuItem?
  @IBOutlet weak var scrobblingSpearator: NSMenuItem?
  @IBOutlet weak var enableScrobblingItem: NSMenuItem?

  // MARK: Stored Properties
  /// The icon that displays in the menu bar.
  private let STATUS_TITLE = "♫"

  /// The rating scale multiplier.
  private let RATING_SCALE = 20

  /// Allows access to user preferences.
  private let defaults: UserDefaults

  /// Music player object
  private let musicPlayer: AnyObject!

  /// Lyrical's About Window.
  private var aboutController: LyricalAboutController?

  /// Lyrical's FirstRun Window that shows user how to enable Lyrical's widget.
  private var firstRunController: FirstRunWindowController?

  /// Lyrical's Preferences Window.
  private var preferenceController: LyricalPreferenceController?

  /// Lyrica's Song Controller to control the music player's playback and fetch Song information.
  private let songController: SongController

  /// Lyrical's menu bar item that holds a popup list of menu items.
  private var statusBarItem: NSStatusItem?

  // Can the song be scrobbled?
  private var songCanBeScrobbled: Bool

  // Store Song to be scrobbled
  private var songToBeScrobbled: Song?

  // Are we currently sending a 'Now Playing' request to Last.fm?
  private var isNowPlaying: Bool

  /// Timestamp to record the time the track started playing
  private var startTimeStamp: Double?

  // MARK: Computed Properties

  /// - Returns: true if user has enabled the scrobbling feature, false otherwise.
  private var isScrobblingEnabled: Bool {
    defaults.bool(forKey: Scrobbling.enabled)
  }

  // MARK: Lazy Properties
  lazy var menubarItems: [NSMenuItem?] = self.setupMenuBarItems()

  /// Initializes the AppController object
  override init() {
    defaults = UserDefaults.standard
    musicPlayer = SBApplication(bundleIdentifier: MusicPlayer.bundleIdentifier)
    songController = SongController()
    songCanBeScrobbled = false
    isNowPlaying = false
    super.init()
  }

  override func awakeFromNib() {
    super.awakeFromNib()
    let firstRun = defaults.bool(forKey: LyricalOptions.firstRunFinished)

    // NOTE: The -1 length here is for NSVariableStatusItemLength.
    statusBarItem = NSStatusBar.system.statusItem(withLength: -1)
    statusBarItem?.button?.title = STATUS_TITLE
    statusBarItem?.menu = statusMenu

    // Show the FirstRunWindow when Lyrical is first launched.
    if !firstRun {
      firstRunController = FirstRunWindowController()
      firstRunController?.window?.center()
      firstRunController?.window?.makeKey()
      firstRunController?.showWindow(self)
      activateCurrentApp()
    }

    // Request permission from user to send Apple Events to the music player.
    // If not authorized, let the user know what they can do to rectify, and then quit Lyrical,
    // because we can't do anything else at this point.
    checkAEAuthorized()

    // Observe when the music player launches
    let notificationCenter = NSWorkspace.shared.notificationCenter
    notificationCenter.addObserver(
      self, selector: #selector(musicPlayerLaunched),
      name: NSApplication.didFinishLaunchingNotification, object: nil)
    evaluateMenuItems()
    startListeningForSongChanges()
  }

  private func checkAEAuthorized() {
    if promptUserForPermission() != .permitted {
      let alertResponse = displayAENotAuthorizedAlert()
      if alertResponse == .alertSecondButtonReturn {
        NSApplication.shared.terminate(self)
      } else if alertResponse == .alertFirstButtonReturn {
        let prefsURL = "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        guard let url = URL(string: prefsURL) else {
          NSApplication.shared.terminate(self)
          return
        }
        NSWorkspace.shared.open(url)
        NSApplication.shared.terminate(self)
      }
    }
  }

  private func displayAENotAuthorizedAlert() -> NSApplication.ModalResponse {
    let alert = NSAlert()
    alert.messageText = "Lyrical needs permission to control Music app"
    alert.informativeText = """
      Lyrical cannot show you song information, or allow you to control Music.app's playback unless permission is granted.

      Please change this setting in System Preferences and then relaunch Lyrical.

      Lyrical will now quit.
      """
    alert.alertStyle = .warning
    alert.addButton(withTitle: "Change Security & Privacy Preferences")
    alert.addButton(withTitle: "OK")
    return alert.runModal()
  }

  private func promptUserForPermission() -> AEPermissionStatus {
    print("Checking for permissions to Music app...")
    var addressDesc = AEAddressDesc()
    guard let targetBundleID = MusicPlayer.bundleIdentifier.cString(using: .utf8) else {
      return .notApplicable
    }
    AECreateDesc(typeApplicationBundleID, targetBundleID, targetBundleID.count, &addressDesc)
    let status = AEDeterminePermissionToAutomateTarget(
      &addressDesc, typeWildCard, typeWildCard, true)

    if case noErr = status {
      print("Authorization is granted to Lyrical to send Apple Events to Music app.")
      return .permitted
    }

    print("User has denied permission to send Apple Events to Music app. Error code: \(status)")
    return .notPermitted
  }

  @objc func musicPlayerLaunched(_ note: Notification) {
    let applicationKey = (note as NSNotification).userInfo?["NSWorkspaceApplicationKey"]

    guard let appKey = applicationKey as? NSRunningApplication else {
      return
    }
    if appKey.bundleIdentifier == MusicPlayer.bundleIdentifier {
      print("Music app just launched. Starting to observe song changes...")
      startListeningForSongChanges()
    }
  }

  // MARK: Last.FM Listeners

  /// Shows menu items related to current playing tracks or Last.fm
  func evaluateMenuItems() {
    self.evaluateSongMenuItems()

    let sessionKey = defaults.string(forKey: Scrobbling.session)
    guard sessionKey != nil else {
      return
    }

    menubarItems.forEach { $0?.isHidden = false }
    enableScrobblingItem?.state = isScrobblingEnabled ? .on : .off
  }

  /// Changes the state of Love/Dislike/Rating menu items depending on the current playing song
  private func evaluateSongMenuItems() {
    if songController.isRunning && !songController.isStopped {
      rateBarItem?.isHidden = false

      loveMenuItem?.isHidden = false
      loveMenuItem?.state = songController.isLoved ? .on : .off

      dislikeMenuItem?.isHidden = false
      dislikeMenuItem?.state = songController.isDisliked ? .on : .off
    } else {
      rateBarItem?.isHidden = true

      loveMenuItem?.isHidden = true
      loveMenuItem?.state = .off

      dislikeMenuItem?.isHidden = true
      dislikeMenuItem?.state = .off
    }
  }

  /// Listens for song changes and starts scrobbling to Last.fm (if enabled)
  func startListeningForSongChanges() {
    guard songController.isRunning && isScrobblingEnabled else {
      print("Music app is not running or scrobbling isn't enabled -- not starting observers!")
      return
    }

    print("Starting Music app observers...")
    let distributedCenter = DistributedNotificationCenter.default()
    let stateChangeSelector = #selector(musicPlayerStateChanged)
    let playerNotification = NSNotification.Name(rawValue: MusicPlayer.playerInfoIdentifier)

    distributedCenter.addObserver(
      self, selector: stateChangeSelector,
      name: playerNotification,
      object: MusicPlayer.playerIdentifier,
      suspensionBehavior: .drop)

    // When Lyrical is launched, check if a song is already playing
    if songController.isPlaying {
      musicPlayerStateChanged(nil)
    }
  }

  // MARK: - Selectors

  /// Publish 'Now Playing' status and start scrobble timer.
  @objc func musicPlayerStateChanged(_: Notification?) {
    print("Music app State Change detected: \(songController.playerState)")
    evaluateSongMenuItems()

    guard isScrobblingEnabled else {
      print("Scrobbling is not enabled. Ignoring Music app State Change")
      return
    }

    // Check if we should scrobble any previous or paused songs
    if isNowPlaying && songCanBeScrobbled {
      print("Music app State Changed: scrobbling song")
      scrobbleSong()
    }

    startTimeStamp = Date().timeIntervalSince1970

    // This timer is needed to allow Music app to fully quit if it's in the process of doing so.
    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5), execute: processLastFmEvents)
  }

  /// Processes Last.fm events like posting a NowPlaying notification or publishing a scrobble
  func processLastFmEvents() {
    // Gather the current playing Song's information but first ensure Music app is running
    guard songController.isRunning else {
      print("Music app isn't running -- removing observers")
      removeObservers()
      return
    }

    print("Starting with fresh Now Playing data")
    guard songController.isPlaying else {
      print("Music app is paused.")
      return
    }

    guard let currentTrack = musicPlayer.currentTrack, let track = currentTrack else {
      print("Couldn't read track information.")
      return
    }
    guard let name = track.name, let artist = track.artist, let album = track.album else {
      print("Coudn't read track information")
      return
    }

    // Don't scrobble movies
    let isMediaSongType = track.mediaKind == MusicEMdKSong
    print("Media Kind is song: \(track.mediaKind == MusicEMdKSong)")
    guard isMediaSongType else {
      print("Media isn't a song, ignoring state change.")
      return
    }

    let timestamp = Int(startTimeStamp ?? 0)
    let current = Song(
      name: name, artist: artist, album: album,
      finish: track.finish, timestamp: timestamp)

    sendToLastFM(forMethod: .nowPlaying, forSong: current)

    // Initially assume that song can't yet be scrobbled
    songCanBeScrobbled = false
    isNowPlaying = true

    // Start scrobble timer to determine if a song can be scrobbled
    // Per Last.fm API, scrobble only if a track is longer than 30 seconds.
    let minScrobbleTime = Int(min(ceil(track.finish / 2), 240.0))
    guard track.finish > 30 else {
      print("Not scrobbling song since it's less than 30 seconds: \(track.finish)")
      return
    }

    songToBeScrobbled = current
    let deadline = DispatchTime.now() + .seconds(minScrobbleTime)
    DispatchQueue.main.asyncAfter(deadline: deadline, execute: setSongToScrobble)
  }

  /// Set the current playing song to be scrobbled as it passed minimum scrobble time
  func setSongToScrobble() {
    print("Setting current song to be scrobbled.")
    songCanBeScrobbled = true
  }

  /// Scrobbles (i.e. publishes) the cached track to user's Last.fm profile.
  func scrobbleSong() {
    guard let song = songToBeScrobbled else {
      return
    }

    sendToLastFM(forMethod: .scrobble, forSong: song)

    // Reset scrobble and now playing flags
    songCanBeScrobbled = false
    isNowPlaying = false
    songToBeScrobbled = nil
  }

  // MARK: Actions

  @IBAction func enableScrobbling(_ sender: NSMenuItem) {
    defaults.set(!sender.isOnState, forKey: Scrobbling.enabled)

    print("Synchronizing Scrobbling Enabled State to: \(!sender.isOnState)")
    defaults.synchronize()

    if sender.isOnState {
      sender.state = .off
    } else {
      sender.state = .on
      startListeningForSongChanges()
    }
  }

  @IBAction func showAboutWindow(_: NSMenuItem) {
    if aboutController == nil {
      aboutController = LyricalAboutController()
      aboutController?.window?.center()
    }
    aboutController?.showWindow(nil)
    activateCurrentApp()
  }

  @IBAction func showPreferenceWindow(_: NSMenuItem) {
    if preferenceController == nil {
      preferenceController = LyricalPreferenceController()
      preferenceController?.appControllerDelegate = self
      preferenceController?.window?.center()
    }
    preferenceController?.showWindow(nil)
    activateCurrentApp()
  }

  @IBAction func rateSong(_ sender: NSMenuItem) {
    if songController.isRunning {
      songController.set(songRating: sender.tag * RATING_SCALE)
    }
  }

  @IBAction func loveCurrentSong(_: NSMenuItem?) {
    if songController.isRunning && !songController.isStopped {
      let isLoved = songController.isLoved

      if isLoved {
        songController.set(isLoved: false)
        loveMenuItem?.state = .off
        evaluateActionOnSongForMethod(.unlove)
      } else {
        songController.set(isLoved: true)
        loveMenuItem?.state = .on
        dislikeMenuItem?.state = .off  // If loved, unset disliked since a song can't be both
        songController.set(songRating: 100)  // If loved, rate the song as 5 stars
        evaluateActionOnSongForMethod(.love)
      }
    }
  }

  @IBAction func dislikeCurrentSong(_: NSMenuItem?) {
    if songController.isRunning && !songController.isStopped {
      let isDisliked = songController.isDisliked

      if isDisliked {
        songController.set(isDisliked: false)
        dislikeMenuItem?.state = .off
      } else {
        songController.set(isDisliked: true)
        dislikeMenuItem?.state = .on
        loveMenuItem?.state = .off  // if disliked, unset loved since a song can't be both
        songController.set(songRating: 10)  // 10 for 0.5/5 star rating
        evaluateActionOnSongForMethod(.unlove)
      }
    }
  }

  @IBAction func quitLyrical(_: NSMenuItem?) {
    let isScrobbling = defaults.bool(forKey: Scrobbling.enabled)
    let isSuppressed = defaults.bool(forKey: LyricalOptions.suppressQuitAlert)

    // If user is connected to last.fm, warn the user that quitting Lyrical
    // will stop scrobbling the songs. Also store the preference to disk.
    if isScrobbling && !isSuppressed {
      showQuitWarning()
    } else {
      NSApplication.shared.terminate(self)
    }
  }

  // MARK: Helpers

  private func sendToLastFM(forMethod method: APIMethod, forSong song: Song) {
    let lastfm = LastFMController.sharedInstance
    lastfm.currentSong = song

    lastfm.post(method)
  }

  /// Activates the current running app
  private func activateCurrentApp() {
    let currentApp = NSRunningApplication.current
    currentApp.activate(options: .activateIgnoringOtherApps)
  }

  /// Decides whether to love or unlove a track depending on the API method provided.
  /// - Parameter method: The APIMethod .love or .unlove for loving/unloving a song
  private func evaluateActionOnSongForMethod(_ method: APIMethod) {
    let isNotStopped = !songController.isStopped

    guard let musicPlayerRunning = musicPlayer.isRunning, musicPlayerRunning else {
      removeObservers()
      return
    }

    guard let currentTrack = musicPlayer.currentTrack, let track = currentTrack else {
      return
    }
    guard isNotStopped, [.love, .unlove].contains(method) else {
      return
    }

    if let name = track.name, let artist = track.artist {
      sendToLastFM(
        forMethod: method,
        forSong: Song(name: name, artist: artist, album: ""))
    }
  }

  /// Create a new NSAlert instance and design it for a Quit dialog.
  /// :return: The NSAlert instance designed for a Quit dialog
  private func createQuitAlert() -> NSAlert {
    let alertWindow = NSAlert()
    alertWindow.addButton(withTitle: "Quit")
    alertWindow.addButton(withTitle: "Cancel")

    alertWindow.messageText = "Are you sure you want to quit?"
    alertWindow.informativeText =
      "Lyrical is about to quit. " + "This will stop scrobbling songs to Last.fm."
    alertWindow.showsSuppressionButton = true

    return alertWindow
  }

  /// Warn user that Lyrical will stop scrobbling when it's quit.
  private func showQuitWarning() {
    let alertWindow = createQuitAlert()
    activateCurrentApp()

    let modalResponse = alertWindow.runModal()
    if modalResponse == .alertFirstButtonReturn {
      let isSupressed = alertWindow.suppressionButton?.state == .on
      defaults.set(isSupressed, forKey: LyricalOptions.suppressQuitAlert)
      defaults.synchronize()
      removeObservers()
      NSWorkspace.shared.notificationCenter.removeObserver(self)
      NSApplication.shared.terminate(self)
    }
  }

  private func removeObservers() {
    let defaultCenter = DistributedNotificationCenter.default()
    let playerNotification = NSNotification.Name(rawValue: MusicPlayer.playerInfoIdentifier)
    defaultCenter.removeObserver(
      self, name: playerNotification, object: MusicPlayer.playerIdentifier)
  }

  /// - Returns: An array containing the Last.fm menu bar items.
  func setupMenuBarItems() -> [NSMenuItem?] {
    [scrobblingSpearator, enableScrobblingItem]
  }
}
