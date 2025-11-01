import axios from 'axios';
import config, { discoverApiEndpoint, startHealthMonitor } from '../config/environment';

// API Configuration - Use dynamic configuration
const API_BASE_URL = config.API_BASE_URL;

// Initialize health monitoring for AWS environments
if (config.ENVIRONMENT !== 'development') {
  startHealthMonitor();
}

// Create axios instance with dynamic configuration
const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: config.API_TIMEOUT,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Dynamic baseURL updater for AWS environments
let currentBaseURL = API_BASE_URL;

const updateBaseURL = (newBaseURL) => {
  if (newBaseURL !== currentBaseURL) {
    currentBaseURL = newBaseURL;
    api.defaults.baseURL = newBaseURL;
    console.log(`🔄 API base URL updated to: ${newBaseURL}`);
  }
};

// Retry mechanism for failed requests
const retryRequest = async (originalRequest, retryCount = 0) => {
  if (retryCount >= config.MAX_RETRIES) {
    throw new Error(`Max retries (${config.MAX_RETRIES}) exceeded`);
  }

  // Wait before retry
  await new Promise(resolve => setTimeout(resolve, config.RETRY_DELAY * (retryCount + 1)));

  // Attempt to rediscover API endpoint on network errors
  if (retryCount === 0) {
    try {
      const newBaseURL = await discoverApiEndpoint();
      updateBaseURL(newBaseURL);
      originalRequest.baseURL = newBaseURL;
    } catch (error) {
      console.warn('Failed to rediscover API endpoint:', error.message);
    }
  }

  return api(originalRequest);
};

