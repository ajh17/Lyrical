//
// Copyright (©) Akshay Hegde
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//
//  LastFMController.swift
//  Lyrical
//
//  Created by Akshay Hegde on 9/7/14.
//  Copyright (c) Akshay Hegde. All rights reserved.
//
import CryptoKit

extension String {
  /// Generates an MD5 hash of this string.
  fileprivate func md5() -> String {
    Insecure.MD5.hash(data: data(using: .utf8) ?? Data())
      .map { String(format: "%02x", $0) }
      .joined()
  }
}

extension Data {
  /// Returns a UTF8 String encoded version of the data, or nil if it cannot be encoded
  fileprivate func toUTF8String() -> String? {
    String(data: self, encoding: .utf8)
  }
}

extension JSONSerialization {
  /// Parse the JSON as NSDictionary with Mutable Containers
  fileprivate class func parseJSONData(_ data: Data) throws -> NSDictionary? {
    try jsonObject(with: data, options: .mutableContainers) as? NSDictionary
  }
}

/// Controls Last.fm API requests.
final class LastFMController: NSObject {
  // MARK: Properties

  /// Public API Key to communicate with Last.fm
  private let apiKey = "<enter your own Last.fm api key>"

  /// Secret API Key to communicate with Last.fm
  private let secretKey = "<enter your own Last.fm secret key>"

  /// The token used to make authenticated calls to Last.fm
  private var auth_token: String?

  /// The username of the connected Last.fm account.
  var userName: String?

  /// Delegate to enable interapp communication.
  var preferenceDelegate: LyricalPreferenceController?

  /// The current song that is playing.
  var currentSong: Song?

  // MARK: Initialization

  /// The shared LastFMController object.
  class var sharedInstance: LastFMController {
    struct Singleton {
      static let instance = LastFMController()
    }
    return Singleton.instance
  }

  // MARK: - Authentication and Session

  /// Authenticates a user with their Last.fm account using the default browser.
  func authenticateUser() {
    get(.authToken)
  }

  /// Starts the web session using the session key stored on disk.
  /// - Returns: True if session was successfully started, false otherwise.
  func startSession() {
    get(.session)
  }

  // MARK: - Helpers

  /// Returns a UTF8 encoded string using characters allowed in a URL query
  /// - Parameter string: the string to encode
  /// - Parameter isSong: Encode the string for a song
  /// - Returns: the UTF-8 encoded string using characters allowed in URL queries
  private func encodeString(_ string: String, isSong: Bool = false) -> String {
    let allowedChars = CharacterSet.urlQueryAllowed
    let encString = string.addingPercentEncoding(withAllowedCharacters: allowedChars)
    guard let encodedString = encString else { return string }

    // Ensure '&' symbol is properly escaped if we're encoding for a song
    return isSong ? encodedString.replacingOccurrences(of: "%2526", with: "%26") : encodedString
  }

  /// Generates a Last.fm API signature used for authenticated API method calls.
  /// - Parameter method: The Last.fm API method to use for signature generation.
  /// - Returns: an MD5 hashed API Signature for the Last.fm API Method.
  private func signatureForMethod(_ method: APIMethod) -> String? {
    guard method != .scrobbleCount else {
      print("Tried to get signature for \(method)!")
      return ""
    }
    let sk = UserDefaults.standard.string(forKey: Scrobbling.session)

    if method == .session && auth_token == nil {
      print("Tried to generate signature for \(method) but auth_token was nil")
      return nil
    }
    if ![.authToken, .session].contains(method) && sk == nil {
      print("Tried to generate signature for \(method) but session key was nil")
      return nil
    }

    var (track, artist, album, duration) = ("", "", "", 0)
    var timestamp = 0
    if let song = currentSong {
      track = song.name
      artist = song.artist
      album = song.album!
      duration = Int(song.finish)
      timestamp = song.timestamp ?? 0
    }

    // Construct the API method signature based on the type of request
    let sig: String
    let rawMethod = method.rawValue

    switch method {
    case .authToken:
      sig = "api_key\(apiKey)\(rawMethod)\(secretKey)"
    case .session:
      sig = "api_key\(apiKey)method\(rawMethod)token\(auth_token!)\(secretKey)"
    case .nowPlaying:
      sig =
        "album\(album)api_key\(apiKey)artist\(artist)duration\(duration)"
        + "method\(rawMethod)sk\(sk!)track\(track)\(secretKey)"
    case .scrobble:
      sig =
        "album\(album)api_key\(apiKey)artist\(artist)duration\(duration)"
        + "method\(rawMethod)sk\(sk!)timestamp\(timestamp)track\(track)\(secretKey)"
    case .love, .unlove:
      sig =
        "api_key\(apiKey)artist\(artist)method\(rawMethod)sk\(sk!)" + "track\(track)\(secretKey)"
    default:
      return nil
    }

    print("Successfully generated signature for method \(method)")
    return sig.md5()
  }

