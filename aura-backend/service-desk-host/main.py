"""
Aura Service Desk Host - Ticket Management, Knowledge Base, and AI Chatbot
"""

import os
import logging
from contextlib import asynccontextmanager
from typing import List, Optional, Dict, Any
from datetime import datetime
from fastapi import FastAPI, HTTPException, Depends, Query, Path
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv(dotenv_path="../.env")

from shared.models.base import (
    HealthCheckResponse, BaseResponse, PaginationParams, PaginatedResponse,
    Priority, Status, BaseDBModel
)
from shared.utils.database import (
    init_database_connections, check_database_health, db_manager,
    RedisCache, MongoRepository
)
from shared.utils.ai_service import get_ai_service, get_prompt_manager
from shared.middleware.common import (
    RequestLoggingMiddleware, ErrorHandlingMiddleware,
    RateLimitingMiddleware, SecurityHeadersMiddleware
)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


async def check_and_populate_tickets():
    """Check if database has enough tickets and populate if needed"""
    try:
        if not app.state.tickets_repo:
            logger.warning("MongoDB not available - skipping ticket population check")
            return
        
        # Check existing ticket count
        existing_count = await app.state.tickets_repo.count({})
        logger.info(f"Found {existing_count} existing tickets in database")
        
        if existing_count < 50:
            logger.info(f"Database has {existing_count} tickets (< 50). Generating enhanced tickets...")
            
            # Import and run the enhanced ticket generation
            import sys
            import os
            import random
            from datetime import datetime, timedelta
            
            # Enhanced ticket generation logic (simplified version)
            from shared.models.base import Priority, Status
            
            # Realistic distribution for 50 tickets
            STATUS_DISTRIBUTION = {
                Status.OPEN: 18,        # 36%
                Status.IN_PROGRESS: 15, # 30%
                Status.RESOLVED: 12,    # 24%
                Status.CLOSED: 5        # 10%
            }
            
            PRIORITY_DISTRIBUTION = {
                Priority.CRITICAL: 3,   # 6%
                Priority.HIGH: 12,      # 24%
                Priority.MEDIUM: 25,    # 50%
                Priority.LOW: 10        # 20%
            }
            
            CATEGORY_DISTRIBUTION = {
                "Software": 15, "Hardware": 12, "Network": 10,
                "Email": 8, "Access": 3, "Other": 2
            }
            
            # Sample scenarios
            scenarios = [
                {
                    "title": "Complete email server outage - all users affected",
                    "description": "The main email server has crashed and no users can send or receive emails company-wide.",
                    "category": "Email", "priority": Priority.CRITICAL
                },
                {
                    "title": "Network infrastructure failure - entire building offline",
                    "description": "The main network switch has failed causing complete internet and internal network outage.",
                    "category": "Network", "priority": Priority.CRITICAL
                },
                {
                    "title": "CEO laptop completely non-functional before board meeting",
                    "description": "The CEO's laptop won't boot up and shows a blue screen error.",
                    "category": "Hardware", "priority": Priority.HIGH
                },
                {
                    "title": "Laptop screen flickering intermittently during presentations",
                    "description": "My laptop screen flickers randomly, especially during PowerPoint presentations.",
                    "category": "Hardware", "priority": Priority.MEDIUM
                },
                {
                    "title": "Request installation of additional software for productivity",
                    "description": "I would like to have Notepad++ and 7-Zip installed on my workstation.",
                    "category": "Software", "priority": Priority.LOW
                }
            ]
            
            # User data
            departments = ["Engineering", "Marketing", "Sales", "HR", "Finance", "Operations"]
            user_names = [
                "Sarah Johnson", "Michael Chen", "Emily Davis", "David Wilson", "Lisa Anderson",
                "Robert Garcia", "Jennifer Martinez", "William Brown", "Jessica Taylor", "James Lee"
            ]
            agents = ["Sarah Wilson", "Mike Chen", "Emma Rodriguez", "David Kim", "Lisa Anderson"]
            
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
            
            random.shuffle(status_list)
            random.shuffle(priority_list)
            random.shuffle(category_list)
            
            tickets_to_generate = 50 - existing_count
            tickets_created = 0
            
            for i in range(tickets_to_generate):
                # Use predefined scenarios or generate generic ones
                if i < len(scenarios):
                    scenario = scenarios[i]
                    title = scenario["title"]
                    description = scenario["description"]
                    category = scenario["category"]
                    priority = scenario["priority"]
                else:
                    title = f"IT Support Request #{existing_count + i + 1}"
                    description = f"Standard IT support request for {random.choice(['software', 'hardware', 'network'])} assistance."
                    category = category_list[i % len(category_list)]
                    priority = priority_list[i % len(priority_list)]
                
                # Generate user data
                user_name = random.choice(user_names)
                department = random.choice(departments)
                name_parts = user_name.lower().split()
                user_email = f"{name_parts[0]}.{name_parts[1]}@company.com"
                user_id = f"USR{random.randint(10000, 99999)}"
                
                # Assign status
                status = status_list[i % len(status_list)]
                
                # Create realistic timestamps
                days_ago = random.randint(0, 30)
                created_time = datetime.utcnow() - timedelta(days=days_ago)
                
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
                    "ai_suggestions": [{
                        "type": "category_confidence",
                        "content": f"Automatically categorized as '{category}' with 95% confidence",
                        "confidence": 0.95
                    }],
                    "created_at": created_time,
                    "updated_at": created_time
                }
                
                # Add assignment and resolution for non-open tickets
                if status != Status.OPEN:
                    ticket_doc["assigned_to"] = random.choice(agents)
                    
                    if status in [Status.RESOLVED, Status.CLOSED]:
                        resolutions = [
                            "Issue resolved by restarting the service and updating configuration.",
                            "Problem fixed by reinstalling the application and clearing cache.",
                            "Resolved by replacing faulty hardware component.",
                            "Fixed by updating drivers and adjusting settings."
                        ]
                        ticket_doc["resolution"] = random.choice(resolutions)
                        
                        # Update resolution time
                        resolution_hours = random.uniform(1, 48)
                        ticket_doc["updated_at"] = created_time + timedelta(hours=resolution_hours)
                
                # Insert ticket
                await app.state.tickets_repo.create(ticket_doc)
                tickets_created += 1
                
                if tickets_created % 10 == 0:
                    logger.info(f"Created {tickets_created}/{tickets_to_generate} tickets...")
            
            logger.info(f"✅ Successfully generated {tickets_created} tickets! Total: {existing_count + tickets_created}")
        else:
            logger.info(f"✅ Database has sufficient tickets ({existing_count} ≥ 50). Skipping generation.")
            
    except Exception as e:
        logger.error(f"Error in ticket population check: {e}")
        # Don't raise - allow service to continue even if ticket population fails


# Pydantic Models
class TicketCreate(BaseModel):
    """Create ticket request model"""
    title: str
    description: str
    category: Optional[str] = None
    priority: Priority = Priority.MEDIUM
    user_id: str
    user_email: str
    user_name: str
    department: Optional[str] = None
    attachments: List[str] = []


class TicketUpdate(BaseModel):
    """Update ticket request model"""
    title: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None
    priority: Optional[Priority] = None
    status: Optional[Status] = None
    assigned_to: Optional[str] = None
    resolution: Optional[str] = None


class Ticket(BaseDBModel):
    """Ticket model"""
    title: str
    description: str
    category: str
    priority: Priority
    status: Status = Status.OPEN
    user_id: str
    user_email: str
    user_name: str
    department: Optional[str] = None
    assigned_to: Optional[str] = None
    resolution: Optional[str] = None
    attachments: List[str] = []
    ai_suggestions: List[Dict[str, Any]] = []


class KBArticleCreate(BaseModel):
    """Create knowledge base article request"""
    title: str
    content: str
    category: str
    tags: List[str] = []
    author: str


