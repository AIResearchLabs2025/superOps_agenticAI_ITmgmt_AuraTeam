#!/bin/bash
# Comprehensive Workflow Testing Script for Aura Team Application
# Tests all 5 key workflows: ticket creation, listing, AI analysis, knowledge base, and chatbot

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_test() {
    echo -e "${CYAN}[TEST]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Global variables
API_BASE_URL=""
VERBOSE=false
TIMEOUT=30
TEST_RESULTS=()

# Function to show usage
show_usage() {
    echo "Usage: $0 <API_BASE_URL> [OPTIONS]"
    echo ""
    echo "ARGUMENTS:"
    echo "  API_BASE_URL    - Base URL for the API (e.g., http://3.145.123.45:8000)"
    echo ""
    echo "OPTIONS:"
    echo "  --verbose       - Show detailed request/response information"
    echo "  --timeout       - Request timeout in seconds (default: 30)"
    echo ""
    echo "Examples:"
    echo "  $0 http://3.145.123.45:8000"
    echo "  $0 http://localhost:8000 --verbose"
    echo "  $0 http://3.145.123.45:8000 --timeout 60"
    echo ""
    exit 1
}

# Function to parse command line arguments
parse_arguments() {
    if [[ $# -eq 0 ]]; then
        show_usage
    fi
    
    API_BASE_URL=$1
    shift
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose)
                VERBOSE=true
                shift
                ;;
            --timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                ;;
        esac
    done
    
    # Validate API_BASE_URL
    if [[ ! "$API_BASE_URL" =~ ^https?:// ]]; then
        print_error "Invalid API_BASE_URL format. Must start with http:// or https://"
        exit 1
    fi
    
    # Remove trailing slash
    API_BASE_URL=${API_BASE_URL%/}
}

# Function to make HTTP requests with error handling
make_request() {
    local method=$1
    local endpoint=$2
    local data=$3
    local description=$4
    
    local url="${API_BASE_URL}${endpoint}"
    local curl_args=("-s" "--max-time" "$TIMEOUT" "-w" "\n%{http_code}")
    
    if [[ "$VERBOSE" == "true" ]]; then
        print_test "Making $method request to: $url"
        if [[ -n "$data" ]]; then
            echo "Request data: $data"
        fi
    fi
    
    local response
    if [[ "$method" == "GET" ]]; then
        response=$(curl "${curl_args[@]}" "$url" 2>/dev/null)
    elif [[ "$method" == "POST" ]]; then
        curl_args+=("-X" "POST" "-H" "Content-Type: application/json")
        if [[ -n "$data" ]]; then
            curl_args+=("-d" "$data")
        fi
        response=$(curl "${curl_args[@]}" "$url" 2>/dev/null)
    else
        print_error "Unsupported HTTP method: $method"
        return 1
    fi
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n -1)
    
    if [[ "$VERBOSE" == "true" ]]; then
        echo "Response code: $http_code"
        echo "Response body: $body"
        echo ""
    fi
    
    # Check if request was successful
    if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
        print_success "$description - HTTP $http_code"
        TEST_RESULTS+=("✓ $description")
        echo "$body"
        return 0
    else
        print_error "$description - HTTP $http_code"
        TEST_RESULTS+=("✗ $description - HTTP $http_code")
        if [[ "$VERBOSE" == "true" ]]; then
            echo "Error response: $body"
        fi
        return 1
    fi
}

# Function to test API health endpoints
test_health_endpoints() {
    print_header "Testing Health Endpoints"
    
    # Test API Gateway health
    make_request "GET" "/health" "" "API Gateway Health Check"
    
    # Test Service Desk health (assuming it's on port 8001)
    local service_desk_url="${API_BASE_URL/8000/8001}"
    print_test "Testing Service Desk health at: $service_desk_url/health"
    
    local response=$(curl -s --max-time "$TIMEOUT" -w "\n%{http_code}" "$service_desk_url/health" 2>/dev/null || echo -e "\n000")
    local http_code=$(echo "$response" | tail -n1)
    
    if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
        print_success "Service Desk Health Check - HTTP $http_code"
        TEST_RESULTS+=("✓ Service Desk Health Check")
    else
        print_error "Service Desk Health Check - HTTP $http_code"
        TEST_RESULTS+=("✗ Service Desk Health Check - HTTP $http_code")
    fi
}

# Function to test ticket creation workflow
test_ticket_creation() {
    print_header "Testing Ticket Creation Workflow"
    
    local ticket_data='{
        "title": "Test Ticket - Network Connectivity Issue",
        "description": "Unable to connect to the company VPN from home office. Getting timeout errors when trying to establish connection.",
        "priority": "medium",
        "category": "Network",
        "user_id": "test_user_001",
        "user_email": "test.user@company.com",
        "user_name": "Test User",
        "department": "Engineering"
    }'
    
    local response=$(make_request "POST" "/api/v1/tickets" "$ticket_data" "Create New Ticket")
    
    if [[ $? -eq 0 ]]; then
        # Extract ticket ID from response
        local ticket_id=$(echo "$response" | grep -o '"id"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*' | head -1)
        if [[ -n "$ticket_id" ]]; then
            print_status "Created ticket with ID: $ticket_id"
            echo "$ticket_id" > /tmp/test_ticket_id.txt
        else
            print_warning "Could not extract ticket ID from response"
        fi
    fi
}

# Function to test ticket listing workflow
test_ticket_listing() {
    print_header "Testing Ticket Listing Workflow"
    
    # Test basic ticket listing
    make_request "GET" "/api/v1/tickets" "" "List All Tickets"
    
    # Test ticket listing with pagination
    make_request "GET" "/api/v1/tickets?page=1&limit=10" "" "List Tickets with Pagination"
    
    # Test ticket listing with filters
    make_request "GET" "/api/v1/tickets?status=open" "" "List Open Tickets"
    make_request "GET" "/api/v1/tickets?priority=high" "" "List High Priority Tickets"
    make_request "GET" "/api/v1/tickets?category=Network" "" "List Network Category Tickets"
    
    # Test individual ticket retrieval if we have a ticket ID
    if [[ -f /tmp/test_ticket_id.txt ]]; then
        local ticket_id=$(cat /tmp/test_ticket_id.txt)
        make_request "GET" "/api/v1/tickets/$ticket_id" "" "Get Specific Ticket Details"
    fi
}

# Function to test AI analysis workflow
test_ai_analysis() {
    print_header "Testing AI Analysis Workflow"
    
    # Test AI analysis on a ticket
    if [[ -f /tmp/test_ticket_id.txt ]]; then
        local ticket_id=$(cat /tmp/test_ticket_id.txt)
        make_request "POST" "/api/v1/tickets/$ticket_id/analyze" "" "AI Analysis of Ticket"
    else
        # Create a test ticket for analysis
        local ticket_data='{
            "title": "Server Performance Degradation",
            "description": "The main application server has been experiencing slow response times and high CPU usage since yesterday. Users are reporting timeouts when accessing the dashboard.",
            "priority": "high",
            "category": "Infrastructure"
        }'
        
        local response=$(make_request "POST" "/api/v1/tickets" "$ticket_data" "Create Ticket for AI Analysis")
        
        if [[ $? -eq 0 ]]; then
            local ticket_id=$(echo "$response" | grep -o '"id"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*' | head -1)
            if [[ -n "$ticket_id" ]]; then
                sleep 2  # Give the system a moment to process
                make_request "POST" "/api/v1/tickets/$ticket_id/analyze" "" "AI Analysis of New Ticket"
            fi
        fi
    fi
    
    # Test general AI recommendations
    make_request "GET" "/api/v1/ai/recommendations" "" "Get AI Recommendations"
}

# Function to test knowledge base workflow
test_knowledge_base() {
    print_header "Testing Knowledge Base Workflow"
    
    # Test knowledge base article listing
    make_request "GET" "/api/v1/knowledge-base/articles" "" "List Knowledge Base Articles"
    
    # Test knowledge base search
    make_request "GET" "/api/v1/knowledge-base/search?q=network" "" "Search KB Articles for 'network'"
    make_request "GET" "/api/v1/knowledge-base/search?q=VPN" "" "Search KB Articles for 'VPN'"
    make_request "GET" "/api/v1/knowledge-base/search?q=password" "" "Search KB Articles for 'password'"
    
    # Test knowledge base categories
    make_request "GET" "/api/v1/knowledge-base/categories" "" "Get KB Categories"
    
    # Test knowledge base suggestions for a ticket
    if [[ -f /tmp/test_ticket_id.txt ]]; then
        local ticket_id=$(cat /tmp/test_ticket_id.txt)
        make_request "GET" "/api/v1/knowledge-base/suggestions?ticket_id=$ticket_id" "" "Get KB Suggestions for Ticket"
    fi
    
    # Test creating a new KB article
    local kb_article_data='{
        "title": "How to Reset Network Settings",
        "content": "To reset network settings: 1. Open Network Settings 2. Click Advanced 3. Select Reset Network Configuration 4. Restart the system",
        "category": "Network",
        "tags": ["network", "reset", "troubleshooting"]
    }'
    
    make_request "POST" "/api/v1/knowledge-base/articles" "$kb_article_data" "Create New KB Article"
}

