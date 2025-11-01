#!/usr/bin/env python3
"""
Knowledge Base Population Script
Populates the MongoDB knowledge base with sample IT support articles
"""

import asyncio
import os
import sys
from datetime import datetime
from dotenv import load_dotenv

# Add the current directory to Python path for imports
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# Load environment variables
load_dotenv()

from shared.utils.database import init_database_connections, db_manager, MongoRepository

# Sample Knowledge Base Articles
SAMPLE_ARTICLES = [
    {
        "title": "How to Reset Your Windows Password",
        "content": """
# Password Reset Guide

## For Windows 10/11 Users

### Method 1: Using Security Questions
1. On the login screen, click "Reset password"
2. Answer your security questions
3. Enter your new password twice
4. Click "Finish"

### Method 2: Using Another Admin Account
1. Log in with an administrator account
2. Go to Settings > Accounts > Family & other users
3. Select the user account
4. Click "Change password"
5. Enter the new password

### Method 3: Using Command Prompt (Admin Required)
1. Open Command Prompt as Administrator
2. Type: `net user [username] [newpassword]`
3. Press Enter
4. The password will be changed immediately

## Important Notes
- Passwords must be at least 8 characters long
- Include uppercase, lowercase, numbers, and special characters
- Don't use personal information in passwords
- Consider using a password manager

## Need Help?
If these methods don't work, contact IT support for assistance.
        """,
        "category": "Account Management",
        "tags": ["password", "reset", "windows", "login", "security"],
        "author": "IT Support Team"
    },
    {
        "title": "VPN Connection Setup Guide",
        "content": """
# VPN Setup Instructions

## Windows VPN Setup

### Step 1: Download VPN Client
1. Download the company VPN client from the IT portal
2. Run the installer as Administrator
3. Follow the installation wizard

### Step 2: Configure Connection
1. Open the VPN client
2. Click "Add New Connection"
3. Enter server details:
   - Server: vpn.company.com
   - Protocol: IKEv2
   - Authentication: Username/Password

### Step 3: Connect
1. Enter your company credentials
2. Click "Connect"
3. Wait for connection confirmation

## macOS VPN Setup

### Using Built-in VPN
1. Go to System Preferences > Network
2. Click "+" to add new service
3. Select "VPN" and "IKEv2"
4. Enter connection details
5. Click "Connect"

## Troubleshooting
- Check internet connection first
- Verify credentials are correct
- Try different server locations
- Contact IT if connection fails repeatedly

## Security Notes
- Always use VPN when working remotely
- Disconnect when not needed
- Report any connection issues immediately
        """,
        "category": "Network",
        "tags": ["vpn", "remote", "connection", "security", "setup"],
        "author": "Network Team"
    },
    {
        "title": "Email Configuration for Outlook",
        "content": """
# Outlook Email Setup

## Automatic Configuration (Recommended)

### For Office 365 Accounts
1. Open Outlook
2. Click "File" > "Add Account"
3. Enter your email address
4. Enter your password
5. Outlook will configure automatically

## Manual Configuration

### IMAP Settings
- **Incoming Server**: mail.company.com
- **Port**: 993
- **Encryption**: SSL/TLS
- **Outgoing Server**: smtp.company.com
- **Port**: 587
- **Encryption**: STARTTLS

### POP3 Settings (Not Recommended)
- **Incoming Server**: pop.company.com
- **Port**: 995
- **Encryption**: SSL/TLS

## Common Issues

### "Cannot Connect to Server"
1. Check internet connection
2. Verify server settings
3. Check firewall settings
4. Try different port numbers

### "Authentication Failed"
1. Verify username and password
2. Check if 2FA is enabled
3. Generate app-specific password if needed

### Emails Not Syncing
1. Check sync settings
2. Verify folder subscriptions
3. Clear Outlook cache
4. Restart Outlook

## Mobile Setup
Use the same IMAP settings for mobile devices.
Enable "Use SSL" for security.

## Support
Contact IT support if you continue experiencing issues.
        """,
        "category": "Email",
        "tags": ["outlook", "email", "configuration", "imap", "smtp"],
        "author": "IT Support Team"
    },
    {
        "title": "Printer Setup and Troubleshooting",
        "content": """
# Printer Setup Guide

## Adding a Network Printer

### Windows 10/11
1. Go to Settings > Devices > Printers & scanners
2. Click "Add a printer or scanner"
3. Select your printer from the list
4. Follow the setup wizard

### Manual IP Setup
1. Click "The printer that I want isn't listed"
2. Select "Add a printer using a TCP/IP address"
3. Enter printer IP address
4. Install appropriate drivers

## Common Printer Issues

### Printer Offline
1. Check power and network cables
2. Restart the printer
3. Remove and re-add printer in Windows
4. Update printer drivers

### Print Jobs Stuck in Queue
1. Open Control Panel > Devices and Printers
2. Right-click your printer
3. Select "See what's printing"
4. Cancel all documents
5. Restart Print Spooler service

### Poor Print Quality
1. Check ink/toner levels
2. Run printer cleaning cycle
3. Check paper type settings
4. Replace cartridges if needed

## Printer Locations
- **Main Office**: HP LaserJet Pro (IP: 192.168.1.100)
- **Conference Room**: Canon ImageClass (IP: 192.168.1.101)
- **Marketing Dept**: Epson EcoTank (IP: 192.168.1.102)

## Driver Downloads
Download latest drivers from manufacturer websites:
- HP: hp.com/support
- Canon: canon.com/support
- Epson: epson.com/support

## Need Help?
Submit a ticket if printer issues persist.
        """,
        "category": "Hardware",
        "tags": ["printer", "setup", "troubleshooting", "network", "drivers"],
        "author": "IT Support Team"
    },
    {
        "title": "Software Installation Requests",
        "content": """
# Software Installation Process

## Approved Software List
The following software can be installed without special approval:
- Microsoft Office Suite
- Adobe Acrobat Reader
- Google Chrome
- Mozilla Firefox
- 7-Zip
- Notepad++
- VLC Media Player
- Zoom
- Teams

## Request Process

### For Approved Software
1. Submit ticket with software name
2. Include business justification
3. IT will install within 24 hours

### For New Software
1. Submit detailed request including:
   - Software name and version
   - Business justification
   - Number of licenses needed
   - Budget information
2. Manager approval required
3. Security review (5-10 business days)
4. Procurement and installation

## Self-Service Options
Some software can be installed via Company Portal:
1. Open Company Portal app
2. Browse available software
3. Click "Install" for desired applications

## Security Requirements
All software must:
- Be from trusted vendors
- Pass security scanning
- Have current support contracts
- Comply with licensing agreements

## Prohibited Software
- Peer-to-peer file sharing applications
- Cryptocurrency mining software
- Unlicensed or cracked software
- Software with known security vulnerabilities

## Installation Guidelines
- Only install software from official sources
- Keep software updated
- Report any suspicious behavior
- Don't share license keys

## Need Custom Software?
Contact IT for evaluation of specialized business applications.
        """,
        "category": "Software",
        "tags": ["software", "installation", "approval", "security", "licensing"],
        "author": "IT Security Team"
    },
    {
        "title": "Wi-Fi Connection Troubleshooting",
        "content": """
# Wi-Fi Connection Guide

## Company Wi-Fi Networks
- **AuraSecure**: Main corporate network (WPA3)
- **AuraGuest**: Guest network (Open with portal)
- **AuraIoT**: Device network (Restricted)

## Connection Steps

### Windows
1. Click Wi-Fi icon in system tray
2. Select "AuraSecure"
3. Enter your domain credentials
4. Check "Connect automatically"

### macOS
1. Click Wi-Fi icon in menu bar
2. Select "AuraSecure"
3. Enter username and password
4. Click "Join"

### Mobile Devices
1. Go to Wi-Fi settings
2. Select "AuraSecure"
3. Choose "WPA2/WPA3 Enterprise"
4. Enter domain credentials

## Troubleshooting Steps

### Cannot See Network
1. Check if Wi-Fi is enabled
2. Refresh available networks
3. Move closer to access point
4. Restart Wi-Fi adapter

### Cannot Connect
1. Verify credentials are correct
2. Forget and reconnect to network
3. Check for MAC address filtering
4. Contact IT for account verification

### Slow Connection
1. Check signal strength
2. Move to different location
3. Restart device
4. Run speed test
5. Report persistent issues

### Frequent Disconnections
1. Update Wi-Fi drivers
2. Disable power management for Wi-Fi
3. Check for interference
4. Reset network settings

## Guest Access
Visitors can use "AuraGuest":
1. Connect to AuraGuest network
2. Open web browser
3. Complete registration form
4. Access valid for 24 hours

## Security Notes
- Never share Wi-Fi passwords
- Use VPN for sensitive data
- Report suspicious network activity
- Keep devices updated

## Coverage Areas
Wi-Fi is available in:
- All office floors
- Conference rooms
- Break areas
- Lobby and reception

## Support
Contact IT for persistent connectivity issues.
        """,
        "category": "Network",
        "tags": ["wifi", "wireless", "connection", "troubleshooting", "network"],
        "author": "Network Team"
    },
    {
        "title": "Multi-Factor Authentication (MFA) Setup",
        "content": """
# Multi-Factor Authentication Setup

## Why MFA is Required
MFA adds an extra layer of security to protect company data and systems from unauthorized access.

## Supported MFA Methods
1. **Microsoft Authenticator** (Recommended)
2. **SMS Text Messages**
3. **Phone Calls**
4. **Hardware Tokens** (For high-privilege accounts)

## Setup Instructions

### Microsoft Authenticator App
1. Download Microsoft Authenticator from app store
2. Go to https://aka.ms/mfasetup
3. Sign in with your company account
4. Click "Set up Authenticator app"
5. Scan QR code with the app
6. Enter verification code to complete setup

### SMS Setup
1. Go to https://aka.ms/mfasetup
2. Select "Phone" as authentication method
3. Enter your mobile phone number
4. Choose "Send me a code by text message"
5. Enter received code to verify

### Phone Call Setup
1. Go to https://aka.ms/mfasetup
2. Select "Phone" as authentication method
3. Enter your phone number
4. Choose "Call me"
5. Answer call and follow prompts

## Using MFA

### Daily Login
1. Enter username and password
2. Approve notification in Authenticator app
   OR
   Enter code from SMS/app

### Backup Codes
- Generate backup codes for emergencies
- Store codes in secure location
- Each code can only be used once

## Troubleshooting

### App Not Working
1. Check internet connection
2. Sync time on device
3. Reinstall Authenticator app
4. Contact IT for reset

### Not Receiving SMS
1. Check phone signal
2. Verify phone number is correct
3. Try phone call method instead
4. Contact IT support

### Lost Device
1. Contact IT immediately
2. Provide alternative verification
3. IT will reset MFA settings
4. Set up MFA on new device

## Best Practices
- Keep backup authentication methods updated
- Don't share authentication codes
- Report lost devices immediately
- Use Authenticator app when possible

## Getting Help
Contact IT support for MFA issues or questions.
        """,
        "category": "Security",
        "tags": ["mfa", "authentication", "security", "microsoft", "2fa"],
        "author": "IT Security Team"
    },
    {
        "title": "File Sharing and OneDrive Usage",
        "content": """
# File Sharing Guide

## OneDrive for Business

### Accessing OneDrive
1. Go to office.com
2. Sign in with company credentials
3. Click OneDrive icon
   OR
4. Use OneDrive desktop app

### Syncing Files
1. Install OneDrive desktop client
2. Sign in with company account
3. Choose folders to sync
4. Files sync automatically

### Sharing Files

#### Internal Sharing
1. Right-click file in OneDrive
2. Select "Share"
3. Enter colleague's email
4. Set permissions (View/Edit)
5. Click "Send"

#### External Sharing
1. Right-click file
2. Select "Share"
3. Click "Anyone with the link"
4. Set expiration date
5. Choose view/edit permissions

## SharePoint Document Libraries

### Accessing Team Sites
1. Go to office.com
2. Click SharePoint
3. Select your team site
4. Navigate to Documents library

### Version Control
- SharePoint automatically saves versions
- View version history by right-clicking file
- Restore previous versions if needed
- Check out files for exclusive editing

## File Sharing Best Practices

### Security Guidelines
- Only share with necessary people
- Set expiration dates for external links
- Use "View only" when editing isn't needed
- Regularly review shared files

### Organization Tips
- Use descriptive file names
- Create folder structures
- Tag files with metadata
- Delete outdated files regularly

## Large File Transfers

### For Files Over 100MB
1. Upload to OneDrive
2. Share link instead of email attachment
3. Use SharePoint for team collaboration
4. Consider file compression

### Alternative Methods
- **Secure File Transfer**: Use company FTP
- **External Partners**: Use approved file sharing services
- **Temporary Sharing**: Use company-approved tools

## Collaboration Features

### Co-authoring
- Multiple users can edit simultaneously
- Real-time changes visible to all
- Comments and suggestions available
- Version conflicts automatically resolved

### Teams Integration
- Access files directly in Teams
- Edit files without leaving Teams
- Share files in chat or channels

## Storage Limits
- OneDrive: 1TB per user
- SharePoint: 25TB per site
- Contact IT for additional storage

## Troubleshooting

### Sync Issues
1. Check internet connection
2. Restart OneDrive client
3. Clear OneDrive cache
4. Reset OneDrive if needed

### Access Denied
1. Check sharing permissions
2. Verify you're signed in correctly
3. Contact file owner for access
4. Submit IT ticket if persistent

## Support
Contact IT for file sharing issues or questions.
        """,
        "category": "Software",
        "tags": ["onedrive", "sharepoint", "file sharing", "collaboration", "cloud"],
        "author": "IT Support Team"
    },
    {
        "title": "Advanced Password Recovery Methods",
        "content": """
# Advanced Password Recovery Guide

## When Standard Reset Methods Don't Work

### Method 1: Using Password Reset Disk
1. Insert your password reset disk
2. On the login screen, click "Reset password"
3. Follow the Password Reset Wizard
4. Create a new password

### Method 2: Safe Mode Administrator Account
1. Restart computer and press F8 during boot
2. Select "Safe Mode"
3. Log in as Administrator (usually no password)
4. Go to Control Panel > User Accounts
5. Reset the user password

### Method 3: Command Prompt Recovery
1. Boot from Windows installation media
2. Press Shift+F10 to open Command Prompt
3. Navigate to System32 folder
4. Replace sethc.exe with cmd.exe
5. Restart and use Sticky Keys shortcut at login

### Method 4: Third-Party Tools
- Ophcrack (for older systems)
- Kon-Boot (commercial solution)
- Trinity Rescue Kit (Linux-based)

## Prevention Tips
- Create a password reset disk when you first set up your account
- Use a password manager
- Set up security questions
- Enable two-factor authentication

## When to Contact IT
- If you're on a domain-joined computer
- If BitLocker encryption is enabled
- If you need to recover encrypted files
- If multiple failed attempts have locked the account
        """,
        "category": "Account Management",
        "tags": ["password", "recovery", "advanced", "troubleshooting", "security"],
        "author": "IT Security Team"
    },
    {
        "title": "VPN Troubleshooting Checklist",
        "content": """
# VPN Connection Troubleshooting

## Quick Diagnostic Steps

### Step 1: Basic Connectivity Check
1. Test internet connection without VPN
2. Try connecting to a different VPN server
3. Restart your network adapter
4. Flush DNS cache: `ipconfig /flushdns`

### Step 2: VPN Client Issues
1. Update VPN client to latest version
2. Run VPN client as administrator
3. Check for conflicting software (antivirus, firewall)
4. Clear VPN client cache and logs

### Step 3: Network Configuration
1. Check if your ISP blocks VPN traffic
2. Try different VPN protocols (OpenVPN, IKEv2, WireGuard)
3. Change VPN port numbers
4. Disable IPv6 temporarily

### Step 4: Firewall and Antivirus
1. Add VPN client to firewall exceptions
2. Temporarily disable antivirus
3. Check Windows Defender settings
4. Verify corporate firewall rules

## Common Error Messages

### "Connection Timeout"
- Check internet connection
- Try different server location
- Verify credentials
- Check firewall settings

### "Authentication Failed"
- Verify username and password
- Check if account is active
- Try resetting password
- Contact IT for account status

### "DNS Resolution Failed"
- Change DNS servers (8.8.8.8, 1.1.1.1)
- Flush DNS cache
- Restart network adapter
- Check DNS leak protection

## Advanced Troubleshooting
- Use network diagnostic tools (ping, tracert, nslookup)
- Check VPN logs for error details
- Test with different devices
- Monitor network traffic with Wireshark

## When to Escalate
- Persistent connection failures after trying all steps
- Suspected network infrastructure issues
- Need for alternative VPN solutions
- Security concerns or policy violations
        """,
        "category": "Network",
        "tags": ["vpn", "troubleshooting", "connectivity", "network", "remote"],
        "author": "Network Team"
    },
    {
        "title": "Email Synchronization Best Practices",
        "content": """
# Email Synchronization Issues Resolution

## Common Sync Problems

### Emails Not Downloading
1. Check internet connection stability
2. Verify account settings (IMAP/POP3)
3. Check server status and maintenance windows
4. Clear Outlook cache and restart

### Sent Items Not Syncing
1. Enable "Save sent items on server"
2. Check SMTP settings
3. Verify folder mapping in account settings
4. Rebuild Outlook profile if needed

### Calendar/Contacts Sync Issues
1. Enable Exchange ActiveSync
2. Check sync frequency settings
3. Verify permissions on shared calendars
4. Clear mobile device cache

## Optimization Tips

### For Better Performance
- Use IMAP instead of POP3 for multiple devices
- Set appropriate sync intervals (15-30 minutes)
- Limit sync to recent emails (30-90 days)
- Use server-side rules instead of client-side

### For Mobile Devices
- Enable push notifications for important folders only
- Sync headers only for large mailboxes
- Use focused inbox to reduce data usage
- Set up VIP lists for priority contacts

### For Shared Mailboxes
- Configure proper permissions (Full Access, Send As)
- Use automapping for seamless access
- Set up delegation instead of shared passwords
- Monitor mailbox size limits

## Troubleshooting Steps

### Outlook Desktop Issues
1. Run Outlook in Safe Mode
2. Repair Office installation
3. Create new Outlook profile
4. Check for add-in conflicts

### Mobile App Problems
1. Remove and re-add account
2. Update app to latest version
3. Check device storage space
4. Verify corporate policy compliance

### Web Access (OWA) Issues
1. Clear browser cache and cookies
2. Try different browser or incognito mode
3. Disable browser extensions
4. Check for proxy settings

## Prevention Strategies
- Regular mailbox cleanup and archiving
- Use rules to organize emails automatically
- Monitor mailbox size limits
- Keep software updated
- Train users on best practices

## When to Contact IT
- Server-side configuration changes needed
- Mailbox migration or setup
- Exchange server issues
- Policy or security concerns
        """,
        "category": "Email",
        "tags": ["email", "synchronization", "outlook", "exchange", "mobile"],
        "author": "IT Support Team"
    },
    {
        "title": "Printer Driver Installation Guide",
        "content": """
# Comprehensive Printer Driver Installation

## Automatic Installation Methods

### Windows Update Method
1. Connect printer via USB or ensure network connectivity
2. Go to Settings > Update & Security > Windows Update
3. Click "Check for updates"
4. Windows will automatically detect and install drivers
5. Test print to verify installation

### Manufacturer's Software
1. Visit printer manufacturer's website
2. Download latest driver package for your OS
3. Run installer as administrator
4. Follow setup wizard instructions
5. Configure printer preferences

## Manual Installation Steps

### For Network Printers
1. Open Control Panel > Devices and Printers
2. Click "Add a printer"
3. Select "Add a network, wireless or Bluetooth printer"
4. Choose your printer from the list
5. If not found, click "The printer that I want isn't listed"
6. Enter printer IP address or hostname
7. Select appropriate driver from list

### For USB Printers
1. Connect printer to computer via USB
2. Power on the printer
3. Windows should auto-detect (if not, follow manual steps)
4. Go to Settings > Printers & scanners
5. Click "Add a printer or scanner"
6. Select your printer and click "Add device"

## Driver Troubleshooting

### Driver Conflicts
1. Uninstall old/conflicting drivers
2. Use manufacturer's removal tool
3. Clean registry entries (use CCleaner)
4. Restart computer before installing new drivers

### Compatibility Issues
1. Check Windows compatibility mode
2. Download drivers for correct OS version (32-bit vs 64-bit)
3. Use generic PCL or PostScript drivers as fallback
4. Contact manufacturer for updated drivers

### Installation Failures
1. Run installer as administrator
2. Temporarily disable antivirus
3. Check Windows Installer service status
4. Use Windows built-in troubleshooter

## Advanced Configuration

### Print Server Setup
1. Install printer on server computer
2. Share printer with appropriate permissions
3. Install drivers for all client OS versions
4. Configure print queues and priorities

### Group Policy Deployment
1. Create printer deployment package
2. Configure Group Policy for automatic installation
3. Test deployment on pilot group
4. Monitor installation success rates

## Common Issues and Solutions

### "Driver is unavailable"
- Update Windows to latest version
- Download latest driver from manufacturer
- Use Windows Update to find compatible driver
- Try generic driver as temporary solution

### Print quality problems after driver update
- Access printer properties and reset to defaults
- Calibrate printer if option available
- Check paper type settings
- Clean print heads or replace cartridges

### Printer not responding after driver installation
- Restart print spooler service
- Check printer connection (USB/network)
- Verify printer is set as default
- Run printer troubleshooter

## Maintenance Tips
- Keep drivers updated regularly
- Monitor manufacturer websites for updates
- Document successful driver versions
- Create system restore points before major updates
- Test print functionality after any system changes

## When to Escalate
- Corporate printer policy violations
- Network printer server issues
- Bulk driver deployment problems
- Licensing or procurement questions
        """,
        "category": "Hardware",
        "tags": ["printer", "driver", "installation", "troubleshooting", "network"],
        "author": "IT Support Team"
    }
]

