# Gaining Access

Getting access to the X (formerly Twitter) API has changed significantly over the last couple of years. It’s now a tiered system, ranging from a very restricted free level to enterprise-grade access that costs as much as a luxury car per month.
Here is the step-by-step process to get your keys and a breakdown of what you'll pay.

1. Sign Up for a Developer Account
Everything starts at the X Developer Portal.

* Login: Sign in with the X account you want to associate with your app.
* Apply: Click on "Sign up for a Free Account" (or "Get Started").
* Describe Your Use Case: You will be asked to explain how you intend to use the API. Be honest but detailed; a description of at least 250 characters is typically required for approval.
* Accept Terms: Agree to the Developer Agreement. Note: Your account usually needs a verified phone number and should be at least 30 days old to avoid immediate rejection.

2. Create a Project and an App
Once your developer account is approved (which is often instant for the Free tier), you need to set up a container for your API keys.

* Create a Project: In the dashboard, click "Create Project." Give it a name and select your use case (e.g., "Student" or "Building a Bot").
* Create an App: Inside your project, click "Add App." This generates your unique credentials.
* App Settings: Under "User authentication settings," click Set up.
  * Enable OAuth 1.0a (essential if you want to post tweets/post media).
  * Set permissions to Read and Write if you plan to post content.
  * Provide a "Callback URI" and "Website URL" (placeholders like <http://localhost> work for testing).

3. Generate Your Keys and Tokens
Navigate to the "Keys and Tokens" tab of your App. You will need to save these four items securely:

* API Key & Secret: (Consumer Keys) Identifies your app.
* Access Token & Secret: (Authentication Tokens) Identifies the user (you) giving the app permission to act.

> Note: These are only displayed once. If you lose them, you’ll have to "Regenerate" them, which will break any code currently using the old keys.
>
1. Choose Your Tier (Pricing)
As of early 2026, these are the standard access levels:
| Tier | Monthly Cost | What You Get |
|---|---|---|
| Free | $0 | Write-only mostly. 1,500 tweets/mo (post). Very limited reading (1 request/15 mins). |
| Basic | ~$100 | 10,000 tweets/mo (read). 3,000 tweets/mo (write). Access to 7-day search. |
| Pro | ~$5,000 | 1M tweets/mo (read). 300k tweets/mo (write). Full archive search access. |
| Enterprise | $42,000+ | Custom limits, commercial scale, and dedicated support. |
Pro-Tips for Success

* The "Write" Permission: If you get a "403 Forbidden" error when trying to post a tweet, it’s almost always because your App Permissions are set to "Read-only" by default. Change it to "Read and Write" and regenerate your tokens.
* Library Choice: If you’re using Python, Tweepy is the industry standard for interacting with these endpoints.
Would you like me to write a basic Python script using Tweepy to help you test your new keys once you have them?

# Using Swift

Swift is a great choice for this, especially if you're building native apps for iOS or macOS. However, fair warning: X's authentication (OAuth 1.0a) is famously picky about how headers are signed. If you try to build the signature manually in Swift, you're in for a long afternoon of cryptographic debugging.
Here is the most efficient way to get started using Swift.

1. The Library Situation
Because the X API requires complex request signing for posting tweets, most Swift developers use a library.

* TwitterAPIKit: Currently one of the most up-to-date libraries for Swift. It supports both API v1.1 and v2, and handles the OAuth 1.0a signing for you.
* Swifter: A classic, but often requires manual updates to work with the newer v2 endpoints.

2. Reading Data (The Simple Way)
If you only need to read public data (and you have a "Bearer Token" from the developer portal), you don't need a heavy library. You can use standard URLSession.
import Foundation

func fetchTweet(tweetID: String, bearerToken: String) {
    let url = URL(string: "<https://api.twitter.com/2/tweets/\(tweetID)>")!
    var request = URLRequest(url: url)

    // Authenticate using your Bearer Token
    request.httpMethod = "GET"
    request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        guard let data = data, error == nil else {
            print("Error: \(error?.localizedDescription ?? "Unknown error")")
            return
        }
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("Response: \(responseString)")
        }
    }
    task.resume()
}