# Function to test chatbot workflow
test_chatbot() {
    print_header "Testing Chatbot Workflow"
    
    # Test basic chatbot queries
    local queries=(
        "How do I reset my password?"
        "I'm having network connectivity issues"
        "My computer is running slowly"
        "How do I connect to VPN?"
        "I can't access my email"
    )
    
    for query in "${queries[@]}"; do
        local chat_data="{\"message\": \"$query\", \"user_id\": \"test_user_001\"}"
        make_request "POST" "/api/v1/chatbot/query" "$chat_data" "Chatbot Query: '$query'"
        sleep 1  # Brief pause between queries
    done
    
    # Test chatbot conversation history
    make_request "GET" "/api/v1/chatbot/history?user_id=test_user_001" "" "Get Chatbot Conversation History"
    
    # Test chatbot capabilities
    make_request "GET" "/api/v1/chatbot/capabilities" "" "Get Chatbot Capabilities"
}

# Function to test frontend accessibility
test_frontend() {
    print_header "Testing Frontend Accessibility"
    
    local frontend_url="${API_BASE_URL/8000/80}"
    print_test "Testing frontend at: $frontend_url"
    
    # Test main page
    local response=$(curl -s --max-time "$TIMEOUT" -w "\n%{http_code}" "$frontend_url" 2>/dev/null || echo -e "\n000")
    local http_code=$(echo "$response" | tail -n1)
    
    if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
        print_success "Frontend Main Page - HTTP $http_code"
        TEST_RESULTS+=("✓ Frontend Main Page")
    else
        print_error "Frontend Main Page - HTTP $http_code"
        TEST_RESULTS+=("✗ Frontend Main Page - HTTP $http_code")
    fi
    
    # Test static assets
    local static_endpoints=("/static/css" "/static/js" "/favicon.ico")
    for endpoint in "${static_endpoints[@]}"; do
        local response=$(curl -s --max-time "$TIMEOUT" -w "\n%{http_code}" "$frontend_url$endpoint" 2>/dev/null || echo -e "\n000")
        local http_code=$(echo "$response" | tail -n1)
        
        if [[ "$http_code" =~ ^[23][0-9][0-9]$ ]]; then
            print_success "Frontend Asset $endpoint - HTTP $http_code"
            TEST_RESULTS+=("✓ Frontend Asset $endpoint")
        else
            print_warning "Frontend Asset $endpoint - HTTP $http_code (may not exist)"
        fi
    done
}

