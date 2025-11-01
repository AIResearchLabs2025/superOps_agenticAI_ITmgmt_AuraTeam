#!/usr/bin/env python3
"""
Generate 50 enhanced ticket scenarios for the Aura Service Desk system
This script creates diverse, realistic tickets with proper distribution across status, priority, and categories
"""

import asyncio
import os
import sys
import json
from datetime import datetime, timedelta
from typing import List, Dict, Any
import random

# Add the shared modules to path
sys.path.append(os.path.join(os.path.dirname(__file__), 'shared'))

from shared.models.base import Priority, Status
from shared.utils.database import init_database_connections, db_manager, MongoRepository

# Enhanced configuration for 50 tickets
TOTAL_TICKETS = 50

# Realistic distribution
STATUS_DISTRIBUTION = {
    Status.OPEN: 18,        # 36% - New tickets awaiting assignment
    Status.IN_PROGRESS: 15, # 30% - Currently being worked on
    Status.RESOLVED: 12,    # 24% - Recently resolved, awaiting closure
    Status.CLOSED: 5        # 10% - Fully completed tickets
}

PRIORITY_DISTRIBUTION = {
    Priority.CRITICAL: 3,   # 6% - System down, major outages
    Priority.HIGH: 12,      # 24% - Urgent business impact
    Priority.MEDIUM: 25,    # 50% - Standard business requests
    Priority.LOW: 10        # 20% - Nice-to-have improvements
}

CATEGORY_DISTRIBUTION = {
    "Software": 15,    # 30% - Application issues, installations
    "Hardware": 12,    # 24% - Equipment problems, replacements
    "Network": 10,     # 20% - Connectivity, VPN, WiFi issues
    "Email": 8,        # 16% - Email client, server issues
    "Access": 3,       # 6% - Permissions, account access
    "Other": 2         # 4% - Miscellaneous issues
}

# Enhanced departments and users
DEPARTMENTS = [
    "Engineering", "Marketing", "Sales", "HR", "Finance", "Operations", 
    "Customer Support", "IT", "Legal", "Product Management", "Executive",
    "Quality Assurance", "Business Development", "Research & Development"
]

# More realistic user names
USER_NAMES = [
    "Sarah Johnson", "Michael Chen", "Emily Davis", "David Wilson", "Lisa Anderson",
    "Robert Garcia", "Jennifer Martinez", "William Brown", "Jessica Taylor", "James Lee",
    "Amanda White", "Christopher Harris", "Michelle Clark", "Daniel Lewis", "Rebecca Walker",
    "Kevin Hall", "Laura Allen", "Steven Young", "Karen King", "Thomas Wright",
    "Nancy Lopez", "Mark Hill", "Sandra Scott", "Andrew Green", "Rachel Adams",
    "Brian Miller", "Ashley Moore", "Ryan Taylor", "Stephanie Wilson", "Justin Clark",
    "Melissa Rodriguez", "Jonathan Davis", "Christina Martinez", "Matthew Anderson",
    "Samantha Thompson", "Nicholas White", "Kimberly Jackson", "Anthony Brown",
    "Elizabeth Johnson", "Joshua Garcia", "Heather Williams", "Alexander Jones",
    "Megan Smith", "Tyler Davis", "Brittany Miller", "Zachary Wilson", "Danielle Moore",
    "Brandon Taylor", "Amber Anderson", "Jordan Thomas", "Kayla Jackson"
]

# Skilled agents with specializations
AGENTS = [
    {"name": "Sarah Wilson", "skills": ["Network", "Hardware", "Security"], "workload": 0},
    {"name": "Mike Chen", "skills": ["Software", "Email", "Access"], "workload": 0},
    {"name": "Emma Rodriguez", "skills": ["Access", "Security", "Other"], "workload": 0},
    {"name": "David Kim", "skills": ["Hardware", "Software", "Network"], "workload": 0},
    {"name": "Lisa Anderson", "skills": ["Email", "Software", "Other"], "workload": 0},
    {"name": "Alex Thompson", "skills": ["Network", "Security", "Hardware"], "workload": 0}
]

