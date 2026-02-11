Universal Logging System

## The ULS

Since macOS Sierra, Apple has used the Unified Logging System (ULS). If you remember the old days of Linux or macOS, logs were mostly just plain text files sitting in /var/log/ that grew until a "log rotation" script zipped them up.
The modern system is far more sophisticated. It handles thousands of events per second without choking your storage or your CPU. Here’s how it pulls off that magic trick.

1. The "Firehose" Architecture
The ULS treats logs like a high-speed stream rather than a static diary. Instead of writing every single "heartbeat" or minor event directly to the SSD (which would wear it out), macOS uses a memory-to-disk pipeline.

* Memory Buffering: Log entries are first written to a high-performance "firehose" buffer in RAM. This is incredibly fast and has zero impact on disk I/O.
* Binary Format: Unlike old logs that were human-readable text, modern logs are stored in a compressed binary format (.tracev3 files). This can shrink the size of log data by up to 10x compared to raw text.

1. Volatile vs. Persisted Data
The system is smart enough to know that not every log entry is equally important. It categorizes logs into different levels:

* Default: These are saved to disk (persisted).
* Info: These are usually kept in memory and only written to disk if they happen right before a crash or if the system is under "high pressure."
* Debug: These are almost never saved to disk unless you specifically turn on "Debug Mode" for troubleshooting.
By keeping "chattery" logs in RAM and letting them expire, the system avoids ever writing them to your hard drive.

1. Automatic Aging and Pruning
The ULS doesn't have a fixed "file size" limit in the traditional sense; it has a quota and time-based retention policy.

* The "Circular" Log: Think of the log storage as a circular track. When the allocated space for logs (usually a small percentage of your drive) is full, the system automatically overwrites the oldest entries to make room for new ones.
* Maintenance: macOS periodically runs background tasks to prune old .tracev3 files that have outlived their usefulness (usually after a few days for standard logs).

1. Why You Can't Just "Open" Them
Because these logs are compressed binary blobs, you can’t just open them with a text editor like NotePad or TextEdit. You have to use:

* Console.app: The GUI way to view and filter logs.
* The log command: In Terminal, running log show or log stream decompresses these binary files on the fly so you can read them.

> Pro Tip: If your Mac is feeling sluggish, it's almost never because the logs are "full." It's more likely a specific process is spamming the firehose, causing the CPU to work overtime just to process the stream.
>
Would you like me to show you a few Terminal commands to filter your system logs for specific errors or app crashes?

## Social Marketer's Logs

Setup Social Marketer to log everything it does and feed its logs into MacOS' Universal Logging System (ULS).
These logs should be categorized into Default, Info and Debug logs; I trust you to determine which log event belongs to the appropriate category.
There should be a Debug Mode Toggle in Social Marketer's settings that will, when toggled On, will save the Debug logs to disk.
Social Marketer's logs should be accessible from both the Console App and the 'log' command in the Terminal App.
Is there any feature of Social Marketer's logging system I neglected to mention that maybe useful to us?
