//
// Copyright (©) Akshay Hegde
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//
//  LyricalPreferenceController.swift
//  Lyrical
//
//  Created by Akshay Hegde on 8/27/14.
//  Copyright (c) Akshay Hegde. All rights reserved.
//

import Cocoa

/// Controls Lyrical's Preferences. For now, only contains Last.fm authentication.
final class LyricalPreferenceController: NSWindowController {

  // MARK: Outlets
  @IBOutlet weak var authenticateButton: NSButton?
  @IBOutlet weak var descriptionText: NSTextField?
  @IBOutlet weak var infoText: NSTextField?
  @IBOutlet weak var lyricsAlignmentControl: NSSegmentedControl?
  @IBOutlet weak var lyricsFontSizeControl: NSSegmentedControl?

  /// The stored Last.fm Session Key if applicable.
  private var sessionKey: String?

  /// The connected user if applicable
  private var userName: String?

  /// AppController delegate used to enable menu bar items
  var appControllerDelegate: AppController?

  // MARK: Initializer
  convenience init() {
    self.init(windowNibName: NSNib.Name("LyricalPreferenceView"))
    let defaults = UserDefaults.standard

    if let key = defaults.string(forKey: Scrobbling.session) {
      sessionKey = key
      if let name = defaults.string(forKey: Scrobbling.user) {
        userName = name
      }
    }
  }

  // MARK: Window life cycle
  override func windowDidLoad() {
    super.windowDidLoad()

    // Restore checkbox state
    let groupedDefaults = UserDefaults(suiteName: LyricalSuite.group)
    if sessionKey != nil {
      let loggedIn = NSLocalizedString("Logged in as: ", comment: "Logged in as:")
      let reauthenticate = NSLocalizedString("Reauthenticate", comment: "Reauthenticate")

      authenticateButton?.title = reauthenticate
      if let userName = userName {
        let lastfm = LastFMController.sharedInstance
        lastfm.preferenceDelegate = self
        descriptionText?.stringValue = loggedIn + "\(userName)"
      } else {
        descriptionText?.stringValue = ""
      }
    }

    // Get the stored lyrics alignment otherwise choose 1 for .Center alignment
    let alignmentSegment = groupedDefaults?.integer(forKey: WidgetOptions.Lyrics.alignment) ?? 1
    let fontSegment = groupedDefaults?.integer(forKey: WidgetOptions.Lyrics.fontSizeOption) ?? 1

    lyricsAlignmentControl?.selectedSegment = alignmentSegment
    lyricsFontSizeControl?.selectedSegment = fontSegment

    super.windowDidLoad()
  }

  override func showWindow(_ sender: Any?) {
    if sessionKey != nil {
      let lastfm = LastFMController.sharedInstance
      lastfm.preferenceDelegate = self
      lastfm.get(.scrobbleCount)
    }
    super.showWindow(sender)
  }

  // MARK: Actions/Selectors

  @IBAction func authenticateClicked(_: NSButton?) {
    let lastfm = LastFMController.sharedInstance
    lastfm.preferenceDelegate = self
    lastfm.authenticateUser()
  }

  @IBAction func lyricsAlignmentChanged(_ sender: NSSegmentedControl) {
    let selectedSegment = sender.selectedSegment
    let groupedDefaults = UserDefaults(suiteName: LyricalSuite.group)
    groupedDefaults?.set(selectedSegment, forKey: WidgetOptions.Lyrics.alignment)
    groupedDefaults?.synchronize()
  }

  @IBAction func lyricsFontSizeChanged(_ sender: NSSegmentedControl) {
    let selectedSegment = sender.selectedSegment
    let groupedDefaults = UserDefaults(suiteName: LyricalSuite.group)
    groupedDefaults?.set(selectedSegment, forKey: WidgetOptions.Lyrics.fontSizeOption)
    groupedDefaults?.synchronize()
  }

  /// Fetches the session key from Last.fm
  @objc func getSession() {
    LastFMController.sharedInstance.startSession()
  }

  /// Update the scrobble count along with the average scrobbles per day
  /// - Parameter scrobbleCount: the number of scrobbles for the user
  /// - Parameter registeredDate: the date the user registered on in Unix time
  func updateScrobbleCount(_ scrobbleCount: Int, registeredDate: Int) {
    let playcount = Double(scrobbleCount)

    // Use a separator for scrobble count, using current locale, to make it easier to read
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    guard let formattedPlaycount = formatter.string(from: NSNumber(value: playcount)) else {
      return
    }

    // Calculate the difference between today's date and user's registered date
    let today = Date()
    let registeredOn = Date(timeIntervalSince1970: TimeInterval(registeredDate))
    let interval = today.timeIntervalSince(registeredOn)

    // Calculate the interval in days, and update user info text
    let intervalInDays = round(interval / (60 * 60 * 24))
    print("It has been \(intervalInDays) days since user registered with Last.fm")
    let average = round((playcount / intervalInDays) * 1000) / 1000
    let info = "Scrobbled \(formattedPlaycount) songs, \(average) per day"

    DispatchQueue.main.async { [weak self] in
      self?.infoText?.stringValue = info
    }
  }

  /// Update the LastFM description text in the Preferences Window
  func updateLastFMInfo() {
    guard let delegate = appControllerDelegate else {
      print("Tried to get Session key but AppController delegate was nil.")
      return
    }
    let lastfm = LastFMController.sharedInstance
    let loggedIn = NSLocalizedString("Logged in as: ", comment: "Logged in as:")
    let authenticated = NSLocalizedString("Authenticated!", comment: "Authenticated!")

    DispatchQueue.main.async { [weak self] in
      if let name = lastfm.userName {
        self?.descriptionText?.stringValue = loggedIn + "\(name)"
        self?.authenticateButton?.title = authenticated
        self?.authenticateButton?.action = nil

        // Enable hidden items.
        delegate.menubarItems.forEach { $0?.isHidden = false }
        delegate.enableScrobblingItem?.state = .on
        delegate.startListeningForSongChanges()
      } else {
        self?.descriptionText?.stringValue = NSLocalizedString(
          "You haven't authenticated with Last.fm yet!",
          comment: "You haven't authenticated with Last.fm yet!")
      }
    }
  }
}