# Function to display test summary
display_test_summary() {
    print_header "Test Summary"
    
    local total_tests=${#TEST_RESULTS[@]}
    local passed_tests=0
    local failed_tests=0
    
    echo ""
    print_status "Test Results:"
    for result in "${TEST_RESULTS[@]}"; do
        echo "  $result"
        if [[ "$result" =~ ^✓ ]]; then
            ((passed_tests++))
        else
            ((failed_tests++))
        fi
    done
    
    echo ""
    print_status "Summary:"
    print_status "  Total Tests: $total_tests"
    print_success "  Passed: $passed_tests"
    if [[ $failed_tests -gt 0 ]]; then
        print_error "  Failed: $failed_tests"
    else
        print_status "  Failed: $failed_tests"
    fi
    
    local success_rate=$((passed_tests * 100 / total_tests))
    print_status "  Success Rate: ${success_rate}%"
    
    echo ""
    if [[ $failed_tests -eq 0 ]]; then
        print_success "🎉 All tests passed! Your application is working correctly."
    elif [[ $success_rate -ge 80 ]]; then
        print_warning "⚠️  Most tests passed, but some issues were found. Check the failed tests above."
    else
        print_error "❌ Multiple tests failed. Please review the application deployment and configuration."
    fi
    
    # Clean up temp files
    rm -f /tmp/test_ticket_id.txt
    
    return $failed_tests
}

# Main function
main() {
    # Parse arguments
    parse_arguments "$@"
    
    print_header "Aura Team Application Workflow Testing"
    print_status "API Base URL: $API_BASE_URL"
    print_status "Timeout: ${TIMEOUT}s"
    print_status "Verbose: $VERBOSE"
    print_status ""
    
    # Test health endpoints first
    test_health_endpoints
    
    # Test core workflows
    test_ticket_creation
    test_ticket_listing
    test_ai_analysis
    test_knowledge_base
    test_chatbot
    
    # Test frontend
    test_frontend
    
    # Display summary
    display_test_summary
    
    # Exit with appropriate code
    local failed_tests=$?
    if [[ $failed_tests -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Run main function with all arguments
main "$@"
