//
// Copyright (©) Akshay Hegde
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//
//  TodayViewController.swift
//  LyricalToday
//
//  Created by Akshay Hegde on 7/29/14.
//  Copyright (c) Akshay Hegde. All rights reserved.
//

import Cocoa
import NotificationCenter

extension String {
  /// Returns true if the Lyrics is empty or contains "instrumental", otherwise returns false
  fileprivate var isEmptyOrInstrumental: Bool {
    guard !isEmpty else { return true }
    let currentLyrics = lowercased()
    let instrumentalTexts = ["instrumental", "(instrumental)", "[instrumental]"]
    return instrumentalTexts.contains(currentLyrics)
  }
}

final class TodayViewController: NSViewController, NCWidgetProviding {

  // MARK: - Outlets
  @IBOutlet private weak var albumArtView: ArtworkView?
  @IBOutlet private weak var songTitle: NSTextField?
  @IBOutlet private weak var songArtistAlbum: NSTextField?
  @IBOutlet private weak var songRatingIndicator: NSLevelIndicator?
  @IBOutlet private weak var songRatingCell: SongRatingLevelIndicatorCell?
  @IBOutlet private weak var playButton: NSButton?
  @IBOutlet private weak var soundVolume: NSSlider?
  @IBOutlet private weak var progressBar: ScrubberIndicator?
  @IBOutlet private weak var songDurationLabel: DurationTextField?
  @IBOutlet private weak var toggleLyricsButton: NSButton?
  @IBOutlet private var lyricsView: LyricsTextView?
  @IBOutlet weak var songPositionLabel: NSTextField?

  @IBOutlet private weak var mainStackView: NSStackView?
  @IBOutlet private weak var lyricsStackView: NSStackView?
  @IBOutlet private weak var songInfoStackView: NSStackView?

  // MARK: - Stored properties
  /// The multiplier used to convert 0-5 ratings scale to 0-100 (for Music.app)
  private let ratingScale = 20

  /// SongController instance to fetch Song Info and control playback
  private let songController: SongController

  /// The completion handler for widgetPerformUpdateWithCompletionHandler method
  private var completionHandler: ((NCUpdateResult) -> Void)?

  /// The timer used for animating the progress-bar/scrubber
  private var timer: Timer?

  /// User preferences
  private let defaults: UserDefaults

  /// If set, show the remaining time of the current Song instead of total duration.
  var showRemaining: Bool {
    willSet {
      defaults.set(newValue, forKey: WidgetOptions.showRemaining)
    }
    didSet {
      defaults.synchronize()
    }
  }

  // MARK: - Computed Properties

  /// Get the alignment of the lyrics
  private var lyricsTextAlignment: NSTextAlignment {
    let groupedDefaults = UserDefaults(suiteName: LyricalSuite.group)
    let alignmentIndex = groupedDefaults?.integer(forKey: WidgetOptions.Lyrics.alignment) ?? 1

    if alignmentIndex == 0 {
      return NSTextAlignment.left
    } else if alignmentIndex == 2 {
      return NSTextAlignment.right
    }
    return NSTextAlignment.center
  }

  /// Get the font size of the lyrics
  private var lyricsFontSize: CGFloat {
    let groupedDefaults = UserDefaults(suiteName: LyricalSuite.group)
    let fontSize = groupedDefaults?.integer(forKey: WidgetOptions.Lyrics.fontSizeOption) ?? 1

    if fontSize == 0 {
      return CGFloat(WidgetOptions.Lyrics.FontSize.small.rawValue)
    } else if fontSize == 2 {
      return CGFloat(WidgetOptions.Lyrics.FontSize.large.rawValue)
    }
    return CGFloat(WidgetOptions.Lyrics.FontSize.medium.rawValue)
  }

  // MARK: - Enums and Structs
  struct LyricsText {
    static let Hide = NSLocalizedString("Hide Lyrics", comment: "Hide Lyrics")
    static let Show = NSLocalizedString("Show Lyrics", comment: "Show Lyrics")
  }