  // MARK: - Request

  /// Send a HTTP GET request to Last.fm for the specified method.
  /// - Parameter method: the Last.fm API method to send the HTTP GET request to
  func get(_ method: APIMethod) {
    processRequestForMethod(method)
  }

  /// Send a HTTP POST request to Last.fm for the specified method.
  /// - Parameter method: the Last.fm API method to send the HTTP POST request to
  func post(_ method: APIMethod) {
    processRequestForMethod(method)
  }

  /// Processes the HTTP request for the specified method
  /// - Parameter method: the method to process the request for.
  private func processRequestForMethod(_ method: APIMethod) {
    guard let signature = signatureForMethod(method) else { return }

    let isFetchRequest = method.httpMethod == "GET"
    let urlStr = "https://ws.audioscrobbler.com/2.0/?"
    var requestParams = "&api_key=\(apiKey)&api_sig=\(signature)&format=json"

    if isFetchRequest {
      let rawMethod = "method=\(method.rawValue)"
      if case .authToken = method {
        requestParams = rawMethod + requestParams
      } else if case .scrobbleCount = method {
        requestParams = "&api_key=\(apiKey)&format=json"
        let defaults = UserDefaults.standard
        let userName = defaults.object(forKey: Scrobbling.user)
        guard let user = userName as? String else { return }
        requestParams = rawMethod + "&user=\(user)" + requestParams
      } else {
        guard let token = auth_token else { return }
        requestParams = rawMethod + requestParams + "&token=\(token)"
      }
    }

    guard let requestURL = URL(string: urlStr + requestParams) else {
      print("Error when trying to create URL for method \(method).")
      return
    }

    var request = URLRequest(url: requestURL)
    if !isFetchRequest {
      guard let postBody = bodyForMethod(method),
        let postLength = postBody.toUTF8String()?.utf8.count
      else {
        print("Error when constructing POST body for method \(method)")
        return
      }

      request.setValue("\(postLength)", forHTTPHeaderField: "Content-Length")
      request.setValue(
        "application/x-www-form-urlencoded",
        forHTTPHeaderField: "Content-Type")
      request.httpBody = postBody
    }

    request.httpMethod = method.httpMethod
    processResponse(request, forMethod: method)
  }

  /// Return the POST HTTP body to send to Last.fm.
  /// - Parameter method: the method used to prepare the POST body
  /// - Returns the UTF8 String encoded POST HTTP body
  private func bodyForMethod(_ method: APIMethod) -> Data? {
    guard ![.authToken, .session].contains(method) else {
      print("Wrong method \(method) sent to bodyForMethod")
      return nil
    }

    let defaults = UserDefaults.standard
    guard let song = currentSong, let sk = defaults.string(forKey: Scrobbling.session) else {
      print("Error generating body for method \(method): params not set")
      return nil
    }

    let songInfo = [song.name, song.artist, song.album].map {
      $0!.replacingOccurrences(of: "&", with: "%26")
    }
    let (track, artist, album) = (songInfo[0], songInfo[1], songInfo[2])
    let duration = Int(song.finish)
    let timeStamp = song.timestamp

    var body = "method=\(method.rawValue)&"
    switch method {
    case .nowPlaying:
      body += "artist=\(artist)&album=\(album)&duration=\(duration)" + "&track=\(track)&sk=\(sk)"
    case .scrobble:
      guard let time = timeStamp else { return nil }
      body +=
        "artist=\(artist)&album=\(album)&duration=\(duration)"
        + "&timestamp=\(time)&track=\(track)&sk=\(sk)"
    case .unlove, .love:
      body += "track=\(track)&artist=\(artist)&sk=\(sk)"
    default:
      return nil
    }

    return encodeString(body, isSong: true).data(using: String.Encoding.utf8)
  }

  // MARK: - Response