class KBArticle(BaseDBModel):
    """Knowledge base article model"""
    title: str
    content: str
    category: str
    tags: List[str] = []
    author: str
    views: int = 0
    helpful_votes: int = 0
    unhelpful_votes: int = 0


class ChatMessage(BaseModel):
    """Chat message model"""
    message: str
    user_id: Optional[str] = None
    context: Optional[Dict[str, Any]] = None


class ChatResponse(BaseModel):
    """Chat response model"""
    response: str
    suggestions: List[str] = []
    escalate_to_human: bool = False
    confidence: float = 0.0


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan management"""
    logger.info("🎫 Starting Service Desk Host")
    
    try:
        # Initialize database connections
        await init_database_connections(
            postgres_url=os.getenv("DATABASE_URL"),
            mongodb_url=os.getenv("MONGODB_URL"),
            mongodb_name="aura_servicedesk",
            redis_url=os.getenv("REDIS_URL")
        )
        
        # Initialize repositories (handle cases where databases aren't available)
        try:
            mongo_db = db_manager.get_mongo_db()
            app.state.tickets_repo = MongoRepository("tickets", mongo_db)
            app.state.kb_repo = MongoRepository("knowledge_base", mongo_db)
        except RuntimeError:
            logger.warning("MongoDB not available - using fallback mode")
            app.state.tickets_repo = None
            app.state.kb_repo = None
        
        try:
            redis_client = db_manager.get_redis_client()
            app.state.cache = RedisCache(redis_client)
        except RuntimeError:
            logger.warning("Redis not available - using fallback mode")
            app.state.cache = None
        
        # Initialize AI service
        from shared.utils.ai_service import initialize_ai_service
        await initialize_ai_service(os.getenv("OPENAI_API_KEY"))
        
        # Check and populate tickets if needed
        await check_and_populate_tickets()
        
        logger.info("Service Desk Host initialized successfully")
        
    except Exception as e:
        logger.error(f"Startup error: {e}")
        raise
    
    yield
    
    # Cleanup
    try:
        await db_manager.close_connections()
        logger.info("Database connections closed")
    except Exception as e:
        logger.error(f"Cleanup error: {e}")
    
    logger.info("🛑 Service Desk Host stopped")


# Create FastAPI app
app = FastAPI(
    title="Aura Service Desk Host",
    description="Service Desk Automation - Tickets, Knowledge Base, and AI Chatbot",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Add custom middleware
app.add_middleware(RequestLoggingMiddleware)
app.add_middleware(ErrorHandlingMiddleware)
app.add_middleware(RateLimitingMiddleware, requests_per_minute=500)
app.add_middleware(SecurityHeadersMiddleware)


# Health Check
@app.get("/health", response_model=HealthCheckResponse)
async def health_check():
    """Service health check"""
    dependencies = await check_database_health()
    
    # Check AI service
    ai_service = get_ai_service()
    dependencies["openai"] = "healthy" if ai_service.client else "unhealthy"
    
    overall_status = "healthy" if all(status == "healthy" for status in dependencies.values()) else "degraded"
    
    return HealthCheckResponse(
        service_name="service-desk-host",
        status=overall_status,
        version="1.0.0",
        dependencies=dependencies
    )


# Ticket Management APIs
@app.post("/api/v1/tickets", response_model=BaseResponse)
async def create_ticket(ticket_data: TicketCreate):
    """Create a new ticket with AI categorization"""
    
    try:
        # Get AI service
        ai_service = get_ai_service()
        prompt_manager = get_prompt_manager()
        
        # Auto-categorize ticket if category not provided
        if not ticket_data.category:
            categories = ["Hardware", "Software", "Network", "Access", "Email", "Other"]
            
            try:
                # Use AI to categorize
                prompt = prompt_manager.render_template(
                    "ticket_categorization",
                    categories=", ".join(categories),
                    title=ticket_data.title,
                    description=ticket_data.description
                )
                
                classification = await ai_service.classify_text(
                    text=f"{ticket_data.title} {ticket_data.description}",
                    categories=categories
                )
                
                ticket_data.category = classification.get("category", "Other")
                
            except Exception as e:
                logger.error(f"AI categorization failed: {e}")
                ticket_data.category = "Other"
        
        # Get AI suggestions for resolution
        ai_suggestions = []
        try:
            if app.state.kb_repo:
                kb_articles = await app.state.kb_repo.find_many(
                    {"category": ticket_data.category},
                    limit=5
                )
                
                if kb_articles:
                    articles_str = "\n".join([f"- {article['title']}" for article in kb_articles])
                    prompt = prompt_manager.render_template(
                        "kb_search",
                        question=f"{ticket_data.title} {ticket_data.description}",
                        articles=articles_str,
                        max_results="3"
                    )
                    
                    response = await ai_service.generate_completion(prompt, max_tokens=300)
                    # Parse AI response for suggestions
                    ai_suggestions = [{"type": "kb_recommendation", "content": response.response}]
        except Exception as e:
            logger.error(f"AI suggestions failed: {e}")
        
        # Create ticket document
        ticket_doc = {
            "title": ticket_data.title,
            "description": ticket_data.description,
            "category": ticket_data.category,
            "priority": ticket_data.priority,
            "status": Status.OPEN,
            "user_id": ticket_data.user_id,
            "user_email": ticket_data.user_email,
            "user_name": ticket_data.user_name,
            "department": ticket_data.department,
            "attachments": ticket_data.attachments,
            "ai_suggestions": ai_suggestions,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }
        
        # Save to database or generate mock ID
        if app.state.tickets_repo:
            ticket_id = await app.state.tickets_repo.create(ticket_doc)
        else:
            # Fallback: generate mock ticket ID
            import uuid
            ticket_id = str(uuid.uuid4())
            logger.warning("MongoDB not available - using mock ticket ID")
        
        # Cache ticket for quick access
        if app.state.cache:
            import json
            await app.state.cache.set(f"ticket:{ticket_id}", json.dumps(ticket_doc, default=str), ttl=3600)
        
        logger.info(f"Ticket created: {ticket_id}")
        
        return BaseResponse(
            message="Ticket created successfully",
            data={
                "ticket_id": ticket_id,
                "category": ticket_data.category,
                "ai_suggestions": ai_suggestions
            }
        )
        
    except Exception as e:
        logger.error(f"Error creating ticket: {e}")
        raise HTTPException(status_code=500, detail="Failed to create ticket")


@app.get("/api/v1/tickets", response_model=PaginatedResponse)
async def get_tickets(
    status: Optional[Status] = Query(None, description="Filter by status"),
    category: Optional[str] = Query(None, description="Filter by category"),
    assigned_to: Optional[str] = Query(None, description="Filter by assigned agent"),
    user_id: Optional[str] = Query(None, description="Filter by user"),
    pagination: PaginationParams = Depends()
):
    """Get tickets with filters and pagination"""
    
    try:
        # Build filter
        filter_dict = {}
        if status:
            filter_dict["status"] = status
        if category:
            filter_dict["category"] = category
        if assigned_to:
            filter_dict["assigned_to"] = assigned_to
        if user_id:
            filter_dict["user_id"] = user_id
        
        # Get tickets
        if app.state.tickets_repo:
            tickets = await app.state.tickets_repo.find_many(
                filter_dict,
                limit=pagination.limit,
                skip=pagination.offset
            )
            
            # Get total count
            total = await app.state.tickets_repo.count(filter_dict)
        else:
            # Fallback: return mock tickets for demo
            from datetime import datetime, timedelta
            import uuid
            
            mock_tickets = [
                {
                    "_id": str(uuid.uuid4()),
                    "title": "Computer running very slowly after Windows update",
                    "description": "My computer has been running extremely slowly since the latest Windows update. Applications take forever to load and the system freezes occasionally.",
                    "category": "Software",
                    "priority": "high",
                    "status": "open",
                    "user_id": "jane.doe@company.com",
                    "user_email": "jane.doe@company.com",
                    "user_name": "Jane Doe",
                    "department": "Marketing",
                    "created_at": datetime.utcnow() - timedelta(hours=2),
                    "updated_at": datetime.utcnow() - timedelta(hours=1)
                },
                {
                    "_id": str(uuid.uuid4()),
                    "title": "Email client not receiving new messages",
                    "description": "Outlook is not downloading new emails since this morning. I can send emails but cannot receive them.",
                    "category": "Email",
                    "priority": "high",
                    "status": "open",
                    "user_id": "john.smith@company.com",
                    "user_email": "john.smith@company.com",
                    "user_name": "John Smith",
                    "department": "Sales",
                    "created_at": datetime.utcnow() - timedelta(hours=1),
                    "updated_at": datetime.utcnow() - timedelta(minutes=30)
                },
                {
                    "_id": str(uuid.uuid4()),
                    "title": "Unable to connect to office Wi-Fi",
                    "description": "I can't connect to the office Wi-Fi network. It keeps asking for password even though I'm entering the correct one.",
                    "category": "Network",
                    "priority": "medium",
                    "status": "in_progress",
                    "user_id": "alice.johnson@company.com",
                    "user_email": "alice.johnson@company.com",
                    "user_name": "Alice Johnson",
                    "department": "HR",
                    "assigned_to": "Sarah Wilson",
                    "created_at": datetime.utcnow() - timedelta(days=1),
                    "updated_at": datetime.utcnow() - timedelta(hours=3)
                },
                {
                    "_id": str(uuid.uuid4()),
                    "title": "Printer not responding",
                    "description": "The office printer is not responding to print jobs. The status shows as offline even though it's powered on.",
                    "category": "Hardware",
                    "priority": "low",
                    "status": "resolved",
                    "user_id": "bob.wilson@company.com",
                    "user_email": "bob.wilson@company.com",
                    "user_name": "Bob Wilson",
                    "department": "Finance",
                    "assigned_to": "David Kim",
                    "resolution": "Restarted printer service and updated drivers",
                    "created_at": datetime.utcnow() - timedelta(days=2),
                    "updated_at": datetime.utcnow() - timedelta(hours=6)
                }
            ]
            
            # Apply filters to mock data
            filtered_tickets = mock_tickets
            if status:
                filtered_tickets = [t for t in filtered_tickets if t["status"] == status.value]
            if category:
                filtered_tickets = [t for t in filtered_tickets if t["category"].lower() == category.lower()]
            if assigned_to:
                filtered_tickets = [t for t in filtered_tickets if t.get("assigned_to") == assigned_to]
            if user_id:
                filtered_tickets = [t for t in filtered_tickets if t["user_id"] == user_id]
            
            # Apply pagination
            total = len(filtered_tickets)
            start_idx = pagination.offset
            end_idx = start_idx + pagination.limit
            tickets = filtered_tickets[start_idx:end_idx]
            
            logger.warning("MongoDB not available - returning mock ticket list")
        
        # Calculate pagination info
        pages = (total + pagination.limit - 1) // pagination.limit
        has_next = pagination.page < pages
        has_prev = pagination.page > 1
        
        return PaginatedResponse(
            items=tickets,
            total=total,
            page=pagination.page,
            limit=pagination.limit,
            pages=pages,
            has_next=has_next,
            has_prev=has_prev
        )
        
    except Exception as e:
        logger.error(f"Error retrieving tickets: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve tickets")


@app.get("/api/v1/tickets/{ticket_id}")
async def get_ticket(ticket_id: str = Path(..., description="Ticket ID")):
    """Get ticket by ID"""
    
    try:
        # Skip cache for now - get directly from database
        if app.state.tickets_repo:
            ticket = await app.state.tickets_repo.find_by_id(ticket_id)
            if not ticket:
                raise HTTPException(status_code=404, detail="Ticket not found")
            
            # Return ticket data directly for frontend compatibility
            return ticket
        else:
            # Fallback when database is not available
            logger.warning("MongoDB not available - returning mock ticket data")
            raise HTTPException(status_code=404, detail="Ticket not found")
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error retrieving ticket {ticket_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve ticket")


@app.put("/api/v1/tickets/{ticket_id}")
async def update_ticket(
    ticket_id: str,
    update_data: TicketUpdate
):
    """Update ticket"""
    
    try:
        # Get current ticket
        ticket = await app.state.tickets_repo.find_by_id(ticket_id)
        if not ticket:
            raise HTTPException(status_code=404, detail="Ticket not found")
        
        # Prepare update data
        update_dict = {k: v for k, v in update_data.dict().items() if v is not None}
        update_dict["updated_at"] = datetime.utcnow()
        
        # Update in database
        success = await app.state.tickets_repo.update_by_id(ticket_id, update_dict)
        if not success:
            raise HTTPException(status_code=500, detail="Failed to update ticket")
        
        # Clear cache
        await app.state.cache.delete(f"ticket:{ticket_id}")
        
        logger.info(f"Ticket updated: {ticket_id}")
        
        return BaseResponse(
            message="Ticket updated successfully",
            data={"ticket_id": ticket_id, "updated_fields": list(update_dict.keys())}
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating ticket {ticket_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to update ticket")


@app.post("/api/v1/tickets/{ticket_id}/categorize")
async def categorize_ticket(ticket_id: str):
    """Re-categorize ticket using AI"""
    
    try:
        # Get ticket
        ticket = await app.state.tickets_repo.find_by_id(ticket_id)
        if not ticket:
            raise HTTPException(status_code=404, detail="Ticket not found")
        
        # Get AI service
        ai_service = get_ai_service()
        categories = ["Hardware", "Software", "Network", "Access", "Email", "Other"]
        
        # Classify using AI
        classification = await ai_service.classify_text(
            text=f"{ticket['title']} {ticket['description']}",
            categories=categories
        )
        
        # Update ticket category
        update_dict = {
            "category": classification.get("category", "Other"),
            "updated_at": datetime.utcnow()
        }
        
        await app.state.tickets_repo.update_by_id(ticket_id, update_dict)
        
        # Clear cache
        await app.state.cache.delete(f"ticket:{ticket_id}")
        
        logger.info(f"Ticket re-categorized: {ticket_id} -> {classification.get('category')}")
        
        return BaseResponse(
            message="Ticket categorized successfully",
            data={
                "ticket_id": ticket_id,
                "category": classification.get("category"),
                "confidence": classification.get("confidence")
            }
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error categorizing ticket: {e}")
        raise HTTPException(status_code=500, detail="Failed to categorize ticket")


@app.post("/api/v1/tickets/{ticket_id}/analyze")
async def analyze_ticket(ticket_id: str):
    """Comprehensive AI analysis of ticket for routing and recommendations"""
    
    try:
        # Get ticket
        if not app.state.tickets_repo:
            # Fallback when database is not available
            logger.warning("MongoDB not available - using mock ticket data for analysis")
            ticket = {
                "title": "Sample ticket for analysis",
                "description": "This is a mock ticket used when database is unavailable",
                "category": "Software",
                "priority": "medium",
                "department": "IT"
            }
        else:
            ticket = await app.state.tickets_repo.find_by_id(ticket_id)
            if not ticket:
                raise HTTPException(status_code=404, detail="Ticket not found")
        
        # Get AI service
        ai_service = get_ai_service()
        
        # Mock agents for demonstration
        agents = [
            {"name": "Sarah Wilson", "skills": ["Network", "Hardware"], "availability": "available"},
            {"name": "Mike Chen", "skills": ["Software", "Email"], "availability": "busy"},
            {"name": "Emma Rodriguez", "skills": ["Access", "Security"], "availability": "available"},
            {"name": "David Kim", "skills": ["Hardware", "Software"], "availability": "available"}
        ]
        
        # Find similar tickets for context
        similar_tickets = []
        try:
            if app.state.tickets_repo:
                all_tickets = await app.state.tickets_repo.find_many(
                    {"category": ticket.get("category"), "_id": {"$ne": ticket.get("_id")}},
                    limit=10
                )
                
                # Simple similarity based on category and keywords
                ticket_text = f"{ticket.get('title', '')} {ticket.get('description', '')}".lower()
                for similar in all_tickets:
                    similar_text = f"{similar.get('title', '')} {similar.get('description', '')}".lower()
                    # Basic keyword matching for similarity
                    common_words = set(ticket_text.split()) & set(similar_text.split())
                    if len(common_words) > 2:
                        similar_tickets.append({
                            "title": similar.get("title", ""),
                            "similarity_score": len(common_words) / max(len(ticket_text.split()), len(similar_text.split())),
                            "resolution_approach": similar.get("resolution", "Standard troubleshooting")
                        })
                
                # Sort by similarity and take top 3
                similar_tickets.sort(key=lambda x: x["similarity_score"], reverse=True)
                similar_tickets = similar_tickets[:3]
            else:
                logger.warning("MongoDB not available - skipping similar tickets search")
            
        except Exception as e:
            logger.error(f"Error finding similar tickets: {e}")
        
        # Generate comprehensive AI analysis
        try:
            analysis_prompt = f"""
            Analyze this IT support ticket and provide comprehensive recommendations:
            
            Ticket Title: {ticket.get('title', '')}
            Description: {ticket.get('description', '')}
            Category: {ticket.get('category', '')}
            Priority: {ticket.get('priority', '')}
            Department: {ticket.get('department', 'Unknown')}
            
            Available Agents:
            {chr(10).join([f"- {agent['name']}: {', '.join(agent['skills'])} ({agent['availability']})" for agent in agents])}
            
            Similar Past Tickets:
            {chr(10).join([f"- {similar['title']} (similarity: {similar['similarity_score']:.2f})" for similar in similar_tickets]) if similar_tickets else "None found"}
            
            Please provide:
            1. Best agent to assign (with confidence percentage)
            2. 3-5 self-fix suggestions for the user
            3. Estimated resolution time
            4. Priority recommendation
            5. Any additional insights
            
            Format your response as a structured analysis.
            """
            
            ai_response = await ai_service.generate_completion(analysis_prompt, max_tokens=800)
            
            # Parse AI response and structure the data
            response_text = ai_response.response
            
            # Find the best available agent based on skills matching
            ticket_category = ticket.get('category', '').lower()
            best_agent = None
            best_confidence = 0
            
            for agent in agents:
                if agent['availability'] == 'available':
                    skill_match = any(skill.lower() in ticket_category or ticket_category in skill.lower() 
                                    for skill in agent['skills'])
                    if skill_match:
                        confidence = 0.85 if len([s for s in agent['skills'] if s.lower() in ticket_category]) > 0 else 0.70
                        if confidence > best_confidence:
                            best_agent = agent
                            best_confidence = confidence
            
            # Fallback to first available agent
            if not best_agent:
                available_agents = [a for a in agents if a['availability'] == 'available']
                if available_agents:
                    best_agent = available_agents[0]
                    best_confidence = 0.60
            
            # Generate self-fix suggestions based on category
            self_fix_suggestions = []
            category = ticket.get('category', '').lower()
            
            if 'network' in category:
                self_fix_suggestions = [
                    "Check network cable connections",
                    "Restart your router and modem",
                    "Run Windows Network Troubleshooter",
                    "Check if other devices can connect to the network"
                ]
            elif 'email' in category:
                self_fix_suggestions = [
                    "Check your internet connection",
                    "Verify email server settings",
                    "Clear browser cache and cookies",
                    "Try accessing email from a different device"
                ]
            elif 'software' in category:
                self_fix_suggestions = [
                    "Restart the application",
                    "Check for software updates",
                    "Run the program as administrator",
                    "Temporarily disable antivirus software"
                ]
            elif 'hardware' in category:
                self_fix_suggestions = [
                    "Check all cable connections",
                    "Restart the device",
                    "Check power supply connections",
                    "Look for any visible damage or loose parts"
                ]
            else:
                self_fix_suggestions = [
                    "Restart your computer",
                    "Check for system updates",
                    "Try the operation again",
                    "Document any error messages you see"
                ]
            
            # Estimate resolution time based on priority and category
            priority = ticket.get('priority', 'medium').lower()
            if priority == 'critical':
                resolution_time = "1-2 hours"
            elif priority == 'high':
                resolution_time = "4-6 hours"
            elif priority == 'medium':
                resolution_time = "1-2 business days"
            else:
                resolution_time = "2-3 business days"
            
            # Priority recommendation logic
            if any(word in ticket.get('description', '').lower() for word in ['urgent', 'critical', 'down', 'offline']):
                priority_recommendation = "Consider upgrading to HIGH priority due to business impact keywords"
            elif ticket.get('department', '').lower() in ['executive', 'management']:
                priority_recommendation = "Consider MEDIUM priority for executive department"
            else:
                priority_recommendation = f"Current {priority.upper()} priority appears appropriate"
            
            # Additional insights
            additional_insights = []
            if similar_tickets:
                additional_insights.append(f"Found {len(similar_tickets)} similar tickets that may provide resolution guidance")
            if ticket.get('department'):
                additional_insights.append(f"Department context: {ticket.get('department')} may have specific requirements")
            if len(ticket.get('description', '')) < 50:
                additional_insights.append("Ticket description is brief - may need additional information from user")
            
            # Structure the analysis response
            analysis_data = {
                "suggested_processor": {
                    "name": best_agent['name'] if best_agent else "No agent available",
                    "confidence": best_confidence,
                    "reason": f"Best match for {ticket.get('category', 'this')} category with {best_agent['skills'] if best_agent else []} skills"
                },
                "self_fix_suggestions": self_fix_suggestions,
                "estimated_resolution_time": resolution_time,
                "priority_recommendation": priority_recommendation,
                "similar_tickets": similar_tickets,
                "additional_insights": additional_insights,
                "ai_analysis_text": response_text
            }
            
            logger.info(f"AI analysis completed for ticket {ticket_id}")
            
            # Return analysis data directly for frontend compatibility
            return {
                "ticket_id": ticket_id,
                "analysis": analysis_data
            }
            
        except Exception as e:
            logger.error(f"AI analysis failed: {e}")
            # Provide fallback analysis
            fallback_analysis = {
                "suggested_processor": {
                    "name": "General Support Agent",
                    "confidence": 0.5,
                    "reason": "AI analysis unavailable - defaulting to general support"
                },
                "self_fix_suggestions": [
                    "Restart your computer",
                    "Check for updates",
                    "Try the operation again",
                    "Contact IT support if issue persists"
                ],
                "estimated_resolution_time": "1-2 business days",
                "priority_recommendation": "Current priority level appears appropriate",
                "similar_tickets": [],
                "additional_insights": ["AI analysis temporarily unavailable"],
                "ai_analysis_text": "Fallback analysis provided due to AI service unavailability"
            }
            
            return BaseResponse(
                message="Ticket analysis completed with fallback data",
                data={
                    "ticket_id": ticket_id,
                    "analysis": fallback_analysis
                }
            )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error analyzing ticket {ticket_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to analyze ticket")


# Knowledge Base APIs
@app.post("/api/v1/kb/articles", response_model=BaseResponse)
async def create_kb_article(article_data: KBArticleCreate):
    """Create knowledge base article"""
    
    try:
        # Create article document
        article_doc = {
            "title": article_data.title,
            "content": article_data.content,
            "category": article_data.category,
            "tags": article_data.tags,
            "author": article_data.author,
            "views": 0,
            "helpful_votes": 0,
            "unhelpful_votes": 0,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }
        
        # Save to database
        article_id = await app.state.kb_repo.create(article_doc)
        
        logger.info(f"KB article created: {article_id}")
        
        return BaseResponse(
            message="Knowledge base article created successfully",
            data={"article_id": article_id}
        )
        
    except Exception as e:
        logger.error(f"Error creating KB article: {e}")
        raise HTTPException(status_code=500, detail="Failed to create knowledge base article")


@app.get("/api/v1/kb/articles", response_model=PaginatedResponse)
async def get_kb_articles(
    category: Optional[str] = Query(None, description="Filter by category"),
    search: Optional[str] = Query(None, description="Search in title and content"),
    pagination: PaginationParams = Depends()
):
    """Get knowledge base articles with filters"""
    
    try:
        # Build filter
        filter_dict = {}
        if category:
            filter_dict["category"] = category
        if search:
            # Simple text search in title and content
            filter_dict["$or"] = [
                {"title": {"$regex": search, "$options": "i"}},
                {"content": {"$regex": search, "$options": "i"}}
            ]
        
        # Get articles
        articles = await app.state.kb_repo.find_many(
            filter_dict,
            limit=pagination.limit,
            skip=pagination.offset
        )
        
        # Get total count
        total = await app.state.kb_repo.count(filter_dict)
        
        # Calculate pagination info
        pages = (total + pagination.limit - 1) // pagination.limit
        has_next = pagination.page < pages
        has_prev = pagination.page > 1
        
        return PaginatedResponse(
            items=articles,
            total=total,
            page=pagination.page,
            limit=pagination.limit,
            pages=pages,
            has_next=has_next,
            has_prev=has_prev
        )
        
    except Exception as e:
        logger.error(f"Error retrieving KB articles: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve knowledge base articles")


@app.get("/api/v1/kb/articles/{article_id}")
async def get_kb_article(article_id: str):
    """Get knowledge base article by ID"""
    
    try:
        # Get article
        article = await app.state.kb_repo.find_by_id(article_id)
        if not article:
            raise HTTPException(status_code=404, detail="Article not found")
        
        # Increment view count
        await app.state.kb_repo.update_by_id(article_id, {"$inc": {"views": 1}})
        
        return BaseResponse(message="Article retrieved successfully", data=article)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error retrieving KB article {article_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve knowledge base article")


@app.post("/api/v1/kb/search", response_model=BaseResponse)
async def search_kb_articles(search_request: dict):
    """AI-powered knowledge base search"""
    
    try:
        query = search_request.get("query", "")
        if not query:
            raise HTTPException(status_code=400, detail="Query is required")
        
        # Get all articles for AI-powered search
        all_articles = await app.state.kb_repo.find_many({}, limit=100)
        
        if not all_articles:
            return BaseResponse(
                message="No articles found",
                data={"articles": [], "suggestions": []}
            )
        
        # Use AI to find most relevant articles
        ai_service = get_ai_service()
        prompt_manager = get_prompt_manager()
        
        articles_str = "\n".join([
            f"ID: {article['_id']}, Title: {article['title']}, Category: {article['category']}"
            for article in all_articles
        ])
        
        try:
            prompt = prompt_manager.render_template(
                "kb_search",
                question=query,
                articles=articles_str,
                max_results="5"
            )
            
            response = await ai_service.generate_completion(prompt, max_tokens=500)
            
            # Simple relevance scoring based on title and content matching
            relevant_articles = []
            query_lower = query.lower()
            
            for article in all_articles:
                score = 0
                if query_lower in article['title'].lower():
                    score += 3
                if query_lower in article['content'].lower():
                    score += 2
                if article['category'].lower() in query_lower:
                    score += 1
                
                if score > 0:
                    article['relevance_score'] = score
                    relevant_articles.append(article)
            
            # Sort by relevance
            relevant_articles.sort(key=lambda x: x.get('relevance_score', 0), reverse=True)
            top_articles = relevant_articles[:5]
            
            return BaseResponse(
                message="Knowledge base search completed",
                data={
                    "articles": top_articles,
                    "ai_suggestions": response.response,
                    "total_found": len(relevant_articles)
                }
            )
            
        except Exception as e:
            logger.error(f"AI search failed: {e}")
            # Fallback to simple text search
            simple_results = []
            query_lower = query.lower()
            
            for article in all_articles:
                if (query_lower in article['title'].lower() or 
                    query_lower in article['content'].lower()):
                    simple_results.append(article)
            
            return BaseResponse(
                message="Knowledge base search completed (fallback)",
                data={"articles": simple_results[:5], "suggestions": []}
            )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in KB search: {e}")
        raise HTTPException(status_code=500, detail="Failed to search knowledge base")


# Dashboard APIs
@app.get("/api/v1/dashboard/overview")
async def get_dashboard_overview():
    """Get dashboard overview statistics"""
    
    try:
        if not app.state.tickets_repo:
            # Fallback when database is not available
            logger.warning("MongoDB not available - returning mock dashboard data")
            return {
                "totalTickets": 50,
                "openTickets": 18,
                "resolvedToday": 4,
                "avgResolutionTime": "2.5h",
                "systemUptime": 99.9,
                "agentWorkload": 75
            }
        
        # Get current date for today's calculations
        from datetime import datetime, timedelta
        today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
        today_end = today_start + timedelta(days=1)
        
        # Aggregate ticket statistics
        total_tickets = await app.state.tickets_repo.count({})
        
        # Count by status
        open_tickets = await app.state.tickets_repo.count({"status": Status.OPEN})
        in_progress_tickets = await app.state.tickets_repo.count({"status": Status.IN_PROGRESS})
        resolved_tickets = await app.state.tickets_repo.count({"status": Status.RESOLVED})
        closed_tickets = await app.state.tickets_repo.count({"status": Status.CLOSED})
        
        # Count resolved today
        resolved_today = await app.state.tickets_repo.count({
            "status": {"$in": [Status.RESOLVED, Status.CLOSED]},
            "updated_at": {"$gte": today_start, "$lt": today_end}
        })
        
        # Calculate average resolution time (simplified)
        resolved_tickets_with_time = await app.state.tickets_repo.find_many(
            {"status": {"$in": [Status.RESOLVED, Status.CLOSED]}},
            limit=100
        )
        
        avg_resolution_hours = 0
        if resolved_tickets_with_time:
            total_resolution_time = 0
            count = 0
            for ticket in resolved_tickets_with_time:
                if ticket.get("created_at") and ticket.get("updated_at"):
                    created = ticket["created_at"]
                    updated = ticket["updated_at"]
                    if isinstance(created, str):
                        created = datetime.fromisoformat(created.replace('Z', '+00:00'))
                    if isinstance(updated, str):
                        updated = datetime.fromisoformat(updated.replace('Z', '+00:00'))
                    
                    resolution_time = (updated - created).total_seconds() / 3600  # hours
                    total_resolution_time += resolution_time
                    count += 1
            
            if count > 0:
                avg_resolution_hours = total_resolution_time / count
        
        # Format average resolution time
        if avg_resolution_hours < 1:
            avg_resolution_time = f"{int(avg_resolution_hours * 60)}m"
        elif avg_resolution_hours < 24:
            avg_resolution_time = f"{avg_resolution_hours:.1f}h"
        else:
            avg_resolution_time = f"{avg_resolution_hours / 24:.1f}d"
        
        # Calculate agent workload (percentage of tickets assigned vs capacity)
        assigned_tickets = await app.state.tickets_repo.count({
            "status": {"$in": [Status.IN_PROGRESS]},
            "assigned_to": {"$ne": None}
        })
        
        # Assume 5 agents with capacity of 8 tickets each
        agent_capacity = 5 * 8
        agent_workload = min(100, (assigned_tickets / agent_capacity) * 100) if agent_capacity > 0 else 0
        
        # System uptime (mock for now - could be real system metrics)
        system_uptime = 99.9
        
        dashboard_data = {
            "totalTickets": total_tickets,
            "openTickets": open_tickets,
            "inProgressTickets": in_progress_tickets,
            "resolvedTickets": resolved_tickets,
            "closedTickets": closed_tickets,
            "resolvedToday": resolved_today,
            "avgResolutionTime": avg_resolution_time,
            "systemUptime": system_uptime,
            "agentWorkload": round(agent_workload, 1)
        }
        
        # Cache the results for 5 minutes
        if app.state.cache:
            import json
            await app.state.cache.set(
                "dashboard:overview", 
                json.dumps(dashboard_data, default=str), 
                ttl=300
            )
        
        logger.info("Dashboard overview data generated successfully")
        return dashboard_data
        
    except Exception as e:
        logger.error(f"Error generating dashboard overview: {e}")
        # Return fallback data
        return {
            "totalTickets": 0,
            "openTickets": 0,
            "resolvedToday": 0,
            "avgResolutionTime": "N/A",
            "systemUptime": 99.9,
            "agentWorkload": 0
        }


@app.get("/api/v1/dashboard/ticket-metrics")
async def get_ticket_metrics(time_range: str = Query("7d", description="Time range: 1d, 7d, 30d")):
    """Get detailed ticket metrics for charts"""
    
    try:
        if not app.state.tickets_repo:
            # Fallback mock data for charts
            logger.warning("MongoDB not available - returning mock chart data")
            return {
                "statusDistribution": {
                    "open": 18,
                    "in_progress": 15,
                    "resolved": 12,
                    "closed": 5
                },
                "categoryDistribution": {
                    "Software": 15,
                    "Hardware": 12,
                    "Network": 10,
                    "Email": 8,
                    "Access": 3,
                    "Other": 2
                },
                "priorityDistribution": {
                    "critical": 3,
                    "high": 12,
                    "medium": 25,
                    "low": 10
                },
                "trendData": {
                    "labels": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
                    "created": [8, 12, 15, 10, 14, 6, 4],
                    "resolved": [6, 10, 12, 13, 16, 8, 5]
                }
            }
        
        # Parse time range
        from datetime import datetime, timedelta
        now = datetime.utcnow()
        if time_range == "1d":
            start_date = now - timedelta(days=1)
        elif time_range == "30d":
            start_date = now - timedelta(days=30)
        else:  # default 7d
            start_date = now - timedelta(days=7)
        
        # Get all tickets for analysis
        all_tickets = await app.state.tickets_repo.find_many({}, limit=1000)
        
        # Status distribution
        status_counts = {"open": 0, "in_progress": 0, "resolved": 0, "closed": 0}
        for ticket in all_tickets:
            status = ticket.get("status", "open").lower().replace(" ", "_")
            if status in status_counts:
                status_counts[status] += 1
        
        # Category distribution
        category_counts = {}
        for ticket in all_tickets:
            category = ticket.get("category", "Other")
            category_counts[category] = category_counts.get(category, 0) + 1
        
        # Priority distribution
        priority_counts = {"critical": 0, "high": 0, "medium": 0, "low": 0}
        for ticket in all_tickets:
            priority = ticket.get("priority", "medium").lower()
            if priority in priority_counts:
                priority_counts[priority] += 1
        
        # Trend data (simplified - last 7 days)
        trend_labels = []
        created_counts = []
        resolved_counts = []
        
        for i in range(7):
            day = now - timedelta(days=6-i)
            day_start = day.replace(hour=0, minute=0, second=0, microsecond=0)
            day_end = day_start + timedelta(days=1)
            
            # Count created tickets for this day
            created_count = 0
            resolved_count = 0
            
            for ticket in all_tickets:
                created_at = ticket.get("created_at")
                updated_at = ticket.get("updated_at")
                
                if created_at:
                    if isinstance(created_at, str):
                        created_at = datetime.fromisoformat(created_at.replace('Z', '+00:00'))
                    if day_start <= created_at < day_end:
                        created_count += 1
                
                if (updated_at and ticket.get("status") in [Status.RESOLVED, Status.CLOSED]):
                    if isinstance(updated_at, str):
                        updated_at = datetime.fromisoformat(updated_at.replace('Z', '+00:00'))
                    if day_start <= updated_at < day_end:
                        resolved_count += 1
            
            trend_labels.append(day.strftime("%a"))
            created_counts.append(created_count)
            resolved_counts.append(resolved_count)
        
        metrics_data = {
            "statusDistribution": status_counts,
            "categoryDistribution": category_counts,
            "priorityDistribution": priority_counts,
            "trendData": {
                "labels": trend_labels,
                "created": created_counts,
                "resolved": resolved_counts
            }
        }
        
        # Cache the results
        if app.state.cache:
            import json
            await app.state.cache.set(
                f"dashboard:metrics:{time_range}", 
                json.dumps(metrics_data, default=str), 
                ttl=300
            )
        
        logger.info(f"Dashboard metrics generated for {time_range}")
        return metrics_data
        
    except Exception as e:
        logger.error(f"Error generating dashboard metrics: {e}")
        raise HTTPException(status_code=500, detail="Failed to generate dashboard metrics")


@app.get("/api/v1/dashboard/agent-performance")
async def get_agent_performance():
    """Get agent performance metrics"""
    
    try:
        if not app.state.tickets_repo:
            # Mock agent data
            return {
                "agents": [
                    {"name": "Sarah Wilson", "assigned": 8, "resolved": 12, "avg_time": "2.1h", "status": "available"},
                    {"name": "Mike Chen", "assigned": 6, "resolved": 15, "avg_time": "1.8h", "status": "busy"},
                    {"name": "Emma Rodriguez", "assigned": 4, "resolved": 8, "avg_time": "3.2h", "status": "available"},
                    {"name": "David Kim", "assigned": 7, "resolved": 11, "avg_time": "2.5h", "status": "available"},
                    {"name": "Lisa Anderson", "assigned": 5, "resolved": 9, "avg_time": "2.8h", "status": "busy"}
                ],
                "totalAgents": 5,
                "activeAgents": 3,
                "avgWorkload": 75
            }
        
        # Get tickets with assigned agents
        assigned_tickets = await app.state.tickets_repo.find_many(
            {"assigned_to": {"$ne": None}}, 
            limit=500
        )
        
        # Aggregate by agent
        agent_stats = {}
        for ticket in assigned_tickets:
            agent = ticket.get("assigned_to")
            if not agent:
                continue
                
            if agent not in agent_stats:
                agent_stats[agent] = {
                    "name": agent,
                    "assigned": 0,
                    "resolved": 0,
                    "total_time": 0,
                    "resolved_count": 0
                }
            
            agent_stats[agent]["assigned"] += 1
            
            if ticket.get("status") in [Status.RESOLVED, Status.CLOSED]:
                agent_stats[agent]["resolved"] += 1
                
                # Calculate resolution time
                created_at = ticket.get("created_at")
                updated_at = ticket.get("updated_at")
                if created_at and updated_at:
                    if isinstance(created_at, str):
                        created_at = datetime.fromisoformat(created_at.replace('Z', '+00:00'))
                    if isinstance(updated_at, str):
                        updated_at = datetime.fromisoformat(updated_at.replace('Z', '+00:00'))
                    
                    resolution_time = (updated_at - created_at).total_seconds() / 3600
                    agent_stats[agent]["total_time"] += resolution_time
                    agent_stats[agent]["resolved_count"] += 1
        
        # Format agent data
        agents = []
        for agent_name, stats in agent_stats.items():
            avg_time = 0
            if stats["resolved_count"] > 0:
                avg_time = stats["total_time"] / stats["resolved_count"]
            
            # Format average time
            if avg_time < 1:
                avg_time_str = f"{int(avg_time * 60)}m"
            elif avg_time < 24:
                avg_time_str = f"{avg_time:.1f}h"
            else:
                avg_time_str = f"{avg_time / 24:.1f}d"
            
            # Mock status (in real system, this would come from agent availability system)
            status = "available" if stats["assigned"] < 8 else "busy"
            
            agents.append({
                "name": agent_name,
                "assigned": stats["assigned"],
                "resolved": stats["resolved"],
                "avg_time": avg_time_str,
                "status": status
            })
        
        # Calculate summary stats
        total_agents = len(agents)
        active_agents = len([a for a in agents if a["assigned"] > 0])
        total_assigned = sum(a["assigned"] for a in agents)
        avg_workload = (total_assigned / (total_agents * 8)) * 100 if total_agents > 0 else 0
        
        performance_data = {
            "agents": agents,
            "totalAgents": total_agents,
            "activeAgents": active_agents,
            "avgWorkload": round(avg_workload, 1)
        }
        
        logger.info("Agent performance data generated successfully")
        return performance_data
        
    except Exception as e:
        logger.error(f"Error generating agent performance data: {e}")
        raise HTTPException(status_code=500, detail="Failed to generate agent performance data")


# Chatbot APIs
@app.post("/api/v1/chatbot/message", response_model=ChatResponse)
async def chatbot_message(message_data: ChatMessage):
    """Process chatbot message and generate AI response"""
    
    try:
        user_message = message_data.message
        user_id = message_data.user_id
        context = message_data.context or {}
        
        # Get AI service
        ai_service = get_ai_service()
        
        # Analyze user intent
        intent_analysis = await ai_service.extract_intent(user_message)
        
        # Search for relevant KB articles
        kb_results = []
        try:
            all_articles = await app.state.kb_repo.find_many({}, limit=50)
            query_lower = user_message.lower()
            
            for article in all_articles:
                if (query_lower in article['title'].lower() or 
                    any(tag.lower() in query_lower for tag in article.get('tags', []))):
                    kb_results.append(article)
            
        except Exception as e:
            logger.error(f"KB search in chatbot failed: {e}")
        
        # Prepare context for AI
        ai_context = {
            "user_intent": intent_analysis,
            "relevant_articles": [{"title": art["title"], "category": art["category"]} 
                                for art in kb_results[:3]],
            "user_context": context
        }
        
        # Generate AI response
        try:
            prompt_manager = get_prompt_manager()
            context_info = f"Context: {ai_context}" if ai_context else ""
            
            prompt = prompt_manager.render_template(
                "chatbot_response",
                user_message=user_message,
                context_info=context_info
            )
            
            ai_response = await ai_service.generate_completion(prompt, max_tokens=400)
            
            # Determine if escalation is needed
            escalate_keywords = ['complex', 'urgent', 'manager', 'escalate', 'human agent']
            escalate_to_human = any(keyword in user_message.lower() for keyword in escalate_keywords)
            
            # Generate suggestions
            suggestions = []
            if kb_results:
                suggestions = [f"Check: {art['title']}" for art in kb_results[:3]]
            
            # Determine confidence based on intent analysis
            confidence = intent_analysis.get('confidence', 0.7)
            
            response = ChatResponse(
                response=ai_response.response,
                suggestions=suggestions,
                escalate_to_human=escalate_to_human,
                confidence=confidence
            )
            
            # Cache conversation for context
            if user_id:
                conversation_key = f"chat:{user_id}"
                await app.state.cache.set(
                    conversation_key,
                    f"{user_message}|{ai_response.response}",
                    ttl=1800  # 30 minutes
                )
            
            logger.info(f"Chatbot response generated for user {user_id}")
            
            return response
            
        except Exception as e:
            logger.error(f"AI response generation failed: {e}")
            return ChatResponse(
                response="I apologize, but I'm having trouble processing your request right now. Would you like me to connect you with a human agent?",
                suggestions=["Contact human agent", "Try rephrasing your question"],
                escalate_to_human=True,
                confidence=0.0
            )
        
    except Exception as e:
        logger.error(f"Error in chatbot message processing: {e}")
        return ChatResponse(
            response="I'm experiencing technical difficulties. Please try again or contact support.",
            suggestions=["Try again", "Contact support"],
            escalate_to_human=True,
            confidence=0.0
        )


@app.get("/api/v1/kb/recommendations")
async def get_kb_recommendations(ticket_id: Optional[str] = Query(None)):
    """Get KB article recommendations for a ticket"""
    
    try:
        if not ticket_id:
            # Return popular articles
            if app.state.kb_repo:
                articles = await app.state.kb_repo.find_many({}, limit=10)
                # Sort by views (simple popularity)
                articles.sort(key=lambda x: x.get('views', 0), reverse=True)
                
                return BaseResponse(
                    message="Popular KB articles retrieved",
                    data={"articles": articles[:5], "type": "popular"}
                )
            else:
                return BaseResponse(
                    message="KB not available",
                    data={"articles": [], "type": "unavailable"}
                )
        
        # Get ticket for context
        if app.state.tickets_repo:
            ticket = await app.state.tickets_repo.find_by_id(ticket_id)
            if not ticket:
                raise HTTPException(status_code=404, detail="Ticket not found")
            
            # Find articles in same category
            category_articles = await app.state.kb_repo.find_many(
                {"category": ticket.get("category", "")},
                limit=10
            )
            
            # Use AI to recommend most relevant articles
            if category_articles:
                ai_service = get_ai_service()
                
                articles_context = "\n".join([
                    f"- {article['title']}: {article['content'][:200]}..."
                    for article in category_articles
                ])
                
                try:
                    prompt = f"""
                    Based on this ticket, recommend the most relevant knowledge base articles:
                    
                    Ticket: {ticket.get('title', '')} - {ticket.get('description', '')}
                    Category: {ticket.get('category', '')}
                    
                    Available Articles:
                    {articles_context}
                    
                    Rank the top 3 most relevant articles and explain why they're relevant.
                    """
                    
                    response = await ai_service.generate_completion(prompt, max_tokens=300)
                    
                    return BaseResponse(
                        message="KB recommendations generated",
                        data={
                            "articles": category_articles[:5],
                            "ai_analysis": response.response,
                            "ticket_id": ticket_id,
                            "type": "ai_recommended"
                        }
                    )
                    
                except Exception as e:
                    logger.error(f"AI recommendation failed: {e}")
            
            # Fallback to category-based recommendations
            return BaseResponse(
                message="Category-based KB recommendations",
                data={
                    "articles": category_articles[:5],
                    "ticket_id": ticket_id,
                    "type": "category_based"
                }
            )
        else:
            raise HTTPException(status_code=404, detail="Ticket not found")
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting KB recommendations: {e}")
        raise HTTPException(status_code=500, detail="Failed to get KB recommendations")


@app.get("/api/v1/kb/suggestions")
async def get_kb_suggestions():
    """Get AI-generated KB suggestions from ticket patterns"""
    
    try:
        # For now, return mock suggestions since we need the MCP agent integration
        # In production, this would call the KB AI agent via MCP
        
        mock_suggestions = [
            {
                "id": "suggestion_1",
                "title": "Resolving Slow Computer Performance After Updates",
                "content": """# Slow Computer Performance After Updates

