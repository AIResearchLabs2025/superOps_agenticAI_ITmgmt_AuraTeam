import React, { useState, useEffect } from 'react';
import {
  Box,
  Card,
  CardContent,
  Typography,
  TextField,
  Grid,
  Chip,
  IconButton,
  List,
  ListItem,
  ListItemText,
  ListItemButton,
  Divider,
  CircularProgress,
  InputAdornment,
  Button,
  useTheme,
} from '@mui/material';
import {
  Search as SearchIcon,
  Article as ArticleIcon,
  Category as CategoryIcon,
  AccessTime as TimeIcon,
  Person as PersonIcon,
  Refresh as RefreshIcon,
  Add as AddIcon,
} from '@mui/icons-material';
import { apiWithFallback } from '../../services/api';
import { useSnackbar } from 'notistack';

const KnowledgeBase = () => {
  const theme = useTheme();
  const { enqueueSnackbar } = useSnackbar();

  const [loading, setLoading] = useState(true);
  const [articles, setArticles] = useState([]);
  const [filteredArticles, setFilteredArticles] = useState([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('all');
  const [selectedArticle, setSelectedArticle] = useState(null);

  // Load articles
  const loadArticles = async () => {
    try {
      setLoading(true);
      const response = await apiWithFallback.getArticles();
      const articleData = response.articles || response;
      // Ensure articleData is an array
      const articlesArray = Array.isArray(articleData) ? articleData : [];
      setArticles(articlesArray);
      setFilteredArticles(articlesArray);
      if (articlesArray.length > 0 && !selectedArticle) {
        setSelectedArticle(articlesArray[0]);
      }
    } catch (error) {
      enqueueSnackbar('Failed to load knowledge base articles', { variant: 'error' });
      console.error('Load articles error:', error);
      // Set empty arrays on error
      setArticles([]);
      setFilteredArticles([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadArticles();
  }, []);

  // Filter articles based on search and category
  useEffect(() => {
    let filtered = articles;

    // Search filter
    if (searchTerm) {
      filtered = filtered.filter(article =>
        article.title && article.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
        article.content && article.content.toLowerCase().includes(searchTerm.toLowerCase()) ||
        (Array.isArray(article.tags) && article.tags.some(tag => tag.toLowerCase().includes(searchTerm.toLowerCase())))
      );
    }

    // Category filter
    if (selectedCategory !== 'all') {
      filtered = filtered.filter(article => article.category === selectedCategory);
    }

    setFilteredArticles(filtered);
  }, [articles, searchTerm, selectedCategory]);

  // Get unique categories
  const categories = ['all', ...new Set(
    Array.isArray(articles) && articles.length > 0 
      ? articles.map(article => article.category).filter(Boolean)
      : []
  )];

  const formatDate = (dateString) => {
    const date = new Date(dateString);
    return date.toLocaleDateString();
  };

  const highlightSearchTerm = (text, term) => {
    if (!term) return text;
    const regex = new RegExp(`(${term})`, 'gi');
    return text.replace(regex, '<mark>$1</mark>');
  };

  if (loading) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '60vh' }}>
        <CircularProgress />
      </Box>
    );
  }

  return (
    <Box className="fade-in">
      {/* Header */}
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Box>
          <Typography variant="h4" sx={{ fontWeight: 600, mb: 1 }}>
            Knowledge Base
          </Typography>
          <Typography variant="body1" color="text.secondary">
            Search and browse help articles and documentation
          </Typography>
        </Box>
        <Box sx={{ display: 'flex', gap: 1 }}>
          <IconButton onClick={loadArticles}>
            <RefreshIcon />
          </IconButton>
          <Button variant="contained" startIcon={<AddIcon />}>
            Add Article
          </Button>
        </Box>
      </Box>

      {/* Search and Filter */}
      <Card sx={{ mb: 3 }}>
        <CardContent>
          <Grid container spacing={2} alignItems="center">
            <Grid item xs={12} md={8}>
              <TextField
                fullWidth
                variant="outlined"
                placeholder="Search articles, topics, or keywords..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                InputProps={{
                  startAdornment: (
                    <InputAdornment position="start">
                      <SearchIcon />
                    </InputAdornment>
                  ),
                }}
              />
            </Grid>
            <Grid item xs={12} md={4}>
              <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap' }}>
                {categories.map((category) => (
                  <Chip
                    key={category}
                    label={category === 'all' ? 'All Categories' : category}
                    variant={selectedCategory === category ? 'filled' : 'outlined'}
                    color={selectedCategory === category ? 'primary' : 'default'}
                    onClick={() => setSelectedCategory(category)}
                    sx={{ textTransform: 'capitalize' }}
                  />
                ))}
              </Box>
            </Grid>
          </Grid>
        </CardContent>
      </Card>

      {/* Main Content */}
      <Grid container spacing={3}>
        {/* Article List */}
        <Grid item xs={12} md={4}>
          <Card sx={{ height: 'calc(100vh - 300px)', overflow: 'hidden' }}>
            <CardContent sx={{ p: 0 }}>
              <Box sx={{ p: 2, borderBottom: `1px solid ${theme.palette.divider}` }}>
                <Typography variant="h6" sx={{ fontWeight: 600 }}>
                  Articles ({filteredArticles.length})
                </Typography>
              </Box>
              
              <List sx={{ overflow: 'auto', height: 'calc(100% - 80px)' }}>
                {filteredArticles.map((article, index) => (
                  <React.Fragment key={article.id}>
                    <ListItemButton
                      selected={selectedArticle?.id === article.id}
                      onClick={() => setSelectedArticle(article)}
                      sx={{ py: 2 }}
                    >
                      <ListItemText
                        primary={
                          <Typography
                            variant="subtitle2"
                            sx={{ fontWeight: 600, mb: 0.5 }}
                            dangerouslySetInnerHTML={{
                              __html: highlightSearchTerm(article.title, searchTerm)
                            }}
                          />
                        }
                        secondary={
                          <Box>
                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 0.5 }}>
                              <CategoryIcon sx={{ fontSize: 14 }} />
                              <Typography variant="caption" color="text.secondary">
                                {article.category}
                              </Typography>
                            </Box>
                            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                              <TimeIcon sx={{ fontSize: 14 }} />
                              <Typography variant="caption" color="text.secondary">
                                {formatDate(article.updated_at)}
                              </Typography>
                            </Box>
                            <Box sx={{ display: 'flex', gap: 0.5, flexWrap: 'wrap' }}>
                              {Array.isArray(article.tags) && article.tags.slice(0, 3).map((tag) => (
                                <Chip
                                  key={tag}
                                  label={tag}
                                  size="small"
                                  variant="outlined"
                                  sx={{ fontSize: '0.7rem', height: 20 }}
                                />
                              ))}
                              {Array.isArray(article.tags) && article.tags.length > 3 && (
                                <Typography variant="caption" color="text.secondary">
                                  +{article.tags.length - 3} more
                                </Typography>
                              )}
                            </Box>
                          </Box>
                        }
                      />
                    </ListItemButton>
                    {index < filteredArticles.length - 1 && <Divider />}
                  </React.Fragment>
                ))}

                {filteredArticles.length === 0 && (
                  <ListItem>
                    <ListItemText
                      primary={
                        <Typography variant="body1" color="text.secondary" sx={{ textAlign: 'center', py: 4 }}>
                          No articles found matching your search criteria
                        </Typography>
                      }
                    />
                  </ListItem>
                )}
              </List>
            </CardContent>
          </Card>
        </Grid>

        {/* Article Content */}
        <Grid item xs={12} md={8}>
          <Card sx={{ height: 'calc(100vh - 300px)' }}>
            {selectedArticle ? (
              <CardContent sx={{ height: '100%', overflow: 'auto' }}>
                {/* Article Header */}
                <Box sx={{ mb: 3, pb: 2, borderBottom: `1px solid ${theme.palette.divider}` }}>
                  <Typography variant="h5" sx={{ fontWeight: 600, mb: 2 }}>
                    {selectedArticle.title}
                  </Typography>
                  
                  <Grid container spacing={2} sx={{ mb: 2 }}>
                    <Grid item>
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <PersonIcon sx={{ fontSize: 16, color: 'text.secondary' }} />
                        <Typography variant="body2" color="text.secondary">
                          By {selectedArticle.author}
                        </Typography>
                      </Box>
                    </Grid>
                    <Grid item>
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <TimeIcon sx={{ fontSize: 16, color: 'text.secondary' }} />
                        <Typography variant="body2" color="text.secondary">
                          Updated {formatDate(selectedArticle.updated_at)}
                        </Typography>
                      </Box>
                    </Grid>
                    <Grid item>
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <CategoryIcon sx={{ fontSize: 16, color: 'text.secondary' }} />
                        <Typography variant="body2" color="text.secondary">
                          {selectedArticle.category}
                        </Typography>
                      </Box>
                    </Grid>
                  </Grid>

                  <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap' }}>
                    {Array.isArray(selectedArticle.tags) && selectedArticle.tags.map((tag) => (
                      <Chip
                        key={tag}
                        label={tag}
                        size="small"
                        variant="outlined"
                        color="primary"
                      />
                    ))}
                  </Box>
                </Box>

                {/* Article Content */}
                <Box sx={{ typography: 'body1', lineHeight: 1.7 }}>
                  <div dangerouslySetInnerHTML={{ 
                    __html: selectedArticle.content.replace(/\n/g, '<br/>')
                  }} />
                </Box>

                {/* Article Footer */}
                <Box sx={{ mt: 4, pt: 2, borderTop: `1px solid ${theme.palette.divider}` }}>
                  <Typography variant="body2" color="text.secondary">
                    Was this article helpful? Let us know how we can improve our documentation.
                  </Typography>
                  <Box sx={{ mt: 2, display: 'flex', gap: 1 }}>
                    <Button variant="outlined" size="small">
                      👍 Helpful
                    </Button>
                    <Button variant="outlined" size="small">
                      👎 Not Helpful
                    </Button>
                    <Button variant="outlined" size="small">
                      💬 Feedback
                    </Button>
                  </Box>
                </Box>
              </CardContent>
            ) : (
              <CardContent>
                <Box sx={{ textAlign: 'center', py: 8 }}>
                  <ArticleIcon sx={{ fontSize: 64, color: 'text.secondary', mb: 2 }} />
                  <Typography variant="h6" color="text.secondary" sx={{ mb: 1 }}>
                    Select an Article
                  </Typography>
                  <Typography variant="body2" color="text.secondary">
                    Choose an article from the list to view its content
                  </Typography>
                </Box>
              </CardContent>
            )}
          </Card>
        </Grid>
      </Grid>
    </Box>
  );
};

export default KnowledgeBase;
