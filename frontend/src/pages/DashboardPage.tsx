/**
 * Dashboard Page - Main user interface
 */
import React, { useEffect, useState } from "react";
import {
  Box,
  Container,
  Grid,
  Card,
  CardContent,
  Typography,
  Button,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Chip,
  CircularProgress,
  Stack,
} from "@mui/material";
import { CloudUpload, CheckCircle, History } from "@mui/icons-material";
import { useNavigate } from "react-router-dom";
import { apiClient } from "../api/client";
import { useAuthStore } from "../store/authStore";

const DeploymentTypeCard = ({ type, icon, label, color }: any) => (
  <Card
    sx={{
      cursor: "pointer",
      transition: "transform 0.2s",
      "&:hover": { transform: "translateY(-4px)" },
    }}
    onClick={() => window.location.href = `/deployments/create/${type}`}
  >
    <CardContent sx={{ textAlign: "center", py: 4 }}>
      <Box sx={{ fontSize: 48, mb: 2 }}>{icon}</Box>
      <Typography variant="h6">{label}</Typography>
      <Typography variant="body2" color="textSecondary">
        Deploy {label} instances
      </Typography>
    </CardContent>
  </Card>
);

const StatusChip = ({ status }: { status: string }) => {
  const statusConfig: any = {
    draft: { color: "default", label: "Draft" },
    submitted: { color: "info", label: "Submitted" },
    approved: { color: "success", label: "Approved" },
    deploying: { color: "warning", label: "Deploying" },
    deployed: { color: "success", label: "Deployed" },
    failed: { color: "error", label: "Failed" },
  };

  const config = statusConfig[status] || statusConfig.draft;
  return <Chip label={config.label} color={config.color} size="small" />;
};

export default function DashboardPage() {
  const navigate = useNavigate();
  const user = useAuthStore((state) => state.user);
  const [deployments, setDeployments] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [stats, setStats] = useState({
    total: 0,
    deployed: 0,
    pending: 0,
    failed: 0,
  });

  useEffect(() => {
    fetchDeployments();
  }, []);

  const fetchDeployments = async () => {
    try {
      setLoading(true);
      const response = await apiClient.listDeployments({ limit: 10 });
      setDeployments(response.items || []);

      // Calculate stats
      const statusCounts: any = {};
      response.items?.forEach((d: any) => {
        statusCounts[d.status] = (statusCounts[d.status] || 0) + 1;
      });

      setStats({
        total: response.total || 0,
        deployed: statusCounts.deployed || 0,
        pending: (statusCounts.submitted || 0) + (statusCounts.draft || 0),
        failed: statusCounts.failed || 0,
      });
    } catch (error) {
      console.error("Failed to fetch deployments:", error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <Container maxWidth="lg" sx={{ py: 4 }}>
      {/* Header */}
      <Box sx={{ mb: 4 }}>
        <Typography variant="h4" sx={{ fontWeight: "bold", mb: 1 }}>
          Welcome, {user?.full_name || user?.username}!
        </Typography>
        <Typography variant="body1" color="textSecondary">
          Manage your GCP deployments with ease
        </Typography>
      </Box>

      {/* Stats */}
      <Grid container spacing={2} sx={{ mb: 4 }}>
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Typography color="textSecondary" gutterBottom>
                Total Deployments
              </Typography>
              <Typography variant="h5">{stats.total}</Typography>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Typography color="textSecondary" gutterBottom>
                Deployed
              </Typography>
              <Typography variant="h5" sx={{ color: "green" }}>
                {stats.deployed}
              </Typography>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Typography color="textSecondary" gutterBottom>
                Pending
              </Typography>
              <Typography variant="h5" sx={{ color: "orange" }}>
                {stats.pending}
              </Typography>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Typography color="textSecondary" gutterBottom>
                Failed
              </Typography>
              <Typography variant="h5" sx={{ color: "red" }}>
                {stats.failed}
              </Typography>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {/* Deployment Types */}
      <Typography variant="h6" sx={{ fontWeight: "bold", mb: 2 }}>
        Create New Deployment
      </Typography>
      <Grid container spacing={2} sx={{ mb: 4 }}>
        <Grid item xs={12} sm={6} md={4}>
          <DeploymentTypeCard
            type="gce"
            icon="💻"
            label="GCE VMs"
            color="primary"
          />
        </Grid>
        <Grid item xs={12} sm={6} md={4}>
          <DeploymentTypeCard
            type="gke"
            icon="🐳"
            label="GKE Clusters"
            color="info"
          />
        </Grid>
        <Grid item xs={12} sm={6} md={4}>
          <DeploymentTypeCard
            type="cloud-sql"
            icon="🗄️"
            label="Cloud SQL"
            color="success"
          />
        </Grid>
      </Grid>

      {/* Recent Deployments */}
      <Typography variant="h6" sx={{ fontWeight: "bold", mb: 2 }}>
        Recent Deployments
      </Typography>

      {loading ? (
        <Box sx={{ display: "flex", justifyContent: "center", py: 4 }}>
          <CircularProgress />
        </Box>
      ) : deployments.length === 0 ? (
        <Card sx={{ p: 3, textAlign: "center" }}>
          <Typography color="textSecondary">
            No deployments yet. Create one to get started!
          </Typography>
        </Card>
      ) : (
        <TableContainer component={Card}>
          <Table>
            <TableHead>
              <TableRow sx={{ backgroundColor: "#f5f5f5" }}>
                <TableCell>Request ID</TableCell>
                <TableCell>Name</TableCell>
                <TableCell>Type</TableCell>
                <TableCell>Region</TableCell>
                <TableCell>Status</TableCell>
                <TableCell>Cost/Month</TableCell>
                <TableCell>Actions</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {deployments.map((deployment) => (
                <TableRow key={deployment.id} hover>
                  <TableCell sx={{ fontWeight: "bold" }}>
                    {deployment.request_id}
                  </TableCell>
                  <TableCell>{deployment.name}</TableCell>
                  <TableCell>
                    <Chip
                      label={deployment.deployment_type}
                      size="small"
                      variant="outlined"
                    />
                  </TableCell>
                  <TableCell>{deployment.region}</TableCell>
                  <TableCell>
                    <StatusChip status={deployment.status} />
                  </TableCell>
                  <TableCell>${deployment.estimated_cost_monthly}/mo</TableCell>
                  <TableCell>
                    <Button
                      size="small"
                      onClick={() => navigate(`/deployments/${deployment.id}`)}
                    >
                      View
                    </Button>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      )}
    </Container>
  );
}