# Enhanced ticket scenarios with realistic variety
ENHANCED_TICKET_SCENARIOS = [
    # Critical Priority Scenarios
    {
        "title": "Complete email server outage - all users affected",
        "description": "The main email server has crashed and no users can send or receive emails company-wide. This is affecting all business operations and client communications. Error logs show database connection failures.",
        "category": "Email",
        "priority": Priority.CRITICAL,
        "keywords": ["server", "outage", "email", "critical", "database"]
    },
    {
        "title": "Network infrastructure failure - entire building offline",
        "description": "The main network switch has failed causing complete internet and internal network outage for the entire building. All work has stopped and we cannot access any cloud services or internal systems.",
        "category": "Network", 
        "priority": Priority.CRITICAL,
        "keywords": ["network", "switch", "outage", "building", "infrastructure"]
    },
    {
        "title": "Security breach detected - immediate action required",
        "description": "Our security monitoring system has detected unauthorized access attempts and potential data exfiltration. Multiple failed login attempts from foreign IP addresses. Need immediate security assessment and containment.",
        "category": "Other",
        "priority": Priority.CRITICAL,
        "keywords": ["security", "breach", "unauthorized", "data", "containment"]
    },

    # High Priority Scenarios
    {
        "title": "CEO laptop completely non-functional before board meeting",
        "description": "The CEO's laptop won't boot up and shows a blue screen error. There's an important board meeting in 2 hours and all presentation materials are on this laptop. Need immediate replacement or data recovery.",
        "category": "Hardware",
        "priority": Priority.HIGH,
        "keywords": ["ceo", "laptop", "blue screen", "board meeting", "urgent"]
    },
    {
        "title": "Sales CRM system down during quarter-end",
        "description": "Salesforce CRM is completely inaccessible and showing database errors. This is the last week of the quarter and the sales team cannot access leads, update opportunities, or generate reports.",
        "category": "Software",
        "priority": Priority.HIGH,
        "keywords": ["crm", "salesforce", "quarter-end", "sales", "database"]
    },
    {
        "title": "VPN server overloaded - remote workers cannot connect",
        "description": "The VPN server is at capacity and new connections are being rejected. 60% of our workforce is remote today and cannot access internal systems. Connection timeouts and authentication failures reported.",
        "category": "Network",
        "priority": Priority.HIGH,
        "keywords": ["vpn", "overloaded", "remote", "capacity", "authentication"]
    },
    {
        "title": "Payroll system error before payday",
        "description": "The payroll processing system is showing calculation errors and won't generate paychecks. Payday is tomorrow and HR cannot process payments for 200+ employees. Database integrity issues suspected.",
        "category": "Software",
        "priority": Priority.HIGH,
        "keywords": ["payroll", "payday", "calculation", "database", "employees"]
    },
    {
        "title": "Main file server crashed - project data inaccessible",
        "description": "The primary file server hosting all project documents has crashed with disk errors. Multiple teams cannot access critical project files needed for client deliverables due today.",
        "category": "Hardware",
        "priority": Priority.HIGH,
        "keywords": ["file server", "crashed", "disk errors", "project data", "deliverables"]
    },
    {
        "title": "Email security filter blocking legitimate messages",
        "description": "The new email security system is incorrectly flagging and blocking important client emails and internal communications. Business operations are being severely impacted.",
        "category": "Email",
        "priority": Priority.HIGH,
        "keywords": ["email", "security filter", "blocking", "client", "communications"]
    },
    {
        "title": "Database server running out of disk space",
        "description": "The main database server is at 95% disk capacity and applications are starting to fail. Transaction logs are growing rapidly and we risk complete system failure within hours.",
        "category": "Other",
        "priority": Priority.HIGH,
        "keywords": ["database", "disk space", "capacity", "transaction logs", "system failure"]
    },
    {
        "title": "Backup system failure discovered during restore test",
        "description": "During routine backup testing, we discovered that backups have been failing for the past 2 weeks. We have no recent backup data and are at risk of major data loss.",
        "category": "Other",
        "priority": Priority.HIGH,
        "keywords": ["backup", "failure", "restore test", "data loss", "risk"]
    },
    {
        "title": "Active Directory server authentication issues",
        "description": "Users cannot log into their computers or access network resources. Active Directory is showing replication errors and authentication services are intermittent.",
        "category": "Access",
        "priority": Priority.HIGH,
        "keywords": ["active directory", "authentication", "replication", "network resources", "login"]
    },

    # Medium Priority Scenarios (25 tickets)
    {
        "title": "Laptop screen flickering intermittently during presentations",
        "description": "My laptop screen flickers randomly, especially during PowerPoint presentations. It's embarrassing during client meetings and affects productivity. The issue started after the latest Windows update.",
        "category": "Hardware",
        "priority": Priority.MEDIUM,
        "keywords": ["laptop", "screen", "flickering", "presentations", "windows update"]
    },
    {
        "title": "Microsoft Excel crashes when opening large spreadsheets",
        "description": "Excel consistently crashes when I try to open files larger than 50MB. I work with large datasets for financial analysis and this is significantly impacting my work efficiency.",
        "category": "Software",
        "priority": Priority.MEDIUM,
        "keywords": ["excel", "crashes", "large files", "financial analysis", "datasets"]
    },
    {
        "title": "WiFi connection drops every 30 minutes in conference room",
        "description": "The WiFi in Conference Room B keeps disconnecting every 30 minutes during meetings. Participants have to reconnect frequently, disrupting video calls and presentations.",
        "category": "Network",
        "priority": Priority.MEDIUM,
        "keywords": ["wifi", "conference room", "disconnecting", "video calls", "meetings"]
    },
    {
        "title": "Outlook email synchronization delays with mobile device",
        "description": "Emails take 15-20 minutes to sync between my desktop Outlook and iPhone. This delay is causing me to miss time-sensitive communications and client responses.",
        "category": "Email",
        "priority": Priority.MEDIUM,
        "keywords": ["outlook", "synchronization", "mobile", "delays", "time-sensitive"]
    },
    {
        "title": "Request access to new project SharePoint site",
        "description": "I've been assigned to Project Phoenix and need read/write access to the SharePoint site. My manager confirmed I should have access to all project folders except the confidential budget section.",
        "category": "Access",
        "priority": Priority.MEDIUM,
        "keywords": ["sharepoint", "project phoenix", "access", "read/write", "permissions"]
    },
    {
        "title": "Printer queue stuck with multiple jobs pending",
        "description": "The 3rd floor printer has 15 jobs stuck in the queue and won't print anything new. The printer shows as online but documents just sit in the queue indefinitely.",
        "category": "Hardware",
        "priority": Priority.MEDIUM,
        "keywords": ["printer", "queue", "stuck", "3rd floor", "pending jobs"]
    },
    {
        "title": "Teams application freezes during screen sharing",
        "description": "Microsoft Teams consistently freezes when I try to share my screen during meetings. Audio continues but video becomes unresponsive, forcing me to restart the application.",
        "category": "Software",
        "priority": Priority.MEDIUM,
        "keywords": ["teams", "freezes", "screen sharing", "video", "meetings"]
    },
    {
        "title": "VPN connection very slow affecting file transfers",
        "description": "When connected to VPN, file transfer speeds drop to less than 1 Mbps. Uploading documents to cloud storage takes hours instead of minutes, severely impacting remote work productivity.",
        "category": "Network",
        "priority": Priority.MEDIUM,
        "keywords": ["vpn", "slow", "file transfers", "cloud storage", "remote work"]
    },
    {
        "title": "Email signature not updating across all devices",
        "description": "I updated my email signature last week but it only shows correctly on my desktop. My mobile phone and tablet still display the old signature, creating inconsistent communications.",
        "category": "Email",
        "priority": Priority.MEDIUM,
        "keywords": ["email signature", "updating", "mobile", "tablet", "inconsistent"]
    },
    {
        "title": "Cannot edit shared documents in OneDrive",
        "description": "I can view shared OneDrive documents but cannot edit them even though I have edit permissions. Getting 'Permission denied' errors when trying to save changes to team documents.",
        "category": "Access",
        "priority": Priority.MEDIUM,
        "keywords": ["onedrive", "shared documents", "edit permissions", "permission denied", "team"]
    },
    {
        "title": "Computer running slowly after Windows update",
        "description": "My computer has been extremely slow since the latest Windows update. Applications take 2-3 minutes to open and the system frequently becomes unresponsive during multitasking.",
        "category": "Software",
        "priority": Priority.MEDIUM,
        "keywords": ["computer", "slow", "windows update", "applications", "unresponsive"]
    },
    {
        "title": "External monitor not detected via USB-C dock",
        "description": "My external monitor stopped working after connecting through the new USB-C dock. The laptop doesn't detect the monitor and I can't extend my display for productivity work.",
        "category": "Hardware",
        "priority": Priority.MEDIUM,
        "keywords": ["external monitor", "usb-c dock", "not detected", "display", "productivity"]
    },
    {
        "title": "Internet browser crashes when accessing specific websites",
        "description": "Chrome crashes consistently when I try to access our vendor portal and client management system. Other websites work fine but these critical business sites cause immediate crashes.",
        "category": "Software",
        "priority": Priority.MEDIUM,
        "keywords": ["browser", "chrome", "crashes", "vendor portal", "client management"]
    },
    {
        "title": "Shared network drive mapping fails after computer restart",
        "description": "Every time I restart my computer, the mapped network drives (S: and T: drives) disappear and I have to manually reconnect them. This happens daily and disrupts my workflow.",
        "category": "Network",
        "priority": Priority.MEDIUM,
        "keywords": ["network drive", "mapping", "restart", "disappear", "workflow"]
    },
    {
        "title": "Email attachments fail to download in web browser",
        "description": "When using Outlook Web App, email attachments show 'Download failed' errors. This only happens in the browser version - desktop Outlook works fine for the same emails.",
        "category": "Email",
        "priority": Priority.MEDIUM,
        "keywords": ["email attachments", "download failed", "web browser", "outlook web app", "desktop"]
    },
    {
        "title": "Need access to financial reporting system for new role",
        "description": "I've been promoted to Financial Analyst and need access to the SAP financial reporting system. My manager submitted the request but I still cannot log in after 3 days.",
        "category": "Access",
        "priority": Priority.MEDIUM,
        "keywords": ["financial reporting", "sap", "new role", "analyst", "log in"]
    },
    {
        "title": "Keyboard keys sticking affecting typing speed",
        "description": "Several keys on my keyboard are sticking, particularly the spacebar and Enter key. This is significantly slowing down my typing and causing errors in documents and emails.",
        "category": "Hardware",
        "priority": Priority.MEDIUM,
        "keywords": ["keyboard", "keys sticking", "spacebar", "typing speed", "errors"]
    },
    {
        "title": "Adobe Creative Suite license expired need renewal",
        "description": "My Adobe Creative Suite license expired and I cannot access Photoshop or Illustrator needed for marketing materials. The design team is waiting for assets for the new campaign.",
        "category": "Software",
        "priority": Priority.MEDIUM,
        "keywords": ["adobe", "creative suite", "license expired", "photoshop", "marketing"]
    },
    {
        "title": "WiFi password not working for guest network",
        "description": "Clients visiting our office cannot connect to the guest WiFi network. The password we provide doesn't work and they cannot access internet for their presentations and demos.",
        "category": "Network",
        "priority": Priority.MEDIUM,
        "keywords": ["wifi password", "guest network", "clients", "presentations", "demos"]
    },
    {
        "title": "Spam emails bypassing security filter",
        "description": "I'm receiving 10-15 obvious spam emails daily that are getting past our email security system. These include phishing attempts and malware attachments that pose security risks.",
        "category": "Email",
        "priority": Priority.MEDIUM,
        "keywords": ["spam emails", "security filter", "phishing", "malware", "security risks"]
    },
    {
        "title": "Cannot access HR portal to update personal information",
        "description": "The HR self-service portal shows 'Access Denied' when I try to update my address and emergency contact information. I need to update this for insurance purposes.",
        "category": "Access",
        "priority": Priority.MEDIUM,
        "keywords": ["hr portal", "access denied", "personal information", "address", "insurance"]
    },
    {
        "title": "Webcam not working for video conferences",
        "description": "My laptop's built-in webcam stopped working and shows up as 'Device not found' in Teams and Zoom. I have important client video calls scheduled and need this resolved quickly.",
        "category": "Hardware",
        "priority": Priority.MEDIUM,
        "keywords": ["webcam", "not working", "device not found", "teams", "client calls"]
    },
    {
        "title": "PowerPoint presentations corrupted after auto-save",
        "description": "Several important PowerPoint presentations have become corrupted after the auto-save feature activated. Files show 'Cannot open' errors and I may have lost hours of work.",
        "category": "Software",
        "priority": Priority.MEDIUM,
        "keywords": ["powerpoint", "corrupted", "auto-save", "cannot open", "lost work"]
    },
    {
        "title": "Network file transfer speeds extremely slow",
        "description": "Copying files to and from the network server takes 10x longer than usual. A 100MB file that used to transfer in 30 seconds now takes 5+ minutes.",
        "category": "Network",
        "priority": Priority.MEDIUM,
        "keywords": ["network", "file transfer", "slow", "server", "performance"]
    },
    {
        "title": "Email rules not working after system update",
        "description": "All my Outlook email rules stopped working after the recent system update. Emails are no longer being automatically sorted into folders and I'm missing important messages.",
        "category": "Email",
        "priority": Priority.MEDIUM,
        "keywords": ["email rules", "outlook", "system update", "sorting", "folders"]
    },

    # Low Priority Scenarios (10 tickets)
    {
        "title": "Request installation of additional software for productivity",
        "description": "I would like to have Notepad++ and 7-Zip installed on my workstation to improve my development workflow. These are free tools that would help with text editing and file compression tasks.",
        "category": "Software",
        "priority": Priority.LOW,
        "keywords": ["software installation", "notepad++", "7-zip", "productivity", "development"]
    },
    {
        "title": "Mouse scroll wheel occasionally unresponsive",
        "description": "The scroll wheel on my mouse sometimes doesn't respond and I have to click and drag the scrollbar instead. It's a minor inconvenience but affects efficiency when reviewing long documents.",
        "category": "Hardware",
        "priority": Priority.LOW,
        "keywords": ["mouse", "scroll wheel", "unresponsive", "documents", "efficiency"]
    },
    {
        "title": "Desktop wallpaper resets to default after restart",
        "description": "My custom desktop wallpaper keeps reverting to the default Windows background after each restart. It's not critical but I'd like to keep my personalized workspace setup.",
        "category": "Software",
        "priority": Priority.LOW,
        "keywords": ["desktop wallpaper", "resets", "default", "restart", "personalized"]
    },
    {
        "title": "Request for ergonomic keyboard for comfort",
        "description": "I've been experiencing some wrist discomfort during long typing sessions. Could I get an ergonomic keyboard to help prevent repetitive strain injury and improve comfort?",
        "category": "Hardware",
        "priority": Priority.LOW,
        "keywords": ["ergonomic keyboard", "wrist discomfort", "typing", "strain injury", "comfort"]
    },
    {
        "title": "WiFi signal weak in corner office location",
        "description": "The WiFi signal in my corner office is weaker than other locations. Internet works but is slower for video calls and large file downloads. Not urgent but would improve productivity.",
        "category": "Network",
        "priority": Priority.LOW,
        "keywords": ["wifi signal", "weak", "corner office", "video calls", "productivity"]
    },
    {
        "title": "Email notification sound too quiet to hear",
        "description": "The email notification sound is very quiet and I often miss new messages. Could the volume be increased or a different notification sound be configured?",
        "category": "Email",
        "priority": Priority.LOW,
        "keywords": ["email notification", "sound", "quiet", "volume", "messages"]
    },
    {
        "title": "Request access to optional training portal",
        "description": "I'd like access to the LinkedIn Learning portal for professional development. It's not required for my current role but would help with skill enhancement and career growth.",
        "category": "Access",
        "priority": Priority.LOW,
        "keywords": ["training portal", "linkedin learning", "professional development", "skill enhancement", "career"]
    },
    {
        "title": "Computer fan noise slightly louder than usual",
        "description": "My computer's fan seems to run a bit louder than before, especially during intensive tasks. It's not affecting performance but the noise is somewhat distracting in the quiet office.",
        "category": "Hardware",
        "priority": Priority.LOW,
        "keywords": ["computer fan", "noise", "louder", "intensive tasks", "distracting"]
    },
    {
        "title": "Suggestion to update company screensaver",
        "description": "The current company screensaver shows outdated branding and old contact information. It would be nice to update it with current logos and messaging for a more professional appearance.",
        "category": "Software",
        "priority": Priority.LOW,
        "keywords": ["screensaver", "outdated branding", "contact information", "logos", "professional"]
    },
    {
        "title": "Request for dual monitor setup for better workflow",
        "description": "I currently work with a single monitor but would be more productive with a dual monitor setup. This would help with multitasking between applications and improve overall efficiency.",
        "category": "Hardware",
        "priority": Priority.LOW,
        "keywords": ["dual monitor", "workflow", "productivity", "multitasking", "efficiency"]
    }
]