// Request interceptor for adding auth headers if needed
api.interceptors.request.use(
  (config) => {
    // Add auth token if available
    const token = localStorage.getItem('authToken');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Response interceptor for handling errors with retry logic
api.interceptors.response.use(
  (response) => {
    return response;
  },
  async (error) => {
    const originalRequest = error.config;

    // Handle common errors
    if (error.response?.status === 401) {
      // Unauthorized - redirect to login
      localStorage.removeItem('authToken');
      // window.location.href = '/login';
    }

    // Handle network errors with retry logic for AWS environments
    if (!error.response && !originalRequest._retry && config.ENVIRONMENT !== 'development') {
      originalRequest._retry = true;
      
      try {
        console.log('🔄 Network error detected, attempting retry with endpoint discovery...');
        return await retryRequest(originalRequest, originalRequest._retryCount || 0);
      } catch (retryError) {
        console.error('❌ All retry attempts failed:', retryError.message);
      }
    }
    
    // Return a more user-friendly error
    const errorMessage = error.response?.data?.message || error.message || 'An error occurred';
    return Promise.reject({
      ...error,
      message: errorMessage,
      status: error.response?.status,
    });
  }
);

// Service Desk API endpoints
export const serviceDeskAPI = {
  // Get all tickets
  getTickets: async (params = {}) => {
    const response = await api.get('/api/v1/tickets', { params });
    return response.data;
  },

  // Get ticket by ID
  getTicket: async (ticketId) => {
    const response = await api.get(`/api/v1/tickets/${ticketId}`);
    return response.data;
  },

  // Create new ticket
  createTicket: async (ticketData) => {
    const response = await api.post('/api/v1/tickets', ticketData);
    return response.data;
  },

  // Update ticket
  updateTicket: async (ticketId, updateData) => {
    const response = await api.put(`/api/v1/tickets/${ticketId}`, updateData);
    return response.data;
  },

  // Assign ticket
  assignTicket: async (ticketId, agentId) => {
    const response = await api.put(`/api/v1/tickets/${ticketId}`, {
      assigned_to: agentId,
    });
    return response.data;
  },

  // Update ticket status
  updateTicketStatus: async (ticketId, status) => {
    const response = await api.put(`/api/v1/tickets/${ticketId}`, {
      status,
    });
    return response.data;
  },

  // Analyze ticket using AI (categorize + route)
  analyzeTicket: async (ticketId) => {
    const response = await api.post(`/api/v1/tickets/${ticketId}/analyze`);
    return response.data;
  },

  // Categorize ticket using AI (legacy - use analyzeTicket instead)
  categorizeTicket: async (ticketId) => {
    const response = await api.post(`/api/v1/tickets/${ticketId}/analyze`);
    return response.data;
  },

  // Route ticket using AI (legacy - use analyzeTicket instead)
  routeTicket: async (ticketId) => {
    const response = await api.post(`/api/v1/tickets/${ticketId}/analyze`);
    return response.data;
  },

  // Get ticket analytics
  getTicketAnalytics: async (params = {}) => {
    const response = await api.get('/api/v1/tickets/analytics', { params });
    return response.data;
  },
};

// Knowledge Base API endpoints
export const knowledgeBaseAPI = {
  // Search articles
  searchArticles: async (query, filters = {}) => {
    const response = await api.post('/api/v1/kb/search', { query, ...filters });
    return response.data;
  },

  // Get all articles
  getArticles: async (params = {}) => {
    const response = await api.get('/api/v1/kb/articles', { params });
    return response.data;
  },

  // Get article by ID
  getArticle: async (articleId) => {
    const response = await api.get(`/api/v1/kb/articles/${articleId}`);
    return response.data;
  },

  // Create new article
  createArticle: async (articleData) => {
    const response = await api.post('/api/v1/kb/articles', articleData);
    return response.data;
  },

  // Update article
  updateArticle: async (articleId, updateData) => {
    const response = await api.put(`/api/v1/kb/articles/${articleId}`, updateData);
    return response.data;
  },

  // Delete article
  deleteArticle: async (articleId) => {
    const response = await api.delete(`/api/v1/kb/articles/${articleId}`);
    return response.data;
  },

  // Get KB recommendations
  getRecommendations: async (ticketId = null) => {
    const params = ticketId ? { ticket_id: ticketId } : {};
    const response = await api.get('/api/v1/kb/recommendations', { params });
    return response.data;
  },

  // Analyze knowledge gaps
  analyzeGaps: async () => {
    const response = await api.post('/api/v1/kb/analyze-gaps');
    return response.data;
  },

  // Generate article suggestions
  generateSuggestions: async (ticketData) => {
    const response = await api.post('/api/v1/kb/generate-suggestions', ticketData);
    return response.data;
  },

  // Get KB suggestions from AI analysis
  getSuggestions: async () => {
    const response = await api.get('/api/v1/kb/suggestions');
    return response.data;
  },

  // Update KB suggestion status
  updateSuggestionStatus: async (suggestionId, action, feedback = '', editedContent = '') => {
    const response = await api.post(`/api/v1/kb/suggestions/${suggestionId}/action`, {
      action,
      feedback,
      edited_content: editedContent,
    });
    return response.data;
  },

  // Get KB suggestions analytics
  getSuggestionsAnalytics: async () => {
    const response = await api.get('/api/v1/kb/suggestions/analytics');
    return response.data;
  },
};

// Chatbot API endpoints
export const chatbotAPI = {
  // Send message to chatbot
  sendMessage: async (message, userId = null, context = null) => {
    const response = await api.post('/api/v1/chatbot/message', {
      message,
      user_id: userId,
      context: context,
    });
    return response.data;
  },

  // Get chat session (legacy - not implemented in backend)
  getSession: async (sessionId) => {
    const response = await api.get(`/api/v1/chatbot/sessions/${sessionId}`);
    return response.data;
  },

  // Create new chat session (legacy - not implemented in backend)
  createSession: async () => {
    const response = await api.post('/api/v1/chatbot/sessions');
    return response.data;
  },

  // Get chat history (legacy - not implemented in backend)
  getChatHistory: async (sessionId) => {
    const response = await api.get(`/api/v1/chatbot/sessions/${sessionId}/history`);
    return response.data;
  },

  // Clear chat session (legacy - not implemented in backend)
  clearSession: async (sessionId) => {
    const response = await api.delete(`/api/v1/chatbot/sessions/${sessionId}`);
    return response.data;
  },
};

// Dashboard API endpoints
export const dashboardAPI = {
  // Get dashboard overview
  getOverview: async () => {
    const response = await api.get('/api/v1/dashboard/overview');
    return response.data;
  },

  // Get ticket metrics
  getTicketMetrics: async (timeRange = '7d') => {
    const response = await api.get('/api/v1/dashboard/ticket-metrics', {
      params: { time_range: timeRange },
    });
    return response.data;
  },

  // Get agent performance
  getAgentPerformance: async () => {
    const response = await api.get('/api/v1/dashboard/agent-performance');
    return response.data;
  },

  // Get system health
  getSystemHealth: async () => {
    const response = await api.get('/health');
    return response.data;
  },
};

// Mock data generators for development (when backend is not available)
export const mockData = {
  tickets: [
    {
      id: 1,
      title: 'Cannot access email',
      description: 'User unable to login to Outlook',
      status: 'open',
      priority: 'medium',
      category: 'Email',
      created_at: '2024-01-15T10:30:00Z',
      updated_at: '2024-01-15T10:30:00Z',
      assigned_to: null,
      requester: 'john.doe@company.com',
    },
    {
      id: 2,
      title: 'VPN connection issues',
      description: 'Cannot connect to company VPN from home',
      status: 'in_progress',
      priority: 'high',
      category: 'Network',
      created_at: '2024-01-15T09:15:00Z',
      updated_at: '2024-01-15T11:45:00Z',
      assigned_to: 'agent-1',
      requester: 'jane.smith@company.com',
    },
    {
      id: 3,
      title: 'Software installation request',
      description: 'Need Adobe Creative Suite installed on workstation',
      status: 'resolved',
      priority: 'low',
      category: 'Software',
      created_at: '2024-01-14T14:20:00Z',
      updated_at: '2024-01-15T08:30:00Z',
      assigned_to: 'agent-2',
      requester: 'bob.johnson@company.com',
    },
  ],

  articles: [
    {
      id: 1,
      title: 'How to Reset Your Password',
      content: 'Step-by-step guide to reset your company password...',
      category: 'Account Management',
      tags: ['password', 'security', 'login'],
      created_at: '2024-01-10T12:00:00Z',
      updated_at: '2024-01-12T15:30:00Z',
      author: 'IT Admin',
    },
    {
      id: 2,
      title: 'VPN Setup Guide',
      content: 'Instructions for setting up VPN connection...',
      category: 'Network',
      tags: ['vpn', 'remote', 'connection'],
      created_at: '2024-01-08T10:15:00Z',
      updated_at: '2024-01-08T10:15:00Z',
      author: 'Network Admin',
    },
  ],

  dashboardStats: {
    totalTickets: 156,
    openTickets: 23,
    resolvedToday: 12,
    avgResolutionTime: '2.5 hours',
    agentWorkload: 85,
    systemUptime: 99.9,
  },
};

// Development mode helpers
const isDevelopment = config.ENVIRONMENT === 'development' || config.ENABLE_MOCK_DATA;

// Enhanced wrapper functions with AWS-specific error handling
export const apiWithFallback = {
  getTickets: async (params) => {
    try {
      return await serviceDeskAPI.getTickets(params);
    } catch (error) {
      // Log error details for AWS debugging
      if (config.ENABLE_DEBUG_LOGS) {
        console.error('API Error Details:', {
          message: error.message,
          status: error.status,
          baseURL: currentBaseURL,
          environment: config.ENVIRONMENT
        });
      }

      if (isDevelopment) {
        console.warn('API call failed, using mock data:', error.message);
        return { tickets: mockData.tickets, total: mockData.tickets.length };
      }
      throw error;
    }
  },

  getTicket: async (ticketId) => {
    try {
      return await serviceDeskAPI.getTicket(ticketId);
    } catch (error) {
      // Enhanced error logging for AWS debugging
      if (config.ENABLE_DEBUG_LOGS) {
        console.error('Get Ticket Error:', {
          ticketId,
          message: error.message,
          status: error.status,
          baseURL: currentBaseURL
        });
      }

      if (isDevelopment) {
        console.warn('API call failed, using mock data:', error.message);
        const mockTicket = mockData.tickets.find(t => t.id.toString() === ticketId.toString());
        if (mockTicket) {
          return { data: mockTicket };
        } else {
          // Create a mock ticket with the requested ID
          return { 
            data: {
              id: ticketId,
              _id: ticketId,
              title: `Sample Ticket ${ticketId}`,
              description: `This is a mock ticket with ID ${ticketId} for testing purposes.`,
              status: 'open',
              priority: 'medium',
              category: 'General',
              created_at: new Date().toISOString(),
              updated_at: new Date().toISOString(),
              assigned_to: null,
              requester: 'test.user@company.com',
              user_name: 'Test User',
              user_email: 'test.user@company.com',
              department: 'IT'
            }
          };
        }
      }
      throw error;
    }
  },

  getArticles: async (params) => {
    try {
      const response = await knowledgeBaseAPI.getArticles(params);
      // The API returns 'items' but frontend expects 'articles'
      return { 
        articles: response.items || response.articles || [], 
        total: response.total || 0 
      };
    } catch (error) {
      // Enhanced error logging for knowledge base issues
      if (config.ENABLE_DEBUG_LOGS) {
        console.error('Knowledge Base API Error:', {
          params,
          message: error.message,
          status: error.status,
          baseURL: currentBaseURL,
          endpoint: '/api/v1/kb/articles'
        });
      }

      if (isDevelopment) {
        console.warn('Knowledge Base API call failed, using mock data:', error.message);
        return { articles: mockData.articles, total: mockData.articles.length };
      }
      throw error;
    }
  },

  getDashboardStats: async () => {
    try {
      return await dashboardAPI.getOverview();
    } catch (error) {
      if (isDevelopment) {
        console.warn('API call failed, using mock data:', error.message);
        return mockData.dashboardStats;
      }
      throw error;
    }
  },

  getDashboardMetrics: async (timeRange = '7d') => {
    try {
      return await dashboardAPI.getTicketMetrics(timeRange);
    } catch (error) {
      if (isDevelopment) {
        console.warn('API call failed, using mock metrics data:', error.message);
        return {
          statusDistribution: {
            open: 18,
            in_progress: 15,
            resolved: 12,
            closed: 5
          },
          categoryDistribution: {
            Software: 15,
            Hardware: 12,
            Network: 10,
            Email: 8,
            Access: 3,
            Other: 2
          },
          priorityDistribution: {
            critical: 3,
            high: 12,
            medium: 25,
            low: 10
          },
          trendData: {
            labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
            created: [8, 12, 15, 10, 14, 6, 4],
            resolved: [6, 10, 12, 13, 16, 8, 5]
          }
        };
      }
      throw error;
    }
  },

  getAgentPerformance: async () => {
    try {
      return await dashboardAPI.getAgentPerformance();
    } catch (error) {
      if (isDevelopment) {
        console.warn('API call failed, using mock agent data:', error.message);
        return {
          agents: [
            { name: 'Sarah Wilson', assigned: 8, resolved: 12, avg_time: '2.1h', status: 'available' },
            { name: 'Mike Chen', assigned: 6, resolved: 15, avg_time: '1.8h', status: 'busy' },
            { name: 'Emma Rodriguez', assigned: 4, resolved: 8, avg_time: '3.2h', status: 'available' },
            { name: 'David Kim', assigned: 7, resolved: 11, avg_time: '2.5h', status: 'available' },
            { name: 'Lisa Anderson', assigned: 5, resolved: 9, avg_time: '2.8h', status: 'busy' }
          ],
          totalAgents: 5,
          activeAgents: 3,
          avgWorkload: 75
        };
      }
      throw error;
    }
  },
};

export default api;
