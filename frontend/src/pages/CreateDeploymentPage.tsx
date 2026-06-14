/**
 * Create Deployment Page
 */
import React, { useState } from "react";
import { useParams, useNavigate } from "react-router-dom";
import {
  Box,
  Container,
  Card,
  TextField,
  Button,
  Typography,
  Select,
  MenuItem,
  FormControl,
  FormLabel,
  Alert,
} from "@mui/material";
import { apiClient } from "../api/client";

export default function CreateDeploymentPage() {
  const { type } = useParams<{ type: string }>();
  const navigate = useNavigate();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [formData, setFormData] = useState({
    name: "",
    description: "",
    region: "us-central1",
    environment: "dev",
    machineType: "n1-standard-2",
    image: "debian-12",
  });

  const handleChange = (e: React.ChangeEvent<any>) => {
    setFormData({
      ...formData,
      [e.target.name]: e.target.value,
    });
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError("");

    try {
      let response;
      const baseData = {
        name: formData.name,
        description: formData.description,
        region: formData.region,
        environment: formData.environment,
        estimated_cost_monthly: 25.0,
      };

      if (type === "gce") {
        response = await apiClient.createGCEDeployment(1, {
          ...baseData,
          gce_config: {
            machine_type: formData.machineType,
            image: formData.image,
            boot_disk_size_gb: 10,
            network: "default",
            enable_public_ip: true,
          },
          deployment_type: "gce",
        });
      } else if (type === "gke") {
        response = await apiClient.createGKEDeployment(1, {
          ...baseData,
          gke_config: {
            cluster_version: "1.27.0",
            num_nodes: 3,
            min_nodes: 1,
            max_nodes: 10,
            machine_type_gke: "n1-standard-2",
            enable_autoscaling: true,
          },
          deployment_type: "gke",
        });
      } else {
        response = await apiClient.createCloudSQLDeployment(1, {
          ...baseData,
          cloud_sql_config: {
            database_version: "MYSQL_8_0",
            tier: "db-n1-standard-1",
            storage_size_gb: 20,
            backup_enabled: true,
          },
          deployment_type: "cloud_sql",
        });
      }

      navigate(`/deployments/${response.id}`);
    } catch (err: any) {
      setError(err.response?.data?.detail || "Failed to create deployment");
    } finally {
      setLoading(false);
    }
  };

  return (
    <Container maxWidth="md" sx={{ py: 4 }}>
      <Card sx={{ p: 4 }}>
        <Typography variant="h5" sx={{ fontWeight: "bold", mb: 3 }}>
          Create {type?.toUpperCase()} Deployment
        </Typography>

        {error && (
          <Alert severity="error" sx={{ mb: 2 }}>
            {error}
          </Alert>
        )}

        <form onSubmit={handleSubmit}>
          <TextField
            fullWidth
            label="Deployment Name"
            name="name"
            value={formData.name}
            onChange={handleChange}
            margin="normal"
            required
            disabled={loading}
          />

          <TextField
            fullWidth
            label="Description"
            name="description"
            value={formData.description}
            onChange={handleChange}
            margin="normal"
            multiline
            rows={3}
            disabled={loading}
          />

          <FormControl fullWidth margin="normal">
            <FormLabel>Region</FormLabel>
            <Select
              name="region"
              value={formData.region}
              onChange={handleChange}
              disabled={loading}
            >
              <MenuItem value="us-central1">US Central</MenuItem>
              <MenuItem value="us-east1">US East</MenuItem>
              <MenuItem value="europe-west1">Europe West</MenuItem>
              <MenuItem value="asia-east1">Asia East</MenuItem>
            </Select>
          </FormControl>

          <FormControl fullWidth margin="normal">
            <FormLabel>Environment</FormLabel>
            <Select
              name="environment"
              value={formData.environment}
              onChange={handleChange}
              disabled={loading}
            >
              <MenuItem value="dev">Development</MenuItem>
              <MenuItem value="staging">Staging</MenuItem>
              <MenuItem value="prod">Production</MenuItem>
            </Select>
          </FormControl>

          {type === "gce" && (
            <>
              <FormControl fullWidth margin="normal">
                <FormLabel>Machine Type</FormLabel>
                <Select
                  name="machineType"
                  value={formData.machineType}
                  onChange={handleChange}
                  disabled={loading}
                >
                  <MenuItem value="n1-standard-1">n1-standard-1</MenuItem>
                  <MenuItem value="n1-standard-2">n1-standard-2</MenuItem>
                  <MenuItem value="n1-standard-4">n1-standard-4</MenuItem>
                </Select>
              </FormControl>
            </>
          )}

          <Box sx={{ mt: 3, display: "flex", gap: 2 }}>
            <Button
              variant="contained"
              type="submit"
              disabled={loading}
            >
              Create Deployment
            </Button>
            <Button
              variant="outlined"
              onClick={() => navigate("/")}
              disabled={loading}
            >
              Cancel
            </Button>
          </Box>
        </form>
      </Card>
    </Container>
  );
}
