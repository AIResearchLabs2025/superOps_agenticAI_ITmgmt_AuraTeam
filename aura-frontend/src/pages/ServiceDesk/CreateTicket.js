import React, { useState, useEffect, useCallback } from 'react';
import {
  Box,
  Typography,
  Card,
  CardContent,
  TextField,
  Button,
  Grid,
  MenuItem,
  FormControl,
  InputLabel,
  Select,
  FormHelperText,
  Alert,
  CircularProgress,
  Chip,
  Stack,
  Paper,
  IconButton,
  Divider,
  Stepper,
  Step,
  StepLabel,
  Container,
  useTheme,
  useMediaQuery,
  Tooltip,
  Badge,
  Fade,
  LinearProgress,
} from '@mui/material';
import {
  Send as SendIcon,
  Clear as ClearIcon,
  AttachFile as AttachFileIcon,
  Delete as DeleteIcon,
  ContactSupport as ContactIcon,
  Description as DescriptionIcon,
  Person as PersonIcon,
  Info as InfoIcon,
  AutoAwesome as AIIcon,
  Psychology as BrainIcon,
  TrendingUp as ConfidenceIcon,
  Lightbulb as SuggestionIcon,
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import { useSnackbar } from 'notistack';
import { serviceDeskAPI } from '../../services/api';

const CreateTicket = () => {
  const navigate = useNavigate();
  const { enqueueSnackbar } = useSnackbar();
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('md'));
  const isSmallScreen = useMediaQuery(theme.breakpoints.down('sm'));

  // Form state
  const [formData, setFormData] = useState({
    title: '',
    description: '',
    category: '',
    priority: 'medium',
    user_email: '',
    user_name: '',
    department: '',
    attachments: []
  });

  // Form validation state
  const [errors, setErrors] = useState({});
  const [loading, setLoading] = useState(false);
  const [activeStep, setActiveStep] = useState(0);

  // AI-powered features state
  const [aiSuggestions, setAiSuggestions] = useState([]);
  const [aiLoading, setAiLoading] = useState(false);
  const [showAiSuggestions, setShowAiSuggestions] = useState(false);
  const [aiAnalysis, setAiAnalysis] = useState(null);
  const [suggestedCategory, setSuggestedCategory] = useState('');
  const [suggestedPriority, setSuggestedPriority] = useState('');
  const [confidenceScore, setConfidenceScore] = useState(0);

  // Steps for the form
  const steps = [
    'Issue Details',
    'Contact Info',
    'Review & Submit'
  ];

  // Available options
  const categories = [
    'Hardware Issues',
    'Software Issues',
    'Network Issues',
    'Email Issues',
    'Account Management',
    'Security Issues',
    'Installation Request',
    'Access Request',
    'Other'
  ];

  const priorities = [
    { value: 'low', label: 'Low', color: 'success' },
    { value: 'medium', label: 'Medium', color: 'warning' },
    { value: 'high', label: 'High', color: 'error' },
    { value: 'critical', label: 'Critical', color: 'error' }
  ];

  const departments = [
    'IT',
    'HR',
    'Finance',
    'Marketing',
    'Sales',
    'Operations',
    'Legal',
    'Other'
  ];

  // Input validation functions
  const validateEmail = (email) => {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  };

  const sanitizeInput = (input) => {
    if (typeof input !== 'string') return input;
    
    // Remove potentially harmful characters and scripts while preserving spaces
    return input
      .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '') // Remove script tags
      .replace(/<[^>]*>/g, '') // Remove HTML tags
      .replace(/javascript:/gi, '') // Remove javascript: protocol
      .replace(/on\w+\s*=\s*["'][^"']*["']/gi, '') // Remove event handlers
      .replace(/[<>]/g, ''); // Remove any remaining < > characters
  };

  const validateForm = () => {
    const newErrors = {};

    // Title validation
    if (!formData.title.trim()) {
      newErrors.title = 'Title is required';
    } else if (formData.title.trim().length < 5) {
      newErrors.title = 'Title must be at least 5 characters long';
    } else if (formData.title.trim().length > 200) {
      newErrors.title = 'Title must be less than 200 characters';
    }

    // Description validation
    if (!formData.description.trim()) {
      newErrors.description = 'Description is required';
    } else if (formData.description.trim().length < 10) {
      newErrors.description = 'Description must be at least 10 characters long';
    } else if (formData.description.trim().length > 2000) {
      newErrors.description = 'Description must be less than 2000 characters';
    }

    // Category validation
    if (!formData.category) {
      newErrors.category = 'Category is required';
    }

    // User email validation
    if (!formData.user_email.trim()) {
      newErrors.user_email = 'Email is required';
    } else if (!validateEmail(formData.user_email)) {
      newErrors.user_email = 'Please enter a valid email address';
    }

    // User name validation
    if (!formData.user_name.trim()) {
      newErrors.user_name = 'Name is required';
    } else if (formData.user_name.trim().length < 2) {
      newErrors.user_name = 'Name must be at least 2 characters long';
    } else if (formData.user_name.trim().length > 100) {
      newErrors.user_name = 'Name must be less than 100 characters';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleInputChange = (field, value) => {
    // Sanitize input to prevent XSS
    const sanitizedValue = typeof value === 'string' ? sanitizeInput(value) : value;
    
    setFormData(prev => ({
      ...prev,
      [field]: sanitizedValue
    }));

    // Clear error for this field if it exists
    if (errors[field]) {
      setErrors(prev => ({
        ...prev,
        [field]: ''
      }));
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    if (!validateForm()) {
      enqueueSnackbar('Please fix the validation errors', { variant: 'error' });
      return;
    }

    setLoading(true);

    try {
      // Prepare ticket data
      const ticketData = {
        title: formData.title.trim(),
        description: formData.description.trim(),
        category: formData.category,
        priority: formData.priority,
        user_email: formData.user_email.trim().toLowerCase(),
        user_name: formData.user_name.trim(),
        department: formData.department,
        user_id: formData.user_email.trim().toLowerCase(), // Use email as user_id for now
        attachments: formData.attachments
      };

      // Create ticket via API
      const response = await serviceDeskAPI.createTicket(ticketData);
      
      enqueueSnackbar('Ticket created successfully!', { variant: 'success' });
      
      // Navigate to tickets list
      navigate('/tickets');
      
    } catch (error) {
      console.error('Error creating ticket:', error);
      enqueueSnackbar(
        error.message || 'Failed to create ticket. Please try again.', 
        { variant: 'error' }
      );
    } finally {
      setLoading(false);
    }
  };

  const handleClear = () => {
    setFormData({
      title: '',
      description: '',
      category: '',
      priority: 'medium',
      user_email: '',
      user_name: '',
      department: '',
      attachments: []
    });
    setErrors({});
  };

  const handleFileAttachment = (event) => {
    const files = Array.from(event.target.files);
    // For now, just store file names. In a real implementation, 
    // you would upload files to a storage service
    const fileNames = files.map(file => file.name);
    setFormData(prev => ({
      ...prev,
      attachments: [...prev.attachments, ...fileNames]
    }));
  };

  const removeAttachment = (index) => {
    setFormData(prev => ({
      ...prev,
      attachments: prev.attachments.filter((_, i) => i !== index)
    }));
  };

  const getPriorityChip = (priority) => {
    const priorityData = priorities.find(p => p.value === priority);
    return (
      <Chip
        label={priorityData?.label || priority}
        color={priorityData?.color || 'default'}
        size="small"
        variant="outlined"
      />
    );
  };

  // AI-powered functions
  const getAiSuggestions = useCallback(async (title, description) => {
    if (!title.trim() && !description.trim()) {
      setAiSuggestions([]);
      setShowAiSuggestions(false);
      return;
    }

    if (title.length < 3 && description.length < 10) {
      return; // Wait for more input
    }

    setAiLoading(true);
    
    try {
      // Simulate MCP agent call for real-time suggestions
      // In a real implementation, this would call the MCP categorization agent
      const mockSuggestions = await simulateAiSuggestions(title, description);
      
      setAiSuggestions(mockSuggestions);
      setShowAiSuggestions(mockSuggestions.length > 0);
      
      // Auto-suggest category if confidence is high
      if (mockSuggestions.length > 0 && mockSuggestions[0].confidence > 0.8) {
        setSuggestedCategory(mockSuggestions[0].category);
        setConfidenceScore(mockSuggestions[0].confidence);
      }
      
    } catch (error) {
      console.error('Error getting AI suggestions:', error);
    } finally {
      setAiLoading(false);
    }
  }, []);

  // Simulate AI suggestions (replace with actual MCP agent calls)
  const simulateAiSuggestions = async (title, description) => {
    // Simulate API delay
    await new Promise(resolve => setTimeout(resolve, 500));
    
    const text = `${title} ${description}`.toLowerCase();
    const suggestions = [];
    
    // Simple keyword-based suggestions (mimicking the MCP agent logic)
    const categoryKeywords = {
      'Email Issues': ['email', 'outlook', 'mail', 'inbox', 'send', 'receive'],
      'Network Issues': ['network', 'internet', 'wifi', 'connection', 'vpn'],
      'Hardware Issues': ['computer', 'laptop', 'printer', 'monitor', 'keyboard'],
      'Software Issues': ['software', 'application', 'app', 'program', 'windows'],
      'Access Request': ['password', 'login', 'access', 'account', 'locked'],
      'Security Issues': ['security', 'virus', 'malware', 'suspicious', 'phishing']
    };

    Object.entries(categoryKeywords).forEach(([category, keywords]) => {
      let score = 0;
      let matchedKeywords = [];
      
      keywords.forEach(keyword => {
        if (text.includes(keyword)) {
          score += keyword.length > 4 ? 2 : 1;
          matchedKeywords.push(keyword);
        }
      });
      
      if (score > 0) {
        suggestions.push({
          category,
          confidence: Math.min(score * 0.2, 0.95),
          reason: `Matches keywords: ${matchedKeywords.join(', ')}`,
          matchedKeywords
        });
      }
    });

    // Sort by confidence and return top 3
    return suggestions
      .sort((a, b) => b.confidence - a.confidence)
      .slice(0, 3);
  };

  // Debounced AI suggestions
  useEffect(() => {
    const timeoutId = setTimeout(() => {
      if (formData.title || formData.description) {
        getAiSuggestions(formData.title, formData.description);
      }
    }, 1000); // 1 second delay

    return () => clearTimeout(timeoutId);
  }, [formData.title, formData.description, getAiSuggestions]);

  // Apply AI suggestion
  const applyAiSuggestion = (suggestion) => {
    handleInputChange('category', suggestion.category);
    setSuggestedCategory('');
    setShowAiSuggestions(false);
    enqueueSnackbar(`Applied AI suggestion: ${suggestion.category}`, { variant: 'success' });
  };

  // Get comprehensive AI analysis
  const getAiAnalysis = async () => {
    if (!formData.title.trim() || !formData.description.trim()) {
      return;
    }

    setAiLoading(true);
    
    try {
      // Simulate comprehensive AI analysis
      const analysis = await simulateComprehensiveAnalysis();
      setAiAnalysis(analysis);
      
      // Auto-suggest priority based on analysis
      if (analysis.suggestedPriority && analysis.confidence > 0.7) {
        setSuggestedPriority(analysis.suggestedPriority);
      }
      
    } catch (error) {
      console.error('Error getting AI analysis:', error);
    } finally {
      setAiLoading(false);
    }
  };

  // Simulate comprehensive AI analysis
  const simulateComprehensiveAnalysis = async () => {
    await new Promise(resolve => setTimeout(resolve, 800));
    
    const text = `${formData.title} ${formData.description}`.toLowerCase();
    
    // Analyze urgency indicators
    const urgencyKeywords = ['urgent', 'asap', 'critical', 'emergency', 'down', 'offline'];
    const hasUrgency = urgencyKeywords.some(keyword => text.includes(keyword));
    
    // Analyze impact indicators
    const impactKeywords = ['everyone', 'team', 'multiple users', 'can\'t work', 'blocking'];
    const hasHighImpact = impactKeywords.some(keyword => text.includes(keyword));
    
    let suggestedPriority = 'medium';
    if (hasUrgency && hasHighImpact) {
      suggestedPriority = 'critical';
    } else if (hasUrgency || hasHighImpact) {
      suggestedPriority = 'high';
    } else if (text.includes('slow') || text.includes('issue')) {
      suggestedPriority = 'medium';
    } else {
      suggestedPriority = 'low';
    }

    return {
      suggestedPriority,
      confidence: 0.85,
      urgencyIndicators: urgencyKeywords.filter(keyword => text.includes(keyword)),
      impactIndicators: impactKeywords.filter(keyword => text.includes(keyword)),
      estimatedResolutionTime: suggestedPriority === 'critical' ? '1-2 hours' : 
                               suggestedPriority === 'high' ? '4-6 hours' : 
                               suggestedPriority === 'medium' ? '1-2 days' : '2-3 days',
      recommendedActions: [
        'Gather additional system information',
        'Check for similar recent issues',
        'Prepare troubleshooting steps'
      ]
    };
  };

  // Helper function to render step content
  const renderStepContent = (step) => {
    switch (step) {
      case 0:
        return (
          <Grid container spacing={3}>
            {/* Issue Details */}
            <Grid item xs={12}>
              <Box sx={{ display: 'flex', alignItems: 'center', mb: 3 }}>
                <DescriptionIcon sx={{ mr: 2, color: 'primary.main' }} />
                <Typography variant="h6" sx={{ color: 'primary.main' }}>
                  Describe Your Issue
                </Typography>
              </Box>
            </Grid>

            {/* Title */}
            <Grid item xs={12}>
              <TextField
                fullWidth
                label="Issue Title"
                placeholder="Brief description of the issue (e.g., 'Cannot access email')"
                value={formData.title}
                onChange={(e) => handleInputChange('title', e.target.value)}
                error={!!errors.title}
                helperText={errors.title}
                required
                inputProps={{ maxLength: 200 }}
                sx={{ mb: 2 }}
              />
            </Grid>

            {/* Description */}
            <Grid item xs={12}>
              <TextField
                fullWidth
                multiline
                rows={isSmallScreen ? 3 : 5}
                label="Detailed Description"
                placeholder="Please provide detailed information including:
• What happened?
• When did it start?
• Any error messages?
• Steps you've already tried?"
                value={formData.description}
                onChange={(e) => handleInputChange('description', e.target.value)}
                error={!!errors.description}
                helperText={errors.description}
                required
                inputProps={{ maxLength: 2000 }}
              />
              <Box sx={{ display: 'flex', justifyContent: 'space-between', mt: 1 }}>
                <Typography variant="caption" color="text.secondary">
                  Tip: More details help us resolve your issue faster
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  {formData.description.length}/2000
                </Typography>
              </Box>
            </Grid>

            {/* AI Suggestions Panel */}
            {(showAiSuggestions || aiLoading) && (
              <Grid item xs={12}>
                <Fade in={showAiSuggestions || aiLoading}>
                  <Paper 
                    variant="outlined" 
                    sx={{ 
                      p: 3, 
                      backgroundColor: 'primary.50',
                      border: '2px solid',
                      borderColor: 'primary.200',
                      borderRadius: 2
                    }}
                  >
                    <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                      <AIIcon sx={{ mr: 2, color: 'primary.main' }} />
                      <Typography variant="h6" sx={{ color: 'primary.main', flexGrow: 1 }}>
                        AI Suggestions
                      </Typography>
                      {aiLoading && <CircularProgress size={20} />}
                    </Box>
                    
                    {aiLoading ? (
                      <Box sx={{ display: 'flex', alignItems: 'center', py: 2 }}>
                        <LinearProgress sx={{ flexGrow: 1, mr: 2 }} />
                        <Typography variant="body2" color="text.secondary">
                          Analyzing your issue...
                        </Typography>
                      </Box>
                    ) : (
                      <>
                        <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                          Based on your description, here are our AI-powered category suggestions:
                        </Typography>
                        
                        <Stack spacing={2}>
                          {aiSuggestions.map((suggestion, index) => (
                            <Paper 
                              key={index}
                              variant="outlined" 
                              sx={{ 
                                p: 2, 
                                cursor: 'pointer',
                                transition: 'all 0.2s',
                                '&:hover': {
                                  backgroundColor: 'primary.50',
                                  borderColor: 'primary.main'
                                }
                              }}
                              onClick={() => applyAiSuggestion(suggestion)}
                            >
                              <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                                <Box sx={{ flexGrow: 1 }}>
                                  <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 0.5 }}>
                                    {suggestion.category}
                                  </Typography>
                                  <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
                                    {suggestion.reason}
                                  </Typography>
                                  <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                                    <ConfidenceIcon sx={{ fontSize: 16, color: 'success.main' }} />
                                    <Typography variant="caption" color="success.main">
                                      {Math.round(suggestion.confidence * 100)}% confidence
                                    </Typography>
                                  </Box>
                                </Box>
                                <Button
                                  variant="outlined"
                                  size="small"
                                  startIcon={<SuggestionIcon />}
                                  onClick={(e) => {
                                    e.stopPropagation();
                                    applyAiSuggestion(suggestion);
                                  }}
                                >
                                  Apply
                                </Button>
                              </Box>
                            </Paper>
                          ))}
                        </Stack>
                        
                        {aiSuggestions.length === 0 && (
                          <Alert severity="info" sx={{ mt: 2 }}>
                            <Typography variant="body2">
                              No specific suggestions yet. Try adding more details to get better AI recommendations.
                            </Typography>
                          </Alert>
                        )}
                      </>
                    )}
                  </Paper>
                </Fade>
              </Grid>
            )}

            {/* Category and Priority */}
            <Grid item xs={12} sm={6}>
              <FormControl fullWidth error={!!errors.category} required>
                <InputLabel>Issue Category</InputLabel>
                <Select
                  value={formData.category}
                  onChange={(e) => handleInputChange('category', e.target.value)}
                  label="Issue Category"
                >
                  {categories.map((category) => (
                    <MenuItem key={category} value={category}>
                      {category}
                    </MenuItem>
                  ))}
                </Select>
                {errors.category && <FormHelperText>{errors.category}</FormHelperText>}
                
                {/* Show AI suggestion badge if available */}
                {suggestedCategory && suggestedCategory !== formData.category && (
                  <FormHelperText sx={{ color: 'primary.main' }}>
                    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mt: 1 }}>
                      <BrainIcon sx={{ fontSize: 16 }} />
                      <Typography variant="caption">
                        AI suggests: {suggestedCategory} ({Math.round(confidenceScore * 100)}% confidence)
                      </Typography>
                      <Button
                        size="small"
                        variant="text"
                        onClick={() => applyAiSuggestion({ category: suggestedCategory })}
                        sx={{ ml: 1, minWidth: 'auto', p: 0.5 }}
                      >
                        Apply
                      </Button>
                    </Box>
                  </FormHelperText>
                )}
              </FormControl>
            </Grid>

            <Grid item xs={12} sm={6}>
              <FormControl fullWidth>
                <InputLabel>Priority Level</InputLabel>
                <Select
                  value={formData.priority}
                  onChange={(e) => handleInputChange('priority', e.target.value)}
                  label="Priority Level"
                >
                  {priorities.map((priority) => (
                    <MenuItem key={priority.value} value={priority.value}>
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, width: '100%' }}>
                        <Box sx={{ flexGrow: 1 }}>{priority.label}</Box>
                        {getPriorityChip(priority.value)}
                      </Box>
                    </MenuItem>
                  ))}
                </Select>
                <FormHelperText>
                  {formData.priority === 'critical' && 'Critical: System down, no workaround'}
                  {formData.priority === 'high' && 'High: Significant impact on work'}
                  {formData.priority === 'medium' && 'Medium: Some impact, workaround available'}
                  {formData.priority === 'low' && 'Low: Minor issue, can wait'}
                </FormHelperText>
              </FormControl>
            </Grid>

            {/* Attachments */}
            <Grid item xs={12}>
              <Box sx={{ mt: 2 }}>
                <Typography variant="subtitle1" sx={{ mb: 2, display: 'flex', alignItems: 'center' }}>
                  <AttachFileIcon sx={{ mr: 1 }} />
                  Attachments (Optional)
                </Typography>
                
                <input
                  accept="image/*,.pdf,.doc,.docx,.txt"
                  style={{ display: 'none' }}
                  id="file-upload"
                  multiple
                  type="file"
                  onChange={handleFileAttachment}
                />
                <label htmlFor="file-upload">
                  <Button
                    variant="outlined"
                    component="span"
                    startIcon={<AttachFileIcon />}
                    sx={{ mb: 2 }}
                    fullWidth={isSmallScreen}
                  >
                    Add Screenshots or Documents
                  </Button>
                </label>

                {formData.attachments.length > 0 && (
                  <Paper 
                    variant="outlined" 
                    sx={{ 
                      p: 2, 
                      mt: 2, 
                      backgroundColor: 'grey.50',
                      borderRadius: 2 
                    }}
                  >
                    <Typography variant="subtitle2" sx={{ mb: 1, color: 'text.secondary' }}>
                      Attached Files ({formData.attachments.length}):
                    </Typography>
                    <Stack 
                      direction={isSmallScreen ? 'column' : 'row'} 
                      spacing={1} 
                      flexWrap="wrap"
                      useFlexGap
                    >
                      {formData.attachments.map((file, index) => (
                        <Chip
                          key={index}
                          label={file}
                          onDelete={() => removeAttachment(index)}
                          deleteIcon={<DeleteIcon />}
                          variant="outlined"
                          size="small"
                          sx={{ maxWidth: '100%' }}
                        />
                      ))}
                    </Stack>
                  </Paper>
                )}
              </Box>
            </Grid>
          </Grid>
        );

      case 1:
        return (
          <Grid container spacing={3}>
            {/* Contact Information */}
            <Grid item xs={12}>
              <Box sx={{ display: 'flex', alignItems: 'center', mb: 3 }}>
                <PersonIcon sx={{ mr: 2, color: 'primary.main' }} />
                <Typography variant="h6" sx={{ color: 'primary.main' }}>
                  Your Contact Information
                </Typography>
              </Box>
            </Grid>

            <Grid item xs={12} sm={6}>
              <TextField
                fullWidth
                label="Full Name"
                placeholder="Enter your full name"
                value={formData.user_name}
                onChange={(e) => handleInputChange('user_name', e.target.value)}
                error={!!errors.user_name}
                helperText={errors.user_name}
                required
                inputProps={{ maxLength: 100 }}
              />
            </Grid>

            <Grid item xs={12} sm={6}>
              <TextField
                fullWidth
                type="email"
                label="Email Address"
                placeholder="your.email@company.com"
                value={formData.user_email}
                onChange={(e) => handleInputChange('user_email', e.target.value)}
                error={!!errors.user_email}
                helperText={errors.user_email}
                required
              />
            </Grid>

            <Grid item xs={12} sm={6}>
              <FormControl fullWidth>
                <InputLabel>Department</InputLabel>
                <Select
                  value={formData.department}
                  onChange={(e) => handleInputChange('department', e.target.value)}
                  label="Department"
                >
                  <MenuItem value="">
                    <em>Select your department</em>
                  </MenuItem>
                  {departments.map((dept) => (
                    <MenuItem key={dept} value={dept}>
                      {dept}
                    </MenuItem>
                  ))}
                </Select>
                <FormHelperText>This helps us route your ticket to the right team</FormHelperText>
              </FormControl>
            </Grid>
          </Grid>
        );

      case 2:
        return (
          <Grid container spacing={3}>
            {/* Review Information */}
            <Grid item xs={12}>
              <Box sx={{ display: 'flex', alignItems: 'center', mb: 3 }}>
                <InfoIcon sx={{ mr: 2, color: 'primary.main' }} />
                <Typography variant="h6" sx={{ color: 'primary.main' }}>
                  Review Your Ticket
                </Typography>
              </Box>
            </Grid>

            {/* Summary Cards */}
            <Grid item xs={12}>
              <Paper variant="outlined" sx={{ p: 3, mb: 2, borderRadius: 2 }}>
                <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 2, color: 'primary.main' }}>
                  Issue Summary
                </Typography>
                <Box sx={{ mb: 2 }}>
                  <Typography variant="body2" color="text.secondary" sx={{ mb: 0.5 }}>
                    Title:
                  </Typography>
                  <Typography variant="body1" sx={{ fontWeight: 500 }}>
                    {formData.title || 'Not specified'}
                  </Typography>
                </Box>
                <Box sx={{ mb: 2 }}>
                  <Typography variant="body2" color="text.secondary" sx={{ mb: 0.5 }}>
                    Category:
                  </Typography>
                  <Chip label={formData.category || 'Not selected'} size="small" variant="outlined" />
                </Box>
                <Box sx={{ mb: 2 }}>
                  <Typography variant="body2" color="text.secondary" sx={{ mb: 0.5 }}>
                    Priority:
                  </Typography>
                  {getPriorityChip(formData.priority)}
                </Box>
                <Box>
                  <Typography variant="body2" color="text.secondary" sx={{ mb: 0.5 }}>
                    Description:
                  </Typography>
                  <Typography variant="body2" sx={{ 
                    whiteSpace: 'pre-wrap', 
                    backgroundColor: 'grey.50', 
                    p: 2, 
                    borderRadius: 1,
                    maxHeight: 100,
                    overflow: 'auto'
                  }}>
                    {formData.description || 'Not provided'}
                  </Typography>
                </Box>
              </Paper>
            </Grid>

            <Grid item xs={12}>
              <Paper variant="outlined" sx={{ p: 3, borderRadius: 2 }}>
                <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 2, color: 'primary.main' }}>
                  Contact Details
                </Typography>
                <Grid container spacing={2}>
                  <Grid item xs={12} sm={6}>
                    <Typography variant="body2" color="text.secondary">
                      Name: <strong>{formData.user_name || 'Not provided'}</strong>
                    </Typography>
                  </Grid>
                  <Grid item xs={12} sm={6}>
                    <Typography variant="body2" color="text.secondary">
                      Email: <strong>{formData.user_email || 'Not provided'}</strong>
                    </Typography>
                  </Grid>
                  <Grid item xs={12} sm={6}>
                    <Typography variant="body2" color="text.secondary">
                      Department: <strong>{formData.department || 'Not specified'}</strong>
                    </Typography>
                  </Grid>
                  {formData.attachments.length > 0 && (
                    <Grid item xs={12}>
                      <Typography variant="body2" color="text.secondary">
                        Attachments: <strong>{formData.attachments.length} file(s)</strong>
                      </Typography>
                    </Grid>
                  )}
                </Grid>
              </Paper>
            </Grid>
          </Grid>
        );

      default:
        return null;
    }
  };

  return (
    <Container maxWidth="lg" className="fade-in">
      {/* Header */}
      <Box sx={{ mb: 4, textAlign: isMobile ? 'center' : 'left' }}>
        <Typography 
          variant={isSmallScreen ? "h5" : "h4"} 
          sx={{ fontWeight: 600, mb: 1, display: 'flex', alignItems: 'center', justifyContent: isMobile ? 'center' : 'flex-start' }}
        >
          <ContactIcon sx={{ mr: 2, fontSize: isSmallScreen ? '1.5rem' : '2rem' }} />
          Create New Support Ticket
        </Typography>
        <Typography variant="body1" color="text.secondary">
          We're here to help! Provide details about your issue and we'll get back to you quickly.
        </Typography>
      </Box>

      {/* Progress Stepper */}
      {!isSmallScreen && (
        <Card sx={{ mb: 4 }}>
          <CardContent sx={{ py: 3 }}>
            <Stepper activeStep={activeStep} alternativeLabel={isMobile}>
              {steps.map((label) => (
                <Step key={label}>
                  <StepLabel>{label}</StepLabel>
                </Step>
              ))}
            </Stepper>
          </CardContent>
        </Card>
      )}

      {/* Form Card */}
      <Card sx={{ mb: 4 }}>
        <CardContent sx={{ p: isSmallScreen ? 2 : 4 }}>
          <form onSubmit={handleSubmit}>
            {renderStepContent(activeStep)}

            {/* Navigation Buttons */}
            <Box sx={{ 
              display: 'flex', 
              justifyContent: 'space-between', 
              mt: 4, 
              pt: 3, 
              borderTop: 1, 
              borderColor: 'divider',
              flexDirection: isSmallScreen ? 'column' : 'row',
              gap: 2
            }}>
              <Box sx={{ display: 'flex', gap: 2 }}>
                {activeStep > 0 && (
                  <Button
                    onClick={() => setActiveStep(activeStep - 1)}
                    variant="outlined"
                    fullWidth={isSmallScreen}
                  >
                    Back
                  </Button>
                )}
                <Button
                  variant="outlined"
                  onClick={handleClear}
                  startIcon={<ClearIcon />}
                  disabled={loading}
                  fullWidth={isSmallScreen}
                >
                  Clear Form
                </Button>
              </Box>

              <Box sx={{ display: 'flex', gap: 2 }}>
                {activeStep < steps.length - 1 ? (
                  <Button
                    variant="contained"
                    onClick={() => {
                      // Basic validation before moving to next step
                      if (activeStep === 0 && (!formData.title.trim() || !formData.description.trim() || !formData.category)) {
                        validateForm();
                        enqueueSnackbar('Please fill in all required fields', { variant: 'warning' });
                        return;
                      }
                      if (activeStep === 1 && (!formData.user_name.trim() || !formData.user_email.trim())) {
                        validateForm();
                        enqueueSnackbar('Please fill in all required fields', { variant: 'warning' });
                        return;
                      }
                      setActiveStep(activeStep + 1);
                    }}
                    fullWidth={isSmallScreen}
                  >
                    Continue
                  </Button>
                ) : (
                  <Button
                    type="submit"
                    variant="contained"
                    startIcon={loading ? <CircularProgress size={20} color="inherit" /> : <SendIcon />}
                    disabled={loading}
                    sx={{ minWidth: 140 }}
                    fullWidth={isSmallScreen}
                  >
                    {loading ? 'Creating Ticket...' : 'Submit Ticket'}
                  </Button>
                )}
              </Box>
            </Box>
          </form>
        </CardContent>
      </Card>

      {/* Help Section */}
      <Card>
        <CardContent sx={{ p: isSmallScreen ? 2 : 3 }}>
          <Typography variant="h6" sx={{ mb: 2, display: 'flex', alignItems: 'center' }}>
            <InfoIcon sx={{ mr: 1 }} />
            Need Immediate Help?
          </Typography>
          
          <Grid container spacing={2}>
            <Grid item xs={12} md={8}>
              <Alert severity="info" sx={{ mb: 2 }}>
                <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                  Emergency Support: +1 (555) 123-4567
                </Typography>
                <Typography variant="body2">
                  Available 24/7 for critical system issues
                </Typography>
              </Alert>
            </Grid>
            <Grid item xs={12} md={4}>
              <Paper variant="outlined" sx={{ p: 2, textAlign: 'center' }}>
                <Typography variant="caption" color="text.secondary">
                  Average Response Time
                </Typography>
                <Typography variant="h6" color="primary.main">
                  2-4 Hours
                </Typography>
              </Paper>
            </Grid>
          </Grid>

          <Box sx={{ mt: 2 }}>
            <Typography variant="body2" color="text.secondary">
              <strong>Tips for faster resolution:</strong>
            </Typography>
            <Box component="ul" sx={{ mt: 1, pl: 2 }}>
              <Typography component="li" variant="body2" color="text.secondary">
                Include screenshots or error messages when possible
              </Typography>
              <Typography component="li" variant="body2" color="text.secondary">
                Describe what you were doing when the issue occurred
              </Typography>
              <Typography component="li" variant="body2" color="text.secondary">
                Mention any troubleshooting steps you've already tried
              </Typography>
            </Box>
          </Box>
        </CardContent>
      </Card>
    </Container>
  );
};

export default CreateTicket;
