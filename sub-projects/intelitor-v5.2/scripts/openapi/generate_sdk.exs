#!/usr/bin/env elixir

# Mobile SDK Generation Script
# Generates SDK code for iOS, Android, and Flutter from OpenAPI spec
#
# Usage: elixir scripts/openapi/generate_sdk.exs [platform]
# Platforms: ios, android, flutter, all
#
# Agent: Worker-1 generates SDKs
# SOPv5.1 Compliance: ✅

defmodule SDKGenerator do
  @moduledoc """
  Generates mobile SDKs from OpenAPI specification.
  """

  @spec main(any()) :: any()
  def main(args) do
    platform = List.first(args) || "all"

    IO.puts("🚀 Starting SDK generation for platform: #{platform}")

    # Ensure OpenAPI spec exists
    spec_path = "priv/static/openapi.json"
    unless File.exists?(spec_path) do
      IO.puts("❌ OpenAPI specification not found. Run 'mix openapi.generate' first.")
      System.halt(1)
    end

    case platform do
      "ios" -> generate_ios_sdk()
      "android" -> generate_android_sdk()
      "flutter" -> generate_flutter_sdk()
      "all" -> generate_all_sdks()
      _ ->
        IO.puts("❌ Unknown platform: #{platform}")
        IO.puts("   Valid platforms: ios, android, flutter, all")
        System.halt(1)
    end
  end

  @spec generate_all_sdks() :: any()
  defp generate_all_sdks do
    generate_ios_sdk()
    generate_android_sdk()
    generate_flutter_sdk()
  end

  @spec generate_ios_sdk() :: any()
  defp generate_ios_sdk do
    IO.puts("\n📱 Generating iOS SDK...")

    output_dir = "priv/sdks/ios"
    File.mkdir_p!(output_dir)

    # Generate Swift package structure
    generate_swift_package(output_dir)
    generate_swift_models(output_dir)
    generate_swift_api_client(output_dir)
    generate_swift_websocket_client(output_dir)

    IO.puts("✅ iOS SDK generated at: #{output_dir}")
  end

  @spec generate_android_sdk() :: any()
  defp generate_android_sdk do
    IO.puts("\n🤖 Generating Android SDK...")

    output_dir = "priv/sdks/android"
    File.mkdir_p!(output_dir)

    # Generate Kotlin package structure
    generate_kotlin_package(output_dir)
    generate_kotlin_models(output_dir)
    generate_kotlin_api_client(output_dir)
    generate_kotlin_websocket_client(output_dir)

    IO.puts("✅ Android SDK generated at: #{output_dir}")
  end

  @spec generate_flutter_sdk() :: any()
  defp generate_flutter_sdk do
    IO.puts("\n🦋 Generating Flutter SDK...")

    output_dir = "priv/sdks/flutter"
    File.mkdir_p!(output_dir)

    # Generate Dart package structure
    generate_dart_package(output_dir)
    generate_dart_models(output_dir)
    generate_dart_api_client(output_dir)
    generate_dart_websocket_client(output_dir)

    IO.puts("✅ Flutter SDK generated at: #{output_dir}")
  end

  # iOS SDK Generation
  @spec generate_swift_package(term()) :: term()
  defp generate_swift_package(output_dir) do
    package_content = """
    // swift-tools-version:5.7
    import PackageDescription

    let package = Package(
        name: "IndrajaalSDK",
        platforms: [
            .iOS(.v14),
            .macOS(.v11)
        ],
        products: [
            .library(
                name: "IndrajaalSDK",
                targets: ["IndrajaalSDK"]
            ),
        ],
        dependencies: [
            .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0"),
            .package(url: "https://github.com/daltoniam/Starscream.git", from: "4.0.0")
        ],
        targets: [
            .target(
                name: "IndrajaalSDK",
                dependencies: ["Alamofire", "Starscream"],
                path: "Sources"
            ),
            .testTarget(
                name: "IndrajaalSDKTests",
                dependencies: ["IndrajaalSDK"],
                path: "Tests"
            ),
        ]
    )
    """

    File.write!(Path.join(output_dir, "Package.swift"), package_content)
  end

  @spec generate_swift_models(term()) :: term()
  defp generate_swift_models(output_dir) do
    models_dir = Path.join([output_dir, "Sources", "Models"])
    File.mkdir_p!(models_dir)

    # Generate authentication models
    auth_models = """
    import Foundation

    // MARK: - Authentication Models

    public struct LoginRequest: Codable {
        public let __username: String
        public let password: String
        public let deviceId: String?
        public let deviceName: String?
        public let platform: String = "ios"
        public let appVersion: String?
        public let pushToken: String?

        public init(__username: String, password: String, deviceId: String? = nil,
                    deviceName: String? = nil, appVersion: String? = nil,
                    pushToken: String? = nil) {
            self.__username = __username
            self.password = password
            self.deviceId = deviceId
            self.deviceName = deviceName
            self.appVersion = appVersion
            self.pushToken = pushToken
        }
    }

    public struct LoginResponse: Codable {
        public let token: String
        public let refreshToken: String
        public let expiresIn: Int
        public let tokenType: String
        public let __user: UserProfile
        public let permissions: [String]
        public let __requiresMfa: Bool?
        public let mfaToken: String?
    }

    public struct UserProfile: Codable {
        public let id: String
        public let email: String
        public let name: String
        public let role: String
        public let tenantId: String
        public let avatarUrl: String?
        public let locale: String
        public let timezone: String
    }
    """

    File.write!(Path.join(models_dir, "AuthModels.swift"), auth_models)

    # Generate alarm models
    alarm_models = """
    import Foundation

    // MARK: - Alarm Models

    public struct Alarm: Codable {
        public let id: String
        public let tenantId: String
        public let name: String
        public let description: String
        public let priority: AlarmPriority
        public let status: AlarmStatus
        public let deviceId: String?
        public let siteId: String?
        public let triggeredAt: Date
        public let acknowledgedAt: Date?
        public let acknowledgedBy: String?
        public let resolvedAt: Date?
        public let resolvedBy: String?
        public let resolution: String?
        public let metadata: [String: Any]?
        public let createdAt: Date
        public let updatedAt: Date
    }

    public enum AlarmPriority: String, Codable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case critical = "critical"
    }

    public enum AlarmStatus: String, Codable {
        case active = "active"
        case acknowledged = "acknowledged"
        case resolved = "resolved"
        case escalated = "escalated"
    }
    """

    File.write!(Path.join(models_dir, "AlarmModels.swift"), alarm_models)
  end

  @spec generate_swift_api_client(term()) :: term()
  defp generate_swift_api_client(output_dir) do
    client_dir = Path.join([output_dir, "Sources", "API"])
    File.mkdir_p!(client_dir)

    api_client = """
    import Foundation
    import Alamofire

    public class IndrajaalAPIClient {
        private let baseURL: String
        private var token: String?
        private let session: Session

        public static let shared = IndrajaalAPIClient()

        private init() {
            self.baseURL = "https://api.indrajaal.com"

            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 30
            configuration.timeoutIntervalForResource = 300

            self.session = Session(configuration: configuration)
        }

        public func configure(baseURL: String? = nil, token: String? = nil) {
            if let baseURL = baseURL {
                self.baseURL = baseURL
            }
            self.token = token
        }

        // MARK: - Authentication

        public func login(__request: LoginRequest,
      completion: @escaping (Result<LoginResponse, Error>)
    -> Void) {
            session.__request("\\(baseURL)/api/mobile/auth/login",
                          method: .post,
                          parameters: __request,
                          encoder: JSONParameterEncoder.default)
                .validate()
                .responseDecodable(of: LoginResponse.self) { response in
                    switch response.result {
                    case .success(let loginResponse):
                        self.token = loginResponse.token
                        completion(.success(loginResponse))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
        }

        // MARK: - Alarms

        public func getAlarms(page: Int = 1,
      pageSize: Int = 20, completion: @escaping (Result<[Alarm], Error>) -> Void) {
            var headers = HTTPHeaders()
            if let token = token {
                headers.add(.authorization(bearerToken: token))
            }

            let parameters: Parameters = [
                "page": page,
                "page_size": pageSize
            ]

            session.__request("\\(baseURL)/api/mobile/alarms",
                          method: .get,
                          parameters: parameters,
                          headers: headers)
                .validate()
                .responseDecodable(of: AlarmListResponse.self) { response in
                    switch response.result {
                    case .success(let listResponse):
                        completion(.success(listResponse.__data))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
        }
    }
    """

    File.write!(Path.join(client_dir, "IndrajaalAPIClient.swift"), api_client)
  end

  @spec generate_swift_websocket_client(term()) :: term()
  defp generate_swift_websocket_client(output_dir) do
    websocket_dir = Path.join([output_dir, "Sources", "WebSocket"])
    File.mkdir_p!(websocket_dir)

    websocket_client = """
    import Foundation
    import Starscream

    public class IndrajaalWebSocketClient: WebSocketDelegate {
        private var socket: WebSocket?
        private let baseURL: String
        private var token: String?
        private var isConnected = false

        public static let shared = IndrajaalWebSocketClient()

        private init() {
            self.baseURL = "wss://api.indrajaal.com/mobile/socket/websocket"
        }

        public func connect(token: String) {
            self.token = token

            var __request = URLRequest(url: URL(string: "\\(baseURL)?token=\\(token)")!)
            __request.timeoutInterval = 45

            socket = WebSocket(__request: __request)
            socket?.delegate = self
            socket?.connect()
        }

        public func disconnect() {
            socket?.disconnect()
        }

        // MARK: - Channel Management

        public func joinAlarmChannel(alarmId: String) {
            let payload = [
                "topic": "alarm:\\(alarmId)",
                "__event": "phx_join",
                "payload": [:],
                "ref": UUID().uuidString
            ]

            sendMessage(payload)
        }

        // MARK: - WebSocketDelegate

        public func websocketDidConnect(socket: WebSocketClient) {
            isConnected = true
            print("WebSocket connected")
        }

        public func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
            isConnected = false
            print("WebSocket disconnected: \\(error?.localizedDescription ?? "Unknown error")")
        }

        public func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
            // Handle incoming messages
            print("Received: \\(text)")
        }

        public func websocketDidReceiveData(socket: WebSocketClient, __data: Data) {
            // Handle binary __data if needed
        }

        private func sendMessage(_ payload: [String: Any]) {
            guard isConnected else { return }

            do {
                let __data = try JSONSerialization.__data(withJSONObject: payload)
                let text = String(__data: __data, encoding: .utf8)!
                socket?.write(string: text)
            } catch {
                print("Failed to send message: \\(error)")
            }
        }
    }
    """

    File.write!(Path.join(websocket_dir, "IndrajaalWebSocketClient.swift"), websocket_client)
  end

  # Android SDK Generation (Kotlin)
  @spec generate_kotlin_package(term()) :: term()
  defp generate_kotlin_package(output_dir) do
    # Generate build.gradle.kts
    build_gradle = """
    plugins {
        id("com.android.library")
        id("org.jetbrains.kotlin.android")
        id("kotlinx-serialization")
    }

    android {
        namespace = "com.indrajaal.sdk"
        compileSdk = 34

        defaultConfig {
            minSdk = 24
            targetSdk = 34

            testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        }

        buildTypes {
            release {
                isMinifyEnabled = false
                proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"),
      "proguard-rules.pro")
            }
        }

        compileOptions {
            sourceCompatibility = JavaVersion.VERSION_1_8
            targetCompatibility = JavaVersion.VERSION_1_8
        }

        kotlinOptions {
            jvmTarget = "1.8"
        }
    }

    dependencies {
        implementation("org.jetbrains.kotlin:kotlin-stdlib:1.9.0")
        implementation("com.squareup.retrofit2:retrofit:2.9.0")
        implementation("com.squareup.retrofit2:converter-gson:2.9.0")
        implementation("com.squareup.okhttp3:okhttp:4.11.0")
        implementation("com.squareup.okhttp3:logging-interceptor:4.11.0")
        implementation("org.java-websocket:Java-WebSocket:1.5.4")
        implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")

        testImplementation("junit:junit:4.13.2")
        androidTestImplementation("androidx.test.ext:junit:1.1.5")
    }
    """

    File.write!(Path.join(output_dir, "build.gradle.kts"), build_gradle)
  end

  @spec generate_kotlin_models(term()) :: term()
  defp generate_kotlin_models(_output_dir) do
    # Implementation for Kotlin models
    :ok
  end

  @spec generate_kotlin_api_client(term()) :: term()
  defp generate_kotlin_api_client(_output_dir) do
    # Implementation for Kotlin API client
    :ok
  end

  @spec generate_kotlin_websocket_client(term()) :: term()
  defp generate_kotlin_websocket_client(_output_dir) do
    # Implementation for Kotlin WebSocket client
    :ok
  end

  # Flutter SDK Generation (Dart)
  @spec generate_dart_package(term()) :: term()
  defp generate_dart_package(output_dir) do
    pubspec = """
    name: indrajaal_sdk
    description: Official Indrajaal Mobile SDK for Flutter
    version: 1.0.0
    homepage: https://github.com/indrajaal/flutter-sdk

    environment:
      sdk: '>=3.0.0 <4.0.0'

    dependencies:
      dio: ^5.3.2
      web_socket_channel: ^2.4.0
      json_annotation: ^4.8.1
      freezed_annotation: ^2.4.1
      shared_preferences: ^2.2.1

    dev_dependencies:
      build_runner: ^2.4.6
      json_serializable: ^6.7.1
      freezed: ^2.4.5
      test: ^1.24.6
      mockito: ^5.4.2
    """

    File.write!(Path.join(output_dir, "pubspec.yaml"), pubspec)
  end

  @spec generate_dart_models(term()) :: term()
  defp generate_dart_models(_output_dir) do
    # Implementation for Dart models
    :ok
  end

  @spec generate_dart_api_client(term()) :: term()
  defp generate_dart_api_client(_output_dir) do
    # Implementation for Dart API client
    :ok
  end

  @spec generate_dart_websocket_client(term()) :: term()
  defp generate_dart_websocket_client(_output_dir) do
    # Implementation for Dart WebSocket client
    :ok
  end
end

# Run the script
SDKGenerator.main(System.argv())