async def check_existing_tickets_count():
    """Check how many tickets already exist in the database"""
    try:
        # Initialize database connections
        await init_database_connections(
            postgres_url=None,  # Skip PostgreSQL
            mongodb_url=os.getenv("MONGODB_URL", "mongodb://localhost:27017"),
            mongodb_name="aura_servicedesk",
            redis_url=os.getenv("REDIS_URL", "redis://localhost:6379")
        )
        
        # Get MongoDB repository for tickets
        tickets_repo = MongoRepository("tickets", db_manager.get_mongo_db())
        
        # Count existing tickets
        existing_count = await tickets_repo.count({})
        return existing_count
        
    except Exception as e:
        print(f"⚠️ Error checking existing tickets: {e}")
        return 0

async def generate_enhanced_tickets():
    """Generate 50 enhanced ticket scenarios with realistic distribution"""
    
    try:
        print("🎫 Starting enhanced ticket generation (50 tickets)...")
        
        # Check existing tickets
        existing_count = await check_existing_tickets_count()
        print(f"📊 Found {existing_count} existing tickets in database")
        
        if existing_count >= 50:
            print(f"✅ Database already has {existing_count} tickets (≥50). Skipping generation.")
            print("💡 To regenerate tickets, clear the database first or lower the threshold.")
            return existing_count
        
        # Initialize database connections
        print("📊 Initializing database connections...")
        await init_database_connections(
            postgres_url=None,  # Skip PostgreSQL
            mongodb_url=os.getenv("MONGODB_URL", "mongodb://localhost:27017"),
            mongodb_name="aura_servicedesk",
            redis_url=os.getenv("REDIS_URL", "redis://localhost:6379")
        )
        
        # Get MongoDB repository for tickets
        tickets_repo = MongoRepository("tickets", db_manager.get_mongo_db())
        
        print("🔢 Generating enhanced tickets with realistic distribution...")
        
        # Create distribution lists
        status_list = []
        for status, count in STATUS_DISTRIBUTION.items():
            status_list.extend([status] * count)
        
        priority_list = []
        for priority, count in PRIORITY_DISTRIBUTION.items():
            priority_list.extend([priority] * count)
        
        category_list = []
        for category, count in CATEGORY_DISTRIBUTION.items():
            category_list.extend([category] * count)
        
        # Shuffle for randomness
        random.shuffle(status_list)
        random.shuffle(priority_list)
        random.shuffle(category_list)
        
        tickets_created = 0
        
        # Generate tickets based on scenarios
        for i in range(TOTAL_TICKETS):
            if i < len(ENHANCED_TICKET_SCENARIOS):
                # Use predefined scenarios
                scenario = ENHANCED_TICKET_SCENARIOS[i]
                title = scenario["title"]
                description = scenario["description"]
                category = scenario["category"]
                priority = scenario["priority"]
            else:
                # Generate additional tickets for remaining slots
                base_scenarios = [
                    "Software installation request for team productivity",
                    "Hardware replacement needed for aging equipment", 
                    "Network connectivity issues in specific office area",
                    "Email configuration problem for new employee",
                    "Access request for departmental shared resources"
                ]
                title = f"{random.choice(base_scenarios)} #{i+1}"
                description = f"Additional ticket generated to reach 50 total tickets. This represents typical IT support requests that occur in daily operations."
                category = category_list[i] if i < len(category_list) else "Other"
                priority = priority_list[i] if i < len(priority_list) else Priority.MEDIUM
            
            # Generate realistic user data
            user_name = random.choice(USER_NAMES)
            department = random.choice(DEPARTMENTS)
            
            # Create email from name
            name_parts = user_name.lower().split()
            if len(name_parts) >= 2:
                user_email = f"{name_parts[0]}.{name_parts[1]}@company.com"
            else:
                user_email = f"{name_parts[0]}@company.com"
            
            user_id = f"USR{random.randint(10000, 99999)}"
            
            # Assign status from distribution
            status = status_list[i] if i < len(status_list) else Status.OPEN
            
            # Create realistic timestamps
            if status == Status.CLOSED:
                # Closed tickets are older
                days_ago = random.randint(7, 60)
            elif status == Status.RESOLVED:
                # Resolved tickets are recent
                days_ago = random.randint(1, 14)
            elif status == Status.IN_PROGRESS:
                # In progress tickets are current
                days_ago = random.randint(0, 7)
            else:
                # Open tickets are very recent
                days_ago = random.randint(0, 3)
            
            # Add business hours weighting
            if random.random() < 0.8:  # 80% during business hours
                hour = random.randint(8, 18)
            else:  # 20% outside business hours
                hour = random.choice(list(range(0, 8)) + list(range(19, 24)))
            
            created_time = datetime.utcnow() - timedelta(
                days=days_ago, 
                hours=random.randint(0, 23),
                minutes=random.randint(0, 59)
            )
            created_time = created_time.replace(hour=hour)
            
            # Create ticket document
            ticket_doc = {
                "title": title,
                "description": description,
                "category": category,
                "priority": priority,
                "status": status,
                "user_id": user_id,
                "user_email": user_email,
                "user_name": user_name,
                "department": department,
                "attachments": [],
                "ai_suggestions": [
                    {
                        "type": "category_confidence",
                        "content": f"Automatically categorized as '{category}' with {random.randint(85, 98)}% confidence",
                        "confidence": random.uniform(0.85, 0.98)
                    }
                ],
                "created_at": created_time,
                "updated_at": created_time
            }
            
            # Add agent assignment and resolution for non-open tickets
            if status != Status.OPEN:
                # Find best agent based on skills
                best_agent = None
                for agent in AGENTS:
                    if category in agent["skills"] and agent["workload"] < 8:
                        best_agent = agent
                        break
                
                if not best_agent:
                    # Fallback to least loaded agent
                    best_agent = min(AGENTS, key=lambda x: x["workload"])
                
                ticket_doc["assigned_to"] = best_agent["name"]
                best_agent["workload"] += 1
                
                # Add resolution for resolved/closed tickets
                if status in [Status.RESOLVED, Status.CLOSED]:
                    resolutions = [
                        "Issue resolved by restarting the service and updating configuration settings.",
                        "Problem fixed by reinstalling the application and clearing user profile cache.",
                        "Resolved by replacing faulty hardware component and testing functionality.",
                        "Fixed by updating network drivers and adjusting firewall settings.",
                        "Issue resolved through user training and process documentation update.",
                        "Problem solved by applying security patches and system updates.",
                        "Resolved by reconfiguring email client settings and testing connectivity.",
                        "Fixed by clearing browser cache and updating application to latest version.",
                        "Issue resolved by adjusting user permissions and access controls.",
                        "Problem fixed by optimizing system performance and removing unnecessary software."
                    ]
                    ticket_doc["resolution"] = random.choice(resolutions)
                    
                    # Calculate realistic resolution time based on priority
                    if priority == Priority.CRITICAL:
                        resolution_hours = random.uniform(0.5, 4)
                    elif priority == Priority.HIGH:
                        resolution_hours = random.uniform(2, 24)
                    elif priority == Priority.MEDIUM:
                        resolution_hours = random.uniform(4, 72)
                    else:
                        resolution_hours = random.uniform(24, 168)
                    
                    resolution_time = created_time + timedelta(hours=resolution_hours)
                    ticket_doc["updated_at"] = resolution_time
            
            # Insert ticket into database
            ticket_id = await tickets_repo.create(ticket_doc)
            tickets_created += 1
            
            # Progress indicator
            if tickets_created % 10 == 0:
                print(f"✅ Created {tickets_created}/50 tickets...")
        
        print(f"\n🎉 Successfully generated {tickets_created} enhanced tickets!")
        print("📈 Ticket distribution:")
        
        # Show summary statistics
        print("\n📊 Status Distribution:")
        for status, count in STATUS_DISTRIBUTION.items():
            print(f"  {status.value}: {count} tickets")
            
        print("\n🎯 Priority Distribution:")
        for priority, count in PRIORITY_DISTRIBUTION.items():
            print(f"  {priority.value}: {count} tickets")
            
        print("\n📋 Category Distribution:")
        for category, count in CATEGORY_DISTRIBUTION.items():
            print(f"  {category}: {count} tickets")
            
        print(f"\n👥 Generated for {len(DEPARTMENTS)} departments")
        print(f"🕐 Time span: Past 60 days with business hours weighting")
        print(f"👨‍💼 Assigned to {len(AGENTS)} skilled agents")
        
        print("\n✨ Enhanced tickets have been successfully added to the database!")
        print("🌐 You can now view them in the Dashboard and 'All Tickets' section.")
        
        return tickets_created
        
    except Exception as e:
        print(f"❌ Error generating enhanced tickets: {e}")
        raise
    finally:
        # Close database connections
        try:
            await db_manager.close_connections()
            print("🔐 Database connections closed.")
        except Exception as e:
            print(f"⚠️ Error closing connections: {e}")

def main():
    """Main function to run enhanced ticket generation"""
    print("🚀 Aura Service Desk - Enhanced Ticket Generator (50 Tickets)")
    print("=" * 60)
    
    # Check if we're in the right directory
    if not os.path.exists("shared"):
        print("❌ Error: Please run this script from the aura-backend directory")
        print("Current directory should contain the 'shared' folder")
        return 1
    
    # Run the async function
    try:
        result = asyncio.run(generate_enhanced_tickets())
        if result >= 50:
            print(f"\n🎯 Target achieved: {result} tickets in database")
        return 0
    except KeyboardInterrupt:
        print("\n⚠️ Operation cancelled by user")
        return 1
    except Exception as e:
        print(f"\n❌ Fatal error: {e}")
        return 1

if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)
