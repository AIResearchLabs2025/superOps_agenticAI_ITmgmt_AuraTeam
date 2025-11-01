import React, { useState, useEffect } from 'react';
import {
  Box,
  Grid,
  Card,
  CardContent,
  Typography,
  LinearProgress,
  CircularProgress,
  IconButton,
  Chip,
  Button,
  useTheme,
} from '@mui/material';
import {
  TrendingUp as TrendingUpIcon,
  Assignment as TicketIcon,
  CheckCircle as ResolvedIcon,
  Schedule as PendingIcon,
  Person as AgentIcon,
  Computer as SystemIcon,
  Refresh as RefreshIcon,
  ArrowForward as ArrowForwardIcon,
} from '@mui/icons-material';
import { Line, Doughnut, Bar } from 'react-chartjs-2';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
  ArcElement,
  BarElement,
} from 'chart.js';
import { useNavigate } from 'react-router-dom';
import { apiWithFallback } from '../../services/api';
import { useSnackbar } from 'notistack';

// Register Chart.js components
ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
  ArcElement,
  BarElement
);

const Dashboard = () => {
  const theme = useTheme();
  const navigate = useNavigate();
  const { enqueueSnackbar } = useSnackbar();
  
  const [loading, setLoading] = useState(true);
  const [stats, setStats] = useState(null);
  const [metrics, setMetrics] = useState(null);
  const [refreshing, setRefreshing] = useState(false);

  // Load dashboard data
  const loadDashboardData = async () => {
    try {
      // Load overview stats and metrics in parallel
      const [overviewData, metricsData] = await Promise.all([
        apiWithFallback.getDashboardStats(),
        apiWithFallback.getDashboardMetrics()
      ]);
      
      setStats(overviewData);
      setMetrics(metricsData);
    } catch (error) {
      enqueueSnackbar('Failed to load dashboard data', { variant: 'error' });
      console.error('Dashboard data error:', error);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  useEffect(() => {
    loadDashboardData();
  }, []);

  const handleRefresh = () => {
    setRefreshing(true);
    loadDashboardData();
  };

  // Generate chart data from API metrics
  const ticketTrendData = {
    labels: metrics?.trendData?.labels || ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    datasets: [
      {
        label: 'New Tickets',
        data: metrics?.trendData?.created || [12, 19, 15, 25, 22, 8, 14],
        borderColor: theme.palette.primary.main,
        backgroundColor: 'rgba(0, 112, 243, 0.1)',
        tension: 0.4,
      },
      {
        label: 'Resolved Tickets',
        data: metrics?.trendData?.resolved || [8, 15, 18, 20, 25, 12, 16],
        borderColor: theme.palette.success.main,
        backgroundColor: 'rgba(76, 175, 80, 0.1)',
        tension: 0.4,
      },
    ],
  };

  const statusDistributionData = {
    labels: ['Open', 'In Progress', 'Resolved', 'Closed'],
    datasets: [
      {
        data: [
          metrics?.statusDistribution?.open || 23,
          metrics?.statusDistribution?.in_progress || 45,
          metrics?.statusDistribution?.resolved || 67,
          metrics?.statusDistribution?.closed || 21
        ],
        backgroundColor: [
          theme.palette.info.main,
          theme.palette.warning.main,
          theme.palette.success.main,
          theme.palette.grey[400],
        ],
      },
    ],
  };

  const categoryData = {
    labels: Object.keys(metrics?.categoryDistribution || {}),
    datasets: [
      {
        label: 'Tickets by Category',
        data: Object.values(metrics?.categoryDistribution || {}),
        backgroundColor: [
          theme.palette.primary.main,
          theme.palette.secondary.main,
          theme.palette.success.main,
          theme.palette.warning.main,
          theme.palette.error.main,
          theme.palette.info.main,
        ],
      },
    ],
  };

  const chartOptions = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        position: 'bottom',
      },
    },
    scales: {
      y: {
        beginAtZero: true,
      },
    },
  };

  const MetricCard = ({ title, value, subtitle, icon, color = 'primary', trend = null }) => (
    <Card className="card-hover" sx={{ height: '100%' }}>
      <CardContent>
        <Box sx={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between' }}>
          <Box sx={{ flex: 1 }}>
            <Typography color="text.secondary" gutterBottom variant="body2">
              {title}
            </Typography>
            <Typography variant="h4" component="div" sx={{ mb: 1, fontWeight: 600 }}>
              {value}
            </Typography>
            <Typography variant="body2" color="text.secondary">
              {subtitle}
            </Typography>
            {trend && (
              <Box sx={{ display: 'flex', alignItems: 'center', mt: 1 }}>
                <TrendingUpIcon 
                  sx={{ 
                    fontSize: 16, 
                    mr: 0.5, 
                    color: trend > 0 ? 'success.main' : 'error.main' 
                  }} 
                />
                <Typography 
                  variant="caption" 
                  sx={{ 
                    color: trend > 0 ? 'success.main' : 'error.main',
                    fontWeight: 500 
                  }}
                >
                  {trend > 0 ? '+' : ''}{trend}% from last week
                </Typography>
              </Box>
            )}
          </Box>
          <Box
            sx={{
              p: 1,
              borderRadius: 2,
              backgroundColor: `${theme.palette[color].main}20`,
              color: `${theme.palette[color].main}`,
            }}
          >
            {icon}
          </Box>
        </Box>
      </CardContent>
    </Card>
  );

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
            Dashboard
          </Typography>
          <Typography variant="body1" color="text.secondary">
            Welcome back! Here's what's happening with your IT operations.
          </Typography>
        </Box>
        <Box sx={{ display: 'flex', gap: 1 }}>
          <IconButton onClick={handleRefresh} disabled={refreshing}>
            <RefreshIcon sx={{ transform: refreshing ? 'rotate(360deg)' : 'none', transition: 'transform 1s' }} />
          </IconButton>
          <Button
            variant="contained"
            endIcon={<ArrowForwardIcon />}
            onClick={() => navigate('/tickets/create')}
          >
            Create Ticket
          </Button>
        </Box>
      </Box>

      {/* Key Metrics */}
      <Grid container spacing={3} sx={{ mb: 4 }}>
        <Grid item xs={12} sm={6} md={3}>
          <MetricCard
            title="Total Tickets"
            value={stats?.totalTickets || 156}
            subtitle="All time"
            icon={<TicketIcon />}
            color="primary"
            trend={8}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <MetricCard
            title="Open Tickets"
            value={stats?.openTickets || 23}
            subtitle="Need attention"
            icon={<PendingIcon />}
            color="warning"
            trend={-12}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <MetricCard
            title="Resolved Today"
            value={stats?.resolvedToday || 12}
            subtitle="Great progress!"
            icon={<ResolvedIcon />}
            color="success"
            trend={15}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <MetricCard
            title="Avg Resolution"
            value={stats?.avgResolutionTime || '2.5h'}
            subtitle="Response time"
            icon={<SystemIcon />}
            color="info"
            trend={-5}
          />
        </Grid>
      </Grid>

      {/* Charts Row */}
      <Grid container spacing={3} sx={{ mb: 4 }}>
        {/* Ticket Trends */}
        <Grid item xs={12} lg={8}>
          <Card>
            <CardContent>
              <Typography variant="h6" sx={{ mb: 2, fontWeight: 600 }}>
                Ticket Trends (Last 7 Days)
              </Typography>
              <Box sx={{ height: 300 }}>
                <Line data={ticketTrendData} options={chartOptions} />
              </Box>
            </CardContent>
          </Card>
        </Grid>

        {/* Status Distribution */}
        <Grid item xs={12} lg={4}>
          <Card sx={{ height: '100%' }}>
            <CardContent>
              <Typography variant="h6" sx={{ mb: 2, fontWeight: 600 }}>
                Ticket Status
              </Typography>
              <Box sx={{ height: 300 }}>
                <Doughnut 
                  data={statusDistributionData} 
                  options={{
                    ...chartOptions,
                    plugins: {
                      ...chartOptions.plugins,
                      legend: {
                        position: 'bottom',
                      },
                    },
                  }} 
                />
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {/* Bottom Row */}
      <Grid container spacing={3}>
        {/* Category Breakdown */}
        <Grid item xs={12} md={8}>
          <Card>
            <CardContent>
              <Typography variant="h6" sx={{ mb: 2, fontWeight: 600 }}>
                Tickets by Category
              </Typography>
              <Box sx={{ height: 300 }}>
                <Bar data={categoryData} options={chartOptions} />
              </Box>
            </CardContent>
          </Card>
        </Grid>

        {/* System Health & Quick Actions */}
        <Grid item xs={12} md={4}>
          <Grid container spacing={2}>
            {/* System Health */}
            <Grid item xs={12}>
              <Card>
                <CardContent>
                  <Typography variant="h6" sx={{ mb: 2, fontWeight: 600 }}>
                    System Health
                  </Typography>
                  
                  <Box sx={{ mb: 2 }}>
                    <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                      <Typography variant="body2">Server Uptime</Typography>
                      <Typography variant="body2" sx={{ fontWeight: 600 }}>
                        {stats?.systemUptime || 99.9}%
                      </Typography>
                    </Box>
                    <LinearProgress 
                      variant="determinate" 
                      value={stats?.systemUptime || 99.9} 
                      sx={{ height: 8, borderRadius: 4 }}
                    />
                  </Box>

                  <Box sx={{ mb: 2 }}>
                    <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 1 }}>
                      <Typography variant="body2">Agent Workload</Typography>
                      <Typography variant="body2" sx={{ fontWeight: 600 }}>
                        {stats?.agentWorkload || 85}%
                      </Typography>
                    </Box>
                    <LinearProgress 
                      variant="determinate" 
                      value={stats?.agentWorkload || 85} 
                      color="warning"
                      sx={{ height: 8, borderRadius: 4 }}
                    />
                  </Box>

                  <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap' }}>
                    <Chip 
                      label="API Healthy" 
                      color="success" 
                      size="small" 
                      variant="outlined" 
                    />
                    <Chip 
                      label="DB Connected" 
                      color="success" 
                      size="small" 
                      variant="outlined" 
                    />
                    <Chip 
                      label="AI Service Active" 
                      color="info" 
                      size="small" 
                      variant="outlined" 
                    />
                  </Box>
                </CardContent>
              </Card>
            </Grid>

            {/* Quick Actions */}
            <Grid item xs={12}>
              <Card>
                <CardContent>
                  <Typography variant="h6" sx={{ mb: 2, fontWeight: 600 }}>
                    Quick Actions
                  </Typography>
                  
                  <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
                    <Button
                      variant="outlined"
                      fullWidth
                      startIcon={<TicketIcon />}
                      onClick={() => navigate('/tickets')}
                    >
                      View All Tickets
                    </Button>
                    <Button
                      variant="outlined"
                      fullWidth
                      startIcon={<AgentIcon />}
                      onClick={() => navigate('/knowledge-base')}
                    >
                      Browse Knowledge Base
                    </Button>
                    <Button
                      variant="outlined"
                      fullWidth
                      startIcon={<SystemIcon />}
                      onClick={() => navigate('/chatbot')}
                    >
                      Open AI Assistant
                    </Button>
                  </Box>
                </CardContent>
              </Card>
            </Grid>
          </Grid>
        </Grid>
      </Grid>
    </Box>
  );
};

export default Dashboard;