  /// Process the Authentication JSON received from Last.fm
  /// - Parameter data: the authentication JSON
  private func processAuthenticationData(_ data: NSDictionary) {
    // Bail out if parsing failed
    guard let token = data["token"] as? String else {
      print("Failed to obtain authentication token from JSON: \(data)")
      return
    }

    auth_token = token
    let path = "http://www.last.fm/api/auth/?api_key=\(apiKey)&token=\(token)"
    guard let authUrl = URL(string: path) else {
      print("Could not open Last.fm URL to authenticate Lyrical.")
      return
    }

    DispatchQueue.main.async { [weak self] in
      NSWorkspace.shared.open(authUrl)
      self?.preferenceDelegate?.authenticateButton?.title = NSLocalizedString(
        "Refresh Authentication Status", comment: "Refresh Authentication Status")
      let action = #selector(self?.preferenceDelegate?.getSession)
      self?.preferenceDelegate?.authenticateButton?.action = action
    }
  }

  /// Process the Session JSON received from Last.fm
  /// - Parameter data: the Session JSON
  private func processSessionData(_ data: NSDictionary) {
    guard let session = data["session"] as? NSDictionary, let user = session["name"] as? String,
      let key = session["key"] as? String
    else {
      print("Failed to obtain session key from JSON: \(data))")
      return
    }

    userName = user
    print("Authenticated as: \(user)")
    let defaults = UserDefaults.standard
    defaults.set(key, forKey: Scrobbling.session)
    defaults.set(user, forKey: Scrobbling.user)
    defaults.set(true, forKey: Scrobbling.enabled)
    defaults.synchronize()
    preferenceDelegate?.updateLastFMInfo()
  }

  /// Process the Scrobble JSON received from Last.fm
  /// - Parameter data: the Scrobble JSON
  private func processScrobbleData(_ data: NSDictionary) {
    guard let scrobbles = data["scrobbles"] as? NSDictionary,
      let _ = scrobbles["scrobble"]
    else {
      print("Failed to publish scrobble: \(data)")
      return
    }
    print("Sucessfully published Song to Last.fm: \(data)")
  }

  /// Process the NowPlaying JSON received from Last.fm
  /// - Parameter data: the NowPlaying JSON
  private func processNowPlayingData(_ data: NSDictionary) {
    guard let now_playing = data["nowplaying"] as? NSDictionary else {
      print("Failed to publish now playing data: \(data)")
      return
    }
    print("Sucessfully published Now Playing Song to Last.fm: \(now_playing))")
  }

  /// Process the Love/Unlove JSON received from Last.fm
  /// - Parameter data: the Love/Unlove JSON
  private func processLoveStatusData(_ data: NSDictionary) {
    if data.count != 0 {  // Last.fm returns an empty JSON if successfully Loved/Unloved
      print("Failed to Love/Unlove the current Song: \(data)")
      return
    }
    print("Successfully Loved/Unloved current Song: \(data)")
  }

  private func processScrobbleCountData(_ data: NSDictionary) {
    guard let user_info = data["user"] as? NSDictionary,
      let playcount = user_info["playcount"] as? NSString,
      let registered = user_info["registered"] as? NSDictionary,
      let registeredDate = registered["unixtime"] as? NSString
    else {
      print("Failed to get user information from Last.fm: \(data)")
      return
    }
    print("Got playcount for user: \(playcount)")
    print("User registered date: \(registeredDate)")

    let signupDate = Int(registeredDate.doubleValue)
    let playcountInt = Int(playcount.doubleValue)
    preferenceDelegate?.updateScrobbleCount(playcountInt, registeredDate: signupDate)
  }

  /// Process the Response using the given request for the specified method
  /// - Parameter request: The URL request to process
  /// - Parameter forMethod: the Last.fm API method used to process the response
  private func processResponse(_ request: URLRequest, forMethod method: APIMethod) {
    print("Processing response for method \(method)")
    let session = URLSession.shared

    let task = session.dataTask(with: request) { (optData, _, error) in
      if let error = error {
        print("Error communicating with last.fm: \(error.localizedDescription)")
        return
      }
      guard let data = optData, let jsonData = try? JSONSerialization.parseJSONData(data) else {
        print("Failed to parse JSON for method \(method)")
        return
      }

      switch method {
      case .authToken:
        self.processAuthenticationData(jsonData)
      case .session:
        self.processSessionData(jsonData)
      case .unlove, .love:
        self.processLoveStatusData(jsonData)
      case .nowPlaying:
        self.processNowPlayingData(jsonData)
      case .scrobble:
        self.processScrobbleData(jsonData)
      case .scrobbleCount:
        self.processScrobbleCountData(jsonData)
      }
    }
    task.resume()
  }
}
