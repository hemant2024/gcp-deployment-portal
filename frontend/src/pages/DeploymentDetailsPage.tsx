/**
 * Deployment Details Page
 */
import React, { useEffect, useState } from "react";
import { useParams, useNavigate } from "react-router-dom";
import {
  Box,
  Container,
  Card,
  CardContent,
  Typography,
  Button,
  CircularProgress,
  Alert,
  Chip,
  Grid,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
} from "@mui/material";
import { apiClient } from "../api/client";

export default function DeploymentDetailsPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [deployment, setDeployment] = useState<any>(null);
  const [approvals, setApprovals] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchDeployment();
  }, [id]);

  const fetchDeployment = async () => {
    try {
      const response = await apiClient.getDeployment(Number(id));
      setDeployment(response);
      const approvalsResponse = await apiClient.getDeploymentApprovals(Number(id));
      setApprovals(approvalsResponse);
    } catch (error) {
      console.error("Failed to fetch deployment:", error);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <Container>
        <Box sx={{ display: "flex", justifyContent: "center", py: 8 }}>
          <CircularProgress />
        </Box>
      </Container>
    );
  }

  if (!deployment) {
    return (
      <Container>
        <Alert severity="error">Deployment not found</Alert>
      </Container>
    );
  }

  return (
    <Container maxWidth="lg" sx={{ py: 4 }}>
      {/* Header */}
      <Box sx={{ mb: 3, display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <Box>
          <Typography variant="h5" sx={{ fontWeight: "bold" }}>
            {deployment.name}
          </Typography>
          <Typography variant="body2" color="textSecondary">
            {deployment.request_id}
          </Typography>
        </Box>
        <Button variant="outlined" onClick={() => navigate("/")}>
          Back
        </Button>
      </Box>

      {/* Details */}
      <Grid container spacing={3}>
        <Grid item xs={12} md={8}>
          <Card sx={{ mb: 3 }}>
            <CardContent>
              <Typography variant="h6" sx={{ fontWeight: "bold", mb: 2 }}>
                Details
              </Typography>
              <Box sx={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 2 }}>
                <Box>
                  <Typography variant="caption" color="textSecondary">
                    Type
                  </Typography>
                  <Typography variant="body1">{deployment.deployment_type}</Typography>
                </Box>
                <Box>
                  <Typography variant="caption" color="textSecondary">
                    Region
                  </Typography>
                  <Typography variant="body1">{deployment.region}</Typography>
                </Box>
                <Box>
                  <Typography variant="caption" color="textSecondary">
                    Environment
                  </Typography>
                  <Typography variant="body1">{deployment.environment}</Typography>
                </Box>
                <Box>
                  <Typography variant="caption" color="textSecondary">
                    Status
                  </Typography>
                  <Chip label={deployment.status} size="small" sx={{ mt: 0.5 }} />
                </Box>
              </Box>
            </CardContent>
          </Card>

          {/* Approvals */}
          <Card>
            <CardContent>
              <Typography variant="h6" sx={{ fontWeight: "bold", mb: 2 }}>
                Approvals
              </Typography>
              {approvals.length === 0 ? (
                <Typography variant="body2" color="textSecondary">
                  No approvals yet
                </Typography>
              ) : (
                <TableContainer>
                  <Table size="small">
                    <TableHead>
                      <TableRow>
                        <TableCell>Approver</TableCell>
                        <TableCell>Type</TableCell>
                        <TableCell>Status</TableCell>
                      </TableRow>
                    </TableHead>
                    <TableBody>
                      {approvals.map((approval) => (
                        <TableRow key={approval.id}>
                          <TableCell>{approval.approver.full_name || approval.approver.email}</TableCell>
                          <TableCell>{approval.approval_type}</TableCell>
                          <TableCell>
                            <Chip label={approval.status} size="small" />
                          </TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </TableContainer>
              )}
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} md={4}>
          <Card sx={{ mb: 3 }}>
            <CardContent>
              <Typography variant="h6" sx={{ fontWeight: "bold", mb: 2 }}>
                Cost
              </Typography>
              <Typography variant="h5" sx={{ color: "primary.main" }}>
                ${deployment.estimated_cost_monthly}/month
              </Typography>
            </CardContent>
          </Card>

          <Card>
            <CardContent>
              <Typography variant="h6" sx={{ fontWeight: "bold", mb: 2 }}>
                Actions
              </Typography>
              {deployment.status === "draft" && (
                <Button
                  fullWidth
                  variant="contained"
                  sx={{ mb: 1 }}
                  onClick={async () => {
                    await apiClient.submitDeployment(deployment.id);
                    fetchDeployment();
                  }}
                >
                  Submit for Approval
                </Button>
              )}
              {deployment.status === "submitted" && (
                <Button
                  fullWidth
                  variant="outlined"
                  disabled
                  sx={{ mb: 1 }}
                >
                  Waiting for Approval
                </Button>
              )}
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Container>
  );
}