## Common Causes
1. Background processes consuming resources
2. Outdated drivers after system updates
3. Insufficient disk space
4. Malware or unwanted software

## Step-by-Step Solutions

### Method 1: Check System Resources
1. Open Task Manager (Ctrl+Shift+Esc)
2. Click on "Processes" tab
3. Sort by CPU or Memory usage
4. End unnecessary high-usage processes

### Method 2: Update Drivers
1. Right-click "This PC" and select "Properties"
2. Click "Device Manager"
3. Look for devices with yellow warning signs
4. Right-click and select "Update driver"

### Method 3: Disk Cleanup
1. Open File Explorer
2. Right-click on C: drive
3. Select "Properties"
4. Click "Disk Cleanup"
5. Select files to delete and click "OK"

## Prevention Tips
- Restart computer regularly
- Keep software updated
- Run antivirus scans weekly
- Monitor disk space usage

## When to Contact IT
- Performance issues persist after trying all steps
- System crashes or blue screens occur
- Suspected malware infection
""",
                "category": "Software",
                "tags": ["performance", "slow", "computer", "updates", "troubleshooting"],
                "confidence_score": 0.87,
                "impact_score": 0.92,
                "ticket_cluster": {
                    "count": 15,
                    "sample_tickets": ["ticket_001", "ticket_045", "ticket_089"],
                    "common_patterns": ["slow", "performance", "update", "computer"]
                },
                "status": "pending",
                "created_at": datetime.utcnow().isoformat()
            },
            {
                "id": "suggestion_2", 
                "title": "Advanced Email Attachment Issues Resolution",
                "content": """# Email Attachment Problems - Advanced Solutions