async def populate_knowledge_base():
    """Populate the knowledge base with sample articles"""
    print("🔧 Initializing database connections...")
    
    try:
        # Initialize database connections
        await init_database_connections(
            postgres_url=None,  # Skip PostgreSQL for KB
            mongodb_url=os.getenv("MONGODB_URL", "mongodb://localhost:27017/aura_servicedesk"),
            mongodb_name="aura_servicedesk",
            redis_url=None  # Skip Redis for this script
        )
        
        # Get MongoDB database and create repository
        mongo_db = db_manager.get_mongo_db()
        kb_repo = MongoRepository("knowledge_base", mongo_db)
        
        print("📚 Checking existing knowledge base articles...")
        
        # Check if articles already exist
        existing_count = await kb_repo.count({})
        print(f"Found {existing_count} existing articles")
        
        if existing_count >= len(SAMPLE_ARTICLES):
            print("✅ Knowledge base already has sufficient articles. Skipping population.")
            return
        
        print(f"📝 Adding {len(SAMPLE_ARTICLES)} sample articles to knowledge base...")
        
        # Add each article
        for i, article_data in enumerate(SAMPLE_ARTICLES, 1):
            # Check if article with same title already exists
            existing = await kb_repo.find_one({"title": article_data["title"]})
            
            if existing:
                print(f"   ⏭️  Article '{article_data['title']}' already exists, skipping...")
                continue
            
            # Prepare article document
            article_doc = {
                **article_data,
                "views": 0,
                "helpful_votes": 0,
                "unhelpful_votes": 0,
                "created_at": datetime.utcnow(),
                "updated_at": datetime.utcnow()
            }
            
            # Insert article
            article_id = await kb_repo.create(article_doc)
            print(f"   ✅ Added article {i}/{len(SAMPLE_ARTICLES)}: '{article_data['title']}'")
        
        # Final count
        final_count = await kb_repo.count({})
        print(f"\n🎉 Knowledge base population completed!")
        print(f"📊 Total articles in database: {final_count}")
        
        # Show category breakdown
        categories = {}
        all_articles = await kb_repo.find_many({}, limit=100)
        for article in all_articles:
            category = article.get("category", "Unknown")
            categories[category] = categories.get(category, 0) + 1
        
        print("\n📋 Articles by category:")
        for category, count in categories.items():
            print(f"   • {category}: {count} articles")
        
    except Exception as e:
        print(f"❌ Error populating knowledge base: {e}")
        raise
    finally:
        # Close database connections
        try:
            await db_manager.close_connections()
            print("🔌 Database connections closed")
        except Exception as e:
            print(f"⚠️  Warning: Error closing connections: {e}")

if __name__ == "__main__":
    print("🚀 Aura Knowledge Base Population Script")
    print("=" * 50)
    
    # Run the population script
    asyncio.run(populate_knowledge_base())
