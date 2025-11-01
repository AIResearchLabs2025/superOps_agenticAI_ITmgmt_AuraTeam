import React, { useState, useEffect } from 'react';
import {
  Box,
  Card,
  CardContent,
  Typography,
  Button,
  Chip,
  Grid,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  Alert,
  CircularProgress,
  Tabs,
  Tab,
  Paper,
  List,
  ListItem,
  ListItemText,
  ListItemSecondaryAction,
  IconButton,
  Tooltip,
  LinearProgress,
  Divider,
} from '@mui/material';
import {
  AutoAwesome as AIIcon,
  ThumbUp as ApproveIcon,
  ThumbDown as RejectIcon,
  Edit as EditIcon,
  Visibility as ViewIcon,
  TrendingUp as TrendingIcon,
  Assessment as AnalyticsIcon,
  Lightbulb as SuggestionIcon,
  CheckCircle as CheckIcon,
  Cancel as CancelIcon,
  Schedule as PendingIcon,
} from '@mui/icons-material';
import { knowledgeBaseAPI } from '../../services/api';

const KBSuggestions = () => {
  const [suggestions, setSuggestions] = useState([]);
  const [analytics, setAnalytics] = useState(null);
  const [loading, setLoading] = useState(true);
  const [selectedTab, setSelectedTab] = useState(0);
  const [selectedSuggestion, setSelectedSuggestion] = useState(null);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [actionType, setActionType] = useState('');
  const [feedback, setFeedback] = useState('');
  const [editedContent, setEditedContent] = useState('');
  const [processing, setProcessing] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      setLoading(true);
      setError(null);
      
      const [suggestionsResponse, analyticsResponse] = await Promise.all([
        knowledgeBaseAPI.getSuggestions(),
        knowledgeBaseAPI.getSuggestionsAnalytics()
      ]);
      
      setSuggestions(suggestionsResponse.suggestions || []);
      setAnalytics(analyticsResponse.analytics || null);
    } catch (error) {
      console.error('Error loading KB suggestions:', error);
      setError('Failed to load KB suggestions. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleAction = (suggestion, action) => {
    setSelectedSuggestion(suggestion);
    setActionType(action);
    setFeedback('');
    setEditedContent(action === 'edit' ? suggestion.content : '');
    setDialogOpen(true);
  };

  const handleConfirmAction = async () => {
    if (!selectedSuggestion || !actionType) return;

    try {
      setProcessing(true);
      
      await knowledgeBaseAPI.updateSuggestionStatus(
        selectedSuggestion.id,
        actionType,
        feedback,
        editedContent
      );

      // Update local state
      setSuggestions(prev => prev.map(s => 
        s.id === selectedSuggestion.id 
          ? { ...s, status: actionType === 'edit' ? 'pending' : actionType }
          : s
      ));

      setDialogOpen(false);
      
      // Reload analytics
      const analyticsResponse = await knowledgeBaseAPI.getSuggestionsAnalytics();
      setAnalytics(analyticsResponse.analytics || null);
      
    } catch (error) {
      console.error('Error updating suggestion:', error);
      setError('Failed to update suggestion. Please try again.');
    } finally {
      setProcessing(false);
    }
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'approved': return 'success';
      case 'rejected': return 'error';
      case 'pending': return 'warning';
      default: return 'default';
    }
  };

  const getStatusIcon = (status) => {
    switch (status) {
      case 'approved': return <CheckIcon />;
      case 'rejected': return <CancelIcon />;
      case 'pending': return <PendingIcon />;
      default: return <SuggestionIcon />;
    }
  };

  const getConfidenceColor = (score) => {
    if (score >= 0.8) return 'success';
    if (score >= 0.6) return 'warning';
    return 'error';
  };

  const renderSuggestionCard = (suggestion) => (
    <Card key={suggestion.id} sx={{ mb: 2, border: '1px solid #e0e0e0' }}>
      <CardContent>
        <Box display="flex" justifyContent="space-between" alignItems="flex-start" mb={2}>
          <Box flex={1}>
            <Typography variant="h6" gutterBottom>
              {suggestion.title}
            </Typography>
            <Box display="flex" gap={1} mb={1}>
              <Chip 
                label={suggestion.category} 
                size="small" 
                color="primary" 
                variant="outlined" 
              />
              <Chip 
                icon={getStatusIcon(suggestion.status)}
                label={suggestion.status.toUpperCase()} 
                size="small" 
                color={getStatusColor(suggestion.status)}
              />
            </Box>
          </Box>
          <Box display="flex" gap={1}>
            <Tooltip title="View Details">
              <IconButton 
                size="small" 
                onClick={() => handleAction(suggestion, 'view')}
              >
                <ViewIcon />
              </IconButton>
            </Tooltip>
            {suggestion.status === 'pending' && (
              <>
                <Tooltip title="Edit Content">
                  <IconButton 
                    size="small" 
                    onClick={() => handleAction(suggestion, 'edit')}
                  >
                    <EditIcon />
                  </IconButton>
                </Tooltip>
                <Tooltip title="Approve">
                  <IconButton 
                    size="small" 
                    color="success"
                    onClick={() => handleAction(suggestion, 'approve')}
                  >
                    <ApproveIcon />
                  </IconButton>
                </Tooltip>
                <Tooltip title="Reject">
                  <IconButton 
                    size="small" 
                    color="error"
                    onClick={() => handleAction(suggestion, 'reject')}
                  >
                    <RejectIcon />
                  </IconButton>
                </Tooltip>
              </>
            )}
          </Box>
        </Box>

        <Typography variant="body2" color="text.secondary" paragraph>
          {suggestion.content.substring(0, 200)}...
        </Typography>

        <Grid container spacing={2}>
          <Grid item xs={12} sm={6}>
            <Box>
              <Typography variant="caption" display="block">
                Confidence Score
              </Typography>
              <Box display="flex" alignItems="center" gap={1}>
                <LinearProgress 
                  variant="determinate" 
                  value={suggestion.confidence_score * 100}
                  color={getConfidenceColor(suggestion.confidence_score)}
                  sx={{ flex: 1, height: 8, borderRadius: 4 }}
                />
                <Typography variant="caption">
                  {Math.round(suggestion.confidence_score * 100)}%
                </Typography>
              </Box>
            </Box>
          </Grid>
          <Grid item xs={12} sm={6}>
            <Box>
              <Typography variant="caption" display="block">
                Impact Score
              </Typography>
              <Box display="flex" alignItems="center" gap={1}>
                <LinearProgress 
                  variant="determinate" 
                  value={suggestion.impact_score * 100}
                  color={getConfidenceColor(suggestion.impact_score)}
                  sx={{ flex: 1, height: 8, borderRadius: 4 }}
                />
                <Typography variant="caption">
                  {Math.round(suggestion.impact_score * 100)}%
                </Typography>
              </Box>
            </Box>
          </Grid>
        </Grid>

        <Box mt={2}>
          <Typography variant="caption" color="text.secondary">
            Based on {suggestion.ticket_cluster.count} similar tickets • 
            Tags: {suggestion.tags.join(', ')} • 
            Created: {new Date(suggestion.created_at).toLocaleDateString()}
          </Typography>
        </Box>
      </CardContent>
    </Card>
  );

  const renderAnalytics = () => {
    if (!analytics) return null;

    return (
      <Grid container spacing={3}>
        <Grid item xs={12} md={4}>
          <Card>
            <CardContent>
              <Box display="flex" alignItems="center" gap={2}>
                <SuggestionIcon color="primary" />
                <Box>
                  <Typography variant="h4">{analytics.total_suggestions}</Typography>
                  <Typography variant="body2" color="text.secondary">
                    Total Suggestions
                  </Typography>
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>
        
        <Grid item xs={12} md={4}>
          <Card>
            <CardContent>
              <Box display="flex" alignItems="center" gap={2}>
                <TrendingIcon color="success" />
                <Box>
                  <Typography variant="h4">
                    {Math.round(analytics.approval_rate * 100)}%
                  </Typography>
                  <Typography variant="body2" color="text.secondary">
                    Approval Rate
                  </Typography>
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>
        
        <Grid item xs={12} md={4}>
          <Card>
            <CardContent>
              <Box display="flex" alignItems="center" gap={2}>
                <AnalyticsIcon color="info" />
                <Box>
                  <Typography variant="h4">
                    {Math.round(analytics.avg_confidence_score * 100)}%
                  </Typography>
                  <Typography variant="body2" color="text.secondary">
                    Avg Confidence
                  </Typography>
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} md={6}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Status Breakdown
              </Typography>
              <List dense>
                {Object.entries(analytics.status_breakdown).map(([status, count]) => (
                  <ListItem key={status}>
                    <ListItemText 
                      primary={status.charAt(0).toUpperCase() + status.slice(1)}
                      secondary={`${count} suggestions`}
                    />
                    <ListItemSecondaryAction>
                      <Chip 
                        label={count} 
                        size="small" 
                        color={getStatusColor(status)}
                      />
                    </ListItemSecondaryAction>
                  </ListItem>
                ))}
              </List>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} md={6}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Top Categories
              </Typography>
              <List dense>
                {analytics.top_categories.map((category) => (
                  <ListItem key={category.category}>
                    <ListItemText 
                      primary={category.category}
                      secondary={`${category.count} suggestions`}
                    />
                    <ListItemSecondaryAction>
                      <Chip 
                        label={category.count} 
                        size="small" 
                        color="primary"
                        variant="outlined"
                      />
                    </ListItemSecondaryAction>
                  </ListItem>
                ))}
              </List>
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    );
  };

  const filteredSuggestions = suggestions.filter(suggestion => {
    switch (selectedTab) {
      case 0: return suggestion.status === 'pending';
      case 1: return suggestion.status === 'approved';
      case 2: return suggestion.status === 'rejected';
      default: return true;
    }
  });

  if (loading) {
    return (
      <Box display="flex" justifyContent="center" alignItems="center" minHeight="400px">
        <CircularProgress />
      </Box>
    );
  }

  return (
    <Box>
      <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
        <Typography variant="h4" component="h1">
          <AIIcon sx={{ mr: 1, verticalAlign: 'middle' }} />
          KB Suggestions
        </Typography>
        <Button 
          variant="outlined" 
          onClick={loadData}
          disabled={loading}
        >
          Refresh
        </Button>
      </Box>

      {error && (
        <Alert severity="error" sx={{ mb: 3 }}>
          {error}
        </Alert>
      )}

      <Paper sx={{ mb: 3 }}>
        <Tabs 
          value={selectedTab} 
          onChange={(e, newValue) => setSelectedTab(newValue)}
          variant="fullWidth"
        >
          <Tab label={`Pending (${suggestions.filter(s => s.status === 'pending').length})`} />
          <Tab label={`Approved (${suggestions.filter(s => s.status === 'approved').length})`} />
          <Tab label={`Rejected (${suggestions.filter(s => s.status === 'rejected').length})`} />
          <Tab label="Analytics" />
        </Tabs>
      </Paper>

      {selectedTab === 3 ? (
        renderAnalytics()
      ) : (
        <Box>
          {filteredSuggestions.length === 0 ? (
            <Card>
              <CardContent>
                <Typography variant="body1" color="text.secondary" textAlign="center">
                  No suggestions found for this category.
                </Typography>
              </CardContent>
            </Card>
          ) : (
            filteredSuggestions.map(renderSuggestionCard)
          )}
        </Box>
      )}

      {/* Action Dialog */}
      <Dialog 
        open={dialogOpen} 
        onClose={() => setDialogOpen(false)}
        maxWidth="md"
        fullWidth
      >
        <DialogTitle>
          {actionType === 'view' && 'View Suggestion'}
          {actionType === 'edit' && 'Edit Suggestion'}
          {actionType === 'approve' && 'Approve Suggestion'}
          {actionType === 'reject' && 'Reject Suggestion'}
        </DialogTitle>
        
        <DialogContent>
          {selectedSuggestion && (
            <Box>
              <Typography variant="h6" gutterBottom>
                {selectedSuggestion.title}
              </Typography>
              
              <Box display="flex" gap={1} mb={2}>
                <Chip label={selectedSuggestion.category} size="small" />
                <Chip 
                  label={`${Math.round(selectedSuggestion.confidence_score * 100)}% confidence`}
                  size="small" 
                  color={getConfidenceColor(selectedSuggestion.confidence_score)}
                />
              </Box>

              {actionType === 'edit' ? (
                <TextField
                  fullWidth
                  multiline
                  rows={12}
                  label="Article Content"
                  value={editedContent}
                  onChange={(e) => setEditedContent(e.target.value)}
                  sx={{ mb: 2 }}
                />
              ) : (
                <Paper sx={{ p: 2, mb: 2, maxHeight: 400, overflow: 'auto' }}>
                  <Typography variant="body2" style={{ whiteSpace: 'pre-wrap' }}>
                    {selectedSuggestion.content}
                  </Typography>
                </Paper>
              )}

              {(actionType === 'approve' || actionType === 'reject') && (
                <TextField
                  fullWidth
                  multiline
                  rows={3}
                  label="Feedback (optional)"
                  value={feedback}
                  onChange={(e) => setFeedback(e.target.value)}
                  placeholder="Add any comments about this suggestion..."
                />
              )}

              <Divider sx={{ my: 2 }} />
              
              <Typography variant="subtitle2" gutterBottom>
                Ticket Analysis
              </Typography>
              <Typography variant="body2" color="text.secondary">
                Based on {selectedSuggestion.ticket_cluster.count} similar tickets with patterns: {' '}
                {selectedSuggestion.ticket_cluster.common_patterns.join(', ')}
              </Typography>
            </Box>
          )}
        </DialogContent>
        
        <DialogActions>
          <Button onClick={() => setDialogOpen(false)}>
            Cancel
          </Button>
          {actionType !== 'view' && (
            <Button 
              onClick={handleConfirmAction}
              variant="contained"
              disabled={processing}
              color={actionType === 'reject' ? 'error' : 'primary'}
            >
              {processing ? <CircularProgress size={20} /> : 
                actionType === 'edit' ? 'Save Changes' :
                actionType === 'approve' ? 'Approve' : 'Reject'
              }
            </Button>
          )}
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default KBSuggestions;