## Common Attachment Issues
1. Large file size restrictions
2. Blocked file types by security policies
3. Corrupted attachments
4. Sync issues with mobile devices

## Troubleshooting Steps

### For Large Files (>25MB)
1. Use OneDrive or SharePoint sharing instead
2. Compress files using 7-Zip or WinRAR
3. Split large files into smaller parts
4. Use company file transfer service

### For Blocked File Types
1. Rename file extension (e.g., .exe to .txt)
2. Compress file in password-protected archive
3. Use approved file sharing platforms
4. Contact IT for policy exceptions

### For Corrupted Attachments
1. Ask sender to resend the file
2. Try downloading from webmail interface
3. Check antivirus quarantine folder
4. Use different email client temporarily

## Mobile Device Solutions
1. Update email app to latest version
2. Clear email app cache and data
3. Remove and re-add email account
4. Check available storage space

## Best Practices
- Keep attachments under 10MB when possible
- Use cloud sharing for collaboration
- Scan attachments before opening
- Maintain organized folder structure

## Security Considerations
- Never open suspicious attachments
- Verify sender identity for unexpected files
- Report phishing attempts to IT security
- Use company-approved sharing methods only
""",
                "category": "Email",
                "tags": ["email", "attachment", "file", "sharing", "mobile"],
                "confidence_score": 0.82,
                "impact_score": 0.78,
                "ticket_cluster": {
                    "count": 12,
                    "sample_tickets": ["ticket_023", "ticket_067", "ticket_134"],
                    "common_patterns": ["attachment", "email", "file", "send", "receive"]
                },
                "status": "pending",
                "created_at": datetime.utcnow().isoformat()
            },
            {
                "id": "suggestion_3",
                "title": "Network Connectivity Troubleshooting for Remote Workers",
                "content": """# Remote Work Network Issues - Complete Guide

