import React from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Drawer,
  List,
  ListItem,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  Box,
  Typography,
  Divider,
  Collapse,
  Badge,
  useTheme,
} from '@mui/material';
import {
  Dashboard as DashboardIcon,
  ConfirmationNumber as TicketIcon,
  Add as AddIcon,
  MenuBook as KnowledgeBaseIcon,
  Chat as ChatIcon,
  Analytics as AnalyticsIcon,
  Computer as InfrastructureIcon,
  Security as SecurityIcon,
  ExpandLess,
  ExpandMore,
  Assignment as AssignmentIcon,
  Search as SearchIcon,
  Article as ArticleIcon,
  SmartToy as BotIcon,
} from '@mui/icons-material';

const Sidebar = ({ open, collapsed, isMobile, onClose, currentPath }) => {
  const theme = useTheme();
  const navigate = useNavigate();
  const [expandedSection, setExpandedSection] = React.useState(null);

  const drawerWidth = collapsed ? 64 : 280;

  const handleNavigation = (path) => {
    navigate(path);
    if (isMobile) {
      onClose();
    }
  };

  const handleSectionToggle = (section) => {
    setExpandedSection(expandedSection === section ? null : section);
  };

  const menuItems = [
    {
      title: 'Dashboard',
      icon: <DashboardIcon />,
      path: '/dashboard',
      badge: null,
    },
    {
      title: 'Service Desk',
      icon: <TicketIcon />,
      path: null,
      badge: 12,
      children: [
        {
          title: 'All Tickets',
          icon: <AssignmentIcon />,
          path: '/tickets',
          badge: 8,
        },
        {
          title: 'Create Ticket',
          icon: <AddIcon />,
          path: '/tickets/create',
          badge: null,
        },
      ],
    },
    {
      title: 'Knowledge Base',
      icon: <KnowledgeBaseIcon />,
      path: null,
      badge: null,
      children: [
        {
          title: 'Search Articles',
          icon: <SearchIcon />,
          path: '/knowledge-base',
          badge: null,
        },
        {
          title: 'Browse Articles',
          icon: <ArticleIcon />,
          path: '/knowledge-base',
          badge: null,
        },
        {
          title: 'AI Suggestions',
          icon: <BotIcon />,
          path: '/knowledge-base/suggestions',
          badge: 3,
        },
      ],
    },
    {
      title: 'AI Chatbot',
      icon: <ChatIcon />,
      path: '/chatbot',
      badge: null,
    },
  ];

  const secondaryMenuItems = [
    {
      title: 'Analytics',
      icon: <AnalyticsIcon />,
      path: '/analytics',
      badge: null,
      disabled: true,
    },
    {
      title: 'Infrastructure',
      icon: <InfrastructureIcon />,
      path: '/infrastructure',
      badge: null,
      disabled: true,
    },
    {
      title: 'Security',
      icon: <SecurityIcon />,
      path: '/security',
      badge: 3,
      disabled: true,
    },
  ];

  const isActive = (path) => {
    if (!path) return false;
    return currentPath === path || currentPath.startsWith(path + '/');
  };

  const renderMenuItem = (item, isChild = false) => {
    const active = isActive(item.path);
    
    return (
      <ListItem
        key={item.title}
        disablePadding
        sx={{
          display: 'block',
          pl: isChild ? 2 : 0,
        }}
      >
        <ListItemButton
          onClick={() => {
            if (item.path) {
              handleNavigation(item.path);
            } else if (item.children) {
              handleSectionToggle(item.title);
            }
          }}
          disabled={item.disabled}
          sx={{
            minHeight: 48,
            justifyContent: collapsed ? 'center' : 'flex-start',
            px: 2.5,
            py: 1,
            mx: 1,
            mb: 0.5,
            borderRadius: 2,
            backgroundColor: active ? 'rgba(255, 255, 255, 0.15)' : 'transparent',
            color: active ? '#ffffff' : '#ffffff',
            '&:hover': {
              backgroundColor: 'rgba(255, 255, 255, 0.1)',
              color: '#ffffff',
            },
            '&.Mui-disabled': {
              opacity: 0.5,
              color: 'rgba(255, 255, 255, 0.6)',
            },
          }}
        >
          <ListItemIcon
            sx={{
              minWidth: 0,
              mr: collapsed ? 0 : 3,
              justifyContent: 'center',
              color: 'inherit',
            }}
          >
            {item.badge && !collapsed ? (
              <Badge badgeContent={item.badge} color="error" variant="dot">
                {item.icon}
              </Badge>
            ) : (
              item.icon
            )}
          </ListItemIcon>
          
          {!collapsed && (
            <>
              <ListItemText
                primary={item.title}
                primaryTypographyProps={{
                  fontSize: '0.875rem',
                  fontWeight: active ? 600 : 400,
                  color: '#ffffff',
                }}
                sx={{
                  '& .MuiListItemText-primary': {
                    color: '#ffffff !important',
                  },
                }}
              />
              
              {item.badge && (
                <Badge
                  badgeContent={item.badge}
                  color="error"
                  sx={{
                    '& .MuiBadge-badge': {
                      fontSize: '0.75rem',
                      height: 18,
                      minWidth: 18,
                    },
                  }}
                />
              )}
              
              {item.children && (
                expandedSection === item.title ? <ExpandLess /> : <ExpandMore />
              )}
            </>
          )}
        </ListItemButton>
      </ListItem>
    );
  };

  const drawerContent = (
    <Box sx={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      {/* Logo Section */}
      {!collapsed && (
        <Box sx={{ p: 3, pb: 2 }}>
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, mb: 1 }}>
            <Box
              sx={{
                width: 40,
                height: 40,
                borderRadius: '10px',
                background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: 'white',
                fontWeight: 'bold',
                fontSize: '1.25rem',
              }}
            >
              A
            </Box>
            <Box>
              <Typography
                variant="h6"
                sx={{
                  color: 'white',
                  fontWeight: 600,
                  fontSize: '1.1rem',
                  lineHeight: 1.2,
                }}
              >
                Aura
              </Typography>
              <Typography
                variant="caption"
                sx={{
                  color: 'rgba(255, 255, 255, 0.7)',
                  fontSize: '0.75rem',
                }}
              >
                IT Management Suite
              </Typography>
            </Box>
          </Box>
        </Box>
      )}

      {/* Main Navigation */}
      <Box sx={{ flex: 1, overflow: 'auto' }}>
        <List sx={{ px: 1 }}>
          {menuItems.map((item) => (
            <React.Fragment key={item.title}>
              {renderMenuItem(item)}
              
              {/* Collapsible children */}
              {item.children && !collapsed && (
                <Collapse in={expandedSection === item.title} timeout="auto" unmountOnExit>
                  <List component="div" disablePadding>
                    {item.children.map((child) => renderMenuItem(child, true))}
                  </List>
                </Collapse>
              )}
            </React.Fragment>
          ))}
        </List>

        {/* Divider */}
        {!collapsed && (
          <Divider sx={{ mx: 2, my: 2, borderColor: 'rgba(255, 255, 255, 0.2)' }} />
        )}

        {/* Secondary Navigation */}
        <List sx={{ px: 1 }}>
          {!collapsed && (
            <ListItem>
              <Typography
                variant="overline"
                sx={{
                  color: '#ffffff',
                  fontSize: '0.75rem',
                  fontWeight: 600,
                  letterSpacing: '0.1em',
                  px: 1,
                }}
              >
                ADVANCED FEATURES
              </Typography>
            </ListItem>
          )}
          
          {secondaryMenuItems.map((item) => renderMenuItem(item))}
        </List>
      </Box>

      {/* Footer */}
      {!collapsed && (
        <Box sx={{ p: 2, mt: 'auto' }}>
          <Box
            sx={{
              p: 2,
              backgroundColor: 'rgba(255, 255, 255, 0.1)',
              borderRadius: 2,
              textAlign: 'center',
            }}
          >
            <BotIcon sx={{ color: 'rgba(255, 255, 255, 0.8)', mb: 1 }} />
            <Typography
              variant="caption"
              sx={{
                color: 'rgba(255, 255, 255, 0.8)',
                display: 'block',
                fontSize: '0.75rem',
              }}
            >
              AI Assistant Ready
            </Typography>
            <Typography
              variant="caption"
              sx={{
                color: 'rgba(255, 255, 255, 0.6)',
                fontSize: '0.7rem',
              }}
            >
              Click chat to start
            </Typography>
          </Box>
        </Box>
      )}
    </Box>
  );

  if (isMobile) {
    return (
      <Drawer
        anchor="left"
        open={open}
        onClose={onClose}
        ModalProps={{
          keepMounted: true, // Better open performance on mobile
        }}
        sx={{
          '& .MuiDrawer-paper': {
            width: drawerWidth,
            backgroundColor: '#354a5f', // SAP Fiori shell background
            color: 'white',
            borderRight: 'none',
          },
        }}
      >
        {drawerContent}
      </Drawer>
    );
  }

  return (
    <Drawer
      variant="permanent"
      sx={{
        width: drawerWidth,
        flexShrink: 0,
        '& .MuiDrawer-paper': {
          width: drawerWidth,
          boxSizing: 'border-box',
          backgroundColor: '#354a5f', // SAP Fiori shell background
          color: 'white',
          borderRight: 'none',
          transition: theme.transitions.create('width', {
            easing: theme.transitions.easing.sharp,
            duration: theme.transitions.duration.enteringScreen,
          }),
        },
      }}
    >
      {drawerContent}
    </Drawer>
  );
};

export default Sidebar;