  enum StackViewIdentifier: String {
    case Lyrics = "lyrics"
    case Artwork = "artwork"
    case AlbumArtist = "albumartist"
    case Progress = "progress"

    var containedStack: StackType {
      switch self {
      case .Artwork, .AlbumArtist: return .SongInfoStack
      case .Lyrics, .Progress: return .MainStack
      }
    }

    enum StackType: String {
      case MainStack
      case SongInfoStack
    }
  }

  /// A type that describes the height of the TodayViewController widget.
  private struct WidgetHeight {
    /// The initial height of the widget when Lyrics are hidden.
    static let Initial: CGFloat = 250.0
    /// The height of the widget when there are lyrics present, but collapsed
    static let Collapsed: CGFloat = 285.0
  }

  /// A type that stores the Playback labels used in the TodayViewController widget.
  private struct PlaybackLabel {
    /// The Label used for the Pause button
    static let Pause = "❚❚"
    /// The Label used for the Play button
    static let Play = "►"
  }

  // MARK: - Initializers
  override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
    defaults = UserDefaults.standard
    showRemaining = defaults.bool(forKey: WidgetOptions.showRemaining)
    songController = SongController()
    super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
  }

  convenience required init(coder aDecoder: NSCoder) {
    self.init(coder: aDecoder)
  }

  // MARK: - View life cycle

  override func awakeFromNib() {
    super.awakeFromNib()

    // Set the initial value of LyricsExpanded to false if not already set.
    if defaults.object(forKey: WidgetOptions.Lyrics.expanded) == nil {
      defaults.set(false, forKey: WidgetOptions.Lyrics.expanded)
      defaults.synchronize()
    }

    // Set some NSTextView's properties (For lyrics)
    lyricsView?.font = NSFont.systemFont(ofSize: lyricsFontSize)

    songTitle?.stringValue = NSLocalizedString("No Song Playing", comment: "No Song Playing")
    songArtistAlbum?.stringValue = "N/A - N/A"
    albumArtView?.image = NSImage(named: "empty_artwork.png")
    songRatingCell?.isHighlighted = true

    progressBar?.todayDelegate = self
    songDurationLabel?.todayDelegate = self
  }

  override func viewWillAppear() {
    // If Music app is running, get current song info
    if songController.isRunning {
      if songController.isStopped {
        hideStackView(forIdentifiers: [.Artwork, .AlbumArtist, .Lyrics, .Progress])

        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
          let volume = self.songController.currentVolume
          DispatchQueue.main.async { [unowned self] in
            self.soundVolume?.intValue = volume
          }
        }
        completionHandler?(.noData)
      } else {
        updateSongInfo()
        updatePlayLabel()
        completionHandler?(.newData)
      }
    } else {
      hideStackView(forIdentifiers: [.Artwork, .AlbumArtist, .Lyrics, .Progress])
      soundVolume?.intValue = 0
      completionHandler?(.noData)
    }
    lyricsView?.alignment = lyricsTextAlignment
  }

  override func viewWillDisappear() {
    invalidateTimer()  // Don't keep running in the background.
  }

  // MARK: Helper Methods

  /// Resizes the superview to a specified height.
  /// - Parameter height: the height of the view to change
  private func resizeHeight(to heightSize: CGFloat) {
    preferredContentSize = NSSize(width: view.bounds.size.width, height: heightSize)
  }

  /// Invalidates the timer.
  private func invalidateTimer() {
    DispatchQueue.main.async {
      self.timer?.invalidate()
      self.timer = nil
    }
  }

  /// Updates the play button depending on Music app's player state
  private func updatePlayLabel() {
    playButton?.title = songController.isPlaying ? PlaybackLabel.Pause : PlaybackLabel.Play
  }

  /// Hide the view indicated by the given stack identifier.
  /// - Parameter stackIdentifier: The identifier which refers to the stack to hide the view from.
  private func hideStackView(forIndentifier identifier: StackViewIdentifier) {
    let containedStack = identifier.containedStack.rawValue
    let stack = containedStack == "MainStack" ? mainStackView : songInfoStackView

    let arrangedSubViews = stack?.arrangedSubviews
    let subviews = arrangedSubViews?.filter { $0.identifier?.rawValue == identifier.rawValue }.first
    guard let view = subviews else { return }

    view.isHidden = true
    if identifier == .Lyrics {
      guard let lyricsTextView = self.lyricsStackView?.arrangedSubviews.first else { return }
      lyricsTextView.isHidden = true
    }
  }

  /// Reveal the view indicated by the given stack identifier.
  /// - Parameter stackIdentifier: The identifier which refers to the stack to reveal the view in.
  private func revealStackView(forIndentifier identifier: StackViewIdentifier) {
    let containedStack = identifier.containedStack.rawValue
    let stack = containedStack == "MainStack" ? mainStackView : songInfoStackView

    let arrangedSubViews = stack?.arrangedSubviews
    let subviews = arrangedSubViews?.filter { $0.identifier?.rawValue == identifier.rawValue }.first
    guard let view = subviews else { return }

    view.isHidden = false
    if identifier == .Lyrics {
      guard let lyricsTextView = self.lyricsStackView?.arrangedSubviews.first else { return }
      lyricsTextView.isHidden = false
    }
  }

  /// Hides several views for the given list of stack identifiers
  /// - Parameter stackIdentifiers: The list of identifiers for which to hide the views for.
  private func hideStackView(forIdentifiers identifiers: [StackViewIdentifier]) {
    for identifier in identifiers {
      hideStackView(forIndentifier: identifier)
    }
  }

  /// Reveals several views for the given list of stack identifiers
  /// - Parameter stackIdentifiers: The list of identifiers for which to reveal the views for.
  private func revealStackView(forIdentifiers identifiers: [StackViewIdentifier]) {
    for identifier in identifiers {
      revealStackView(forIndentifier: identifier)
    }
  }

  // MARK: Widget Update

  /// Updates the widget for potential lyrics text in the current Song.
  /// - Parameter lyrics: The lyrics to set in the widget.
  /// - Parameter expanded: Whether the widget is expanded or collapsed for lyrics.
  private func updateWidget(forLyrics lyrics: String, expanded: Bool) {
    guard !lyrics.isEmptyOrInstrumental else {
      lyricsView?.string = ""
      toggleLyricsButton?.title = ""
      hideStackView(forIndentifier: .Lyrics)
      resizeHeight(to: WidgetHeight.Initial)
      return
    }

    // Lyrics aren't empty, set lyrics based on if widget is expanded or not
    if expanded {
      lyricsView?.string = lyrics
      toggleLyricsButton?.title = LyricsText.Hide
      revealStackView(forIndentifier: .Lyrics)
      if let lyricsScrollView = lyricsView, let height = lyricsScrollView.textHeight {
        resizeHeight(to: WidgetHeight.Initial + height)
      }
    } else {
      revealStackView(forIndentifier: .Lyrics)
      toggleLyricsButton?.title = LyricsText.Show
      resizeHeight(to: WidgetHeight.Collapsed)
    }
  }

  /// Updates the song information to the current playing song.
  private func updateSongInfo() {
    DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
      let duration =
        self.showRemaining
        ? self.songController.timeRemaining : self.songController.durationTimeStamp
      let artwork = self.songController.songArtwork
      let expanded = self.defaults.bool(forKey: WidgetOptions.Lyrics.expanded)
      let (title, artist, album, lyrics, ratings, volume, finish) = self.songController.songInfo

      DispatchQueue.main.async { [unowned self] in
        self.revealStackView(forIdentifiers: [.Artwork, .Progress, .AlbumArtist])
        self.lyricsView?.alignment = self.lyricsTextAlignment
        self.lyricsView?.font = NSFont.systemFont(ofSize: self.lyricsFontSize)
        self.updateWidget(forLyrics: lyrics, expanded: expanded)

        self.songTitle?.stringValue = title
        self.songArtistAlbum?.stringValue = !artist.isEmpty ? "\(artist) - \(album)" : "\(album)"
        self.albumArtView?.image = artwork

        self.songDurationLabel?.stringValue = duration
        self.songRatingIndicator?.integerValue = Int(ratings) / self.ratingScale
        self.soundVolume?.integerValue = Int(volume)

        if let finish = finish {
          self.progressBar?.maxValue = (finish as NSString).doubleValue
        }

        // Update progress bar every second
        self.updateProgressBar()
      }
    }
  }

  /// Updates the progress bar every second if a song is currently playing.
  private func updateProgressBar() {
    if songController.isPlaying {
      timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: updateProgress)
    } else if songController.isPaused {
      invalidateTimer()
      progressBar?.doubleValue = Double(songController.playerPosition)
      songPositionLabel?.stringValue = songController.playerPositionTimeStamp
    } else {
      invalidateTimer()
      progressBar?.doubleValue = 0.0
      songPositionLabel?.stringValue = "0:00"
      songDurationLabel?.stringValue = "0:00"
    }
  }

  // MARK: - Selectors

  func updateProgress(_: Timer?) {
    progressBar?.doubleValue = Double(songController.playerPosition)
    songPositionLabel?.stringValue = songController.playerPositionTimeStamp

    if showRemaining {
      songDurationLabel?.stringValue = songController.timeRemaining
    }

    // Also check for any song changes
    if let title = songController.title, songTitle?.stringValue != title {
      updateSongInfo()
    }
  }

  // MARK: - Actions

  @IBAction func seeMoreClicked(_ sender: NSButton) {
    let expanded = defaults.bool(forKey: WidgetOptions.Lyrics.expanded)
    if expanded {
      lyricsView?.string = ""
      sender.title = LyricsText.Show
      defaults.set(false, forKey: WidgetOptions.Lyrics.expanded)
      self.resizeHeight(to: WidgetHeight.Collapsed)
      self.lyricsStackView?.arrangedSubviews.first?.isHidden = true
    } else {
      DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        let lyrics = self?.songController.songLyrics ?? ""
        guard let alignment = self?.lyricsTextAlignment else { return }

        DispatchQueue.main.async { [weak self] in
          self?.lyricsView?.alignment = alignment
          self?.lyricsView?.string = lyrics
          sender.title = LyricsText.Hide

          guard let textHeight = self?.lyricsView?.textHeight else { return }
          let newHeight = WidgetHeight.Initial + textHeight
          self?.resizeHeight(to: newHeight)
          self?.lyricsStackView?.arrangedSubviews.first?.isHidden = false
          self?.defaults.set(true, forKey: WidgetOptions.Lyrics.expanded)
        }
      }
    }

    lyricsStackView?.layoutSubtreeIfNeeded()
    defaults.synchronize()
  }

  @IBAction func playButtonClicked(_: NSButton) {
    if songController.isPlaying {
      songController.playback(.pause)
      invalidateTimer()
    } else {
      songController.playback(.play)
      updateSongInfo()
    }
    updatePlayLabel()
  }

  @IBAction func previousButtonClicked(_: NSButton) {
    songController.playback(.previousTrack)
    updatePlayLabel()
    invalidateTimer()
    updateSongInfo()
  }

  @IBAction func nextButtonClicked(_: NSButton) {
    songController.playback(.nextTrack)
    updatePlayLabel()
    invalidateTimer()
    updateSongInfo()
  }

  @IBAction func updateRating(_ sender: NSLevelIndicator) {
    songController.set(songRating: sender.integerValue * ratingScale)
    songRatingCell?.isHighlighted = true
  }

  @IBAction func updateSoundVolume(_ sender: NSSlider) {
    songController.set(soundVolume: sender.integerValue)
  }

  // MARK: Widget Management

  override var nibName: NSNib.Name? {
    NSNib.Name("TodayViewController")
  }

  func widgetPerformUpdate(completionHandler: @escaping ((NCUpdateResult) -> Void)) {
    self.completionHandler = completionHandler
    self.completionHandler?(.newData)
  }
}