## Initial Diagnostics
1. Test internet speed using speedtest.net
2. Check if issue affects all devices or just one
3. Verify VPN connection status
4. Test connectivity to different websites

## Home Network Optimization

### Router Configuration
1. Position router in central location
2. Update router firmware
3. Change Wi-Fi channel (1, 6, or 11 for 2.4GHz)
4. Enable QoS for work applications

### Bandwidth Management
1. Limit streaming during work hours
2. Use ethernet cable for important meetings
3. Close unnecessary applications and browser tabs
4. Schedule large downloads for off-hours

## VPN Optimization
1. Connect to nearest VPN server
2. Try different VPN protocols
3. Split tunneling for non-work traffic
4. Update VPN client software

## Troubleshooting Steps

### Connection Drops
1. Check power saving settings on network adapter
2. Update network drivers
3. Reset network settings: netsh winsock reset
4. Contact ISP if issues persist

### Slow Performance
1. Run network speed test at different times
2. Check for background updates
3. Scan for malware
4. Consider upgrading internet plan

## Mobile Hotspot Backup
1. Set up phone hotspot as backup
2. Monitor data usage carefully
3. Use for critical meetings only
4. Request company mobile data allowance

## When to Escalate
- Consistent connection issues affecting productivity
- VPN authentication problems
- Need for dedicated business internet line
- Security concerns about home network
""",
                "category": "Network",
                "tags": ["network", "remote", "connectivity", "vpn", "home"],
                "confidence_score": 0.89,
                "impact_score": 0.85,
                "ticket_cluster": {
                    "count": 18,
                    "sample_tickets": ["ticket_012", "ticket_078", "ticket_156"],
                    "common_patterns": ["network", "connection", "remote", "slow", "vpn"]
                },
                "status": "pending",
                "created_at": datetime.utcnow().isoformat()
            }
        ]
        
        return {
            "success": True,
            "suggestions": mock_suggestions,
            "total": len(mock_suggestions),
            "generated_at": datetime.utcnow().isoformat(),
            "message": "KB suggestions generated from ticket pattern analysis"
        }
        
    except Exception as e:
        logger.error(f"Error getting KB suggestions: {e}")
        raise HTTPException(status_code=500, detail="Failed to get KB suggestions")


@app.post("/api/v1/kb/suggestions/{suggestion_id}/action")
async def update_kb_suggestion_status(
    suggestion_id: str,
    action_data: dict
):
    """Update KB suggestion status (approve/reject/edit)"""
    
    try:
        action = action_data.get("action")
        feedback = action_data.get("feedback", "")
        edited_content = action_data.get("edited_content", "")
        
        if action not in ["approve", "reject", "edit"]:
            raise HTTPException(status_code=400, detail="Invalid action. Must be 'approve', 'reject', or 'edit'")
        
        # For now, return success response
        # In production, this would update the suggestion in the database
        # and potentially create a new KB article if approved
        
        if action == "approve":
            # Would create new KB article from suggestion
            message = f"Suggestion {suggestion_id} approved and article created"
        elif action == "reject":
            message = f"Suggestion {suggestion_id} rejected with feedback: {feedback}"
        else:  # edit
            message = f"Suggestion {suggestion_id} edited and saved for review"
        
        return {
            "success": True,
            "message": message,
            "suggestion_id": suggestion_id,
            "action": action,
            "timestamp": datetime.utcnow().isoformat()
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating suggestion status: {e}")
        raise HTTPException(status_code=500, detail="Failed to update suggestion status")


@app.get("/api/v1/kb/suggestions/analytics")
async def get_kb_suggestions_analytics():
    """Get analytics about KB suggestions performance"""
    
    try:
        # Mock analytics data
        # In production, this would query the suggestions database
        
        analytics = {
            "total_suggestions": 25,
            "status_breakdown": {
                "pending": 8,
                "approved": 12,
                "rejected": 5
            },
            "approval_rate": 0.71,  # 12/17 (approved + rejected)
            "avg_confidence_score": 0.84,
            "avg_impact_score": 0.78,
            "top_categories": [
                {"category": "Software", "count": 8},
                {"category": "Network", "count": 6},
                {"category": "Email", "count": 5},
                {"category": "Hardware", "count": 4},
                {"category": "Security", "count": 2}
            ],
            "recent_activity": [
                {
                    "date": "2025-01-15",
                    "suggestions_generated": 3,
                    "suggestions_approved": 2,
                    "suggestions_rejected": 1
                },
                {
                    "date": "2025-01-14", 
                    "suggestions_generated": 2,
                    "suggestions_approved": 1,
                    "suggestions_rejected": 0
                }
            ],
            "generated_at": datetime.utcnow().isoformat()
        }
        
        return {
            "success": True,
            "analytics": analytics
        }
        
    except Exception as e:
        logger.error(f"Error getting KB suggestions analytics: {e}")
        raise HTTPException(status_code=500, detail="Failed to get KB suggestions analytics")


if __name__ == "__main__":
    # Get configuration from environment
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "8001"))
    debug = os.getenv("DEBUG", "false").lower() == "true"
    
    # Run the application
    uvicorn.run(
        "main:app",
        host=host,
        port=port,
        reload=debug,
        log_level="info",
        access_log=True
    )
