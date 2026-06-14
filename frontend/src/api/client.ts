/**
 * API Client for GCP Portal Backend
 */
import axios, { AxiosInstance } from "axios";

const API_BASE_URL = process.env.REACT_APP_API_URL || "http://localhost:8000";

class APIClient {
  private client: AxiosInstance;

  constructor() {
    this.client = axios.create({
      baseURL: API_BASE_URL,
      headers: {
        "Content-Type": "application/json",
      },
    });

    // Add token to all requests
    this.client.interceptors.request.use((config) => {
      const token = localStorage.getItem("access_token");
      if (token) {
        config.headers.Authorization = `Bearer ${token}`;
      }
      return config;
    });

    // Handle responses
    this.client.interceptors.response.use(
      (response) => response,
      (error) => {
        if (error.response?.status === 401) {
          localStorage.removeItem("access_token");
          window.location.href = "/login";
        }
        return Promise.reject(error);
      }
    );
  }

  // ==================== Auth ====================

  async register(email: string, username: string, password: string, fullName?: string) {
    const response = await this.client.post("/api/v1/auth/register", {
      email,
      username,
      password,
      full_name: fullName,
    });
    return response.data;
  }

  async login(email: string, password: string) {
    const response = await this.client.post("/api/v1/auth/login", {
      email,
      password,
    });
    return response.data;
  }

  async googleAuth(googleToken: string) {
    const response = await this.client.post("/api/v1/auth/google-callback", {
      google_token: googleToken,
    });
    return response.data;
  }

  // ==================== Deployments ====================

  async createGCEDeployment(projectId: number, data: any) {
    const response = await this.client.post(
      `/api/v1/deployments/gce?project_id=${projectId}`,
      data
    );
    return response.data;
  }

  async createGKEDeployment(projectId: number, data: any) {
    const response = await this.client.post(
      `/api/v1/deployments/gke?project_id=${projectId}`,
      data
    );
    return response.data;
  }

  async createCloudSQLDeployment(projectId: number, data: any) {
    const response = await this.client.post(
      `/api/v1/deployments/cloud-sql?project_id=${projectId}`,
      data
    );
    return response.data;
  }

  async getDeployment(deploymentId: number) {
    const response = await this.client.get(`/api/v1/deployments/${deploymentId}`);
    return response.data;
  }

  async listDeployments(filters?: {
    project_id?: number;
    status?: string;
    skip?: number;
    limit?: number;
  }) {
    const params = new URLSearchParams();
    if (filters) {
      Object.entries(filters).forEach(([key, value]) => {
        if (value !== undefined) {
          params.append(key, String(value));
        }
      });
    }

    const response = await this.client.get(
      `/api/v1/deployments?${params.toString()}`
    );
    return response.data;
  }

  async submitDeployment(deploymentId: number) {
    const response = await this.client.post(
      `/api/v1/deployments/${deploymentId}/submit`
    );
    return response.data;
  }

  async approveDeployment(deploymentId: number, comments?: string) {
    const response = await this.client.post(
      `/api/v1/deployments/${deploymentId}/approve`,
      { status: "approved", comments }
    );
    return response.data;
  }

  async rejectDeployment(deploymentId: number, comments?: string) {
    const response = await this.client.post(
      `/api/v1/deployments/${deploymentId}/reject`,
      { status: "rejected", comments }
    );
    return response.data;
  }

  async deployDeployment(deploymentId: number) {
    const response = await this.client.post(
      `/api/v1/deployments/${deploymentId}/deploy`
    );
    return response.data;
  }

  async getDeploymentApprovals(deploymentId: number) {
    const response = await this.client.get(
      `/api/v1/deployments/${deploymentId}/approvals`
    );
    return response.data;
  }

  // ==================== Catalog ====================

  async getMachineTypes(region: string = "us-central1") {
    const response = await this.client.get(`/api/v1/catalog/machines`, {
      params: { region },
    });
    return response.data;
  }

  async getImages(family: string = "debian-12") {
    const response = await this.client.get(`/api/v1/catalog/images`, {
      params: { family },
    });
    return response.data;
  }

  async getNetworks() {
    const response = await this.client.get(`/api/v1/catalog/networks`);
    return response.data;
  }

  async getGKEVersions(region: string = "us-central1") {
    const response = await this.client.get(`/api/v1/catalog/gke-versions`, {
      params: { region },
    });
    return response.data;
  }

  async getFullCatalog(region: string = "us-central1") {
    const response = await this.client.get(`/api/v1/catalog`, {
      params: { region },
    });
    return response.data;
  }
}

export const apiClient = new APIClient();
