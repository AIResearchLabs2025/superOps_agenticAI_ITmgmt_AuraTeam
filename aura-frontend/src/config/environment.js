// Environment configuration for dynamic API endpoint detection
// This handles the dynamic IP issue in AWS deployments

const getApiBaseUrl = () => {
  // Check if we're in a browser environment
  if (typeof window === 'undefined') {
    return process.env.REACT_APP_API_BASE_URL || 'http://localhost:8000';
  }

  // Priority 1: Environment variable (set during build)
  if (process.env.REACT_APP_API_BASE_URL) {
    return process.env.REACT_APP_API_BASE_URL;
  }

  // Priority 2: Runtime detection for AWS environments
  const hostname = window.location.hostname;
  const protocol = window.location.protocol;
  const port = window.location.port;

  // If we're running on AWS (detected by hostname patterns)
  if (hostname.includes('amazonaws.com') || 
      hostname.includes('elb.') || 
      hostname.match(/^\d+\.\d+\.\d+\.\d+$/)) {
    
    // If we're behind an ALB, use the same hostname
    if (hostname.includes('elb.')) {
      return `${protocol}//${hostname}`;
    }
    
    // If we're on a direct IP, try to detect the API gateway port
    if (hostname.match(/^\d+\.\d+\.\d+\.\d+$/)) {
      return `${protocol}//${hostname}:8000`;
    }
    
    // Fallback for other AWS patterns
    return `${protocol}//${hostname}:8000`;
  }

  // Priority 3: Local development detection
  if (hostname === 'localhost' || hostname === '127.0.0.1') {
    return 'http://localhost:8000';
  }

  // Priority 4: Default fallback
  return 'http://localhost:8000';
};

const config = {
  // API Configuration
  API_BASE_URL: getApiBaseUrl(),
  
  // Environment detection
  ENVIRONMENT: process.env.NODE_ENV || 'development',
  
  // Feature flags
  ENABLE_MOCK_DATA: process.env.NODE_ENV === 'development',
  ENABLE_DEBUG_LOGS: process.env.NODE_ENV === 'development',
  
  // Timeout configurations
  API_TIMEOUT: 10000, // 10 seconds
  HEALTH_CHECK_INTERVAL: 30000, // 30 seconds
  
  // Retry configuration for failed requests
  MAX_RETRIES: 3,
  RETRY_DELAY: 1000, // 1 second
  
  // AWS-specific configurations
  AWS_REGION: 'us-east-2',
  
  // Health check endpoints for dynamic discovery
  HEALTH_ENDPOINTS: [
    '/health',
    '/api/v1/health',
    '/status'
  ]
};

// Dynamic API endpoint discovery function
export const discoverApiEndpoint = async () => {
  const baseUrl = config.API_BASE_URL;
  
  // Test the current configuration
  for (const endpoint of config.HEALTH_ENDPOINTS) {
    try {
      const response = await fetch(`${baseUrl}${endpoint}`, {
        method: 'GET',
        timeout: 5000
      });
      
      if (response.ok) {
        console.log(`✅ API endpoint discovered: ${baseUrl}${endpoint}`);
        return baseUrl;
      }
    } catch (error) {
      console.warn(`❌ Health check failed for ${baseUrl}${endpoint}:`, error.message);
    }
  }
  
  // If current config fails, try alternative endpoints in AWS
  if (typeof window !== 'undefined') {
    const hostname = window.location.hostname;
    const protocol = window.location.protocol;
    
    // Try different port combinations for AWS deployments
    const alternativePorts = [8000, 8001, 80, 443];
    
    for (const port of alternativePorts) {
      const altUrl = `${protocol}//${hostname}:${port}`;
      
      for (const endpoint of config.HEALTH_ENDPOINTS) {
        try {
          const response = await fetch(`${altUrl}${endpoint}`, {
            method: 'GET',
            timeout: 5000
          });
          
          if (response.ok) {
            console.log(`✅ Alternative API endpoint discovered: ${altUrl}${endpoint}`);
            // Update the configuration dynamically
            config.API_BASE_URL = altUrl;
            return altUrl;
          }
        } catch (error) {
          // Silent fail for discovery attempts
        }
      }
    }
  }
  
  console.warn('⚠️ Could not discover API endpoint, using default configuration');
  return baseUrl;
};

// Connection health monitor
export const startHealthMonitor = () => {
  if (typeof window === 'undefined' || !config.ENABLE_DEBUG_LOGS) {
    return;
  }
  
  const checkHealth = async () => {
    try {
      const response = await fetch(`${config.API_BASE_URL}/health`, {
        method: 'GET',
        timeout: 5000
      });
      
      if (response.ok) {
        console.log('🟢 API health check: OK');
      } else {
        console.warn('🟡 API health check: Degraded');
      }
    } catch (error) {
      console.error('🔴 API health check: Failed', error.message);
      
      // Attempt to rediscover endpoint
      if (error.message.includes('fetch')) {
        console.log('🔍 Attempting to rediscover API endpoint...');
        await discoverApiEndpoint();
      }
    }
  };
  
  // Initial health check
  setTimeout(checkHealth, 2000);
  
  // Periodic health checks
  setInterval(checkHealth, config.HEALTH_CHECK_INTERVAL);
};

// Utility function to get environment-specific configuration
export const getEnvironmentConfig = () => {
  const hostname = typeof window !== 'undefined' ? window.location.hostname : 'localhost';
  
  if (hostname.includes('amazonaws.com') || hostname.includes('elb.')) {
    return {
      ...config,
      ENVIRONMENT: 'aws',
      ENABLE_MOCK_DATA: false,
      ENABLE_DEBUG_LOGS: false
    };
  }
  
  if (hostname === 'localhost' || hostname === '127.0.0.1') {
    return {
      ...config,
      ENVIRONMENT: 'local',
      ENABLE_MOCK_DATA: true,
      ENABLE_DEBUG_LOGS: true
    };
  }
  
  return config;
};

// Export the configuration
export default config;

// Debug logging
if (config.ENABLE_DEBUG_LOGS) {
  console.log('🔧 Environment Configuration:', {
    API_BASE_URL: config.API_BASE_URL,
    ENVIRONMENT: config.ENVIRONMENT,
    hostname: typeof window !== 'undefined' ? window.location.hostname : 'server',
    userAgent: typeof window !== 'undefined' ? window.navigator.userAgent : 'server'
  });
}
