-----------------------------------
BSOD Diagnostic & Repair Utility: 
-----------------------------------

<img width="981" height="685" alt="image" src="https://github.com/user-attachments/assets/0c8d5ce4-a9ce-49ff-9873-72eb2d14123d" />

--------------
Prerequisites
--------------

This script provides a centralized graphical interface to scan Windows Event Logs for common crash-related events (IDs 1001, 6008, 41) and provides one-click access to Windows built-in repair tools.

Permissions: You must run this script as an Administrator. Without elevated privileges, the script will be unable to query system logs or initiate repair processes like DISM or sfc.
Environment: PowerShell 5.1 or later.

----------
Features
----------

1. Automated Crash ScanningWhen you click "Scan for Crash Logs", the script queries the System Event Log for the 15 most recent occurrences of the following events:Event ID 1001: Windows BugCheck (BSOD).Event ID 6008: Unexpected system shutdown.Event ID 41: Critical kernel power failure.
2. Interactive Results DashboardSorting: Click any column header (Time, ID, Source) to sort the logs in ascending or descending order.Filtering: Use the text box in the top-right to filter logs in real-time by keyword, Event ID, or source name.Dynamic UI: The data grid columns automatically resize to fit the message content for better readability.
3. One-Click RepairsThe "Fix Issue" button next to each entry uses a specialized closure-based execution method to ensure the repair tool triggers correctly.For IDs 41 and 6008: Launches a command prompt to run DISM /Online /Cleanup-image /Restorehealth followed by sfc /scannow to verify and repair corrupted system files.For ID 1001: Launches the Windows Memory Diagnostic tool (mdsched.exe) to check for hardware-related memory errors.

-----------------------------
Technical Maintenance Notes
-----------------------------

For your future development, please note the following technical standards established for this tool:

Closure Memory Management: The FixCommand implementation utilizes .GetNewClosure() within a private script block. This ensures that the context of the specific event (such as window positioning) is correctly captured and that the "Remove" or "Fix" actions always target the intended file/event path without memory leaks or reference errors.

File Handling: The architecture is designed to maintain persistence, ensuring the application "remembers" the loaded log set during the session.

PDF/Upload Integration: Ensure any future implementations of the PDF uploader continue to utilize the established fix for file handling, ensuring that the upload pathway remains stable and correctly mapped to the UI.


<img width="982" height="686" alt="image" src="https://github.com/user-attachments/assets/0270f7a9-cf37-4c1f-91a3-0571936c31b5" />


<img width="980" height="684" alt="image" src="https://github.com/user-attachments/assets/35e5ffa5-2d40-4ced-8e88-cce7adb45638" />


<img width="978" height="687" alt="image" src="https://github.com/user-attachments/assets/941eed0a-0523-4bf6-8857-ba9759e9568d" />
