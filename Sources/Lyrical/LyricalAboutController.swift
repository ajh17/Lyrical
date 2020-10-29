//
// Copyright (©) Akshay Hegde
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//
//  AboutViewController.swift
//  Lyrical
//
//  Created by Akshay Hegde on 8/27/14.
//  Copyright (c) Akshay Hegde. All rights reserved.
//

import Cocoa

/// An About Window that has links to Twitter and Last.fm profiles, and a review link.
final class LyricalAboutController: NSWindowController {

  private let twitterURL = "https://twitter.com/@LyricalToday"
  private let rateURL = "macappstore://itunes.apple.com/us/app/lyrical/id924743736"
  private let lastfmURL = "https://last.fm/user/ozymandias90"
  @IBOutlet weak var versionField: NSTextField?

  /// Stroes the keys to this app's Info.plist file.
  struct BundleKey {
    /// This App's Version number.
    static let Version = "CFBundleShortVersionString"

    /// This App's Build number.
    static let Build = "CFBundleVersion"
  }

  convenience init() {
    self.init(windowNibName: NSNib.Name("LyricalAboutView"))
  }

  override func windowDidLoad() {
    super.windowDidLoad()

    DispatchQueue.global(qos: .userInitiated).async {
      let bundle = Bundle.main

      guard let version = bundle.object(forInfoDictionaryKey: BundleKey.Version) as? String,
        let build = bundle.object(forInfoDictionaryKey: BundleKey.Build) as? String
      else {
        return
      }

      DispatchQueue.main.async { [unowned self] in
        self.versionField?.stringValue = "Version: \(version) (\(build))"
      }
    }
  }

  /// Opens Twitter.
  @IBAction func twitterButtonClicked(_: NSButton) {
    guard let twitter = URL(string: twitterURL) else { return }
    NSWorkspace.shared.open(twitter)
  }

  /// Opens Mac App Store for rating Lyrical
  @IBAction func rateButtonClicked(_: NSButton) {
    guard let rate = URL(string: rateURL) else { return }
    NSWorkspace.shared.open(rate)
  }

  /// Opens up Last.fm profile page.
  @IBAction func lastfmButtonClicked(_: NSButton) {
    guard let lastfm = URL(string: lastfmURL) else { return }
    NSWorkspace.shared.open(lastfm)
  }
}
