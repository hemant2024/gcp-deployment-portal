"""
GCP integration service - handles all Google Cloud API interactions
"""
import logging
from typing import List, Dict, Any, Optional
from google.cloud import compute_v1, container_v1, sqladmin_v1, iam_v1
from google.oauth2 import service_account
from config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()


class GCPService:
    """Main service for GCP operations"""

    def __init__(self, project_id: str):
        """Initialize GCP service with credentials"""
        self.project_id = project_id
        self.credentials = self._load_credentials()

        # Initialize clients
        if self.credentials:
            self.compute_client = compute_v1.InstancesClient(credentials=self.credentials)
            self.machine_types_client = compute_v1.MachineTypesClient(credentials=self.credentials)
            self.networks_client = compute_v1.NetworksClient(credentials=self.credentials)
            self.images_client = compute_v1.ImagesClient(credentials=self.credentials)
            self.container_client = container_v1.ClusterManagerClient(credentials=self.credentials)
            self.sql_client = sqladmin_v1.SqlInstancesServiceClient(credentials=self.credentials)
            self.iam_client = iam_v1.IAMPolicyClient(credentials=self.credentials)
        else:
            self.compute_client = None
            self.machine_types_client = None

    def _load_credentials(self):
        """Load GCP credentials from file"""
        try:
            if settings.GCP_CREDENTIALS_PATH:
                credentials = service_account.Credentials.from_service_account_file(
                    settings.GCP_CREDENTIALS_PATH
                )
                return credentials
            return None
        except Exception as e:
            logger.error(f"Failed to load GCP credentials: {e}")
            return None

    # ==================== GCE Methods ====================

    def list_machine_types(self, region: str) -> List[Dict[str, Any]]:
        """List available machine types for a region"""
        try:
            # Convert region to zone (e.g., us-central1 -> us-central1-a)
            zone = f"{region}-a"
            request = compute_v1.ListMachineTypesRequest(
                project=self.project_id,
                zone=zone
            )
            machines = self.machine_types_client.list(request=request)

            machine_list = []
            for machine in machines:
                machine_list.append({
                    "name": machine.name,
                    "description": machine.description,
                    "cpu_count": machine.guest_cpus,
                    "memory_mb": machine.memory_mb,
                    "is_deprecated": machine.deprecated is not None,
                })

            return machine_list[:20]  # Return top 20 machines
        except Exception as e:
            logger.error(f"Error listing machine types: {e}")
            return self._get_mock_machine_types()

    def list_images(self, family: str = "debian-12") -> List[Dict[str, str]]:
        """List available VM images"""
        try:
            request = compute_v1.ListImagesRequest(
                project="debian-cloud"  # Using Debian's public project
            )
            images = self.images_client.list(request=request)

            image_list = []
            for image in images:
                if family in image.name:
                    image_list.append({
                        "name": image.name,
                        "family": image.family,
                        "status": image.status,
                    })
                if len(image_list) >= 10:
                    break

            return image_list
        except Exception as e:
            logger.error(f"Error listing images: {e}")
            return self._get_mock_images()

    def list_networks(self) -> List[Dict[str, str]]:
        """List available VPC networks"""
        try:
            request = compute_v1.ListNetworksRequest(project=self.project_id)
            networks = self.networks_client.list(request=request)

            network_list = []
            for network in networks:
                network_list.append({
                    "name": network.name,
                    "auto_create_subnetworks": network.auto_create_subnetworks,
                    "mtu": network.mtu,
                })

            return network_list
        except Exception as e:
            logger.error(f"Error listing networks: {e}")
            return self._get_mock_networks()

    def create_gce_instance(
        self,
        zone: str,
        instance_name: str,
        machine_type: str,
        image_family: str,
        network: str = "default",
        tags: List[str] = None,
        labels: Dict[str, str] = None,
    ) -> Dict[str, Any]:
        """Create a GCE instance"""
        try:
            # Get the latest image
            images_request = compute_v1.GetFromImageRequest(
                project="debian-cloud",
                image_family=image_family,
            )
            image = self.images_client.get_from_family(request=images_request)

            # Build instance
            instance = compute_v1.Instance(
                name=instance_name,
                machine_type=f"zones/{zone}/machineTypes/{machine_type}",
                disks=[
                    compute_v1.AttachedDisk(
                        boot=True,
                        source_image=image.self_link,
                        auto_delete=True,
                        initialize_params=compute_v1.AttachedDiskInitializeParams(
                            source_image=image.self_link,
                        ),
                    )
                ],
                network_interfaces=[
                    compute_v1.NetworkInterface(
                        network=f"global/networks/{network}",
                        access_configs=[compute_v1.AccessConfig(name="External NAT")],
                    )
                ],
                tags=compute_v1.Tags(items=tags or []),
                labels=labels or {},
            )

            request = compute_v1.InsertInstanceRequest(
                project=self.project_id,
                zone=zone,
                instance_resource=instance,
            )

            operation = self.compute_client.insert(request=request)
            logger.info(f"Created GCE instance: {instance_name}")

            return {
                "success": True,
                "instance_name": instance_name,
                "operation_id": operation.id,
                "status": operation.status,
            }
        except Exception as e:
            logger.error(f"Error creating GCE instance: {e}")
            return {"success": False, "error": str(e)}

    # ==================== GKE Methods ====================

    def list_gke_versions(self, region: str) -> List[str]:
        """List available GKE cluster versions"""
        try:
            request = container_v1.GetServerConfigRequest(
                project_id=self.project_id,
                zone=f"{region}-a",
            )
            config = self.container_client.get_server_config(request=request)
            return config.valid_master_versions[:5]  # Return top 5 versions
        except Exception as e:
            logger.error(f"Error listing GKE versions: {e}")
            return self._get_mock_gke_versions()

    def create_gke_cluster(
        self,
        cluster_name: str,
        zone: str,
        version: str,
        num_nodes: int,
        machine_type: str,
        enable_autoscaling: bool = True,
        min_nodes: int = 1,
        max_nodes: int = 10,
    ) -> Dict[str, Any]:
        """Create a GKE cluster"""
        try:
            cluster = container_v1.Cluster(
                name=cluster_name,
                initial_node_count=num_nodes,
                node_config=container_v1.NodeConfig(
                    machine_type=machine_type,
                    oauth_scopes=[
                        "https://www.googleapis.com/auth/cloud-platform",
                    ],
                    workload_metadata_config=container_v1.WorkloadMetadataConfig(
                        mode=container_v1.WorkloadMetadataConfig.Mode.GKE_METADATA,
                    ),
                ),
                master_auth=container_v1.MasterAuth(
                    client_certificate_config=container_v1.ClientCertificateConfig(
                        issue_client_certificate=False,
                    ),
                ),
            )

            if enable_autoscaling:
                cluster.node_pools[0].autoscaling = container_v1.NodePoolAutoscaling(
                    enabled=True,
                    min_node_count=min_nodes,
                    max_node_count=max_nodes,
                )

            request = container_v1.CreateClusterRequest(
                project_id=self.project_id,
                zone=zone,
                cluster=cluster,
            )

            operation = self.container_client.create_cluster(request=request)
            logger.info(f"Created GKE cluster: {cluster_name}")

            return {
                "success": True,
                "cluster_name": cluster_name,
                "operation_name": operation.name,
                "status": operation.status,
            }
        except Exception as e:
            logger.error(f"Error creating GKE cluster: {e}")
            return {"success": False, "error": str(e)}

    # ==================== Cloud SQL Methods ====================

    def create_cloud_sql_instance(
        self,
        instance_id: str,
        database_version: str,
        region: str,
        tier: str,
        storage_gb: int = 20,
    ) -> Dict[str, Any]:
        """Create a Cloud SQL instance"""
        try:
            instance = sqladmin_v1.DatabaseInstance(
                name=instance_id,
                database_version=database_version,
                region=region,
                settings=sqladmin_v1.Settings(
                    tier=tier,
                    backup_configuration=sqladmin_v1.BackupConfiguration(
                        enabled=True,
                        start_time="03:00",
                    ),
                    database_flags=[
                        sqladmin_v1.DatabaseFlags(name="max_connections", value="100"),
                    ],
                ),
            )

            request = sqladmin_v1.CreateInstanceRequest(
                project=self.project_id,
                instance=instance,
            )

            operation = self.sql_client.create(request=request)
            logger.info(f"Created Cloud SQL instance: {instance_id}")

            return {
                "success": True,
                "instance_id": instance_id,
                "operation_name": operation.name,
                "status": operation.status,
            }
        except Exception as e:
            logger.error(f"Error creating Cloud SQL instance: {e}")
            return {"success": False, "error": str(e)}

    # ==================== Mock Data Methods ====================

    def _get_mock_machine_types(self) -> List[Dict[str, Any]]:
        """Return mock machine types for testing"""
        return [
            {"name": "n1-standard-1", "cpu_count": 1, "memory_mb": 3840, "is_deprecated": False},
            {"name": "n1-standard-2", "cpu_count": 2, "memory_mb": 7680, "is_deprecated": False},
            {"name": "n1-standard-4", "cpu_count": 4, "memory_mb": 15360, "is_deprecated": False},
            {"name": "n2-standard-2", "cpu_count": 2, "memory_mb": 8192, "is_deprecated": False},
            {"name": "n2-standard-4", "cpu_count": 4, "memory_mb": 16384, "is_deprecated": False},
        ]

    def _get_mock_images(self) -> List[Dict[str, str]]:
        """Return mock images for testing"""
        return [
            {"name": "debian-12-minimal", "family": "debian-12", "status": "READY"},
            {"name": "debian-11-minimal", "family": "debian-11", "status": "READY"},
            {"name": "ubuntu-2204-lts", "family": "ubuntu-2204-lts", "status": "READY"},
        ]

    def _get_mock_networks(self) -> List[Dict[str, str]]:
        """Return mock networks for testing"""
        return [
            {"name": "default", "auto_create_subnetworks": True, "mtu": 1460},
            {"name": "production", "auto_create_subnetworks": False, "mtu": 1460},
        ]

    def _get_mock_gke_versions(self) -> List[str]:
        """Return mock GKE versions for testing"""
        return ["1.28.0", "1.27.5", "1.27.4", "1.26.8"]
