/**
 * Approvals Page
 */
import React, { useEffect, useState } from "react";
import {
  Box,
  Container,
  Card,
  CircularProgress,
  Typography,
} from "@mui/material";
import { apiClient } from "../api/client";

export default function ApprovalsPage() {
  const [approvals, setApprovals] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchApprovals();
  }, []);

  const fetchApprovals = async () => {
    try {
      // Fetch deployments to find pending approvals
      const response = await apiClient.listDeployments();
      setApprovals(response.items || []);
    } catch (error) {
      console.error("Failed to fetch approvals:", error);
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

  return (
    <Container maxWidth="lg" sx={{ py: 4 }}>
      <Typography variant="h5" sx={{ fontWeight: "bold", mb: 3 }}>
        Pending Approvals
      </Typography>

      {approvals.length === 0 ? (
        <Card sx={{ p: 3, textAlign: "center" }}>
          <Typography color="textSecondary">
            No pending approvals
          </Typography>
        </Card>
      ) : (
        <Card>
          <Typography variant="body2" sx={{ p: 2 }}>
            Approvals list will be displayed here
          </Typography>
        </Card>
      )}
    </Container>
  );
}