1. Posting Content (The "OAuth 1.0a" Wall)
To post a tweet (the "Write" permission), you cannot use a simple Bearer Token. You must use your API Key, API Secret, Access Token, and Access Secret to sign the request.
In Swift, this involves:

* Creating a unique nonce (a random string).
* Generating a timestamp.
* Combining your keys and the request parameters into a "Base String."
* Hashing that string using HMAC-SHA1.
My advice: Don't write this manually. If you use a package manager like Swift Package Manager (SPM), add TwitterAPIKit and use this clean syntax:
import TwitterAPIKit

let client = TwitterAPIClient(.init(
    consumerKey: "YOUR_CONSUMER_KEY",
    consumerSecret: "YOUR_CONSUMER_SECRET",
    oauthToken: "YOUR_ACCESS_TOKEN",
    oauthTokenSecret: "YOUR_ACCESS_TOKEN_SECRET"
))

// Posting a tweet in v2
client.v2.postTweet(text: "Hello from Swift!") { result in
    switch result {
    case .success(let response):
        print("Tweet posted! ID: \(response.data.id)")
    case .failure(let error):
        print("Error: \(error)")
    }
}

1. Important Xcode Settings
If you are building a macOS or iOS app, remember to check your App Sandbox settings:

* Go to your Project Target.
* Select Signing & Capabilities.
* Ensure App Sandbox -> Network -> Outgoing Connections (Client) is checked. If it isn't, your API calls will fail silently.
Would you like me to show you how to set up the Swift Package Manager (SPM) in Xcode to bring in one of these libraries?

# Swift Package Manager Setup

Setting up Swift Package Manager (SPM) is the "Apple-approved" way to handle dependencies. It’s built right into Xcode, so you don't need to install external tools like CocoaPods or Homebrew just to manage your libraries.
Here is exactly how to pull in a library like TwitterAPIKit to handle the X API.

1. Open the Package Manager in Xcode
With your project open in Xcode:

* Go to the top menu bar and select File > Add Package Dependencies...
* In the search bar at the top right of the popup, paste the GitHub URL for the library:
   > <https://github.com/mironal/TwitterAPIKit>
   >
1. Configure Version Rules
Once Xcode finds the package, you'll see options for Dependency Rule:

* Up to Next Major Version: (Recommended) This ensures you get bug fixes and new features but won't accidentally break your code with a major update (e.g., 1.x.x to 2.0.0).
* Version Number: Usually, it will default to the latest stable release (e.g., 0.2.3).
Click Add Package.

3. Choose Your Target
A second popup will appear asking which Target to add the library to.

* If you have a standard app, just make sure your main app name is selected under the "Add to Target" column.
* Click Add Package again. Xcode will now download the source code and link it to your project. You’ll see a new "Package Dependencies" section in your file navigator on the left.

4. Import and Test
Now you can use the library in your Swift files. Open your ViewController.swift or ContentView.swift and add the import statement:
import TwitterAPIKit

// Example: Initializing the client
let client = TwitterAPIClient(.init(
    consumerKey: "YOUR_KEY",
    consumerSecret: "YOUR_SECRET",
    oauthToken: "YOUR_TOKEN",
    oauthTokenSecret: "YOUR_TOKEN_SECRET"
))

⚠️ The "Silent Failure" Gotcha
If you are building for macOS or iOS, your app lives in a "Sandbox" for security. By default, it isn't allowed to talk to the internet.

* Click your project file at the top of the Navigator.
* Select your Target.
* Go to Signing & Capabilities.
* Under App Sandbox, ensure Outgoing Connections (Client) is checked.
Quick Comparison: SPM vs. The Alternatives
| Feature | Swift Package Manager | CocoaPods |
|---|---|---|
| Setup | Native to Xcode | Requires Terminal/Ruby |
| Project Structure | Clean .xcodeproj | Messy .xcworkspace |
| Speed | Fast (Binary support) | Slow (Compiles everything) |
| Maintenance | Auto-updates | Manual pod update |
Would you like me to write a specific function that authenticates a user and fetches their latest profile data using this library?
