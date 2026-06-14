/**
 * Zustand Store for Authentication
 */
import { create } from "zustand";
import { apiClient } from "../api/client";

interface User {
  id: number;
  email: string;
  username: string;
  full_name?: string;
  role: string;
  is_active: boolean;
  is_admin: boolean;
}

interface AuthState {
  user: User | null;
  token: string | null;
  isLoading: boolean;
  error: string | null;

  // Actions
  register: (email: string, username: string, password: string, fullName?: string) => Promise<void>;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
  setToken: (token: string) => void;
  setUser: (user: User) => void;
  clearError: () => void;
}

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  token: localStorage.getItem("access_token"),
  isLoading: false,
  error: null,

  register: async (email, username, password, fullName) => {
    set({ isLoading: true, error: null });
    try {
      const response = await apiClient.register(email, username, password, fullName);
      localStorage.setItem("access_token", response.access_token);
      set({
        token: response.access_token,
        user: response.user,
        isLoading: false,
      });
    } catch (error: any) {
      const message = error.response?.data?.detail || "Registration failed";
      set({ error: message, isLoading: false });
      throw error;
    }
  },

  login: async (email, password) => {
    set({ isLoading: true, error: null });
    try {
      const response = await apiClient.login(email, password);
      localStorage.setItem("access_token", response.access_token);
      set({
        token: response.access_token,
        user: response.user,
        isLoading: false,
      });
    } catch (error: any) {
      const message = error.response?.data?.detail || "Login failed";
      set({ error: message, isLoading: false });
      throw error;
    }
  },

  logout: () => {
    localStorage.removeItem("access_token");
    set({ user: null, token: null, error: null });
  },

  setToken: (token) => {
    localStorage.setItem("access_token", token);
    set({ token });
  },

  setUser: (user) => {
    set({ user });
  },

  clearError: () => {
    set({ error: null });
  },
}));
